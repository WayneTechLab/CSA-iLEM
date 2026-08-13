#!/usr/bin/env bash
set -euo pipefail

# Disposable Stage 2 preflight safety test. It exercises a weak/partial source
# and proves that a blocked preflight writes only a report under its temporary
# managed root while preserving the source tree.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-recovery.XXXXXX")"

cleanup() {
  if [[ "$TEST_ROOT" == "${TMPDIR:-/tmp}"/csa-iem-recovery.* && -d "$TEST_ROOT" ]]; then
    find "$TEST_ROOT" -depth -delete
  fi
}
trap cleanup EXIT

SOURCE_ROOT="$TEST_ROOT/source"
MANAGED_ROOT="$TEST_ROOT/managed"
REPORT_PATH="$TEST_ROOT/report.md"
PROJECT="$SOURCE_ROOT/Partial-Wiki-Metadata"
GH_STUB_ROOT="$TEST_ROOT/bin"

mkdir -p "$PROJECT/.git" "$MANAGED_ROOT" "$GH_STUB_ROOT"
printf 'partial metadata fixture\n' > "$PROJECT/wiki.md"
printf 'source must remain after blocked preflight\n' > "$PROJECT/README.md"
cat > "$GH_STUB_ROOT/gh" <<'EOF'
#!/usr/bin/env bash
# Keep this safety test local and deterministic: every GitHub operation fails
# immediately without consulting the host's real gh credentials or network.
exit 1
EOF
chmod +x "$GH_STUB_ROOT/gh"

echo "[1/4] blocked-source preflight"
set +e
PATH="$GH_STUB_ROOT:$PATH" GH_HOST=invalid.invalid bash "$ROOT_DIR/stage2-workspace.sh" \
  --source "$SOURCE_ROOT" \
  --managed-root "$MANAGED_ROOT" \
  --preflight \
  --all \
  --report "$REPORT_PATH" > "$TEST_ROOT/stage2-output.log" 2>&1
preflight_status=$?
set -e

echo "[2/4] report evidence"
test -f "$REPORT_PATH"
grep -q '^# CSA-iEM Stage 2 Report' "$REPORT_PATH"
grep -q 'Any blocker aborts the entire apply' "$REPORT_PATH"

echo "[3/4] source preservation"
test -f "$PROJECT/wiki.md"
test -f "$PROJECT/README.md"
test -d "$PROJECT/.git"
test -d "$MANAGED_ROOT"

echo "[4/4] no apply mutation"
test ! -e "$MANAGED_ROOT/Code/Repos/Partial-Wiki-Metadata"
printf 'Preflight exit status: %s\n' "$preflight_status"
echo "PASS: blocked Stage 2 preflight preserved source and isolated report state"
