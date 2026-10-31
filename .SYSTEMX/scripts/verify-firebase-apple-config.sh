#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXPECTED_BUNDLE_ID="com.waynetechlab.csa-iem"
EXPECTED_PROJECT_ID="csa-ilem"
DESTINATION="$ROOT_DIR/GoogleService-Info.plist"

usage() {
  cat <<'EOF'
Verify or import the Firebase Apple client configuration for CSA-iLEM.

Usage:
  .SYSTEMX/scripts/verify-firebase-apple-config.sh
  .SYSTEMX/scripts/verify-firebase-apple-config.sh /path/to/GoogleService-Info.plist
  .SYSTEMX/scripts/verify-firebase-apple-config.sh --import /path/to/GoogleService-Info.plist

The verifier checks required fields without printing their values. Import is an
explicit, atomic copy into the repository root using Firebase's standard name.
EOF
}

validate_configuration() {
  local configuration_path="$1"

  if [[ ! -f "$configuration_path" || -L "$configuration_path" ]]; then
    echo "FAIL: Firebase Apple configuration must be a regular, non-symlink file." >&2
    return 1
  fi
  if ! plutil -lint "$configuration_path" >/dev/null; then
    echo "FAIL: Firebase Apple configuration is not a valid property list." >&2
    return 1
  fi

  local required_field
  for required_field in API_KEY BUNDLE_ID GCM_SENDER_ID GOOGLE_APP_ID PROJECT_ID; do
    if ! /usr/libexec/PlistBuddy -c "Print :$required_field" "$configuration_path" 2>/dev/null \
      | grep -q '[^[:space:]]'; then
      echo "FAIL: Firebase Apple configuration is missing required field $required_field." >&2
      return 1
    fi
  done

  local bundle_id project_id
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$configuration_path" 2>/dev/null)"
  project_id="$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$configuration_path" 2>/dev/null)"
  if [[ "$bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
    echo "FAIL: Firebase Apple bundle identifier does not match CSA-iLEM." >&2
    return 1
  fi
  if [[ "$project_id" != "$EXPECTED_PROJECT_ID" ]]; then
    echo "FAIL: Firebase project identifier does not match CSA-iLEM." >&2
    return 1
  fi

  echo "PASS: Firebase Apple client configuration matches CSA-iLEM; client field values were not displayed."
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --import)
    if [[ "$#" -ne 2 ]]; then
      usage >&2
      exit 2
    fi
    validate_configuration "$2"
    temporary_file="$(mktemp "$ROOT_DIR/.GoogleService-Info.plist.XXXXXX")"
    trap 'rm -f -- "$temporary_file"' EXIT
    install -m 0644 "$2" "$temporary_file"
    mv -f -- "$temporary_file" "$DESTINATION"
    trap - EXIT
    validate_configuration "$DESTINATION"
    echo "PASS: imported Firebase Apple configuration into the native CSA-iLEM checkout."
    ;;
  "")
    validate_configuration "$DESTINATION"
    ;;
  *)
    if [[ "$#" -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    validate_configuration "$1"
    ;;
esac
