#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="CSA-iEM"
APP_VERSION="$(sed -n '1p' "$SCRIPT_DIR/VERSION" 2>/dev/null || printf '0.2.4')"
INSTALL_ROOT="${CSA_IEM_INSTALL_ROOT:-${CSA_ILEM_INSTALL_ROOT:-$HOME/.local/share/csa-iem}}"
BIN_DIR="${CSA_IEM_BIN_DIR:-${CSA_ILEM_BIN_DIR:-$HOME/.local/bin}}"
INSTALL_DIR="$INSTALL_ROOT/$APP_VERSION"

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

INSTALL_DIR_RESOLVED="$INSTALL_DIR"
if [[ -d "$INSTALL_DIR" ]]; then
  INSTALL_DIR_RESOLVED="$(cd -P -- "$INSTALL_DIR" && pwd)"
fi

for command_name in "${COMMANDS[@]}"; do
  link_path="$BIN_DIR/$command_name"
  if [[ -L "$link_path" ]]; then
    target_path="$(resolve_link_target "$link_path" || true)"
    if [[ "$target_path" == "$INSTALL_DIR_RESOLVED/$command_name" ]]; then
      rm -f "$link_path"
    fi
  fi
done

if [[ -L "$INSTALL_ROOT/current" ]]; then
  current_target="$(resolve_link_target "$INSTALL_ROOT/current" || true)"
  if [[ "$current_target" == "$INSTALL_DIR_RESOLVED" ]]; then
    rm -f "$INSTALL_ROOT/current"
  fi
fi

rm -rf "$INSTALL_DIR"

echo
printf '%s %s removed from:\n' "$APP_NAME" "$APP_VERSION"
printf '  %s\n' "$INSTALL_DIR"
