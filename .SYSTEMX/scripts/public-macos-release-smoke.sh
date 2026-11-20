#!/usr/bin/env bash
set -euo pipefail

# Offline negative-path proof: a clean tagged fixture and valid ad-hoc bundle
# must stop before creating output when Developer ID is unavailable. This test
# never touches the installed CSA-iEM app or the Apple notary service.

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-public-release-smoke.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
FIXTURE_REPO="$TEST_ROOT/repo"
FIXTURE_SCRIPTS="$FIXTURE_REPO/.SYSTEMX/scripts"
FIXTURE_APP="$TEST_ROOT/input/CSA-iEM.app"
FIXTURE_OUTPUT="$TEST_ROOT/output"

mkdir -p -- "$FIXTURE_SCRIPTS" "$FIXTURE_APP/Contents/MacOS" "$FIXTURE_APP/Contents/Resources"
cp -- "$SOURCE_ROOT/.SYSTEMX/scripts/package-public-macos-release.sh" "$FIXTURE_SCRIPTS/"
cp -- "$SOURCE_ROOT/.SYSTEMX/scripts/macos-bundle-inventory.py" "$FIXTURE_SCRIPTS/"
cp -- "$SOURCE_ROOT/.SYSTEMX/scripts/public-macos-release-readiness.sh" "$FIXTURE_SCRIPTS/"
cp -- "$SOURCE_ROOT/.SYSTEMX/scripts/validate-macos-release-tag.sh" "$FIXTURE_SCRIPTS/"
printf '0.8.0\n' > "$FIXTURE_REPO/VERSION"
(cd "$FIXTURE_REPO" && shasum -a 256 VERSION > SHA256SUMS)
cp -- "$FIXTURE_REPO/SHA256SUMS" "$FIXTURE_APP/Contents/Resources/SHA256SUMS"
printf 'Reviewed help resource\n' > "$FIXTURE_APP/Contents/Resources/Help.txt"
cat > "$FIXTURE_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.waynetechlab.csa-iem</string>
<key>CFBundleShortVersionString</key><string>0.8.0</string>
<key>CFBundleVersion</key><string>0.8.0</string>
<key>CFBundleExecutable</key><string>CSA-iEM</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
cat > "$TEST_ROOT/main.c" <<'C'
int main(void) { return 0; }
C
cc "$TEST_ROOT/main.c" -o "$FIXTURE_APP/Contents/MacOS/CSA-iEM"
codesign --force --sign - --timestamp=none "$FIXTURE_APP" >/dev/null 2>&1
codesign --verify --deep --strict "$FIXTURE_APP" >/dev/null

git -C "$FIXTURE_REPO" init -q
git -C "$FIXTURE_REPO" add -A
git -C "$FIXTURE_REPO" -c user.name='Release Smoke' \
  -c user.email='release-smoke@example.invalid' commit -qm fixture
git -C "$FIXTURE_REPO" tag v0.8.0

before="$(shasum -a 256 "$FIXTURE_APP/Contents/MacOS/CSA-iEM" | awk '{print $1}')"
reviewed_inventory="$(/usr/bin/python3 "$FIXTURE_SCRIPTS/macos-bundle-inventory.py" "$FIXTURE_APP")"
if bash "$FIXTURE_SCRIPTS/package-public-macos-release.sh" \
  --app "$FIXTURE_APP" --output-dir "$FIXTURE_OUTPUT" \
  --expected-binary-sha256 "$before" \
  --expected-bundle-inventory-sha256 "$reviewed_inventory" \
  --identity 'Developer ID Application: Unsupported (AAAAAAAAAA)' \
  --notary-profile 'nonexistent-test-profile' \
  > "$TEST_ROOT/stdout.log" 2> "$TEST_ROOT/stderr.log"; then
  echo 'FAIL: unrecognized signing identity passed public release preflight' >&2
  exit 1
fi
grep -Fq 'identity is not valid in Keychain' "$TEST_ROOT/stderr.log" || {
  cat "$TEST_ROOT/stderr.log" >&2
  echo 'FAIL: public release stopped for an unexpected reason' >&2
  exit 1
}
[[ ! -e "$FIXTURE_OUTPUT" ]] || { echo 'FAIL: output was created before identity validation' >&2; exit 1; }
after="$(shasum -a 256 "$FIXTURE_APP/Contents/MacOS/CSA-iEM" | awk '{print $1}')"
[[ "$before" == "$after" ]] || { echo 'FAIL: input app changed' >&2; exit 1; }

if bash "$FIXTURE_SCRIPTS/package-public-macos-release.sh" \
  --app "$FIXTURE_APP" --output-dir "$FIXTURE_REPO/build-output" \
  --expected-binary-sha256 "$before" \
  --expected-bundle-inventory-sha256 "$reviewed_inventory" \
  --identity 'Developer ID Application: Unsupported (AAAAAAAAAA)' \
  --notary-profile 'nonexistent-test-profile' \
  > "$TEST_ROOT/overlap-stdout.log" 2> "$TEST_ROOT/overlap-stderr.log"; then
  echo 'FAIL: output inside tagged source was accepted' >&2
  exit 1
fi
grep -Fq 'Release paths overlap' "$TEST_ROOT/overlap-stderr.log" || {
  cat "$TEST_ROOT/overlap-stderr.log" >&2
  echo 'FAIL: source overlap stopped for an unexpected reason' >&2
  exit 1
}
[[ ! -e "$FIXTURE_REPO/build-output" ]] || { echo 'FAIL: overlapping output was created' >&2; exit 1; }

if bash "$FIXTURE_SCRIPTS/package-public-macos-release.sh" \
  --app "$FIXTURE_APP" --output-dir "$TEST_ROOT/hash-mismatch-output" \
  --expected-binary-sha256 "$(printf '0%.0s' {1..64})" \
  --expected-bundle-inventory-sha256 "$reviewed_inventory" \
  --identity 'Developer ID Application: Unsupported (AAAAAAAAAA)' \
  --notary-profile 'nonexistent-test-profile' \
  > "$TEST_ROOT/hash-stdout.log" 2> "$TEST_ROOT/hash-stderr.log"; then
  echo 'FAIL: mismatched reviewed executable digest was accepted' >&2
  exit 1
fi
grep -Fq 'differs from the separately reviewed SHA-256' "$TEST_ROOT/hash-stderr.log" || {
  cat "$TEST_ROOT/hash-stderr.log" >&2
  echo 'FAIL: digest mismatch stopped for an unexpected reason' >&2
  exit 1
}
[[ ! -e "$TEST_ROOT/hash-mismatch-output" ]] || { echo 'FAIL: mismatched digest created output' >&2; exit 1; }

TAMPERED_APP="$TEST_ROOT/tampered/CSA-iEM.app"
mkdir -p -- "$(dirname "$TAMPERED_APP")"
ditto --norsrc "$FIXTURE_APP" "$TAMPERED_APP"
printf 'Changed help resource\n' > "$TAMPERED_APP/Contents/Resources/Help.txt"
codesign --force --sign - --timestamp=none "$TAMPERED_APP" >/dev/null 2>&1
codesign --verify --deep --strict "$TAMPERED_APP" >/dev/null
tampered_binary="$(shasum -a 256 "$TAMPERED_APP/Contents/MacOS/CSA-iEM" | awk '{print $1}')"
if bash "$FIXTURE_SCRIPTS/package-public-macos-release.sh" \
  --app "$TAMPERED_APP" --output-dir "$TEST_ROOT/resource-tamper-output" \
  --expected-binary-sha256 "$tampered_binary" \
  --expected-bundle-inventory-sha256 "$reviewed_inventory" \
  --identity 'Developer ID Application: Unsupported (AAAAAAAAAA)' \
  --notary-profile 'nonexistent-test-profile' \
  > "$TEST_ROOT/resource-stdout.log" 2> "$TEST_ROOT/resource-stderr.log"; then
  echo 'FAIL: tampered resource passed public release preflight' >&2
  exit 1
fi
grep -Fq 'outside the separately reviewed bundle inventory' "$TEST_ROOT/resource-stderr.log" || {
  cat "$TEST_ROOT/resource-stderr.log" >&2
  echo 'FAIL: resource tamper stopped for an unexpected reason' >&2
  exit 1
}
[[ ! -e "$TEST_ROOT/resource-tamper-output" ]] || { echo 'FAIL: resource tamper created output' >&2; exit 1; }

if bash "$FIXTURE_SCRIPTS/public-macos-release-readiness.sh" \
  --app "$TAMPERED_APP" \
  --expected-signed-bundle-inventory-sha256 "$reviewed_inventory" \
  > "$TEST_ROOT/readiness-tamper.log" 2>&1; then
  echo 'FAIL: public readiness accepted changed signed resource' >&2
  exit 1
fi
grep -Fq 'Signed app bundle differs from the reviewed inventory' "$TEST_ROOT/readiness-tamper.log" || {
  cat "$TEST_ROOT/readiness-tamper.log" >&2
  echo 'FAIL: public readiness did not report changed signed resource' >&2
  exit 1
}

EXTRA_APP="$TEST_ROOT/extra/CSA-iEM.app"
mkdir -p -- "$(dirname "$EXTRA_APP")"
ditto --norsrc "$FIXTURE_APP" "$EXTRA_APP"
printf 'Unreviewed extra resource\n' > "$EXTRA_APP/Contents/Resources/Extra.txt"
codesign --force --sign - --timestamp=none "$EXTRA_APP" >/dev/null 2>&1
codesign --verify --deep --strict "$EXTRA_APP" >/dev/null
extra_binary="$(shasum -a 256 "$EXTRA_APP/Contents/MacOS/CSA-iEM" | awk '{print $1}')"
if bash "$FIXTURE_SCRIPTS/package-public-macos-release.sh" \
  --app "$EXTRA_APP" --output-dir "$TEST_ROOT/extra-resource-output" \
  --expected-binary-sha256 "$extra_binary" \
  --expected-bundle-inventory-sha256 "$reviewed_inventory" \
  --identity 'Developer ID Application: Unsupported (AAAAAAAAAA)' \
  --notary-profile 'nonexistent-test-profile' \
  > "$TEST_ROOT/extra-stdout.log" 2> "$TEST_ROOT/extra-stderr.log"; then
  echo 'FAIL: extra resource passed public release preflight' >&2
  exit 1
fi
grep -Fq 'outside the separately reviewed bundle inventory' "$TEST_ROOT/extra-stderr.log" || {
  cat "$TEST_ROOT/extra-stderr.log" >&2
  echo 'FAIL: extra resource stopped for an unexpected reason' >&2
  exit 1
}
[[ ! -e "$TEST_ROOT/extra-resource-output" ]] || { echo 'FAIL: extra resource created output' >&2; exit 1; }

ln -s /etc/hosts "$FIXTURE_APP/Contents/Resources/Linked.txt"
if bash "$FIXTURE_SCRIPTS/package-public-macos-release.sh" \
  --app "$FIXTURE_APP" --output-dir "$TEST_ROOT/symlink-output" \
  --expected-binary-sha256 "$before" \
  --expected-bundle-inventory-sha256 "$reviewed_inventory" \
  --identity 'Developer ID Application: Unsupported (AAAAAAAAAA)' \
  --notary-profile 'nonexistent-test-profile' \
  > "$TEST_ROOT/symlink-stdout.log" 2> "$TEST_ROOT/symlink-stderr.log"; then
  echo 'FAIL: linked resource passed public release preflight' >&2
  exit 1
fi
grep -Fq 'unreadable, linked, or special bundle entry' "$TEST_ROOT/symlink-stderr.log" || {
  cat "$TEST_ROOT/symlink-stderr.log" >&2
  echo 'FAIL: linked resource stopped for an unexpected reason' >&2
  exit 1
}
[[ ! -e "$TEST_ROOT/symlink-output" ]] || { echo 'FAIL: symlink created output' >&2; exit 1; }

echo 'PASS: public release blocks missing identity, overlap, binary mismatch, changed/extra resources, and symlinks before output'
