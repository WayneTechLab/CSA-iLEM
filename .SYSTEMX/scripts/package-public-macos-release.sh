#!/usr/bin/env bash
set -euo pipefail

# Separate public release lane. The normal builder/installer intentionally use
# ad-hoc signatures for local development. This script never changes that app,
# the source checkout, an installed app, a Git ref, or a public distribution.
# Every intermediate artifact remains under a new, caller-selected directory.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT_APP=""
OUTPUT_DIR=""
IDENTITY=""
NOTARY_PROFILE=""
EXPECTED_BINARY_SHA256=""
EXPECTED_BUNDLE_INVENTORY_SHA256=""

usage() {
  cat <<'EOF'
Usage: package-public-macos-release.sh --app BUILT_APP --output-dir NEW_DIR \
  --expected-binary-sha256 REVIEWED_SHA256 \
  --expected-bundle-inventory-sha256 REVIEWED_INVENTORY_SHA256 \
  --identity 'Developer ID Application: Legal Entity (TEAMID)' \
  --notary-profile KEYCHAIN_PROFILE

The input must be a locally verified CSA-iEM.app matching a clean, exactly
tagged source checkout. The output directory must not exist. A valid Developer
ID Application identity and an authenticated notarytool Keychain profile are
required before any artifact is created. This submits a ZIP to Apple for
notarization, staples the app, validates Gatekeeper acceptance, and creates a
separate distribution ZIP and SHA-256 manifest. It does not publish a release.
No password, private key, or API key is accepted on this command line.
The expected executable and whole-bundle inventory digests must come from a
separately reviewed build. The inventory covers all files and directories,
including resources and signature files. See macos-bundle-inventory.py.
EOF
}

fail() {
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --app|--output-dir|--identity|--notary-profile|--expected-binary-sha256|--expected-bundle-inventory-sha256)
      option="$1"
      shift
      [[ "$#" -gt 0 ]] || { usage >&2; exit 2; }
      case "$option" in
        --app) INPUT_APP="$1" ;;
        --output-dir) OUTPUT_DIR="$1" ;;
        --identity) IDENTITY="$1" ;;
        --notary-profile) NOTARY_PROFILE="$1" ;;
        --expected-binary-sha256) EXPECTED_BINARY_SHA256="$1" ;;
        --expected-bundle-inventory-sha256) EXPECTED_BUNDLE_INVENTORY_SHA256="$1" ;;
      esac
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

[[ "$(uname -s)" == Darwin ]] || fail 'Public macOS packaging requires macOS.'
[[ -n "$INPUT_APP" && -n "$OUTPUT_DIR" && -n "$IDENTITY" && -n "$NOTARY_PROFILE" \
   && -n "$EXPECTED_BINARY_SHA256" && -n "$EXPECTED_BUNDLE_INVENTORY_SHA256" ]] \
  || { usage >&2; fail 'App, new output directory, reviewed executable and bundle inventory SHA-256 digests, exact Developer ID identity, and notary profile are required.'; }
[[ "$EXPECTED_BINARY_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] \
  || fail 'The reviewed executable SHA-256 must contain exactly 64 hexadecimal characters.'
[[ "$EXPECTED_BUNDLE_INVENTORY_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] \
  || fail 'The reviewed bundle inventory SHA-256 must contain exactly 64 hexadecimal characters.'
EXPECTED_BINARY_SHA256_LC="$(printf '%s' "$EXPECTED_BINARY_SHA256" | tr '[:upper:]' '[:lower:]')"
EXPECTED_BUNDLE_INVENTORY_SHA256_LC="$(printf '%s' "$EXPECTED_BUNDLE_INVENTORY_SHA256" | tr '[:upper:]' '[:lower:]')"
[[ "$IDENTITY" == 'Developer ID Application: '* ]] \
  || fail 'The signing identity must be a Developer ID Application identity.'
[[ "$IDENTITY" =~ \(([A-Z0-9]{10})\)$ ]] \
  || fail 'The Developer ID Application identity must include its 10-character team ID.'
EXPECTED_TEAM="${BASH_REMATCH[1]}"
[[ "$INPUT_APP" == /* && "$OUTPUT_DIR" == /* ]] \
  || fail 'App and output paths must be absolute.'
[[ -d "$INPUT_APP" && ! -L "$INPUT_APP" ]] \
  || fail 'The built app must be a real directory, not a symlink.'
[[ ! -e "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]] \
  || fail 'The output directory already exists; choose a new path.'
[[ -d "$(dirname "$OUTPUT_DIR")" && ! -L "$(dirname "$OUTPUT_DIR")" ]] \
  || fail 'The output parent must be an existing real directory.'

for tool in security codesign spctl xcrun shasum ditto unzip git tr /usr/libexec/PlistBuddy /usr/bin/python3; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required release tool is unavailable: $tool"
done
xcrun --find notarytool >/dev/null 2>&1 || fail 'notarytool is unavailable.'
xcrun --find stapler >/dev/null 2>&1 || fail 'stapler is unavailable.'

# Resolve and validate paths before any output is made. Keeping the output
# outside source and input prevents recursion, dirty tags, and input mutation.
/usr/bin/python3 - "$ROOT_DIR" "$INPUT_APP" "$OUTPUT_DIR" <<'PY' \
  || fail 'Release paths overlap or contain unsupported components.'
import os
import sys
from pathlib import Path

repo, app, out = map(Path, sys.argv[1:])
repo_real, app_real, out_real = map(lambda p: str(p.resolve()), (repo, app, out))
for path in (app, out):
    if path.name in ("", ".", "..") or str(path) != os.path.normpath(str(path)):
        sys.exit(1)
for left, right in ((repo_real, out_real), (app_real, out_real)):
    if os.path.commonpath((left, right)) == left:
        sys.exit(1)
if out_real == app_real:
    sys.exit(1)
PY

[[ -z "$(git -C "$ROOT_DIR" status --porcelain=v1)" ]] \
  || fail 'The source checkout must be clean before public packaging.'
(cd "$ROOT_DIR" && shasum -a 256 -c --strict SHA256SUMS >/dev/null) \
  || fail 'The source payload checksum manifest does not verify.'
VERSION="$(sed -n '1p' "$ROOT_DIR/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail 'VERSION must be an exact semantic version.'
bash "$ROOT_DIR/.SYSTEMX/scripts/validate-macos-release-tag.sh" "v$VERSION" >/dev/null \
  || fail 'An exact vVERSION tag must identify checked-out HEAD.'

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INPUT_APP/Contents/Info.plist" 2>/dev/null || true)"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INPUT_APP/Contents/Info.plist" 2>/dev/null || true)"
[[ "$bundle_id" == com.waynetechlab.csa-iem && "$bundle_version" == "$VERSION" ]] \
  || fail 'The built app bundle ID or version differs from the tagged source.'
[[ "$(shasum -a 256 "$INPUT_APP/Contents/MacOS/CSA-iEM" | awk '{print $1}')" \
   == "$EXPECTED_BINARY_SHA256_LC" ]] \
  || fail 'The built app executable differs from the separately reviewed SHA-256.'
[[ -f "$INPUT_APP/Contents/Resources/SHA256SUMS" ]] \
  || fail 'The built app lacks its source payload manifest.'
[[ "$(shasum -a 256 "$INPUT_APP/Contents/Resources/SHA256SUMS" | awk '{print $1}')" \
   == "$(shasum -a 256 "$ROOT_DIR/SHA256SUMS" | awk '{print $1}')" ]] \
  || fail 'The built app payload manifest differs from tagged source.'
input_inventory="$(/usr/bin/python3 "$ROOT_DIR/.SYSTEMX/scripts/macos-bundle-inventory.py" "$INPUT_APP")" \
  || fail 'The built app has an unreadable, linked, or special bundle entry.'
[[ "$input_inventory" == "$EXPECTED_BUNDLE_INVENTORY_SHA256_LC" ]] \
  || fail 'The built app contains files or resources outside the separately reviewed bundle inventory.'
codesign --verify --deep --strict "$INPUT_APP" >/dev/null 2>&1 \
  || fail 'The built app does not pass strict code-signature verification.'

# The current product has one Mach-O executable. A future framework/helper
# requires explicit inside-out signing; never use --deep to sign it blindly.
/usr/bin/python3 - "$INPUT_APP" <<'PY' \
  || fail 'Unexpected nested code, link, or special file needs reviewed inside-out signing.'
import os
import stat
import sys
from pathlib import Path

app = Path(sys.argv[1])
mach_o = {b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf",
          b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe",
          b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
expected = "Contents/MacOS/CSA-iEM"
found = []
for base, dirs, files in os.walk(app, followlinks=False):
    for name in dirs + files:
        entry = Path(base) / name
        mode = entry.lstat().st_mode
        if stat.S_ISLNK(mode) or not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
            sys.exit(1)
        if stat.S_ISDIR(mode):
            if entry != app and entry.suffix in (".app", ".appex", ".xpc", ".framework"):
                sys.exit(1)
            continue
        with entry.open("rb") as handle:
            if handle.read(4) in mach_o:
                found.append(entry.relative_to(app).as_posix())
if found != [expected]:
    sys.exit(1)
PY

if [[ -n "$(codesign -d --entitlements :- "$INPUT_APP" 2>/dev/null || true)" ]]; then
  fail 'The built app has entitlements requiring a reviewed distribution signing configuration.'
fi
valid_identities="$(security find-identity -v -p codesigning 2>/dev/null)" \
  || fail 'Could not read valid signing identities from Keychain.'
grep -Fq -- "\"$IDENTITY\"" <<< "$valid_identities" \
  || fail 'The exact Developer ID Application identity is not valid in Keychain.'

# A read-only Apple request checks that the named Keychain profile is usable.
# Its output and errors stay hidden to avoid leaking account information.
/usr/bin/python3 - "$NOTARY_PROFILE" <<'PY' \
  || fail 'The named notarytool Keychain profile could not authenticate.'
import subprocess
import sys

try:
    result = subprocess.run(
        ["xcrun", "notarytool", "history", "--keychain-profile", sys.argv[1],
         "--output-format", "json", "--no-progress"],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, timeout=30,
    )
except (OSError, subprocess.TimeoutExpired):
    sys.exit(1)
sys.exit(result.returncode)
PY

mkdir -m 700 -- "$OUTPUT_DIR" || fail 'Could not create the new output directory.'
RELEASE_APP="$OUTPUT_DIR/CSA-iEM.app"
SUBMISSION_ZIP="$OUTPUT_DIR/CSA-iEM-v$VERSION-submission.zip"
FINAL_ZIP="$OUTPUT_DIR/CSA-iEM-v$VERSION-macos.zip"
SUBMISSION_JSON="$OUTPUT_DIR/notary-submission.json"

printf 'Copying verified input into isolated release output...\n'
ditto --norsrc "$INPUT_APP" "$RELEASE_APP" \
  || fail "Copy failed; inspect preserved output at $OUTPUT_DIR"
[[ "$(shasum -a 256 "$RELEASE_APP/Contents/MacOS/CSA-iEM" | awk '{print $1}')" \
   == "$EXPECTED_BINARY_SHA256_LC" ]] \
  || fail "Copied executable differs from the reviewed build; inspect $OUTPUT_DIR"
[[ "$(shasum -a 256 "$RELEASE_APP/Contents/Resources/SHA256SUMS" | awk '{print $1}')" \
   == "$(shasum -a 256 "$ROOT_DIR/SHA256SUMS" | awk '{print $1}')" ]] \
  || fail "Copied payload manifest differs from tagged source; inspect $OUTPUT_DIR"
[[ "$(/usr/bin/python3 "$ROOT_DIR/.SYSTEMX/scripts/macos-bundle-inventory.py" "$RELEASE_APP")" \
   == "$EXPECTED_BUNDLE_INVENTORY_SHA256_LC" ]] \
  || fail "Copied bundle differs from the reviewed inventory; inspect $OUTPUT_DIR"
codesign --verify --deep --strict "$RELEASE_APP" >/dev/null 2>&1 \
  || fail "Copied app failed signature verification; inspect $OUTPUT_DIR"

printf 'Applying Developer ID signature with Hardened Runtime and secure timestamp...\n'
codesign --force --sign "$IDENTITY" --options runtime --timestamp "$RELEASE_APP" \
  || fail "Developer ID signing failed; inspect preserved output at $OUTPUT_DIR"
codesign --verify --deep --strict "$RELEASE_APP" >/dev/null 2>&1 \
  || fail "Developer ID signature verification failed; inspect $OUTPUT_DIR"
signature="$(codesign -dv --verbose=4 "$RELEASE_APP" 2>&1)"
grep -Fqx -- "Authority=$IDENTITY" <<< "$signature" \
  || fail "Signed app has the wrong Developer ID authority; inspect $OUTPUT_DIR"
grep -Fqx -- "TeamIdentifier=$EXPECTED_TEAM" <<< "$signature" \
  || fail "Signed app has the wrong team identity; inspect $OUTPUT_DIR"
grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)' <<< "$signature" \
  || fail "Signed app lacks Hardened Runtime; inspect $OUTPUT_DIR"
grep -Eq '^Timestamp=[^ ]' <<< "$signature" \
  || fail "Signed app lacks a secure timestamp; inspect $OUTPUT_DIR"

ditto -c -k --keepParent "$RELEASE_APP" "$SUBMISSION_ZIP" \
  || fail "Notarization archive failed; inspect $OUTPUT_DIR"
unzip -tq "$SUBMISSION_ZIP" >/dev/null \
  || fail "Notarization archive failed ZIP validation; inspect $OUTPUT_DIR"

printf 'Submitting signed archive to Apple notary service...\n'
if ! xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" \
  --wait --timeout 60m --output-format json --no-progress > "$SUBMISSION_JSON"; then
  fail "Notarization submission failed; response and artifacts remain at $OUTPUT_DIR"
fi
/usr/bin/python3 - "$SUBMISSION_JSON" <<'PY' \
  || fail "Apple did not accept the notarization submission; inspect $SUBMISSION_JSON"
import json
import sys
from pathlib import Path

response = json.loads(Path(sys.argv[1]).read_text())
if response.get("status") != "Accepted" or not response.get("id"):
    sys.exit(1)
PY

xcrun stapler staple "$RELEASE_APP" \
  || fail "Stapling failed; accepted submission and app remain at $OUTPUT_DIR"
xcrun stapler validate -q "$RELEASE_APP" \
  || fail "Stapled ticket validation failed; inspect $OUTPUT_DIR"
codesign --verify --deep --strict "$RELEASE_APP" >/dev/null 2>&1 \
  || fail "Stapled app signature failed verification; inspect $OUTPUT_DIR"
spctl --assess --type execute "$RELEASE_APP" \
  || fail "Gatekeeper rejected the stapled app; inspect $OUTPUT_DIR"

ditto -c -k --keepParent "$RELEASE_APP" "$FINAL_ZIP" \
  || fail "Final distribution ZIP failed; inspect $OUTPUT_DIR"
unzip -tq "$FINAL_ZIP" >/dev/null \
  || fail "Final distribution ZIP failed validation; inspect $OUTPUT_DIR"
READBACK_DIR="$OUTPUT_DIR/.final-zip-readback"
mkdir -m 700 -- "$READBACK_DIR" \
  || fail "Could not prepare final ZIP readback; inspect $OUTPUT_DIR"
ditto -x -k "$FINAL_ZIP" "$READBACK_DIR" \
  || fail "Could not extract final ZIP for readback; inspect $OUTPUT_DIR"
READBACK_APP="$READBACK_DIR/CSA-iEM.app"
[[ -d "$READBACK_APP" && ! -L "$READBACK_APP" ]] \
  || fail "Final ZIP did not contain the expected app; inspect $OUTPUT_DIR"
codesign --verify --deep --strict "$READBACK_APP" >/dev/null 2>&1 \
  || fail "Extracted final app failed signature verification; inspect $OUTPUT_DIR"
xcrun stapler validate -q "$READBACK_APP" \
  || fail "Extracted final app has no valid stapled ticket; inspect $OUTPUT_DIR"
spctl --assess --type execute "$READBACK_APP" \
  || fail "Gatekeeper rejected the extracted final app; inspect $OUTPUT_DIR"
signed_inventory="$(/usr/bin/python3 "$ROOT_DIR/.SYSTEMX/scripts/macos-bundle-inventory.py" "$RELEASE_APP")" \
  || fail "Signed app inventory could not be read; inspect $OUTPUT_DIR"
[[ "$(/usr/bin/python3 "$ROOT_DIR/.SYSTEMX/scripts/macos-bundle-inventory.py" "$READBACK_APP")" \
   == "$signed_inventory" ]] \
  || fail "Final ZIP contents differ from the accepted app; inspect $OUTPUT_DIR"
printf '%s\n' "$signed_inventory" > "$OUTPUT_DIR/SIGNED-BUNDLE-INVENTORY.sha256" \
  || fail "Could not record the signed bundle inventory; inspect $OUTPUT_DIR"
(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$FINAL_ZIP")" SIGNED-BUNDLE-INVENTORY.sha256 > SHA256SUMS) \
  || fail "Final artifact checksum manifest failed; inspect $OUTPUT_DIR"
(cd "$OUTPUT_DIR" && shasum -a 256 -c --strict SHA256SUMS >/dev/null) \
  || fail "Final artifact checksum readback failed; inspect $OUTPUT_DIR"
rm -r -- "$READBACK_DIR" \
  || fail "Final ZIP readback passed but cleanup failed; inspect $OUTPUT_DIR"

printf 'PASS: local notarized release artifact prepared at %s\n' "$FINAL_ZIP"
printf 'PASS: SHA-256 manifest prepared at %s\n' "$OUTPUT_DIR/SHA256SUMS"
printf 'PASS: signed bundle inventory recorded at %s\n' "$OUTPUT_DIR/SIGNED-BUNDLE-INVENTORY.sha256"
printf 'Review and publish the artifact and checksum through a separately authorized release channel.\n'
