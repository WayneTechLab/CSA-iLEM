#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CSA-iEM"
APP_BUNDLE_IDENTIFIER="com.waynetechlab.csa-iem"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.0.0')"
INSTALL_RECEIPT_NAME=".csa-iem-install-receipt"
INSTALL_ROOT="${CSA_IEM_INSTALL_ROOT:-${CSA_ILEM_INSTALL_ROOT:-$HOME/.local/share/csa-iem}}"
BIN_DIR="${CSA_IEM_BIN_DIR:-${CSA_ILEM_BIN_DIR:-$HOME/.local/bin}}"
INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"

COMMANDS=(
  "csa-iem"
  "csa-iem-update"
  "csa-iem-public"
  "csa-iem-wtl"
  "csa-iem-diamond"
  "csa-iem-open"
  "csa-iem-gui"
  "csa-iem-build-gui"
  "csa-ilem"
  "csa-ilem-update"
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
$APP_NAME uninstaller
Version: $APP_VERSION

Usage:
  ./uninstall.sh
  ./uninstall.sh --install-root <dir>
  ./uninstall.sh --bin-dir <dir>
EOF
}

resolve_link_target() {
  local link_path="$1"
  local raw_target=""
  local resolved_dir=""
  local resolved_target=""

  [[ -L "$link_path" ]] || return 1
  raw_target="$(readlink "$link_path")" || return 1
  if [[ "$raw_target" != /* ]]; then
    raw_target="$(cd -- "$(dirname -- "$link_path")" && pwd)/$raw_target"
  fi

  resolved_dir="$(dirname -- "$raw_target")"
  if [[ -d "$resolved_dir" ]]; then
    resolved_target="$(cd -P -- "$resolved_dir" && pwd)/$(basename -- "$raw_target")"
  else
    resolved_target="$raw_target"
  fi

  printf '%s\n' "$resolved_target"
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
  [[ -d "$INSTALL_ROOT" ]] || return 0
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

is_owned_install_version() {
  local candidate="$1"
  local receipt="$candidate/$INSTALL_RECEIPT_NAME"
  local candidate_device=""
  local parent_device=""

  [[ -d "$candidate" && ! -L "$candidate" ]] || return 1
  candidate_device="$(stat -f %d "$candidate" 2>/dev/null)" || return 1
  parent_device="$(stat -f %d "$INSTALL_ROOT" 2>/dev/null)" || return 1
  [[ -n "$candidate_device" && "$candidate_device" == "$parent_device" ]] || return 1
  [[ -f "$receipt" && ! -L "$receipt" ]] || return 1
  [[ "$(cat -- "$receipt")" == "$APP_BUNDLE_IDENTIFIER|$APP_VERSION" ]] || return 1
  [[ -f "$candidate/VERSION" && "$(sed -n '1p' "$candidate/VERSION")" == "$APP_VERSION" ]] || return 1
  [[ -f "$candidate/install.sh" && -f "$candidate/csa-iem" && -f "$candidate/SHA256SUMS" ]] || return 1
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
      INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"
      ;;
    --bin-dir)
      shift
      BIN_DIR="$1"
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

validate_install_root
INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"
if [[ ! -e "$INSTALL_DIR" && ! -L "$INSTALL_DIR" ]]; then
  printf '%s %s is not installed at %s\n' "$APP_NAME" "$APP_VERSION" "$INSTALL_DIR"
  exit 0
fi
if ! is_owned_install_version "$INSTALL_DIR"; then
  printf 'Refusing to remove unrecognized install-root entry: %s\n' "$INSTALL_DIR" >&2
  exit 1
fi
INSTALL_DIR_RESOLVED="$(cd -P -- "$INSTALL_DIR" && pwd)"
links_to_remove=()
current_link_to_remove=""

for command_name in "${COMMANDS[@]}"; do
  link_path="$BIN_DIR/$command_name"
  if [[ -L "$link_path" ]]; then
    target_path="$(resolve_link_target "$link_path" || true)"
    if [[ "$target_path" == "$INSTALL_DIR_RESOLVED/$command_name" ]]; then
      links_to_remove+=("$link_path")
    fi
  fi
done

if [[ -L "$INSTALL_ROOT/current" ]]; then
  current_target="$(resolve_link_target "$INSTALL_ROOT/current" || true)"
  if [[ "$current_target" == "$INSTALL_DIR_RESOLVED" ]]; then
    current_link_to_remove="$INSTALL_ROOT/current"
  fi
fi

rm -rfx -- "$INSTALL_DIR"
if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
  printf 'Installed files remain and need review: %s\n' "$INSTALL_DIR" >&2
  exit 1
fi

for link_path in "${links_to_remove[@]}"; do
  rm -f -- "$link_path"
done
if [[ -n "$current_link_to_remove" ]]; then
  rm -f -- "$current_link_to_remove"
fi

echo
printf '%s %s removed from:\n' "$APP_NAME" "$APP_VERSION"
printf '  %s\n' "$INSTALL_DIR"
