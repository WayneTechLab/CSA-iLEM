#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CSA-iEM"
APP_VENDOR="Wayne Tech Lab LLC"
APP_URL="https://www.WayneTechLab.com"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.0.14')"
INSTALL_ROOT="${CSA_IEM_INSTALL_ROOT:-${CSA_ILEM_INSTALL_ROOT:-$HOME/.local/share/csa-iem}}"
BIN_DIR="${CSA_IEM_BIN_DIR:-${CSA_ILEM_BIN_DIR:-$HOME/.local/bin}}"
INSTALL_DIR=""
UPDATE_SHELL_PROFILE=1
FORCE_INSTALL=0

FILES=(
  "VERSION"
  "README.md"
  "LICENSE.txt"
  "NOTICE.md"
  "TERMS-OF-SERVICE.md"
  "PRIVACY-NOTICE.md"
  "DISCLAIMER.md"
  "CHANGELOG.md"
  "SECURITY.md"
  "PROJECT-INFO.md"
  "Package.swift"
  "install-remote.sh"
  "CSA-iLEM.sh"
  "CSA-iLEM-Public.sh"
  "CSA-iLEM-WTL.sh"
  "CSA-iLEM-Diamond.sh"
  "CSA-iLEM-Open.sh"
  "build-gui-app.sh"
  "run-gui.sh"
  "openproj"
  "csa-iem-gui"
  "csa-iem-build-gui"
  "csa-iem"
  "csa-iem-public"
  "csa-iem-wtl"
  "csa-iem-diamond"
  "csa-iem-open"
  "csa-ilem-gui"
  "csa-ilem-build-gui"
  "csa-ilem"
  "csa-ilem-public"
  "csa-ilem-wtl"
  "csa-ilem-diamond"
  "csa-ilem-open"
  "install.sh"
  "uninstall.sh"
)

DIRS=(
  "Sources"
  "assets"
  "docs"
)

COMMANDS=(
  "csa-iem"
  "csa-iem-public"
  "csa-iem-wtl"
  "csa-iem-diamond"
  "csa-iem-open"
  "csa-iem-gui"
  "csa-iem-build-gui"
  "csa-ilem"
  "csa-ilem-public"
  "csa-ilem-wtl"
  "csa-ilem-diamond"
  "csa-ilem-open"
  "csa-ilem-gui"
  "csa-ilem-build-gui"
  "openproj"
)

print_help() {
  cat <<EOF
$APP_NAME installer
Version: $APP_VERSION
Provider: $APP_VENDOR
Website: $APP_URL

Usage:
  ./install.sh
  ./install.sh --install-root <dir>
  ./install.sh --bin-dir <dir>
  ./install.sh --no-shell-profile
  ./install.sh --force

Defaults:
  install root: $INSTALL_ROOT
  bin dir: $BIN_DIR
EOF
}

ensure_profile_line() {
  local file_path="$1"
  local line="$2"

  touch "$file_path"
  if ! grep -Fq "$line" "$file_path"; then
    printf '%s\n' "$line" >> "$file_path"
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --install-root)
      shift
      INSTALL_ROOT="$1"
      ;;
    --bin-dir)
      shift
      BIN_DIR="$1"
      ;;
    --no-shell-profile)
      UPDATE_SHELL_PROFILE=0
      ;;
    --force)
      FORCE_INSTALL=1
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s installs are supported only on macOS.\n' "$APP_NAME" >&2
  exit 1
fi

INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

if [[ -d "$INSTALL_DIR" && "$FORCE_INSTALL" -eq 1 ]]; then
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

for file_name in "${FILES[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$file_name" ]]; then
    printf 'Missing install file: %s\n' "$file_name" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$INSTALL_DIR/$file_name")"
  cp -f "$SCRIPT_DIR/$file_name" "$INSTALL_DIR/$file_name"
done

for dir_name in "${DIRS[@]}"; do
  if [[ ! -d "$SCRIPT_DIR/$dir_name" ]]; then
    printf 'Missing install directory: %s\n' "$dir_name" >&2
    exit 1
  fi
  rm -rf "$INSTALL_DIR/$dir_name"
  mkdir -p "$(dirname "$INSTALL_DIR/$dir_name")"
  cp -R "$SCRIPT_DIR/$dir_name" "$INSTALL_DIR/$dir_name"
done

chmod +x \
  "$INSTALL_DIR/CSA-iLEM.sh" \
  "$INSTALL_DIR/CSA-iLEM-Public.sh" \
  "$INSTALL_DIR/CSA-iLEM-WTL.sh" \
  "$INSTALL_DIR/CSA-iLEM-Diamond.sh" \
  "$INSTALL_DIR/CSA-iLEM-Open.sh" \
  "$INSTALL_DIR/build-gui-app.sh" \
  "$INSTALL_DIR/run-gui.sh" \
  "$INSTALL_DIR/openproj" \
  "$INSTALL_DIR/csa-iem-gui" \
  "$INSTALL_DIR/csa-iem-build-gui" \
  "$INSTALL_DIR/csa-iem" \
  "$INSTALL_DIR/csa-iem-public" \
  "$INSTALL_DIR/csa-iem-wtl" \
  "$INSTALL_DIR/csa-iem-diamond" \
  "$INSTALL_DIR/csa-iem-open" \
  "$INSTALL_DIR/csa-ilem-gui" \
  "$INSTALL_DIR/csa-ilem-build-gui" \
  "$INSTALL_DIR/csa-ilem" \
  "$INSTALL_DIR/csa-ilem-public" \
  "$INSTALL_DIR/csa-ilem-wtl" \
  "$INSTALL_DIR/csa-ilem-diamond" \
  "$INSTALL_DIR/csa-ilem-open" \
  "$INSTALL_DIR/install-remote.sh" \
  "$INSTALL_DIR/install.sh" \
  "$INSTALL_DIR/uninstall.sh"

ln -sfn "$INSTALL_DIR" "$INSTALL_ROOT/current"

for command_name in "${COMMANDS[@]}"; do
  ln -sfn "$INSTALL_DIR/$command_name" "$BIN_DIR/$command_name"
done

if [[ "$UPDATE_SHELL_PROFILE" -eq 1 ]]; then
  ensure_profile_line "$HOME/.zprofile" 'export PATH="$HOME/.local/bin:$PATH"'
fi

echo
printf '%s %s installed.\n' "$APP_NAME" "$APP_VERSION"
printf 'Provider: %s\n' "$APP_VENDOR"
printf 'Website: %s\n' "$APP_URL"
printf 'Install dir: %s\n' "$INSTALL_DIR"
printf 'Command dir: %s\n' "$BIN_DIR"
echo
if ! command -v swift >/dev/null 2>&1; then
  echo "GUI note:"
  echo "  Swift was not found in PATH."
  echo "  Install Xcode Command Line Tools or Xcode before using csa-iem-gui or csa-iem-build-gui."
  echo
fi
echo "Available commands:"
for command_name in "${COMMANDS[@]}"; do
  printf '  %s\n' "$command_name"
done
echo
if [[ "$UPDATE_SHELL_PROFILE" -eq 1 ]]; then
  echo "Run this in a new shell or now in the current one:"
  echo '  source ~/.zprofile'
fi
echo
echo "Then verify:"
echo "  csa-iem --version"
echo
echo "Install or update from any supported Mac terminal:"
echo "  curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash"
echo "  curl -fsSL https://raw.githubusercontent.com/WayneTechLab/CSA-iLEM/main/install-remote.sh | bash -s -- --force"
echo
echo "Installed remote installer:"
echo "  $INSTALL_DIR/install-remote.sh --help"
