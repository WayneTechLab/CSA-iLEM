#!/usr/bin/env bash
set -uo pipefail

# Read-only public-distribution gate. The normal release preflight deliberately
# accepts an ad-hoc signed local app; this gate must not mistake it for a
# Developer ID-signed, notarized artifact.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH="${CSA_IEM_PUBLIC_APP:-/Applications/CSA-iEM.app}"
IDENTITY="${CSA_IEM_DEVELOPER_ID_IDENTITY:-}"
NOTARY_PROFILE="${CSA_IEM_NOTARY_PROFILE:-}"
EXPECTED_SIGNED_BUNDLE_INVENTORY_SHA256="${CSA_IEM_PUBLIC_SIGNED_BUNDLE_INVENTORY_SHA256:-}"
BLOCKED=0

usage() {
  cat <<'EOF'
Usage: public-macos-release-readiness.sh [--app APP_PATH] [--identity NAME] \
  [--notary-profile NAME] --expected-signed-bundle-inventory-sha256 REVIEWED_SHA256

Read-only assessment of a finished macOS release candidate. NAME must be the
exact Developer ID Application identity displayed by `security find-identity`.
The notary profile must already have been stored in Keychain with `notarytool
store-credentials`. No certificate, password, API key, or profile is created.
The signed-bundle inventory digest must come from a separately reviewed
packaging result; do not calculate it from an unreviewed candidate at gate time.

Environment alternatives: CSA_IEM_PUBLIC_APP, CSA_IEM_DEVELOPER_ID_IDENTITY,
CSA_IEM_NOTARY_PROFILE, CSA_IEM_PUBLIC_SIGNED_BUNDLE_INVENTORY_SHA256.
EOF
}

blocked() {
  printf 'BLOCKED: %s\n' "$1"
  BLOCKED=1
}

passed() {
  printf 'PASS: %s\n' "$1"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --app|--identity|--notary-profile|--expected-signed-bundle-inventory-sha256)
      option="$1"
      shift
      [[ "$#" -gt 0 ]] || { usage >&2; exit 2; }
      case "$option" in
        --app) APP_PATH="$1" ;;
        --identity) IDENTITY="$1" ;;
        --notary-profile) NOTARY_PROFILE="$1" ;;
        --expected-signed-bundle-inventory-sha256) EXPECTED_SIGNED_BUNDLE_INVENTORY_SHA256="$1" ;;
      esac
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != Darwin ]]; then
  blocked 'A macOS host is required for public release assessment.'
  exit 1
fi

for tool in security codesign spctl xcrun shasum git /usr/libexec/PlistBuddy /usr/bin/python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    blocked "Required release tool is unavailable: $tool"
  fi
done
[[ "$BLOCKED" -eq 0 ]] || exit 1

if xcrun --find notarytool >/dev/null 2>&1 && xcrun --find stapler >/dev/null 2>&1; then
  passed 'notarytool and stapler are available.'
else
  blocked 'Xcode notarytool and stapler are required.'
fi

if [[ -z "$IDENTITY" || "$IDENTITY" != 'Developer ID Application: '* ]]; then
  blocked 'Set the exact Developer ID Application identity with --identity.'
elif valid_identities="$(security find-identity -v -p codesigning 2>/dev/null)" \
  && grep -Fq -- "\"$IDENTITY\"" <<< "$valid_identities"; then
  passed 'The selected Developer ID Application signing identity is valid in Keychain.'
else
  blocked 'The selected Developer ID Application identity is not a valid Keychain signing identity.'
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  blocked 'Set a stored notarytool Keychain profile with --notary-profile.'
elif /usr/bin/python3 - "$NOTARY_PROFILE" <<'PY'
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
then
  passed 'The stored notarytool profile authenticated with Apple.'
else
  blocked 'The notarytool profile could not be authenticated; check Keychain and Apple service access.'
fi

if [[ ! "$EXPECTED_SIGNED_BUNDLE_INVENTORY_SHA256" =~ ^[0-9a-fA-F]{64}$ ]]; then
  blocked 'Supply a separately reviewed signed-bundle inventory SHA-256.'
fi

VERSION="$(sed -n '1p' "$ROOT_DIR/VERSION" 2>/dev/null || true)"
if source_state="$(git -C "$ROOT_DIR" status --porcelain=v1 2>/dev/null)" \
  && [[ -z "$source_state" ]]; then
  passed 'The release source checkout is clean.'
else
  blocked 'The release source checkout has uncommitted or untracked files.'
fi
if (cd "$ROOT_DIR" && shasum -a 256 -c --strict SHA256SUMS >/dev/null 2>&1); then
  passed 'All source payload checksums verify.'
else
  blocked 'The source payload checksum manifest does not verify.'
fi
if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  && bash "$ROOT_DIR/.SYSTEMX/scripts/validate-macos-release-tag.sh" "v$VERSION" >/dev/null 2>&1; then
  passed 'The exact version tag identifies checked-out HEAD.'
else
  blocked 'A vVERSION release tag must identify checked-out HEAD.'
fi

if [[ ! -d "$APP_PATH" || -L "$APP_PATH" ]]; then
  blocked 'The release candidate must be a real app bundle directory.'
else
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
  bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$bundle_id" == com.waynetechlab.csa-iem && "$bundle_version" == "$VERSION" ]]; then
    passed 'App bundle identity and version match the source.'
  else
    blocked 'App bundle ID or version differs from the source.'
  fi
  if [[ -f "$APP_PATH/Contents/Resources/SHA256SUMS" ]] \
    && [[ "$(shasum -a 256 "$APP_PATH/Contents/Resources/SHA256SUMS" | awk '{print $1}')" \
       == "$(shasum -a 256 "$ROOT_DIR/SHA256SUMS" | awk '{print $1}')" ]]; then
    passed 'Bundled payload manifest matches checked-out source.'
  else
    blocked 'Bundled payload manifest differs from checked-out source.'
  fi
  if [[ "$EXPECTED_SIGNED_BUNDLE_INVENTORY_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] \
    && actual_inventory="$(/usr/bin/python3 "$ROOT_DIR/.SYSTEMX/scripts/macos-bundle-inventory.py" "$APP_PATH" 2>/dev/null)" \
    && [[ "$actual_inventory" == "$(printf '%s' "$EXPECTED_SIGNED_BUNDLE_INVENTORY_SHA256" | tr '[:upper:]' '[:lower:]')" ]]; then
    passed 'The entire signed app bundle matches the separately reviewed inventory.'
  else
    blocked 'Signed app bundle differs from the reviewed inventory, or contains an unreadable/link/special entry.'
  fi

  if codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
    passed 'The app passes strict code-signature verification.'
  else
    blocked 'The app fails strict code-signature verification.'
  fi
  signature="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
  if [[ "$IDENTITY" =~ \(([A-Z0-9]{10})\)$ ]] \
    && grep -Fqx -- "Authority=$IDENTITY" <<< "$signature" \
    && grep -Fqx -- "TeamIdentifier=${BASH_REMATCH[1]}" <<< "$signature" \
    && ! grep -q '^Signature=adhoc' <<< "$signature"; then
    passed 'The app is signed with a Developer ID Application certificate.'
  else
    blocked 'The app lacks a Developer ID Application signature and team identity.'
  fi
  if grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)' <<< "$signature"; then
    passed 'Hardened Runtime is enabled.'
  else
    blocked 'Hardened Runtime is not enabled.'
  fi
  if grep -Eq '^Timestamp=[^ ]' <<< "$signature"; then
    passed 'The code signature has a secure timestamp.'
  else
    blocked 'The code signature has no secure timestamp.'
  fi
  if xcrun stapler validate -q "$APP_PATH" >/dev/null 2>&1; then
    passed 'The notarization ticket is stapled and validates.'
  else
    blocked 'The app has no validated stapled notarization ticket.'
  fi
  if spctl --assess --type execute "$APP_PATH" >/dev/null 2>&1; then
    passed 'Gatekeeper accepts the app.'
  else
    blocked 'Gatekeeper rejects the app.'
  fi
fi

if [[ "$BLOCKED" -eq 0 ]]; then
  printf 'PASS: public macOS release readiness gate\n'
else
  printf 'BLOCKED: public macOS release readiness gate\n'
fi
exit "$BLOCKED"
