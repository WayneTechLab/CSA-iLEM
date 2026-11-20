#!/usr/bin/env bash
set -euo pipefail

# Offline trust-boundary smoke. The curl shim returns a disposable archive;
# neither the network nor a user install root is touched.
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-remote-trust.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

REF_VALUE="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
FIXTURE="$TEST_ROOT/fixture/WayneTechLab-CSA-iLEM-aaaaaaa"
ARCHIVE="$TEST_ROOT/fixture.tar.gz"
MARKER="$TEST_ROOT/installer-ran"
mkdir -p -- "$FIXTURE" "$TEST_ROOT/bin"
printf '0.8.0\n' > "$FIXTURE/VERSION"
cat > "$FIXTURE/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'ran\n' > "$CSA_IEM_TEST_INSTALL_MARKER"
EOF
chmod +x "$FIXTURE/install.sh"
(cd "$FIXTURE" && shasum -a 256 VERSION install.sh > SHA256SUMS)
tar -czf "$ARCHIVE" -C "$TEST_ROOT/fixture" "$(basename -- "$FIXTURE")"
ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"

cat > "$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then
    shift
    output="${1:-}"
  fi
  shift
done
[[ -n "$output" ]]
cp -- "$CSA_IEM_TEST_ARCHIVE" "$output"
EOF
chmod +x "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH"
export CSA_IEM_TEST_ARCHIVE="$ARCHIVE"
export CSA_IEM_TEST_INSTALL_MARKER="$MARKER"

if bash "$ROOT_DIR/install-remote.sh" --ref main --archive-sha256 "$ARCHIVE_SHA256" >"$TEST_ROOT/mutable.log" 2>&1; then
  echo 'FAIL: mutable branch passed the remote installer trust gate' >&2
  exit 1
fi
test ! -e "$MARKER"
if bash "$ROOT_DIR/csa-iem-update" >"$TEST_ROOT/wrapper.log" 2>&1; then
  echo 'FAIL: update wrapper installed without independent release evidence' >&2
  exit 1
fi
test ! -e "$MARKER"
if cat "$ROOT_DIR/install-remote.sh" | bash -s -- --ref "$REF_VALUE" --archive-sha256 "$ARCHIVE_SHA256" >"$TEST_ROOT/pipe.log" 2>&1; then
  echo 'FAIL: piped remote installer was accepted' >&2
  exit 1
fi
test ! -e "$MARKER"
if bash "$ROOT_DIR/install-remote.sh" --ref "$REF_VALUE" --archive-sha256 "$(printf '0%.0s' {1..64})" >"$TEST_ROOT/digest.log" 2>&1; then
  echo 'FAIL: incorrect archive digest was accepted' >&2
  exit 1
fi
test ! -e "$MARKER"

bash "$ROOT_DIR/install-remote.sh" --ref "$REF_VALUE" --archive-sha256 "$ARCHIVE_SHA256" \
  --no-deps --no-gui-app --no-open --no-shell-profile >"$TEST_ROOT/valid.log" 2>&1
test -f "$MARKER"
echo 'PASS: remote install requires a pinned commit and independent archive digest before execution'
