#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CSA-iEM"
APP_VENDOR="Wayne Tech Lab LLC"
APP_URL="https://www.WayneTechLab.com"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.3.0')"
INSTALL_ROOT="${CSA_IEM_INSTALL_ROOT:-${CSA_ILEM_INSTALL_ROOT:-$HOME/.local/share/csa-iem}}"
BIN_DIR="${CSA_IEM_BIN_DIR:-${CSA_ILEM_BIN_DIR:-$HOME/.local/bin}}"
INSTALL_DIR=""
UPDATE_SHELL_PROFILE=1
FORCE_INSTALL=0
BOOTSTRAP_DEPS=1

FILES=(
  "VERSION"
  "README.md"
  "LICENSE.txt"
  "NOTICE.md"
  "TERMS-OF-SERVICE.md"
  "PRIVACY-NOTICE.md"
  "DISCLAIMER.md"
  "CHANGELOG.md"
  "STATUS.md"
  "SECURITY.md"
  "PROJECT-INFO.md"
  "SHA256SUMS"
  "Package.swift"
  "install-remote.sh"
  "CSA-iEM.ps1"
  "install.ps1"
  "install-remote.ps1"
  "uninstall.ps1"
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
  ./install.sh --no-deps
  ./install.sh --force

Defaults:
  install root: $INSTALL_ROOT
  bin dir: $BIN_DIR

Cross-platform note:
  Windows 11 admin-shell installers also ship in this repo:
    install.ps1
    install-remote.ps1
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

confirm() {
  local prompt="${1:-Continue?}"
  local answer=""

  if [[ ! -t 0 ]]; then
    return 0
  fi

  read -r -p "$prompt [Y/n]: " answer
  case "$answer" in
    ""|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_profile_line() {
  local file_path="$1"
  local line="$2"

  touch "$file_path"
  if ! grep -Fq "$line" "$file_path"; then
    printf '%s\n' "$line" >> "$file_path"
  fi
}

build_path_export_line() {
  local bin_path="$1"
  local escaped=""

  if [[ "$bin_path" == "$HOME" ]]; then
    printf '%s' 'export PATH="$HOME:$PATH"'
    return
  fi

  if [[ "$bin_path" == "$HOME/"* ]]; then
    local suffix="${bin_path#$HOME}"
    suffix="${suffix//\\/\\\\}"
    suffix="${suffix//\"/\\\"}"
    printf 'export PATH="$HOME%s:$PATH"' "$suffix"
    return
  fi

  escaped="${bin_path//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf 'export PATH="%s:$PATH"' "$escaped"
}

detect_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '/opt/homebrew/bin/brew\n'
    return
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    printf '/usr/local/bin/brew\n'
    return
  fi
}

activate_brew_shellenv() {
  local brew_bin=""
  brew_bin="$(detect_brew_bin || true)"
  if [[ -n "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
  fi
}

ensure_xcode_command_line_tools() {
  if xcode-select -p >/dev/null 2>&1 && command -v xcodebuild >/dev/null 2>&1; then
    info "Xcode Command Line Tools are available."
    return 0
  fi

  warn "Xcode Command Line Tools were not detected."
  if ! confirm "Trigger the macOS Command Line Tools installer now?"; then
    warn "Skipping Command Line Tools bootstrap."
    return 1
  fi

  xcode-select --install >/dev/null 2>&1 || true
  warn "Finish the Apple Command Line Tools install if macOS prompts you, then rerun the installer if Swift-based GUI build support is still missing."
  return 1
}

install_homebrew_if_missing() {
  if command -v brew >/dev/null 2>&1 || [[ -n "$(detect_brew_bin || true)" ]]; then
    activate_brew_shellenv
    info "Homebrew is available."
    return 0
  fi

  warn "Homebrew was not detected."
  if ! confirm "Install Homebrew now?"; then
    warn "Skipping Homebrew install. Automatic dependency bootstrap will be limited."
    return 1
  fi

  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  activate_brew_shellenv
  info "Homebrew installed."
}

brew_install_formula_if_missing() {
  local formula="$1"
  local binary="$2"
  local label="$3"

  if command -v "$binary" >/dev/null 2>&1; then
    info "$label is already available."
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    warn "Cannot install $label automatically because Homebrew is not available."
    return 1
  fi

  info "Installing $label with Homebrew..."
  brew install "$formula"
  activate_brew_shellenv
}

brew_install_cask_if_missing() {
  local cask="$1"
  local app_path="$2"
  local label="$3"

  if [[ -d "$app_path" ]]; then
    info "$label is already installed."
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    warn "Cannot install $label automatically because Homebrew is not available."
    return 1
  fi

  if ! confirm "Install $label now?"; then
    warn "Skipping $label install."
    return 1
  fi

  info "Installing $label with Homebrew..."
  brew install --cask "$cask"
}

link_tool_from_app_if_missing() {
  local tool_name="$1"
  local source_path="$2"
  local target_path="$BIN_DIR/$tool_name"

  if command -v "$tool_name" >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x "$source_path" ]]; then
    mkdir -p "$BIN_DIR"
    ln -sfn "$source_path" "$target_path"
    info "Linked $tool_name into $BIN_DIR."
  fi
}

ensure_devcontainer_cli() {
  if command -v devcontainer >/dev/null 2>&1; then
    info "Dev Containers CLI is already available."
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm is not available, so Dev Containers CLI could not be installed automatically."
    return 1
  fi

  info "Installing Dev Containers CLI with npm..."
  npm install -g @devcontainers/cli
}

bootstrap_dependencies() {
  local vscode_cli=""
  local docker_cli=""

  echo
  info "Checking Mac dependencies..."

  ensure_xcode_command_line_tools || true
  install_homebrew_if_missing || true
  activate_brew_shellenv

  brew_install_formula_if_missing git git "git" || true
  brew_install_formula_if_missing gh gh "GitHub CLI" || true
  brew_install_formula_if_missing node node "Node.js" || true

  if ! command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    activate_brew_shellenv
  fi

  ensure_devcontainer_cli || true

  brew_install_cask_if_missing visual-studio-code "/Applications/Visual Studio Code.app" "Visual Studio Code" || true
  vscode_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  link_tool_from_app_if_missing code "$vscode_cli"

  brew_install_cask_if_missing docker "/Applications/Docker.app" "Docker Desktop" || true
  docker_cli="/Applications/Docker.app/Contents/Resources/bin/docker"
  link_tool_from_app_if_missing docker "$docker_cli"

  if ! command -v swift >/dev/null 2>&1; then
    warn "Swift is still not available. The CLI is installed, but GUI builds will need Xcode Command Line Tools or Xcode."
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
    --no-deps)
      BOOTSTRAP_DEPS=0
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

if [[ "$BOOTSTRAP_DEPS" -eq 1 ]]; then
  bootstrap_dependencies
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
  ensure_profile_line "$HOME/.zprofile" "$(build_path_export_line "$BIN_DIR")"
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
echo "Primary commands:"
printf '  %s\n' "csa-iem" "csa-iem-gui" "csa-iem-build-gui" "csa-iem-open" "openproj"
echo
echo "Advanced compatibility commands:"
printf '  %s\n' \
  "csa-iem-public" "csa-iem-wtl" "csa-iem-diamond" \
  "csa-ilem" "csa-ilem-public" "csa-ilem-wtl" "csa-ilem-diamond" \
  "csa-ilem-open" "csa-ilem-gui" "csa-ilem-build-gui"
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
