#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE_PATH" ]]; do
  SOURCE_DIR="$(cd -P -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
  SOURCE_PATH="$(readlink "$SOURCE_PATH")"
  [[ "$SOURCE_PATH" != /* ]] && SOURCE_PATH="$SOURCE_DIR/$SOURCE_PATH"
done
SCRIPT_DIR="$(cd -P -- "$(dirname -- "$SOURCE_PATH")" && pwd)"

detect_launcher_profile() {
  local config_base="${XDG_CONFIG_HOME:-$HOME/.config}"
  local current_profile="${CSA_PROFILE:-}"
  local candidate=""

  if [[ -n "$current_profile" ]]; then
    printf '%s\n' "$current_profile"
    return
  fi

  for candidate in \
    "$config_base/csa-iem/diamond.env" \
    "$config_base/csa-ilem/diamond.env"
  do
    if [[ -f "$candidate" ]] && grep -q '^SAVED_CODE_ROOT=' "$candidate" && grep -q '^SAVED_RUNTIME_ROOT=' "$candidate"; then
      printf 'diamond\n'
      return
    fi
  done

  if [[ -d "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-X/GH/Repos" && -d "/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH/Repos" ]]; then
    printf 'diamond\n'
    return
  fi

  for candidate in \
    "$config_base/csa-iem/public.env" \
    "$config_base/csa-ilem/public.env"
  do
    if [[ -f "$candidate" ]] && grep -q '^SAVED_DEFAULT_ROOT=' "$candidate"; then
      printf 'public\n'
      return
    fi
  done

  for candidate in \
    "$config_base/csa-iem/wtl.env" \
    "$config_base/csa-ilem/wtl.env"
  do
    if [[ -f "$candidate" ]] && grep -q '^SAVED_DEFAULT_ROOT=' "$candidate"; then
      printf 'wtl\n'
      return
    fi
  done

  printf 'public\n'
}

CSA_PROFILE="$(detect_launcher_profile)"
export CSA_PROFILE
exec "$SCRIPT_DIR/CSA-iLEM.sh" --profile "$CSA_PROFILE" --browse-projects --use-current-root "$@"
