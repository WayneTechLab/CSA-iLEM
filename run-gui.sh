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
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.3.0')"
APP_DIR="$SCRIPT_DIR/dist/$APP_NAME.app"
BUILD_GUI_SCRIPT="$SCRIPT_DIR/build-gui-app.sh"
BUILD_LOG="${TMPDIR:-/tmp}/csa-iem-gui-build.log"
FORCE_REBUILD=0
SOURCE_RUN=0

print_help() {
  cat <<EOF
$APP_NAME GUI runner
Version: $APP_VERSION

Usage:
  ./run-gui.sh
  ./run-gui.sh --rebuild
  ./run-gui.sh --source-run
  ./run-gui.sh --version
  ./run-gui.sh --help

Environment:
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
    --rebuild)
      FORCE_REBUILD=1
      ;;
    --source-run)
      SOURCE_RUN=1
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

export CSA_IEM_ROOT="${CSA_IEM_ROOT:-$SCRIPT_DIR}"

if [[ "$SOURCE_RUN" -eq 1 ]]; then
  SCRATCH_ID="$(printf '%s' "$SCRIPT_DIR" | shasum | awk '{print $1}')"
  SCRATCH_PATH="${CSA_IEM_SCRATCH_PATH:-${TMPDIR:-/tmp}/csa-iem-swiftpm-$SCRATCH_ID}"

  if ! command -v swift >/dev/null 2>&1; then
    echo "Swift is required to run the $APP_NAME GUI from source." >&2
    echo "Install Xcode Command Line Tools or Xcode, then try again." >&2
    exit 1
  fi

  exec swift run --scratch-path "$SCRATCH_PATH" --package-path "$SCRIPT_DIR" CSAiEMMacApp
fi

if [[ "$FORCE_REBUILD" -eq 1 || ! -d "$APP_DIR" ]]; then
  if [[ ! -x "$BUILD_GUI_SCRIPT" ]]; then
    echo "GUI builder not found: $BUILD_GUI_SCRIPT" >&2
    exit 1
  fi
  echo "Preparing native $APP_NAME app bundle..."
  if ! "$BUILD_GUI_SCRIPT" >"$BUILD_LOG" 2>&1; then
    echo "GUI bundle build failed. See log: $BUILD_LOG" >&2
    tail -n 40 "$BUILD_LOG" >&2 || true
    exit 1
  fi
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "Native app bundle was not created: $APP_DIR" >&2
  exit 1
fi

exec open "$APP_DIR"
