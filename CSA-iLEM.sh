#!/usr/bin/env bash
set -euo pipefail

#########################################################
# CSA-iEM
# Container Setup & Action Import Engine Manager
#
# Migrates / prepares:
# - GitHub Codespaces
# - GitHub Actions workflows
#
# Into:
# - Local repositories
# - Local devcontainers
# - Self-hosted Mac runners
#########################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

APP_NAME="CSA-iEM"
APP_FULL_NAME="Container Setup & Action Import Engine Manager"
APP_LEGACY_NAME="CSA-iLEM"
APP_VERSION="0.3.4"
APP_VENDOR="Wayne Tech Lab LLC"
APP_VENDOR_URL="https://www.WayneTechLab.com"
APP_RISK_NOTICE="Use at your own risk."
APP_TAGLINE="Codespaces & Actions -> Into Local Environment Mac"
APP_NOTICE_FILE="$SCRIPT_DIR/NOTICE.md"
APP_TERMS_FILE="$SCRIPT_DIR/TERMS-OF-SERVICE.md"
APP_PRIVACY_FILE="$SCRIPT_DIR/PRIVACY-NOTICE.md"
APP_DISCLAIMER_FILE="$SCRIPT_DIR/DISCLAIMER.md"
PUBLIC_DEFAULT_ROOT="$HOME/CSA-iEM"
WTL_DEFAULT_ROOT="/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH"
DIAMOND_CODE_DEFAULT_ROOT="/Volumes/WTL - MACmini EXT/MM-WTL-CODE-X/GH"
DIAMOND_RUNTIME_DEFAULT_ROOT="/Volumes/WTL - MACmini EXT/MM-WTL-CODE-R/GH"
PUBLIC_CUSTOM_EXAMPLE_ROOT="$WTL_DEFAULT_ROOT"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/csa-iem"
LEGACY_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/csa-ilem"
APP_SUPPORT_DIR="$HOME/Library/Application Support/CSA-iEM"
LAST_SESSION_FILE="$APP_SUPPORT_DIR/last-session.env"
LEGACY_LAST_SESSION_FILE="$HOME/Library/Application Support/CSA-iLEM/last-session.env"
CLEANER_LAST_SESSION_FILE="$HOME/Library/Application Support/GH Workflow Clean/last-session.env"
LEGACY_CLEANER_LAST_SESSION_FILE="$HOME/Library/Application Support/GitHub Action Clean-Up Tool/last-session.env"
USER_BIN_DIR="$HOME/.local/bin"

PROFILE_NAME="${CSA_PROFILE:-}"
PROFILE_LABEL=""
STORAGE_LAYOUT="single"
ENTRY_MODE="interactive"
HOST=""
ACCOUNT=""
ORIGINAL_ACCOUNT=""
SWITCHED_ACCOUNT=0
DOCKER_INSTALLED_THIS_RUN=0
AUTO_USE_CURRENT_ROOT=0
ASSUME_YES=0
NO_COLOR=0
DIRECT_CLEANUP_MODE=0
DIRECT_IMPORT_MODE=0
LAST_HOST=""
LAST_ACCOUNT=""
LAST_REPO_SPEC=""

DEFAULT_ROOT=""
SAVED_DEFAULT_ROOT=""
DEFAULT_CODE_ROOT=""
DEFAULT_RUNTIME_ROOT=""
SAVED_CODE_ROOT=""
SAVED_RUNTIME_ROOT=""
ROOT=""
CODE_ROOT=""
RUNTIME_ROOT=""
REPOS_DIR=""
REPORTS_DIR=""
BACKUPS_DIR=""
RUNNERS_DIR=""
SCRIPTS_DIR=""
CODE_REPOS_DIR=""
RUNTIME_REPOS_DIR=""

MODE=""
IMPORT_MODE_NAME=""
FULL_AUTO=0
FULL_AUTO_CLEANUP=0
SELECTED_REPOS=()
REPO_LIST=()
FAILED_REPOS=()

OWNER=""
REPO=""
SLUG=""
REPO_SPEC=""
REPO_DIR=""
CODE_REPO_DIR=""
DEV_REPO_DIR=""
REPORT_FILE=""
LOCAL_LABEL=""
RUNNER_NAME=""
RUNNER_DIR=""

DO_DISABLE=0
DO_RUNS=0
DO_ARTIFACTS=0
DO_CACHES=0
DO_CODESPACES=0
FULL_CLEANUP=0
DRY_RUN=0
RUN_FILTER=""
TARGET_RUN_ID=""
IMPORTED_PROJECT_SLUGS=()
IMPORTED_PROJECT_CODE_DIRS=()
IMPORTED_PROJECT_RUNTIME_DIRS=()

C_RESET=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_BOLD=""

supports_color() {
  [[ -t 1 ]] && [[ "$NO_COLOR" -eq 0 ]]
}

init_colors() {
  if supports_color; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_BOLD=$'\033[1m'
  else
    C_RESET=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_BOLD=""
  fi
}

print_line() {
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

doc_exists() {
  [[ -f "$1" ]]
}

show_doc_file() {
  local title="$1"
  local file_path="$2"

  echo
  print_line
  echo "$title"
  print_line
  if doc_exists "$file_path"; then
    cat "$file_path"
  else
    echo "Document not found: $file_path"
  fi
}

show_about() {
  echo
  print_line
  printf '%s v%s\n' "$APP_NAME" "$APP_VERSION"
  print_line
  printf 'Full name: %s\n' "$APP_FULL_NAME"
  printf 'Legacy compatibility name: %s\n' "$APP_LEGACY_NAME"
  printf 'Provided by: %s\n' "$APP_VENDOR"
  printf 'Website: %s\n' "$APP_VENDOR_URL"
  printf 'Notice: %s\n' "$APP_RISK_NOTICE"
  echo
  echo "$APP_FULL_NAME"
  echo "$APP_TAGLINE"
  echo
  echo "Included documents:"
  printf '  Notice: %s\n' "$APP_NOTICE_FILE"
  printf '  Terms: %s\n' "$APP_TERMS_FILE"
  printf '  Privacy: %s\n' "$APP_PRIVACY_FILE"
  printf '  Disclaimer: %s\n' "$APP_DISCLAIMER_FILE"
  echo
  echo "This CLI modifies local developer tooling, repositories, devcontainers,"
  echo "and self-hosted GitHub Actions runner state on macOS."
}

info() {
  printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

warn() {
  printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
}

err() {
  printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}

pause() {
  read -r -p "Press Enter to continue..."
}

confirm() {
  local prompt="${1:-Are you sure?}"
  local answer

  if [[ "$FULL_AUTO" -eq 1 ]]; then
    info "FULL AUTO: yes -> $prompt"
    return 0
  fi

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    info "Assume yes -> $prompt"
    return 0
  fi

  read -r -p "$prompt (y/n): " answer
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

manual_confirm() {
  local prompt="${1:-Are you sure?}"
  local answer=""

  read -r -p "$prompt (y/n): " answer
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

require_cmd() {
  local cmd="$1"
  local help_msg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Missing required command: $cmd"
    printf '%s\n' "$help_msg" >&2
    exit 1
  fi
}

profile_config_file() {
  printf '%s/%s.env' "$CONFIG_DIR" "$PROFILE_NAME"
}

legacy_profile_config_file() {
  printf '%s/%s.env' "$LEGACY_CONFIG_DIR" "$PROFILE_NAME"
}

save_profile_config() {
  local config_file=""

  mkdir -p "$CONFIG_DIR"
  config_file="$(profile_config_file)"
  cat > "$config_file" <<EOF
SAVED_DEFAULT_ROOT=$(printf '%q' "$SAVED_DEFAULT_ROOT")
SAVED_CODE_ROOT=$(printf '%q' "$SAVED_CODE_ROOT")
SAVED_RUNTIME_ROOT=$(printf '%q' "$SAVED_RUNTIME_ROOT")
EOF
}

load_profile_config() {
  local config_file=""
  local legacy_file=""

  config_file="$(profile_config_file)"
  legacy_file="$(legacy_profile_config_file)"
  if [[ -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    . "$config_file"
  elif [[ -f "$legacy_file" ]]; then
    # shellcheck disable=SC1090
    . "$legacy_file"
  fi
}

load_last_session() {
  local source_file=""
  local line=""
  local key=""
  local value=""

  if [[ -f "$LAST_SESSION_FILE" ]]; then
    source_file="$LAST_SESSION_FILE"
  elif [[ -f "$LEGACY_LAST_SESSION_FILE" ]]; then
    source_file="$LEGACY_LAST_SESSION_FILE"
  elif [[ -f "$CLEANER_LAST_SESSION_FILE" ]]; then
    source_file="$CLEANER_LAST_SESSION_FILE"
  elif [[ -f "$LEGACY_CLEANER_LAST_SESSION_FILE" ]]; then
    source_file="$LEGACY_CLEANER_LAST_SESSION_FILE"
  else
    return 0
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      HOST) LAST_HOST="$value" ;;
      ACCOUNT) LAST_ACCOUNT="$value" ;;
      REPO) LAST_REPO_SPEC="$value" ;;
    esac
  done < "$source_file"
}

save_last_session() {
  local previous_umask=""

  [[ -n "$HOST" && -n "$ACCOUNT" && -n "$OWNER" && -n "$REPO" ]] || return 0

  mkdir -p "$APP_SUPPORT_DIR"
  chmod 700 "$APP_SUPPORT_DIR" >/dev/null 2>&1 || true

  previous_umask="$(umask)"
  umask 077
  cat > "$LAST_SESSION_FILE" <<EOF
HOST=$HOST
ACCOUNT=$ACCOUNT
REPO=$HOST/$OWNER/$REPO
EOF
  umask "$previous_umask"
}

set_profile_defaults() {
  case "$PROFILE_NAME" in
    public)
      PROFILE_LABEL="Public"
      STORAGE_LAYOUT="single"
      DEFAULT_ROOT="$PUBLIC_DEFAULT_ROOT"
      DEFAULT_CODE_ROOT="$PUBLIC_DEFAULT_ROOT"
      DEFAULT_RUNTIME_ROOT="$PUBLIC_DEFAULT_ROOT"
      ;;
    wtl)
      PROFILE_LABEL="WTL"
      STORAGE_LAYOUT="single"
      DEFAULT_ROOT="$WTL_DEFAULT_ROOT"
      DEFAULT_CODE_ROOT="$WTL_DEFAULT_ROOT"
      DEFAULT_RUNTIME_ROOT="$WTL_DEFAULT_ROOT"
      ;;
    diamond)
      PROFILE_LABEL="Diamond"
      STORAGE_LAYOUT="diamond"
      DEFAULT_CODE_ROOT="$DIAMOND_CODE_DEFAULT_ROOT"
      DEFAULT_RUNTIME_ROOT="$DIAMOND_RUNTIME_DEFAULT_ROOT"
      DEFAULT_ROOT="$DIAMOND_RUNTIME_DEFAULT_ROOT"
      ;;
    *)
      err "Unknown profile: $PROFILE_NAME"
      exit 1
      ;;
  esac
}

select_profile() {
  local requested="${1:-$PROFILE_NAME}"
  local choice=""

  if [[ -n "$requested" ]]; then
    PROFILE_NAME="$requested"
    set_profile_defaults
    load_profile_config
    return 0
  fi

  echo
  print_line
  echo "$APP_NAME Edition"
  print_line
  echo "1) Public"
  echo "2) WTL"
  echo "3) Diamond"
  echo
  read -r -p "Enter choice [1-3]: " choice

  case "$choice" in
    1) PROFILE_NAME="public" ;;
    2) PROFILE_NAME="wtl" ;;
    3) PROFILE_NAME="diamond" ;;
    *)
      err "Invalid choice."
      exit 1
      ;;
  esac

  set_profile_defaults
  load_profile_config
}

current_default_root() {
  if [[ -n "$SAVED_DEFAULT_ROOT" ]]; then
    printf '%s' "$SAVED_DEFAULT_ROOT"
  else
    printf '%s' "$DEFAULT_ROOT"
  fi
}

current_default_code_root() {
  if [[ -n "$SAVED_CODE_ROOT" ]]; then
    printf '%s' "$SAVED_CODE_ROOT"
  else
    printf '%s' "$DEFAULT_CODE_ROOT"
  fi
}

current_default_runtime_root() {
  if [[ -n "$SAVED_RUNTIME_ROOT" ]]; then
    printf '%s' "$SAVED_RUNTIME_ROOT"
  else
    printf '%s' "$DEFAULT_RUNTIME_ROOT"
  fi
}

cleanup_on_exit() {
  local exit_code=$?

  trap - EXIT
  if [[ "$SWITCHED_ACCOUNT" -eq 1 && -n "$ORIGINAL_ACCOUNT" && -n "$HOST" ]]; then
    gh auth switch --hostname "$HOST" --user "$ORIGINAL_ACCOUNT" >/dev/null 2>&1 || \
      warn "Failed to restore the original GitHub account $ORIGINAL_ACCOUNT on $HOST"
  fi

  exit "$exit_code"
}

ensure_profile_line() {
  local file="$1"
  local line="$2"
  touch "$file"
  if ! grep -Fq "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

prompt_optional() {
  local label="$1"
  local default="${2:-}"
  local value=""

  if [[ -n "$default" ]]; then
    read -r -p "$label [$default]: " value
    value="${value:-$default}"
  else
    read -r -p "$label: " value
  fi

  trim "$value"
}

prompt_nonempty() {
  local label="$1"
  local default="${2:-}"
  local value=""

  while true; do
    if [[ -n "$default" ]]; then
      read -r -p "$label [$default]: " value
      value="${value:-$default}"
    else
      read -r -p "$label: " value
    fi

    value="$(trim "$value")"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi

    warn "A value is required."
  done
}

choose_from_list() {
  local title="$1"
  shift
  local options=("$@")
  local choice=""
  local index=1

  if [[ "${#options[@]}" -eq 0 ]]; then
    err "Internal error: no options available for $title"
    exit 1
  fi

  printf '\n' >&2
  print_line >&2
  printf '%s\n' "$title" >&2
  print_line >&2
  for choice in "${options[@]}"; do
    printf '  %d) %s\n' "$index" "$choice" >&2
    index=$((index + 1))
  done

  while true; do
    printf 'Choose [1-%s]: ' "${#options[@]}" >&2
    read -r choice
    case "$choice" in
      ''|*[!0-9]*)
        printf '[WARN] %s\n' "Enter a number." >&2
        ;;
      *)
        if [[ "$choice" -ge 1 && "$choice" -le "${#options[@]}" ]]; then
          printf '%s' "${options[$((choice - 1))]}"
          return 0
        fi
        printf '[WARN] %s\n' "Choice out of range." >&2
        ;;
    esac
  done
}

gh_config_file() {
  local config_path="${XDG_CONFIG_HOME:-$HOME/.config}/gh/hosts.yml"
  if [[ -f "$config_path" ]]; then
    printf '%s' "$config_path"
  fi
}

load_hosts_from_config() {
  local config_path=""

  config_path="$(gh_config_file)"
  [[ -n "$config_path" ]] || return 0

  awk '
    /^[^[:space:]][^:]*:$/ {
      host = $0
      sub(/:$/, "", host)
      print host
    }
  ' "$config_path"
}

load_active_account_for_host() {
  local host="$1"
  local config_path=""

  config_path="$(gh_config_file)"
  [[ -n "$config_path" ]] || return 0

  awk -v host="$host" '
    /^[^[:space:]][^:]*:$/ {
      current = $0
      sub(/:$/, "", current)
      in_host = (current == host)
      next
    }
    in_host && /^    user: / {
      user = $0
      sub(/^    user: /, "", user)
      print user
      exit
    }
  ' "$config_path"
}

load_accounts_for_host() {
  local host="$1"
  local config_path=""
  local active_account=""
  local accounts=""

  config_path="$(gh_config_file)"
  [[ -n "$config_path" ]] || return 0

  active_account="$(load_active_account_for_host "$host")"
  accounts="$(awk -v host="$host" -v active_account="$active_account" '
    /^[^[:space:]][^:]*:$/ {
      current = $0
      sub(/:$/, "", current)
      in_host = (current == host)
      in_users = 0
      next
    }
    in_host && /^    users:$/ {
      in_users = 1
      next
    }
    in_host && /^    [^ ]/ && $0 !~ /^    users:$/ {
      in_users = 0
    }
    in_host && in_users && /^        [^[:space:]][^:]*:$/ {
      user = $0
      sub(/^        /, "", user)
      sub(/:$/, "", user)
      state = (user == active_account ? "active" : "available")
      print user "\t" state
    }
  ' "$config_path")"

  if [[ -z "$accounts" && -n "$active_account" ]]; then
    printf '%s\tactive\n' "$active_account"
    return 0
  fi

  printf '%s\n' "$accounts"
}

load_hosts() {
  local hosts=""

  hosts="$(load_hosts_from_config)"
  if [[ -n "$hosts" ]]; then
    printf '%s\n' "$hosts"
    return 0
  fi

  gh auth status --json hosts --jq '
    .hosts
    | to_entries[]
    | select((.value | length) > 0)
    | .key
  ' 2>/dev/null || true
}

ensure_auth_for_host() {
  local host="$1"
  local accounts=""

  accounts="$(load_accounts_for_host "$host")"
  if [[ -n "$accounts" ]]; then
    return 0
  fi

  warn "No authenticated GitHub account found for $host."
  while true; do
    if ! confirm "Run gh auth login for $host now?"; then
      err "Authentication is required before continuing."
      exit 1
    fi

    gh auth login --hostname "$host" || true
    accounts="$(load_accounts_for_host "$host")"
    if [[ -n "$accounts" ]]; then
      return 0
    fi
    warn "GitHub authentication failed or was cancelled."
  done
}

select_host() {
  local hosts=()
  local line=""
  local default_host=""

  if [[ -n "$HOST" ]]; then
    ensure_auth_for_host "$HOST"
    info "Using GitHub host $HOST"
    return 0
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] && hosts+=("$line")
  done < <(load_hosts)

  if [[ "${#hosts[@]}" -eq 0 ]]; then
    default_host="${LAST_HOST:-github.com}"
    HOST="$(prompt_nonempty "GitHub host" "$default_host")"
    ensure_auth_for_host "$HOST"
    return 0
  fi

  if [[ "${#hosts[@]}" -eq 1 ]]; then
    HOST="${hosts[0]}"
    ensure_auth_for_host "$HOST"
    info "Using GitHub host $HOST"
    return 0
  fi

  if [[ -n "$LAST_HOST" ]]; then
    for line in "${hosts[@]}"; do
      if [[ "$line" == "$LAST_HOST" ]]; then
        HOST="$LAST_HOST"
        ensure_auth_for_host "$HOST"
        info "Using GitHub host $HOST"
        return 0
      fi
    done
  fi

  HOST="$(choose_from_list "Available GitHub Hosts" "${hosts[@]}")"
  ensure_auth_for_host "$HOST"
}

select_account() {
  local lines=()
  local line=""
  local login=""
  local state=""
  local active_account=""
  local menu=()
  local selected=""
  local seen_accounts="|"

  while IFS= read -r line; do
    [[ -n "$line" ]] && lines+=("$line")
  done < <(load_accounts_for_host "$HOST")

  if [[ "${#lines[@]}" -eq 0 ]]; then
    ensure_auth_for_host "$HOST"
    while IFS= read -r line; do
      [[ -n "$line" ]] && lines+=("$line")
    done < <(load_accounts_for_host "$HOST")
  fi

  if [[ "${#lines[@]}" -eq 0 ]]; then
    err "No authenticated accounts found for $HOST."
    exit 1
  fi

  for line in "${lines[@]}"; do
    IFS=$'\t' read -r login state <<<"$line"
    if [[ "$state" == "active" ]]; then
      active_account="$login"
    fi
  done

  if [[ -n "$ACCOUNT" ]]; then
    for line in "${lines[@]}"; do
      IFS=$'\t' read -r login state <<<"$line"
      if [[ "$login" == "$ACCOUNT" ]]; then
        if [[ "$ACCOUNT" != "$active_account" ]]; then
          if [[ "$SWITCHED_ACCOUNT" -eq 0 ]]; then
            ORIGINAL_ACCOUNT="$active_account"
          fi
          SWITCHED_ACCOUNT=1
          info "Switching active GitHub account on $HOST to $ACCOUNT"
          gh auth switch --hostname "$HOST" --user "$ACCOUNT" >/dev/null || {
            err "Failed to switch the GitHub account."
            exit 1
          }
        fi
        return 0
      fi
    done
    err "Authenticated account $ACCOUNT was not found on $HOST."
    exit 1
  fi

  if [[ "${#lines[@]}" -eq 1 ]]; then
    IFS=$'\t' read -r ACCOUNT state <<<"${lines[0]}"
    info "Using GitHub account $ACCOUNT on $HOST"
    return 0
  fi

  if [[ -n "$LAST_ACCOUNT" ]]; then
    for line in "${lines[@]}"; do
      IFS=$'\t' read -r login state <<<"$line"
      if [[ "$login" == "$LAST_ACCOUNT" ]]; then
        ACCOUNT="$LAST_ACCOUNT"
        if [[ -n "$active_account" && "$ACCOUNT" != "$active_account" ]]; then
          if [[ "$SWITCHED_ACCOUNT" -eq 0 ]]; then
            ORIGINAL_ACCOUNT="$active_account"
          fi
          SWITCHED_ACCOUNT=1
          info "Switching active GitHub account on $HOST to $ACCOUNT"
          gh auth switch --hostname "$HOST" --user "$ACCOUNT" >/dev/null || {
            err "Failed to switch the GitHub account."
            exit 1
          }
        fi
        info "Using GitHub account $ACCOUNT on $HOST"
        return 0
      fi
    done
  fi

  for line in "${lines[@]}"; do
    IFS=$'\t' read -r login state <<<"$line"
    [[ "$seen_accounts" == *"|$login|"* ]] && continue
    seen_accounts="${seen_accounts}${login}|"
    if [[ "$state" == "active" ]]; then
      menu+=("$login (active)")
    else
      menu+=("$login")
    fi
  done

  selected="$(choose_from_list "Authenticated Accounts For $HOST" "${menu[@]}")"
  ACCOUNT="${selected%% *}"

  if [[ -z "$active_account" ]]; then
    active_account="$(load_active_account_for_host "$HOST")"
  fi

  if [[ -n "$active_account" && "$ACCOUNT" != "$active_account" ]]; then
    if [[ "$SWITCHED_ACCOUNT" -eq 0 ]]; then
      ORIGINAL_ACCOUNT="$active_account"
    fi
    SWITCHED_ACCOUNT=1
    info "Switching active GitHub account on $HOST to $ACCOUNT"
    gh auth switch --hostname "$HOST" --user "$ACCOUNT" >/dev/null || {
      err "Failed to switch the GitHub account."
      exit 1
    }
  fi
}

ensure_api_ready() {
  local status_output=""
  local limit=""
  local remaining=""
  local auth_status_ok=1

  if ! status_output="$(gh auth status --hostname "$HOST" 2>&1)"; then
    auth_status_ok=0
    warn "GitHub authentication for $HOST looks invalid or expired."
  fi

  limit="$(gh api --hostname "$HOST" rate_limit --jq '.resources.core.limit' 2>/dev/null || printf '')"
  remaining="$(gh api --hostname "$HOST" rate_limit --jq '.resources.core.remaining' 2>/dev/null || printf '')"

  if [[ ! "$remaining" =~ ^[0-9]+$ ]]; then
    if [[ "$auth_status_ok" -eq 0 ]]; then
      warn "Stored gh auth status looks stale. Live API check failed too."
      printf '%s\n' "$status_output" >&2
    fi
    err "GitHub API access failed for $HOST. Run 'gh auth refresh --hostname $HOST --scopes repo,workflow' or 'gh auth login --hostname $HOST'."
    exit 1
  fi

  if [[ "$limit" =~ ^[0-9]+$ ]] && (( limit < 5000 )); then
    err "GitHub API access for $HOST appears unauthenticated or under-scoped. Refresh repo and workflow scopes and retry."
    exit 1
  fi

  if [[ "$auth_status_ok" -eq 0 ]]; then
    warn "Stored gh auth status looks stale, but live GitHub API access works. Continuing."
  fi
}

verify_repo_access() {
  local target_spec="$1"

  if ! gh repo view "$target_spec" --json nameWithOwner >/dev/null 2>&1; then
    err "Cannot access repository $target_spec on $HOST."
    return 1
  fi
}

normalize_import_mode() {
  local value="${1:-}"

  case "$value" in
    codespace|codespaces|codespace_to_local)
      printf 'codespace_to_local\n'
      ;;
    repo|repo_to_local)
      printf 'repo_to_local\n'
      ;;
    repo-plus|repo_plus|repo_to_local_plus)
      printf 'repo_to_local_plus\n'
      ;;
    *)
      return 1
      ;;
  esac
}

show_help() {
  cat <<EOF
$APP_NAME v$APP_VERSION
$APP_FULL_NAME
$APP_TAGLINE
Provided by $APP_VENDOR
$APP_VENDOR_URL
$APP_RISK_NOTICE

Usage:
  $(basename "$0")
  $(basename "$0") --help
  $(basename "$0") --version
  $(basename "$0") --about
  $(basename "$0") --notice
  $(basename "$0") --terms
  $(basename "$0") --privacy
  $(basename "$0") --disclaimer
  $(basename "$0") --profile public
  $(basename "$0") --profile wtl
  $(basename "$0") --profile diamond
  $(basename "$0") --browse
  $(basename "$0") --browse-projects
  $(basename "$0") --browse --use-current-root
  $(basename "$0") --browse-projects --use-current-root
  $(basename "$0") --browse-cost-control
  $(basename "$0") --browse-cost-control --use-current-root
  $(basename "$0") --browse-devcontainers
  $(basename "$0") --browse-devcontainers --use-current-root
  $(basename "$0") --profile diamond --host github.com --account USER --repo OWNER/REPO --import-mode codespace --import-full-auto
  $(basename "$0") --profile diamond --host github.com --account USER --repo OWNER/REPO --import-mode repo-plus --import-full-auto --import-cleanup-preview
  $(basename "$0") --repo OWNER/REPO --all --yes
  $(basename "$0") --profile diamond --repo OWNER/REPO --disable-workflows --delete-runs --delete-artifacts --delete-caches --delete-codespaces --yes
  $(basename "$0") --repo https://github.com/OWNER/REPO --delete-runs --run https://github.com/OWNER/REPO/actions/runs/123456789 --yes
  $(basename "$0") --host github.com --account USER --repo OWNER/REPO --delete-runs --run-filter "release" --dry-run --yes

What it does:
  - Scans the current machine before any install prompts
  - Checks for required Mac tooling
  - Supports Public, WTL, and Diamond editions
  - Selects an authenticated GitHub host and account
  - Saves a default workspace root per edition for next time
  - Explains the workspace/root layout, saved paths, and storage behavior from the root menu
  - Lets you choose one repo, all repos one by one, a FULL AUTO batch import, a FULL AUTO + cleanup preview batch import, or a manual repo
  - Supports direct noninteractive import commands for GUI/background use
  - Can create a starter .devcontainer if one is missing
  - Can test starting the local devcontainer
  - Can install a repo-level self-hosted Mac Actions runner
  - Can patch common GitHub-hosted runs-on values to self-hosted Mac labels
  - Can run generic GitHub cleanup for workflows, runs, artifacts, caches, and Codespaces
  - Can apply a recommended no-spend safeguard plan project by project from the browser
  - Can disable GitHub Actions at the repo settings level when you want a hard stop
  - Can stop local runner services and active local devcontainer containers
  - Supports dry-run cleanup previews before deleting anything
  - Can optionally commit and push workflow changes
  - Includes a browser for imported projects, active local containers, and local Actions runners
  - Lets you open an imported project in VS Code and optionally start its devcontainer
  - Can jump directly into imported projects, the full local browser, cost-control review, or installed devcontainers
  - Accepts cleaner-style direct cleanup flags for host, account, repo, workflows, runs, artifacts, caches, and Codespaces
  - Can be installed into ~/.local/bin on any supported Mac with the included install.sh
  - Returns to a main menu after single operations instead of exiting immediately
  - Restores your original GitHub account when the script exits if it switched accounts

Direct cleanup flags:
  --host HOST
  --account USER
  --repo TARGET
  --disable-workflows
  --delete-runs
  --run TARGET
  --run-filter TEXT
  --delete-artifacts
  --delete-caches
  --delete-codespaces
  --all
  --yes
  --dry-run
  --no-color

Direct import flags:
  --import-mode MODE
    MODE values:
      codespace
      repo
      repo-plus
  --import-full-auto
  --import-cleanup-preview

Built-in default roots:
  Public: $PUBLIC_DEFAULT_ROOT
  WTL: $WTL_DEFAULT_ROOT
  Diamond code: $DIAMOND_CODE_DEFAULT_ROOT
  Diamond runtime: $DIAMOND_RUNTIME_DEFAULT_ROOT

Wrapper scripts:
  install.sh
  uninstall.sh
  run-gui.sh
  build-gui-app.sh
  CSA-iLEM-Public.sh
  CSA-iLEM-WTL.sh
  CSA-iLEM-Diamond.sh
  CSA-iLEM-Open.sh
  openproj
  csa-iem
  csa-iem-public
  csa-iem-wtl
  csa-iem-diamond
  csa-iem-open
  csa-iem-gui
  csa-iem-build-gui
  csa-ilem
  csa-ilem-public
  csa-ilem-wtl
  csa-ilem-diamond
  csa-ilem-open
  csa-ilem-gui
  csa-ilem-build-gui

Folders created:
  Single-root editions:
    Repos/
    Reports/
    Backups/
    Runners/
    Scripts/
  Diamond code root:
    Repos/
  Diamond runtime root:
    Repos/
    Reports/
    Backups/
    Runners/
    Scripts/

Documents:
  Notice: $APP_NOTICE_FILE
  License: $SCRIPT_DIR/LICENSE.txt
  Terms: $APP_TERMS_FILE
  Privacy: $APP_PRIVACY_FILE
  Disclaimer: $APP_DISCLAIMER_FILE
EOF
}

ensure_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    err "$APP_NAME is for macOS only."
    exit 1
  fi
}

print_scan_item() {
  local label="$1"
  local value="$2"
  printf '  %-18s %s\n' "$label" "$value"
}

docker_engine_ready() {
  docker info >/dev/null 2>&1
}

show_preflight_scan() {
  local vscode_app=""
  local docker_app=""
  local github_auth_status="not available"

  vscode_app="$(find_vscode_app || true)"
  docker_app="$(find_docker_app || true)"

  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      github_auth_status="signed in"
    else
      github_auth_status="installed, not signed in"
    fi
  else
    github_auth_status="gh not installed"
  fi

  echo
  print_line
  echo "Preflight Scan"
  print_line
  if command -v brew >/dev/null 2>&1; then
    print_scan_item "Homebrew" "installed"
  else
    print_scan_item "Homebrew" "missing"
  fi
  if command -v git >/dev/null 2>&1; then
    print_scan_item "git" "available"
  else
    print_scan_item "git" "missing"
  fi
  if command -v gh >/dev/null 2>&1; then
    print_scan_item "gh CLI" "available"
  else
    print_scan_item "gh CLI" "missing"
  fi
  print_scan_item "GitHub auth" "$github_auth_status"
  if [[ -n "$vscode_app" ]]; then
    print_scan_item "VS Code app" "$vscode_app"
  else
    print_scan_item "VS Code app" "missing"
  fi
  if command -v code >/dev/null 2>&1; then
    print_scan_item "code CLI" "available"
  elif [[ -n "$vscode_app" ]]; then
    print_scan_item "code CLI" "missing, can be linked from app"
  else
    print_scan_item "code CLI" "missing"
  fi
  if [[ -n "$docker_app" ]]; then
    print_scan_item "Docker app" "$docker_app"
  else
    print_scan_item "Docker app" "missing"
  fi
  if command -v docker >/dev/null 2>&1; then
    print_scan_item "docker CLI" "available"
  elif [[ -n "$docker_app" ]]; then
    print_scan_item "docker CLI" "missing, will try to link from app"
  else
    print_scan_item "docker CLI" "missing"
  fi
  if command -v docker >/dev/null 2>&1; then
    if docker_engine_ready; then
      print_scan_item "Docker engine" "running"
    else
      print_scan_item "Docker engine" "not running"
    fi
  fi
  if command -v node >/dev/null 2>&1; then
    print_scan_item "Node.js" "available"
  else
    print_scan_item "Node.js" "missing"
  fi
  if command -v npm >/dev/null 2>&1; then
    print_scan_item "npm" "available"
  else
    print_scan_item "npm" "missing"
  fi
  if command -v devcontainer >/dev/null 2>&1; then
    print_scan_item "devcontainer" "available"
  else
    print_scan_item "devcontainer" "missing"
  fi
  echo
}

install_brew_if_missing() {
  if command -v brew >/dev/null 2>&1; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    return
  fi

  warn "Homebrew is not installed."
  if ! confirm "Install Homebrew now?"; then
    err "Homebrew is required."
    exit 1
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    err "Homebrew installed but was not found in the standard paths."
    exit 1
  fi
}

ensure_brew_shellenv_in_profile() {
  local brew_line=""
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_line='eval "$(/opt/homebrew/bin/brew shellenv)"'
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_line='eval "$(/usr/local/bin/brew shellenv)"'
  fi

  if [[ -n "$brew_line" ]]; then
    ensure_profile_line "$HOME/.zprofile" "$brew_line"
  fi
}

ensure_user_bin_on_path() {
  local path_line='export PATH="$HOME/.local/bin:$PATH"'
  mkdir -p "$USER_BIN_DIR"
  case ":$PATH:" in
    *":$USER_BIN_DIR:"*) ;;
    *) export PATH="$USER_BIN_DIR:$PATH" ;;
  esac
  ensure_profile_line "$HOME/.zprofile" "$path_line"
}

brew_formula_installed() {
  local brew_name="$1"
  brew list --formula "$brew_name" >/dev/null 2>&1
}

brew_cask_installed() {
  local brew_name="$1"
  brew list --cask "$brew_name" >/dev/null 2>&1
}

find_vscode_app() {
  local candidate=""
  for candidate in \
    "/Applications/Visual Studio Code.app" \
    "$HOME/Applications/Visual Studio Code.app"
  do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_docker_app() {
  local candidate=""
  for candidate in \
    "/Applications/Docker.app" \
    "$HOME/Applications/Docker.app"
  do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

open_docker_desktop_app() {
  if [[ -d "/Applications/Docker.app" || -d "$HOME/Applications/Docker.app" ]]; then
    open -a "Docker" || true
  fi
}

prompt_finish_docker_desktop_setup() {
  local docker_app=""
  local choice=""

  docker_app="$(find_docker_app || true)"

  while true; do
    if docker_engine_ready; then
      info "Docker is running."
      return 0
    fi

    if [[ "$FULL_AUTO" -eq 1 ]]; then
      open_docker_desktop_app
      warn "FULL AUTO cannot wait for manual Docker Desktop onboarding. Skipping this Docker-dependent step."
      return 1
    fi

    echo
    print_line
    echo "Docker Desktop Setup"
    print_line
    if [[ -n "$docker_app" ]]; then
      printf 'Docker app: %s\n' "$docker_app"
    fi
    echo "Docker Desktop may still need first-time setup."
    echo "Complete any onboarding, permissions, privileged helper, file-sharing, or sign-in prompts."
    echo "Wait until Docker Desktop shows the engine is running."
    echo
    echo "Options:"
    echo "  O) Open Docker Desktop"
    echo "  Y) I finished setup/login, retry Docker"
    echo "  S) Skip this Docker-dependent step"
    read -r -p "Choose [O/Y/S]: " choice

    case "$choice" in
      o|O)
        open_docker_desktop_app
        ;;
      y|Y|"")
        if docker_engine_ready; then
          info "Docker is running."
          return 0
        fi
        warn "Docker is still not ready."
        ;;
      s|S)
        warn "Skipping the Docker-dependent step."
        return 1
        ;;
      *)
        warn "Invalid choice."
        ;;
    esac
  done
}

link_cli_into_user_bin() {
  local source_path="$1"
  local target_name="$2"
  ensure_user_bin_on_path
  ln -sf "$source_path" "$USER_BIN_DIR/$target_name"
}

install_tool_if_missing() {
  local cmd="$1"
  local brew_name="$2"
  local kind="${3:-formula}"

  if command -v "$cmd" >/dev/null 2>&1; then
    return
  fi

  if [[ "$kind" == "cask" ]] && brew_cask_installed "$brew_name"; then
    info "$brew_name is already installed via Homebrew cask."
    return
  fi

  if [[ "$kind" != "cask" ]] && brew_formula_installed "$brew_name"; then
    info "$brew_name is already installed via Homebrew."
    return
  fi

  if ! confirm "$cmd is missing. Install $brew_name with Homebrew now?"; then
    err "$cmd is required."
    exit 1
  fi

  if [[ "$kind" == "cask" ]]; then
    brew install --cask "$brew_name"
  else
    brew install "$brew_name"
  fi
}

ensure_vscode_cli() {
  local app_path=""
  local cli_path=""

  if command -v code >/dev/null 2>&1; then
    return
  fi

  app_path="$(find_vscode_app || true)"
  if [[ -n "$app_path" ]]; then
    cli_path="$app_path/Contents/Resources/app/bin/code"
    if [[ -x "$cli_path" ]]; then
      link_cli_into_user_bin "$cli_path" "code"
      if command -v code >/dev/null 2>&1; then
        info "Using the existing Visual Studio Code app and linked the 'code' CLI."
        return
      fi
    fi
  fi

  if ! brew_cask_installed "visual-studio-code"; then
    if ! confirm "Visual Studio Code is missing. Install it with Homebrew now?"; then
      err "Visual Studio Code is required."
      exit 1
    fi
    brew install --cask visual-studio-code
  else
    info "visual-studio-code is already installed via Homebrew cask."
  fi

  app_path="$(find_vscode_app || true)"
  if [[ -n "$app_path" ]]; then
    cli_path="$app_path/Contents/Resources/app/bin/code"
    if [[ -x "$cli_path" ]]; then
      link_cli_into_user_bin "$cli_path" "code"
    fi
  fi

  require_cmd code "Visual Studio Code is installed, but the 'code' CLI is still missing. Open VS Code and run 'Shell Command: Install code command in PATH', or rerun this script."
}

ensure_docker_cli() {
  local app_path=""
  local cli_path=""

  if command -v docker >/dev/null 2>&1; then
    return
  fi

  app_path="$(find_docker_app || true)"
  if [[ -n "$app_path" ]]; then
    for cli_path in \
      "$app_path/Contents/Resources/bin/docker" \
      "$app_path/Contents/MacOS/com.docker.cli"
    do
      if [[ -x "$cli_path" ]]; then
        link_cli_into_user_bin "$cli_path" "docker"
        break
      fi
    done

    if command -v docker >/dev/null 2>&1; then
      info "Using the existing Docker app and linked the 'docker' CLI."
      return
    fi
  fi

  if ! brew_cask_installed "docker"; then
    if ! confirm "Docker Desktop is missing. Install it with Homebrew now?"; then
      err "Docker Desktop is required."
      exit 1
    fi
    brew install --cask docker
    DOCKER_INSTALLED_THIS_RUN=1
  else
    info "docker is already installed via Homebrew cask."
  fi

  app_path="$(find_docker_app || true)"
  if [[ -n "$app_path" ]]; then
    for cli_path in \
      "$app_path/Contents/Resources/bin/docker" \
      "$app_path/Contents/MacOS/com.docker.cli"
    do
      if [[ -x "$cli_path" ]]; then
        link_cli_into_user_bin "$cli_path" "docker"
        break
      fi
    done
  fi

  if [[ "$DOCKER_INSTALLED_THIS_RUN" -eq 1 ]]; then
    info "Docker Desktop was installed in this run."
    open_docker_desktop_app
    if ! prompt_finish_docker_desktop_setup; then
      warn "Docker Desktop setup is not complete yet."
    fi
  fi

  require_cmd docker "Docker Desktop is installed, but the 'docker' CLI is still missing. Open Docker Desktop once and rerun this script."
}

ensure_devcontainers_cli() {
  if command -v devcontainer >/dev/null 2>&1; then
    return
  fi

  if ! command -v npm >/dev/null 2>&1; then
    install_tool_if_missing node node
  fi

  if ! confirm "Dev Containers CLI is missing. Install it with npm now?"; then
    err "The devcontainer CLI is required for local Codespaces-style setup."
    exit 1
  fi

  require_cmd npm "Install Node.js first."
  npm install -g @devcontainers/cli
}

ensure_docker_ready_for_devcontainers() {
  require_cmd docker "Install Docker Desktop first."

  if docker_engine_ready; then
    info "Docker is running."
    return 0
  fi

  warn "Docker is required only for devcontainer build/test steps, and the engine is not ready."
  open_docker_desktop_app
  prompt_finish_docker_desktop_setup
}

apply_single_root_layout() {
  ROOT="$1"
  CODE_ROOT="$ROOT"
  RUNTIME_ROOT="$ROOT"
  REPOS_DIR="$ROOT/Repos"
  CODE_REPOS_DIR="$REPOS_DIR"
  RUNTIME_REPOS_DIR="$REPOS_DIR"
  REPORTS_DIR="$ROOT/Reports"
  BACKUPS_DIR="$ROOT/Backups"
  RUNNERS_DIR="$ROOT/Runners"
  SCRIPTS_DIR="$ROOT/Scripts"

  mkdir -p "$REPOS_DIR" "$REPORTS_DIR" "$BACKUPS_DIR" "$RUNNERS_DIR" "$SCRIPTS_DIR"
}

apply_diamond_root_layout() {
  CODE_ROOT="$1"
  RUNTIME_ROOT="$2"
  ROOT="$RUNTIME_ROOT"
  CODE_REPOS_DIR="$CODE_ROOT/Repos"
  RUNTIME_REPOS_DIR="$RUNTIME_ROOT/Repos"
  REPOS_DIR="$RUNTIME_REPOS_DIR"
  REPORTS_DIR="$RUNTIME_ROOT/Reports"
  BACKUPS_DIR="$RUNTIME_ROOT/Backups"
  RUNNERS_DIR="$RUNTIME_ROOT/Runners"
  SCRIPTS_DIR="$RUNTIME_ROOT/Scripts"

  mkdir -p "$CODE_REPOS_DIR" "$RUNTIME_REPOS_DIR" "$REPORTS_DIR" "$BACKUPS_DIR" "$RUNNERS_DIR" "$SCRIPTS_DIR"
}

apply_root_layout() {
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    apply_diamond_root_layout "$1" "$2"
  else
    apply_single_root_layout "$1"
  fi
}

show_workspace_root_guide() {
  local effective_root="$1"
  local effective_code_root="$2"
  local effective_runtime_root="$3"

  echo
  print_line
  echo "Workspace Root Guide"
  print_line
  echo "What $APP_NAME does:"
  echo "- Clones GitHub repos into local workspaces."
  echo "- Prepares local devcontainers / Codespaces-style runtime workspaces."
  echo "- Installs repo-level self-hosted GitHub Actions runners."
  echo "- Saves reports and workflow backups for repeatable local operations."
  echo
  echo "Why $APP_NAME uses these folders:"
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    echo "- The code root stays clean for normal editing, Codex, and CLI work."
    echo "- The runtime root is isolated for local Codespaces-style work, containers, reports, backups, and runners."
    echo "- This keeps runtime/container state out of the plain code workspace."
  else
    echo "- One root keeps repos, reports, backups, runners, and helper scripts together."
    echo "- This makes the whole local setup portable and predictable."
  fi
  echo
  echo "Where $APP_NAME saves files:"
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    printf '  Plain repo clones: %s/Repos/<owner>/<repo>\n' "$effective_code_root"
    printf '  Runtime workspaces: %s/Repos/<owner>/<repo>\n' "$effective_runtime_root"
    printf '  Reports: %s/Reports\n' "$effective_runtime_root"
    printf '  Workflow backups: %s/Backups\n' "$effective_runtime_root"
    printf '  Local runners: %s/Runners/<owner>/<repo>\n' "$effective_runtime_root"
    printf '  Helper scripts: %s/Scripts\n' "$effective_runtime_root"
  else
    printf '  Repo clones: %s/Repos/<owner>/<repo>\n' "$effective_root"
    printf '  Reports: %s/Reports\n' "$effective_root"
    printf '  Workflow backups: %s/Backups\n' "$effective_root"
    printf '  Local runners: %s/Runners/<owner>/<repo>\n' "$effective_root"
    printf '  Helper scripts: %s/Scripts\n' "$effective_root"
  fi
  echo
  echo "Other places $APP_NAME may write:"
  printf '  Saved root settings: %s/%s.env\n' "$CONFIG_DIR" "$PROFILE_NAME"
  echo "  macOS runner services: ~/Library/LaunchAgents/"
  echo "  macOS runner logs: ~/Library/Logs/"
  echo
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    echo "Diamond meaning:"
    printf '  %s = plain repo/code side\n' "$effective_code_root"
    printf '  %s = runtime / local Codespace / container side\n' "$effective_runtime_root"
    echo
  fi
  echo "Important behavior:"
  echo "- Starter .devcontainer files are created only in the runtime workspace."
  echo "- Workflow patching happens in the plain repo clone."
  echo "- Reports are written after each processed repo."
  echo "- Cleanup only deletes GitHub resources after explicit confirmation."
  echo "- Browse is in the Main Menu after you finish root selection."
  echo
  pause
}

prompt_custom_root_value() {
  local fallback_default="$1"
  local custom_value=""
  local prompt_label="$2"

  if [[ "$PROFILE_NAME" == "public" ]] && confirm "Use example custom root ($PUBLIC_CUSTOM_EXAMPLE_ROOT) as the starting value?"; then
    fallback_default="$PUBLIC_CUSTOM_EXAMPLE_ROOT"
  fi

  custom_value="$(prompt_nonempty "$prompt_label" "$fallback_default")"
  printf '%s' "$custom_value"
}

use_current_root_defaults() {
  local effective_default=""
  local effective_code_root=""
  local effective_runtime_root=""

  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    effective_code_root="$(current_default_code_root)"
    effective_runtime_root="$(current_default_runtime_root)"
    apply_root_layout "$effective_code_root" "$effective_runtime_root"
  else
    effective_default="$(current_default_root)"
    apply_root_layout "$effective_default"
  fi

  echo
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    info "Using Diamond roots:"
    printf 'Code root: %s\n' "$CODE_ROOT"
    printf 'Runtime root: %s\n' "$RUNTIME_ROOT"
  else
    info "Using workspace root:"
    printf '%s\n' "$ROOT"
  fi
}

choose_root() {
  local effective_default=""
  local built_in_default=""
  local choice=""
  local custom_root=""
  local effective_code_root=""
  local effective_runtime_root=""
  local custom_code_root=""
  local custom_runtime_root=""

  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    effective_code_root="$(current_default_code_root)"
    effective_runtime_root="$(current_default_runtime_root)"
  else
    effective_default="$(current_default_root)"
    built_in_default="$DEFAULT_ROOT"
  fi

  echo
  print_line
  echo "Workspace Root"
  print_line
  printf 'Edition: %s\n' "$PROFILE_LABEL"
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    printf 'Built-in code root: %s\n' "$DEFAULT_CODE_ROOT"
    printf 'Built-in runtime root: %s\n' "$DEFAULT_RUNTIME_ROOT"
    if [[ -n "$SAVED_CODE_ROOT" ]]; then
      printf 'Saved code root: %s\n' "$SAVED_CODE_ROOT"
    fi
    if [[ -n "$SAVED_RUNTIME_ROOT" ]]; then
      printf 'Saved runtime root: %s\n' "$SAVED_RUNTIME_ROOT"
    fi
  else
    printf 'Built-in default: %s\n' "$built_in_default"
    if [[ -n "$SAVED_DEFAULT_ROOT" ]]; then
      printf 'Saved default: %s\n' "$SAVED_DEFAULT_ROOT"
    fi
  fi
  echo
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    echo "Press Enter to use the current Diamond roots and continue to the Main Menu."
    echo "1) Use current Diamond roots"
    echo "2) Set my own default Diamond roots for next time"
    echo "3) Use one-time Diamond roots"
    echo "4) Reset the saved Diamond roots back to the built-in defaults"
    echo "5) Explain how $APP_NAME works, why it uses these folders, and where it saves files"
  else
    echo "Press Enter to use the current default root and continue to the Main Menu."
    echo "1) Use current default root"
    echo "2) Set my own default root for next time"
    echo "3) Use a one-time custom root"
    echo "4) Reset the saved default back to the built-in default"
    echo "5) Explain how $APP_NAME works, why it uses this root, and where it saves files"
  fi
  echo

  while true; do
    read -r -p "Enter choice [1-5] (Enter = 1): " choice
    case "$choice" in
      ""|1)
        if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
          apply_root_layout "$effective_code_root" "$effective_runtime_root"
        else
          apply_root_layout "$effective_default"
        fi
        break
        ;;
      2)
        if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
          custom_code_root="$(prompt_nonempty "Enter the default code root path" "$effective_code_root")"
          custom_runtime_root="$(prompt_nonempty "Enter the default runtime root path" "$effective_runtime_root")"
          SAVED_CODE_ROOT="$custom_code_root"
          SAVED_RUNTIME_ROOT="$custom_runtime_root"
          SAVED_DEFAULT_ROOT=""
          save_profile_config
          apply_root_layout "$custom_code_root" "$custom_runtime_root"
        else
          custom_root="$(prompt_custom_root_value "$effective_default" "Enter the default root path")"
          SAVED_DEFAULT_ROOT="$custom_root"
          SAVED_CODE_ROOT=""
          SAVED_RUNTIME_ROOT=""
          save_profile_config
          apply_root_layout "$custom_root"
        fi
        info "Saved the default root for the $PROFILE_LABEL edition."
        break
        ;;
      3)
        if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
          custom_code_root="$(prompt_nonempty "Enter the one-time code root path" "$effective_code_root")"
          custom_runtime_root="$(prompt_nonempty "Enter the one-time runtime root path" "$effective_runtime_root")"
          apply_root_layout "$custom_code_root" "$custom_runtime_root"
        else
          custom_root="$(prompt_custom_root_value "$effective_default" "Enter the one-time root path")"
          apply_root_layout "$custom_root"
        fi
        break
        ;;
      4)
        if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
          SAVED_CODE_ROOT=""
          SAVED_RUNTIME_ROOT=""
          SAVED_DEFAULT_ROOT=""
          save_profile_config
          apply_root_layout "$DEFAULT_CODE_ROOT" "$DEFAULT_RUNTIME_ROOT"
        else
          SAVED_DEFAULT_ROOT=""
          SAVED_CODE_ROOT=""
          SAVED_RUNTIME_ROOT=""
          save_profile_config
          apply_root_layout "$built_in_default"
        fi
        info "Reset the saved default root for the $PROFILE_LABEL edition."
        break
        ;;
      5)
        show_workspace_root_guide "$effective_default" "$effective_code_root" "$effective_runtime_root"
        ;;
      *)
        warn "Invalid choice."
        ;;
    esac
  done

  echo
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    info "Using Diamond roots:"
    printf 'Code root: %s\n' "$CODE_ROOT"
    printf 'Runtime root: %s\n' "$RUNTIME_ROOT"
  else
    info "Using workspace root:"
    printf '%s\n' "$ROOT"
  fi
}

choose_mode() {
  local choice
  while true; do
    echo
    print_line
    echo "Migration Mode"
    print_line
    echo "1) Codespace -> Local"
    echo "2) Repo -> Local"
    echo "3) Repo -> Local + local devcontainer + local Actions prep"
    echo "4) Cleanup only (workflows, runs, artifacts, caches, Codespaces)"
    echo
    read -r -p "Enter choice [1-4]: " choice

    case "$choice" in
      1) MODE="codespace_to_local"; return 0 ;;
      2) MODE="repo_to_local"; return 0 ;;
      3) MODE="repo_to_local_plus"; return 0 ;;
      4) MODE="cleanup_only"; return 0 ;;
      *) warn "Invalid choice." ;;
    esac
  done
}

load_repo_list() {
  REPO_LIST=()
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      REPO_LIST+=("$line")
    fi
  done < <(GH_HOST="$HOST" gh repo list --limit 200 --json nameWithOwner --jq '.[].nameWithOwner')

  if [[ "${#REPO_LIST[@]}" -eq 0 ]]; then
    err "No repositories were returned for the current GitHub account."
    exit 1
  fi
}

show_repo_list() {
  local i=1
  echo
  print_line
  echo "Available Repositories"
  print_line
  for repo_item in "${REPO_LIST[@]}"; do
    printf '%3d) %s\n' "$i" "$repo_item"
    i=$((i + 1))
  done
  echo
}

choose_repositories() {
  local repo_choice=""
  local repo_index=""
  local start_index=""
  local manual_owner=""
  local manual_repo=""
  local normalized=""

  FULL_AUTO=0
  FULL_AUTO_CLEANUP=0

  while true; do
    echo
    print_line
    echo "Repository Selection"
    print_line
    if [[ "$MODE" == "cleanup_only" ]]; then
      echo "1) One repo at a time from my GitHub repo list"
      echo "2) All repos one by one from my GitHub repo list"
      echo "3) Enter one repo manually"
    else
      echo "1) One repo at a time from my GitHub repo list"
      echo "2) All repos one by one from my GitHub repo list"
      echo "3) All repos one by one from my GitHub repo list (FULL AUTO)"
      echo "4) All repos one by one from my GitHub repo list (FULL AUTO + CLEANUP PREVIEW)"
      echo "5) Enter one repo manually"
    fi
    echo
    if [[ "$MODE" == "cleanup_only" ]]; then
      read -r -p "Enter choice [1-3]: " repo_choice
    else
      read -r -p "Enter choice [1-5]: " repo_choice
    fi

    case "$repo_choice" in
      1)
        FULL_AUTO=0
        FULL_AUTO_CLEANUP=0
        load_repo_list
        show_repo_list
        read -r -p "Enter repo number: " repo_index
        case "$repo_index" in
          ''|*[!0-9]*)
            warn "Invalid selection."
            continue
            ;;
        esac
        if [[ "$repo_index" -lt 1 || "$repo_index" -gt "${#REPO_LIST[@]}" ]]; then
          warn "Selection is out of range."
          continue
        fi
        SELECTED_REPOS=("${REPO_LIST[$((repo_index - 1))]}")
        return 0
        ;;
      2)
        FULL_AUTO=0
        FULL_AUTO_CLEANUP=0
        load_repo_list
        printf 'Total repositories found: %s\n' "${#REPO_LIST[@]}"
        read -r -p "Start from repo number [1-${#REPO_LIST[@]}] (Enter = 1): " start_index
        case "$start_index" in
          "")
            start_index=1
            ;;
          *[!0-9]*)
            warn "Invalid start number."
            continue
            ;;
        esac
        if [[ "$start_index" -lt 1 || "$start_index" -gt "${#REPO_LIST[@]}" ]]; then
          warn "Start number is out of range."
          continue
        fi
        SELECTED_REPOS=("${REPO_LIST[@]:$((start_index - 1))}")
        return 0
        ;;
      3)
        if [[ "$MODE" == "cleanup_only" ]]; then
          FULL_AUTO=0
          FULL_AUTO_CLEANUP=0
          read -r -p "GitHub owner or org, or paste a full GitHub repo URL: " manual_owner
          read -r -p "Repository name (leave blank if you pasted a full URL): " manual_repo
          if ! normalized="$(normalize_repo_input "$manual_owner" "$manual_repo")"; then
            continue
          fi
          OWNER="${normalized%%/*}"
          REPO="${normalized#*/}"
          SELECTED_REPOS=("$OWNER/$REPO")
          return 0
        else
          FULL_AUTO=1
          FULL_AUTO_CLEANUP=0
          load_repo_list
          printf 'Total repositories found: %s\n' "${#REPO_LIST[@]}"
          read -r -p "Start from repo number [1-${#REPO_LIST[@]}] (Enter = 1): " start_index
          case "$start_index" in
            "")
              start_index=1
              ;;
            *[!0-9]*)
              warn "Invalid start number."
              continue
              ;;
          esac
          if [[ "$start_index" -lt 1 || "$start_index" -gt "${#REPO_LIST[@]}" ]]; then
            warn "Start number is out of range."
            continue
          fi
          SELECTED_REPOS=("${REPO_LIST[@]:$((start_index - 1))}")
          info "FULL AUTO is enabled for this batch."
          info "Import/prep prompts will auto-confirm, quick devcontainer checks will be used, and cleanup prompts will be skipped."
          return 0
        fi
        ;;
      4)
        if [[ "$MODE" == "cleanup_only" ]]; then
          warn "Invalid selection."
          continue
        fi
        FULL_AUTO=1
        FULL_AUTO_CLEANUP=1
        load_repo_list
        printf 'Total repositories found: %s\n' "${#REPO_LIST[@]}"
        read -r -p "Start from repo number [1-${#REPO_LIST[@]}] (Enter = 1): " start_index
        case "$start_index" in
          "")
            start_index=1
            ;;
          *[!0-9]*)
            warn "Invalid start number."
            continue
            ;;
        esac
        if [[ "$start_index" -lt 1 || "$start_index" -gt "${#REPO_LIST[@]}" ]]; then
          warn "Start number is out of range."
          continue
        fi
        SELECTED_REPOS=("${REPO_LIST[@]:$((start_index - 1))}")
        info "FULL AUTO + CLEANUP PREVIEW is enabled for this batch."
        info "Import/prep prompts will auto-confirm, quick devcontainer checks will be used, and cleanup will auto-run as a dry-run preview."
        return 0
        ;;
      5)
        FULL_AUTO=0
        FULL_AUTO_CLEANUP=0
        read -r -p "GitHub owner or org, or paste a full GitHub repo URL: " manual_owner
        read -r -p "Repository name (leave blank if you pasted a full URL): " manual_repo
        if ! normalized="$(normalize_repo_input "$manual_owner" "$manual_repo")"; then
          continue
        fi
        OWNER="${normalized%%/*}"
        REPO="${normalized#*/}"
        SELECTED_REPOS=("$OWNER/$REPO")
        return 0
        ;;
      *)
        warn "Invalid selection."
        ;;
    esac
  done
}

repo_has_devcontainer_file() {
  [[ -f "$1/.devcontainer/devcontainer.json" ]]
}

project_is_git_repo() {
  [[ -d "$1/.git" || -f "$1/.git" ]]
}

project_remote_origin() {
  git -C "$1" config --get remote.origin.url 2>/dev/null || true
}

project_is_github_import() {
  local remote_url=""

  remote_url="$(project_remote_origin "$1")"
  [[ "$remote_url" == *"github.com"* ]]
}

project_has_devcontainer_file() {
  local repo_path="$1"
  [[ -n "$repo_path" && -f "$repo_path/.devcontainer/devcontainer.json" ]]
}

project_has_generated_devcontainer() {
  [[ -f "$1/.devcontainer/.csa-ilem-generated" ]]
}

project_is_codespaces_ready() {
  local repo_path="$1"

  repo_has_devcontainer_file "$repo_path" && project_is_github_import "$repo_path" && ! project_has_generated_devcontainer "$repo_path"
}

devcontainer_config_has_post_create() {
  [[ -f "$1/.devcontainer/devcontainer.json" ]] && grep -Fq '"postCreateCommand"' "$1/.devcontainer/devcontainer.json"
}

devcontainer_config_uses_dind() {
  [[ -f "$1/.devcontainer/devcontainer.json" ]] && grep -Fq 'docker-in-docker' "$1/.devcontainer/devcontainer.json"
}

devcontainer_cli_supports_skip_post_create() {
  command -v devcontainer >/dev/null 2>&1 || return 1
  devcontainer up --help 2>/dev/null | grep -q -- '--skip-post-create'
}

normalize_remote_slug() {
  local remote="$1"
  local normalized=""

  normalized="${remote#git@}"
  normalized="${normalized#ssh://git@}"
  normalized="${normalized#ssh://}"
  normalized="${normalized#https://}"
  normalized="${normalized#http://}"
  normalized="${normalized#www.}"

  case "$normalized" in
    *:*)
      normalized="${normalized#*:}"
      ;;
    */*)
      normalized="${normalized#*/}"
      ;;
  esac

  normalized="${normalized%.git}"
  normalized="${normalized#/}"
  normalized="$(trim "$normalized")"

  case "$normalized" in
    */*)
      printf '%s' "$normalized"
      return 0
      ;;
  esac

  return 1
}

project_slug_from_repo_dir() {
  local repo_path="$1"
  local remote_url=""
  local root_candidate=""
  local relative_path=""
  local owner=""
  local repo=""
  local seen_roots="|"

  remote_url="$(git -C "$repo_path" config --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    if normalize_remote_slug "$remote_url" >/dev/null 2>&1; then
      normalize_remote_slug "$remote_url"
      return 0
    fi
  fi

  for root_candidate in "$CODE_REPOS_DIR" "$RUNTIME_REPOS_DIR" "$REPOS_DIR"; do
    [[ -n "$root_candidate" ]] || continue
    [[ "$seen_roots" == *"|$root_candidate|"* ]] && continue
    seen_roots="${seen_roots}${root_candidate}|"
    if [[ "$repo_path" == "$root_candidate/"* ]]; then
      relative_path="${repo_path#"$root_candidate/"}"
      owner="$(printf '%s' "$relative_path" | awk -F'/' '{print $1}')"
      repo="$(basename "$repo_path")"
      if [[ -n "$owner" && -n "$repo" ]]; then
        printf '%s/%s' "$owner" "$repo"
        return 0
      fi
    fi
  done

  printf 'local/%s' "$(basename "$repo_path")"
}

runner_dir_for_slug() {
  local slug="$1"
  local owner="${slug%/*}"
  local repo="${slug#*/}"
  printf '%s/%s/%s' "$RUNNERS_DIR" "$owner" "$repo"
}

runner_service_status_output_for_dir() {
  local runner_path="$1"

  [[ -x "$runner_path/svc.sh" ]] || return 1
  (
    cd "$runner_path" && ./svc.sh status 2>&1
  ) || true
}

runner_service_status_state_for_dir() {
  local runner_path="$1"
  local output=""
  local status_code=0

  if [[ ! -x "$runner_path/svc.sh" ]]; then
    printf 'missing-helper'
    return 0
  fi

  output="$(
    cd "$runner_path" && ./svc.sh status 2>&1
  )" || status_code=$?

  if [[ "$output" == *"not installed"* ]]; then
    printf 'not-installed'
  elif [[ "$status_code" -eq 0 ]]; then
    printf 'running'
  elif [[ "$output" == *"stopped"* || "$output" == *"not running"* ]]; then
    printf 'stopped'
  else
    printf 'configured'
  fi
}

repo_runner_configured() {
  local slug="$1"
  local runner_path=""

  runner_path="$(runner_dir_for_slug "$slug")"
  [[ -f "$runner_path/.runner" ]]
}

repo_active_container_count() {
  local repo_path="$1"

  if ! command -v docker >/dev/null 2>&1; then
    printf '0'
    return 0
  fi

  if ! docker_engine_ready; then
    printf '0'
    return 0
  fi

  docker ps --filter "label=devcontainer.local_folder=$repo_path" --format '{{.ID}}' 2>/dev/null | awk 'NF {count++} END {print count+0}'
}

repo_active_container_ids() {
  local repo_path="$1"

  if [[ -z "$repo_path" ]]; then
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi

  if ! docker_engine_ready; then
    return 0
  fi

  docker ps --filter "label=devcontainer.local_folder=$repo_path" --format '{{.ID}}' 2>/dev/null | awk 'NF {print}'
}

project_plain_repo_dir_for_slug() {
  local slug="$1"
  local code_dir=""
  local runtime_dir=""

  code_dir="$(project_code_dir_for_slug "$slug")"
  runtime_dir="$(project_runtime_dir_for_slug "$slug")"

  if [[ -n "$code_dir" ]]; then
    printf '%s' "$code_dir"
  else
    printf '%s' "$runtime_dir"
  fi
}

project_runtime_workspace_dir_for_slug() {
  local slug="$1"
  local runtime_dir=""
  local code_dir=""

  runtime_dir="$(project_runtime_dir_for_slug "$slug")"
  code_dir="$(project_code_dir_for_slug "$slug")"

  if [[ -n "$runtime_dir" ]]; then
    printf '%s' "$runtime_dir"
  else
    printf '%s' "$code_dir"
  fi
}

project_workspace_has_devcontainer_by_slug() {
  local slug="$1"
  local workspace_dir=""

  workspace_dir="$(project_runtime_workspace_dir_for_slug "$slug")"
  project_has_devcontainer_file "$workspace_dir"
}

project_status_summary() {
  local slug="$1"
  local parts=()
  local active_count="0"
  local code_dir=""
  local workspace_dir=""

  code_dir="$(project_code_dir_for_slug "$slug")"
  workspace_dir="$(project_dev_workspace_dir_for_slug "$slug")"

  if [[ -n "$code_dir" && -n "$workspace_dir" && "$code_dir" != "$workspace_dir" ]]; then
    parts+=("split")
  elif [[ -n "$code_dir" ]]; then
    parts+=("code")
  elif [[ -n "$workspace_dir" ]]; then
    parts+=("runtime")
  fi

  if project_is_codespaces_ready_by_slug "$slug"; then
    parts+=("codespaces-ready")
  elif project_has_generated_devcontainer_by_slug "$slug"; then
    parts+=("local-starter")
  elif [[ -n "$workspace_dir" ]] && repo_has_devcontainer_file "$workspace_dir"; then
    parts+=("devcontainer")
  fi

  if project_is_github_import_by_slug "$slug"; then
    parts+=("github")
  fi

  active_count="$(project_active_container_count_for_slug "$slug")"
  if [[ "$active_count" =~ ^[0-9]+$ ]] && (( active_count > 0 )); then
    parts+=("active:$active_count")
  fi

  if repo_runner_configured "$slug"; then
    parts+=("runner")
  fi

  if [[ "${#parts[@]}" -eq 0 ]]; then
    printf 'plain'
  else
    printf '%s' "${parts[*]}" | tr ' ' ','
  fi
}

find_imported_project_index_by_slug() {
  local slug="$1"
  local idx=0

  while [[ "$idx" -lt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    if [[ "${IMPORTED_PROJECT_SLUGS[$idx]}" == "$slug" ]]; then
      printf '%s' "$idx"
      return 0
    fi
    idx=$((idx + 1))
  done

  return 1
}

add_imported_project() {
  local slug="$1"
  local repo_path="$2"
  local role="$3"
  local idx=""

  [[ -n "$slug" && -n "$repo_path" ]] || return 0

  if idx="$(find_imported_project_index_by_slug "$slug" 2>/dev/null)"; then
    :
  else
    idx="${#IMPORTED_PROJECT_SLUGS[@]}"
    IMPORTED_PROJECT_SLUGS+=("$slug")
    IMPORTED_PROJECT_CODE_DIRS+=("")
    IMPORTED_PROJECT_RUNTIME_DIRS+=("")
  fi

  case "$role" in
    code)
      IMPORTED_PROJECT_CODE_DIRS[$idx]="$repo_path"
      ;;
    runtime)
      IMPORTED_PROJECT_RUNTIME_DIRS[$idx]="$repo_path"
      ;;
  esac
}

project_code_dir_for_slug() {
  local slug="$1"
  local idx=""

  if idx="$(find_imported_project_index_by_slug "$slug" 2>/dev/null)"; then
    printf '%s' "${IMPORTED_PROJECT_CODE_DIRS[$idx]}"
  fi
}

project_runtime_dir_for_slug() {
  local slug="$1"
  local idx=""

  if idx="$(find_imported_project_index_by_slug "$slug" 2>/dev/null)"; then
    printf '%s' "${IMPORTED_PROJECT_RUNTIME_DIRS[$idx]}"
  fi
}

project_primary_dir_for_slug() {
  local slug="$1"
  local code_dir=""
  local runtime_dir=""

  code_dir="$(project_code_dir_for_slug "$slug")"
  runtime_dir="$(project_runtime_dir_for_slug "$slug")"

  if [[ -n "$code_dir" ]]; then
    printf '%s' "$code_dir"
  else
    printf '%s' "$runtime_dir"
  fi
}

project_dev_workspace_dir_for_slug() {
  local slug="$1"
  project_runtime_workspace_dir_for_slug "$slug"
}

project_is_github_import_by_slug() {
  local slug="$1"
  local primary_dir=""

  primary_dir="$(project_primary_dir_for_slug "$slug")"
  [[ -n "$primary_dir" ]] && project_is_github_import "$primary_dir"
}

project_has_generated_devcontainer_by_slug() {
  local slug="$1"
  local workspace_dir=""

  workspace_dir="$(project_dev_workspace_dir_for_slug "$slug")"
  [[ -n "$workspace_dir" ]] && project_has_generated_devcontainer "$workspace_dir"
}

project_is_codespaces_ready_by_slug() {
  local slug="$1"
  local workspace_dir=""

  workspace_dir="$(project_dev_workspace_dir_for_slug "$slug")"
  [[ -n "$workspace_dir" ]] && project_is_codespaces_ready "$workspace_dir"
}

project_active_container_count_for_slug() {
  local slug="$1"
  local code_dir=""
  local workspace_dir=""

  code_dir="$(project_code_dir_for_slug "$slug")"
  workspace_dir="$(project_dev_workspace_dir_for_slug "$slug")"
  if [[ -z "$workspace_dir" && -z "$code_dir" ]]; then
    printf '0'
    return 0
  fi

  {
    if [[ -n "$code_dir" ]]; then
      repo_active_container_ids "$code_dir"
    fi
    if [[ -n "$workspace_dir" && "$workspace_dir" != "$code_dir" ]]; then
      repo_active_container_ids "$workspace_dir"
    fi
  } | LC_ALL=C sort -u | awk 'NF {count++} END {print count+0}'
}

project_smart_open_dir_for_slug() {
  local slug="$1"
  local runtime_dir=""
  local code_dir=""

  runtime_dir="$(project_runtime_workspace_dir_for_slug "$slug")"
  code_dir="$(project_code_dir_for_slug "$slug")"

  if [[ -n "$runtime_dir" ]]; then
    printf '%s' "$runtime_dir"
  else
    printf '%s' "$code_dir"
  fi
}

collect_imported_projects() {
  local include_docker="${1:-1}"
  IMPORTED_PROJECT_SLUGS=()
  IMPORTED_PROJECT_CODE_DIRS=()
  IMPORTED_PROJECT_RUNTIME_DIRS=()
  local repo_path=""
  local slug=""
  local runner_path=""
  local container_path=""

  if [[ -d "$CODE_REPOS_DIR" ]]; then
    while IFS= read -r repo_path; do
      [[ -n "$repo_path" ]] || continue
      [[ -d "$repo_path" ]] || continue
      project_is_git_repo "$repo_path" || continue
      slug="$(project_slug_from_repo_dir "$repo_path")"
      add_imported_project "$slug" "$repo_path" "code"
    done < <(
      find "$CODE_REPOS_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | LC_ALL=C sort
    )
  fi

  if [[ -d "$RUNTIME_REPOS_DIR" ]]; then
    while IFS= read -r repo_path; do
      [[ -n "$repo_path" ]] || continue
      [[ -d "$repo_path" ]] || continue
      project_is_git_repo "$repo_path" || continue
      slug="$(project_slug_from_repo_dir "$repo_path")"
      add_imported_project "$slug" "$repo_path" "runtime"
    done < <(
      find "$RUNTIME_REPOS_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | LC_ALL=C sort
    )
  fi

  while IFS= read -r runner_path; do
    [[ -f "$runner_path/.runner" ]] || continue
    slug="$(basename "$(dirname "$runner_path")")/$(basename "$runner_path")"
    if [[ -d "$CODE_REPOS_DIR/${slug%/*}/${slug#*/}" ]]; then
      add_imported_project "$slug" "$CODE_REPOS_DIR/${slug%/*}/${slug#*/}" "code"
    fi
    if [[ -d "$RUNTIME_REPOS_DIR/${slug%/*}/${slug#*/}" ]]; then
      add_imported_project "$slug" "$RUNTIME_REPOS_DIR/${slug%/*}/${slug#*/}" "runtime"
    fi
  done < <(find "$RUNNERS_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | LC_ALL=C sort)

  if [[ "$include_docker" -eq 1 ]] && command -v docker >/dev/null 2>&1 && docker_engine_ready; then
    while IFS= read -r container_path; do
      [[ -n "$container_path" ]] || continue
      [[ -d "$container_path" ]] || continue
      project_is_git_repo "$container_path" || continue
      slug="$(project_slug_from_repo_dir "$container_path")"
      if [[ "$container_path" == "$RUNTIME_REPOS_DIR/"* ]]; then
        add_imported_project "$slug" "$container_path" "runtime"
      else
        add_imported_project "$slug" "$container_path" "code"
      fi
    done < <(docker ps --format '{{.Label "devcontainer.local_folder"}}' 2>/dev/null | awk 'NF' | LC_ALL=C sort -u)
  fi
}

count_imported_projects_with_active_containers() {
  local idx=0
  local count=0
  local active_count="0"

  while [[ "$idx" -lt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    active_count="$(project_active_container_count_for_slug "${IMPORTED_PROJECT_SLUGS[$idx]}")"
    if [[ "$active_count" =~ ^[0-9]+$ ]] && (( active_count > 0 )); then
      count=$((count + 1))
    fi
    idx=$((idx + 1))
  done

  printf '%s' "$count"
}

count_imported_projects_with_runners() {
  local idx=0
  local count=0

  while [[ "$idx" -lt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    if repo_runner_configured "${IMPORTED_PROJECT_SLUGS[$idx]}"; then
      count=$((count + 1))
    fi
    idx=$((idx + 1))
  done

  printf '%s' "$count"
}

count_imported_projects_with_devcontainers() {
  local idx=0
  local count=0

  while [[ "$idx" -lt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    if project_workspace_has_devcontainer_by_slug "${IMPORTED_PROJECT_SLUGS[$idx]}"; then
      count=$((count + 1))
    fi
    idx=$((idx + 1))
  done

  printf '%s' "$count"
}

count_imported_projects_with_generated_starters() {
  local idx=0
  local count=0

  while [[ "$idx" -lt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    if project_has_generated_devcontainer_by_slug "${IMPORTED_PROJECT_SLUGS[$idx]}"; then
      count=$((count + 1))
    fi
    idx=$((idx + 1))
  done

  printf '%s' "$count"
}

count_imported_projects_codespaces_ready() {
  local idx=0
  local count=0

  while [[ "$idx" -lt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    if project_is_codespaces_ready_by_slug "${IMPORTED_PROJECT_SLUGS[$idx]}"; then
      count=$((count + 1))
    fi
    idx=$((idx + 1))
  done

  printf '%s' "$count"
}

open_repo_in_vscode() {
  local repo_path="$1"

  [[ -n "$repo_path" ]] || return 1

  if command -v code >/dev/null 2>&1; then
    code "$repo_path"
  else
    open -a "Visual Studio Code" "$repo_path"
  fi
}

open_repo_in_vscode_wait() {
  local repo_path="$1"

  [[ -n "$repo_path" ]] || return 1

  if command -v code >/dev/null 2>&1; then
    if code --help 2>/dev/null | grep -q -- '--wait'; then
      code --new-window --wait "$repo_path"
    else
      code --new-window "$repo_path"
      echo "Close the VS Code window when you are done checking this project."
      pause
    fi
  else
    open -a "Visual Studio Code" "$repo_path"
    echo "Close the VS Code window when you are done checking this project."
    pause
  fi
}

start_devcontainer_for_project() {
  local slug="$1"
  local repo_path=""
  local temp_report=""
  local previous_slug="$SLUG"
  local previous_repo_dir="$REPO_DIR"
  local previous_dev_repo_dir="$DEV_REPO_DIR"
  local previous_report="$REPORT_FILE"

  repo_path="$(project_dev_workspace_dir_for_slug "$slug")"

  if ! repo_has_devcontainer_file "$repo_path"; then
    warn "No .devcontainer/devcontainer.json found for $slug"
    return 1
  fi

  temp_report="$REPORTS_DIR/$(sanitize_label "$slug")-browse-$(date +%Y%m%d-%H%M%S).txt"
  : > "$temp_report"

  SLUG="$slug"
  REPO_DIR="$(project_primary_dir_for_slug "$slug")"
  DEV_REPO_DIR="$repo_path"
  REPORT_FILE="$temp_report"
  offer_local_devcontainer_start
  SLUG="$previous_slug"
  REPO_DIR="$previous_repo_dir"
  DEV_REPO_DIR="$previous_dev_repo_dir"
  REPORT_FILE="$previous_report"
}

smart_open_project() {
  local slug="$1"
  local code_dir=""
  local repo_path=""
  local runtime_workspace=""
  local active_count="0"

  code_dir="$(project_plain_repo_dir_for_slug "$slug")"
  repo_path="$(project_smart_open_dir_for_slug "$slug")"
  runtime_workspace="$(project_runtime_workspace_dir_for_slug "$slug")"
  if ! open_repo_in_vscode "$repo_path"; then
    warn "No local workspace path was found for $slug"
    return 1
  fi
  active_count="$(project_active_container_count_for_slug "$slug")"

  if [[ "$active_count" =~ ^[0-9]+$ ]] && (( active_count > 0 )); then
    info "An active local devcontainer is already running for $slug."
    if [[ -n "$runtime_workspace" ]]; then
      printf 'Runtime/local Codespace workspace:\n  %s\n' "$runtime_workspace"
    fi
    echo "Attach or reopen in the container from VS Code if needed."
    return 0
  fi

  if project_is_codespaces_ready_by_slug "$slug"; then
    info "$slug already has a GitHub Codespaces/devcontainer configuration."
    echo "The project is ready to use locally without creating a new starter config."
    if [[ -n "$runtime_workspace" ]]; then
      printf 'Runtime/local Codespace workspace:\n  %s\n' "$runtime_workspace"
    fi
    if [[ -n "$code_dir" && "$code_dir" != "$runtime_workspace" ]]; then
      printf 'Plain repo workspace:\n  %s\n' "$code_dir"
    fi
    echo "Open it in VS Code and run 'Dev Containers: Reopen in Container' when you want to enter the container."
    return 0
  fi

  if project_has_generated_devcontainer_by_slug "$slug"; then
    info "$slug is using a $APP_NAME-generated local starter devcontainer."
    echo "Open it in VS Code and tune the generated .devcontainer for this repo as needed."
    echo "Use 'Force start/update local devcontainer now' only when you explicitly want to test the generated starter."
    return 0
  fi

  if [[ -n "$runtime_workspace" ]] && repo_has_devcontainer_file "$runtime_workspace"; then
    info "$slug already has a local devcontainer configuration."
    echo "Open it in VS Code and run 'Dev Containers: Reopen in Container' when needed."
    return 0
  fi

  warn "$slug does not have a .devcontainer/devcontainer.json file."
  return 0
}

show_project_browser_summary() {
  local slug="$1"
  local code_dir=""
  local runtime_workspace=""
  local active_count="0"
  local runner_path=""
  local smart_open_dir=""

  code_dir="$(project_code_dir_for_slug "$slug")"
  runtime_workspace="$(project_runtime_workspace_dir_for_slug "$slug")"
  active_count="$(project_active_container_count_for_slug "$slug")"
  runner_path="$(runner_dir_for_slug "$slug")"
  smart_open_dir="$(project_smart_open_dir_for_slug "$slug")"

  echo
  print_line
  printf 'Project: %s\n' "$slug"
  print_line
  printf 'Code path: %s\n' "${code_dir:-not present}"
  printf 'Runtime path: %s\n' "${runtime_workspace:-not present}"
  printf 'Smart open target: %s\n' "${smart_open_dir:-not present}"
  printf 'GitHub import: %s\n' "$(project_is_github_import_by_slug "$slug" && printf yes || printf no)"
  printf 'Codespaces/devcontainer ready: %s\n' "$(project_is_codespaces_ready_by_slug "$slug" && printf yes || printf no)"
  printf 'Generated local starter: %s\n' "$(project_has_generated_devcontainer_by_slug "$slug" && printf yes || printf no)"
  printf 'Devcontainer file: %s\n' "$(project_workspace_has_devcontainer_by_slug "$slug" && printf yes || printf no)"
  printf 'Active local containers: %s\n' "$active_count"
  printf 'Runner configured: %s\n' "$([[ -f "$runner_path/.runner" ]] && printf yes || printf no)"
  if [[ -f "$runner_path/.runner" ]]; then
    printf 'Runner path: %s\n' "$runner_path"
  fi
}

show_runner_status_for_slug() {
  local slug="$1"
  local runner_path=""

  runner_path="$(runner_dir_for_slug "$slug")"
  echo
  print_line
  printf 'Local Actions Runner: %s\n' "$slug"
  print_line

  if [[ ! -d "$runner_path" ]]; then
    echo "No local runner directory found."
    return 0
  fi

  printf 'Path: %s\n' "$runner_path"
  printf 'Configured: %s\n' "$([[ -f "$runner_path/.runner" ]] && printf yes || printf no)"

  if [[ -x "$runner_path/svc.sh" ]]; then
    printf 'Service state: %s\n' "$(runner_service_status_state_for_dir "$runner_path")"
    echo "Service status:"
    runner_service_status_output_for_dir "$runner_path" || true
  else
    echo "Service helper: missing"
  fi
}

show_imported_projects_summary() {
  local total_projects=0
  local devcontainer_projects=0
  local starter_projects=0
  local codespaces_ready_projects=0
  local active_projects=0
  local runner_projects=0

  total_projects="${#IMPORTED_PROJECT_SLUGS[@]}"
  devcontainer_projects="$(count_imported_projects_with_devcontainers)"
  starter_projects="$(count_imported_projects_with_generated_starters)"
  codespaces_ready_projects="$(count_imported_projects_codespaces_ready)"
  active_projects="$(count_imported_projects_with_active_containers)"
  runner_projects="$(count_imported_projects_with_runners)"

  printf 'Detected imported projects: %s\n' "$total_projects"
  printf 'Projects with local devcontainers: %s\n' "$devcontainer_projects"
  printf 'Generated local starters: %s\n' "$starter_projects"
  printf 'Checked-in Codespaces/devcontainer configs: %s\n' "$codespaces_ready_projects"
  printf 'Projects with active containers: %s\n' "$active_projects"
  printf 'Projects with local runners: %s\n' "$runner_projects"
}

browse_project_actions() {
  local slug="$1"
  local choice=""

  while true; do
    show_project_browser_summary "$slug"
    echo
    echo "1) Open plain repo in VS Code"
    echo "2) Open runtime/local Codespace workspace"
    echo "3) Force start/update runtime devcontainer now"
    echo "4) Show local Actions runner status"
    echo "5) Apply recommended no-spend safeguards"
    echo "6) Back"
    echo
    read -r -p "Enter choice [1-6]: " choice

    case "$choice" in
      1)
        if ! open_repo_in_vscode "$(project_plain_repo_dir_for_slug "$slug")"; then
          warn "No plain repo path was found for $slug"
        fi
        ;;
      2)
        smart_open_project "$slug"
        ;;
      3)
        start_devcontainer_for_project "$slug" || true
        ;;
      4)
        show_runner_status_for_slug "$slug"
        pause
        ;;
      5)
        run_recommended_cost_control_for_slug "$slug" || true
        pause
        ;;
      6)
        break
        ;;
      *)
        warn "Invalid choice."
        ;;
    esac
  done
}

browse_imported_projects_quick() {
  local idx=""
  local i=1

  collect_imported_projects 0

  if [[ "${#IMPORTED_PROJECT_SLUGS[@]}" -eq 0 ]]; then
    echo
    print_line
    echo "Imported Projects"
    print_line
    echo "No imported projects were found under the current root."
    pause
    return 0
  fi

  while true; do
    echo
    print_line
    echo "Imported Projects"
    print_line
    printf 'Detected imported projects: %s\n' "${#IMPORTED_PROJECT_SLUGS[@]}"
    echo
    i=1
    while [[ "$i" -le "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
      printf '%3d) %s\n' "$i" "${IMPORTED_PROJECT_SLUGS[$((i - 1))]}"
      i=$((i + 1))
    done
    echo "  B) Back"
    echo

    read -r -p "Select a project: " idx
    case "$idx" in
      b|B)
        return 0
        ;;
      ''|*[!0-9]*)
        warn "Invalid selection."
        ;;
      *)
        if [[ "$idx" -lt 1 || "$idx" -gt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; then
          warn "Selection is out of range."
        else
          browse_project_actions "${IMPORTED_PROJECT_SLUGS[$((idx - 1))]}"
        fi
        ;;
    esac
  done
}

browse_imported_projects() {
  local idx=""
  local i=1
  local slug=""
  local status=""

  collect_imported_projects

  if [[ "${#IMPORTED_PROJECT_SLUGS[@]}" -eq 0 ]]; then
    echo
    print_line
    echo "Imported Projects"
    print_line
    echo "No imported projects were found under the current root."
    pause
    return 0
  fi

  while true; do
    echo
    print_line
    echo "Imported Projects"
    print_line
    show_imported_projects_summary
    echo
    i=1
    while [[ "$i" -le "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
      slug="${IMPORTED_PROJECT_SLUGS[$((i - 1))]}"
      status="$(project_status_summary "$slug")"
      printf '%3d) %s [%s]\n' "$i" "$slug" "$status"
      i=$((i + 1))
    done
    echo "  B) Back"
    echo

    read -r -p "Select a project: " idx
    case "$idx" in
      b|B)
        return 0
        ;;
      ''|*[!0-9]*)
        warn "Invalid selection."
        ;;
      *)
        if [[ "$idx" -lt 1 || "$idx" -gt "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; then
          warn "Selection is out of range."
        else
          browse_project_actions "${IMPORTED_PROJECT_SLUGS[$((idx - 1))]}"
        fi
        ;;
    esac
  done
}

browse_installed_devcontainers() {
  local idx=""
  local i=1
  local slug=""
  local status=""
  local devcontainer_slugs=()

  collect_imported_projects

  while [[ "$i" -le "${#IMPORTED_PROJECT_SLUGS[@]}" ]]; do
    slug="${IMPORTED_PROJECT_SLUGS[$((i - 1))]}"
    if project_workspace_has_devcontainer_by_slug "$slug"; then
      devcontainer_slugs+=("$slug")
    fi
    i=$((i + 1))
  done

  if [[ "${#devcontainer_slugs[@]}" -eq 0 ]]; then
    echo
    print_line
    echo "Installed Local Devcontainers"
    print_line
    echo "No local devcontainers were found under the current root."
    pause
    return 0
  fi

  while true; do
    echo
    print_line
    echo "Installed Local Devcontainers"
    print_line
    printf 'Installed local devcontainer projects: %s\n' "${#devcontainer_slugs[@]}"
    show_imported_projects_summary
    echo
    i=1
    while [[ "$i" -le "${#devcontainer_slugs[@]}" ]]; do
      slug="${devcontainer_slugs[$((i - 1))]}"
      status="$(project_status_summary "$slug")"
      printf '%3d) %s [%s]\n' "$i" "$slug" "$status"
      i=$((i + 1))
    done
    echo "  B) Back"
    echo

    read -r -p "Select a local devcontainer project: " idx
    case "$idx" in
      b|B)
        return 0
        ;;
      ''|*[!0-9]*)
        warn "Invalid selection."
        ;;
      *)
        if [[ "$idx" -lt 1 || "$idx" -gt "${#devcontainer_slugs[@]}" ]]; then
          warn "Selection is out of range."
        else
          browse_project_actions "${devcontainer_slugs[$((idx - 1))]}"
        fi
        ;;
    esac
  done
}

browse_active_containers() {
  local rows=()
  local line=""
  local idx=""
  local i=1
  local container_name=""
  local image=""
  local status=""
  local project_path=""
  local slug=""
  local action=""

  collect_imported_projects

  echo
  print_line
  echo "Active Local Containers"
  print_line

  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker CLI is not installed."
    pause
    return 0
  fi

  if ! docker_engine_ready; then
    echo "Docker is not running."
    pause
    return 0
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] && rows+=("$line")
  done < <(docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Label "devcontainer.local_folder"}}' 2>/dev/null)

  if [[ "${#rows[@]}" -eq 0 ]]; then
    echo "No running containers were found."
    pause
    return 0
  fi

  while true; do
    echo
    print_line
    echo "Active Local Containers"
    print_line
    printf 'Active local containers: %s\n' "${#rows[@]}"
    echo
    i=1
    for line in "${rows[@]}"; do
      IFS=$'\t' read -r container_name image status project_path <<<"$line"
      slug=""
      if [[ -n "$project_path" && -d "$project_path" ]]; then
        slug="$(project_slug_from_repo_dir "$project_path")"
      fi
      if [[ -n "$slug" ]]; then
        printf '%3d) %s [%s]\n' "$i" "$slug" "$status"
      else
        printf '%3d) %s [%s]\n' "$i" "$container_name" "$status"
      fi
      i=$((i + 1))
    done
    echo "  B) Back"
    echo

    read -r -p "Select an active container: " idx
    case "$idx" in
      b|B)
        return 0
        ;;
      ''|*[!0-9]*)
        warn "Invalid selection."
        ;;
      *)
        if [[ "$idx" -lt 1 || "$idx" -gt "${#rows[@]}" ]]; then
          warn "Selection is out of range."
          continue
        fi

        line="${rows[$((idx - 1))]}"
        IFS=$'\t' read -r container_name image status project_path <<<"$line"
        slug=""
        if [[ -n "$project_path" && -d "$project_path" ]]; then
          slug="$(project_slug_from_repo_dir "$project_path")"
        fi

        while true; do
          echo
          print_line
          printf 'Active Container: %s\n' "${slug:-$container_name}"
          print_line
          printf 'Container name: %s\n' "$container_name"
          printf 'Image: %s\n' "$image"
          printf 'Status: %s\n' "$status"
          printf 'Project path: %s\n' "${project_path:-unknown}"
          if [[ -n "$slug" ]]; then
            printf 'Project slug: %s\n' "$slug"
          fi
          echo
          echo "1) Open current runtime workspace in VS Code"
          echo "2) Open plain repo in VS Code"
          echo "3) Open project actions"
          echo "4) Apply recommended no-spend safeguards"
          echo "5) Back"
          echo

          read -r -p "Enter choice [1-5]: " action
          case "$action" in
            1)
              if [[ -n "$project_path" ]]; then
                open_repo_in_vscode "$project_path" || warn "Could not open $project_path"
              else
                warn "No project path is attached to this container."
              fi
              ;;
            2)
              if [[ -n "$slug" ]]; then
                if ! open_repo_in_vscode "$(project_plain_repo_dir_for_slug "$slug")"; then
                  warn "No plain repo path was found for $slug"
                fi
              else
                warn "No project slug was detected for this container."
              fi
              ;;
            3)
              if [[ -n "$slug" ]]; then
                browse_project_actions "$slug"
              else
                warn "No project slug was detected for this container."
              fi
              ;;
            4)
              if [[ -n "$slug" ]]; then
                run_recommended_cost_control_for_slug "$slug" || true
                pause
              else
                warn "No project slug was detected for this container."
              fi
              ;;
            5)
              break
              ;;
            *)
              warn "Invalid choice."
              ;;
          esac
        done
        ;;
    esac
  done
}

browse_local_runners() {
  local runner_paths=()
  local runner_path=""
  local slug=""
  local idx=""
  local owner=""
  local repo=""
  local configured=""
  local service_state=""

  echo
  print_line
  echo "Local Actions Runners"
  print_line

  [[ -d "$RUNNERS_DIR" ]] || {
    echo "No local runner directory exists under the current root."
    pause
    return 0
  }

  while IFS= read -r runner_path; do
    runner_paths+=("$runner_path")
  done < <(find "$RUNNERS_DIR" -mindepth 2 -maxdepth 2 -type d | LC_ALL=C sort)

  if [[ "${#runner_paths[@]}" -eq 0 ]]; then
    echo "No local runner directories were found."
    pause
    return 0
  fi

  while true; do
    idx=1
    for runner_path in "${runner_paths[@]}"; do
      owner="$(basename "$(dirname "$runner_path")")"
      repo="$(basename "$runner_path")"
      slug="$owner/$repo"
      configured="$([[ -f "$runner_path/.runner" ]] && printf configured || printf plain)"
      service_state="$(runner_service_status_state_for_dir "$runner_path")"
      printf '%3d) %s [%s,%s]\n' "$idx" "$slug" "$configured" "$service_state"
      idx=$((idx + 1))
    done
    echo "  B) Back"
    echo

    read -r -p "Select a runner: " idx
    case "$idx" in
      b|B)
        return 0
        ;;
      ''|*[!0-9]*)
        warn "Invalid selection."
        ;;
      *)
        if [[ "$idx" -lt 1 || "$idx" -gt "${#runner_paths[@]}" ]]; then
          warn "Selection is out of range."
        else
          owner="$(basename "$(dirname "${runner_paths[$((idx - 1))]}")")"
          repo="$(basename "${runner_paths[$((idx - 1))]}")"
          show_runner_status_for_slug "$owner/$repo"
          pause
        fi
        ;;
    esac
  done
}

browse_local_resources() {
  local choice=""
  local imported_total=0
  local devcontainer_total=0
  local starter_total=0
  local active_total=0
  local runner_total=0
  local codespaces_ready_total=0

  while true; do
    collect_imported_projects
    imported_total="${#IMPORTED_PROJECT_SLUGS[@]}"
    devcontainer_total="$(count_imported_projects_with_devcontainers)"
    starter_total="$(count_imported_projects_with_generated_starters)"
    active_total="$(count_imported_projects_with_active_containers)"
    runner_total="$(count_imported_projects_with_runners)"
    codespaces_ready_total="$(count_imported_projects_codespaces_ready)"

    echo
    print_line
    echo "Browse Imported Projects / Containers / Local Actions"
    print_line
    printf '1) Imported projects (%s total)\n' "$imported_total"
    printf '2) Installed local devcontainers (%s total, %s starters, %s checked-in)\n' "$devcontainer_total" "$starter_total" "$codespaces_ready_total"
    printf '3) Active local containers (%s projects)\n' "$active_total"
    printf '4) Local Actions runners (%s projects)\n' "$runner_total"
    echo "5) Cost-control review (one project at a time)"
    echo "6) Back"
    echo

    read -r -p "Enter choice [1-6]: " choice
    case "$choice" in
      1) browse_imported_projects ;;
      2) browse_installed_devcontainers ;;
      3) browse_active_containers ;;
      4) browse_local_runners ;;
      5) browse_cost_control_review ;;
      6) return 0 ;;
      *) warn "Invalid choice." ;;
    esac
  done
}

open_project_for_review() {
  local slug="$1"
  local target_kind="${2:-runtime}"
  local target_path=""

  case "$target_kind" in
    plain)
      target_path="$(project_plain_repo_dir_for_slug "$slug")"
      ;;
    runtime|smart|*)
      target_path="$(project_smart_open_dir_for_slug "$slug")"
      ;;
  esac

  if [[ -z "$target_path" ]]; then
    warn "No local path was found for $slug"
    return 1
  fi

  printf 'Opening %s:\n  %s\n' "$slug" "$target_path"
  open_repo_in_vscode_wait "$target_path"
}

review_projects_one_by_one() {
  local review_slugs=("$@")
  local idx=1
  local total=0
  local slug=""
  local choice=""

  total="${#review_slugs[@]}"
  [[ "$total" -gt 0 ]] || return 0

  collect_imported_projects

  while [[ "$idx" -le "$total" ]]; do
    slug="${review_slugs[$((idx - 1))]}"

    while true; do
      echo
      print_line
      printf 'Open Imported Projects One By One (%s of %s)\n' "$idx" "$total"
      print_line
      show_project_browser_summary "$slug"
      echo
      echo "Y or Enter = yes, open runtime/local workspace"
      echo "P = open plain repo"
      echo "S = skip this project"
      echo "N or Q = stop this review"
      echo
      read -r -p "Choice: " choice

      case "$choice" in
        n|N|q|Q)
          return 0
          ;;
        s|S)
          break
          ;;
        p|P)
          if ! open_project_for_review "$slug" "plain"; then
            break
          fi
          ;;
        ""|y|Y|o|O|k|K)
          if ! open_project_for_review "$slug" "runtime"; then
            break
          fi
          ;;
        *)
          warn "Invalid choice."
          continue
          ;;
      esac

      while true; do
        echo
        echo "O or Enter = OK / next project"
        echo "R = reopen this project"
        echo "S = skip this project"
        echo "N or Q = stop this review"
        echo
        read -r -p "After checking $slug: " choice

        case "$choice" in
          n|N|q|Q)
            return 0
            ;;
          o|O)
            choice=""
            break
            ;;
          r|R)
            break
            ;;
          s|S|"")
            choice=""
            break
            ;;
          *)
            warn "Invalid choice."
            ;;
        esac
      done

      if [[ "$choice" == "r" || "$choice" == "R" ]]; then
        continue
      fi

      break
    done

    idx=$((idx + 1))
  done
}

browse_cost_control_review() {
  local review_slugs=()
  local idx=1
  local total=0
  local slug=""
  local choice=""

  collect_imported_projects
  review_slugs=("${IMPORTED_PROJECT_SLUGS[@]}")
  total="${#review_slugs[@]}"

  if [[ "$total" -eq 0 ]]; then
    echo
    print_line
    echo "Cost Control Review"
    print_line
    echo "No imported projects were found under the current root."
    pause
    return 0
  fi

  while [[ "$idx" -le "$total" ]]; do
    slug="${review_slugs[$((idx - 1))]}"

    while true; do
      ensure_github_ready_for_browser_actions
      show_cost_control_summary_for_slug "$slug"
      echo
      echo "Y or Enter = yes, apply recommended no-spend safeguards now"
      echo "O = open runtime/local workspace in VS Code first"
      echo "P = open plain repo in VS Code first"
      echo "S = skip this project"
      echo "N or Q = stop this review"
      echo
      read -r -p "Choice: " choice

      case "$choice" in
        n|N|q|Q)
          return 0
          ;;
        s|S)
          break
          ;;
        o|O)
          if ! open_project_for_review "$slug" "runtime"; then
            break
          fi
          continue
          ;;
        p|P)
          if ! open_project_for_review "$slug" "plain"; then
            break
          fi
          continue
          ;;
        ""|y|Y)
          run_recommended_cost_control_for_slug "$slug" || true
          ;;
        *)
          warn "Invalid choice."
          continue
          ;;
      esac

      while true; do
        echo
        echo "O or Enter = OK / next project"
        echo "R = review this project again"
        echo "S = skip this project"
        echo "N or Q = stop this review"
        echo
        read -r -p "After checking $slug: " choice

        case "$choice" in
          n|N|q|Q)
            return 0
            ;;
          r|R)
            break
            ;;
          o|O|s|S|"")
            choice=""
            break
            ;;
          *)
            warn "Invalid choice."
            ;;
        esac
      done

      if [[ "$choice" == "r" || "$choice" == "R" ]]; then
        continue
      fi

      break
    done

    idx=$((idx + 1))
  done
}

show_batch_inventory_summary() {
  local requested_total="$1"
  local success_total="$2"
  local failed_total="$3"

  collect_imported_projects

  echo
  print_line
  echo "Batch Summary"
  print_line
  printf 'Repos selected in this batch: %s\n' "$requested_total"
  printf 'Successful repos in this batch: %s\n' "$success_total"
  printf 'Failed repos in this batch: %s\n' "$failed_total"
  echo
  echo "Current local inventory under the selected root(s):"
  show_imported_projects_summary
}

main_menu_loop() {
  local choice=""

  while true; do
    FULL_AUTO=0
    FULL_AUTO_CLEANUP=0
    echo
    print_line
    echo "Main Menu"
    print_line
    echo "1) Run migration or cleanup"
    echo "2) Change workspace root"
    echo "3) Switch GitHub host/account"
    echo "4) Show preflight scan"
    echo "5) Browse imported projects / containers / local Actions / etc."
    echo "6) Exit"
    echo

    read -r -p "Enter choice [1-6]: " choice
    case "$choice" in
      1)
        choose_mode
        choose_repositories
        process_selected_repositories
        ;;
      2)
        choose_root
        ;;
      3)
        select_host
        select_account
        ensure_api_ready
        ;;
      4)
        show_preflight_scan
        ;;
      5)
        browse_local_resources
        ;;
      6)
        break
        ;;
      *)
        warn "Invalid choice."
        ;;
    esac
  done
}

sanitize_label() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//'
}

normalize_repo_input() {
  local owner_input="$1"
  local repo_input="${2:-}"
  local combined=""
  local parsed_host=""

  owner_input="$(trim "$owner_input")"
  repo_input="$(trim "$repo_input")"

  if [[ -z "$owner_input" ]]; then
    err "A repository owner, repo name, or full GitHub URL is required."
    return 1
  fi

  combined="$owner_input"
  if [[ -n "$repo_input" ]]; then
    combined="$owner_input/$repo_input"
  fi

  if [[ "$combined" =~ ^https?://([^/]+)/([^/]+)/([^/]+)/?$ ]]; then
    parsed_host="${BASH_REMATCH[1]}"
    OWNER="${BASH_REMATCH[2]}"
    REPO="${BASH_REMATCH[3]}"
    REPO="${REPO%.git}"
    [[ -n "$parsed_host" ]] && HOST="$parsed_host"
    printf '%s/%s' "$OWNER" "$REPO"
    return 0
  fi

  if [[ "$combined" =~ ^git@([^:]+):([^/]+)/([^/]+)\.git$ ]]; then
    parsed_host="${BASH_REMATCH[1]}"
    OWNER="${BASH_REMATCH[2]}"
    REPO="${BASH_REMATCH[3]}"
    [[ -n "$parsed_host" ]] && HOST="$parsed_host"
    printf '%s/%s' "$OWNER" "$REPO"
    return 0
  fi

  combined="${combined#https://}"
  combined="${combined#http://}"
  combined="${combined#www.}"
  combined="${combined#${HOST}/}"

  while [[ "$combined" == */ && "$combined" != "/" ]]; do
    combined="${combined%/}"
  done
  combined="${combined%.git}"

  if [[ "$combined" == */*/* ]]; then
    parsed_host="${combined%%/*}"
    combined="${combined#*/}"
    [[ -n "$parsed_host" ]] && HOST="$parsed_host"
  fi

  case "$combined" in
    */*)
      OWNER="${combined%%/*}"
      REPO="${combined##*/}"
      ;;
    *)
      OWNER="$owner_input"
      REPO="$repo_input"
      ;;
  esac

  OWNER="$(trim "$OWNER")"
  REPO="$(trim "$REPO")"

  if [[ -z "$OWNER" || -z "$REPO" ]]; then
    err "Repository input must resolve to OWNER/REPO."
    return 1
  fi

  printf '%s/%s' "$OWNER" "$REPO"
}

codespace_scope_available() {
  gh auth status --hostname "$HOST" 2>/dev/null | grep -q "codespace"
}

prepare_repo_vars() {
  SLUG="$1"
  OWNER="${SLUG%/*}"
  REPO="${SLUG#*/}"
  if [[ -n "$HOST" && "$HOST" != "github.com" ]]; then
    REPO_SPEC="$HOST/$OWNER/$REPO"
  else
    REPO_SPEC="$OWNER/$REPO"
  fi
  CODE_REPO_DIR="$CODE_REPOS_DIR/$OWNER/$REPO"
  DEV_REPO_DIR="$RUNTIME_REPOS_DIR/$OWNER/$REPO"
  REPO_DIR="$CODE_REPO_DIR"
  REPORT_FILE="$REPORTS_DIR/$(sanitize_label "$OWNER")-$(sanitize_label "$REPO")-$(date +%Y%m%d-%H%M%S).txt"
  LOCAL_LABEL="$(sanitize_label "$SLUG")-mac"
  RUNNER_NAME="$(hostname -s)-$(sanitize_label "$SLUG")-mac"
  RUNNER_DIR="$RUNNERS_DIR/$OWNER/$REPO"
}

mode_requires_runtime_workspace() {
  case "$MODE" in
    cleanup_only) return 1 ;;
  esac

  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    return 0
  fi

  case "$MODE" in
    codespace_to_local|repo_to_local_plus) return 0 ;;
    *) return 1 ;;
  esac
}

runtime_repo_available() {
  [[ -d "$DEV_REPO_DIR/.git" || -f "$DEV_REPO_DIR/.git" ]]
}

current_dev_workspace_dir() {
  if [[ "$STORAGE_LAYOUT" == "diamond" && -n "$DEV_REPO_DIR" && -d "$DEV_REPO_DIR" ]]; then
    printf '%s' "$DEV_REPO_DIR"
  else
    printf '%s' "$REPO_DIR"
  fi
}

ensure_github_ready_for_browser_actions() {
  if ! command -v gh >/dev/null 2>&1; then
    install_brew_if_missing
    ensure_brew_shellenv_in_profile
    install_tool_if_missing gh gh
  fi

  require_cmd gh "Install GitHub CLI first."

  if [[ -z "$HOST" ]]; then
    select_host
  fi

  if [[ -z "$ACCOUNT" ]]; then
    select_account
  fi

  ensure_api_ready
}

repo_actions_permissions_state() {
  local enabled=""

  enabled="$(gh api --hostname "$HOST" "repos/${OWNER}/${REPO}/actions/permissions" --jq '.enabled' 2>/dev/null || true)"
  case "$enabled" in
    true) printf 'enabled' ;;
    false) printf 'disabled' ;;
    *) printf 'unknown' ;;
  esac
}

repo_has_github_hosted_runs_on_values() {
  [[ -d "$REPO_DIR/.github/workflows" ]] || return 1
  grep -REq 'runs-on:[[:space:]]*(ubuntu-latest|macos-latest|macos-13|macos-14|windows-latest)' "$REPO_DIR/.github/workflows"
}

disable_repo_actions_in_settings() {
  local current_state=""

  current_state="$(repo_actions_permissions_state)"
  case "$current_state" in
    disabled)
      info "GitHub Actions are already disabled in repo settings."
      return 0
      ;;
    unknown)
      warn "Could not read the repo-level GitHub Actions setting."
      ;;
  esac

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run: GitHub Actions would be disabled in repo settings."
    return 0
  fi

  if gh api --method PUT --hostname "$HOST" "repos/${OWNER}/${REPO}/actions/permissions" -F enabled=false >/dev/null 2>&1; then
    info "Disabled GitHub Actions in repo settings."
    return 0
  fi

  warn "Failed to disable GitHub Actions in repo settings."
  return 1
}

cleanup_actions_requested() {
  (( FULL_CLEANUP + DO_DISABLE + DO_RUNS + DO_ARTIFACTS + DO_CACHES + DO_CODESPACES > 0 ))
}

resolve_cleanup_targets() {
  local parsed_run_id=""

  if [[ "$DO_RUNS" -ne 1 ]]; then
    return 0
  fi

  if [[ -n "$TARGET_RUN_ID" ]]; then
    if ! parsed_run_id="$(parse_run_target "$TARGET_RUN_ID")"; then
      err "Run target must be a numeric workflow run ID or a GitHub Actions run URL."
      return 1
    fi
    TARGET_RUN_ID="$parsed_run_id"
  fi

  return 0
}

stop_runner_service_for_dir() {
  local runner_path="$1"
  local service_state=""

  if [[ ! -d "$runner_path" ]]; then
    info "No local runner directory was found."
    return 0
  fi

  if [[ ! -x "$runner_path/svc.sh" ]]; then
    info "No runner service helper was found."
    return 0
  fi

  service_state="$(runner_service_status_state_for_dir "$runner_path")"
  case "$service_state" in
    running)
      if [[ "$DRY_RUN" -eq 1 ]]; then
        info "Dry run: local runner service would be stopped."
        return 0
      fi

      echo "Stopping local runner service..." | tee -a "$REPORT_FILE"
      if (
        cd "$runner_path" && ./svc.sh stop
      ) 2>&1 | tee -a "$REPORT_FILE"; then
        info "Stopped local runner service."
        return 0
      fi

      warn "Failed to stop the local runner service."
      return 1
      ;;
    stopped)
      info "Local runner service is already stopped."
      ;;
    not-installed)
      info "Local runner service is not installed."
      ;;
    configured)
      info "Local runner is configured, but the service is not running."
      ;;
    *)
      info "No running local runner service was detected."
      ;;
  esac

  return 0
}

collect_active_container_ids_for_slug() {
  local slug="$1"
  local seen_ids="|"
  local repo_path=""
  local container_id=""

  for repo_path in "$(project_runtime_workspace_dir_for_slug "$slug")" "$(project_plain_repo_dir_for_slug "$slug")"; do
    [[ -n "$repo_path" ]] || continue
    while IFS= read -r container_id; do
      [[ -n "$container_id" ]] || continue
      [[ "$seen_ids" == *"|$container_id|"* ]] && continue
      seen_ids="${seen_ids}${container_id}|"
      printf '%s\n' "$container_id"
    done < <(repo_active_container_ids "$repo_path")
  done
}

stop_active_containers_for_slug() {
  local slug="$1"
  local container_ids=()
  local container_id=""

  if ! command -v docker >/dev/null 2>&1; then
    info "Docker CLI is not installed, so no local containers can be stopped."
    return 0
  fi

  if ! docker_engine_ready; then
    info "Docker is not running, so no local containers can be stopped."
    return 0
  fi

  while IFS= read -r container_id; do
    [[ -n "$container_id" ]] && container_ids+=("$container_id")
  done < <(collect_active_container_ids_for_slug "$slug")

  if [[ "${#container_ids[@]}" -eq 0 ]]; then
    info "No active local containers were found for $slug."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run: ${#container_ids[@]} local container(s) would be stopped for $slug."
    printf '  %s\n' "${container_ids[@]}"
    return 0
  fi

  info "Stopping ${#container_ids[@]} local container(s) for $slug."
  if docker stop "${container_ids[@]}" >/dev/null 2>&1; then
    info "Stopped local containers for $slug."
    return 0
  fi

  warn "Failed to stop one or more local containers for $slug."
  return 1
}

show_cost_control_summary_for_slug() {
  local slug="$1"
  local runner_path=""
  local runner_state="not present"
  local actions_state="unknown"
  local active_containers="0"

  prepare_repo_vars "$slug"
  runner_path="$(runner_dir_for_slug "$slug")"
  if [[ -d "$runner_path" ]]; then
    runner_state="$(runner_service_status_state_for_dir "$runner_path")"
  fi

  actions_state="$(repo_actions_permissions_state)"
  active_containers="$(collect_active_container_ids_for_slug "$slug" | awk 'NF {count++} END {print count+0}')"

  echo
  print_line
  printf 'Cost Control Review: %s\n' "$slug"
  print_line
  printf 'GitHub Actions repo setting: %s\n' "$actions_state"
  printf 'Workflow files present: %s\n' "$([[ -d "$REPO_DIR/.github/workflows" ]] && printf yes || printf no)"
  printf 'GitHub-hosted runs-on found in code: %s\n' "$(repo_has_github_hosted_runs_on_values && printf yes || printf no)"
  printf 'Local runner configured: %s\n' "$([[ -f "$runner_path/.runner" ]] && printf yes || printf no)"
  printf 'Local runner service state: %s\n' "$runner_state"
  printf 'Active local containers: %s\n' "$active_containers"
  echo
  echo "Recommended no-spend safeguards:"
  echo "- Disable GitHub Actions in repo settings."
  echo "- Disable workflows and delete runs, artifacts, caches, and Codespaces."
  echo "- Stop the local runner service."
  echo "- Stop active local devcontainer containers."
  echo "- Patch workflow files in code to self-hosted labels for future use."
}

reset_cleanup_plan() {
  DO_DISABLE=0
  DO_RUNS=0
  DO_ARTIFACTS=0
  DO_CACHES=0
  DO_CODESPACES=0
  FULL_CLEANUP=0
  DRY_RUN=0
  RUN_FILTER=""
  TARGET_RUN_ID=""
}

configure_auto_cleanup_plan() {
  reset_cleanup_plan
  DRY_RUN=1
  FULL_CLEANUP=1
  DO_DISABLE=1
  DO_RUNS=1
  DO_ARTIFACTS=1
  DO_CACHES=1
  DO_CODESPACES=1
}

parse_run_target() {
  local target="$1"
  local run_id=""

  if [[ "$target" =~ ^[0-9]+$ ]]; then
    printf '%s' "$target"
    return 0
  fi

  if [[ "$target" =~ /actions/runs/([0-9]+) ]]; then
    run_id="${BASH_REMATCH[1]}"
    printf '%s' "$run_id"
    return 0
  fi

  return 1
}

count_from_api() {
  local path="$1"
  local jq_expr="$2"
  local output=""

  if ! output="$(gh api --hostname "$HOST" "$path" --paginate --jq "$jq_expr" 2>/dev/null)"; then
    printf '0'
    return 0
  fi

  if [[ -z "$output" ]]; then
    printf '0'
    return 0
  fi

  printf '%s\n' "$output" | awk 'NF && $0 != "null" {count++} END {print count+0}'
}

collect_api_ids() {
  local path="$1"
  local jq_expr="$2"
  local output=""

  if ! output="$(gh api --hostname "$HOST" "$path" --paginate --jq "$jq_expr" 2>/dev/null)"; then
    return 1
  fi

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" | awk 'NF && $0 != "null" {print}'
  fi
}

collect_workflow_rows() {
  local output=""

  if ! output="$(gh workflow list -R "$REPO_SPEC" -a -L 1000 --json id,name,state --jq '.[] | [.id, .name, .state] | @tsv' 2>/dev/null)"; then
    return 1
  fi

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  fi
}

collect_run_ids() {
  local output=""
  local filter=""

  if [[ -n "$TARGET_RUN_ID" ]]; then
    printf '%s\n' "$TARGET_RUN_ID"
    return 0
  fi

  if [[ -z "$RUN_FILTER" ]]; then
    collect_api_ids "repos/${OWNER}/${REPO}/actions/runs?per_page=100" '.workflow_runs[]?.id'
    return $?
  fi

  if ! output="$(gh api --hostname "$HOST" "repos/${OWNER}/${REPO}/actions/runs?per_page=100" --paginate --jq '.workflow_runs[]? | [.id, (.name // ""), (.display_title // ""), (.path // "")] | @tsv' 2>/dev/null)"; then
    return 1
  fi

  filter="$(printf '%s' "$RUN_FILTER" | tr '[:upper:]' '[:lower:]')"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output" | awk -F'\t' -v filter="$filter" '
      {
        haystack = tolower($2 "\t" $3 "\t" $4)
        if (index(haystack, filter) > 0) {
          print $1
        }
      }
    '
  fi
}

count_run_ids() {
  local output=""

  if ! output="$(collect_run_ids)"; then
    printf '0'
    return 1
  fi

  if [[ -z "$output" ]]; then
    printf '0'
    return 0
  fi

  printf '%s\n' "$output" | awk 'NF {count++} END {print count+0}'
}

count_codespaces() {
  local output=""

  if ! output="$(gh codespace list --repo "$OWNER/$REPO" --json name --jq '.[].name' 2>/dev/null || true)"; then
    printf '0'
    return 0
  fi

  if [[ -z "$output" ]]; then
    printf '0'
    return 0
  fi

  printf '%s\n' "$output" | awk 'NF {count++} END {print count+0}'
}

show_cleanup_summary() {
  local workflow_count="0"
  local run_count="0"
  local artifact_count="0"
  local cache_count="0"
  local codespace_count="0"

  echo
  print_line
  echo "Cleanup Summary"
  print_line
  printf '  Host: %s\n' "$HOST"
  printf '  Account: %s\n' "$ACCOUNT"
  printf '  Repository: %s\n' "$REPO_SPEC"
  printf '  Disable workflows: %s\n' "$([[ "$DO_DISABLE" -eq 1 ]] && printf yes || printf no)"
  printf '  Delete runs: %s\n' "$([[ "$DO_RUNS" -eq 1 ]] && printf yes || printf no)"
  printf '  Delete artifacts: %s\n' "$([[ "$DO_ARTIFACTS" -eq 1 ]] && printf yes || printf no)"
  printf '  Delete caches: %s\n' "$([[ "$DO_CACHES" -eq 1 ]] && printf yes || printf no)"
  printf '  Delete Codespaces: %s\n' "$([[ "$DO_CODESPACES" -eq 1 ]] && printf yes || printf no)"
  [[ -n "$TARGET_RUN_ID" ]] && printf '  Target run ID: %s\n' "$TARGET_RUN_ID"
  [[ -n "$RUN_FILTER" ]] && printf '  Run filter: %s\n' "$RUN_FILTER"
  printf '  Dry run: %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf yes || printf no)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$DO_DISABLE" -eq 1 ]]; then
      workflow_count="$(gh workflow list -R "$REPO_SPEC" -a -L 1000 --json id --jq 'length' 2>/dev/null || printf '0')"
      printf '  Workflows found: %s\n' "${workflow_count:-0}"
    fi
    if [[ "$DO_RUNS" -eq 1 ]]; then
      run_count="$(count_run_ids)"
      printf '  Workflow runs found: %s\n' "${run_count:-0}"
    fi
    if [[ "$DO_ARTIFACTS" -eq 1 ]]; then
      artifact_count="$(count_from_api "repos/${OWNER}/${REPO}/actions/artifacts?per_page=100" '.artifacts[]?.id')"
      printf '  Artifacts found: %s\n' "$artifact_count"
    fi
    if [[ "$DO_CACHES" -eq 1 ]]; then
      cache_count="$(gh cache list -R "$REPO_SPEC" --limit 1000 --json id --jq 'length' 2>/dev/null || printf '0')"
      printf '  Caches found: %s\n' "${cache_count:-0}"
    fi
    if [[ "$DO_CODESPACES" -eq 1 ]]; then
      codespace_count="$(count_codespaces)"
      printf '  Codespaces found: %s\n' "$codespace_count"
    fi
  fi
}

configure_cleanup_plan() {
  local target_value=""
  local parsed_run_id=""

  if [[ "$DIRECT_CLEANUP_MODE" -eq 1 ]]; then
    if ! cleanup_actions_requested; then
      if confirm "Run full cleanup for $REPO_SPEC (disable workflows, delete runs, artifacts, caches, Codespaces)?" "Y"; then
        FULL_CLEANUP=1
        DO_DISABLE=1
        DO_RUNS=1
        DO_ARTIFACTS=1
        DO_CACHES=1
        DO_CODESPACES=1
      else
        confirm "Disable all workflows?" && DO_DISABLE=1
        confirm "Delete workflow runs?" && DO_RUNS=1
        confirm "Delete Actions artifacts?" && DO_ARTIFACTS=1
        confirm "Delete Actions caches?" && DO_CACHES=1
        confirm "Delete Codespaces?" && DO_CODESPACES=1
      fi
    fi

    if (( DO_DISABLE + DO_RUNS + DO_ARTIFACTS + DO_CACHES + DO_CODESPACES == 0 )); then
      err "No cleanup action selected."
      return 1
    fi

    if [[ "$DO_RUNS" -eq 1 && -z "$TARGET_RUN_ID" && -z "$RUN_FILTER" && "$ASSUME_YES" -eq 0 ]]; then
      target_value="$(prompt_optional "Specific run URL or ID (optional, blank for none)")"
      if [[ -n "$target_value" ]]; then
        parsed_run_id="$(parse_run_target "$target_value")" || {
          err "Run target must be a numeric workflow run ID or a GitHub Actions run URL."
          return 1
        }
        TARGET_RUN_ID="$parsed_run_id"
      else
        RUN_FILTER="$(prompt_optional "Workflow run filter (optional substring, blank for all runs)")"
      fi
    fi

    return 0
  fi

  reset_cleanup_plan

  if ! confirm "Run GitHub cleanup for $REPO_SPEC now?"; then
    return 1
  fi

  if confirm "Preview the cleanup as a dry run first?"; then
    DRY_RUN=1
  fi

  if confirm "Run full cleanup for $REPO_SPEC (disable workflows, delete runs, artifacts, caches, Codespaces)?"; then
    FULL_CLEANUP=1
    DO_DISABLE=1
    DO_RUNS=1
    DO_ARTIFACTS=1
    DO_CACHES=1
    DO_CODESPACES=1
  else
    confirm "Disable all workflows?" && DO_DISABLE=1
    confirm "Delete workflow runs?" && DO_RUNS=1
    confirm "Delete Actions artifacts?" && DO_ARTIFACTS=1
    confirm "Delete Actions caches?" && DO_CACHES=1
    confirm "Delete Codespaces?" && DO_CODESPACES=1
  fi

  if (( DO_DISABLE + DO_RUNS + DO_ARTIFACTS + DO_CACHES + DO_CODESPACES == 0 )); then
    info "No cleanup action selected."
    return 1
  fi

  if [[ "$DO_RUNS" -eq 1 ]]; then
    target_value="$(prompt_optional "Specific run URL or ID (optional, blank for none)")"
    if [[ -n "$target_value" ]]; then
      parsed_run_id="$(parse_run_target "$target_value")" || {
        err "Run target must be a numeric workflow run ID or a GitHub Actions run URL."
        return 1
      }
      TARGET_RUN_ID="$parsed_run_id"
    else
      RUN_FILTER="$(prompt_optional "Workflow run filter (optional substring, blank for all runs)")"
    fi
  fi

  return 0
}

delete_run_request() {
  local run_id="$1"
  local output=""

  if output="$(gh api --method DELETE --hostname "$HOST" "repos/${OWNER}/${REPO}/actions/runs/${run_id}" 2>&1)"; then
    return 0
  fi

  if [[ "$output" == *"HTTP 404"* ]]; then
    return 2
  fi

  return 1
}

disable_workflows_cleanup() {
  local workflows=()
  local line=""
  local id=""
  local name=""
  local state=""
  local workflows_output=""
  local total=0
  local changed=0
  local failed=0

  if ! workflows_output="$(collect_workflow_rows)"; then
    warn "Could not list workflows. Check GitHub API access and token permissions."
    return 1
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] && workflows+=("$line")
  done <<<"$workflows_output"

  total="${#workflows[@]}"
  if [[ "$total" -eq 0 ]]; then
    info "No workflows found."
    return 0
  fi

  info "Checking $total workflows"
  for line in "${workflows[@]}"; do
    IFS=$'\t' read -r id name state <<<"$line"

    if [[ "$state" == "disabled_manually" || "$state" == "disabled_inactivity" ]]; then
      info "Already disabled: $name"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '  dry-run disable workflow %s (%s)\n' "$name" "$id"
      changed=$((changed + 1))
      continue
    fi

    if gh workflow disable "$id" -R "$REPO_SPEC" >/dev/null 2>&1; then
      info "Disabled workflow: $name"
      changed=$((changed + 1))
    else
      warn "Failed to disable workflow: $name"
      failed=$((failed + 1))
    fi
  done

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run complete for workflows."
    return 0
  fi

  if [[ "$failed" -eq 0 ]]; then
    return 0
  fi

  return 1
}

delete_runs_cleanup() {
  local run_ids=()
  local ids_output=""
  local id=""
  local total=0
  local completed=0
  local failed=0

  if ! ids_output="$(collect_run_ids)"; then
    warn "Could not list workflow runs. Check GitHub API access and token permissions."
    return 1
  fi

  while IFS= read -r id; do
    [[ -n "$id" ]] && run_ids+=("$id")
  done <<<"$ids_output"

  total="${#run_ids[@]}"
  if [[ "$total" -eq 0 ]]; then
    info "No workflow runs found."
    return 0
  fi

  if [[ -n "$TARGET_RUN_ID" ]]; then
    info "Deleting workflow run $TARGET_RUN_ID"
  elif [[ -n "$RUN_FILTER" ]]; then
    info "Deleting $total workflow runs matching \"$RUN_FILTER\""
  else
    info "Deleting $total workflow runs"
  fi

  for id in "${run_ids[@]}"; do
    completed=$((completed + 1))

    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '  dry-run delete run %s\n' "$id"
      continue
    fi

    if delete_run_request "$id"; then
      :
    else
      case $? in
        2)
          info "Workflow run $id was already removed."
          ;;
        *)
          failed=$((failed + 1))
          warn "Failed to delete run $id"
          ;;
      esac
    fi

    if (( completed % 25 == 0 || completed == total )); then
      info "Runs progress: $completed/$total"
    fi
  done

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run complete for workflow runs."
    return 0
  fi

  if [[ "$failed" -eq 0 ]]; then
    return 0
  fi

  return 1
}

delete_artifacts_cleanup() {
  local artifact_ids=()
  local ids_output=""
  local id=""
  local total=0
  local completed=0
  local failed=0

  if ! ids_output="$(collect_api_ids "repos/${OWNER}/${REPO}/actions/artifacts?per_page=100" '.artifacts[]?.id')"; then
    warn "Could not list artifacts. Check GitHub API access and token permissions."
    return 1
  fi

  while IFS= read -r id; do
    [[ -n "$id" ]] && artifact_ids+=("$id")
  done <<<"$ids_output"

  total="${#artifact_ids[@]}"
  if [[ "$total" -eq 0 ]]; then
    info "No artifacts found."
    return 0
  fi

  info "Deleting $total artifacts"
  for id in "${artifact_ids[@]}"; do
    completed=$((completed + 1))

    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '  dry-run delete artifact %s\n' "$id"
      continue
    fi

    if gh api --method DELETE --hostname "$HOST" "repos/${OWNER}/${REPO}/actions/artifacts/${id}" >/dev/null 2>&1; then
      :
    else
      failed=$((failed + 1))
      warn "Failed to delete artifact $id"
    fi

    if (( completed % 25 == 0 || completed == total )); then
      info "Artifacts progress: $completed/$total"
    fi
  done

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run complete for artifacts."
    return 0
  fi

  if [[ "$failed" -eq 0 ]]; then
    return 0
  fi

  return 1
}

delete_caches_cleanup() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run: caches would be deleted with gh cache delete --all"
    return 0
  fi

  if gh cache delete --all --succeed-on-no-caches --repo "$REPO_SPEC" >/dev/null 2>&1; then
    info "Deleted Actions caches."
    return 0
  fi

  warn "Cache cleanup reported an issue."
  return 1
}

delete_codespaces_cleanup() {
  local codespace_names=""
  local codespace_name=""
  local total=0
  local completed=0
  local failed=0

  codespace_names="$(gh codespace list --repo "$OWNER/$REPO" --json name --jq '.[].name' 2>/dev/null || true)"
  if [[ -z "$codespace_names" ]]; then
    info "No Codespaces found."
    return 0
  fi

  total="$(printf '%s\n' "$codespace_names" | awk 'NF {count++} END {print count+0}')"
  info "Deleting $total Codespaces"

  while IFS= read -r codespace_name; do
    [[ -n "$codespace_name" ]] || continue
    completed=$((completed + 1))

    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '  dry-run delete codespace %s\n' "$codespace_name"
      continue
    fi

    if gh codespace delete -c "$codespace_name" -f >/dev/null 2>&1; then
      :
    else
      failed=$((failed + 1))
      warn "Failed to delete Codespace $codespace_name"
    fi

    if (( completed % 10 == 0 || completed == total )); then
      info "Codespaces progress: $completed/$total"
    fi
  done <<EOF
$codespace_names
EOF

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run complete for Codespaces."
    return 0
  fi

  if [[ "$failed" -eq 0 ]]; then
    return 0
  fi

  return 1
}

run_cleanup_flow() {
  local cleanup_failed=0
  local plan_is_preconfigured=0

  if [[ "$FULL_AUTO" -eq 1 && "$MODE" != "cleanup_only" ]]; then
    if [[ "$FULL_AUTO_CLEANUP" -eq 1 ]]; then
      info "FULL AUTO + CLEANUP PREVIEW is running the GitHub cleanup plan automatically."
      ensure_api_ready
      configure_auto_cleanup_plan
      show_cleanup_summary
    else
      info "FULL AUTO skips GitHub cleanup prompts during import flows."
      echo "GitHub cleanup: SKIPPED (FULL AUTO)" | tee -a "$REPORT_FILE"
      return 0
    fi
  else
    ensure_api_ready
    if cleanup_actions_requested; then
      plan_is_preconfigured=1
    fi

    if [[ "$plan_is_preconfigured" -eq 0 ]]; then
      if ! configure_cleanup_plan; then
        return 0
      fi
    fi

    if ! resolve_cleanup_targets; then
      return 1
    fi

    show_cleanup_summary

    if [[ "$ASSUME_YES" -ne 1 ]] && ! confirm "Proceed with cleanup?"; then
      warn "Cleanup cancelled."
      return 0
    fi
  fi

  if [[ "$DO_DISABLE" -eq 1 ]] && ! disable_workflows_cleanup; then
    cleanup_failed=1
  fi
  if [[ "$DO_RUNS" -eq 1 ]] && ! delete_runs_cleanup; then
    cleanup_failed=1
  fi
  if [[ "$DO_ARTIFACTS" -eq 1 ]] && ! delete_artifacts_cleanup; then
    cleanup_failed=1
  fi
  if [[ "$DO_CACHES" -eq 1 ]] && ! delete_caches_cleanup; then
    cleanup_failed=1
  fi
  if [[ "$DO_CODESPACES" -eq 1 ]] && ! delete_codespaces_cleanup; then
    cleanup_failed=1
  fi

  if [[ "$cleanup_failed" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
    warn "Dry-run cleanup finished with errors for $REPO_SPEC"
  elif [[ "$cleanup_failed" -eq 1 ]]; then
    warn "Cleanup finished with errors for $REPO_SPEC"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry-run cleanup finished for $REPO_SPEC"
  else
    info "Cleanup finished for $REPO_SPEC"
  fi
}

clone_or_update_one_repo_copy() {
  local target_dir="$1"
  local role_label="$2"
  local default_branch=""
  local remote_url=""

  mkdir -p "$(dirname "$target_dir")"

  if [[ -e "$target_dir" && ! -d "$target_dir/.git" && ! -f "$target_dir/.git" ]]; then
    err "The $role_label path exists but is not a Git repository: $target_dir"
    return 1
  fi

  if [[ ! -d "$target_dir/.git" && ! -f "$target_dir/.git" ]]; then
    if ! GH_HOST="$HOST" gh repo clone "$REPO_SPEC" "$target_dir"; then
      default_branch="$(GH_HOST="$HOST" gh repo view "$REPO_SPEC" --json defaultBranchRef --jq '.defaultBranchRef.name // empty' 2>/dev/null || true)"
      if [[ -z "$default_branch" ]]; then
        remote_url="https://${HOST}/${OWNER}/${REPO}.git"
        mkdir -p "$target_dir"
        if git init "$target_dir" >/dev/null 2>&1; then
          if git -C "$target_dir" remote get-url origin >/dev/null 2>&1; then
            git -C "$target_dir" remote set-url origin "$remote_url" >/dev/null 2>&1 || true
          else
            git -C "$target_dir" remote add origin "$remote_url" >/dev/null 2>&1 || true
          fi
          warn "$role_label repository appears to be empty on GitHub. Created a local empty mirror at $target_dir."
          return 0
        fi
        err "Failed to initialize an empty local mirror for $REPO_SPEC at $target_dir"
        return 1
      elif [[ -d "$target_dir/.git" || -f "$target_dir/.git" ]]; then
        warn "$role_label repository appears to be empty or missing a default branch. Continuing with the local clone."
      else
        err "Failed to clone $REPO_SPEC into $target_dir"
        return 1
      fi
    fi
  else
    info "$role_label repository already exists locally."
    if ! git -C "$target_dir" fetch origin --prune; then
      warn "Failed to fetch origin for $target_dir"
      return 1
    fi
  fi

  default_branch="$(GH_HOST="$HOST" gh repo view "$REPO_SPEC" --json defaultBranchRef --jq '.defaultBranchRef.name // empty' 2>/dev/null || true)"
  if [[ -z "$default_branch" ]]; then
    warn "No default branch was reported for $REPO_SPEC. The repository may be empty. Skipping checkout and pull for $role_label."
    return 0
  fi

  git -C "$target_dir" checkout "$default_branch" >/dev/null 2>&1 || true

  if git -C "$target_dir" diff --quiet && git -C "$target_dir" diff --cached --quiet; then
    if ! git -C "$target_dir" pull --ff-only origin "$default_branch"; then
      warn "Failed to pull $default_branch for $target_dir"
      return 1
    fi
  else
    warn "Local changes are present in $target_dir. Skipping pull."
  fi
}

sync_runtime_repo() {
  if [[ "$STORAGE_LAYOUT" != "diamond" ]]; then
    return 0
  fi

  info "Preparing runtime mirror for $REPO_SPEC"
  clone_or_update_one_repo_copy "$DEV_REPO_DIR" "Runtime mirror"
}

clone_or_update_repo() {
  echo
  info "Preparing $REPO_SPEC"
  clone_or_update_one_repo_copy "$CODE_REPO_DIR" "Code"

  if mode_requires_runtime_workspace; then
    sync_runtime_repo
  fi
}

write_report_header() {
  {
    print_line
    printf '%s Report\n' "$APP_NAME"
    printf 'Version: %s\n' "$APP_VERSION"
    printf 'Time: %s\n' "$(date)"
    printf 'Host: %s\n' "$HOST"
    printf 'Account: %s\n' "$ACCOUNT"
    printf 'Mode: %s\n' "$MODE"
    printf 'Full Auto: %s\n' "$([[ "$FULL_AUTO" -eq 1 ]] && printf yes || printf no)"
    printf 'Full Auto Cleanup Preview: %s\n' "$([[ "$FULL_AUTO_CLEANUP" -eq 1 ]] && printf yes || printf no)"
    printf 'Repo: %s\n' "$REPO_SPEC"
    printf 'Code Path: %s\n' "$CODE_REPO_DIR"
    if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
      printf 'Runtime Path: %s\n' "$DEV_REPO_DIR"
    fi
    printf 'Runner Path: %s\n' "$RUNNER_DIR"
    printf 'Runner Label: %s\n' "$LOCAL_LABEL"
    print_line
    printf '\n'
  } | tee "$REPORT_FILE"
}

audit_repo() {
  local workspace_dir=""

  workspace_dir="$(current_dev_workspace_dir)"

  {
    echo "== Repo Audit =="
    echo
    if [[ "$workspace_dir" == "$REPO_DIR" ]]; then
      echo "-- Git Status --"
      git -C "$REPO_DIR" status --short || true
      echo
      echo "-- Root Files --"
      (cd "$REPO_DIR" && ls -la) || true
      echo
      echo "-- .devcontainer --"
      if [[ -d "$workspace_dir/.devcontainer" ]]; then
        find "$workspace_dir/.devcontainer" -maxdepth 2 -type f | sort
      else
        echo ".devcontainer directory not found."
      fi
      echo
    else
      echo "-- Code Repo Git Status --"
      git -C "$REPO_DIR" status --short || true
      echo
      echo "-- Code Repo Root Files --"
      (cd "$REPO_DIR" && ls -la) || true
      echo
      echo "-- Runtime Workspace Git Status --"
      git -C "$workspace_dir" status --short || true
      echo
      echo "-- Runtime Workspace Root Files --"
      (cd "$workspace_dir" && ls -la) || true
      echo
      echo "-- Runtime Workspace .devcontainer --"
      if [[ -d "$workspace_dir/.devcontainer" ]]; then
        find "$workspace_dir/.devcontainer" -maxdepth 2 -type f | sort
      else
        echo ".devcontainer directory not found."
      fi
      echo
    fi
    echo "-- Workflow Files --"
    if [[ -d "$REPO_DIR/.github/workflows" ]]; then
      find "$REPO_DIR/.github/workflows" -type f | sort
    else
      echo ".github/workflows directory not found."
    fi
    echo
    echo "-- Current runs-on Values --"
    if [[ -d "$REPO_DIR/.github/workflows" ]]; then
      grep -RIn "runs-on:" "$REPO_DIR/.github/workflows" || true
    else
      echo "No workflows found."
    fi
    echo
    echo "-- GitHub Workflow List --"
    gh workflow list -R "$REPO_SPEC" || true
    echo
    echo "-- GitHub Codespaces List --"
    if codespace_scope_available; then
      gh codespace list --repo "$OWNER/$REPO" || true
    else
      echo "Codespace scope not present on the current gh token."
      echo "Run: gh auth refresh -h $HOST -s codespace"
    fi
    echo
  } | tee -a "$REPORT_FILE"
}

show_devcontainer_preview() {
  local workspace_dir=""

  workspace_dir="$(current_dev_workspace_dir)"
  if [[ -f "$workspace_dir/.devcontainer/devcontainer.json" ]]; then
    {
      echo "-- devcontainer.json preview --"
      if [[ "$workspace_dir" != "$REPO_DIR" ]]; then
        printf 'Preview source: %s\n' "$workspace_dir/.devcontainer/devcontainer.json"
      fi
      sed -n '1,220p' "$workspace_dir/.devcontainer/devcontainer.json"
      echo
    } | tee -a "$REPORT_FILE"
  fi
}

create_basic_devcontainer_if_missing() {
  local has_package_json="false"
  local has_requirements_txt="false"
  local has_pyproject="false"
  local workspace_dir=""

  workspace_dir="$(current_dev_workspace_dir)"

  if [[ -f "$workspace_dir/.devcontainer/devcontainer.json" ]]; then
    info ".devcontainer/devcontainer.json already exists."
    return
  fi

  if ! confirm "No devcontainer found for $SLUG. Create a starter one now?"; then
    return
  fi

  mkdir -p "$workspace_dir/.devcontainer"

  [[ -f "$workspace_dir/package.json" ]] && has_package_json="true"
  [[ -f "$workspace_dir/requirements.txt" ]] && has_requirements_txt="true"
  [[ -f "$workspace_dir/pyproject.toml" ]] && has_pyproject="true"

  if [[ "$has_package_json" == "true" && ( "$has_requirements_txt" == "true" || "$has_pyproject" == "true" ) ]]; then
    cat > "$workspace_dir/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "local-devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:bookworm",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20"
    },
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.11"
    }
  },
  "forwardPorts": [3000, 5173, 8000, 8080],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-azuretools.vscode-docker",
        "github.vscode-github-actions"
      ]
    }
  }
}
EOF
  elif [[ "$has_package_json" == "true" ]]; then
    cat > "$workspace_dir/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "local-devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:bookworm",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20"
    }
  },
  "forwardPorts": [3000, 5173, 8080],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-azuretools.vscode-docker",
        "github.vscode-github-actions"
      ]
    }
  }
}
EOF
  else
    cat > "$workspace_dir/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "local-devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:bookworm",
  "forwardPorts": [8000, 8080],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-azuretools.vscode-docker",
        "github.vscode-github-actions"
      ]
    }
  }
}
EOF
  fi

  cat > "$workspace_dir/.devcontainer/.csa-ilem-generated" <<EOF
generated_by=$APP_NAME
EOF

  {
    echo "-- Created starter .devcontainer/devcontainer.json --"
    printf 'Target workspace: %s\n' "$workspace_dir"
    cat "$workspace_dir/.devcontainer/devcontainer.json"
    echo "-- Marked as a $APP_NAME-generated local starter --"
    echo
  } | tee -a "$REPORT_FILE"
}

offer_local_devcontainer_start() {
  local devcontainer_log=""
  local test_mode=""
  local command_ok=0
  local workspace_dir=""

  workspace_dir="$(current_dev_workspace_dir)"

  if [[ ! -f "$workspace_dir/.devcontainer/devcontainer.json" ]]; then
    info "No devcontainer file found. Skipping local devcontainer test."
    return
  fi

  ensure_docker_cli
  ensure_devcontainers_cli

  if ! ensure_docker_ready_for_devcontainers; then
    echo "Devcontainer build/start test: SKIPPED (Docker not ready)" | tee -a "$REPORT_FILE"
    return
  fi

  echo
  print_line
  echo "Devcontainer Test Mode"
  print_line
  if project_is_codespaces_ready "$workspace_dir"; then
    echo "This imported GitHub project already has a Codespaces/devcontainer configuration."
    echo "Recommended default: quick startup check only."
  fi
  if project_has_generated_devcontainer "$workspace_dir"; then
    echo "This workspace is a $APP_NAME-generated local starter."
  fi
  if devcontainer_config_has_post_create "$workspace_dir"; then
    echo "This repo has a postCreateCommand and a full setup may take a while."
  fi
  if devcontainer_config_uses_dind "$workspace_dir"; then
    echo "This repo uses docker-in-docker; full setup can look stuck locally even when the container starts."
  fi
  echo
  echo "1) Quick startup check (recommended)"
  echo "2) Full setup test (runs postCreateCommand)"
  echo "3) Skip"
  echo

  if [[ "$FULL_AUTO" -eq 1 ]]; then
    test_mode="quick"
    info "FULL AUTO: using quick devcontainer startup check."
  else
    while true; do
      read -r -p "Enter choice [1-3] (Enter = 1): " test_mode
      case "$test_mode" in
        ""|1)
          test_mode="quick"
          break
          ;;
        2)
          test_mode="full"
          break
          ;;
        3)
          echo "Devcontainer build/start test: SKIPPED" | tee -a "$REPORT_FILE"
          return
          ;;
        *)
          warn "Invalid choice."
          ;;
      esac
    done
  fi

  if [[ "$test_mode" == "full" ]]; then
    if project_has_generated_devcontainer "$workspace_dir"; then
      warn "This repo is using a $APP_NAME-generated local starter devcontainer, not an original checked-in Codespaces config."
    fi
    if devcontainer_config_has_post_create "$workspace_dir" || devcontainer_config_uses_dind "$workspace_dir"; then
      if ! confirm "Full setup may take a while or look stuck. Continue anyway?"; then
        echo "Devcontainer full setup test: SKIPPED" | tee -a "$REPORT_FILE"
        return
      fi
    fi
  fi

  devcontainer_log="$REPORTS_DIR/$(sanitize_label "$SLUG")-devcontainer-$(date +%Y%m%d-%H%M%S).log"

  if [[ "$test_mode" == "quick" && ! devcontainer_cli_supports_skip_post_create ]]; then
    warn "This devcontainer CLI does not support --skip-post-create. Skipping the quick startup check to avoid running the full postCreateCommand by accident."
    echo "Devcontainer startup check: SKIPPED (--skip-post-create not supported)" | tee -a "$REPORT_FILE"
    return
  fi

  if [[ "$test_mode" == "quick" ]]; then
    if devcontainer up --skip-post-create --workspace-folder "$workspace_dir" 2>&1 | tee "$devcontainer_log"; then
      command_ok=1
    fi
  else
    if devcontainer up --workspace-folder "$workspace_dir" 2>&1 | tee "$devcontainer_log"; then
      command_ok=1
    fi
  fi

  if [[ "$command_ok" -eq 0 ]]; then
    echo "Devcontainer build/start test: FAILED" | tee -a "$REPORT_FILE"
    printf 'Devcontainer log: %s\n' "$devcontainer_log" | tee -a "$REPORT_FILE"
  elif grep -Fq "postCreateCommand from devcontainer.json interrupted." "$devcontainer_log"; then
    echo "Devcontainer full setup test: PARTIAL (postCreate interrupted)" | tee -a "$REPORT_FILE"
    printf 'Devcontainer log: %s\n' "$devcontainer_log" | tee -a "$REPORT_FILE"
    warn "The container started, but postCreateCommand did not finish cleanly."
  elif [[ "$test_mode" == "quick" ]]; then
    echo "Devcontainer startup check: SUCCESS (postCreate skipped)" | tee -a "$REPORT_FILE"
  else
    echo "Devcontainer full setup test: SUCCESS" | tee -a "$REPORT_FILE"
  fi

  if grep -Fq "Failed to start docker, retrying" "$devcontainer_log"; then
    warn "The local Docker engine is running, but the devcontainer is also trying to start Docker inside the container."
    if grep -Fq "docker-in-docker" "$workspace_dir/.devcontainer/devcontainer.json"; then
      warn "This repo uses the docker-in-docker feature. The issue is likely repo-specific devcontainer configuration, not Docker Desktop installation."
    else
      warn "This looks like an in-container Docker startup issue, not a local Docker Desktop startup issue."
    fi
    echo "Review .devcontainer/devcontainer.json and Docker-related features/mounts before retrying." | tee -a "$REPORT_FILE"
  fi
}

offer_codespace_guidance() {
  {
    echo "== Codespace -> Local Guidance =="
    echo
    if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
      echo "Diamond mode keeps the plain repo and runtime workspace separate:"
      printf '  Plain repo workspace: %s\n' "$CODE_REPO_DIR"
      printf '  Runtime/local Codespace workspace: %s\n' "$DEV_REPO_DIR"
      echo
    fi
    if ! repo_has_devcontainer_file "$REPO_DIR"; then
      echo "This repo does not include a checked-in devcontainer yet."
      printf '%s can generate a local starter, but that is not the same as a portable existing Codespaces definition.\n' "$APP_NAME"
      echo
    fi
    if ! codespace_scope_available; then
      echo "The current gh token does not include the codespace scope."
      echo "Without that scope, this mode can sync the repo and prepare the local runtime workspace,"
      echo "but it cannot inspect or export live Codespaces directly."
      echo
    fi
    echo "If the Codespace has newer work than the repo remote:"
    echo "1. Commit and push it from the Codespace first."
    echo "2. Or export any uncommitted files before deletion."
    echo
    echo "Useful commands:"
    echo "  gh codespace list --repo $OWNER/$REPO"
    echo "  gh codespace ssh -c <codespace-name>"
    echo
  } | tee -a "$REPORT_FILE"
}

backup_workflows() {
  local backup_dir
  backup_dir="$BACKUPS_DIR/$(sanitize_label "$SLUG")-workflows-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"

  if [[ -d "$REPO_DIR/.github/workflows" ]]; then
    cp -R "$REPO_DIR/.github/workflows" "$backup_dir/"
    printf 'Workflow backup created at: %s\n' "$backup_dir" | tee -a "$REPORT_FILE"
  else
    echo "No workflow folder to back up." | tee -a "$REPORT_FILE"
  fi
}

patch_workflows_for_self_hosted_apply() {
  local changed="false"
  local file=""

  if ! command -v perl >/dev/null 2>&1; then
    install_tool_if_missing perl perl
  fi

  if [[ ! -d "$REPO_DIR/.github/workflows" ]]; then
    info "No workflow folder found. Skipping workflow patch."
    return
  fi

  backup_workflows

  while IFS= read -r -d '' file; do
    if grep -Eq 'runs-on:[[:space:]]*(ubuntu-latest|macos-latest|macos-13|macos-14)' "$file"; then
      perl -0pi -e 's/runs-on:\s*ubuntu-latest/runs-on: [self-hosted, macOS, '"$LOCAL_LABEL"']/g' "$file"
      perl -0pi -e 's/runs-on:\s*macos-latest/runs-on: [self-hosted, macOS, '"$LOCAL_LABEL"']/g' "$file"
      perl -0pi -e 's/runs-on:\s*macos-13/runs-on: [self-hosted, macOS, '"$LOCAL_LABEL"']/g' "$file"
      perl -0pi -e 's/runs-on:\s*macos-14/runs-on: [self-hosted, macOS, '"$LOCAL_LABEL"']/g' "$file"
      changed="true"
    fi
  done < <(find "$REPO_DIR/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

  {
    echo
    echo "== Patched runs-on values =="
    grep -RIn "runs-on:" "$REPO_DIR/.github/workflows" || true
    echo
  } | tee -a "$REPORT_FILE"

  if [[ "$changed" != "true" ]]; then
    warn "No common GitHub-hosted runs-on values were found to patch."
  fi
}

patch_workflows_for_self_hosted() {
  if ! confirm "Patch workflow files to use the self-hosted Mac runner for $SLUG?"; then
    return
  fi

  patch_workflows_for_self_hosted_apply
}

offer_commit_workflow_changes() {
  if [[ ! -d "$REPO_DIR/.github/workflows" ]]; then
    return
  fi

  cd "$REPO_DIR"
  if git diff --quiet -- .github/workflows; then
    info "No workflow changes to commit."
    return
  fi

  git status --short .github/workflows | tee -a "$REPORT_FILE"

  if ! confirm "Commit patched workflow changes now?"; then
    return
  fi

  git add .github/workflows
  git commit -m "CSA-iEM: switch workflows to self-hosted mac runner"
  echo "Workflow changes committed locally." | tee -a "$REPORT_FILE"

  if confirm "Push this commit to origin now?"; then
    git push origin HEAD
    echo "Workflow changes pushed." | tee -a "$REPORT_FILE"
  fi
}

run_recommended_cost_control_for_slug() {
  local slug="$1"
  local old_mode="$MODE"
  local cost_failed=0

  ensure_github_ready_for_browser_actions
  prepare_repo_vars "$slug"
  MODE="cost_control"
  write_report_header
  show_cost_control_summary_for_slug "$slug" | tee -a "$REPORT_FILE"
  echo | tee -a "$REPORT_FILE"

  if ! disable_repo_actions_in_settings; then
    cost_failed=1
  fi

  reset_cleanup_plan
  DO_DISABLE=1
  DO_RUNS=1
  DO_ARTIFACTS=1
  DO_CACHES=1
  DO_CODESPACES=1

  if ! disable_workflows_cleanup; then
    cost_failed=1
  fi
  if ! delete_runs_cleanup; then
    cost_failed=1
  fi
  if ! delete_artifacts_cleanup; then
    cost_failed=1
  fi
  if ! delete_caches_cleanup; then
    cost_failed=1
  fi
  if ! delete_codespaces_cleanup; then
    cost_failed=1
  fi
  if ! stop_runner_service_for_dir "$RUNNER_DIR"; then
    cost_failed=1
  fi
  if ! stop_active_containers_for_slug "$slug"; then
    cost_failed=1
  fi

  if [[ -d "$REPO_DIR/.github/workflows" ]]; then
    patch_workflows_for_self_hosted_apply
    offer_commit_workflow_changes
  fi

  MODE="$old_mode"

  echo | tee -a "$REPORT_FILE"
  if [[ "$cost_failed" -eq 1 ]]; then
    warn "Recommended no-spend safeguards finished with errors for $REPO_SPEC"
  else
    info "Recommended no-spend safeguards finished for $REPO_SPEC"
  fi

  printf 'Cost-control report saved to: %s\n' "$REPORT_FILE"
  return "$cost_failed"
}

runner_is_configured() {
  [[ -x "$RUNNER_DIR/config.sh" && -f "$RUNNER_DIR/.runner" ]]
}

runner_service_is_installed() {
  local service_state=""

  service_state="$(runner_service_status_state_for_dir "$RUNNER_DIR")"
  [[ "$service_state" != "missing-helper" && "$service_state" != "not-installed" ]]
}

install_and_start_runner_service() {
  local service_ok=0
  local status_output=""
  local service_state=""

  cd "$RUNNER_DIR"

  if [[ ! -x "./svc.sh" ]]; then
    warn "Runner service helper was not found at $RUNNER_DIR/svc.sh"
    return 1
  fi

  service_state="$(runner_service_status_state_for_dir "$RUNNER_DIR")"
  if [[ "$service_state" == "running" ]]; then
    info "Runner service is already running."
    status_output="$(runner_service_status_output_for_dir "$RUNNER_DIR")"
    [[ -n "$status_output" ]] && printf '%s\n' "$status_output" | tee -a "$REPORT_FILE"
    return 0
  fi

  if ! runner_service_is_installed; then
    echo "Installing runner service..." | tee -a "$REPORT_FILE"
    if ./svc.sh install 2>&1 | tee -a "$REPORT_FILE"; then
      info "Runner service installed."
    else
      warn "Runner service install failed."
      echo "The runner is configured, but the service is not installed." | tee -a "$REPORT_FILE"
      echo "Retry manually from: $RUNNER_DIR" | tee -a "$REPORT_FILE"
      echo "Command: ./svc.sh install" | tee -a "$REPORT_FILE"
      return 1
    fi
  else
    info "Runner service is already installed."
  fi

  echo "Starting runner service..." | tee -a "$REPORT_FILE"
  if ./svc.sh start 2>&1 | tee -a "$REPORT_FILE"; then
    :
  else
    warn "Runner service start failed."
    echo "The runner is configured, but the service did not start." | tee -a "$REPORT_FILE"
    echo "Retry manually from: $RUNNER_DIR" | tee -a "$REPORT_FILE"
    echo "Commands: ./svc.sh start  or  ./run.sh" | tee -a "$REPORT_FILE"
  fi

  status_output="$(runner_service_status_output_for_dir "$RUNNER_DIR")"
  service_state="$(runner_service_status_state_for_dir "$RUNNER_DIR")"
  if [[ -n "$status_output" ]]; then
    echo "Runner service status:" | tee -a "$REPORT_FILE"
    printf '%s\n' "$status_output" | tee -a "$REPORT_FILE"
  fi

  case "$service_state" in
    running)
      service_ok=1
      info "Runner service started."
      ;;
    not-installed)
      warn "Runner service is not installed correctly."
      ;;
    stopped|configured)
      warn "Runner service did not report as running."
      ;;
    *)
      warn "Runner service state is unknown."
      ;;
  esac

  [[ "$service_ok" -eq 1 ]]
}

install_repo_runner() {
  local arch=""
  local api_arch=""
  local tag_name=""
  local version=""
  local tarball=""
  local token=""

  if ! confirm "Install and register a repo-level self-hosted runner for $SLUG on this Mac?"; then
    return
  fi

  mkdir -p "$RUNNER_DIR"

  if runner_is_configured; then
    printf 'Runner already configured at: %s\n' "$RUNNER_DIR" | tee -a "$REPORT_FILE"
  else
    arch="$(uname -m)"
    case "$arch" in
      arm64) api_arch="arm64" ;;
      x86_64) api_arch="x64" ;;
      *)
        err "Unsupported Mac architecture: $arch"
        return
        ;;
    esac

    tag_name="$(gh api repos/actions/runner/releases/latest --jq '.tag_name')"
    version="${tag_name#v}"
    tarball="actions-runner-osx-${api_arch}-${version}.tar.gz"

    {
      printf 'Using runner version: %s\n' "$version"
      echo "Downloading runner package..."
    } | tee -a "$REPORT_FILE"

    cd "$RUNNER_DIR"
    gh release download "$tag_name" --repo actions/runner --pattern "$tarball" --clobber
    tar xzf "$tarball"

    echo "Requesting repo registration token..." | tee -a "$REPORT_FILE"
    token="$(gh api --hostname "$HOST" -X POST "repos/${OWNER}/${REPO}/actions/runners/registration-token" --jq '.token')"

    echo "Configuring runner..." | tee -a "$REPORT_FILE"
    ./config.sh \
      --url "https://${HOST}/${OWNER}/${REPO}" \
      --token "$token" \
      --name "$RUNNER_NAME" \
      --labels "$LOCAL_LABEL" \
      --work "_work" \
      --unattended \
      --replace
  fi

  install_and_start_runner_service || true

  {
    echo
    printf 'Runner configured: %s\n' "$RUNNER_NAME"
    printf 'Runner label: %s\n' "$LOCAL_LABEL"
    printf 'Runner path: %s\n' "$RUNNER_DIR"
    echo
  } | tee -a "$REPORT_FILE"
}

offer_validation_notes() {
  {
    echo "== Validation Notes =="
    echo
    echo "1. Confirm the runner shows as online in:"
    echo "   Repo -> Settings -> Actions -> Runners"
    echo
    echo "2. Trigger a workflow run after pushing any patched workflow file."
    echo
    echo "3. Confirm jobs land on:"
    printf '   [self-hosted, macOS, %s]\n' "$LOCAL_LABEL"
    echo
  } | tee -a "$REPORT_FILE"
}

open_in_vscode_tip() {
  local app_path=""
  local runtime_workspace=""

  runtime_workspace="$(current_dev_workspace_dir)"

  {
    echo "== VS Code Tip =="
    echo
    if command -v code >/dev/null 2>&1; then
      printf 'Open plain repo locally:\n  code "%s"\n' "$REPO_DIR"
      if [[ "$runtime_workspace" != "$REPO_DIR" ]]; then
        printf 'Open runtime/local Codespace workspace:\n  code "%s"\n' "$runtime_workspace"
      fi
    else
      app_path="$(find_vscode_app || true)"
      if [[ -n "$app_path" ]]; then
        printf 'Open Visual Studio Code, then open this plain repo folder:\n  %s\n' "$REPO_DIR"
        if [[ "$runtime_workspace" != "$REPO_DIR" ]]; then
          printf 'Runtime/local Codespace folder:\n  %s\n' "$runtime_workspace"
        fi
      else
        printf 'Open this plain repo folder in your editor:\n  %s\n' "$REPO_DIR"
        if [[ "$runtime_workspace" != "$REPO_DIR" ]]; then
          printf 'Runtime/local Codespace folder:\n  %s\n' "$runtime_workspace"
        fi
      fi
    fi
    echo
    echo "Then run:"
    echo "  Dev Containers: Reopen in Container"
    echo
  } | tee -a "$REPORT_FILE"
}

process_repo() {
  prepare_repo_vars "$1"
  save_last_session

  echo
  print_line
  printf 'Processing: %s\n' "$REPO_SPEC"
  print_line

  case "$MODE" in
    cleanup_only)
      if ! verify_repo_access "$REPO_SPEC"; then
        return 1
      fi
      write_report_header
      {
        echo "== Cleanup Only =="
        echo
        echo "Cleanup-only mode skips local clone/update, devcontainer, and runner preparation."
        echo
      } | tee -a "$REPORT_FILE"
      run_cleanup_flow
      ;;
    codespace_to_local)
      if ! clone_or_update_repo; then
        err "Failed to prepare $REPO_SPEC"
        return 1
      fi
      write_report_header
      audit_repo
      show_devcontainer_preview
      offer_codespace_guidance
      create_basic_devcontainer_if_missing
      offer_local_devcontainer_start
      install_repo_runner
      patch_workflows_for_self_hosted
      offer_commit_workflow_changes
      offer_validation_notes
      open_in_vscode_tip
      run_cleanup_flow
      ;;
    repo_to_local)
      if ! clone_or_update_repo; then
        err "Failed to prepare $REPO_SPEC"
        return 1
      fi
      write_report_header
      audit_repo
      show_devcontainer_preview
      create_basic_devcontainer_if_missing
      offer_local_devcontainer_start
      open_in_vscode_tip
      ;;
    repo_to_local_plus)
      if ! clone_or_update_repo; then
        err "Failed to prepare $REPO_SPEC"
        return 1
      fi
      write_report_header
      audit_repo
      show_devcontainer_preview
      create_basic_devcontainer_if_missing
      offer_local_devcontainer_start
      install_repo_runner
      patch_workflows_for_self_hosted
      offer_commit_workflow_changes
      offer_validation_notes
      open_in_vscode_tip
      run_cleanup_flow
      ;;
  esac

  echo
  printf 'Done: %s\n' "$REPO_SPEC"
  printf 'Report saved to: %s\n' "$REPORT_FILE"
  printf 'Code repo path: %s\n' "$REPO_DIR"
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    printf 'Runtime workspace path: %s\n' "$DEV_REPO_DIR"
  fi
}

process_selected_repositories() {
  local total=0
  local idx=1
  local repo_slug=""
  local repo_status=0
  local successful_repos=()

  FAILED_REPOS=()
  total="${#SELECTED_REPOS[@]}"
  for repo_slug in "${SELECTED_REPOS[@]}"; do
    echo
    print_line
    printf 'Repo %s of %s\n' "$idx" "$total"
    print_line

    repo_status=0
    if (
      set +e
      process_repo "$repo_slug"
    ); then
      successful_repos+=("$repo_slug")
    else
      repo_status=$?
      FAILED_REPOS+=("$repo_slug")
      warn "Processing failed for $repo_slug (exit $repo_status)."
      warn "Skipping to the next repo."
    fi

    if [[ "$idx" -lt "$total" ]]; then
      echo
      if ! confirm "Continue to the next repo?"; then
        echo "Stopped by user."
        break
      fi
    fi

    idx=$((idx + 1))
  done

  if [[ "$total" -gt 1 || "$FULL_AUTO" -eq 1 ]]; then
    show_batch_inventory_summary "$total" "${#successful_repos[@]}" "${#FAILED_REPOS[@]}"

    if [[ "${#FAILED_REPOS[@]}" -gt 0 ]]; then
      echo
      printf 'Skipped after errors: %s\n' "${#FAILED_REPOS[@]}"
      printf '%s\n' "${FAILED_REPOS[@]}"
    fi

    if [[ "$FULL_AUTO" -eq 1 && "${#successful_repos[@]}" -gt 0 ]]; then
      echo
      if manual_confirm "Open the successful projects from this batch one at a time in VS Code now?"; then
        review_projects_one_by_one "${successful_repos[@]}"
      fi
    fi
  fi
}

parse_cli_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help
        exit 0
        ;;
      --version|-v)
        printf '%s %s\n' "$APP_NAME" "$APP_VERSION"
        exit 0
        ;;
      --about)
        show_about
        exit 0
        ;;
      --notice)
        show_doc_file "Notice" "$APP_NOTICE_FILE"
        exit 0
        ;;
      --terms)
        show_doc_file "Terms Of Service" "$APP_TERMS_FILE"
        exit 0
        ;;
      --privacy)
        show_doc_file "Privacy Notice" "$APP_PRIVACY_FILE"
        exit 0
        ;;
      --disclaimer)
        show_doc_file "Disclaimer" "$APP_DISCLAIMER_FILE"
        exit 0
        ;;
      --profile)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--profile requires a value of public, wtl, or diamond."
          exit 1
        fi
        PROFILE_NAME="$1"
        ;;
      --profile=*)
        PROFILE_NAME="${1#*=}"
        ;;
      --host)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--host requires a value."
          exit 1
        fi
        HOST="$1"
        ;;
      --host=*)
        HOST="${1#*=}"
        ;;
      --account)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--account requires a value."
          exit 1
        fi
        ACCOUNT="$1"
        ;;
      --account=*)
        ACCOUNT="${1#*=}"
        ;;
      --repo)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--repo requires a value."
          exit 1
        fi
        REPO_SPEC="$1"
        ;;
      --repo=*)
        REPO_SPEC="${1#*=}"
        ;;
      --import-mode)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--import-mode requires a value of codespace, repo, or repo-plus."
          exit 1
        fi
        if ! IMPORT_MODE_NAME="$(normalize_import_mode "$1")"; then
          err "Unknown import mode: $1"
          exit 1
        fi
        DIRECT_IMPORT_MODE=1
        ;;
      --import-mode=*)
        if ! IMPORT_MODE_NAME="$(normalize_import_mode "${1#*=}")"; then
          err "Unknown import mode: ${1#*=}"
          exit 1
        fi
        DIRECT_IMPORT_MODE=1
        ;;
      --import-full-auto)
        FULL_AUTO=1
        FULL_AUTO_CLEANUP=0
        DIRECT_IMPORT_MODE=1
        ;;
      --import-cleanup-preview)
        FULL_AUTO=1
        FULL_AUTO_CLEANUP=1
        DIRECT_IMPORT_MODE=1
        ;;
      --disable-workflows)
        DO_DISABLE=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --delete-runs)
        DO_RUNS=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --run)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--run requires a value."
          exit 1
        fi
        TARGET_RUN_ID="$1"
        DO_RUNS=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --run=*)
        TARGET_RUN_ID="${1#*=}"
        DO_RUNS=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --run-filter)
        shift
        if [[ "$#" -eq 0 ]]; then
          err "--run-filter requires a value."
          exit 1
        fi
        RUN_FILTER="$1"
        DO_RUNS=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --run-filter=*)
        RUN_FILTER="${1#*=}"
        DO_RUNS=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --delete-artifacts)
        DO_ARTIFACTS=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --delete-caches)
        DO_CACHES=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --delete-codespaces)
        DO_CODESPACES=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --all)
        FULL_CLEANUP=1
        DO_DISABLE=1
        DO_RUNS=1
        DO_ARTIFACTS=1
        DO_CACHES=1
        DO_CODESPACES=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --yes)
        ASSUME_YES=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --dry-run)
        DRY_RUN=1
        DIRECT_CLEANUP_MODE=1
        ;;
      --no-color)
        NO_COLOR=1
        ;;
      --browse)
        ENTRY_MODE="browse"
        ;;
      --browse-projects)
        ENTRY_MODE="projects"
        ;;
      --browse-cost-control)
        ENTRY_MODE="costcontrol"
        ;;
      --browse-devcontainers)
        ENTRY_MODE="devcontainers"
        ;;
      --use-current-root)
        AUTO_USE_CURRENT_ROOT=1
        ;;
      *)
        err "Unknown argument: $1"
        exit 1
        ;;
    esac
    shift
  done

  if [[ -n "$REPO_SPEC" ]]; then
    if [[ "$REPO_SPEC" =~ ^https?://([^/]+)/ ]]; then
      HOST="${BASH_REMATCH[1]}"
    elif [[ "$REPO_SPEC" == */*/* ]]; then
      HOST="${REPO_SPEC%%/*}"
    fi
  fi

  if [[ "$DIRECT_IMPORT_MODE" -eq 1 ]]; then
    [[ -z "$PROFILE_NAME" ]] && PROFILE_NAME="public"
    AUTO_USE_CURRENT_ROOT=1
  elif [[ "$DIRECT_CLEANUP_MODE" -eq 1 ]]; then
    [[ -z "$PROFILE_NAME" ]] && PROFILE_NAME="public"
    AUTO_USE_CURRENT_ROOT=1
  fi
}

main() {
  ensure_macos
  trap cleanup_on_exit EXIT
  parse_cli_args "$@"
  init_colors
  load_last_session

  print_line
  printf '%s v%s\n' "$APP_NAME" "$APP_VERSION"
  echo "$APP_FULL_NAME"
  echo "$APP_TAGLINE"
  printf 'Provided by %s | %s | %s\n' "$APP_VENDOR" "$APP_VENDOR_URL" "$APP_RISK_NOTICE"
  print_line
  echo

  show_preflight_scan
  select_profile
  info "Using the $PROFILE_LABEL edition."

  if [[ "$ENTRY_MODE" == "interactive" || "$DIRECT_CLEANUP_MODE" -eq 1 || "$DIRECT_IMPORT_MODE" -eq 1 ]]; then
    install_brew_if_missing
    ensure_brew_shellenv_in_profile

    install_tool_if_missing git git
    install_tool_if_missing gh gh

    require_cmd git "Install git first."
    require_cmd gh "Install GitHub CLI first."
    select_host
    select_account
    ensure_api_ready
  else
    info "Using local browser mode. GitHub auth and API checks are skipped."
  fi

  if [[ "$AUTO_USE_CURRENT_ROOT" -eq 1 ]]; then
    use_current_root_defaults
  else
    choose_root
  fi

  if [[ "$ENTRY_MODE" == "browse" ]]; then
    browse_local_resources
  elif [[ "$ENTRY_MODE" == "projects" ]]; then
    browse_imported_projects_quick
  elif [[ "$ENTRY_MODE" == "costcontrol" ]]; then
    browse_cost_control_review
  elif [[ "$ENTRY_MODE" == "devcontainers" ]]; then
    browse_installed_devcontainers
  elif [[ "$DIRECT_IMPORT_MODE" -eq 1 ]]; then
    if [[ -z "$IMPORT_MODE_NAME" ]]; then
      err "A direct import run requires --import-mode codespace, repo, or repo-plus."
      exit 1
    fi
    if [[ -z "$REPO_SPEC" ]]; then
      err "A direct import run requires --repo OWNER/REPO."
      exit 1
    fi
    if ! REPO_SPEC="$(normalize_repo_input "$REPO_SPEC")"; then
      exit 1
    fi
    MODE="$IMPORT_MODE_NAME"
    SELECTED_REPOS=("$REPO_SPEC")
    process_selected_repositories
  elif [[ "$DIRECT_CLEANUP_MODE" -eq 1 ]]; then
    MODE="cleanup_only"
    if [[ -z "$REPO_SPEC" ]]; then
      REPO_SPEC="$(prompt_nonempty "GitHub repo (OWNER/REPO, HOST/OWNER/REPO, or https://HOST/OWNER/REPO)" "${LAST_REPO_SPEC#*/}")"
    fi
    if ! REPO_SPEC="$(normalize_repo_input "$REPO_SPEC")"; then
      exit 1
    fi
    SELECTED_REPOS=("$REPO_SPEC")
    process_selected_repositories
  else
    main_menu_loop
  fi

  echo
  print_line
  echo "All done"
  print_line
  printf 'Edition: %s\n' "$PROFILE_LABEL"
  if [[ "$STORAGE_LAYOUT" == "diamond" ]]; then
    printf 'Code root: %s\n' "$CODE_ROOT"
    printf 'Runtime root: %s\n' "$RUNTIME_ROOT"
  else
    printf 'Root workspace: %s\n' "$ROOT"
  fi
}

main "$@"
