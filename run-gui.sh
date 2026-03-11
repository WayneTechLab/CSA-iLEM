#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE_PATH" ]]; do
  SOURCE_DIR="$(cd -P -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
  SOURCE_PATH="$(readlink "$SOURCE_PATH")"
  [[ "$SOURCE_PATH" != /* ]] && SOURCE_PATH="$SOURCE_DIR/$SOURCE_PATH"
done
SCRIPT_DIR="$(cd -P -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
APP_NAME="CSA-iEM"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.2.1')"
SCRATCH_ID="$(printf '%s' "$SCRIPT_DIR" | shasum | awk '{print $1}')"
SCRATCH_PATH="${CSA_IEM_SCRATCH_PATH:-${TMPDIR:-/tmp}/csa-iem-swiftpm-$SCRATCH_ID}"

print_help() {
  cat <<EOF
$APP_NAME GUI runner
Version: $APP_VERSION

Usage:
  ./run-gui.sh
  ./run-gui.sh --version
  ./run-gui.sh --help

Environment:
  CSA_IEM_SCRATCH_PATH   Override the SwiftPM scratch directory.
  CSA_IEM_ROOT           Override the source or install root used by the GUI.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --version)
      printf '%s %s\n' "$APP_NAME" "$APP_VERSION"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "$APP_NAME GUI runs are supported only on macOS." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is required to run the $APP_NAME GUI from source or an installed bundle." >&2
  echo "Install Xcode Command Line Tools or Xcode, then try again." >&2
  exit 1
fi

export CSA_IEM_ROOT="${CSA_IEM_ROOT:-$SCRIPT_DIR}"
swift run --scratch-path "$SCRATCH_PATH" --package-path "$SCRIPT_DIR" CSAiEMMacApp
