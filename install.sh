#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CSA-iEM"
APP_BUNDLE_IDENTIFIER="com.waynetechlab.csa-iem"
APP_VENDOR="Wayne Tech Lab LLC"
APP_URL="https://www.WayneTechLab.com"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.0.0')"
INSTALL_RECEIPT_NAME=".csa-iem-install-receipt"
INSTALL_ROOT="${CSA_IEM_INSTALL_ROOT:-${CSA_ILEM_INSTALL_ROOT:-$HOME/.local/share/csa-iem}}"
BIN_DIR="${CSA_IEM_BIN_DIR:-${CSA_ILEM_BIN_DIR:-$HOME/.local/bin}}"
DEVCONTAINER_NPM_PREFIX="${CSA_IEM_NPM_PREFIX:-${CSA_ILEM_NPM_PREFIX:-$HOME/.local/share/csa-iem/npm}}"
APP_INSTALL_DIR_OVERRIDE="${CSA_IEM_APP_INSTALL_DIR:-}"
DISABLE_LOGIN_TOOLBAR="${CSA_IEM_DISABLE_LOGIN_TOOLBAR:-0}"
DISABLE_PROCESS_STOP="${CSA_IEM_DISABLE_PROCESS_STOP:-0}"
INSTALL_DIR=""
INSTALL_ROLLBACK_DIR=""
INSTALL_ROLLBACK_KIND=""
STAGED_INSTALL_DIR=""
UPDATE_SHELL_PROFILE=1
FORCE_INSTALL=1
BOOTSTRAP_DEPS=1
INSTALL_GUI_APP=1
OPEN_GUI_APP=1

FILES=(
  ".gitignore"
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
  "Prompt_Inject.MD"
  "Transfer_Note.MD"
  "SHA256SUMS"
  "Package.swift"
  "Package.resolved"
  "GoogleService-Info.plist"
  "install-remote.sh"
  "CSA-iEM.ps1"
  "stage2-workspace.ps1"
  "stage3-cleanup.ps1"
  "install.ps1"
  "csa-iem-tray.ps1"
  "install-remote.ps1"
  "update-win.ps1"
  "uninstall.ps1"
  "CSA-iLEM.sh"
  "stage2-workspace.sh"
  "stage3-cleanup.sh"
  "repo-consolidation-recovery.py"
  "repo-consolidation-local-cleanup.py"
  "CSA-iLEM-Open.sh"
  "build-gui-app.sh"
  "run-gui.sh"
  "openproj"
  "csa-iem-gui"
  "csa-iem-build-gui"
  "csa-iem"
  "csa-iem-update"
  "csa-iem-open"
  "csa-ilem-gui"
  "csa-ilem-build-gui"
  "csa-ilem"
  "csa-ilem-update"
  "csa-ilem-open"
  "install.sh"
  "uninstall.sh"
)

DIRS=(
  ".SYSTEMX"
  ".devcontainer"
  ".github"
  ".vscode"
  "Sources"
  "Tests"
  "assets"
  "docs"
)

COMMANDS=(
  "csa-iem"
  "csa-iem-update"
  "csa-iem-open"
  "csa-iem-gui"
  "csa-iem-build-gui"
  "csa-ilem"
  "csa-ilem-update"
  "csa-ilem-open"
  "csa-ilem-gui"
  "csa-ilem-build-gui"
  "openproj"
)

COMMAND_ALIAS_LINES=(
  'alias CSA-IEM="csa-iem"'
  'alias CSA-iEM="csa-iem"'
  'alias CSA-ILEM="csa-ilem"'
  'alias CSA-iLEM="csa-ilem"'
)

print_help() {
  cat <<EOF
$APP_NAME installer
Version: $APP_VERSION
Provider: $APP_VENDOR
Website: $APP_URL

Usage:
  # macOS Terminal (zsh / bash)
  ./install.sh
  ./install.sh --install-root <dir>
  ./install.sh --bin-dir <dir>
  ./install.sh --no-shell-profile
  ./install.sh --no-deps
  ./install.sh --no-gui-app
  ./install.sh --no-open
  ./install.sh --force

Defaults:
  install root: $INSTALL_ROOT
  bin dir: $BIN_DIR

Install behavior:
  Installs and updates replace the target version by default, update the
  current symlink, and remove older version folders from the install root.
  On macOS, the installer builds and installs one canonical
  /Applications/CSA-iEM.app, preserves other app copies for review, starts
  the canonical app, and registers it to launch at login.

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

validate_install_root() {
  local path_part=""
  local parts=()
  local home_physical=""

  if [[ "$INSTALL_ROOT" != /* || "$INSTALL_ROOT" == "/" || "$INSTALL_ROOT" == "$HOME" ]]; then
    printf 'Unsafe install root: %s\n' "$INSTALL_ROOT" >&2
    return 1
  fi
  IFS='/' read -r -a parts <<< "$INSTALL_ROOT"
  for path_part in "${parts[@]}"; do
    [[ -n "$path_part" ]] || continue
    if [[ "$path_part" == "." || "$path_part" == ".." ]]; then
      printf 'Install root must not contain dot path components: %s\n' "$INSTALL_ROOT" >&2
      return 1
    fi
  done

  if [[ -L "$INSTALL_ROOT" ]]; then
    printf 'Install root itself must not be a symlink: %s\n' "$INSTALL_ROOT" >&2
    return 1
  fi

  mkdir -p -- "$INSTALL_ROOT"
  INSTALL_ROOT="$(cd -P -- "$INSTALL_ROOT" && pwd)"
  home_physical="$(cd -P -- "$HOME" && pwd)"
  case "$home_physical" in
    "$INSTALL_ROOT"|"$INSTALL_ROOT"/*)
      printf 'Install root cannot contain the home directory: %s\n' "$INSTALL_ROOT" >&2
      return 1
      ;;
  esac
  case "$INSTALL_ROOT" in
    /Applications|/Library|/System|/Users|/Volumes|/private|/usr|/bin|/sbin|/etc|/tmp|/var)
      printf 'Install root is a protected system directory: %s\n' "$INSTALL_ROOT" >&2
      return 1
      ;;
  esac
}

is_on_parent_device() {
  local candidate="$1"
  local candidate_device=""
  local parent_device=""
  candidate_device="$(stat -f %d "$candidate" 2>/dev/null)" || return 1
  parent_device="$(stat -f %d "$(dirname -- "$candidate")" 2>/dev/null)" || return 1
  [[ -n "$candidate_device" && "$candidate_device" == "$parent_device" ]]
}

physical_existing_path() {
  local candidate="$1"
  local parent=""
  [[ -e "$candidate" || -L "$candidate" ]] || return 1
  parent="$(cd -P -- "$(dirname -- "$candidate")" && pwd)" || return 1
  printf '%s/%s\n' "$parent" "$(basename -- "$candidate")"
}

is_owned_install_version() {
  local candidate="$1"
  local expected_version="$2"
  local receipt="$candidate/$INSTALL_RECEIPT_NAME"

  [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
  is_on_parent_device "$candidate" || return 1
  [[ -f "$receipt" && ! -L "$receipt" ]] || return 1
  [[ "$(cat -- "$receipt")" == "$APP_BUNDLE_IDENTIFIER|$expected_version" ]] || return 1
  [[ -f "$candidate/VERSION" && "$(sed -n '1p' "$candidate/VERSION")" == "$expected_version" ]] || return 1
  [[ -f "$candidate/install.sh" && -f "$candidate/csa-iem" && -f "$candidate/SHA256SUMS" ]] || return 1
}

is_legacy_install_version() {
  local candidate="$1"
  local expected_version="$2"

  [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
  is_on_parent_device "$candidate" || return 1
  [[ ! -e "$candidate/$INSTALL_RECEIPT_NAME" && ! -L "$candidate/$INSTALL_RECEIPT_NAME" ]] || return 1
  [[ -f "$candidate/VERSION" && "$(sed -n '1p' "$candidate/VERSION")" == "$expected_version" ]] || return 1
  [[ -f "$candidate/install.sh" && -f "$candidate/csa-iem" && -f "$candidate/SHA256SUMS" ]] || return 1
}

prepare_current_install_version() {
  local preserved=""

  [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]] || return 0
  if is_owned_install_version "$INSTALL_DIR" "$APP_VERSION"; then
    preserved="$INSTALL_ROOT/.csa-iem-install-rollback-$APP_VERSION-$(uuidgen)"
    mv -- "$INSTALL_DIR" "$preserved" || return 1
    INSTALL_ROLLBACK_DIR="$preserved"
    INSTALL_ROLLBACK_KIND="managed"
    return 0
  fi
  if is_legacy_install_version "$INSTALL_DIR" "$APP_VERSION"; then
    preserved="$INSTALL_ROOT/.csa-iem-preserved-$APP_VERSION-$(uuidgen)"
    mv -- "$INSTALL_DIR" "$preserved" || return 1
    INSTALL_ROLLBACK_DIR="$preserved"
    INSTALL_ROLLBACK_KIND="legacy"
    return 0
  fi
  printf 'Refusing to replace unrecognized install-root entry: %s\n' "$INSTALL_DIR" >&2
  return 1
}

verify_staged_install() {
  local staged="$1"
  is_owned_install_version "$staged" "$APP_VERSION" || return 1
  (cd "$staged" && shasum -a 256 -c --strict SHA256SUMS >/dev/null)
}

rollback_current_install_version() {
  local failed=""

  if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
    if ! is_owned_install_version "$INSTALL_DIR" "$APP_VERSION"; then
      printf 'Refusing to overwrite an unexpected install during rollback: %s\n' "$INSTALL_DIR" >&2
      return 1
    fi
    failed="$INSTALL_ROOT/.csa-iem-install-failed-$APP_VERSION-$(uuidgen)"
    mv -- "$INSTALL_DIR" "$failed" || return 1
    warn "Preserved failed replacement for review: $failed"
  fi
  if [[ -n "$INSTALL_ROLLBACK_DIR" ]]; then
    mv -- "$INSTALL_ROLLBACK_DIR" "$INSTALL_DIR" || return 1
    INSTALL_ROLLBACK_DIR=""
    INSTALL_ROLLBACK_KIND=""
  fi
}

finalize_prior_install_version() {
  [[ -n "$INSTALL_ROLLBACK_DIR" ]] || return 0
  if [[ "$INSTALL_ROLLBACK_KIND" == "legacy" ]]; then
    warn "Preserved legacy unmarked version instead of deleting it: $INSTALL_ROLLBACK_DIR"
    return 0
  fi
  if ! is_owned_install_version "$INSTALL_ROLLBACK_DIR" "$APP_VERSION"; then
    warn "Retained prior version with unverified receipt: $INSTALL_ROLLBACK_DIR"
    return 1
  fi
  if has_nested_install_tree_app_bundle "$INSTALL_ROLLBACK_DIR"; then
    warn "Retained prior version because it contains a nested GUI bundle: $INSTALL_ROLLBACK_DIR"
    return 0
  fi
  rm -rfx -- "$INSTALL_ROLLBACK_DIR"
  if [[ -e "$INSTALL_ROLLBACK_DIR" || -L "$INSTALL_ROLLBACK_DIR" ]]; then
    warn "Prior version still contains files and needs review: $INSTALL_ROLLBACK_DIR"
    return 1
  fi
  INSTALL_ROLLBACK_DIR=""
  INSTALL_ROLLBACK_KIND=""
}

write_install_receipt() {
  printf '%s|%s\n' "$APP_BUNDLE_IDENTIFIER" "$APP_VERSION" > "$INSTALL_DIR/$INSTALL_RECEIPT_NAME"
}

validate_current_install_link() {
  local current="$INSTALL_ROOT/current"
  local target=""
  local target_version=""

  [[ -e "$current" || -L "$current" ]] || return 0
  if [[ ! -L "$current" ]]; then
    printf 'Refusing to replace unrelated current entry: %s\n' "$current" >&2
    return 1
  fi
  target="$(readlink "$current")"
  target="$(physical_existing_path "$target")" || {
    printf 'Refusing to replace dangling current link: %s\n' "$current" >&2
    return 1
  }
  case "$target" in
    "$INSTALL_ROOT"/*) ;;
    *) printf 'Refusing to replace external current link: %s\n' "$current" >&2; return 1 ;;
  esac
  target_version="$(basename -- "$target")"
  if ! is_owned_install_version "$target" "$target_version" \
    && ! is_legacy_install_version "$target" "$target_version"; then
    printf 'Refusing to replace unrecognized current link: %s\n' "$current" >&2
    return 1
  fi
}

validate_command_links() {
  local command_name=""
  local link_path=""
  local target=""
  local version_path=""
  local version_name=""

  if [[ "$BIN_DIR" != /* || -L "$BIN_DIR" ]]; then
    printf 'Unsafe command directory: %s\n' "$BIN_DIR" >&2
    return 1
  fi
  mkdir -p -- "$BIN_DIR"
  BIN_DIR="$(cd -P -- "$BIN_DIR" && pwd)"
  for command_name in "${COMMANDS[@]}"; do
    link_path="$BIN_DIR/$command_name"
    [[ -e "$link_path" || -L "$link_path" ]] || continue
    if [[ ! -L "$link_path" ]]; then
      printf 'Refusing to replace unrelated command file: %s\n' "$link_path" >&2
      return 1
    fi
    target="$(readlink "$link_path")"
    target="$(physical_existing_path "$target")" || {
      printf 'Refusing to replace dangling command link: %s\n' "$link_path" >&2
      return 1
    }
    case "$target" in
      "$INSTALL_ROOT"/*/"$command_name") ;;
      *) printf 'Refusing to replace external command link: %s\n' "$link_path" >&2; return 1 ;;
    esac
    version_path="$(dirname -- "$target")"
    version_name="$(basename -- "$version_path")"
    if ! is_owned_install_version "$version_path" "$version_name" \
      && ! is_legacy_install_version "$version_path" "$version_name"; then
      printf 'Refusing to replace unrecognized command link: %s\n' "$link_path" >&2
      return 1
    fi
  done
}

cleanup_old_install_versions() {
  local candidate=""
  local candidate_version=""

  while IFS= read -r -d '' candidate; do
    candidate_version="$(basename -- "$candidate")"
    [[ "$candidate_version" == "$APP_VERSION" || "$candidate_version" == "npm" || "$candidate_version" == "Recovery" ]] && continue
    if ! is_owned_install_version "$candidate" "$candidate_version"; then
      warn "Retained unrecognized install-root directory: $candidate"
      continue
    fi
    if has_nested_install_tree_app_bundle "$candidate"; then
      warn "Retained install-root directory with a nested GUI bundle: $candidate"
      continue
    fi
    rm -rfx -- "$candidate"
    if [[ -e "$candidate" || -L "$candidate" ]]; then
      warn "Prior verified install still contains files and needs review: $candidate"
    else
      info "Removed prior verified CSA-iEM install: $candidate"
    fi
  done < <(find "$INSTALL_ROOT" -mindepth 1 -maxdepth 1 -type d -print0)
}

is_owned_app_bundle() {
  local candidate="$1"
  local info_plist="$candidate/Contents/Info.plist"
  local bundle_id=""

  [[ -d "$candidate" && ! -L "$candidate" && -f "$info_plist" ]] || return 1
  is_on_parent_device "$candidate" || return 1
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist" 2>/dev/null || true)"
  [[ "$bundle_id" == "$APP_BUNDLE_IDENTIFIER" ]]
}

has_nested_install_tree_app_bundle() {
  local candidate="$1/dist/$APP_NAME.app"
  [[ -e "$candidate" || -L "$candidate" ]]
}

confirm() {
  local prompt="${1:-Continue?}"
  local answer=""

  if [[ ! -t 0 ]]; then
    return 0
  fi

  if [[ "${CSA_IEM_AUTO_CONFIRM_TERMINAL_GATES:-0}" == "1" ]]; then
    info "Auto-confirm terminal gate: yes -> $prompt"
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

ensure_profile_lines() {
  local file_path="$1"
  shift || true
  local line=""

  for line in "$@"; do
    ensure_profile_line "$file_path" "$line"
  done
}

configure_shell_profiles() {
  local path_line="$1"
  shift || true
  local extra_lines=("$@")
  local shell_name=""

  ensure_profile_lines "$HOME/.profile" "$path_line" "${extra_lines[@]}"

  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh)
      ensure_profile_lines "$HOME/.zprofile" "$path_line" "${extra_lines[@]}"
      ensure_profile_lines "$HOME/.zshrc" "$path_line" "${extra_lines[@]}"
      ;;
    bash)
      ensure_profile_lines "$HOME/.bash_profile" "$path_line" "${extra_lines[@]}"
      ensure_profile_lines "$HOME/.bashrc" "$path_line" "${extra_lines[@]}"
      ;;
    *)
      ensure_profile_lines "$HOME/.zprofile" "$path_line" "${extra_lines[@]}"
      ensure_profile_lines "$HOME/.zshrc" "$path_line" "${extra_lines[@]}"
      ensure_profile_lines "$HOME/.bash_profile" "$path_line" "${extra_lines[@]}"
      ;;
  esac
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

default_app_install_dir() {
  if [[ -n "$APP_INSTALL_DIR_OVERRIDE" ]]; then
    printf '%s\n' "$APP_INSTALL_DIR_OVERRIDE"
    return
  fi

  if [[ -d /Applications && -w /Applications ]]; then
    printf '/Applications\n'
  else
    printf '%s\n' "$HOME/Applications"
  fi
}

remove_stale_gui_app_bundles() {
  local canonical_app="$1"
  local canonical_dir="$(dirname -- "$canonical_app")"
  local app_dir=""
  local candidate=""

  local app_dirs=()
  if [[ -n "$APP_INSTALL_DIR_OVERRIDE" ]]; then
    app_dirs=("$canonical_dir")
  else
    app_dirs=(/Applications "$HOME/Applications")
  fi

  # A matching bundle identifier does not prove that another app copy is an
  # abandoned installer artifact. Leave every other bundle available for the
  # owner's review, including backup names and copies in another app folder.
  for app_dir in "${app_dirs[@]}"; do
    [[ -d "$app_dir" ]] || continue
    while IFS= read -r -d '' candidate; do
      [[ "$candidate" == "$canonical_app" ]] && continue
      if is_owned_app_bundle "$candidate"; then
        warn "Preserved additional CSA-iEM app copy for review: $candidate"
      fi
    done < <(find "$app_dir" -maxdepth 1 \( -type d -o -type l \) -name '*.app' -print0)
  done
}

remove_legacy_install_tree_app_bundle() {
  local candidate="$INSTALL_DIR/dist/$APP_NAME.app"

  [[ -e "$candidate" || -L "$candidate" ]] || return 0
  warn "Preserved nested GUI bundle for review; a bundle identifier alone does not prove installer ownership: $candidate"
}

stop_running_gui_instances() {
  local target_app="$1"
  local expected_executable=""
  local pid=""
  local running=0
  local attempt=0

  if [[ "$DISABLE_PROCESS_STOP" == "1" ]]; then
    info "Skipping process stop (CSA_IEM_DISABLE_PROCESS_STOP=1)."
    return 0
  fi

  [[ -e "$target_app" || -L "$target_app" ]] || return 0
  is_owned_app_bundle "$target_app" || return 1
  expected_executable="$(physical_existing_path "$target_app")/Contents/MacOS/$APP_NAME" || return 1
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if [[ "$(process_executable_for_pid "$pid" || true)" == "$expected_executable" ]]; then
      /bin/kill -TERM "$pid" 2>/dev/null || true
    fi
  done < <(pgrep -x "$APP_NAME" || true)

  while true; do
    running=0
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      if [[ "$(process_executable_for_pid "$pid" || true)" == "$expected_executable" ]]; then
        running=1
      fi
    done < <(pgrep -x "$APP_NAME" || true)
    [[ "$running" -eq 1 ]] || return 0
    attempt=$((attempt + 1))
    if [[ "$attempt" -ge 20 ]]; then
      warn "Could not stop the running app at $target_app before replacement."
      return 1
    fi
    sleep 0.25
  done
}

process_executable_for_pid() {
  local pid="$1"
  local line=""
  while IFS= read -r line; do
    case "$line" in
      n/*) printf '%s\n' "${line#n}"; return 0 ;;
    esac
  done < <(/usr/sbin/lsof -a -p "$pid" -d txt -Fn 2>/dev/null || true)
  return 1
}

preserve_prior_gui_app_bundle() {
  local rollback_root="$1"
  local rollback_app="$2"
  local recovery_base="$INSTALL_ROOT/Recovery/InstalledApps"
  local recovery_slot=""
  local prior_identity=""
  local retained_app=""

  [[ -e "$rollback_app" || -L "$rollback_app" ]] || {
    rmdir -- "$rollback_root" >/dev/null 2>&1 || true
    return 0
  }
  if [[ -L "$INSTALL_ROOT/Recovery" || -L "$recovery_base" ]] \
    || [[ "$(stat -f %d "$rollback_app" 2>/dev/null)" != "$(stat -f %d "$INSTALL_ROOT" 2>/dev/null)" ]]; then
    warn "Prior GUI bundle remains in its same-volume rollback folder for review: $rollback_app"
    return 0
  fi
  if ! mkdir -p -- "$recovery_base"; then
    warn "Could not create app recovery storage; prior GUI bundle remains at $rollback_app"
    return 0
  fi
  recovery_slot="$recovery_base/$(uuidgen)"
  if ! mkdir -m 700 -- "$recovery_slot"; then
    warn "Could not reserve a unique app recovery folder; prior GUI bundle remains at $rollback_app"
    return 0
  fi
  retained_app="$recovery_slot/$APP_NAME.app"
  prior_identity="$(stat -f '%d:%i' "$rollback_app")"
  if mv -- "$rollback_app" "$retained_app" \
    && [[ "$prior_identity" == "$(stat -f '%d:%i' "$retained_app")" ]] \
    && is_owned_app_bundle "$retained_app"; then
    rmdir -- "$rollback_root" >/dev/null 2>&1 || true
    info "Preserved prior GUI bundle outside Applications: $retained_app"
    return 0
  fi
  warn "Prior GUI bundle needs review at $rollback_app or $retained_app; neither path was removed."
}

restore_prior_gui_app_bundle() {
  local rollback_app="$1"
  local target_app="$2"
  [[ -e "$rollback_app" || -L "$rollback_app" ]] || return 0
  if [[ -e "$target_app" || -L "$target_app" ]]; then
    warn "Target path is occupied; prior GUI bundle remains in rollback storage: $rollback_app"
    return 1
  fi
  if ! mv -- "$rollback_app" "$target_app"; then
    warn "Could not restore prior GUI bundle; it remains in rollback storage: $rollback_app"
    return 1
  fi
}

install_login_toolbar_agent() {
  local app_path="$1"
  local launch_agents_dir="$HOME/Library/LaunchAgents"
  local plist_path="$launch_agents_dir/com.waynetechlab.csa-iem.toolbar.plist"

  if [[ "$DISABLE_LOGIN_TOOLBAR" == "1" ]]; then
    info "Skipping login toolbar registration (CSA_IEM_DISABLE_LOGIN_TOOLBAR=1)."
    return 0
  fi

  mkdir -p "$launch_agents_dir"
  cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.waynetechlab.csa-iem.toolbar</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-gj</string>
    <string>$app_path</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

  if command -v launchctl >/dev/null 2>&1; then
    launchctl unload "$plist_path" >/dev/null 2>&1 || true
    launchctl load "$plist_path" >/dev/null 2>&1 || true
  fi
}

install_gui_app_bundle() {
  local app_install_dir=""
  local build_dist_root=""
  local built_app=""
  local target_app=""
  local app_stage_root=""
  local staged_app=""
  local rollback_root=""
  local rollback_app=""
  local build_log="${TMPDIR:-/tmp}/csa-iem-install-gui-build.log"

  if [[ "$INSTALL_GUI_APP" -ne 1 ]]; then
    return 0
  fi

  if ! command -v swift >/dev/null 2>&1; then
    warn "Swift was not found, so $APP_NAME.app could not be built automatically."
    warn "Install Xcode Command Line Tools or Xcode, then run: csa-iem-build-gui"
    return 1
  fi

  if [[ ! -x "$INSTALL_DIR/build-gui-app.sh" ]]; then
    warn "GUI builder was not found, so $APP_NAME.app could not be installed."
    return 1
  fi

  info "Building native $APP_NAME.app for the menu-bar toolbar..."
  build_dist_root="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-install-build.XXXXXX")" || return 1
  built_app="$build_dist_root/$APP_NAME.app"
  if ! CSA_IEM_DIST_DIR="$build_dist_root" "$INSTALL_DIR/build-gui-app.sh" >"$build_log" 2>&1; then
    rm -rf -- "$build_dist_root"
    warn "GUI app build failed. See log: $build_log"
    tail -n 30 "$build_log" >&2 || true
    return 1
  fi

  if [[ ! -d "$built_app" ]]; then
    rm -rf -- "$build_dist_root"
    warn "GUI builder finished but did not create $built_app."
    return 1
  fi

  app_install_dir="$(default_app_install_dir)"
  mkdir -p "$app_install_dir" || return 1
  target_app="$app_install_dir/$APP_NAME.app"
  app_stage_root="$(mktemp -d "$app_install_dir/.csa-iem-install.XXXXXX")" || return 1
  staged_app="$app_stage_root/$APP_NAME.app"
  if ! ditto --norsrc "$built_app" "$staged_app"; then
    rm -rf -- "$app_stage_root" "$build_dist_root"
    printf 'Could not stage the verified GUI bundle for installation: %s\n' "$staged_app" >&2
    return 1
  fi
  if ! is_owned_app_bundle "$staged_app"; then
    rm -rf -- "$app_stage_root" "$build_dist_root"
    printf 'Staged GUI bundle has an unexpected identity: %s\n' "$staged_app" >&2
    return 1
  fi
  rm -rf -- "$build_dist_root"
  xattr -rc "$staged_app" >/dev/null 2>&1 || true
  if command -v codesign >/dev/null 2>&1; then
    if ! codesign --force --deep --sign - --timestamp=none "$staged_app" >/dev/null 2>&1 \
      || ! codesign --verify --deep --strict "$staged_app" >/dev/null 2>&1; then
      rm -rf -- "$app_stage_root"
      printf 'Staged GUI bundle signature verification failed: %s\n' "$staged_app" >&2
      return 1
    fi
  fi

  rollback_root="$(mktemp -d "$app_install_dir/.csa-iem-rollback.XXXXXX")" || return 1
  rollback_app="$rollback_root/$APP_NAME.app"
  if [[ -e "$target_app" || -L "$target_app" ]] \
    && ! is_owned_app_bundle "$target_app"; then
    rm -rf -- "$app_stage_root" "$rollback_root"
    printf 'Refusing to replace app bundle with unverified identity: %s\n' "$target_app" >&2
    return 1
  fi
  if ! stop_running_gui_instances "$target_app"; then
    rm -rf -- "$app_stage_root" "$rollback_root"
    printf 'Could not safely replace %s while an older process is still running.\n' "$target_app" >&2
    return 1
  fi
  if [[ -e "$target_app" || -L "$target_app" ]]; then
    if ! mv -- "$target_app" "$rollback_app"; then
      rm -rf -- "$app_stage_root" "$rollback_root"
      printf 'Could not preserve the currently installed GUI bundle: %s\n' "$target_app" >&2
      return 1
    fi
  fi
  if ! mv -- "$staged_app" "$target_app"; then
    restore_prior_gui_app_bundle "$rollback_app" "$target_app" || true
    rm -rf -- "$app_stage_root"
    rmdir -- "$rollback_root" >/dev/null 2>&1 || true
    printf 'Could not publish the staged GUI bundle: %s\n' "$target_app" >&2
    return 1
  fi
  if command -v codesign >/dev/null 2>&1 \
    && ! codesign --verify --deep --strict "$target_app" >/dev/null 2>&1; then
    mv -- "$target_app" "$app_stage_root/failed-$APP_NAME.app" \
      || warn "Failed GUI bundle remains at $target_app and needs review."
    restore_prior_gui_app_bundle "$rollback_app" "$target_app" || true
    rmdir -- "$app_stage_root" >/dev/null 2>&1 || true
    rmdir -- "$rollback_root" >/dev/null 2>&1 || true
    printf 'Installed GUI bundle signature verification failed. Review the retained prior and failed bundles before retrying: %s\n' "$target_app" >&2
    return 1
  fi
  rmdir -- "$app_stage_root" >/dev/null 2>&1 || true
  preserve_prior_gui_app_bundle "$rollback_root" "$rollback_app"
  remove_legacy_install_tree_app_bundle
  remove_stale_gui_app_bundles "$target_app"
  install_login_toolbar_agent "$target_app"

  info "Installed native app: $target_app"
  if [[ "$DISABLE_LOGIN_TOOLBAR" == "1" ]]; then
    info "Login toolbar launcher was left unchanged (CSA_IEM_DISABLE_LOGIN_TOOLBAR=1)."
  else
    info "Installed login toolbar launcher: ~/Library/LaunchAgents/com.waynetechlab.csa-iem.toolbar.plist"
  fi

  if [[ "$OPEN_GUI_APP" -eq 1 ]]; then
    open -gj "$target_app" >/dev/null 2>&1 || open "$target_app" >/dev/null 2>&1 || true
    info "Started $APP_NAME.app so the menu-bar toolbar can appear."
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

link_tool_if_present() {
  local tool_name="$1"
  local source_path="$2"
  local target_path="$BIN_DIR/$tool_name"

  if [[ -x "$source_path" ]]; then
    mkdir -p "$BIN_DIR"
    ln -sfn "$source_path" "$target_path"
    info "Linked $tool_name into $BIN_DIR."
    return 0
  fi

  return 1
}

npm_global_prefix() {
  npm config get prefix 2>/dev/null | tail -n 1 | tr -d '\r'
}

install_devcontainer_cli_globally() {
  local npm_prefix=""
  local devcontainer_bin=""

  npm_prefix="$(npm_global_prefix || true)"
  if [[ -n "$npm_prefix" && "$npm_prefix" != "undefined" && "$npm_prefix" != "null" ]]; then
    info "Installing Dev Containers CLI with npm global prefix: $npm_prefix"
  else
    info "Installing Dev Containers CLI with npm global prefix."
  fi

  if ! npm install -g @devcontainers/cli; then
    return 1
  fi

  if command -v devcontainer >/dev/null 2>&1; then
    info "Dev Containers CLI is now available."
    return 0
  fi

  if [[ -n "$npm_prefix" && "$npm_prefix" != "undefined" && "$npm_prefix" != "null" ]]; then
    devcontainer_bin="$npm_prefix/bin/devcontainer"
    if link_tool_if_present devcontainer "$devcontainer_bin"; then
      return 0
    fi
  fi

  warn "Dev Containers CLI installed, but the devcontainer binary was not found on PATH."
  return 1
}

install_devcontainer_cli_user_local() {
  local devcontainer_bin="$DEVCONTAINER_NPM_PREFIX/bin/devcontainer"

  mkdir -p "$DEVCONTAINER_NPM_PREFIX"
  info "Retrying Dev Containers CLI install with a user-local npm prefix: $DEVCONTAINER_NPM_PREFIX"

  if ! NPM_CONFIG_PREFIX="$DEVCONTAINER_NPM_PREFIX" npm install -g @devcontainers/cli; then
    return 1
  fi

  if command -v devcontainer >/dev/null 2>&1; then
    info "Dev Containers CLI is now available."
    info "CSA-iEM switched to a user-local install so administrator access was not required."
    return 0
  fi

  if link_tool_if_present devcontainer "$devcontainer_bin"; then
    info "Dev Containers CLI was installed locally at $DEVCONTAINER_NPM_PREFIX and linked into $BIN_DIR."
    info "CSA-iEM switched to a user-local install so administrator access was not required."
    return 0
  fi

  warn "Dev Containers CLI installed into $DEVCONTAINER_NPM_PREFIX, but the devcontainer binary could not be linked."
  return 1
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

  if install_devcontainer_cli_globally; then
    return 0
  fi

  warn "Global npm install for Dev Containers CLI failed. This usually happens on Macs where the npm global prefix is not writable for the current user."
  warn "CSA-iEM will retry with a user-local install path, so admin rights are usually not needed."

  if install_devcontainer_cli_user_local; then
    return 0
  fi

  warn "Dev Containers CLI could not be installed automatically. You can retry later with:"
  warn "  NPM_CONFIG_PREFIX=\"$DEVCONTAINER_NPM_PREFIX\" npm install -g @devcontainers/cli"
  return 1
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
    --no-gui-app)
      INSTALL_GUI_APP=0
      OPEN_GUI_APP=0
      ;;
    --no-open)
      OPEN_GUI_APP=0
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

if ! command -v shasum >/dev/null 2>&1; then
  printf 'shasum is required to verify the install payload.\n' >&2
  exit 1
fi
if ! (cd "$SCRIPT_DIR" && shasum -a 256 -c --strict SHA256SUMS >/dev/null); then
  printf 'Install payload checksum verification failed.\n' >&2
  exit 1
fi

validate_install_root
FINAL_INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"
INSTALL_DIR="$FINAL_INSTALL_DIR"

validate_current_install_link
validate_command_links
if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]] \
  && ! is_owned_install_version "$INSTALL_DIR" "$APP_VERSION" \
  && ! is_legacy_install_version "$INSTALL_DIR" "$APP_VERSION"; then
  printf 'Refusing to replace unrecognized install-root entry: %s\n' "$INSTALL_DIR" >&2
  exit 1
fi
STAGED_INSTALL_DIR="$(mktemp -d "$INSTALL_ROOT/.csa-iem-install-stage.XXXXXX")"
cleanup_unpromoted_stage() {
  if [[ -n "$STAGED_INSTALL_DIR" && -d "$STAGED_INSTALL_DIR" ]]; then
    rm -rfx -- "$STAGED_INSTALL_DIR"
  fi
}
trap cleanup_unpromoted_stage EXIT
INSTALL_DIR="$STAGED_INSTALL_DIR"

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
  "$INSTALL_DIR/stage2-workspace.sh" \
  "$INSTALL_DIR/stage2-workspace.ps1" \
  "$INSTALL_DIR/stage3-cleanup.sh" \
  "$INSTALL_DIR/stage3-cleanup.ps1" \
  "$INSTALL_DIR/repo-consolidation-recovery.py" \
  "$INSTALL_DIR/repo-consolidation-local-cleanup.py" \
  "$INSTALL_DIR/CSA-iLEM-Open.sh" \
  "$INSTALL_DIR/build-gui-app.sh" \
  "$INSTALL_DIR/run-gui.sh" \
  "$INSTALL_DIR/openproj" \
  "$INSTALL_DIR/csa-iem-gui" \
  "$INSTALL_DIR/csa-iem-build-gui" \
  "$INSTALL_DIR/csa-iem" \
  "$INSTALL_DIR/csa-iem-update" \
  "$INSTALL_DIR/csa-iem-open" \
  "$INSTALL_DIR/csa-ilem-gui" \
  "$INSTALL_DIR/csa-ilem-build-gui" \
  "$INSTALL_DIR/csa-ilem" \
  "$INSTALL_DIR/csa-ilem-update" \
  "$INSTALL_DIR/csa-ilem-open" \
  "$INSTALL_DIR/install-remote.sh" \
  "$INSTALL_DIR/install.sh" \
  "$INSTALL_DIR/uninstall.sh"

write_install_receipt
if ! verify_staged_install "$STAGED_INSTALL_DIR"; then
  printf 'Staged install payload did not pass checksum and identity verification. The previous version was retained.\n' >&2
  exit 1
fi

INSTALL_DIR="$FINAL_INSTALL_DIR"
if ! prepare_current_install_version; then
  printf 'Could not preserve the previous install before promotion.\n' >&2
  exit 1
fi
if ! mv -- "$STAGED_INSTALL_DIR" "$INSTALL_DIR"; then
  rollback_current_install_version || true
  printf 'Could not promote the verified staged install. The previous version was restored where possible.\n' >&2
  exit 1
fi
STAGED_INSTALL_DIR=""

if ! install_gui_app_bundle; then
  rollback_current_install_version || true
  printf 'GUI installation failed. The previous CLI version was restored where possible.\n' >&2
  exit 1
fi

ln -sfn "$INSTALL_DIR" "$INSTALL_ROOT/current"

for command_name in "${COMMANDS[@]}"; do
  ln -sfn "$INSTALL_DIR/$command_name" "$BIN_DIR/$command_name"
done

if [[ "$UPDATE_SHELL_PROFILE" -eq 1 ]]; then
  configure_shell_profiles "$(build_path_export_line "$BIN_DIR")" "${COMMAND_ALIAS_LINES[@]}"
fi

finalize_prior_install_version
cleanup_old_install_versions

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
printf '  %s\n' "csa-iem" "csa-iem-update" "csa-iem-gui" "csa-iem-build-gui" "csa-iem-open" "openproj"
echo
echo "Advanced compatibility commands:"
printf '  %s\n' \
  "csa-ilem" "csa-ilem-update" \
  "csa-ilem-open" "csa-ilem-gui" "csa-ilem-build-gui"
echo
if [[ "$UPDATE_SHELL_PROFILE" -eq 1 ]]; then
  echo "Run one of these now in the current shell if the command is not found yet:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
  echo '  source ~/.zprofile'
  echo '  source ~/.zshrc'
  echo
  echo "Capitalized macOS Terminal aliases are also installed:"
  printf '  %s\n' "CSA-IEM" "CSA-iEM" "CSA-ILEM" "CSA-iLEM"
fi
echo
echo "Then verify:"
echo "  csa-iem --version"
echo "  csa-iem-update --help"
echo "  CSA-IEM --version"
echo
echo "For future updates, review a local source checkout and run its install.sh after verifying its publisher and checksum manifest."
