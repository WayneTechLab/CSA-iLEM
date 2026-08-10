#!/usr/bin/env bash
set -eo pipefail
umask 077
export LC_ALL=C

APP_NAME="CSA-iEM"
APP_REPOSITORY="WayneTechLab/CSA-iLEM"
LEGACY_APP_REPOSITORY="WayneTechLab/CSA-iEM"
SOURCE_ROOT="${CSA_IEM_STAGE2_SOURCE:-$HOME/CODEX PROJECTS}"
MANAGED_ROOT="${CSA_IEM_STAGE2_ROOT:-$HOME/CSA-iEM}"
GITHUB_HOST="${GH_HOST:-github.com}"
GITHUB_READY=0
ACCOUNT=""
GH_BIN=""
ACTIVE_GITHUB_LOGIN=""
GITHUB_ACCOUNT_BINDINGS=()
GITHUB_BINDINGS_FILE=""
SCOPED_GITHUB_TOKEN=""
SCOPED_GITHUB_LOGIN=""
ACTION="preflight"
SELECT_ALL=0
CREATE_MISSING_REPOS=0
REPO_VISIBILITY="private"
RETIRE_SOURCES=0
DELETE_SOURCES=0
DELETE_CONFIRMATION=""
CREATE_ARCHIVE=0
CLEANUP_TRANSACTION_TEMP=0
PREPARE_RUNTIME=0
ASSUME_YES=0
OPEN_WITH=""
REPORT_PATH=""
PROJECT_SELECTORS=()
EXCLUDED_PATHS=()

TMP_ROOT=""
PLAN_FILE=""
GH_CATALOG=""
DESTINATION_INDEX=""
TRANSACTION_ID=""
CODE_REPOS=""
IMPORT_ROOT=""
IMPORT_STAGE=""
RUNTIME_REPOS=""
REPORTS_DIR=""
RECEIPTS_ROOT=""
RECEIPTS_DIR=""
ARCHIVES_ROOT=""
ARCHIVES_DIR=""
MANAGED_TEMP=""
TMP_PARENT=""
GIT_BIN=""
PYTHON3_BIN=""

CURRENT_GIT_SNAPSHOT=""
CURRENT_GIT_SNAPSHOT_DIGEST=""
CURRENT_GIT_REF_NAMESPACE=""
CURRENT_REPOSITORY_ID=""
CURRENT_REPOSITORY_ROLE=""
CURRENT_PARENT_REPOSITORY=""
CURRENT_EXACT_GIT_REMOTE=""
CURRENT_WIKI_REF_DIGEST=""
CURRENT_WIKI_DEFAULT_BRANCH=""
CURRENT_WIKI_HEAD_OID=""
CURRENT_GITHUB_OWNER=""
CURRENT_GITHUB_LOGIN=""
CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST=""
REPO_ROLE=""
REPO_PARENT_REPOSITORY=""
REPO_EXACT_GIT_REMOTE=""
REPO_WIKI_REF_DIGEST=""
REPO_WIKI_DEFAULT_BRANCH=""
REPO_WIKI_HEAD_OID=""
CURRENT_FILESYSTEM_EVIDENCE=""
CURRENT_FILESYSTEM_EVIDENCE_DIGEST=""
CURRENT_FILESYSTEM_MANIFEST_DIGEST=""
CURRENT_FILESYSTEM_BINDING_DIGEST=""
CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST=""
CURRENT_FILESYSTEM_SOURCE_PATH_HEX=""
CURRENT_FILESYSTEM_SOURCE_DEVICE=""
CURRENT_FILESYSTEM_SOURCE_INODE=""
CURRENT_FILESYSTEM_EXACT_CATEGORIES=""
CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES=""
CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES=""
CURRENT_FILESYSTEM_DESTINATION_DEVICE=""
CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID=""
CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED=""
CURRENT_FILESYSTEM_BINDING_SOURCE=""
CURRENT_VERIFIED_SLUG=""
CURRENT_VERIFIED_SOURCE=""
CURRENT_VERIFIED_DESTINATION=""
CURRENT_VERIFIED_ARCHIVE=""
GIT_SAFETY_ERROR=""
DESTINATION_PATH_MISMATCH=0
DESTINATION_EXPECTED_PATH=""
DESTINATION_MISMATCH_PATH=""

# Repository inspection must never inherit an ambient Git directory, index, or
# alternate object store from the caller. Lazy object fetching would turn a
# local preservation proof into a network-dependent mutation, so it is also
# disabled for every Git command launched by Stage 2.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_INDEX_FILE GIT_NAMESPACE
unset GIT_REPLACE_REF_BASE GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
unset GIT_CONFIG_NOSYSTEM GIT_ATTR_NOSYSTEM GIT_NO_REPLACE_OBJECTS GIT_EXTERNAL_DIFF GIT_DIFF_OPTS
unset GIT_SHALLOW_FILE GIT_GRAFT_FILE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM
export GIT_NO_LAZY_FETCH=1

cleanup() {
  if [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" && -n "$TMP_PARENT" ]] &&
     path_is_strictly_within "$TMP_ROOT" "$TMP_PARENT" &&
     [[ "$(basename "$TMP_ROOT")" == csa-iem-stage2.* ]]; then
    rm -rf -- "$TMP_ROOT"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
CSA-iEM Stage 2 workspace reconciliation

Usage:
  stage2-workspace.sh --source PATH --managed-root PATH --preflight --all
  stage2-workspace.sh --source PATH --managed-root PATH --preflight --project PATH
  stage2-workspace.sh --source PATH --managed-root PATH --apply --project PATH --yes
  stage2-workspace.sh --source PATH --managed-root PATH --full-auto --yes

Selection:
  --all                         Scan every eligible immediate project folder.
  --project PATH_OR_NAME        Select one project; repeat for multi-select.

Actions:
  --preflight                   Build the Git/GitHub safety plan only (default).
  --apply                       Apply only safe plan rows.
  --full-auto                   Equivalent to --apply --all; safety blocks remain.
  --create-missing-repos        Create a missing repository only when the source
                                supplies an explicit GitHub owner/name identity;
                                project files are not uploaded.
  --repo-visibility private|public
                                New repositories are private by default.
  --retire-sources              Move completed Stage 1 folders into _temp after verify.
  --delete-sources              Rejected: permanent cleanup belongs to Stage 3.
  --confirm-delete VALUE        Retained only for CLI compatibility; never authorizes
                                Stage 2 to permanently delete a source.
  --archive-sources             Create and test a full ZIP before Stage 1 cleanup.
  --cleanup-transaction-temp    Remove this run's verified Import/Stage2 staging data.
  --prepare-runtime             Prepare an additive Runtime/Repos mirror after Code.
  --open codex|code|copilot|finder|devcontainer
                                Open each successfully managed project.
  --yes                         Required for --apply and --full-auto.

Identity and safety:
  --host HOST                   GitHub host (default: github.com).
  --account OWNER               Owner for inferred/new repositories.
  --github-account OWNER=LOGIN  Bind an owner to a stored gh login; repeatable.
                                Tokens remain in memory and global auth is unchanged.
  --exclude-path PATH           Exclude an active project path; repeatable.
  --report PATH                 Write the Markdown report to an explicit path.

Stage 2 preserves .git, dependencies, hidden files, and Finder metadata for new
canonical projects. Source unstaged and untracked files may proceed only when an
additive merge plus full-checksum verification proves their canonical
representation. Source conflicts, ongoing Git operations, and every staged index
entry (including intent-to-add) are blocked. Existing canonical projects are
never overwritten when their worktree is dirty, staged, divergent, ambiguous, or
owned by another repository.
Stage 2 never permanently deletes source inputs. With --retire-sources, it may
atomically move a fully verified source to the managed root's _temp folder and
write a receipt for Stage 3 cleanup. ZIP files are supplemental only and never
substitute for canonical checksum or Git verification.
Every cleanup-eligible receipt also binds a deterministic filesystem-evidence-v2
package beneath the canonical repository's .csa-iem-recovery directory. It
records byte-exact path spelling, type/content/link targets, ACL/xattr sidecars,
file information, allocation, and hardlink topology. Fields that cannot be
honestly reproduced on the destination volume remain explicitly record-only.
EOF
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

info() {
  printf '[INFO] %s\n' "$*"
}

isolated_git() {
  local git_executable="$GIT_BIN"

  if [[ -z "$git_executable" ]]; then
    git_executable="$(command -v git 2>/dev/null || true)"
  fi
  [[ -n "$git_executable" && "$git_executable" == /* && -x "$git_executable" && -n "$TMP_ROOT" && -d "$TMP_ROOT" ]] || return 1
  mkdir -p -- "$TMP_ROOT/git-home" "$TMP_ROOT/git-xdg" || return 1
  /usr/bin/env -i \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LC_ALL=C \
    LANG=C \
    HOME="$TMP_ROOT/git-home" \
    XDG_CONFIG_HOME="$TMP_ROOT/git-xdg" \
    TMPDIR="$TMP_ROOT" \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_SYSTEM=/dev/null \
    GIT_ATTR_NOSYSTEM=1 \
    GIT_TERMINAL_PROMPT=0 \
    GIT_OPTIONAL_LOCKS=0 \
    GIT_NO_LAZY_FETCH=1 \
    GIT_NO_REPLACE_OBJECTS=1 \
    "$git_executable" "$@"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

canonical_path() {
  local value="$1"
  local parent=""
  local leaf=""
  local canonical_parent=""

  case "$value" in
    "~") value="$HOME" ;;
    "~/"*) value="$HOME/${value#~/}" ;;
  esac
  [[ -n "$value" ]] || return 1
  [[ "$value" == /* ]] || value="$PWD/$value"
  [[ ! -L "$value" || -e "$value" ]] || return 1

  if [[ -d "$value" ]]; then
    (cd -P -- "$value" 2>/dev/null && pwd -P)
    return
  fi

  parent="$(dirname -- "$value")"
  leaf="$(basename -- "$value")"
  [[ -n "$leaf" && "$leaf" != "." && "$leaf" != ".." ]] || return 1
  canonical_parent="$(canonical_path "$parent")" || return 1
  if [[ "$canonical_parent" == "/" ]]; then
    printf '/%s' "$leaf"
  else
    printf '%s/%s' "$canonical_parent" "$leaf"
  fi
}

normalize_path() {
  canonical_path "$1"
}

normalize_remote_slug() {
  local remote="$1"
  local remainder=""
  local remote_host=""
  local remote_path=""
  local expected_host=""

  remote="$(trim "$remote")"
  [[ -n "$remote" ]] || return 1
  expected_host="$(printf '%s' "$GITHUB_HOST" | tr '[:upper:]' '[:lower:]')"
  case "$remote" in
    git@*:*)
      remainder="${remote#git@}"
      remote_host="${remainder%%:*}"
      remote_path="${remainder#*:}"
      ;;
    ssh://*)
      remainder="${remote#ssh://}"
      remainder="${remainder#git@}"
      remote_host="${remainder%%/*}"
      [[ "$remainder" == */* ]] || return 1
      remote_path="${remainder#*/}"
      ;;
    https://*|http://*)
      remainder="${remote#https://}"
      remainder="${remainder#http://}"
      remainder="${remainder#*@}"
      remote_host="${remainder%%/*}"
      [[ "$remainder" == */* ]] || return 1
      remote_path="${remainder#*/}"
      ;;
    */*)
      remote_host="${remote%%/*}"
      remote_path="${remote#*/}"
      ;;
    *) return 1 ;;
  esac
  remote_host="${remote_host#www.}"
  [[ "$(printf '%s' "$remote_host" | tr '[:upper:]' '[:lower:]')" == "$expected_host" ]] || return 1
  remote_path="${remote_path#/}"
  remote_path="${remote_path%/}"
  remote_path="${remote_path%.git}"
  remote_path="$(trim "$remote_path")"
  valid_repository_slug "$remote_path" || return 1
  printf '%s' "$remote_path"
}

identity_key() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

slugify_repo_name() {
  local value="$1"
  value="$(printf '%s' "$value" | tr ' ' '-' | tr -cd '[:alnum:]_.-')"
  while [[ "$value" == *--* ]]; do value="${value//--/-}"; done
  value="${value#-}"
  value="${value%-}"
  [[ -n "$value" ]] || value="imported-project"
  printf '%s' "$value"
}

path_is_within() {
  local candidate="$1"
  local root="$2"
  candidate="$(canonical_path "$candidate")" || return 1
  root="$(canonical_path "$root")" || return 1
  [[ "$candidate" == "$root" || "$candidate" == "$root/"* ]]
}

path_is_strictly_within() {
  local candidate="$1"
  local root="$2"
  candidate="$(canonical_path "$candidate")" || return 1
  root="$(canonical_path "$root")" || return 1
  [[ "$candidate" == "$root/"* ]]
}

require_strict_containment() {
  local candidate="$1"
  local root="$2"
  local label="$3"
  path_is_strictly_within "$candidate" "$root" || {
    warn "$label is outside its canonical safety root: $candidate (root: $root)"
    return 1
  }
}

ensure_managed_directory() {
  local requested="$1"
  local label="$2"
  local canonical=""

  require_strict_containment "$requested" "$MANAGED_ROOT" "$label" || return 1
  if [[ -L "$requested" ]]; then
    warn "$label must not be a symlink: $requested"
    return 1
  fi
  if [[ ! -e "$requested" ]]; then
    mkdir -- "$requested" || return 1
  fi
  [[ -d "$requested" ]] || {
    warn "$label is not a directory: $requested"
    return 1
  }
  canonical="$(canonical_path "$requested")" || return 1
  require_strict_containment "$canonical" "$MANAGED_ROOT" "$label" || return 1
  printf '%s' "$canonical"
}

valid_repository_slug() {
  local slug="$1"
  local owner=""
  local repository=""

  [[ "$slug" == */* && "$slug" != */*/* ]] || return 1
  owner="${slug%%/*}"
  repository="${slug#*/}"
  [[ -n "$owner" && -n "$repository" ]] || return 1
  [[ "$owner" != "." && "$owner" != ".." && "$repository" != "." && "$repository" != ".." ]] || return 1
  [[ "$owner" =~ ^[A-Za-z0-9_.-]+$ && "$repository" =~ ^[A-Za-z0-9_.-]+$ ]]
}

is_reserved_project() {
  local source_path="$1"
  local slug="${2:-}"
  local source_name=""
  local source_key=""
  local normalized_slug=""
  local excluded=""

  source_name="$(basename "$source_path")"
  source_key="$(identity_key "$source_name")"
  normalized_slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]')"
  if [[ "$source_key" == "csaiem" || "$source_key" == "csailem" ]]; then
    return 0
  fi
  if [[ -n "$slug" &&
        ( "$normalized_slug" == "$(printf '%s' "$APP_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ||
          "$normalized_slug" == "$(printf '%s' "$LEGACY_APP_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ) ]]; then
    return 0
  fi
  for excluded in "${EXCLUDED_PATHS[@]}"; do
    if path_is_within "$source_path" "$excluded" || path_is_within "$excluded" "$source_path"; then
      return 0
    fi
  done
  return 1
}

has_project_evidence() {
  local path="$1"
  local marker=""

  [[ -d "$path/.git" || -f "$path/.git" ]] && return 0
  for marker in package.json package-lock.json pnpm-lock.yaml yarn.lock pyproject.toml requirements.txt Cargo.toml go.mod Gemfile composer.json Package.swift firebase.json pom.xml build.gradle build.gradle.kts mix.exs pubspec.yaml deno.json deno.jsonc '*.xcodeproj' '*.xcworkspace' Transfer_Note.md Prompt_Inject.md; do
    if compgen -G "$path/$marker" >/dev/null 2>&1; then
      return 0
    fi
  done
  [[ -d "$path/src" || -d "$path/app" || -d "$path/lib" || -d "$path/server" || -d "$path/client" ||
     -d "$path/functions" || -d "$path/ios" || -d "$path/android" || -d "$path/packages" ||
     -d "$path/apps" || -d "$path/.devcontainer" || -d "$path/.SYSTEMX" ]]
}

is_staging_artifact_name() {
  local name="$1"
  case "$name" in
    *.csa-iem-stage-*|*.migrate-*|*.moved-*|*.partial-*|*.transfer-candidate|*.admin-verified|*.data-copy)
      return 0
      ;;
  esac
  return 1
}

should_skip_folder_name() {
  local name="$1"
  if is_staging_artifact_name "$name"; then
    return 0
  fi
  case "$name" in
    _temp|_backup|_backups|.Trash|.*)
      return 0
      ;;
  esac
  return 1
}

record_path_blocker() {
  local state="$1"
  local path="$2"
  local scope="$3"
  local detail="$4"
  local safe_name=""
  local destination="$CODE_REPOS"

  safe_name="$(slugify_repo_name "$(basename -- "$path")")"
  if [[ "$scope" == "canonical" ]]; then
    destination="$path"
  fi
  write_plan_row "$state" "unresolved/$safe_name" "$path" "$destination" "" "" "" "blocked" "$scope" "" "0" "$detail"
}

resolve_selector() {
  local selector="$1"
  local candidate=""

  case "$selector" in
    /*|"~"|"~/"*) candidate="$selector" ;;
    *) candidate="$SOURCE_ROOT/$selector" ;;
  esac
  if [[ -d "$candidate" ]]; then
    normalize_path "$candidate"
    return 0
  fi
  return 1
}

append_candidate() {
  local candidate="$1"
  local existing=""
  candidate="$(normalize_path "$candidate")" || return 1
  require_strict_containment "$candidate" "$SOURCE_ROOT" "Selected Stage 2 source" || return 1
  while IFS= read -r existing; do
    [[ "$existing" == "$candidate" ]] && return 0
  done < "$TMP_ROOT/candidates.txt"
  printf '%s\n' "$candidate" >> "$TMP_ROOT/candidates.txt"
}

collect_candidates() {
  local selector=""
  local candidate=""
  local name=""
  local requested_name=""
  local source_scan="$TMP_ROOT/source-folders.txt"

  : > "$TMP_ROOT/candidates.txt"
  if [[ "$SELECT_ALL" -eq 1 ]]; then
    if ! find "$SOURCE_ROOT" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -print 2>/dev/null | LC_ALL=C sort > "$source_scan"; then
      record_path_blocker "blocked-source-scan-failed" "$SOURCE_ROOT" "source" "The Stage 1 root could not be scanned completely, so Stage 2 cannot prove that no staging artifacts were hidden."
    fi
    while IFS= read -r candidate; do
      name="$(basename "$candidate")"
      if is_staging_artifact_name "$name"; then
        record_path_blocker "blocked-staging-artifact" "$candidate" "source" "A Stage 1 staging/transaction artifact was found and must be reconciled explicitly; it was not hidden or treated as a project."
        continue
      fi
      should_skip_folder_name "$name" && continue
      has_project_evidence "$candidate" || continue
      if ! append_candidate "$candidate"; then
        record_path_blocker "blocked-source-outside-root" "$candidate" "source" "The selected folder resolves outside the canonical Stage 1 source root."
      fi
    done < "$source_scan"
  fi

  for selector in "${PROJECT_SELECTORS[@]}"; do
    requested_name="$(basename -- "$selector")"
    if ! candidate="$(resolve_selector "$selector")"; then
      record_path_blocker "blocked-selected-source-missing" "$SOURCE_ROOT/$requested_name" "source" "A specifically selected Stage 2 project was not found; no partial selection will be applied."
      continue
    fi
    name="$(basename -- "$candidate")"
    if ! path_is_strictly_within "$candidate" "$SOURCE_ROOT"; then
      record_path_blocker "blocked-source-outside-root" "$candidate" "source" "The selected folder resolves outside the canonical Stage 1 source root."
      continue
    fi
    if is_staging_artifact_name "$requested_name" || is_staging_artifact_name "$name"; then
      record_path_blocker "blocked-staging-artifact" "$candidate" "source" "A selected Stage 1 staging/transaction artifact must be reconciled explicitly; it was not hidden or treated as a project."
      continue
    fi
    if should_skip_folder_name "$name"; then
      warn "Skipped transaction or temporary folder: $candidate"
      continue
    fi
    if ! has_project_evidence "$candidate"; then
      warn "Skipped folder without project evidence: $candidate"
      continue
    fi
    if ! append_candidate "$candidate"; then
      record_path_blocker "blocked-source-outside-root" "$candidate" "source" "The selected folder resolves outside the canonical Stage 1 source root."
    fi
  done

  if [[ ! -s "$TMP_ROOT/candidates.txt" && ! -s "$PLAN_FILE" ]]; then
    die "No eligible Stage 2 projects were found under $SOURCE_ROOT"
  fi
}

valid_github_host() {
  local host="$1"
  [[ -n "$host" && "$host" != .* && "$host" != *. && "$host" != *..* &&
     "$host" =~ ^[A-Za-z0-9.-]+$ ]]
}

valid_github_principal() {
  local value="$1"
  [[ -n "$value" && "${#value}" -le 39 && "$value" != -* && "$value" != *- &&
     "$value" =~ ^[A-Za-z0-9-]+$ ]]
}

register_github_account_binding() {
  local specification="$1"
  local owner="${specification%%=*}"
  local login="${specification#*=}"
  local existing=""
  local existing_owner=""

  [[ "$specification" == *=* && "$login" != "$specification" && "$login" != *=* ]] || return 1
  valid_github_principal "$owner" && valid_github_principal "$login" || return 1
  for existing in "${GITHUB_ACCOUNT_BINDINGS[@]}"; do
    existing_owner="${existing%%=*}"
    if [[ "$(printf '%s' "$existing_owner" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')" ]]; then
      return 1
    fi
  done
  GITHUB_ACCOUNT_BINDINGS+=("$owner=$login")
}

github_login_for_owner() {
  local requested="$1"
  local binding=""
  local owner=""
  valid_github_principal "$requested" || return 1
  for binding in "${GITHUB_ACCOUNT_BINDINGS[@]}"; do
    owner="${binding%%=*}"
    if [[ "$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$requested" | tr '[:upper:]' '[:lower:]')" ]]; then
      printf '%s' "${binding#*=}"
      return 0
    fi
  done
  return 1
}

github_account_binding_digest() {
  local owner="$1"
  local login="$2"
  valid_github_principal "$owner" && valid_github_principal "$login" || return 1
  printf '%s=%s\n' "$owner" "$login" | shasum -a 256 | awk '{print $1}'
}

ambient_authenticated_login() {
  [[ -n "$GH_BIN" && "$GH_BIN" == /* && -x "$GH_BIN" ]] || return 1
  /usr/bin/env -u GH_TOKEN -u GITHUB_TOKEN GH_HOST="$GITHUB_HOST" \
    "$GH_BIN" api user --jq '.login' 2>/dev/null
}

load_scoped_github_token() {
  local owner="$1"
  local login=""
  local token=""
  SCOPED_GITHUB_TOKEN=""
  SCOPED_GITHUB_LOGIN=""
  login="$(github_login_for_owner "$owner")" || return 1
  token="$(/usr/bin/env -u GH_TOKEN -u GITHUB_TOKEN GH_HOST="$GITHUB_HOST" \
    "$GH_BIN" auth token --hostname "$GITHUB_HOST" --user "$login" 2>/dev/null)" || return 1
  [[ -n "$token" && "$token" != *$'\n'* && "$token" != *$'\r'* ]] || return 1
  SCOPED_GITHUB_TOKEN="$token"
  SCOPED_GITHUB_LOGIN="$login"
}

github_binding_is_cached() {
  local owner="$1"
  local login="$2"
  local digest="$3"
  [[ -n "$GITHUB_BINDINGS_FILE" && -f "$GITHUB_BINDINGS_FILE" ]] || return 1
  awk -F '\t' -v owner="$owner" -v login="$login" -v digest="$digest" \
    '$1 == owner && $2 == login && $3 == digest { found=1 } END { exit(found ? 0 : 1) }' \
    "$GITHUB_BINDINGS_FILE"
}

verify_github_account_binding() {
  local owner="$1"
  local login=""
  local digest=""
  local actual_login=""
  login="$(github_login_for_owner "$owner")" || return 1
  digest="$(github_account_binding_digest "$owner" "$login")" || return 1
  if github_binding_is_cached "$owner" "$login" "$digest"; then
    return 0
  fi
  load_scoped_github_token "$owner" || return 1
  actual_login="$(/usr/bin/env -u GH_TOKEN -u GITHUB_TOKEN \
    GH_TOKEN="$SCOPED_GITHUB_TOKEN" GH_HOST="$GITHUB_HOST" \
    "$GH_BIN" api user --jq '.login' 2>/dev/null)" || {
      SCOPED_GITHUB_TOKEN=""
      SCOPED_GITHUB_LOGIN=""
      return 1
    }
  SCOPED_GITHUB_TOKEN=""
  SCOPED_GITHUB_LOGIN=""
  [[ "$actual_login" == "$login" ]] || return 1
  if [[ -n "$GITHUB_BINDINGS_FILE" ]]; then
    printf '%s\t%s\t%s\n' "$owner" "$login" "$digest" >> "$GITHUB_BINDINGS_FILE" || return 1
  fi
}

bind_current_github_owner() {
  local owner="$1"
  local login=""
  local digest=""
  verify_github_account_binding "$owner" || return 1
  login="$(github_login_for_owner "$owner")" || return 1
  digest="$(github_account_binding_digest "$owner" "$login")" || return 1
  valid_sha256_digest "$digest" || return 1
  CURRENT_GITHUB_OWNER="$owner"
  CURRENT_GITHUB_LOGIN="$login"
  CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST="$digest"
}

owner_scoped_gh() {
  local owner="$1"
  local status=0
  shift
  verify_github_account_binding "$owner" || return 1
  load_scoped_github_token "$owner" || return 1
  if /usr/bin/env -u GH_TOKEN -u GITHUB_TOKEN \
      GH_TOKEN="$SCOPED_GITHUB_TOKEN" GH_HOST="$GITHUB_HOST" \
      "$GH_BIN" "$@"; then
    status=0
  else
    status=$?
  fi
  SCOPED_GITHUB_TOKEN=""
  SCOPED_GITHUB_LOGIN=""
  return "$status"
}

owner_scoped_git() {
  local owner="$1"
  local token=""
  local basic=""
  local status=0
  shift
  verify_github_account_binding "$owner" || return 1
  load_scoped_github_token "$owner" || return 1
  token="$SCOPED_GITHUB_TOKEN"
  basic="$(printf 'x-access-token:%s' "$token" | /usr/bin/base64 | tr -d '\r\n')" || {
    SCOPED_GITHUB_TOKEN=""
    SCOPED_GITHUB_LOGIN=""
    return 1
  }
  if [[ -z "$basic" || "$basic" == *$'\n'* || "$basic" == *$'\r'* ]]; then
    token=""
    basic=""
    SCOPED_GITHUB_TOKEN=""
    SCOPED_GITHUB_LOGIN=""
    return 1
  fi
  if /usr/bin/env -i \
      PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C \
      HOME="$TMP_ROOT/git-home" XDG_CONFIG_HOME="$TMP_ROOT/git-xdg" TMPDIR="$TMP_ROOT" \
      GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      GIT_ATTR_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 \
      GIT_NO_REPLACE_OBJECTS=1 GIT_CONFIG_COUNT=1 \
      GIT_CONFIG_KEY_0="http.https://$GITHUB_HOST/.extraHeader" \
      GIT_CONFIG_VALUE_0="Authorization: Basic $basic" \
      "$GIT_BIN" "$@"; then
    status=0
  else
    status=$?
  fi
  token=""
  basic=""
  SCOPED_GITHUB_TOKEN=""
  SCOPED_GITHUB_LOGIN=""
  return "$status"
}

initialize_github_accounts() {
  local binding=""
  local first_owner=""
  local requested_owner=""

  valid_github_host "$GITHUB_HOST" || return 1
  GH_BIN="$(command -v gh 2>/dev/null || true)"
  [[ -n "$GH_BIN" && "$GH_BIN" == /* && -x "$GH_BIN" ]] || return 1
  ACTIVE_GITHUB_LOGIN="$(ambient_authenticated_login 2>/dev/null || true)"
  [[ -z "$ACTIVE_GITHUB_LOGIN" ]] || valid_github_principal "$ACTIVE_GITHUB_LOGIN" || return 1

  if [[ "${#GITHUB_ACCOUNT_BINDINGS[@]}" -eq 0 ]]; then
    [[ -n "$ACTIVE_GITHUB_LOGIN" ]] || return 1
    requested_owner="${ACCOUNT:-$ACTIVE_GITHUB_LOGIN}"
    [[ "$requested_owner" == "$ACTIVE_GITHUB_LOGIN" ]] || return 1
    register_github_account_binding "$requested_owner=$ACTIVE_GITHUB_LOGIN" || return 1
  elif [[ -n "$ACCOUNT" ]] && ! github_login_for_owner "$ACCOUNT" >/dev/null 2>&1; then
    [[ -n "$ACTIVE_GITHUB_LOGIN" && "$ACCOUNT" == "$ACTIVE_GITHUB_LOGIN" ]] || return 1
    register_github_account_binding "$ACCOUNT=$ACTIVE_GITHUB_LOGIN" || return 1
  fi

  if [[ -n "$GITHUB_BINDINGS_FILE" ]]; then
    : > "$GITHUB_BINDINGS_FILE" || return 1
  fi
  for binding in "${GITHUB_ACCOUNT_BINDINGS[@]}"; do
    requested_owner="${binding%%=*}"
    [[ -n "$first_owner" ]] || first_owner="$requested_owner"
    verify_github_account_binding "$requested_owner" || return 1
  done
  [[ -n "$ACCOUNT" ]] || ACCOUNT="$first_owner"
  [[ -n "$ACCOUNT" ]]
}

load_github_catalog() {
  local binding=""
  local owner=""
  local owner_catalog=""
  : > "$GH_CATALOG"
  if ! initialize_github_accounts; then
    warn "GitHub owner/account bindings could not be authenticated without changing global gh state. Identity checks will be blocked."
    return 1
  fi
  for binding in "${GITHUB_ACCOUNT_BINDINGS[@]}"; do
    owner="${binding%%=*}"
    owner_catalog="$(mktemp "$TMP_ROOT/github-owner-catalog.XXXXXX")" || return 1
    if ! owner_scoped_gh "$owner" repo list "$owner" --limit 1000 \
        --json id,nameWithOwner,name,url,defaultBranchRef,isPrivate,isArchived,pushedAt,updatedAt \
        --jq '.[] | [.id,.nameWithOwner,.name,.url,(.defaultBranchRef.name // ""),(.isPrivate|tostring),(.isArchived|tostring),(.pushedAt // ""),(.updatedAt // "")] | @tsv' \
        > "$owner_catalog" 2>/dev/null; then
      rm -f -- "$owner_catalog"
      warn "GitHub repository identity catalog could not be loaded for bound owner $owner."
      : > "$GH_CATALOG"
      return 1
    fi
    cat "$owner_catalog" >> "$GH_CATALOG" || { rm -f -- "$owner_catalog"; return 1; }
    rm -f -- "$owner_catalog"
  done
  LC_ALL=C sort -u "$GH_CATALOG" -o "$GH_CATALOG" || return 1
}

lookup_catalog_slug() {
  local requested="$1"
  awk -F '\t' -v requested="$(printf '%s' "$requested" | tr '[:upper:]' '[:lower:]')" '
    tolower($2) == requested { print; exit }
  ' "$GH_CATALOG"
}

repo_metadata() {
  local slug="$1"
  local owner="${slug%%/*}"
  local line=""

  valid_repository_slug "$slug" || return 1
  [[ "${slug##*/}" != *.wiki ]] || return 1
  github_login_for_owner "$owner" >/dev/null || return 1
  line="$(lookup_catalog_slug "$slug")"
  if [[ -n "$line" ]]; then
    printf '%s' "$line"
    return 0
  fi
  owner_scoped_gh "$owner" repo view "$slug" \
    --json id,nameWithOwner,name,url,defaultBranchRef,isPrivate,isArchived,pushedAt,updatedAt \
    --jq '[.id,.nameWithOwner,.name,.url,(.defaultBranchRef.name // ""),(.isPrivate|tostring),(.isArchived|tostring),(.pushedAt // ""),(.updatedAt // "")] | @tsv' \
    2>/dev/null
}

is_wiki_slug() {
  local slug="$1"
  valid_repository_slug "$slug" && [[ "${slug##*/}" == *.wiki && "${slug##*/}" != ".wiki" ]]
}

wiki_parent_slug() {
  local slug="$1"
  local owner="${slug%%/*}"
  local repository="${slug#*/}"
  is_wiki_slug "$slug" || return 1
  repository="${repository%.wiki}"
  [[ -n "$repository" ]] || return 1
  printf '%s/%s' "$owner" "$repository"
}

wiki_remote_metadata() {
  local owner="$1"
  local remote="$2"
  local raw=""
  local canonical=""
  local symbolic=""
  local branch=""
  local head_oid=""
  local branch_oid=""
  local digest=""

  [[ "$remote" == "https://$GITHUB_HOST/$owner/"*.wiki.git ]] || return 1
  raw="$(mktemp "$TMP_ROOT/wiki-refs-raw.XXXXXX")" || return 1
  canonical="$(mktemp "$TMP_ROOT/wiki-refs-canonical.XXXXXX")" || { rm -f -- "$raw"; return 1; }
  if ! owner_scoped_git "$owner" ls-remote --symref "$remote" HEAD 'refs/heads/*' 'refs/tags/*' > "$raw" 2>/dev/null; then
    cleanup_verification_files "$raw" "$canonical"
    return 1
  fi
  if ! awk -F '\t' '
    $1 ~ /^ref: refs\/heads\/[A-Za-z0-9._\/-]+$/ && $2 == "HEAD" { print; next }
    $1 !~ /[^0-9a-f]/ && (length($1) == 40 || length($1) == 64) && ($2 == "HEAD" || $2 ~ /^refs\/(heads|tags)\/[A-Za-z0-9._\/-]+(\^\{\})?$/) { print; next }
    { bad=1 }
    END { exit(bad ? 1 : 0) }
  ' "$raw" | LC_ALL=C sort -u > "$canonical"; then
    cleanup_verification_files "$raw" "$canonical"
    return 1
  fi
  symbolic="$(awk -F '\t' '$1 ~ /^ref: refs\/heads\/[A-Za-z0-9._\/-]+$/ && $2 == "HEAD" { sub(/^ref: /, "", $1); print $1; exit }' "$canonical")"
  [[ "$symbolic" == refs/heads/* ]] || { cleanup_verification_files "$raw" "$canonical"; return 1; }
  branch="${symbolic#refs/heads/}"
  head_oid="$(awk -F '\t' '$2 == "HEAD" && $1 ~ /^[0-9a-f]+$/ { print $1; exit }' "$canonical")"
  branch_oid="$(awk -F '\t' -v ref="$symbolic" '$2 == ref && $1 ~ /^[0-9a-f]+$/ { print $1; exit }' "$canonical")"
  valid_git_object_id "$head_oid" && [[ "$head_oid" == "$branch_oid" ]] || {
    cleanup_verification_files "$raw" "$canonical"
    return 1
  }
  digest="$(shasum -a 256 "$canonical" | awk '{print $1}')"
  cleanup_verification_files "$raw" "$canonical"
  valid_sha256_digest "$digest" || return 1
  printf '%s\t%s\t%s' "$branch" "$head_oid" "$digest"
}

repository_identity_metadata() {
  local slug="$1"
  local parent=""
  local metadata=""
  local repository_id=""
  local canonical_parent=""
  local parent_name=""
  local parent_url=""
  local parent_branch=""
  local private=""
  local archived=""
  local pushed=""
  local updated=""
  local canonical_wiki=""
  local exact_remote=""
  local wiki_metadata=""
  local wiki_branch=""
  local wiki_head=""
  local wiki_digest=""

  valid_repository_slug "$slug" || return 1
  if ! is_wiki_slug "$slug"; then
    metadata="$(repo_metadata "$slug")" || return 1
    IFS=$'\t' read -r repository_id canonical_parent parent_name parent_url parent_branch private archived pushed updated <<< "$metadata"
    [[ -n "$repository_id" && -n "$canonical_parent" && "$parent_url" == "https://$GITHUB_HOST/$canonical_parent" ]] || return 1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\trepository\t%s\t%s.git\t-\t-\t-' \
      "$repository_id" "$canonical_parent" "$parent_name" "$parent_url" "$parent_branch" "$private" "$archived" "$pushed" "$updated" \
      "$canonical_parent" "$parent_url"
    return 0
  fi

  parent="$(wiki_parent_slug "$slug")" || return 1
  metadata="$(repo_metadata "$parent")" || return 1
  IFS=$'\t' read -r repository_id canonical_parent parent_name parent_url parent_branch private archived pushed updated <<< "$metadata"
  [[ -n "$repository_id" && -n "$canonical_parent" && "$parent_url" == "https://$GITHUB_HOST/$canonical_parent" ]] || return 1
  canonical_wiki="$canonical_parent.wiki"
  exact_remote="https://$GITHUB_HOST/$canonical_wiki.git"
  wiki_metadata="$(wiki_remote_metadata "${canonical_parent%%/*}" "$exact_remote")" || return 1
  IFS=$'\t' read -r wiki_branch wiki_head wiki_digest <<< "$wiki_metadata"
  [[ -n "$wiki_branch" ]] && valid_git_object_id "$wiki_head" && valid_sha256_digest "$wiki_digest" || return 1
  printf '%s\t%s\t%s.wiki\t%s\t%s\t%s\t%s\t%s\t%s\twiki\t%s\t%s\t%s\t%s\t%s' \
    "$repository_id" "$canonical_wiki" "$parent_name" "$exact_remote" "$wiki_branch" "$private" "$archived" "$pushed" "$updated" \
    "$canonical_parent" "$exact_remote" "$wiki_digest" "$wiki_branch" "$wiki_head"
}

build_destination_index() {
  local owner=""
  local canonical_owner=""
  local owner_name=""
  local candidate=""
  local canonical_candidate=""
  local name=""
  local remote=""
  local slug=""
  local metadata=""
  local repo_id=""
  local canonical=""
  local role=""
  local owner_scan="$TMP_ROOT/canonical-owners.txt"
  local destination_scan="$TMP_ROOT/canonical-folders.txt"

  : > "$DESTINATION_INDEX"
  if ! find "$CODE_REPOS" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -print 2>/dev/null | LC_ALL=C sort > "$owner_scan"; then
    record_path_blocker "blocked-canonical-scan-failed" "$CODE_REPOS" "canonical" "The canonical owner root could not be scanned completely, so auxiliary owner components may be hidden."
  fi
  while IFS= read -r owner; do
    owner_name="$(basename -- "$owner")"
    if is_staging_artifact_name "$owner_name"; then
      record_path_blocker "blocked-staging-artifact" "$owner" "canonical" "A staging/transaction artifact is being used as a canonical owner component; it must be reconciled before Stage 2 can mutate anything."
      continue
    fi
    if should_skip_folder_name "$owner_name"; then
      record_path_blocker "blocked-canonical-auxiliary-component" "$owner" "canonical" "An auxiliary folder name is being used as a canonical owner component; Stage 2 rejects it instead of hiding it."
      continue
    fi
    if [[ ! -d "$owner" ]]; then
      record_path_blocker "blocked-canonical-path-invalid" "$owner" "canonical" "A canonical owner component is not a directory."
      continue
    fi
    canonical_owner="$(canonical_path "$owner")" || {
      record_path_blocker "blocked-canonical-path-invalid" "$owner" "canonical" "A canonical owner path could not be resolved safely."
      continue
    }
    if ! path_is_strictly_within "$canonical_owner" "$CODE_REPOS"; then
      record_path_blocker "blocked-canonical-path-escape" "$owner" "canonical" "A canonical owner path resolves outside the managed Code/Repos root."
    fi
  done < "$owner_scan"

  if ! find "$CODE_REPOS" -mindepth 2 -maxdepth 2 \( -type d -o -type l \) -print 2>/dev/null | LC_ALL=C sort > "$destination_scan"; then
    record_path_blocker "blocked-canonical-scan-failed" "$CODE_REPOS" "canonical" "The canonical repository root could not be scanned completely, so duplicate or staging destinations may be hidden."
  fi
  while IFS= read -r candidate; do
    owner_name="$(basename -- "$(dirname -- "$candidate")")"
    name="$(basename -- "$candidate")"
    if should_skip_folder_name "$owner_name"; then
      continue
    fi
    if is_staging_artifact_name "$name"; then
      record_path_blocker "blocked-staging-artifact" "$candidate" "canonical" "A staging/transaction artifact is being used as a canonical repository component; it must be reconciled before Stage 2 can mutate anything."
      continue
    fi
    if should_skip_folder_name "$name"; then
      record_path_blocker "blocked-canonical-auxiliary-component" "$candidate" "canonical" "An auxiliary folder name is being used as a canonical repository component; Stage 2 rejects it instead of hiding it."
      continue
    fi
    if [[ ! -d "$candidate" ]]; then
      record_path_blocker "blocked-canonical-path-invalid" "$candidate" "canonical" "A canonical repository component is not a directory."
      continue
    fi
    canonical_candidate="$(canonical_path "$candidate")" || {
      record_path_blocker "blocked-canonical-path-invalid" "$candidate" "canonical" "A canonical repository path could not be resolved safely."
      continue
    }
    if ! path_is_strictly_within "$canonical_candidate" "$CODE_REPOS"; then
      record_path_blocker "blocked-canonical-path-escape" "$candidate" "canonical" "A canonical repository path resolves outside the managed Code/Repos root."
      continue
    fi
    remote="$(isolated_git -C "$canonical_candidate" config --no-includes --local --get remote.origin.url 2>/dev/null || true)"
    slug="$(normalize_remote_slug "$remote" 2>/dev/null || true)"
    if [[ -z "$slug" ]] || ! valid_repository_slug "$slug"; then
      record_path_blocker "blocked-canonical-identity-unresolved" "$canonical_candidate" "canonical" "A canonical repository folder has no safe owner/name origin identity; Stage 2 will not ignore it or create a competing folder."
      continue
    fi
    metadata="$(repository_identity_metadata "$slug" 2>/dev/null || true)"
    repo_id="$(printf '%s' "$metadata" | awk -F '\t' '{print $1}')"
    canonical="$(printf '%s' "$metadata" | awk -F '\t' '{print $2}')"
    role="$(printf '%s' "$metadata" | awk -F '\t' '{print $10}')"
    [[ -n "$canonical" ]] || canonical="$slug"
    [[ "$role" == "repository" || "$role" == "wiki" ]] || role="unresolved"
    printf '%s:%s\t%s\t%s\n' "$role" "$repo_id" "$canonical" "$canonical_candidate" >> "$DESTINATION_INDEX"
  done < "$destination_scan"
}

hinted_remote_slug() {
  local source="$1"
  local file=""
  local match=""
  local slug=""
  local hints_file=""
  local sorted_file=""
  local hint_count=0

  hints_file="$(mktemp "$TMP_ROOT/owner-name-hints.XXXXXX")" || return 1
  sorted_file="$(mktemp "$TMP_ROOT/owner-name-hints-sorted.XXXXXX")" || {
    rm -f -- "$hints_file"
    return 1
  }
  for file in Transfer_Note.md Transfer_Note.MD TRANSFER_NOTE.md TRANSFER_NOTE.MD Prompt_Inject.md Prompt_Inject.MD PROMPT_INJECT.md PROMPT_INJECT.MD; do
    [[ -f "$source/$file" ]] || continue
    while IFS= read -r match; do
      [[ -n "$match" ]] || continue
      if slug="$(normalize_remote_slug "$match" 2>/dev/null)"; then
        printf '%s\n' "$slug" >> "$hints_file"
      fi
    done < <(grep -Eo 'https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?' "$source/$file" 2>/dev/null || true)
  done
  LC_ALL=C sort -fu "$hints_file" > "$sorted_file" || {
    cleanup_verification_files "$hints_file" "$sorted_file"
    return 1
  }
  hint_count="$(awk 'NF { count++ } END { print count+0 }' "$sorted_file")"
  case "$hint_count" in
    1)
      slug="$(awk 'NF { print; exit }' "$sorted_file")"
      cleanup_verification_files "$hints_file" "$sorted_file"
      printf '%s' "$slug"
      return 0
      ;;
    0)
      cleanup_verification_files "$hints_file" "$sorted_file"
      return 1
      ;;
    *)
      cleanup_verification_files "$hints_file" "$sorted_file"
      return 2
      ;;
  esac
}

infer_repository() {
  local source="$1"
  local remote=""
  local hinted=""
  local hinted_status=0
  local metadata=""
  local has_owner_evidence=0

  INFERRED_SLUG=""
  INFERENCE="none"
  REPO_EXISTS=0
  REPO_ID=""
  REPO_CANONICAL=""
  REPO_URL=""
  REPO_DEFAULT_BRANCH=""
  REPO_PRIVATE=""
  REPO_ARCHIVED=""
  REPO_ROLE=""
  REPO_PARENT_REPOSITORY=""
  REPO_EXACT_GIT_REMOTE=""
  REPO_WIKI_REF_DIGEST=""
  REPO_WIKI_DEFAULT_BRANCH=""
  REPO_WIKI_HEAD_OID=""

  remote="$(isolated_git -C "$source" config --no-includes --local --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "$remote" ]]; then
    INFERRED_SLUG="$(normalize_remote_slug "$remote" 2>/dev/null || true)"
    if [[ -n "$INFERRED_SLUG" ]]; then
      INFERENCE="origin owner/name"
      has_owner_evidence=1
    fi
  fi
  if [[ -z "$INFERRED_SLUG" ]]; then
    if hinted="$(hinted_remote_slug "$source" 2>/dev/null)"; then
      INFERRED_SLUG="$hinted"
      INFERENCE="project metadata owner/name"
      has_owner_evidence=1
    else
      hinted_status=$?
      if [[ "$hinted_status" -eq 2 ]]; then
        INFERENCE="conflicting owner/name project metadata"
        return 2
      fi
    fi
  fi
  if [[ -z "$INFERRED_SLUG" ]]; then
    INFERENCE="owner/name evidence missing"
    return 3
  fi

  if ! github_login_for_owner "${INFERRED_SLUG%%/*}" >/dev/null 2>&1; then
    INFERENCE="GitHub owner has no authenticated account binding"
    return 6
  fi
  metadata="$(repository_identity_metadata "$INFERRED_SLUG" 2>/dev/null || true)"
  if [[ -n "$metadata" ]]; then
    IFS=$'\t' read -r REPO_ID REPO_CANONICAL _ REPO_URL REPO_DEFAULT_BRANCH REPO_PRIVATE REPO_ARCHIVED _ _ \
      REPO_ROLE REPO_PARENT_REPOSITORY REPO_EXACT_GIT_REMOTE REPO_WIKI_REF_DIGEST \
      REPO_WIKI_DEFAULT_BRANCH REPO_WIKI_HEAD_OID <<< "$metadata"
    if [[ -z "$REPO_ID" ]] || ! valid_repository_slug "$REPO_CANONICAL"; then
      INFERENCE="GitHub identity metadata incomplete"
      return 4
    fi
    INFERRED_SLUG="$REPO_CANONICAL"
    REPO_EXISTS=1
    if [[ "$has_owner_evidence" -ne 1 ]]; then
      INFERENCE="basename-only existing repository match rejected"
      return 3
    fi
  elif is_wiki_slug "$INFERRED_SLUG"; then
    INFERENCE="GitHub wiki parent or exact child remote could not be verified"
    return 5
  fi
  return 0
}

git_snapshot() {
  local path="$1"
  local branch=""
  local head=""
  local upstream=""
  local remote=""
  local remote_slug=""
  local staged=0
  local unstaged=0
  local untracked=0
  local line=""
  local x=""
  local y=""
  local status_output=""

  if [[ ! -d "$path/.git" && ! -f "$path/.git" ]]; then
    printf '0||||0|0|0||'
    return 0
  fi
  if ! isolated_git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
    printf '%s' '-1||||0|0|0||'
    return 0
  fi
  branch="$(isolated_git -C "$path" branch --show-current 2>/dev/null || true)"
  head="$(isolated_git -C "$path" rev-parse HEAD 2>/dev/null || true)"
  upstream="$(isolated_git -C "$path" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
  remote="$(isolated_git -C "$path" config --no-includes --local --get remote.origin.url 2>/dev/null || true)"
  remote_slug="$(normalize_remote_slug "$remote" 2>/dev/null || true)"
  if ! status_output="$(isolated_git -C "$path" status --porcelain=v1 --untracked-files=normal 2>/dev/null)"; then
    printf '%s' '-1||||0|0|0||'
    return 0
  fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    case "$line" in
      "?? Transfer_Note.MD"|"?? Prompt_Inject.MD") continue ;;
    esac
    x="${line:0:1}"
    y="${line:1:1}"
    if [[ "$x$y" == "??" ]]; then
      untracked=$((untracked + 1))
      continue
    fi
    [[ "$x" != " " ]] && staged=$((staged + 1))
    [[ "$y" != " " ]] && unstaged=$((unstaged + 1))
  done <<< "$status_output"
  printf '1|%s|%s|%s|%s|%s|%s|%s|%s' "$branch" "$head" "$upstream" "$staged" "$unstaged" "$untracked" "$remote_slug" "$remote"
}

commit_relation() {
  local source_path="$1"
  local destination_path="$2"
  local source_head="$3"
  local destination_head="$4"
  local slug="$5"
  local relation=""
  local owner="${slug%%/*}"

  [[ -n "$source_head" && -n "$destination_head" ]] || { printf 'unknown'; return; }
  [[ "$source_head" == "$destination_head" ]] && { printf 'identical'; return; }

  if isolated_git -C "$source_path" cat-file -e "$destination_head^{commit}" 2>/dev/null; then
    if isolated_git -C "$source_path" merge-base --is-ancestor "$destination_head" "$source_head" 2>/dev/null; then
      printf 'source-ahead'
      return
    fi
    if isolated_git -C "$source_path" merge-base --is-ancestor "$source_head" "$destination_head" 2>/dev/null; then
      printf 'destination-ahead'
      return
    fi
  fi
  if isolated_git -C "$destination_path" cat-file -e "$source_head^{commit}" 2>/dev/null; then
    if isolated_git -C "$destination_path" merge-base --is-ancestor "$destination_head" "$source_head" 2>/dev/null; then
      printf 'source-ahead'
      return
    fi
    if isolated_git -C "$destination_path" merge-base --is-ancestor "$source_head" "$destination_head" 2>/dev/null; then
      printf 'destination-ahead'
      return
    fi
  fi
  if is_wiki_slug "$slug"; then
    printf 'unknown'
    return
  fi
  relation="$(owner_scoped_gh "$owner" api "repos/$slug/compare/$destination_head...$source_head" --jq '.status' 2>/dev/null || true)"
  case "$relation" in
    ahead) printf 'source-ahead' ;;
    behind) printf 'destination-ahead' ;;
    identical) printf 'identical' ;;
    diverged) printf 'diverged' ;;
    *) printf 'unknown' ;;
  esac
}

remote_position() {
  local path="$1"
  local local_head="$2"
  local remote_head="$3"

  [[ -n "$local_head" ]] || { printf 'no-head'; return; }
  [[ -n "$remote_head" ]] || { printf 'remote-empty'; return; }
  [[ "$local_head" == "$remote_head" ]] && { printf 'synced'; return; }
  if isolated_git -C "$path" cat-file -e "$remote_head^{commit}" 2>/dev/null; then
    if isolated_git -C "$path" merge-base --is-ancestor "$local_head" "$remote_head" 2>/dev/null; then
      printf 'behind'
      return
    fi
    if isolated_git -C "$path" merge-base --is-ancestor "$remote_head" "$local_head" 2>/dev/null; then
      printf 'ahead'
      return
    fi
    printf 'diverged'
    return
  fi
  printf 'remote-changed-unfetched'
}

find_destination_by_identity() {
  local canonical_slug="$1"
  local repo_id="$2"
  local role="${3:-repository}"
  local identity="$role:$repo_id"
  local expected="$CODE_REPOS/$canonical_slug"
  local candidate=""
  local matches=()

  DESTINATION_PATH_MISMATCH=0
  DESTINATION_EXPECTED_PATH="$expected"
  DESTINATION_MISMATCH_PATH=""
  if [[ -e "$expected" || -L "$expected" ]]; then
    matches+=("$expected")
  fi
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    [[ "$candidate" == "$expected" ]] && continue
    matches+=("$candidate")
    DESTINATION_PATH_MISMATCH=1
    [[ -n "$DESTINATION_MISMATCH_PATH" ]] || DESTINATION_MISMATCH_PATH="$candidate"
  done < <(awk -F '\t' -v id="$identity" -v slug="$(printf '%s' "$canonical_slug" | tr '[:upper:]' '[:lower:]')" '
    (id != "repository:" && id != "wiki:" && $1 == id) || tolower($2) == slug { print $3 }
  ' "$DESTINATION_INDEX")

  DESTINATION_MATCH_COUNT="${#matches[@]}"
  DESTINATION_PATH="${matches[0]:-$expected}"
}

sanitize_detail() {
  printf '%s' "$1" | tr '\t\r\n' '   '
}

write_plan_row() {
  local state="$1"
  local slug="$2"
  local source="$3"
  local destination="$4"
  local source_head="$5"
  local destination_head="$6"
  local remote_head="$7"
  local source_status="$8"
  local destination_status="$9"
  local default_branch="${10}"
  local repo_exists="${11}"
  local detail="${12}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$state" "$slug" "$source" "$destination" "$source_head" "$destination_head" "$remote_head" \
    "$source_status" "$destination_status" "$default_branch" "$repo_exists" "$(sanitize_detail "$detail")" >> "$PLAN_FILE"
  printf 'PLAN | %-27s | %-42s | %s\n' "$state" "$slug" "$(basename "$source")"
}

plan_project() {
  local source="$1"
  local state=""
  local detail=""
  local remote_head=""
  local relation=""
  local source_remote_position=""
  local destination_remote_position=""
  local source_status=""
  local destination_status="missing"
  local source_git source_branch source_head source_upstream source_staged source_unstaged source_untracked source_remote_slug source_remote_url
  local destination_git=0 destination_branch="" destination_head="" destination_upstream="" destination_staged=0 destination_unstaged=0 destination_untracked=0 destination_remote_slug="" destination_remote_url=""
  local infer_status=0
  local prospective_git_ref_namespace=""

  if [[ "$GITHUB_READY" -ne 1 ]]; then
    local unavailable_slug=""
    local unavailable_remote=""
    unavailable_remote="$(isolated_git -C "$source" config --no-includes --local --get remote.origin.url 2>/dev/null || true)"
    unavailable_slug="$(normalize_remote_slug "$unavailable_remote" 2>/dev/null || true)"
    if ! valid_repository_slug "$unavailable_slug"; then
      unavailable_slug="unresolved/$(slugify_repo_name "$(basename -- "$source")")"
    fi
    write_plan_row "blocked-github-unavailable" "$unavailable_slug" "$source" "$CODE_REPOS" "" "" "" "unknown" "blocked" "" "0" "GitHub identity enumeration was unavailable, so Stage 2 cannot prove repository ownership or one-folder uniqueness."
    return
  fi

  infer_repository "$source" || infer_status=$?
  case "$infer_status" in
    2)
      write_plan_row "blocked-conflicting-owner-identity" "unresolved/$(slugify_repo_name "$(basename "$source")")" "$source" "$CODE_REPOS" "" "" "" "unknown" "unknown" "" "0" "Dedicated transfer metadata contains more than one GitHub owner/name identity. Cross-owner selection is blocked."
      return
      ;;
    3)
      write_plan_row "blocked-owner-identity-unresolved" "unresolved/$(slugify_repo_name "$(basename "$source")")" "$source" "$CODE_REPOS" "" "" "" "unknown" "unknown" "" "0" "A repository cannot be selected or created from a basename alone. Provide an explicit owner/name origin or dedicated transfer-metadata URL; cross-owner merging is blocked."
      return
      ;;
    4)
      write_plan_row "blocked-github-identity-incomplete" "unresolved/$(slugify_repo_name "$(basename "$source")")" "$source" "$CODE_REPOS" "" "" "" "unknown" "unknown" "" "0" "GitHub did not return a complete repository ID and cased owner/name identity."
      return
      ;;
    5)
      write_plan_row "blocked-wiki-unavailable" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "" "" "" "unknown" "blocked" "" "0" "The parent repository identity or exact authenticated .wiki.git refs could not be verified. A wiki REST 404 is never treated as a missing normal repository."
      return
      ;;
    6)
      write_plan_row "blocked-github-owner-unbound" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "" "" "" "unknown" "blocked" "" "0" "The repository owner has no verified --github-account OWNER=LOGIN binding."
      return
      ;;
  esac
  if ! valid_repository_slug "$INFERRED_SLUG"; then
    write_plan_row "blocked-invalid-repository-identity" "unresolved/$(slugify_repo_name "$(basename "$source")")" "$source" "$CODE_REPOS" "" "" "" "unknown" "blocked" "" "$REPO_EXISTS" "The inferred repository identity is not a safe canonical owner/name slug."
    return
  fi

  if is_reserved_project "$source" "$INFERRED_SLUG"; then
    write_plan_row "blocked-active-project" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "" "" "" "excluded" "excluded" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The active CSA-iEM project is excluded from Stage 2."
    return
  fi
  if [[ -d "$source/.git" || -f "$source/.git" || -L "$source/.git" ]]; then
    if ! prospective_git_ref_namespace="$(git_ref_namespace_for_slug "$INFERRED_SLUG")"; then
      write_plan_row "blocked-git-ref-namespace" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "" "" "" "unreadable" "blocked" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The verified owner/name cannot be encoded as a safe transaction Git recovery namespace."
      return
    fi
    if ! git_admin_state_is_self_contained "$source" "0"; then
      write_plan_row "blocked-source-git-dependency" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "" "" "" "unreadable" "blocked" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "$GIT_SAFETY_ERROR"
      return
    fi
  fi
  IFS='|' read -r source_git source_branch source_head source_upstream source_staged source_unstaged source_untracked source_remote_slug source_remote_url <<< "$(git_snapshot "$source")"
  source_status="staged:$source_staged unstaged:$source_unstaged untracked:$source_untracked"
  if [[ "$source_git" -lt 0 ]]; then
    write_plan_row "blocked-source-git-unreadable" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "$source_head" "" "" "unreadable" "unknown" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The source contains Git metadata, but its worktree or status could not be read reliably."
    return
  fi
  if [[ "$source_git" -eq 1 ]]; then
    if ! git_index_and_operation_state_is_safe "$source"; then
      write_plan_row "blocked-source-git-state" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "$source_head" "" "" "$source_status" "blocked" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "$GIT_SAFETY_ERROR"
      return
    fi
  fi
  if [[ -n "$source_remote_slug" && "$source_remote_slug" != "$INFERRED_SLUG" ]]; then
    write_plan_row "blocked-source-remote-casing" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "$source_head" "" "" "$source_status" "blocked" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "Source origin owner/name casing does not equal the authenticated canonical GitHub identity."
    return
  fi
  if [[ "$REPO_EXISTS" -ne 1 && "$CREATE_MISSING_REPOS" -ne 1 ]]; then
    write_plan_row "needs-github-repository" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "$source_head" "" "" "$source_status" "missing" "main" "0" "No unique GitHub repository was verified. Enable explicit private repository creation or resolve identity manually."
    return
  fi
  if [[ "$REPO_EXISTS" -eq 1 && "$REPO_ARCHIVED" == "true" ]]; then
    write_plan_row "blocked-archived-repository" "$INFERRED_SLUG" "$source" "$CODE_REPOS/$INFERRED_SLUG" "$source_head" "" "" "$source_status" "unknown" "$REPO_DEFAULT_BRANCH" "1" "GitHub reports that this repository is archived."
    return
  fi

  [[ -n "$REPO_DEFAULT_BRANCH" ]] || REPO_DEFAULT_BRANCH="main"
  if [[ "$REPO_ROLE" == "wiki" ]]; then
    remote_head="$REPO_WIKI_HEAD_OID"
  else
    remote_head="$(owner_scoped_gh "${INFERRED_SLUG%%/*}" api "repos/$INFERRED_SLUG/commits/$REPO_DEFAULT_BRANCH" --jq '.sha' 2>/dev/null || true)"
  fi
  find_destination_by_identity "$INFERRED_SLUG" "$REPO_ID" "${REPO_ROLE:-repository}"
  if [[ "$DESTINATION_PATH_MISMATCH" -eq 1 ]]; then
    write_plan_row "blocked-canonical-owner-repository-mismatch" "$INFERRED_SLUG" "$source" "$DESTINATION_MISMATCH_PATH" "$source_head" "" "$remote_head" "$source_status" "misplaced" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The verified GitHub identity requires $DESTINATION_EXPECTED_PATH, but the same identity is indexed under $DESTINATION_MISMATCH_PATH. Stage 2 will not merge across owner/name folders."
    return
  fi
  if ! path_is_strictly_within "$DESTINATION_PATH" "$CODE_REPOS"; then
    write_plan_row "blocked-canonical-path-escape" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "" "$remote_head" "$source_status" "blocked" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The resolved canonical destination escapes the managed Code/Repos root."
    return
  fi
  if [[ "$DESTINATION_MATCH_COUNT" -gt 1 ]]; then
    write_plan_row "blocked-duplicate-destinations" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "" "$remote_head" "$source_status" "duplicate" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "Multiple canonical folders have the same GitHub identity. No destination was changed."
    return
  fi

  if [[ ! -e "$DESTINATION_PATH" ]]; then
    source_remote_position="$(remote_position "$source" "$source_head" "$remote_head")"
    if [[ "$REPO_EXISTS" -eq 1 ]]; then
      state="ready-new-canonical"
      detail="Identity: $INFERENCE; source vs GitHub: $source_remote_position. The complete project will be staged and promoted without changing Stage 1."
    else
      state="ready-new-private-repo"
      detail="A $REPO_VISIBILITY empty GitHub repository will be created, then the complete local project will be staged and attached without uploading files."
    fi
    write_plan_row "$state" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "" "$remote_head" "$source_status" "missing" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "$detail"
    return
  fi

  if [[ -d "$DESTINATION_PATH/.git" || -f "$DESTINATION_PATH/.git" || -L "$DESTINATION_PATH/.git" ]] &&
     ! git_admin_state_is_self_contained "$DESTINATION_PATH" "0"; then
    write_plan_row "blocked-destination-git-dependency" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "$GIT_SAFETY_ERROR"
    return
  fi
  IFS='|' read -r destination_git destination_branch destination_head destination_upstream destination_staged destination_unstaged destination_untracked destination_remote_slug destination_remote_url <<< "$(git_snapshot "$DESTINATION_PATH")"
  destination_status="staged:$destination_staged unstaged:$destination_unstaged untracked:$destination_untracked"
  if [[ "$destination_git" -ne 1 ]]; then
    write_plan_row "blocked-destination-not-git" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The canonical destination exists but is not a Git worktree."
    return
  fi
  if ! git_index_and_operation_state_is_safe "$DESTINATION_PATH"; then
    write_plan_row "blocked-destination-git-state" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "$GIT_SAFETY_ERROR"
    return
  fi
  if [[ -n "$source_remote_slug" ]]; then
    if [[ -z "$destination_remote_slug" || "$source_remote_slug" != "$destination_remote_slug" ]]; then
      write_plan_row "blocked-remote-identity-conflict" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "Source and canonical origin identities must both be present and equal before receipt-linked Git cleanup can be verified."
      return
    fi
  fi
  if [[ -n "$destination_remote_slug" ]]; then
    local destination_metadata=""
    local destination_repo_id=""
    destination_metadata="$(repository_identity_metadata "$destination_remote_slug" 2>/dev/null || true)"
    destination_repo_id="$(printf '%s' "$destination_metadata" | awk -F '\t' '{print $1}')"
    if [[ -n "$REPO_ID" && -n "$destination_repo_id" && "$REPO_ID" != "$destination_repo_id" ]]; then
      write_plan_row "blocked-identity-conflict" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "The destination belongs to a different GitHub repository ID."
      return
    fi
  fi
  if [[ "$destination_staged" -gt 0 || "$destination_unstaged" -gt 0 || "$destination_untracked" -gt 0 ]]; then
    write_plan_row "blocked-destination-dirty" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "Canonical files are staged, modified, or untracked. No overwrite is allowed."
    return
  fi
  if [[ "$source_git" -ne 1 || -z "$source_head" || -z "$destination_head" ]]; then
    write_plan_row "blocked-history-unavailable" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "Both existing copies need readable Git history before an automatic merge."
    return
  fi

  relation="$(commit_relation "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$INFERRED_SLUG")"
  source_remote_position="$(remote_position "$source" "$source_head" "$remote_head")"
  destination_remote_position="$(remote_position "$DESTINATION_PATH" "$destination_head" "$remote_head")"
  case "$relation" in
    identical)
      state="ready-additive-heal"
      detail="Git heads match. Only missing non-.git paths may be added; existing canonical files are never replaced. Any unstaged or untracked source content must pass the final full-checksum representation proof. Source/GitHub: $source_remote_position; destination/GitHub: $destination_remote_position."
      ;;
    source-ahead)
      state="ready-fast-forward"
      detail="The Stage 1 committed HEAD is a descendant of canonical. Git will fast-forward from that commit, then add only missing non-.git paths; unstaged and untracked content remains subject to full-checksum verification."
      ;;
    destination-ahead)
      state="ready-destination-newer"
      detail="Canonical Git history is newer. Canonical refs are never downgraded; source refs are preserved under the transaction recovery namespace, and only missing non-.git paths may be added subject to full-checksum verification."
      ;;
    diverged)
      state="blocked-diverged-history"
      detail="The clean worktrees have diverged commit history. Manual merge or rebase is required."
      ;;
    *)
      state="blocked-unverified-history"
      detail="GitHub and local object databases could not prove a safe ancestry relationship."
      ;;
  esac
  write_plan_row "$state" "$INFERRED_SLUG" "$source" "$DESTINATION_PATH" "$source_head" "$destination_head" "$remote_head" "$source_status" "$destination_status" "$REPO_DEFAULT_BRANCH" "$REPO_EXISTS" "$detail"
}

finalize_plan_safety() {
  local rewritten="$TMP_ROOT/plan-final.tsv"

  awk -F '\t' -v OFS='\t' -v code_root="$CODE_REPOS" '
    FNR == NR {
      if ($2 !~ /^unresolved\// && $4 != "" && $4 != code_root) {
        destination_count[$4]++
      }
      next
    }
    {
      if ($1 ~ /^ready-/ && destination_count[$4] > 1) {
        $1 = "blocked-multiple-sources-one-repository"
        $12 = "Multiple Stage 1 folders resolve to this one canonical repository. Stage 2 will not pick a winner or mutate any copy; reconcile the sources explicitly first."
      }
      print
    }
  ' "$PLAN_FILE" "$PLAN_FILE" > "$rewritten"
  mv -- "$rewritten" "$PLAN_FILE"
}

copy_complete_project() {
  local source="$1"
  local destination="$2"

  require_strict_containment "$destination" "$IMPORT_STAGE" "Stage 2 transaction copy target" || return 1
  rm -rf -- "$destination"
  mkdir -p -- "$destination"
  if [[ "$(uname -s)" == "Darwin" ]] && cp -cR "$source/." "$destination/" 2>/dev/null; then
    info "Used APFS clone-copy acceleration for $(basename "$source")."
    return 0
  fi
  rm -rf -- "$destination"
  mkdir -p -- "$destination"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    COPYFILE_DISABLE=0 /usr/bin/rsync -aE "$source/" "$destination/"
  else
    rsync -a "$source/" "$destination/"
  fi
}

fast_manifest() {
  local root="$1"
  local output="$2"
  local path=""
  local relative=""
  local kind=""
  local size=""
  local target=""

  : > "$output"
  while IFS= read -r -d '' path; do
    relative="${path#"$root"/}"
    [[ "$path" == "$root" ]] && relative="."
    if [[ -L "$path" ]]; then
      kind="l"
      size="0"
      target="$(readlink "$path" 2>/dev/null || true)"
    elif [[ -d "$path" ]]; then
      kind="d"
      size="0"
      target=""
    else
      kind="f"
      if [[ "$(uname -s)" == "Darwin" ]]; then
        size="$(stat -f '%z' "$path" 2>/dev/null || printf '0')"
      else
        size="$(stat -c '%s' "$path" 2>/dev/null || printf '0')"
      fi
      target=""
    fi
    printf '%s\t%s\t%s\t%s\n' "$relative" "$kind" "$size" "$target" >> "$output"
  done < <(find -H "$root" -print0 2>/dev/null)
  LC_ALL=C sort -o "$output" "$output"
}

verify_complete_project() {
  local source="$1"
  local destination="$2"
  local source_manifest="$TMP_ROOT/source-manifest.tsv"
  local destination_manifest="$TMP_ROOT/destination-manifest.tsv"
  local source_head=""
  local destination_head=""

  fast_manifest "$source" "$source_manifest"
  fast_manifest "$destination" "$destination_manifest"
  if ! cmp -s "$source_manifest" "$destination_manifest"; then
    warn "Fast path/type/size/symlink verification failed for $(basename "$source")."
    diff -u "$source_manifest" "$destination_manifest" | sed -n '1,80p' >&2 || true
    return 1
  fi
  if [[ -d "$source/.git" || -f "$source/.git" ]]; then
    source_head="$(isolated_git -C "$source" rev-parse HEAD 2>/dev/null || true)"
    destination_head="$(isolated_git -C "$destination" rev-parse HEAD 2>/dev/null || true)"
    [[ "$source_head" == "$destination_head" ]] || return 1
  fi
}

create_missing_repository() {
  local slug="$1"
  local owner="${slug%%/*}"
  local visibility_flag="--private"
  local metadata=""
  local created_id=""
  local created_slug=""
  is_wiki_slug "$slug" && {
    warn "GitHub wiki children are Git remotes of a parent repository and are never REST-created: $slug"
    return 1
  }
  github_login_for_owner "$owner" >/dev/null || return 1
  [[ "$REPO_VISIBILITY" == "public" ]] && visibility_flag="--public"
  info "Creating $REPO_VISIBILITY empty GitHub repository $slug (no project files are uploaded)."
  owner_scoped_gh "$owner" repo create "$slug" "$visibility_flag" >/dev/null || return 1
  metadata="$(repo_metadata "$slug" 2>/dev/null || true)"
  created_id="$(printf '%s' "$metadata" | awk -F '\t' '{print $1}')"
  created_slug="$(printf '%s' "$metadata" | awk -F '\t' '{print $2}')"
  [[ -n "$created_id" && "$created_slug" == "$slug" ]] || {
    warn "GitHub created the empty repository, but its verified cased owner/name did not equal the planned identity: planned $slug, returned ${created_slug:-unavailable}. No project files were promoted."
    return 1
  }
}

attach_origin_if_needed() {
  local path="$1"
  local slug="$2"
  local remote_url="https://$GITHUB_HOST/$slug.git"
  local local_origin=""

  if [[ ! -d "$path/.git" && ! -f "$path/.git" ]]; then
    isolated_git -C "$path" init -b main >/dev/null
  fi
  local_origin="$(isolated_git -C "$path" config --no-includes --local --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "$local_origin" ]]; then
    return 0
  fi
  isolated_git -C "$path" config --local remote.origin.url "$remote_url" || return 1
  if ! isolated_git -C "$path" config --local --get-all remote.origin.fetch >/dev/null 2>&1; then
    isolated_git -C "$path" config --local --add remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' || return 1
  fi
}

additive_heal() {
  local source="$1"
  local destination="$2"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    COPYFILE_DISABLE=0 /usr/bin/rsync -aE --ignore-existing --exclude='.git/' "$source/" "$destination/"
  else
    rsync -a --ignore-existing --exclude='.git/' "$source/" "$destination/"
  fi
}

safe_remote_fast_forward() {
  local destination="$1"
  local default_branch="$2"
  local remote_head="$3"
  local current_head=""
  local remote_slug=""
  local owner=""

  [[ -n "$remote_head" ]] || return 0
  current_head="$(isolated_git -C "$destination" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$current_head" && "$current_head" != "$remote_head" ]] || return 0
  remote_slug="$(normalize_remote_slug "$(isolated_git -C "$destination" config --no-includes --local --get remote.origin.url 2>/dev/null || true)" 2>/dev/null || true)"
  valid_repository_slug "$remote_slug" || return 1
  owner="${remote_slug%%/*}"
  owner_scoped_git "$owner" -c core.hooksPath=/dev/null -C "$destination" fetch origin "$default_branch" --prune >/dev/null 2>&1 || return 1
  if isolated_git -C "$destination" merge-base --is-ancestor HEAD "origin/$default_branch" 2>/dev/null; then
    "$GIT_BIN" -c core.hooksPath=/dev/null -C "$destination" merge --ff-only --no-verify "origin/$default_branch" >/dev/null
  fi
}

prepare_runtime_mirror() {
  local code_path="$1"
  local slug="$2"
  local runtime_path="$RUNTIME_REPOS/$slug"
  local runtime_stage="$IMPORT_STAGE/runtime/$slug"

  if [[ ! -e "$runtime_path" ]]; then
    require_strict_containment "$runtime_stage" "$IMPORT_STAGE" "Runtime staging path" || return 1
    require_strict_containment "$runtime_path" "$RUNTIME_REPOS" "Runtime repository path" || return 1
    mkdir -p "$(dirname "$runtime_stage")" "$(dirname "$runtime_path")" || return 1
    copy_complete_project "$code_path" "$runtime_stage" || return 1
    verify_complete_project "$code_path" "$runtime_stage" || return 1
    mv -- "$runtime_stage" "$runtime_path" || return 1
    return 0
  fi
  local snapshot=""
  local runtime_git runtime_branch runtime_head runtime_upstream runtime_staged runtime_unstaged runtime_untracked runtime_remote_slug runtime_remote_url
  snapshot="$(git_snapshot "$runtime_path")"
  IFS='|' read -r runtime_git runtime_branch runtime_head runtime_upstream runtime_staged runtime_unstaged runtime_untracked runtime_remote_slug runtime_remote_url <<< "$snapshot"
  if [[ "$runtime_git" -ne 1 || "$runtime_staged" -gt 0 || "$runtime_unstaged" -gt 0 || "$runtime_untracked" -gt 0 ]]; then
    warn "Runtime mirror is not clean; skipped without changing it: $runtime_path"
    return 1
  fi
  if [[ -d "$code_path/.git" || -f "$code_path/.git" ]]; then
    "$GIT_BIN" -c core.hooksPath=/dev/null -C "$runtime_path" fetch "$code_path" HEAD >/dev/null 2>&1 || return 1
    "$GIT_BIN" -c core.hooksPath=/dev/null -C "$runtime_path" merge --ff-only --no-verify FETCH_HEAD >/dev/null 2>&1 || return 1
  fi
  additive_heal "$code_path" "$runtime_path"
}

verified_zip() {
  local archive="$1"
  [[ -n "$archive" && -f "$archive" ]] || return 1
  unzip -tq "$archive" >/dev/null 2>&1
}

create_stage2_archive() {
  local source="$1"
  local slug="$2"
  local archive="$ARCHIVES_DIR/$slug.zip"
  local partial="$archive.partial.zip"
  local parent=""
  local leaf=""

  valid_repository_slug "$slug" || return 1
  require_strict_containment "$archive" "$ARCHIVES_DIR" "Stage 2 archive" || return 1
  require_strict_containment "$partial" "$ARCHIVES_DIR" "Stage 2 partial archive" || return 1
  mkdir -p "$(dirname "$archive")"
  rm -f -- "$partial"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    COPYFILE_DISABLE=0 /usr/bin/ditto -c -k --keepParent "$source" "$partial"
  else
    parent="$(dirname "$source")"
    leaf="$(basename "$source")"
    (cd "$parent" && zip -qry "$partial" "$leaf")
  fi
  verified_zip "$partial" || {
    rm -f -- "$partial"
    return 1
  }
  mv -- "$partial" "$archive"
  printf '%s' "$archive"
}

cleanup_verification_files() {
  local path=""
  for path in "$@"; do
    if [[ -n "$path" ]]; then
      rm -f -- "$path" || return 1
    fi
  done
  return 0
}

valid_sha256_digest() {
  local digest="$1"
  [[ "${#digest}" -eq 64 && "$digest" != *[!0-9a-f]* ]]
}

valid_git_object_id() {
  local object_id="$1"
  case "${#object_id}" in
    40|64) [[ "$object_id" != *[!0-9a-fA-F]* ]] ;;
    *) return 1 ;;
  esac
}

# Receipt contract:
#   git_ref_namespace=refs/csa-iem/recovery/<transaction>/<owner>/<repo>/source-refs
#   refs/heads/main -> <git_ref_namespace>/heads/main
#   source HEAD     -> <git_ref_namespace parent>/source-HEAD
# If a valid GitHub component is not a valid Git ref component, owner and repo
# are hex-encoded beneath an explicit `encoded` component. The receipt carries
# the resulting authoritative namespace verbatim for Stage 3 verification.
git_ref_namespace_for_slug() {
  local slug="$1"
  local raw_namespace="refs/csa-iem/recovery/$TRANSACTION_ID/$slug/source-refs"
  local owner=""
  local repository=""
  local owner_hex=""
  local repository_hex=""
  local encoded_namespace=""

  valid_repository_slug "$slug" || return 1
  if isolated_git check-ref-format "$raw_namespace/probe" >/dev/null 2>&1; then
    printf '%s' "$raw_namespace"
    return 0
  fi
  owner="${slug%%/*}"
  repository="${slug#*/}"
  owner_hex="$(printf '%s' "$owner" | hex_encode)" || return 1
  repository_hex="$(printf '%s' "$repository" | hex_encode)" || return 1
  [[ -n "$owner_hex" && -n "$repository_hex" ]] || return 1
  encoded_namespace="refs/csa-iem/recovery/$TRANSACTION_ID/encoded/owner-$owner_hex/repository-$repository_hex/source-refs"
  isolated_git check-ref-format "$encoded_namespace/probe" >/dev/null 2>&1 || return 1
  printf '%s' "$encoded_namespace"
}

git_head_recovery_ref_for_namespace() {
  local namespace="$1"
  local parent_namespace=""

  case "$namespace" in
    refs/*/source-refs) ;;
    *) return 1 ;;
  esac
  parent_namespace="${namespace%/source-refs}"
  isolated_git check-ref-format "$parent_namespace/source-HEAD" >/dev/null 2>&1 || return 1
  printf '%s/source-HEAD' "$parent_namespace"
}

permission_mode() {
  local path="$1"
  local mode=""

  if [[ "$(uname -s)" == "Darwin" ]]; then
    mode="$(stat -f '%Lp' "$path" 2>/dev/null)" || return 1
  else
    mode="$(stat -c '%a' "$path" 2>/dev/null)" || return 1
  fi
  case "$mode" in
    ""|*[!0-7]*) return 1 ;;
  esac
  printf '%04o' "$((8#$mode & 07777))"
}

hex_encode() {
  LC_ALL=C od -An -v -tx1 | tr -d ' \n'
}

# Filesystem evidence contract shared byte-for-byte with Stage 3. The embedded
# helper is deliberately bounded to capture/verify operations and runs with
# isolated Python startup (-I). Paths are encoded as raw filesystem-byte hex,
# so newlines, tabs, Unicode normalization, and case are never delimiters.
filesystem_evidence_helper() {
  [[ -n "$PYTHON3_BIN" && "$PYTHON3_BIN" == /* && -x "$PYTHON3_BIN" ]] || return 1
  "$PYTHON3_BIN" -I - "$@" <<'PY'
import errno
import ctypes
import hashlib
import json
import os
import platform
import plistlib
import re
import shutil
import stat
import subprocess
import sys

SCHEMA = "csa-iem-filesystem-evidence-v2"
VERSION = 2
EXACT = "path-bytes,type,regular-content-sha256,symlink-target,xattr-values,acl-bytes,active-or-recovery-representative"
RECORD_ONLY = "mode,uid,gid,bsd-flags,mtime,atime,birthtime,size-allocation-sparse,nlink-hardlink-topology"
PACKAGE_DIGEST_FILE = b"package.sha256"


class EvidenceError(RuntimeError):
    pass


def fail(message):
    raise EvidenceError(message)


def sha256_bytes(value):
    return hashlib.sha256(value).hexdigest()


def canonical_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def write_bytes(path, value, mode=0o600):
    parent = os.path.dirname(path)
    os.makedirs(parent, mode=0o700, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    try:
        view = memoryview(value)
        while view:
            count = os.write(fd, view)
            if count <= 0:
                fail("short write while creating evidence")
            view = view[count:]
        os.fsync(fd)
    finally:
        os.close(fd)


def hash_regular(path):
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    fd = os.open(path, flags)
    digest = hashlib.sha256()
    try:
        before = os.fstat(fd)
        while True:
            block = os.read(fd, 1024 * 1024)
            if not block:
                break
            digest.update(block)
        after = os.fstat(fd)
    finally:
        os.close(fd)
    stable = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns)
    stable_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
    if stable != stable_after:
        fail("regular file changed while hashing")
    return digest.hexdigest()


def enumerate_paths(root):
    paths = [(b"", root)]

    def descend(relative, absolute):
        try:
            with os.scandir(absolute) as iterator:
                children = sorted(((os.fsencode(item.name), item.path) for item in iterator), key=lambda pair: pair[0])
        except OSError as exc:
            fail("directory enumeration failed: %s" % exc)
        for name, child in children:
            child_b = os.fsencode(child)
            child_relative = name if not relative else relative + b"/" + name
            paths.append((child_relative, child_b))
            try:
                child_stat = os.lstat(child_b)
            except OSError as exc:
                fail("entry stat failed: %s" % exc)
            if stat.S_ISDIR(child_stat.st_mode):
                descend(child_relative, child_b)

    descend(b"", root)
    paths.sort(key=lambda pair: pair[0])
    return paths


def acl_bytes(path):
    system = platform.system()
    if system == "Darwin":
        command = [b"/bin/ls", b"-lde", path]
        try:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        except OSError as exc:
            fail("ACL reader failed: %s" % exc)
        if result.returncode != 0:
            fail("ACL reader returned nonzero status")
        rows = [line.strip() for line in result.stdout.splitlines()[1:] if re.match(br"^\s*[0-9]+:\s", line)]
        return b"\n".join(rows) + (b"\n" if rows else b""), "supported"
    getfacl = shutil.which("getfacl")
    if getfacl:
        command = [os.fsencode(getfacl), b"-cp", b"--", path]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        if result.returncode != 0:
            fail("getfacl returned nonzero status")
        return result.stdout, "supported"
    return b"", "record-only:acl-reader-unavailable"


class DarwinTimespec(ctypes.Structure):
    _fields_ = [("tv_sec", ctypes.c_long), ("tv_nsec", ctypes.c_long)]


class DarwinStat(ctypes.Structure):
    _fields_ = [
        ("st_dev", ctypes.c_int32),
        ("st_mode", ctypes.c_uint16),
        ("st_nlink", ctypes.c_uint16),
        ("st_ino", ctypes.c_uint64),
        ("st_uid", ctypes.c_uint32),
        ("st_gid", ctypes.c_uint32),
        ("st_rdev", ctypes.c_int32),
        ("st_atimespec", DarwinTimespec),
        ("st_mtimespec", DarwinTimespec),
        ("st_ctimespec", DarwinTimespec),
        ("st_birthtimespec", DarwinTimespec),
        ("st_size", ctypes.c_int64),
        ("st_blocks", ctypes.c_int64),
        ("st_blksize", ctypes.c_int32),
        ("st_flags", ctypes.c_uint32),
        ("st_gen", ctypes.c_uint32),
        ("st_lspare", ctypes.c_int32),
        ("st_qspare", ctypes.c_int64 * 2),
    ]


def timespec_ns(value):
    if value.tv_nsec < 0 or value.tv_nsec >= 1_000_000_000:
        fail("native Darwin stat returned an invalid nanosecond field")
    return int(value.tv_sec) * 1_000_000_000 + int(value.tv_nsec)


def darwin_birthtime_ns(path, current):
    libc = ctypes.CDLL(None, use_errno=True)
    libc.lstat.argtypes = [ctypes.c_char_p, ctypes.POINTER(DarwinStat)]
    libc.lstat.restype = ctypes.c_int
    native = DarwinStat()
    if libc.lstat(path, ctypes.byref(native)) != 0:
        fail("native Darwin lstat failed: %s" % os.strerror(ctypes.get_errno()))
    native_atime = timespec_ns(native.st_atimespec)
    native_mtime = timespec_ns(native.st_mtimespec)
    native_ctime = timespec_ns(native.st_ctimespec)
    checks = (
        int(native.st_dev) == int(current.st_dev),
        int(native.st_ino) == int(current.st_ino),
        int(native.st_mode) == int(current.st_mode),
        int(native.st_nlink) == int(current.st_nlink),
        int(native.st_uid) == int(current.st_uid),
        int(native.st_gid) == int(current.st_gid),
        int(native.st_size) == int(current.st_size),
        int(native.st_blocks) == int(current.st_blocks),
        int(native.st_blksize) == int(current.st_blksize),
        int(native.st_flags) == int(current.st_flags),
        native_atime == int(current.st_atime_ns),
        native_mtime == int(current.st_mtime_ns),
        native_ctime == int(current.st_ctime_ns),
    )
    if not all(checks):
        fail("native Darwin stat ABI validation failed")
    return timespec_ns(native.st_birthtimespec)


def darwin_xattr_values(path):
    libc = ctypes.CDLL(None, use_errno=True)
    nofollow = 0x0001
    libc.listxattr.restype = ctypes.c_ssize_t
    libc.getxattr.restype = ctypes.c_ssize_t
    for _ in range(3):
        size = libc.listxattr(path, None, 0, nofollow)
        if size < 0:
            error = ctypes.get_errno()
            if error in (errno.ENOTSUP, getattr(errno, "EOPNOTSUPP", errno.ENOTSUP)):
                return [], {}, "record-only:xattrs-filesystem-unsupported"
            fail("native xattr enumeration failed: %s" % os.strerror(error))
        if size == 0:
            return [], {}, "supported"
        buffer = ctypes.create_string_buffer(size)
        actual = libc.listxattr(path, buffer, size, nofollow)
        if actual < 0 and ctypes.get_errno() == errno.ERANGE:
            continue
        if actual < 0:
            fail("native xattr enumeration read failed: %s" % os.strerror(ctypes.get_errno()))
        names = sorted(name for name in bytes(buffer.raw[:actual]).split(b"\0") if name)
        rows = []
        values = {}
        for name in names:
            value = None
            for _ in range(3):
                value_size = libc.getxattr(path, name, None, 0, 0, nofollow)
                if value_size < 0:
                    fail("native xattr size read failed: %s" % os.strerror(ctypes.get_errno()))
                value_buffer = ctypes.create_string_buffer(value_size if value_size else 1)
                value_actual = libc.getxattr(path, name, value_buffer, value_size, 0, nofollow)
                if value_actual < 0 and ctypes.get_errno() == errno.ERANGE:
                    continue
                if value_actual < 0:
                    fail("native xattr value read failed: %s" % os.strerror(ctypes.get_errno()))
                value = bytes(value_buffer.raw[:value_actual])
                break
            if value is None:
                fail("native xattr value remained unstable")
            name_hex = name.hex()
            values[name_hex] = value
            rows.append({"name_hex": name_hex, "length": len(value), "value_sha256": sha256_bytes(value)})
        return rows, values, "supported"
    fail("native xattr enumeration remained unstable")


def xattr_values(path):
    if not hasattr(os, "listxattr") or not hasattr(os, "getxattr"):
        if platform.system() == "Darwin":
            return darwin_xattr_values(path)
        return [], {}, "record-only:python-xattr-api-unavailable"
    try:
        names = os.listxattr(path, follow_symlinks=False)
    except TypeError:
        if platform.system() == "Darwin":
            return darwin_xattr_values(path)
        return [], {}, "record-only:no-nofollow-xattr-api"
    except OSError as exc:
        if exc.errno in (errno.ENOTSUP, getattr(errno, "EOPNOTSUPP", errno.ENOTSUP)):
            return [], {}, "record-only:xattrs-filesystem-unsupported"
        fail("xattr enumeration failed: %s" % exc)
    encoded_names = sorted(os.fsencode(name) for name in names)
    rows = []
    values = {}
    for name in encoded_names:
        try:
            value = os.getxattr(path, os.fsdecode(name), follow_symlinks=False)
        except TypeError:
            if platform.system() == "Darwin":
                return darwin_xattr_values(path)
            return [], {}, "record-only:no-nofollow-xattr-api"
        except OSError as exc:
            fail("xattr value read failed: %s" % exc)
        name_hex = name.hex()
        values[name_hex] = value
        rows.append({"name_hex": name_hex, "length": len(value), "value_sha256": sha256_bytes(value)})
    return rows, values, "supported"


def entry_record(path, relative):
    try:
        before = os.lstat(path)
    except OSError as exc:
        fail("entry lstat failed: %s" % exc)
    mode_type = before.st_mode
    content_digest = None
    target_hex = None
    if stat.S_ISREG(mode_type):
        kind = "regular"
        content_digest = hash_regular(path)
    elif stat.S_ISDIR(mode_type):
        kind = "directory"
    elif stat.S_ISLNK(mode_type):
        kind = "symlink"
        target = os.readlink(path)
        target_hex = os.fsencode(target).hex()
    elif stat.S_ISSOCK(mode_type) and relative == b".git/fsmonitor--daemon.ipc":
        fail("Git fsmonitor socket must be stopped and absent before evidence capture")
    elif stat.S_ISSOCK(mode_type):
        fail("unknown Unix socket blocks evidence capture")
    elif stat.S_ISFIFO(mode_type):
        fail("FIFO blocks evidence capture")
    elif stat.S_ISCHR(mode_type) or stat.S_ISBLK(mode_type):
        fail("device node blocks evidence capture")
    else:
        fail("unsupported filesystem entry blocks evidence capture")
    try:
        current = os.lstat(path)
    except OSError as exc:
        fail("entry restat failed: %s" % exc)
    identity_before = (before.st_dev, before.st_ino, stat.S_IFMT(before.st_mode))
    identity_after = (current.st_dev, current.st_ino, stat.S_IFMT(current.st_mode))
    if identity_before != identity_after:
        fail("entry identity changed during evidence capture")
    xattrs, raw_xattrs, xattr_status = xattr_values(path)
    acl, acl_status = acl_bytes(path)
    birthtime_ns = None
    if platform.system() == "Darwin":
        birthtime_ns = darwin_birthtime_ns(path, current)
    elif hasattr(current, "st_birthtime_ns"):
        birthtime_ns = int(current.st_birthtime_ns)
    flags = int(current.st_flags) if hasattr(current, "st_flags") else None
    blocks = int(current.st_blocks) if hasattr(current, "st_blocks") else None
    allocated = blocks * 512 if blocks is not None else None
    sparse = bool(kind == "regular" and allocated is not None and allocated < current.st_size)
    hardlink_group = None
    if kind == "regular" and current.st_nlink > 1:
        hardlink_group = sha256_bytes((str(current.st_dev) + ":" + str(current.st_ino)).encode("ascii"))
    public = {
        "acl_sha256": sha256_bytes(acl),
        "acl_status": acl_status,
        "allocated_bytes": allocated,
        "atime_ns": int(current.st_atime_ns),
        "birthtime_ns": birthtime_ns,
        "bsd_flags": flags,
        "content_sha256": content_digest,
        "gid": int(current.st_gid),
        "hardlink_group": hardlink_group,
        "mode": format(stat.S_IMODE(current.st_mode), "04o"),
        "mtime_ns": int(current.st_mtime_ns),
        "nlink": int(current.st_nlink),
        "path_encoding": "hex-filesystem-bytes",
        "path_hex": relative.hex(),
        "size": int(current.st_size),
        "sparse": sparse,
        "symlink_target_hex": target_hex,
        "type": kind,
        "uid": int(current.st_uid),
        "xattr_status": xattr_status,
        "xattrs": xattrs,
    }
    return public, raw_xattrs, acl


def collect(root):
    records = []
    private = {}
    for relative, path in enumerate_paths(root):
        record, raw_xattrs, acl = entry_record(path, relative)
        records.append(record)
        private[record["path_hex"]] = (raw_xattrs, acl)
    return records, private


def source_view(record):
    clean = dict(record)
    clean.pop("representative", None)
    clean.pop("acl_sidecar", None)
    clean.pop("acl_sidecar_sha256", None)
    normalized_xattrs = []
    for row in clean.get("xattrs", []):
        item = dict(row)
        item.pop("sidecar", None)
        item.pop("sidecar_sha256", None)
        normalized_xattrs.append(item)
    clean["xattrs"] = normalized_xattrs
    return clean


def stable_collect(root):
    first, _ = collect(root)
    second, private = collect(root)
    if canonical_json([source_view(row) for row in first]) != canonical_json([source_view(row) for row in second]):
        fail("source filesystem metadata is unstable across consecutive captures")
    return second, private


def exact_entry_path(root, relative):
    if not relative:
        return root
    current = root
    parts = relative.split(b"/")
    for index, part in enumerate(parts):
        try:
            with os.scandir(current) as iterator:
                matches = [os.fsencode(item.name) for item in iterator if os.fsencode(item.name) == part]
        except OSError:
            return None
        if len(matches) != 1:
            return None
        current = os.path.join(current, part)
        try:
            current_stat = os.lstat(current)
        except OSError:
            return None
        if index != len(parts) - 1 and not stat.S_ISDIR(current_stat.st_mode):
            return None
    return current


def representative_matches(record, path):
    if path is None:
        return False
    try:
        current = os.lstat(path)
    except OSError:
        return False
    kind = record["type"]
    if kind == "directory":
        return stat.S_ISDIR(current.st_mode)
    if kind == "symlink":
        return stat.S_ISLNK(current.st_mode) and os.fsencode(os.readlink(path)).hex() == record["symlink_target_hex"]
    if kind == "regular":
        return stat.S_ISREG(current.st_mode) and hash_regular(path) == record["content_sha256"]
    return False


def copy_representative(source_root, relative, record, package):
    token = sha256_bytes(b"representative\0" + relative)
    suffix = {"directory": ".dir", "regular": ".file", "symlink": ".link"}[record["type"]]
    rep_relative = os.fsencode("representatives/" + token + suffix)
    rep = os.path.join(package, rep_relative)
    os.makedirs(os.path.dirname(rep), mode=0o700, exist_ok=True)
    source_path = exact_entry_path(source_root, relative)
    if source_path is None:
        fail("source path disappeared while creating recovery representative")
    if record["type"] == "directory":
        os.mkdir(rep, 0o700)
    elif record["type"] == "symlink":
        os.symlink(os.readlink(source_path), rep)
    else:
        flags = os.O_RDONLY | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0)
        source_fd = os.open(source_path, flags)
        destination_fd = os.open(rep, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        digest = hashlib.sha256()
        try:
            while True:
                block = os.read(source_fd, 1024 * 1024)
                if not block:
                    break
                digest.update(block)
                view = memoryview(block)
                while view:
                    count = os.write(destination_fd, view)
                    if count <= 0:
                        fail("short recovery representative write")
                    view = view[count:]
            os.fsync(destination_fd)
        finally:
            os.close(source_fd)
            os.close(destination_fd)
        if digest.hexdigest() != record["content_sha256"]:
            fail("source changed while copying recovery representative")
    if not representative_matches(record, rep):
        fail("recovery representative did not verify")
    return rep_relative.decode("ascii")


def add_representatives(records, private, source, destination, package, git_snapshot_relative):
    git_snapshot_bytes = None if git_snapshot_relative == "-" else os.fsencode(git_snapshot_relative)
    for record in records:
        relative = bytes.fromhex(record["path_hex"])
        candidate = None
        representative_kind = "active-canonical"
        representative_relative = relative
        if relative == b".git" or relative.startswith(b".git/"):
            if git_snapshot_bytes is not None:
                suffix = relative[4:] if relative.startswith(b".git/") else b""
                representative_relative = git_snapshot_bytes if not suffix else git_snapshot_bytes + b"/" + suffix
                candidate = exact_entry_path(destination, representative_relative)
                representative_kind = "git-snapshot"
        else:
            candidate = exact_entry_path(destination, relative)
        if representative_matches(record, candidate):
            record["representative"] = {
                "kind": representative_kind,
                "root": "canonical-destination",
                "path_hex": representative_relative.hex(),
            }
        else:
            rep_relative = copy_representative(source, relative, record, package)
            record["representative"] = {
                "kind": "source-specific-recovery",
                "root": "evidence-package",
                "relative": rep_relative,
            }
        raw_xattrs, acl = private[record["path_hex"]]
        for xattr in record["xattrs"]:
            name_hex = xattr["name_hex"]
            value = raw_xattrs[name_hex]
            sidecar = "xattrs/" + sha256_bytes(b"xattr\0" + relative + b"\0" + bytes.fromhex(name_hex)) + ".bin"
            write_bytes(os.path.join(package, os.fsencode(sidecar)), value)
            xattr["sidecar"] = sidecar
            xattr["sidecar_sha256"] = sha256_bytes(value)
        if record["acl_status"] == "supported" and acl:
            sidecar = "acl/" + sha256_bytes(b"acl\0" + relative) + ".txt"
            write_bytes(os.path.join(package, os.fsencode(sidecar)), acl)
            record["acl_sidecar"] = sidecar
            record["acl_sidecar_sha256"] = sha256_bytes(acl)


def path_within(root, candidate):
    root_real = os.path.realpath(root)
    candidate_real = os.path.realpath(candidate)
    separator = os.fsencode(os.sep) if isinstance(root_real, bytes) else os.sep
    return candidate_real == root_real or candidate_real.startswith(root_real + separator)


def resolve_representative(record, destination, package):
    representative = record.get("representative") or {}
    root = representative.get("root")
    if root == "canonical-destination":
        relative = bytes.fromhex(representative.get("path_hex", ""))
        return exact_entry_path(destination, relative)
    if root == "evidence-package":
        relative = representative.get("relative", "")
        if not re.match(r"^representatives/[0-9a-f]{64}\.(dir|file|link)$", relative):
            fail("unsafe evidence representative path")
        candidate = os.path.join(package, os.fsencode(relative))
        if not path_within(package, candidate):
            fail("evidence representative escaped package")
        return candidate
    fail("unknown representative root")


def verify_sidecars(record, package):
    for xattr in record.get("xattrs", []):
        sidecar = xattr.get("sidecar")
        if not sidecar or not re.match(r"^xattrs/[0-9a-f]{64}\.bin$", sidecar):
            fail("xattr sidecar is missing or unsafe")
        path = os.path.join(package, os.fsencode(sidecar))
        if not os.path.isfile(path) or os.path.islink(path) or hash_regular(path) != xattr["value_sha256"]:
            fail("xattr sidecar digest mismatch")
        if xattr.get("sidecar_sha256") != xattr["value_sha256"]:
            fail("xattr sidecar receipt mismatch")
    acl_sidecar = record.get("acl_sidecar")
    if acl_sidecar:
        if not re.match(r"^acl/[0-9a-f]{64}\.txt$", acl_sidecar):
            fail("ACL sidecar path is unsafe")
        path = os.path.join(package, os.fsencode(acl_sidecar))
        if not os.path.isfile(path) or os.path.islink(path) or hash_regular(path) != record["acl_sha256"]:
            fail("ACL sidecar digest mismatch")
        if record.get("acl_sidecar_sha256") != record["acl_sha256"]:
            fail("ACL sidecar receipt mismatch")


def package_digest(package):
    rows = []
    for relative, path in enumerate_paths(package):
        if relative in (PACKAGE_DIGEST_FILE, b"final.receipt"):
            continue
        current = os.lstat(path)
        mode = format(stat.S_IMODE(current.st_mode), "04o")
        if stat.S_ISDIR(current.st_mode):
            rows.append(["directory", relative.hex(), mode, None])
        elif stat.S_ISREG(current.st_mode):
            rows.append(["regular", relative.hex(), mode, hash_regular(path)])
        else:
            fail("evidence package contains a symlink or special entry")
    return sha256_bytes(canonical_json(rows))


def load_manifest(package):
    manifest_path = os.path.join(package, b"manifest.jsonl")
    if not os.path.isfile(manifest_path) or os.path.islink(manifest_path):
        fail("manifest is missing or unsafe")
    with open(manifest_path, "rb") as handle:
        raw = handle.read()
    records = []
    for line in raw.splitlines():
        if not line:
            fail("manifest contains an empty row")
        records.append(json.loads(line.decode("ascii")))
    if [row["path_hex"] for row in records] != sorted(row["path_hex"] for row in records):
        fail("manifest path order is not deterministic")
    return records, raw, sha256_bytes(raw)


def verify_package(package, destination):
    if not os.path.isdir(package) or os.path.islink(package):
        fail("evidence package is not a real directory")
    digest_file = os.path.join(package, PACKAGE_DIGEST_FILE)
    if not os.path.isfile(digest_file) or os.path.islink(digest_file):
        fail("package digest file is missing")
    with open(digest_file, "rb") as handle:
        declared = handle.read().decode("ascii").strip()
    actual = package_digest(package)
    if declared != actual or not re.match(r"^[0-9a-f]{64}$", declared):
        fail("evidence package digest mismatch")
    records, raw_manifest, manifest_digest = load_manifest(package)
    for record in records:
        verify_sidecars(record, package)
        representative = resolve_representative(record, destination, package)
        if not representative_matches(record, representative):
            fail("active or recovery representative no longer verifies")
    return records, raw_manifest, manifest_digest, actual


def binding_value(value):
    return None if value == "-" else value


def expected_binding(arguments):
    (kind, transaction, repository, repository_id, github_owner, github_login, github_binding_digest,
     repository_role, parent_repository, exact_git_remote, wiki_ref_digest, wiki_default_branch,
     wiki_head_oid, binding_source_path, package_relative, git_snapshot_relative,
     git_snapshot_digest, git_ref_namespace,
     stage1_receipt_path, stage1_receipt_digest, stage2_receipt_path, stage2_receipt_digest) = arguments
    return {
        "binding_kind": kind,
        "destination_path_hex": None,
        "exact_categories": EXACT,
        "final_proof": "manifest-representatives-and-git-snapshot-verified",
        "git_ref_namespace": binding_value(git_ref_namespace),
        "git_snapshot_digest": binding_value(git_snapshot_digest),
        "git_snapshot_relative": binding_value(git_snapshot_relative),
        "github_account_binding_schema": "owner-login-v1",
        "github_account_binding_digest": github_binding_digest,
        "github_owner": github_owner,
        "github_login": github_login,
        "exact_git_remote": exact_git_remote,
        "package_relative": package_relative,
        "parent_repository": parent_repository,
        "record_only_categories": RECORD_ONLY,
        "repository": repository,
        "repository_id": repository_id,
        "repository_role": repository_role,
        "schema": SCHEMA,
        "source_path_hex": os.fsencode(binding_source_path).hex(),
        "stage1_receipt_digest": binding_value(stage1_receipt_digest),
        "stage1_receipt_path_hex": None if stage1_receipt_path == "-" else os.fsencode(stage1_receipt_path).hex(),
        "stage2_receipt_digest": binding_value(stage2_receipt_digest),
        "stage2_receipt_path_hex": None if stage2_receipt_path == "-" else os.fsencode(stage2_receipt_path).hex(),
        "transaction": transaction,
        "version": VERSION,
        "wiki_default_branch": binding_value(wiki_default_branch),
        "wiki_head_oid": binding_value(wiki_head_oid),
        "wiki_ref_digest": binding_value(wiki_ref_digest),
    }


def unsupported_categories(records):
    values = set()
    if any(row.get("bsd_flags") is None for row in records):
        values.add("bsd-flags:record-only-unavailable")
    if any(row.get("birthtime_ns") is None for row in records):
        values.add("birthtime:record-only-unavailable")
    if any(row.get("allocated_bytes") is None for row in records):
        values.add("allocation:record-only-unavailable")
    for row in records:
        if row.get("acl_status") != "supported":
            values.add(row["acl_status"])
        if row.get("xattr_status") != "supported":
            values.add(row["xattr_status"])
    return ";".join(sorted(values)) if values else "none"


def destination_capabilities(destination):
    current = os.lstat(destination)
    result = {
        "destination_device": int(current.st_dev),
        "destination_owners_enabled": None,
        "destination_volume_uuid": None,
        "destination_volume_probe": "record-only:platform-does-not-expose-diskutil",
    }
    if platform.system() != "Darwin" or not os.path.exists("/usr/sbin/diskutil"):
        return result
    completed = subprocess.run(
        [b"/usr/sbin/diskutil", b"info", b"-plist", destination],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        result["destination_volume_probe"] = "record-only:diskutil-probe-failed"
        return result
    try:
        payload = plistlib.loads(completed.stdout)
    except Exception:
        result["destination_volume_probe"] = "record-only:diskutil-plist-invalid"
        return result
    volume_uuid = payload.get("VolumeUUID")
    owners_enabled = payload.get("GlobalPermissionsEnabled")
    if isinstance(volume_uuid, str) and volume_uuid:
        result["destination_volume_uuid"] = volume_uuid
    if isinstance(owners_enabled, bool):
        result["destination_owners_enabled"] = owners_enabled
    result["destination_volume_probe"] = "supported"
    return result


def source_tree_digest(records):
    rows = []
    for row in records:
        rows.append({
            "content_sha256": row.get("content_sha256"),
            "path_hex": row["path_hex"],
            "symlink_target_hex": row.get("symlink_target_hex"),
            "type": row["type"],
        })
    return sha256_bytes(canonical_json(rows))


def print_result(binding_digest, manifest_digest, package_sha, tree_digest_value, binding, records):
    values = {
        "binding_digest": binding_digest,
        "destination_device": str(binding["destination_device"]),
        "destination_owners_enabled": "unknown" if binding["destination_owners_enabled"] is None else str(binding["destination_owners_enabled"]).lower(),
        "destination_volume_uuid": binding["destination_volume_uuid"] or "unavailable",
        "evidence_digest": package_sha,
        "exact_categories": EXACT,
        "manifest_digest": manifest_digest,
        "record_only_categories": RECORD_ONLY,
        "source_device": str(binding["source_device"]),
        "source_inode": str(binding["source_inode"]),
        "source_path_hex": binding["source_path_hex"],
        "source_tree_digest": tree_digest_value,
        "unsupported_categories": unsupported_categories(records),
    }
    for key in sorted(values):
        print(key + "=" + values[key])


def capture(argv):
    if len(argv) != 26:
        fail("capture expects 25 arguments")
    source = os.fsencode(argv[1])
    destination = os.fsencode(argv[2])
    package = os.fsencode(argv[3])
    binding_args = argv[4:]
    if not os.path.isdir(source) or os.path.islink(source):
        fail("source must be a real directory")
    if not os.path.isdir(destination) or os.path.islink(destination):
        fail("destination must be a real directory")
    if os.path.lexists(package):
        fail("evidence package already exists")
    os.makedirs(package, mode=0o700)
    try:
        records, private = stable_collect(source)
        expected = expected_binding(binding_args)
        expected["destination_path_hex"] = destination.hex()
        expected.update(destination_capabilities(destination))
        root_stat = os.lstat(source)
        expected["source_device"] = int(root_stat.st_dev)
        expected["source_inode"] = int(root_stat.st_ino)
        add_representatives(records, private, source, destination, package, binding_args[15])
        manifest_raw = b"".join(canonical_json(record) + b"\n" for record in records)
        write_bytes(os.path.join(package, b"manifest.jsonl"), manifest_raw)
        manifest_digest = sha256_bytes(manifest_raw)
        tree_digest_value = source_tree_digest(records)
        expected["manifest_digest"] = manifest_digest
        expected["source_tree_digest"] = tree_digest_value
        expected["unsupported_categories"] = unsupported_categories(records)
        binding_raw = canonical_json(expected) + b"\n"
        write_bytes(os.path.join(package, b"binding.json"), binding_raw)
        binding_digest = sha256_bytes(binding_raw)
        package_sha = package_digest(package)
        write_bytes(os.path.join(package, PACKAGE_DIGEST_FILE), (package_sha + "\n").encode("ascii"))
        verified_records, _, verified_manifest, verified_package = verify_package(package, destination)
        if verified_manifest != manifest_digest or verified_package != package_sha:
            fail("post-capture evidence verification mismatch")
        print_result(binding_digest, manifest_digest, package_sha, tree_digest_value, expected, verified_records)
    except Exception:
        raise


def verify(argv):
    if len(argv) != 33:
        fail("verify expects 32 arguments")
    source_argument = argv[1]
    destination = os.fsencode(argv[2])
    package = os.fsencode(argv[3])
    binding_args = argv[4:26]
    expected_manifest, expected_package, expected_binding_digest, expected_tree = argv[26:30]
    expected_device, expected_inode = argv[30:32]
    # argv[32] is an explicit package-relative path duplicate. It prevents a
    # caller from resolving one package while validating another binding.
    package_relative_duplicate = argv[32]
    records, _, manifest_digest, package_sha = verify_package(package, destination)
    binding_path = os.path.join(package, b"binding.json")
    if not os.path.isfile(binding_path) or os.path.islink(binding_path):
        fail("binding is missing or unsafe")
    with open(binding_path, "rb") as handle:
        binding_raw = handle.read()
    binding_digest = sha256_bytes(binding_raw)
    binding = json.loads(binding_raw.decode("ascii"))
    expected = expected_binding(binding_args)
    expected["destination_path_hex"] = destination.hex()
    expected.update(destination_capabilities(destination))
    if binding.get("package_relative") != package_relative_duplicate:
        fail("package relative path duplicate does not match binding")
    for key, value in expected.items():
        if binding.get(key) != value:
            fail("binding field mismatch: " + key)
    tree_digest_value = source_tree_digest(records)
    checks = (
        manifest_digest == expected_manifest == binding.get("manifest_digest"),
        package_sha == expected_package,
        binding_digest == expected_binding_digest,
        tree_digest_value == expected_tree == binding.get("source_tree_digest"),
        str(binding.get("source_device")) == expected_device,
        str(binding.get("source_inode")) == expected_inode,
        binding.get("unsupported_categories") == unsupported_categories(records),
    )
    if not all(checks):
        fail("receipt-bound evidence digest or source identity mismatch")
    if source_argument != "-":
        source = os.fsencode(source_argument)
        live_stat = os.lstat(source)
        if not stat.S_ISDIR(live_stat.st_mode) or os.path.islink(source):
            fail("live source is not a real directory")
        if str(live_stat.st_dev) != expected_device or str(live_stat.st_ino) != expected_inode:
            fail("live source device/inode changed")
        live_records, _ = stable_collect(source)
        if canonical_json([source_view(row) for row in live_records]) != canonical_json([source_view(row) for row in records]):
            fail("live source filesystem manifest drifted")
    print_result(binding_digest, manifest_digest, package_sha, tree_digest_value, binding, records)


def main():
    if len(sys.argv) < 2:
        fail("missing evidence helper mode")
    if sys.argv[1] == "capture":
        capture(sys.argv[1:])
    elif sys.argv[1] == "verify":
        verify(sys.argv[1:])
    else:
        fail("unknown evidence helper mode")


try:
    main()
except (EvidenceError, OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
    print("filesystem-evidence-error: " + str(exc), file=sys.stderr)
    sys.exit(2)
PY
}

reset_current_filesystem_evidence() {
  CURRENT_FILESYSTEM_EVIDENCE=""
  CURRENT_FILESYSTEM_EVIDENCE_DIGEST=""
  CURRENT_FILESYSTEM_MANIFEST_DIGEST=""
  CURRENT_FILESYSTEM_BINDING_DIGEST=""
  CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST=""
  CURRENT_FILESYSTEM_SOURCE_PATH_HEX=""
  CURRENT_FILESYSTEM_SOURCE_DEVICE=""
  CURRENT_FILESYSTEM_SOURCE_INODE=""
  CURRENT_FILESYSTEM_EXACT_CATEGORIES=""
  CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES=""
  CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES=""
  CURRENT_FILESYSTEM_DESTINATION_DEVICE=""
  CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID=""
  CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED=""
  CURRENT_FILESYSTEM_BINDING_SOURCE=""
  CURRENT_VERIFIED_SLUG=""
}

load_filesystem_evidence_result() {
  local result_file="$1"
  local key=""
  local value=""

  while IFS='=' read -r key value; do
    case "$key" in
      binding_digest) CURRENT_FILESYSTEM_BINDING_DIGEST="$value" ;;
      destination_device) CURRENT_FILESYSTEM_DESTINATION_DEVICE="$value" ;;
      destination_owners_enabled) CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED="$value" ;;
      destination_volume_uuid) CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID="$value" ;;
      evidence_digest) CURRENT_FILESYSTEM_EVIDENCE_DIGEST="$value" ;;
      exact_categories) CURRENT_FILESYSTEM_EXACT_CATEGORIES="$value" ;;
      manifest_digest) CURRENT_FILESYSTEM_MANIFEST_DIGEST="$value" ;;
      record_only_categories) CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES="$value" ;;
      source_device) CURRENT_FILESYSTEM_SOURCE_DEVICE="$value" ;;
      source_inode) CURRENT_FILESYSTEM_SOURCE_INODE="$value" ;;
      source_path_hex) CURRENT_FILESYSTEM_SOURCE_PATH_HEX="$value" ;;
      source_tree_digest) CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST="$value" ;;
      unsupported_categories) CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES="$value" ;;
      *) return 1 ;;
    esac
  done < "$result_file"

  valid_sha256_digest "$CURRENT_FILESYSTEM_EVIDENCE_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_FILESYSTEM_MANIFEST_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_FILESYSTEM_BINDING_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST" || return 1
  [[ -n "$CURRENT_FILESYSTEM_SOURCE_PATH_HEX" &&
     "$CURRENT_FILESYSTEM_SOURCE_PATH_HEX" != *[!0-9a-f]* &&
     "$CURRENT_FILESYSTEM_SOURCE_DEVICE" != *[!0-9]* &&
     "$CURRENT_FILESYSTEM_SOURCE_INODE" != *[!0-9]* &&
     -n "$CURRENT_FILESYSTEM_EXACT_CATEGORIES" &&
     -n "$CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES" &&
     -n "$CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES" &&
     "$CURRENT_FILESYSTEM_DESTINATION_DEVICE" != *[!0-9]* &&
     ( "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "true" ||
       "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "false" ||
       "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "unknown" ) &&
     -n "$CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID" ]]
}

bind_current_repository_identity() {
  local slug="$1"
  local metadata=""
  local repository_id=""
  local canonical_slug=""
  local repository_url=""
  local repository_role=""
  local parent_repository=""
  local exact_git_remote=""
  local wiki_ref_digest=""
  local wiki_default_branch=""
  local wiki_head_oid=""
  local owner=""

  metadata="$(repository_identity_metadata "$slug" 2>/dev/null || true)" || return 1
  IFS=$'\t' read -r repository_id canonical_slug _ repository_url _ _ _ _ _ \
    repository_role parent_repository exact_git_remote wiki_ref_digest wiki_default_branch wiki_head_oid <<< "$metadata"
  [[ -n "$repository_id" && "$repository_id" != *$'\n'* && "$repository_id" != *$'\r'* &&
     "$canonical_slug" == "$slug" ]] || return 1
  [[ "$repository_role" == "repository" || "$repository_role" == "wiki" ]] || return 1
  valid_repository_slug "$parent_repository" || return 1
  [[ -n "$exact_git_remote" && "$exact_git_remote" != *$'\n'* && "$exact_git_remote" != *$'\r'* ]] || return 1
  if [[ "$repository_role" == "wiki" ]]; then
    is_wiki_slug "$slug" && valid_sha256_digest "$wiki_ref_digest" &&
      valid_git_object_id "$wiki_head_oid" && [[ -n "$wiki_default_branch" ]] || return 1
  else
    is_wiki_slug "$slug" && return 1
    [[ "$wiki_ref_digest" == "-" && "$wiki_default_branch" == "-" && "$wiki_head_oid" == "-" ]] || return 1
  fi
  owner="${slug%%/*}"
  bind_current_github_owner "$owner" || return 1
  CURRENT_REPOSITORY_ID="$repository_id"
  CURRENT_REPOSITORY_ROLE="$repository_role"
  CURRENT_PARENT_REPOSITORY="$parent_repository"
  CURRENT_EXACT_GIT_REMOTE="$exact_git_remote"
  CURRENT_WIKI_REF_DIGEST="$wiki_ref_digest"
  CURRENT_WIKI_DEFAULT_BRANCH="$wiki_default_branch"
  CURRENT_WIKI_HEAD_OID="$wiki_head_oid"
}

prepare_git_fsmonitor_for_evidence() {
  local source="$1"
  local socket_path="$source/.git/fsmonitor--daemon.ipc"

  if [[ -S "$socket_path" ]]; then
    isolated_git -C "$source" fsmonitor--daemon stop >/dev/null 2>&1 || {
      warn "Git fsmonitor daemon could not be stopped before filesystem evidence capture: $source"
      return 1
    }
  fi
  if [[ -S "$socket_path" ]]; then
    warn "Git fsmonitor socket remains after daemon stop; evidence capture is blocked: $socket_path"
    return 1
  fi
  return 0
}

verify_current_filesystem_evidence() {
  local source="$1"
  local destination="$2"
  local package=""
  local result_file=""
  local git_snapshot="${CURRENT_GIT_SNAPSHOT:--}"
  local git_snapshot_digest="${CURRENT_GIT_SNAPSHOT_DIGEST:--}"
  local git_ref_namespace="${CURRENT_GIT_REF_NAMESPACE:--}"
  local verified_evidence=""
  local verified_manifest=""
  local verified_binding=""
  local verified_tree=""
  local verified_device=""
  local verified_inode=""
  local key=""
  local value=""

  [[ -n "$CURRENT_FILESYSTEM_EVIDENCE" && -n "$CURRENT_REPOSITORY_ID" ]] || return 1
  [[ -n "$CURRENT_GITHUB_OWNER" && -n "$CURRENT_GITHUB_LOGIN" &&
     -n "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST" && -n "$CURRENT_REPOSITORY_ROLE" &&
     -n "$CURRENT_PARENT_REPOSITORY" && -n "$CURRENT_EXACT_GIT_REMOTE" ]] || return 1
  package="$destination/$CURRENT_FILESYSTEM_EVIDENCE"
  require_strict_containment "$package" "$destination/.csa-iem-recovery" "Filesystem evidence package" || return 1
  [[ -d "$package" && ! -L "$package" ]] || return 1
  prepare_git_fsmonitor_for_evidence "$source" || return 1
  result_file="$(mktemp "$TMP_ROOT/filesystem-evidence-verify.XXXXXX")" || return 1
  if ! filesystem_evidence_helper verify \
      "$source" "$destination" "$package" \
      "stage2-source" "$TRANSACTION_ID" "${CURRENT_VERIFIED_SLUG:-}" "$CURRENT_REPOSITORY_ID" \
      "$CURRENT_GITHUB_OWNER" "$CURRENT_GITHUB_LOGIN" "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST" \
      "$CURRENT_REPOSITORY_ROLE" "$CURRENT_PARENT_REPOSITORY" "$CURRENT_EXACT_GIT_REMOTE" \
      "$CURRENT_WIKI_REF_DIGEST" "$CURRENT_WIKI_DEFAULT_BRANCH" "$CURRENT_WIKI_HEAD_OID" \
      "$CURRENT_FILESYSTEM_BINDING_SOURCE" "$CURRENT_FILESYSTEM_EVIDENCE" \
      "$git_snapshot" "$git_snapshot_digest" "$git_ref_namespace" \
      "-" "-" "-" "-" \
      "$CURRENT_FILESYSTEM_MANIFEST_DIGEST" "$CURRENT_FILESYSTEM_EVIDENCE_DIGEST" \
      "$CURRENT_FILESYSTEM_BINDING_DIGEST" "$CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST" \
      "$CURRENT_FILESYSTEM_SOURCE_DEVICE" "$CURRENT_FILESYSTEM_SOURCE_INODE" \
      "$CURRENT_FILESYSTEM_EVIDENCE" > "$result_file"; then
    rm -f -- "$result_file"
    return 1
  fi
  while IFS='=' read -r key value; do
    case "$key" in
      evidence_digest) verified_evidence="$value" ;;
      manifest_digest) verified_manifest="$value" ;;
      binding_digest) verified_binding="$value" ;;
      source_tree_digest) verified_tree="$value" ;;
      source_device) verified_device="$value" ;;
      source_inode) verified_inode="$value" ;;
      destination_device|destination_owners_enabled|destination_volume_uuid|exact_categories|record_only_categories|source_path_hex|unsupported_categories) ;;
      *) rm -f -- "$result_file"; return 1 ;;
    esac
  done < "$result_file"
  rm -f -- "$result_file"
  [[ "$verified_evidence" == "$CURRENT_FILESYSTEM_EVIDENCE_DIGEST" &&
     "$verified_manifest" == "$CURRENT_FILESYSTEM_MANIFEST_DIGEST" &&
     "$verified_binding" == "$CURRENT_FILESYSTEM_BINDING_DIGEST" &&
     "$verified_tree" == "$CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST" &&
     "$verified_device" == "$CURRENT_FILESYSTEM_SOURCE_DEVICE" &&
     "$verified_inode" == "$CURRENT_FILESYSTEM_SOURCE_INODE" ]]
}

capture_stage2_filesystem_evidence() {
  local source="$1"
  local destination="$2"
  local slug="$3"
  local recovery_root="$destination/.csa-iem-recovery"
  local relative_package=".csa-iem-recovery/filesystem-evidence/v2/$TRANSACTION_ID/$slug/source"
  local package="$destination/$relative_package"
  local partial="$package.partial.$$"
  local result_file=""
  local git_snapshot="${CURRENT_GIT_SNAPSHOT:--}"
  local git_snapshot_digest="${CURRENT_GIT_SNAPSHOT_DIGEST:--}"
  local git_ref_namespace="${CURRENT_GIT_REF_NAMESPACE:--}"

  reset_current_filesystem_evidence
  valid_repository_slug "$slug" || return 1
  [[ -n "$CURRENT_REPOSITORY_ID" && -n "$CURRENT_GITHUB_OWNER" && -n "$CURRENT_GITHUB_LOGIN" &&
     -n "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST" && -n "$CURRENT_REPOSITORY_ROLE" &&
     -n "$CURRENT_PARENT_REPOSITORY" && -n "$CURRENT_EXACT_GIT_REMOTE" ]] || return 1
  require_strict_containment "$recovery_root" "$destination" "Canonical filesystem recovery root" || return 1
  [[ -d "$recovery_root" && ! -L "$recovery_root" ]] || return 1
  require_strict_containment "$package" "$recovery_root" "Filesystem evidence package" || return 1
  require_strict_containment "$partial" "$recovery_root" "Partial filesystem evidence package" || return 1
  [[ ! -e "$package" && ! -L "$package" && ! -e "$partial" && ! -L "$partial" ]] || return 1
  prepare_git_fsmonitor_for_evidence "$source" || return 1
  result_file="$(mktemp "$TMP_ROOT/filesystem-evidence-capture.XXXXXX")" || return 1
  if ! filesystem_evidence_helper capture \
      "$source" "$destination" "$partial" \
      "stage2-source" "$TRANSACTION_ID" "$slug" "$CURRENT_REPOSITORY_ID" \
      "$CURRENT_GITHUB_OWNER" "$CURRENT_GITHUB_LOGIN" "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST" \
      "$CURRENT_REPOSITORY_ROLE" "$CURRENT_PARENT_REPOSITORY" "$CURRENT_EXACT_GIT_REMOTE" \
      "$CURRENT_WIKI_REF_DIGEST" "$CURRENT_WIKI_DEFAULT_BRANCH" "$CURRENT_WIKI_HEAD_OID" \
      "$source" "$relative_package" \
      "$git_snapshot" "$git_snapshot_digest" "$git_ref_namespace" \
      "-" "-" "-" "-" > "$result_file"; then
    rm -rf -- "$partial"
    rm -f -- "$result_file"
    return 1
  fi
  if ! load_filesystem_evidence_result "$result_file"; then
    rm -rf -- "$partial"
    rm -f -- "$result_file"
    reset_current_filesystem_evidence
    return 1
  fi
  rm -f -- "$result_file"
  if ! mv -- "$partial" "$package"; then
    rm -rf -- "$partial"
    reset_current_filesystem_evidence
    return 1
  fi
  CURRENT_FILESYSTEM_EVIDENCE="$relative_package"
  CURRENT_FILESYSTEM_BINDING_SOURCE="$source"
  CURRENT_VERIFIED_SLUG="$slug"
  if ! verify_current_filesystem_evidence "$source" "$destination"; then
    warn "Final filesystem evidence package did not reverify for $slug. The package is retained for diagnosis but no cleanup receipt will be issued."
    reset_current_filesystem_evidence
    return 1
  fi
  return 0
}

# Keep this byte-for-byte compatible with Stage 3's tree-sha256-v1 contract.
# Each sorted row contains the entry type, mode, hex-encoded relative path,
# and file digest or symlink target. Owners and timestamps are intentionally
# outside the contract; every file byte and executable/permission mode is in it.
tree_digest() {
  local requested_root="$1"
  local root=""
  local entries_file=""
  local manifest_file=""
  local sorted_file=""
  local entry=""
  local relative=""
  local path_hex=""
  local target=""
  local target_hex=""
  local mode=""
  local file_digest=""
  local digest=""

  [[ -d "$requested_root" && ! -L "$requested_root" ]] || return 1
  root="$(canonical_path "$requested_root")" || return 1
  entries_file="$(mktemp "$TMP_ROOT/tree-entries.XXXXXX")" || return 1
  manifest_file="$(mktemp "$TMP_ROOT/tree-manifest.XXXXXX")" || {
    rm -f -- "$entries_file"
    return 1
  }
  sorted_file="$(mktemp "$TMP_ROOT/tree-sorted.XXXXXX")" || {
    rm -f -- "$entries_file" "$manifest_file"
    return 1
  }
  mode="$(permission_mode "$root")" || {
    rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
    return 1
  }
  printf 'D|%s|\n' "$mode" > "$manifest_file"
  if ! find "$root" -mindepth 1 -print0 > "$entries_file" 2>/dev/null; then
    rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
    return 1
  fi
  while IFS= read -r -d '' entry; do
    relative="${entry#"$root"/}"
    [[ "$relative" != "$entry" && -n "$relative" ]] || {
      rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
      return 1
    }
    path_hex="$(printf '%s' "$relative" | hex_encode)" || {
      rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
      return 1
    }
    if [[ -L "$entry" ]]; then
      target="$(readlink "$entry")" || {
        rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
        return 1
      }
      target_hex="$(printf '%s' "$target" | hex_encode)" || {
        rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
        return 1
      }
      printf 'L|0000|%s|%s\n' "$path_hex" "$target_hex" >> "$manifest_file"
    elif [[ -d "$entry" ]]; then
      mode="$(permission_mode "$entry")" || {
        rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
        return 1
      }
      printf 'D|%s|%s\n' "$mode" "$path_hex" >> "$manifest_file"
    elif [[ -f "$entry" ]]; then
      mode="$(permission_mode "$entry")" || {
        rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
        return 1
      }
      file_digest="$(shasum -a 256 "$entry" 2>/dev/null | awk 'NR == 1 { print $1 }')"
      valid_sha256_digest "$file_digest" || {
        rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
        return 1
      }
      printf 'F|%s|%s|%s\n' "$mode" "$path_hex" "$file_digest" >> "$manifest_file"
    else
      rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
      return 1
    fi
  done < "$entries_file"
  if ! LC_ALL=C sort "$manifest_file" > "$sorted_file"; then
    rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
    return 1
  fi
  digest="$(shasum -a 256 "$sorted_file" 2>/dev/null | awk 'NR == 1 { print $1 }')"
  rm -f -- "$entries_file" "$manifest_file" "$sorted_file"
  valid_sha256_digest "$digest" || return 1
  printf '%s' "$digest"
}

resolved_git_common_dir() {
  local repository="$1"
  local git_common_dir=""

  git_common_dir="$(isolated_git -C "$repository" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [[ -z "$git_common_dir" ]]; then
    git_common_dir="$(isolated_git -C "$repository" rev-parse --git-common-dir 2>/dev/null)" || return 1
    case "$git_common_dir" in
      /*) ;;
      *) git_common_dir="$repository/$git_common_dir" ;;
    esac
  fi
  canonical_path "$git_common_dir"
}

git_local_config_is_self_contained() {
  local config="$1"

  [[ -f "$config" && ! -L "$config" ]] || return 1
  isolated_git config --no-includes --file "$config" --get core.worktree >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.hooksPath >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.fsmonitor >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.attributesFile >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.excludesFile >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.alternateRefsCommand >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get lfs.storage >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get extensions.partialclone >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.sparseCheckout >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get core.sparseCheckoutCone >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get index.sparse >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get-regexp '^remote\..*\.promisor$' >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get-regexp '^(include|includeIf\..*)\.path$' >/dev/null 2>&1 && return 1
  return 0
}

git_admin_state_is_self_contained() {
  local repository="$1"
  local run_fsck="${2:-1}"
  local git_entry="$repository/.git"
  local expected_git_dir=""
  local resolved_git_dir=""
  local common_dir=""
  local resolved_objects_dir=""
  local resolved_index_path=""
  local top_level=""
  local superproject=""
  local config_worktree="$git_entry/config.worktree"
  local alternates=""
  local http_alternates=""
  local custom_lfs_storage=""
  local missing_file=""

  GIT_SAFETY_ERROR=""
  [[ "$run_fsck" == "0" || "$run_fsck" == "1" ]] || return 1
  [[ -d "$repository" && ! -L "$repository" && -d "$git_entry" && ! -L "$git_entry" ]] || {
    GIT_SAFETY_ERROR="Git administrative state is not a real in-worktree .git directory (linked worktrees, submodules, and symlinked .git paths are blocked)."
    return 1
  }
  expected_git_dir="$(canonical_path "$git_entry")" || {
    GIT_SAFETY_ERROR="The in-worktree .git directory could not be canonicalized."
    return 1
  }
  resolved_git_dir="$(isolated_git -C "$repository" rev-parse --absolute-git-dir 2>/dev/null)" || {
    GIT_SAFETY_ERROR="Git could not resolve its administrative directory."
    return 1
  }
  resolved_git_dir="$(canonical_path "$resolved_git_dir")" || return 1
  [[ "$resolved_git_dir" == "$expected_git_dir" ]] || {
    GIT_SAFETY_ERROR="Git resolves to an administrative directory outside the source .git tree."
    return 1
  }
  common_dir="$(resolved_git_common_dir "$repository")" || {
    GIT_SAFETY_ERROR="Git common-dir could not be resolved safely."
    return 1
  }
  [[ "$common_dir" == "$expected_git_dir" && ! -e "$git_entry/commondir" && ! -L "$git_entry/commondir" ]] || {
    GIT_SAFETY_ERROR="External or linked-worktree commondir dependencies are blocked until they are fully materialized into a standalone .git directory."
    return 1
  }
  [[ -d "$git_entry/objects" && ! -L "$git_entry/objects" ]] || {
    GIT_SAFETY_ERROR="Git objects must be a real directory inside the standalone .git tree."
    return 1
  }
  if [[ -n "$(find "$git_entry" -type l -print -quit 2>/dev/null)" ]]; then
    GIT_SAFETY_ERROR="Symlinked Git administrative entries are blocked because the snapshot must contain every administrative byte without external path dependencies."
    return 1
  fi
  if [[ -d "$git_entry/worktrees" && -n "$(find "$git_entry/worktrees" -mindepth 1 -print -quit 2>/dev/null)" ]] ||
     [[ -d "$git_entry/modules" && -n "$(find "$git_entry/modules" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    GIT_SAFETY_ERROR="Linked-worktree or submodule administrative stores are blocked because cleanup cannot yet prove their independent repository state."
    return 1
  fi
  alternates="$git_entry/objects/info/alternates"
  http_alternates="$git_entry/objects/info/http-alternates"
  if [[ -e "$alternates" || -L "$alternates" || -e "$http_alternates" || -L "$http_alternates" ]]; then
    GIT_SAFETY_ERROR="External Git object alternates are blocked until every dependency is materialized into the standalone source object database."
    return 1
  fi
  if [[ -n "$(find "$git_entry/objects" -type l -print -quit 2>/dev/null)" ]]; then
    GIT_SAFETY_ERROR="Symlinked Git object storage is blocked because its external bytes cannot be proven by the standalone .git snapshot."
    return 1
  fi
  resolved_objects_dir="$(isolated_git -C "$repository" rev-parse --git-path objects 2>/dev/null)" || {
    GIT_SAFETY_ERROR="Git object storage could not be resolved."
    return 1
  }
  case "$resolved_objects_dir" in /*) ;; *) resolved_objects_dir="$repository/$resolved_objects_dir" ;; esac
  resolved_objects_dir="$(canonical_path "$resolved_objects_dir")" || return 1
  [[ "$resolved_objects_dir" == "$expected_git_dir/objects" ]] || {
    GIT_SAFETY_ERROR="Git object storage resolves outside the standalone .git/objects directory."
    return 1
  }
  resolved_index_path="$(isolated_git -C "$repository" rev-parse --git-path index 2>/dev/null)" || {
    GIT_SAFETY_ERROR="Git index storage could not be resolved."
    return 1
  }
  case "$resolved_index_path" in /*) ;; *) resolved_index_path="$repository/$resolved_index_path" ;; esac
  [[ -f "$resolved_index_path" && ! -L "$resolved_index_path" ]] || {
    GIT_SAFETY_ERROR="Git index must be a real file inside the standalone .git directory."
    return 1
  }
  resolved_index_path="$(canonical_path "$resolved_index_path")" || return 1
  [[ "$resolved_index_path" == "$expected_git_dir/index" ]] || {
    GIT_SAFETY_ERROR="Git index storage resolves outside the standalone .git/index path."
    return 1
  }
  top_level="$(isolated_git -C "$repository" rev-parse --show-toplevel 2>/dev/null)" || return 1
  top_level="$(canonical_path "$top_level")" || return 1
  [[ "$top_level" == "$(canonical_path "$repository")" &&
     "$(isolated_git -C "$repository" rev-parse --is-inside-work-tree 2>/dev/null || true)" == "true" &&
     "$(isolated_git -C "$repository" rev-parse --is-bare-repository 2>/dev/null || true)" == "false" ]] || {
    GIT_SAFETY_ERROR="Git must resolve to this exact non-bare top-level worktree."
    return 1
  }
  superproject="$(isolated_git -C "$repository" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
  [[ -z "$superproject" ]] || {
    GIT_SAFETY_ERROR="Git submodule worktrees are blocked until their parent administrative dependency is materialized independently."
    return 1
  }
  if ! git_local_config_is_self_contained "$git_entry/config"; then
    GIT_SAFETY_ERROR="Local Git config contains an external worktree, hook, monitor, attributes, excludes, alternate-ref, partial-clone, or include dependency."
    return 1
  fi
  if [[ -e "$config_worktree" || -L "$config_worktree" ]] && ! git_local_config_is_self_contained "$config_worktree"; then
    GIT_SAFETY_ERROR="Worktree Git config contains an external or unsupported dependency."
    return 1
  fi
  custom_lfs_storage="$(isolated_git -C "$repository" config --local --path --get lfs.storage 2>/dev/null || true)"
  if [[ -L "$repository/.lfsconfig" ]] ||
     { [[ -f "$repository/.lfsconfig" ]] && isolated_git config --no-includes --file "$repository/.lfsconfig" --get lfs.storage >/dev/null 2>&1; } ||
     [[ -n "$custom_lfs_storage" ]]; then
    GIT_SAFETY_ERROR="Custom Git LFS storage is blocked until every LFS object is materialized under the standalone .git/lfs/objects tree."
    return 1
  fi
  if [[ -n "$(isolated_git -C "$repository" config --local --get extensions.partialClone 2>/dev/null || true)" ]] ||
     [[ -n "$(isolated_git -C "$repository" config --local --get-regexp '^remote\..*\.promisor$' 2>/dev/null || true)" ]] ||
     [[ -n "$(find "$git_entry/objects/pack" -maxdepth 1 -type f -name '*.promisor' -print -quit 2>/dev/null)" ]]; then
    GIT_SAFETY_ERROR="Partial/promisor Git object stores are blocked because Stage 2 cannot prove every reachable object is local without fetching."
    return 1
  fi
  missing_file="$(mktemp "$TMP_ROOT/git-missing-reachable.XXXXXX")" || return 1
  if ! isolated_git -C "$repository" rev-list --objects --all --missing=print > "$missing_file" 2>/dev/null; then
    rm -f -- "$missing_file"
    GIT_SAFETY_ERROR="Git reachable-object enumeration failed."
    return 1
  fi
  if grep -q '^?' "$missing_file"; then
    rm -f -- "$missing_file"
    GIT_SAFETY_ERROR="The source has promised or missing reachable Git objects that are not locally materialized."
    return 1
  fi
  rm -f -- "$missing_file"
  if [[ "$run_fsck" == "1" ]] &&
     ! isolated_git -c core.multiPackIndex=false -C "$repository" fsck --full --strict --no-dangling >/dev/null 2>&1; then
    GIT_SAFETY_ERROR="The standalone Git object database failed strict fsck."
    return 1
  fi
  return 0
}

git_index_and_operation_state_is_safe() {
  local repository="$1"
  local git_dir="$repository/.git"
  local marker=""
  local staged_status=0
  local stage_file=""
  local tag_file=""
  local fsmonitor_file=""
  local resolve_undo_file=""
  local record=""
  local metadata=""
  local index_mode=""
  local object_id=""
  local stage_number=""

  GIT_SAFETY_ERROR=""
  if [[ -n "$(find "$git_dir" -maxdepth 1 -type f \( -name 'sharedindex.*' -o -name 'sharedindex.*.lock' \) -print -quit 2>/dev/null)" ]]; then
    GIT_SAFETY_ERROR="Split-index administrative state is blocked until it is materialized as one plain index."
    return 1
  fi
  for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD REBASE_HEAD BISECT_LOG BISECT_START AUTO_MERGE rebase-apply rebase-merge sequencer index.lock; do
    if [[ -e "$git_dir/$marker" || -L "$git_dir/$marker" ]]; then
      GIT_SAFETY_ERROR="An ongoing Git operation marker is present: $marker"
      return 1
    fi
  done
  if [[ -n "$(isolated_git -C "$repository" ls-files -u 2>/dev/null || true)" ]]; then
    GIT_SAFETY_ERROR="The Git index contains unresolved conflict stages."
    return 1
  fi
  if isolated_git -C "$repository" diff --cached --quiet --no-ext-diff --no-textconv --ita-visible-in-index --ignore-submodules=none -- 2>/dev/null; then
    staged_status=0
  else
    staged_status=$?
  fi
  case "$staged_status" in
    0) ;;
    1)
      GIT_SAFETY_ERROR="The Git index contains staged state, including an intent-to-add entry."
      return 1
      ;;
    *)
      GIT_SAFETY_ERROR="The Git index could not be inspected with intent-to-add visibility."
      return 1
      ;;
  esac
  stage_file="$(mktemp "$TMP_ROOT/index-stage.XXXXXX")" || return 1
  tag_file="$(mktemp "$TMP_ROOT/index-tags.XXXXXX")" || {
    cleanup_verification_files "$stage_file"
    return 1
  }
  fsmonitor_file="$(mktemp "$TMP_ROOT/index-fsmonitor.XXXXXX")" || {
    cleanup_verification_files "$stage_file" "$tag_file"
    return 1
  }
  resolve_undo_file="$(mktemp "$TMP_ROOT/index-resolve-undo.XXXXXX")" || {
    cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file"
    return 1
  }
  if ! isolated_git -C "$repository" ls-files --stage -z > "$stage_file" 2>/dev/null; then
    cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
    GIT_SAFETY_ERROR="The Git index stage table could not be inspected."
    return 1
  fi
  while IFS= read -r -d '' record; do
    [[ "$record" == *$'\t'* ]] || {
      cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
      GIT_SAFETY_ERROR="The Git index contains an unparseable stage entry."
      return 1
    }
    metadata="${record%%$'\t'*}"
    set -- $metadata
    index_mode="${1:-}"
    object_id="${2:-}"
    stage_number="${3:-}"
    if [[ "$#" -ne 3 || "$index_mode" == "040000" || "$stage_number" != "0" || -z "$object_id" || -z "${object_id//0/}" ]]; then
      cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
      GIT_SAFETY_ERROR="The Git index contains conflict-stage, sparse-directory, or intent-to-add state."
      return 1
    fi
  done < "$stage_file"
  if ! isolated_git -C "$repository" ls-files -v -z > "$tag_file" 2>/dev/null; then
    cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
    return 1
  fi
  while IFS= read -r -d '' record; do
    case "$record" in
      H\ *) ;;
      *)
        cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
        GIT_SAFETY_ERROR="The Git index contains assume-unchanged or skip-worktree state."
        return 1
        ;;
    esac
  done < "$tag_file"
  if ! isolated_git -C "$repository" ls-files -f -z > "$fsmonitor_file" 2>/dev/null; then
    cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
    return 1
  fi
  while IFS= read -r -d '' record; do
    case "$record" in
      H\ *) ;;
      *)
        cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
        GIT_SAFETY_ERROR="The Git index contains fsmonitor-valid state."
        return 1
        ;;
    esac
  done < "$fsmonitor_file"
  if ! isolated_git -C "$repository" ls-files --resolve-undo -z > "$resolve_undo_file" 2>/dev/null || [[ -s "$resolve_undo_file" ]]; then
    cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
    GIT_SAFETY_ERROR="The Git index contains resolve-undo state or could not be inspected completely."
    return 1
  fi
  cleanup_verification_files "$stage_file" "$tag_file" "$fsmonitor_file" "$resolve_undo_file"
  return 0
}

copy_tree_preserving_bytes() {
  local source="$1"
  local destination="$2"

  [[ -d "$source" && ! -L "$source" ]] || return 1
  [[ ! -e "$destination" && ! -L "$destination" ]] || return 1
  mkdir -p -- "$(dirname -- "$destination")" || return 1
  if [[ "$(uname -s)" == "Darwin" ]]; then
    COPYFILE_DISABLE=0 /usr/bin/ditto "$source" "$destination"
  else
    mkdir -- "$destination" || return 1
    rsync -a "$source/" "$destination/"
  fi
}

snapshot_source_git_admin_state() {
  local source="$1"
  local destination="$2"
  local slug="$3"
  local recovery_root="$destination/.csa-iem-recovery"
  local relative_snapshot=".csa-iem-recovery/git-snapshots/$TRANSACTION_ID/$slug/source.git"
  local snapshot="$destination/$relative_snapshot"
  local partial_snapshot="$destination/$relative_snapshot.partial.$$"
  local source_digest_before=""
  local source_digest_after=""
  local snapshot_digest=""

  valid_repository_slug "$slug" || return 1
  require_strict_containment "$recovery_root" "$destination" "Canonical recovery root" || return 1
  if [[ -e "$recovery_root" || -L "$recovery_root" ]]; then
    [[ -d "$recovery_root" && ! -L "$recovery_root" ]] || {
      warn "Canonical recovery root is not a real directory: $recovery_root"
      return 1
    }
  else
    mkdir -- "$recovery_root" || return 1
  fi
  recovery_root="$(canonical_path "$recovery_root")" || return 1
  require_strict_containment "$snapshot" "$recovery_root" "Full Git snapshot" || return 1
  require_strict_containment "$partial_snapshot" "$recovery_root" "Partial full Git snapshot" || return 1
  [[ ! -e "$snapshot" && ! -L "$snapshot" ]] || {
    warn "Full Git snapshot already exists: $snapshot"
    return 1
  }
  [[ ! -e "$partial_snapshot" && ! -L "$partial_snapshot" ]] || return 1
  source_digest_before="$(tree_digest "$source/.git")" || return 1
  if ! copy_tree_preserving_bytes "$source/.git" "$partial_snapshot"; then
    rm -rf -- "$partial_snapshot"
    return 1
  fi
  source_digest_after="$(tree_digest "$source/.git")" || {
    rm -rf -- "$partial_snapshot"
    return 1
  }
  snapshot_digest="$(tree_digest "$partial_snapshot")" || {
    rm -rf -- "$partial_snapshot"
    return 1
  }
  if [[ "$source_digest_before" != "$source_digest_after" || "$source_digest_after" != "$snapshot_digest" ]]; then
    warn "Source Git administrative state changed during its full snapshot: $source"
    rm -rf -- "$partial_snapshot"
    return 1
  fi
  if ! mv -- "$partial_snapshot" "$snapshot"; then
    rm -rf -- "$partial_snapshot"
    return 1
  fi
  CURRENT_GIT_SNAPSHOT="$relative_snapshot"
  CURRENT_GIT_SNAPSHOT_DIGEST="$snapshot_digest"
  CURRENT_GIT_REF_NAMESPACE="$(git_ref_namespace_for_slug "$slug")" || return 1
  return 0
}

enumerate_all_local_git_objects() {
  local repository="$1"
  local output="$2"
  local object_id=""

  if ! isolated_git -C "$repository" cat-file --batch-all-objects --batch-check='%(objectname)' 2>/dev/null | LC_ALL=C sort -u > "$output"; then
    return 1
  fi
  while IFS= read -r object_id; do
    [[ -n "$object_id" ]] || continue
    valid_git_object_id "$object_id" || return 1
  done < "$output"
}

import_all_local_git_objects() {
  local source="$1"
  local destination="$2"
  local objects_file=""
  local object_id=""

  objects_file="$(mktemp "$TMP_ROOT/git-all-objects.XXXXXX")" || return 1
  if ! enumerate_all_local_git_objects "$source" "$objects_file"; then
    cleanup_verification_files "$objects_file"
    return 1
  fi
  if [[ -s "$objects_file" ]]; then
    if ! isolated_git -C "$source" pack-objects --stdout < "$objects_file" |
         isolated_git -C "$destination" index-pack --stdin >/dev/null; then
      cleanup_verification_files "$objects_file"
      return 1
    fi
  fi
  while IFS= read -r object_id; do
    [[ -n "$object_id" ]] || continue
    if ! isolated_git -C "$destination" cat-file -e "$object_id^{object}" 2>/dev/null; then
      cleanup_verification_files "$objects_file"
      return 1
    fi
  done < "$objects_file"
  cleanup_verification_files "$objects_file"
  return 0
}

copy_regular_file_create_only() {
  local source="$1"
  local destination="$2"
  local temporary=""

  [[ -f "$source" && ! -L "$source" ]] || return 1
  mkdir -p -- "$(dirname -- "$destination")" || return 1
  if [[ -e "$destination" || -L "$destination" ]]; then
    [[ -f "$destination" && ! -L "$destination" ]] || return 1
    cmp -s "$source" "$destination"
    return
  fi
  temporary="$(mktemp "$(dirname -- "$destination")/.csa-iem-lfs.XXXXXX")" || return 1
  if ! cp -p "$source" "$temporary" || ! cmp -s "$source" "$temporary"; then
    rm -f -- "$temporary"
    return 1
  fi
  if ! ln "$temporary" "$destination" 2>/dev/null; then
    if [[ ! -f "$destination" || -L "$destination" ]] || ! cmp -s "$source" "$destination"; then
      rm -f -- "$temporary"
      return 1
    fi
  fi
  rm -f -- "$temporary"
  [[ -f "$destination" && ! -L "$destination" ]] && cmp -s "$source" "$destination"
}

import_all_local_lfs_bytes() {
  local source="$1"
  local destination="$2"
  local source_lfs="$source/.git/lfs/objects"
  local destination_lfs="$destination/.git/lfs/objects"
  local entries_file=""
  local source_entry=""
  local relative=""

  if [[ ! -e "$source_lfs" && ! -L "$source_lfs" ]]; then
    return 0
  fi
  [[ -d "$source_lfs" && ! -L "$source_lfs" ]] || return 1
  [[ ! -L "$destination_lfs" ]] || return 1
  require_strict_containment "$source_lfs" "$source/.git" "Source Git LFS object storage" || return 1
  require_strict_containment "$destination_lfs" "$destination/.git" "Canonical Git LFS object storage" || return 1
  entries_file="$(mktemp "$TMP_ROOT/git-lfs-import.XXXXXX")" || return 1
  if ! find "$source_lfs" -mindepth 1 -print0 > "$entries_file" 2>/dev/null; then
    cleanup_verification_files "$entries_file"
    return 1
  fi
  while IFS= read -r -d '' source_entry; do
    if [[ -d "$source_entry" && ! -L "$source_entry" ]]; then
      continue
    fi
    [[ -f "$source_entry" && ! -L "$source_entry" ]] || {
      cleanup_verification_files "$entries_file"
      return 1
    }
    relative="${source_entry#"$source_lfs"/}"
    [[ "$relative" != "$source_entry" && -n "$relative" ]] || {
      cleanup_verification_files "$entries_file"
      return 1
    }
    if ! copy_regular_file_create_only "$source_entry" "$destination_lfs/$relative"; then
      cleanup_verification_files "$entries_file"
      return 1
    fi
  done < "$entries_file"
  cleanup_verification_files "$entries_file"
  return 0
}

install_namespaced_source_refs() {
  local source="$1"
  local destination="$2"
  local namespace="$3"
  local refs_file=""
  local updates_file=""
  local object_id=""
  local ref_name=""
  local ref_suffix=""
  local target_ref=""
  local source_head=""
  local source_head_ref=""

  isolated_git check-ref-format "$namespace/probe" >/dev/null 2>&1 || return 1
  source_head_ref="$(git_head_recovery_ref_for_namespace "$namespace")" || return 1
  refs_file="$(mktemp "$TMP_ROOT/git-source-refs.XXXXXX")" || return 1
  updates_file="$(mktemp "$TMP_ROOT/git-ref-updates.XXXXXX")" || {
    cleanup_verification_files "$refs_file"
    return 1
  }
  if ! isolated_git -C "$source" for-each-ref --format='%(objectname)%09%(refname)' > "$refs_file" 2>/dev/null; then
    cleanup_verification_files "$refs_file" "$updates_file"
    return 1
  fi
  source_head="$(isolated_git -C "$source" rev-parse --verify HEAD 2>/dev/null || true)"
  if [[ -n "$source_head" ]]; then
    valid_git_object_id "$source_head" || {
      cleanup_verification_files "$refs_file" "$updates_file"
      return 1
    }
    printf 'create %s %s\n' "$source_head_ref" "$source_head" >> "$updates_file"
  fi
  while IFS=$'\t' read -r object_id ref_name; do
    [[ -n "$object_id" && -n "$ref_name" ]] || continue
    valid_git_object_id "$object_id" || {
      cleanup_verification_files "$refs_file" "$updates_file"
      return 1
    }
    case "$ref_name" in refs/*) ;; *) cleanup_verification_files "$refs_file" "$updates_file"; return 1 ;; esac
    # Stage 3 maps refs/heads/main to <namespace>/heads/main. The full original
    # ref spelling remains byte-preserved in the administrative snapshot.
    ref_suffix="${ref_name#refs/}"
    [[ -n "$ref_suffix" && "$ref_suffix" != "$ref_name" ]] || {
      cleanup_verification_files "$refs_file" "$updates_file"
      return 1
    }
    target_ref="$namespace/$ref_suffix"
    isolated_git check-ref-format "$target_ref" >/dev/null 2>&1 || {
      cleanup_verification_files "$refs_file" "$updates_file"
      return 1
    }
    printf 'create %s %s\n' "$target_ref" "$object_id" >> "$updates_file"
  done < "$refs_file"
  if [[ -s "$updates_file" ]] && ! isolated_git -C "$destination" update-ref --stdin < "$updates_file"; then
    cleanup_verification_files "$refs_file" "$updates_file"
    return 1
  fi
  cleanup_verification_files "$refs_file" "$updates_file"
  return 0
}

verify_git_snapshot_current() {
  local source="$1"
  local destination="$2"
  local snapshot=""
  local source_digest=""
  local snapshot_digest=""

  [[ -n "$CURRENT_GIT_SNAPSHOT" && -n "$CURRENT_GIT_SNAPSHOT_DIGEST" ]] || return 1
  snapshot="$destination/$CURRENT_GIT_SNAPSHOT"
  require_strict_containment "$snapshot" "$destination/.csa-iem-recovery" "Full Git snapshot verification" || return 1
  [[ -d "$snapshot" && ! -L "$snapshot" ]] || return 1
  source_digest="$(tree_digest "$source/.git")" || return 1
  snapshot_digest="$(tree_digest "$snapshot")" || return 1
  [[ "$source_digest" == "$CURRENT_GIT_SNAPSHOT_DIGEST" &&
     "$snapshot_digest" == "$CURRENT_GIT_SNAPSHOT_DIGEST" ]]
}

prepare_git_preservation() {
  local source="$1"
  local destination="$2"
  local slug="$3"
  local already_revalidated="${4:-0}"
  local run_fsck="1"

  CURRENT_GIT_SNAPSHOT=""
  CURRENT_GIT_SNAPSHOT_DIGEST=""
  CURRENT_GIT_REF_NAMESPACE=""
  if [[ ! -d "$source/.git" && ! -f "$source/.git" ]]; then
    return 0
  fi
  prepare_git_fsmonitor_for_evidence "$source" || return 1
  prepare_git_fsmonitor_for_evidence "$destination" || return 1
  [[ "$already_revalidated" == "0" || "$already_revalidated" == "1" ]] || return 1
  [[ "$already_revalidated" == "1" ]] && run_fsck="0"
  if ! git_admin_state_is_self_contained "$source" "$run_fsck"; then
    warn "$GIT_SAFETY_ERROR Source: $source"
    return 1
  fi
  if ! git_index_and_operation_state_is_safe "$source"; then
    warn "$GIT_SAFETY_ERROR Source: $source"
    return 1
  fi
  if ! git_admin_state_is_self_contained "$destination" "$run_fsck"; then
    warn "$GIT_SAFETY_ERROR Canonical destination: $destination"
    return 1
  fi
  if ! git_index_and_operation_state_is_safe "$destination"; then
    warn "$GIT_SAFETY_ERROR Canonical destination: $destination"
    return 1
  fi
  snapshot_source_git_admin_state "$source" "$destination" "$slug" || return 1
  import_all_local_git_objects "$source" "$destination" || return 1
  import_all_local_lfs_bytes "$source" "$destination" || return 1
  install_namespaced_source_refs "$source" "$destination" "$CURRENT_GIT_REF_NAMESPACE" || return 1
  return 0
}

repository_git_path() {
  local repository="$1"
  local git_relative_path="$2"
  local resolved=""

  resolved="$(isolated_git -C "$repository" rev-parse --git-path "$git_relative_path" 2>/dev/null)" || return 1
  case "$resolved" in
    /*) canonical_path "$resolved" ;;
    *) canonical_path "$repository/$resolved" ;;
  esac
}

verify_lfs_objects_represented() {
  local source="$1"
  local destination="$2"
  local source_lfs=""
  local destination_lfs=""
  local entries_file=""
  local source_object=""
  local destination_object=""
  local relative=""

  source_lfs="$(repository_git_path "$source" "lfs/objects")" || {
    warn "Source Git LFS object path could not be resolved: $source"
    return 1
  }
  destination_lfs="$(repository_git_path "$destination" "lfs/objects")" || {
    warn "Canonical Git LFS object path could not be resolved: $destination"
    return 1
  }
  if path_is_within "$destination_lfs" "$source_lfs" || path_is_within "$source_lfs" "$destination_lfs"; then
    warn "Canonical Git LFS storage is not independent from the source: $destination_lfs"
    return 1
  fi
  if [[ ! -e "$source_lfs" && ! -L "$source_lfs" ]]; then
    return 0
  fi
  [[ -d "$source_lfs" ]] || {
    warn "Source Git LFS object path is not a readable directory: $source_lfs"
    return 1
  }

  entries_file="$(mktemp "$TMP_ROOT/source-lfs-entries.XXXXXX")" || return 1
  if ! find "$source_lfs" -mindepth 1 -print0 > "$entries_file" 2>/dev/null; then
    warn "Source Git LFS objects could not be enumerated: $source_lfs"
    cleanup_verification_files "$entries_file"
    return 1
  fi
  while IFS= read -r -d '' source_object; do
    if [[ -d "$source_object" && ! -L "$source_object" ]]; then
      continue
    fi
    if [[ ! -f "$source_object" || -L "$source_object" ]]; then
      warn "Source Git LFS storage contains an unsupported non-regular object entry: $source_object"
      cleanup_verification_files "$entries_file"
      return 1
    fi
    relative="${source_object#"$source_lfs"/}"
    destination_object="$destination_lfs/$relative"
    if [[ ! -f "$destination_object" || -L "$destination_object" ]]; then
      warn "Canonical Git LFS storage is missing source object: $relative"
      cleanup_verification_files "$entries_file"
      return 1
    fi
    if ! cmp -s "$source_object" "$destination_object"; then
      warn "Canonical Git LFS object differs byte-for-byte from source: $relative"
      cleanup_verification_files "$entries_file"
      return 1
    fi
  done < "$entries_file"
  cleanup_verification_files "$entries_file"
  return 0
}

final_destination_git_fsck_once() {
  local destination="$1"
  local key=""
  local marker=""
  local current_digest=""
  local recorded_digest=""

  [[ -n "$CURRENT_REPOSITORY_ID" && ( "$CURRENT_REPOSITORY_ROLE" == "repository" || "$CURRENT_REPOSITORY_ROLE" == "wiki" ) ]] || return 1
  key="$(printf '%s|%s|%s' "$destination" "$CURRENT_REPOSITORY_ID" "$CURRENT_REPOSITORY_ROLE" | shasum -a 256 | awk 'NR == 1 { print $1 }')"
  valid_sha256_digest "$key" || return 1
  marker="$TMP_ROOT/final-destination-fsck-$key"
  current_digest="$(tree_digest "$destination/.git")" || return 1
  if [[ -f "$marker" && ! -L "$marker" ]]; then
    recorded_digest="$(awk 'NR == 1 { print $1; exit }' "$marker")"
    [[ "$recorded_digest" == "$current_digest" ]]
    return
  fi
  isolated_git -c core.multiPackIndex=false -C "$destination" fsck --full --strict --no-dangling >/dev/null 2>&1 || return 1
  printf '%s\n' "$current_digest" > "$marker"
}

executable_permission_bits() {
  local path="$1"
  local mode=""

  if [[ "$(uname -s)" == "Darwin" ]]; then
    mode="$(stat -f '%Lp' "$path" 2>/dev/null)" || return 1
  else
    mode="$(stat -c '%a' "$path" 2>/dev/null)" || return 1
  fi
  case "$mode" in
    ""|*[!0-7]*) return 1 ;;
  esac
  printf '%03o' "$((8#$mode & 0111))"
}

verify_filesystem_metadata_represented() {
  local source="$1"
  local destination="$2"
  local entries_file=""
  local source_link_file=""
  local destination_link_file=""
  local source_path=""
  local destination_path=""
  local relative=""
  local source_exec=""
  local destination_exec=""

  entries_file="$(mktemp "$TMP_ROOT/source-representation-entries.XXXXXX")" || return 1
  source_link_file="$(mktemp "$TMP_ROOT/source-link-target.XXXXXX")" || {
    cleanup_verification_files "$entries_file"
    return 1
  }
  destination_link_file="$(mktemp "$TMP_ROOT/destination-link-target.XXXXXX")" || {
    cleanup_verification_files "$entries_file" "$source_link_file"
    return 1
  }
  if ! find "$source" -path "$source/.git" -prune -o -print0 > "$entries_file" 2>/dev/null; then
    warn "Source filesystem metadata could not be enumerated: $source"
    cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
    return 1
  fi

  while IFS= read -r -d '' source_path; do
    if [[ "$source_path" == "$source" ]]; then
      relative="."
      destination_path="$destination"
    else
      relative="${source_path#"$source"/}"
      destination_path="$destination/$relative"
    fi

    if [[ -L "$source_path" ]]; then
      if [[ ! -L "$destination_path" ]]; then
        warn "Canonical representation is missing source symlink: $relative"
        cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
        return 1
      fi
      if ! readlink "$source_path" > "$source_link_file" 2>/dev/null ||
         ! readlink "$destination_path" > "$destination_link_file" 2>/dev/null ||
         ! cmp -s "$source_link_file" "$destination_link_file"; then
        warn "Canonical symlink target differs from source: $relative"
        cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
        return 1
      fi
      continue
    fi

    if [[ -d "$source_path" ]]; then
      if [[ ! -d "$destination_path" || -L "$destination_path" ]]; then
        warn "Canonical representation has the wrong type for source directory: $relative"
        cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
        return 1
      fi
    elif [[ -f "$source_path" ]]; then
      if [[ ! -f "$destination_path" || -L "$destination_path" ]]; then
        warn "Canonical representation has the wrong type for source file: $relative"
        cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
        return 1
      fi
    else
      warn "Source contains an unsupported filesystem entry: $relative"
      cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
      return 1
    fi

    source_exec="$(executable_permission_bits "$source_path")" || {
      warn "Source executable permission bits could not be read: $relative"
      cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
      return 1
    }
    destination_exec="$(executable_permission_bits "$destination_path")" || {
      warn "Canonical executable permission bits could not be read: $relative"
      cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
      return 1
    }
    if [[ "$source_exec" != "$destination_exec" ]]; then
      warn "Canonical executable permission bits differ from source: $relative (source $source_exec, destination $destination_exec)"
      cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
      return 1
    fi
  done < "$entries_file"

  cleanup_verification_files "$entries_file" "$source_link_file" "$destination_link_file"
  return 0
}

verify_git_objects_represented() {
  local source="$1"
  local destination="$2"
  local source_head=""
  local source_remote=""
  local destination_remote=""
  local object_id=""
  local ref_name=""
  local ref_suffix=""
  local namespaced_ref=""
  local namespaced_object_id=""
  local source_head_ref=""
  local refs_file=""
  local objects_file=""

  if [[ ! -d "$source/.git" && ! -f "$source/.git" ]]; then
    return 0
  fi
  [[ -d "$destination/.git" && ! -L "$destination/.git" ]] || return 1
  if ! git_admin_state_is_self_contained "$source" "0"; then
    warn "$GIT_SAFETY_ERROR Source: $source"
    return 1
  fi
  if ! git_index_and_operation_state_is_safe "$source"; then
    warn "$GIT_SAFETY_ERROR Source: $source"
    return 1
  fi
  if ! git_admin_state_is_self_contained "$destination" "0"; then
    warn "$GIT_SAFETY_ERROR Canonical destination: $destination"
    return 1
  fi
  if ! git_index_and_operation_state_is_safe "$destination"; then
    warn "$GIT_SAFETY_ERROR Canonical destination: $destination"
    return 1
  fi
  # The source received its one strict fsck during immediate apply
  # revalidation. Its byte-exact administrative snapshot and all-object
  # enumeration are rechecked below without repeating that expensive fsck.
  [[ -n "$CURRENT_GIT_REF_NAMESPACE" ]] || return 1
  isolated_git check-ref-format "$CURRENT_GIT_REF_NAMESPACE/probe" >/dev/null 2>&1 || return 1
  source_head="$(isolated_git -C "$source" rev-parse --verify HEAD 2>/dev/null || true)"
  valid_git_object_id "$source_head" || return 1
  isolated_git -C "$destination" cat-file -e "$source_head^{commit}" 2>/dev/null || return 1
  source_remote="$(normalize_remote_slug "$(isolated_git -C "$source" config --no-includes --local --get remote.origin.url 2>/dev/null || true)" 2>/dev/null || true)"
  destination_remote="$(normalize_remote_slug "$(isolated_git -C "$destination" config --no-includes --local --get remote.origin.url 2>/dev/null || true)" 2>/dev/null || true)"
  if [[ -n "$source_remote" ]]; then
    [[ -n "$destination_remote" ]] || return 1
    if [[ "$(printf '%s' "$source_remote" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$destination_remote" | tr '[:upper:]' '[:lower:]')" ]]; then
      return 1
    fi
  fi
  refs_file="$(mktemp "$TMP_ROOT/source-refs.XXXXXX")" || return 1
  objects_file="$(mktemp "$TMP_ROOT/source-objects.XXXXXX")" || {
    cleanup_verification_files "$refs_file"
    return 1
  }
  if ! isolated_git -C "$source" for-each-ref --format='%(objectname)%09%(refname)' > "$refs_file" 2>/dev/null; then
    warn "Source Git ref enumeration failed: $source"
    cleanup_verification_files "$refs_file" "$objects_file"
    return 1
  fi
  source_head_ref="$(git_head_recovery_ref_for_namespace "$CURRENT_GIT_REF_NAMESPACE")" || {
    cleanup_verification_files "$refs_file" "$objects_file"
    return 1
  }
  namespaced_object_id="$(isolated_git -C "$destination" rev-parse --verify "$source_head_ref^{object}" 2>/dev/null || true)"
  if [[ "$namespaced_object_id" != "$source_head" ]]; then
    warn "Canonical Git recovery ref does not preserve source HEAD exactly: $source_head_ref"
    cleanup_verification_files "$refs_file" "$objects_file"
    return 1
  fi
  while IFS=$'\t' read -r object_id ref_name; do
    [[ -n "$object_id" ]] || continue
    if ! valid_git_object_id "$object_id" || [[ "$ref_name" != refs/* ]] ||
       ! isolated_git -C "$destination" cat-file -e "$object_id^{object}" 2>/dev/null; then
      warn "Canonical Git repository is missing or cannot validate source ref $ref_name ($object_id)."
      cleanup_verification_files "$refs_file" "$objects_file"
      return 1
    fi
    ref_suffix="${ref_name#refs/}"
    namespaced_ref="$CURRENT_GIT_REF_NAMESPACE/$ref_suffix"
    isolated_git check-ref-format "$namespaced_ref" >/dev/null 2>&1 || {
      cleanup_verification_files "$refs_file" "$objects_file"
      return 1
    }
    namespaced_object_id="$(isolated_git -C "$destination" rev-parse --verify "$namespaced_ref^{object}" 2>/dev/null || true)"
    if [[ "$namespaced_object_id" != "$object_id" ]]; then
      warn "Canonical Git recovery ref differs from source: $ref_name (source $object_id, recovery $namespaced_object_id)"
      cleanup_verification_files "$refs_file" "$objects_file"
      return 1
    fi
  done < "$refs_file"
  if ! enumerate_all_local_git_objects "$source" "$objects_file"; then
    warn "Source Git all-object enumeration failed: $source"
    cleanup_verification_files "$refs_file" "$objects_file"
    return 1
  fi
  while IFS= read -r object_id; do
    [[ -n "$object_id" ]] || continue
    if ! isolated_git -C "$destination" cat-file -e "$object_id^{object}" 2>/dev/null; then
      warn "Canonical Git repository is missing a source-local reachable or unreachable object: $object_id"
      cleanup_verification_files "$refs_file" "$objects_file"
      return 1
    fi
  done < "$objects_file"
  cleanup_verification_files "$refs_file" "$objects_file"
  if ! verify_lfs_objects_represented "$source" "$destination"; then
    return 1
  fi
  if ! final_destination_git_fsck_once "$destination"; then
    warn "Canonical Git object database failed fsck: $destination"
    return 1
  fi
  if ! verify_git_snapshot_current "$source" "$destination"; then
    warn "The live source .git tree changed during final Git preservation verification."
    return 1
  fi
  return 0
}

verify_source_deletions_represented() {
  local source="$1"
  local destination="$2"
  local deleted_file=""
  local relative=""
  local destination_path=""

  if [[ ! -d "$source/.git" ]]; then
    return 0
  fi
  deleted_file="$(mktemp "$TMP_ROOT/source-unstaged-deletions.XXXXXX")" || return 1
  if ! isolated_git -C "$source" diff --name-only -z --no-ext-diff --no-textconv --diff-filter=D --no-renames --ignore-submodules=none -- > "$deleted_file" 2>/dev/null; then
    cleanup_verification_files "$deleted_file"
    return 1
  fi
  while IFS= read -r -d '' relative; do
    case "$relative" in
      ""|/*|../*|*/../*|*/..) cleanup_verification_files "$deleted_file"; return 1 ;;
    esac
    destination_path="$destination/$relative"
    if [[ -e "$destination_path" || -L "$destination_path" ]]; then
      warn "An unstaged source deletion cannot be represented by an additive merge: $relative"
      cleanup_verification_files "$deleted_file"
      return 1
    fi
  done < "$deleted_file"
  cleanup_verification_files "$deleted_file"
  return 0
}

verify_source_represented() {
  local source="$1"
  local destination="$2"
  local archive="${3:-}"
  local differences=""
  local rsync_bin=""

  CURRENT_VERIFIED_SOURCE=""
  CURRENT_VERIFIED_DESTINATION=""
  CURRENT_VERIFIED_ARCHIVE=""
  [[ -d "$source" && -d "$destination" ]] || return 1
  require_strict_containment "$destination" "$CODE_REPOS" "Canonical destination" || return 1
  rsync_bin="$(command -v rsync)"
  if ! differences="$(COPYFILE_DISABLE=1 "$rsync_bin" -rclni --no-owner --no-group --no-perms --exclude='.git/' "$source/" "$destination/" 2>&1)"; then
    warn "Checksum representation check failed for $(basename "$source"): $differences"
    return 1
  fi
  # Git checkout/fast-forward and APFS clone-copy can legitimately normalize
  # mtimes while preserving the file bytes. With checksum mode enabled, a
  # pure timestamp-only itemized row is not a content mismatch and must not
  # block a no-ZIP verified transfer.
  differences="$(printf '%s\n' "$differences" | sed -e '/^[[:space:]]*$/d' -e '/^sending incremental file list$/d' -e '/^receiving incremental file list$/d' | awk '$1 !~ /^\.[^[:space:]]\.\.T\.\.\.\.$/ { print }')"
  if [[ -n "$differences" ]]; then
    warn "Canonical verification found source data that is not represented at $destination. A ZIP cannot satisfy this check."
    printf '%s\n' "$differences" | sed -n '1,40p' >&2
    return 1
  fi
  if ! verify_filesystem_metadata_represented "$source" "$destination"; then
    warn "Canonical filesystem metadata verification failed. Symlink targets and executable permission bits must match; a ZIP cannot satisfy this check."
    return 1
  fi
  if ! verify_source_deletions_represented "$source" "$destination"; then
    warn "Canonical verification did not represent every unstaged source deletion."
    return 1
  fi
  if ! verify_git_objects_represented "$source" "$destination"; then
    warn "Canonical Git verification did not preserve every source ref/object. A ZIP cannot satisfy this check."
    return 1
  fi
  if [[ -n "$CURRENT_FILESYSTEM_EVIDENCE" ]] &&
     ! verify_current_filesystem_evidence "$source" "$destination"; then
    warn "Receipt-bound filesystem manifest, metadata sidecars, or active/recovery representatives failed final verification."
    return 1
  fi
  if [[ -n "$archive" ]] && ! verified_zip "$archive"; then
    warn "The optional Stage 2 ZIP failed its independent integrity test: $archive"
    return 1
  fi
  CURRENT_VERIFIED_SOURCE="$source"
  CURRENT_VERIFIED_DESTINATION="$destination"
  CURRENT_VERIFIED_ARCHIVE="$archive"
  return 0
}

write_stage2_receipt() {
  local status="$1"
  local slug="$2"
  local original_source="$3"
  local current_source="$4"
  local destination="$5"
  local archive="$6"
  local quarantine="$7"
  local detail="$8"
  local receipt="$RECEIPTS_DIR/$slug.receipt"
  local receipt_temp=""
  local value=""
  local cleanup_eligible=0
  local git_verification="not-applicable"
  local lfs_verification="not-applicable"
  local source_is_git=0
  local expected_git_snapshot=""
  local expected_git_ref_namespace=""
  local expected_filesystem_evidence=".csa-iem-recovery/filesystem-evidence/v2/$TRANSACTION_ID/$slug/source"

  for value in "$status" "$slug" "$original_source" "$current_source" "$destination" "$archive" "$quarantine" "$detail" \
    "$CURRENT_GIT_SNAPSHOT" "$CURRENT_GIT_SNAPSHOT_DIGEST" "$CURRENT_GIT_REF_NAMESPACE" \
    "$CURRENT_REPOSITORY_ID" "$CURRENT_FILESYSTEM_EVIDENCE" "$CURRENT_FILESYSTEM_EVIDENCE_DIGEST" \
    "$CURRENT_FILESYSTEM_MANIFEST_DIGEST" "$CURRENT_FILESYSTEM_BINDING_DIGEST" \
    "$CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST" "$CURRENT_FILESYSTEM_SOURCE_PATH_HEX" \
    "$CURRENT_FILESYSTEM_SOURCE_DEVICE" "$CURRENT_FILESYSTEM_SOURCE_INODE" \
    "$CURRENT_FILESYSTEM_EXACT_CATEGORIES" "$CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES" \
    "$CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES" "$CURRENT_FILESYSTEM_DESTINATION_DEVICE" \
    "$CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID" "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" \
    "$CURRENT_REPOSITORY_ROLE" "$CURRENT_PARENT_REPOSITORY" "$CURRENT_EXACT_GIT_REMOTE" \
    "$CURRENT_WIKI_REF_DIGEST" "$CURRENT_WIKI_DEFAULT_BRANCH" "$CURRENT_WIKI_HEAD_OID" \
    "$CURRENT_GITHUB_OWNER" "$CURRENT_GITHUB_LOGIN" "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST"; do
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || return 1
  done
  valid_repository_slug "$slug" || return 1
  require_strict_containment "$receipt" "$RECEIPTS_DIR" "Stage 2 receipt" || return 1
  case "$status" in
    verified-source-kept|source-retired) cleanup_eligible=1 ;;
  esac
  if [[ -n "$original_source" && ( -d "$original_source/.git" || -f "$original_source/.git" ) ]]; then
    source_is_git=1
  elif [[ -n "$current_source" && ( -d "$current_source/.git" || -f "$current_source/.git" ) ]]; then
    source_is_git=1
  fi
  if [[ "$source_is_git" -eq 1 ]]; then
    expected_git_snapshot=".csa-iem-recovery/git-snapshots/$TRANSACTION_ID/$slug/source.git"
    expected_git_ref_namespace="$(git_ref_namespace_for_slug "$slug")" || return 1
    [[ -n "$CURRENT_GIT_SNAPSHOT" && -n "$CURRENT_GIT_SNAPSHOT_DIGEST" && -n "$CURRENT_GIT_REF_NAMESPACE" ]] || return 1
    [[ "$CURRENT_GIT_SNAPSHOT" == "$expected_git_snapshot" &&
       "$CURRENT_GIT_REF_NAMESPACE" == "$expected_git_ref_namespace" ]] || return 1
    valid_sha256_digest "$CURRENT_GIT_SNAPSHOT_DIGEST" || return 1
    isolated_git check-ref-format "$CURRENT_GIT_REF_NAMESPACE/probe" >/dev/null 2>&1 || return 1
    require_strict_containment "$destination/$CURRENT_GIT_SNAPSHOT" "$destination/.csa-iem-recovery" "Receipt Git snapshot" || return 1
    [[ -d "$destination/$CURRENT_GIT_SNAPSHOT" && ! -L "$destination/$CURRENT_GIT_SNAPSHOT" ]] || return 1
    git_verification="full-admin-snapshot-all-local-objects-lfs-namespaced-refs"
    lfs_verification="byte-identical-local-objects"
  elif [[ -n "$CURRENT_GIT_SNAPSHOT" || -n "$CURRENT_GIT_SNAPSHOT_DIGEST" || -n "$CURRENT_GIT_REF_NAMESPACE" ]]; then
    return 1
  elif [[ "$cleanup_eligible" -eq 1 ]]; then
    # A filesystem-only project remains preserved at its source. Cleanup is
    # never authorized without the required canonical Git snapshot contract.
    cleanup_eligible=0
  fi
  [[ -n "$CURRENT_REPOSITORY_ID" && "$CURRENT_VERIFIED_SLUG" == "$slug" &&
     "$CURRENT_FILESYSTEM_BINDING_SOURCE" == "$original_source" &&
     "$CURRENT_FILESYSTEM_EVIDENCE" == "$expected_filesystem_evidence" ]] || return 1
  [[ "$CURRENT_GITHUB_OWNER" == "${slug%%/*}" && "$CURRENT_EXACT_GIT_REMOTE" == "https://$GITHUB_HOST/$slug.git" &&
     "$CURRENT_GITHUB_LOGIN" == "$(github_login_for_owner "$CURRENT_GITHUB_OWNER")" &&
     "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST" == "$(github_account_binding_digest "$CURRENT_GITHUB_OWNER" "$CURRENT_GITHUB_LOGIN")" &&
     ( "$CURRENT_REPOSITORY_ROLE" == "repository" || "$CURRENT_REPOSITORY_ROLE" == "wiki" ) ]] || return 1
  valid_repository_slug "$CURRENT_PARENT_REPOSITORY" || return 1
  if [[ "$CURRENT_REPOSITORY_ROLE" == "wiki" ]]; then
    is_wiki_slug "$slug" && [[ "$CURRENT_PARENT_REPOSITORY.wiki" == "$slug" ]] &&
      valid_sha256_digest "$CURRENT_WIKI_REF_DIGEST" && valid_git_object_id "$CURRENT_WIKI_HEAD_OID" &&
      [[ -n "$CURRENT_WIKI_DEFAULT_BRANCH" ]] || return 1
  else
    is_wiki_slug "$slug" && return 1
    [[ "$CURRENT_PARENT_REPOSITORY" == "$slug" && "$CURRENT_WIKI_REF_DIGEST" == "-" &&
       "$CURRENT_WIKI_DEFAULT_BRANCH" == "-" && "$CURRENT_WIKI_HEAD_OID" == "-" ]] || return 1
  fi
  valid_sha256_digest "$CURRENT_FILESYSTEM_EVIDENCE_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_FILESYSTEM_MANIFEST_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_FILESYSTEM_BINDING_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST" || return 1
  [[ -n "$CURRENT_FILESYSTEM_SOURCE_PATH_HEX" && "$CURRENT_FILESYSTEM_SOURCE_PATH_HEX" != *[!0-9a-f]* &&
     "$CURRENT_FILESYSTEM_SOURCE_DEVICE" != *[!0-9]* &&
     "$CURRENT_FILESYSTEM_SOURCE_INODE" != *[!0-9]* &&
     -n "$CURRENT_FILESYSTEM_EXACT_CATEGORIES" && -n "$CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES" &&
     -n "$CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES" &&
     "$CURRENT_FILESYSTEM_DESTINATION_DEVICE" != *[!0-9]* &&
     -n "$CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID" &&
     ( "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "true" ||
       "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "false" ||
       "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "unknown" ) ]] || return 1
  require_strict_containment "$destination/$CURRENT_FILESYSTEM_EVIDENCE" "$destination/.csa-iem-recovery" "Receipt filesystem evidence" || return 1
  [[ -d "$destination/$CURRENT_FILESYSTEM_EVIDENCE" && ! -L "$destination/$CURRENT_FILESYSTEM_EVIDENCE" ]] || return 1
  if [[ "$cleanup_eligible" -eq 1 ]]; then
    [[ "$CURRENT_VERIFIED_SOURCE" == "$current_source" &&
       "$CURRENT_VERIFIED_DESTINATION" == "$destination" &&
       "$CURRENT_VERIFIED_ARCHIVE" == "$archive" ]] || return 1
  fi
  mkdir -p "$(dirname "$receipt")"
  receipt_temp="$(mktemp "$(dirname "$receipt")/.stage2-receipt.XXXXXX")" || return 1
  if ! {
    printf 'format=3\n'
    printf 'stage=2\n'
    printf 'status=%s\n' "$status"
    printf 'transaction=%s\n' "$TRANSACTION_ID"
    printf 'repository=%s\n' "$slug"
    printf 'identity_contract=github-owner-account-role-v1\n'
    printf 'github_host=%s\n' "$GITHUB_HOST"
    printf 'github_owner=%s\n' "$CURRENT_GITHUB_OWNER"
    printf 'github_login=%s\n' "$CURRENT_GITHUB_LOGIN"
    printf 'github_account_binding_schema=owner-login-v1\n'
    printf 'github_account_binding_digest=%s\n' "$CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST"
    printf 'repository_role=%s\n' "$CURRENT_REPOSITORY_ROLE"
    printf 'parent_repository=%s\n' "$CURRENT_PARENT_REPOSITORY"
    printf 'parent_repository_id=%s\n' "$CURRENT_REPOSITORY_ID"
    printf 'exact_git_remote=%s\n' "$CURRENT_EXACT_GIT_REMOTE"
    printf 'wiki_ref_digest=%s\n' "$CURRENT_WIKI_REF_DIGEST"
    printf 'wiki_default_branch=%s\n' "$CURRENT_WIKI_DEFAULT_BRANCH"
    printf 'wiki_head_oid=%s\n' "$CURRENT_WIKI_HEAD_OID"
    printf 'source_root=%s\n' "$SOURCE_ROOT"
    printf 'original_source=%s\n' "$original_source"
    printf 'current_source=%s\n' "$current_source"
    printf 'destination=%s\n' "$destination"
    printf 'archive=%s\n' "$archive"
    printf 'quarantine=%s\n' "$quarantine"
    printf 'import_stage=%s\n' "$IMPORT_STAGE"
    printf 'managed_temp=%s\n' "$MANAGED_TEMP"
    printf 'report=%s\n' "$REPORT_PATH"
    printf 'content_verification=full-checksum\n'
    printf 'filesystem_metadata_verification=complete-manifest-with-explicit-record-only\n'
    printf 'filesystem_evidence_schema=csa-iem-filesystem-evidence-v2\n'
    printf 'filesystem_evidence_version=2\n'
    printf 'filesystem_evidence_status=final-verified\n'
    printf 'filesystem_evidence=%s\n' "$CURRENT_FILESYSTEM_EVIDENCE"
    printf 'filesystem_evidence_digest=%s\n' "$CURRENT_FILESYSTEM_EVIDENCE_DIGEST"
    printf 'filesystem_manifest=%s/manifest.jsonl\n' "$CURRENT_FILESYSTEM_EVIDENCE"
    printf 'filesystem_manifest_digest=%s\n' "$CURRENT_FILESYSTEM_MANIFEST_DIGEST"
    printf 'filesystem_binding=%s/binding.json\n' "$CURRENT_FILESYSTEM_EVIDENCE"
    printf 'filesystem_binding_digest=%s\n' "$CURRENT_FILESYSTEM_BINDING_DIGEST"
    printf 'filesystem_source_tree_digest=%s\n' "$CURRENT_FILESYSTEM_SOURCE_TREE_DIGEST"
    printf 'filesystem_source_path_hex=%s\n' "$CURRENT_FILESYSTEM_SOURCE_PATH_HEX"
    printf 'filesystem_source_device=%s\n' "$CURRENT_FILESYSTEM_SOURCE_DEVICE"
    printf 'filesystem_source_inode=%s\n' "$CURRENT_FILESYSTEM_SOURCE_INODE"
    printf 'filesystem_exact_categories=%s\n' "$CURRENT_FILESYSTEM_EXACT_CATEGORIES"
    printf 'filesystem_record_only_categories=%s\n' "$CURRENT_FILESYSTEM_RECORD_ONLY_CATEGORIES"
    printf 'filesystem_unsupported_categories=%s\n' "$CURRENT_FILESYSTEM_UNSUPPORTED_CATEGORIES"
    printf 'filesystem_destination_device=%s\n' "$CURRENT_FILESYSTEM_DESTINATION_DEVICE"
    printf 'filesystem_destination_volume_uuid=%s\n' "$CURRENT_FILESYSTEM_DESTINATION_VOLUME_UUID"
    printf 'filesystem_destination_owners_enabled=%s\n' "$CURRENT_FILESYSTEM_DESTINATION_OWNERS_ENABLED"
    printf 'repository_id=%s\n' "$CURRENT_REPOSITORY_ID"
    printf 'git_verification=%s\n' "$git_verification"
    printf 'lfs_verification=%s\n' "$lfs_verification"
    printf 'git_snapshot=%s\n' "$CURRENT_GIT_SNAPSHOT"
    printf 'git_snapshot_digest=%s\n' "$CURRENT_GIT_SNAPSHOT_DIGEST"
    printf 'git_ref_namespace=%s\n' "$CURRENT_GIT_REF_NAMESPACE"
    printf 'zip_authoritative=0\n'
    printf 'cleanup_owner=stage3\n'
    printf 'stage3_cleanup_eligible=%s\n' "$cleanup_eligible"
    printf 'final_stage2_proof=manifest-representatives-and-git-snapshot-verified\n'
    printf 'verified_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'detail=%s\n' "$detail"
  } > "$receipt_temp"; then
    rm -f -- "$receipt_temp"
    return 1
  fi
  if ! mv -f -- "$receipt_temp" "$receipt"; then
    rm -f -- "$receipt_temp"
    return 1
  fi
  printf '%s' "$receipt"
}

device_id() {
  local path="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%d' "$path" 2>/dev/null
  else
    stat -c '%d' "$path" 2>/dev/null
  fi
}

retire_stage1_source() {
  local source="$1"
  local destination="$2"
  local slug="$3"
  local archive="$4"
  local completed_root="$MANAGED_TEMP/Stage2-Completed/$TRANSACTION_ID"
  local target="$completed_root/$slug"
  local source_device=""
  local target_device=""

  valid_repository_slug "$slug" || return 1
  require_strict_containment "$source" "$SOURCE_ROOT" "Stage 1 retirement source" || return 1
  require_strict_containment "$destination" "$CODE_REPOS" "Canonical destination" || return 1
  require_strict_containment "$target" "$MANAGED_TEMP" "Managed Stage 2 retirement target" || return 1
  [[ -d "$source" && ! -L "$source" ]] || {
    warn "Stage 1 retirement requires a real source directory, not a symlink: $source"
    return 1
  }
  [[ ! -e "$target" && ! -L "$target" ]] || {
    warn "Managed Stage 2 retirement target already exists; source was retained: $target"
    return 1
  }
  mkdir -p -- "$(dirname "$target")" || return 1
  source_device="$(device_id "$source")" || return 1
  target_device="$(device_id "$(dirname "$target")")" || return 1
  if [[ "$source_device" != "$target_device" ]]; then
    warn "Stage 2 retirement requires an atomic same-volume move; source was retained."
    return 1
  fi
  if ! verify_source_represented "$source" "$destination" "$archive"; then
    warn "Stage 2 retirement pre-verification failed; source was retained: $source"
    return 1
  fi
  if ! write_stage2_receipt "retire-pending" "$slug" "$source" "$source" "$destination" "$archive" "$target" "Canonical checksum/Git verification passed; an atomic same-volume move to managed _temp is pending." >/dev/null; then
    warn "Stage 2 retirement pending receipt could not be written; source was retained."
    return 1
  fi
  if ! mv -- "$source" "$target"; then
    warn "Atomic Stage 2 retirement move failed; source was retained."
    return 1
  fi
  if ! verify_source_represented "$target" "$destination" "$archive"; then
    if mv -- "$target" "$source" 2>/dev/null; then
      write_stage2_receipt "retire-rolled-back" "$slug" "$source" "$source" "$destination" "$archive" "$target" "Post-move verification failed; the source was restored to its original Stage 1 path." >/dev/null || true
    else
      write_stage2_receipt "retire-verification-failed" "$slug" "$source" "$target" "$destination" "$archive" "$target" "Post-move verification failed and automatic rollback also failed; no data was deleted." >/dev/null || true
    fi
    return 1
  fi
  if ! write_stage2_receipt "source-retired" "$slug" "$source" "$target" "$destination" "$archive" "$target" "The fully verified Stage 1 input was atomically moved to managed _temp; only Stage 3 may permanently clean it." >/dev/null; then
    if mv -- "$target" "$source" 2>/dev/null; then
      write_stage2_receipt "retire-rolled-back" "$slug" "$source" "$source" "$destination" "$archive" "$target" "Final retirement receipt failed; the source was restored to its original Stage 1 path." >/dev/null || true
    else
      write_stage2_receipt "retire-receipt-failed" "$slug" "$source" "$target" "$destination" "$archive" "$target" "Final retirement receipt failed and automatic rollback also failed; no data was deleted." >/dev/null || true
    fi
    return 1
  fi
  RETIRED_SOURCE_PATH="$target"
  info "Retired Stage 1 source to $target"
}

delete_stage1_source() {
  warn "Stage 2 permanent source deletion is disabled. Stage 3 owns receipt-linked cleanup."
  return 1
}

open_managed_project() {
  local path="$1"
  [[ -n "$OPEN_WITH" ]] || return 0
  case "$OPEN_WITH" in
    codex) open -a Codex "$path" >/dev/null 2>&1 || warn "Codex could not open $path" ;;
    code)
      if command -v code >/dev/null 2>&1; then code "$path" >/dev/null 2>&1 & else open -a "Visual Studio Code" "$path" >/dev/null 2>&1 || warn "Visual Studio Code could not open $path"; fi
      ;;
    copilot) open -a "GitHub Copilot" "$path" >/dev/null 2>&1 || warn "GitHub Copilot could not open $path" ;;
    finder) open "$path" >/dev/null 2>&1 || true ;;
    devcontainer)
      if command -v devcontainer >/dev/null 2>&1; then
        devcontainer up --workspace-folder "$path"
      else
        warn "devcontainer CLI is unavailable; skipped $path"
      fi
      ;;
  esac
}

remove_stage_path() {
  local path="$1"
  require_strict_containment "$path" "$IMPORT_STAGE" "Stage 2 transaction path" || return 1
  rm -rf -- "$path"
}

remove_import_transaction() {
  local stage2_root="$IMPORT_ROOT"
  local expected="$stage2_root/$TRANSACTION_ID"
  local canonical_import=""
  local canonical_expected=""

  require_strict_containment "$IMPORT_STAGE" "$stage2_root" "Stage 2 import transaction" || return 1
  canonical_import="$(canonical_path "$IMPORT_STAGE")" || return 1
  canonical_expected="$(canonical_path "$expected")" || return 1
  [[ "$canonical_import" == "$canonical_expected" && "$(basename -- "$canonical_import")" == "$TRANSACTION_ID" ]] || return 1
  rm -rf -- "$canonical_import"
}

validate_actionable_plan_paths() {
  local state slug source destination source_head destination_head remote_head source_status destination_status default_branch repo_exists detail

  while IFS=$'\t' read -r state slug source destination source_head destination_head remote_head source_status destination_status default_branch repo_exists detail; do
    [[ -n "$state" ]] || continue
    case "$state" in
      ready-new-private-repo|ready-new-canonical|ready-additive-heal|ready-fast-forward|ready-destination-newer) ;;
      *) return 1 ;;
    esac
    valid_repository_slug "$slug" || return 1
    require_strict_containment "$source" "$SOURCE_ROOT" "Planned Stage 1 source" || return 1
    require_strict_containment "$destination" "$CODE_REPOS" "Planned canonical destination" || return 1
    [[ -d "$source" ]] || return 1
  done < "$PLAN_FILE"
}

revalidate_actionable_git_state() {
  local state="$1"
  local source="$2"
  local destination="$3"
  local planned_source_head="$4"
  local planned_destination_head="$5"
  local source_git source_branch source_head source_upstream source_staged source_unstaged source_untracked source_remote_slug source_remote_url
  local destination_git destination_branch destination_head destination_upstream destination_staged destination_unstaged destination_untracked destination_remote_slug destination_remote_url

  if [[ -d "$source/.git" || -f "$source/.git" ]]; then
    prepare_git_fsmonitor_for_evidence "$source" || return 1
    git_admin_state_is_self_contained "$source" || return 1
    git_index_and_operation_state_is_safe "$source" || return 1
    IFS='|' read -r source_git source_branch source_head source_upstream source_staged source_unstaged source_untracked source_remote_slug source_remote_url <<< "$(git_snapshot "$source")"
    [[ "$source_git" -eq 1 && -n "$planned_source_head" && "$source_head" == "$planned_source_head" ]] || return 1
  else
    [[ -z "$planned_source_head" ]] || return 1
    source_remote_slug=""
  fi

  case "$state" in
    ready-new-canonical|ready-new-private-repo)
      [[ ! -e "$destination" && ! -L "$destination" ]] || return 1
      ;;
    *)
      prepare_git_fsmonitor_for_evidence "$destination" || return 1
      git_admin_state_is_self_contained "$destination" "0" || return 1
      git_index_and_operation_state_is_safe "$destination" || return 1
      IFS='|' read -r destination_git destination_branch destination_head destination_upstream destination_staged destination_unstaged destination_untracked destination_remote_slug destination_remote_url <<< "$(git_snapshot "$destination")"
      [[ "$destination_git" -eq 1 && "$destination_head" == "$planned_destination_head" ]] || return 1
      [[ "$destination_staged" -eq 0 && "$destination_unstaged" -eq 0 && "$destination_untracked" -eq 0 ]] || return 1
      if [[ -n "$source_remote_slug" ]]; then
        [[ -n "$destination_remote_slug" && "$source_remote_slug" == "$destination_remote_slug" ]] || return 1
      fi
      ;;
  esac
  return 0
}

apply_plan() {
  local total=""
  local actionable=0
  local blockers=0
  local index=0
  local applied=0
  local skipped=0
  local failed=0
  local state slug source destination source_head destination_head remote_head source_status destination_status default_branch repo_exists detail
  local stage_path=""
  local archive_path=""
  local receipt_path=""

  total="$(awk 'NF { count++ } END { print count+0 }' "$PLAN_FILE")"
  actionable="$(awk -F '\t' '$1 == "ready-new-private-repo" || $1 == "ready-new-canonical" || $1 == "ready-additive-heal" || $1 == "ready-fast-forward" || $1 == "ready-destination-newer" { count++ } END { print count+0 }' "$PLAN_FILE")"
  blockers=$((total - actionable))
  if [[ "$total" -eq 0 || "$blockers" -gt 0 ]]; then
    skipped="$total"
    printf '%s\n' "$applied" > "$TMP_ROOT/applied-count"
    printf '%s\n' "$skipped" > "$TMP_ROOT/skipped-count"
    printf '%s\n' "$failed" > "$TMP_ROOT/failed-count"
    warn "Stage 2 apply blocked before mutation: $blockers blocking/non-actionable plan row(s)."
    return 1
  fi
  if ! validate_actionable_plan_paths; then
    failed=1
    skipped="$total"
    printf '%s\n' "$applied" > "$TMP_ROOT/applied-count"
    printf '%s\n' "$skipped" > "$TMP_ROOT/skipped-count"
    printf '%s\n' "$failed" > "$TMP_ROOT/failed-count"
    warn "Stage 2 apply blocked before mutation because a planned path or repository identity failed canonical validation."
    return 1
  fi
  mkdir -p -- "$IMPORT_STAGE" || {
    printf '0\n' > "$TMP_ROOT/applied-count"
    printf '%s\n' "$total" > "$TMP_ROOT/skipped-count"
    printf '1\n' > "$TMP_ROOT/failed-count"
    return 1
  }

  while IFS=$'\t' read -r state slug source destination source_head destination_head remote_head source_status destination_status default_branch repo_exists detail; do
    [[ -n "$state" ]] || continue
    index=$((index + 1))
    printf 'PROGRESS | %s/%s | %s | %s\n' "$index" "$total" "$state" "$slug"
    CURRENT_GIT_SNAPSHOT=""
    CURRENT_GIT_SNAPSHOT_DIGEST=""
    CURRENT_GIT_REF_NAMESPACE=""
    CURRENT_REPOSITORY_ID=""
    CURRENT_REPOSITORY_ROLE=""
    CURRENT_PARENT_REPOSITORY=""
    CURRENT_EXACT_GIT_REMOTE=""
    CURRENT_WIKI_REF_DIGEST=""
    CURRENT_WIKI_DEFAULT_BRANCH=""
    CURRENT_WIKI_HEAD_OID=""
    CURRENT_GITHUB_OWNER=""
    CURRENT_GITHUB_LOGIN=""
    CURRENT_GITHUB_ACCOUNT_BINDING_DIGEST=""
    reset_current_filesystem_evidence
    CURRENT_VERIFIED_SOURCE=""
    CURRENT_VERIFIED_DESTINATION=""
    CURRENT_VERIFIED_ARCHIVE=""
    if ! revalidate_actionable_git_state "$state" "$source" "$destination" "$source_head" "$destination_head"; then
      warn "Source or canonical Git state changed after preflight; blocked before applying $slug. ${GIT_SAFETY_ERROR:-}"
      failed=$((failed + 1))
      continue
    fi
    if [[ "$state" == "ready-new-canonical" || "$state" == "ready-new-private-repo" ]]; then
      stage_path="$IMPORT_STAGE/code/$slug"
      if ! require_strict_containment "$stage_path" "$IMPORT_STAGE" "Stage 2 repository staging path" ||
         ! require_strict_containment "$destination" "$CODE_REPOS" "Canonical destination" ||
         ! mkdir -p -- "$(dirname "$stage_path")" "$(dirname "$destination")"; then
        warn "Canonical path validation or directory preparation failed for $slug"
        failed=$((failed + 1))
        continue
      fi
      if ! copy_complete_project "$source" "$stage_path"; then
        warn "Staging copy failed for $slug"
        failed=$((failed + 1))
        continue
      fi
      if ! verify_complete_project "$source" "$stage_path"; then
        warn "Staging verification failed for $slug"
        remove_stage_path "$stage_path" || true
        failed=$((failed + 1))
        continue
      fi
      if [[ "$state" == "ready-new-private-repo" ]]; then
        if ! create_missing_repository "$slug"; then
          warn "Repository creation failed for $slug"
          remove_stage_path "$stage_path" || true
          failed=$((failed + 1))
          continue
        fi
        if ! attach_origin_if_needed "$stage_path" "$slug"; then
          warn "Attaching the canonical Git origin failed for $slug"
          remove_stage_path "$stage_path" || true
          failed=$((failed + 1))
          continue
        fi
      fi
      if [[ -e "$destination" || -L "$destination" ]]; then
        warn "Canonical destination appeared during the transaction; skipped $slug"
        remove_stage_path "$stage_path" || true
        failed=$((failed + 1))
        continue
      fi
      if ! mv -- "$stage_path" "$destination"; then
        warn "Canonical promotion failed for $slug"
        failed=$((failed + 1))
        continue
      fi
      if ! safe_remote_fast_forward "$destination" "$default_branch" "$remote_head"; then
        warn "Canonical remote fast-forward failed for $slug"
        failed=$((failed + 1))
        continue
      fi
    elif [[ "$state" == "ready-fast-forward" ]]; then
      if ! "$GIT_BIN" -c core.hooksPath=/dev/null -C "$destination" fetch "$source" "$source_head" >/dev/null 2>&1 ||
         ! "$GIT_BIN" -c core.hooksPath=/dev/null -C "$destination" merge --ff-only --no-verify FETCH_HEAD >/dev/null 2>&1; then
        warn "Local fast-forward failed for $slug; canonical files were not additively merged."
        failed=$((failed + 1))
        continue
      fi
      if ! additive_heal "$source" "$destination" || ! safe_remote_fast_forward "$destination" "$default_branch" "$remote_head"; then
        warn "Canonical additive verification preparation failed for $slug"
        failed=$((failed + 1))
        continue
      fi
    else
      if ! additive_heal "$source" "$destination" || ! safe_remote_fast_forward "$destination" "$default_branch" "$remote_head"; then
        warn "Canonical additive verification preparation failed for $slug"
        failed=$((failed + 1))
        continue
      fi
    fi

    if ! bind_current_repository_identity "$slug"; then
      warn "GitHub owner/account, repository role/ID/casing, or exact wiki refs could not be rebound immediately before final evidence for $slug."
      failed=$((failed + 1))
      continue
    fi

    if ! prepare_git_preservation "$source" "$destination" "$slug" "1"; then
      warn "Full Git administrative snapshot/object/LFS/ref preservation failed for $slug; the Stage 1 source was retained."
      failed=$((failed + 1))
      continue
    fi

    archive_path=""
    if [[ "$CREATE_ARCHIVE" -eq 1 ]]; then
      if ! archive_path="$(create_stage2_archive "$source" "$slug")"; then
        warn "Verified ZIP creation failed for $slug; the Stage 1 source was retained."
        failed=$((failed + 1))
        continue
      fi
      info "Verified Stage 2 source archive: $archive_path"
    fi
    if ! verify_source_represented "$source" "$destination" "$archive_path"; then
      warn "Final canonical verification failed for $slug; the Stage 1 source was retained."
      failed=$((failed + 1))
      continue
    fi
    if ! capture_stage2_filesystem_evidence "$source" "$destination" "$slug"; then
      warn "Complete filesystem/file-info/access evidence capture failed for $slug; no cleanup-eligible receipt was written."
      failed=$((failed + 1))
      continue
    fi
    if ! receipt_path="$(write_stage2_receipt "verified-source-kept" "$slug" "$source" "$source" "$destination" "$archive_path" "" "Canonical and optional archive verification passed.")"; then
      warn "A verification receipt could not be written for $slug; cleanup was blocked."
      failed=$((failed + 1))
      continue
    fi
    info "Stage 2 receipt: $receipt_path"

    if [[ "$PREPARE_RUNTIME" -eq 1 ]]; then
      if ! prepare_runtime_mirror "$destination" "$slug"; then
        warn "Runtime preparation did not complete for $slug; the Stage 1 source was retained."
        failed=$((failed + 1))
        continue
      fi
    fi
    if [[ "$RETIRE_SOURCES" -eq 1 ]]; then
      RETIRED_SOURCE_PATH=""
      if ! retire_stage1_source "$source" "$destination" "$slug" "$archive_path"; then
        warn "Verified Stage 1 retirement failed safely for $slug; no permanent deletion was attempted."
        failed=$((failed + 1))
        continue
      fi
    fi
    open_managed_project "$destination"
    applied=$((applied + 1))
  done < "$PLAN_FILE"

  if [[ "$CLEANUP_TRANSACTION_TEMP" -eq 1 ]]; then
    if [[ "$failed" -eq 0 && "$applied" -eq "$actionable" ]] && remove_import_transaction; then
      info "Removed verified Stage 2 transaction data: $IMPORT_STAGE"
    else
      warn "Stage 2 transaction data was retained because at least one apply failed."
    fi
  fi

  printf '%s\n' "$applied" > "$TMP_ROOT/applied-count"
  printf '%s\n' "$skipped" > "$TMP_ROOT/skipped-count"
  printf '%s\n' "$failed" > "$TMP_ROOT/failed-count"
  [[ "$failed" -eq 0 && "$applied" -eq "$actionable" ]]
}

write_report() {
  local action_label="$1"
  local total ready blocked needs applied skipped failed
  local state slug source destination source_head destination_head remote_head source_status destination_status default_branch repo_exists detail
  local archive_label="disabled"
  local retention_label="keep"
  local cleanup_label="disabled"

  total="$(awk 'NF { count++ } END { print count+0 }' "$PLAN_FILE")"
  ready="$(awk -F '\t' '$1 ~ /^ready-/ { count++ } END { print count+0 }' "$PLAN_FILE")"
  blocked="$(awk -F '\t' '$1 ~ /^blocked-/ { count++ } END { print count+0 }' "$PLAN_FILE")"
  needs="$(awk -F '\t' '$1 ~ /^needs-/ { count++ } END { print count+0 }' "$PLAN_FILE")"
  applied="$(cat "$TMP_ROOT/applied-count" 2>/dev/null || printf '0')"
  skipped="$(cat "$TMP_ROOT/skipped-count" 2>/dev/null || printf '0')"
  failed="$(cat "$TMP_ROOT/failed-count" 2>/dev/null || printf '0')"
  [[ "$CREATE_ARCHIVE" -eq 1 ]] && archive_label="enabled"
  if [[ "$RETIRE_SOURCES" -eq 1 ]]; then
    retention_label="retire-to-managed-temp"
  fi
  [[ "$CLEANUP_TRANSACTION_TEMP" -eq 1 ]] && cleanup_label="enabled"

  mkdir -p "$(dirname "$REPORT_PATH")"
  {
    printf '# CSA-iEM Stage 2 Report\n\n'
    printf -- '- Transaction: `%s`\n' "$TRANSACTION_ID"
    printf -- '- Action: `%s`\n' "$action_label"
    printf -- '- GitHub host/account: `%s` / `%s`\n' "$GITHUB_HOST" "${ACCOUNT:-not authenticated}"
    printf -- '- Stage 1 source: `%s`\n' "$SOURCE_ROOT"
    printf -- '- Managed root: `%s`\n' "$MANAGED_ROOT"
    printf -- '- Managed temp (preserved): `%s`\n' "$MANAGED_TEMP"
    printf -- '- Canonical code root: `%s`\n' "$CODE_REPOS"
    printf -- '- Plans: %s total, %s ready, %s blocked, %s needing a repository\n' "$total" "$ready" "$blocked" "$needs"
    printf -- '- Execution: %s applied, %s skipped, %s failed\n\n' "$applied" "$skipped" "$failed"
    printf -- '- Verified ZIP archives: `%s`\n' "$archive_label"
    printf -- '- Stage 1 retention: `%s`\n' "$retention_label"
    printf -- '- Current transaction cleanup: `%s`\n\n' "$cleanup_label"
    printf '| State | Repository | Source | Destination | Source status | Destination status | Detail |\n'
    printf '|---|---|---|---|---|---|---|\n'
    while IFS=$'\t' read -r state slug source destination source_head destination_head remote_head source_status destination_status default_branch repo_exists detail; do
      printf '| %s | `%s` | `%s` | `%s` | %s | %s | %s |\n' "$state" "$slug" "$source" "$destination" "$source_status" "$destination_status" "$detail"
    done < "$PLAN_FILE"
    printf '\n## Safety Rules\n\n'
    printf -- '- The active `%s` project is excluded.\n' "$APP_REPOSITORY"
    printf -- '- Canonical folders use the verified cased GitHub `owner/repository`; basename-only and cross-owner matches are blocked.\n'
    printf -- '- Existing dirty, staged, divergent, ambiguous, archived, or identity-conflicting destinations are never overwritten.\n'
    printf -- '- Source conflicts, ongoing Git operations, staged/intent-to-add entries, special index flags, and external Git administrative dependencies are blocked.\n'
    printf -- '- Ordinary source unstaged and untracked files proceed only when additive healing and a full-checksum/metadata proof represent them without overwriting canonical files.\n'
    printf -- '- Existing clean destinations receive Git fast-forwards only when ancestry is proven; newer canonical refs are never downgraded.\n'
    printf -- '- Every Git source receives a full administrative snapshot plus create-only object/LFS import and transaction-namespaced source refs before a cleanup-eligible receipt exists.\n'
    printf -- '- Every source receives a receipt-bound filesystem-evidence-v2 package with byte-safe paths, exact active/recovery representatives, ACL/xattr sidecars, and explicit record-only ownership/time/allocation fields.\n'
    printf -- '- New GitHub repositories are empty and `%s`; Stage 2 does not upload project files.\n' "$REPO_VISIBILITY"
    printf -- '- Stage 1 folders remain in place unless `--retire-sources` atomically moves a twice-verified source into managed `_temp`.\n'
    printf -- '- Stage 2 never permanently deletes source inputs; receipt-linked permanent cleanup belongs exclusively to Stage 3.\n'
    printf -- '- A verified ZIP is supplemental and cannot substitute for canonical checksum or Git-object verification.\n'
    printf -- '- Any blocker aborts the entire apply before repository, staging, or source mutations begin.\n'
  } > "$REPORT_PATH"

  info "Stage 2 report: $REPORT_PATH"
  printf 'SUMMARY | total=%s ready=%s blocked=%s needs_repo=%s applied=%s skipped=%s failed=%s\n' "$total" "$ready" "$blocked" "$needs" "$applied" "$skipped" "$failed"
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help|-h) usage; exit 0 ;;
      --source) shift; [[ "$#" -gt 0 ]] || die "--source requires a path"; SOURCE_ROOT="$1" ;;
      --source=*) SOURCE_ROOT="${1#*=}" ;;
      --managed-root|--root) shift; [[ "$#" -gt 0 ]] || die "--managed-root requires a path"; MANAGED_ROOT="$1" ;;
      --managed-root=*|--root=*) MANAGED_ROOT="${1#*=}" ;;
      --host) shift; [[ "$#" -gt 0 ]] || die "--host requires a value"; GITHUB_HOST="$1" ;;
      --host=*) GITHUB_HOST="${1#*=}" ;;
      --account) shift; [[ "$#" -gt 0 ]] || die "--account requires a value"; ACCOUNT="$1" ;;
      --account=*) ACCOUNT="${1#*=}" ;;
      --github-account) shift; [[ "$#" -gt 0 ]] || die "--github-account requires OWNER=LOGIN"; register_github_account_binding "$1" || die "Invalid or duplicate --github-account binding: $1" ;;
      --github-account=*) register_github_account_binding "${1#*=}" || die "Invalid or duplicate --github-account binding: ${1#*=}" ;;
      --all) SELECT_ALL=1 ;;
      --project) shift; [[ "$#" -gt 0 ]] || die "--project requires a path or name"; PROJECT_SELECTORS+=("$1") ;;
      --project=*) PROJECT_SELECTORS+=("${1#*=}") ;;
      --exclude-path) shift; [[ "$#" -gt 0 ]] || die "--exclude-path requires a path"; EXCLUDED_PATHS+=("$(normalize_path "$1")") ;;
      --preflight|--scan) ACTION="preflight" ;;
      --apply) ACTION="apply" ;;
      --full-auto) ACTION="apply"; SELECT_ALL=1 ;;
      --create-missing-repos) CREATE_MISSING_REPOS=1 ;;
      --repo-visibility) shift; [[ "$#" -gt 0 ]] || die "--repo-visibility requires private or public"; REPO_VISIBILITY="$1" ;;
      --retire-sources) RETIRE_SOURCES=1 ;;
      --delete-sources) DELETE_SOURCES=1 ;;
      --confirm-delete) shift; [[ "$#" -gt 0 ]] || die "--confirm-delete requires VERIFIED-STAGE2"; DELETE_CONFIRMATION="$1" ;;
      --archive-sources) CREATE_ARCHIVE=1 ;;
      --cleanup-transaction-temp) CLEANUP_TRANSACTION_TEMP=1 ;;
      --prepare-runtime) PREPARE_RUNTIME=1 ;;
      --open) shift; [[ "$#" -gt 0 ]] || die "--open requires codex, code, copilot, finder, or devcontainer"; OPEN_WITH="$1" ;;
      --yes) ASSUME_YES=1 ;;
      --report) shift; [[ "$#" -gt 0 ]] || die "--report requires a path"; REPORT_PATH="$1" ;;
      *) die "Unknown Stage 2 argument: $1" ;;
    esac
    shift
  done
}

main() {
  local candidate=""
  local apply_status=0
  local code_root=""
  local import_parent=""
  local archives_parent=""
  local runtime_parent=""
  local reports_parent=""
  local receipts_parent=""

  parse_args "$@"
  [[ "$REPO_VISIBILITY" == "private" || "$REPO_VISIBILITY" == "public" ]] || die "Repository visibility must be private or public."
  [[ "$DELETE_SOURCES" -ne 1 ]] || die "Stage 2 permanent source deletion is disabled; use receipt-linked Stage 3 cleanup."
  case "$OPEN_WITH" in ""|codex|code|copilot|finder|devcontainer) ;; *) die "Unknown --open application: $OPEN_WITH" ;; esac
  [[ "$SELECT_ALL" -eq 1 || "${#PROJECT_SELECTORS[@]}" -gt 0 ]] || die "Choose --all or at least one --project."
  if [[ "$ACTION" == "apply" && "$ASSUME_YES" -ne 1 ]]; then
    if [[ -t 0 ]]; then
      local confirmation=""
      read -r -p "Type STAGE2 to run safety-gated workspace reconciliation: " confirmation
      [[ "$confirmation" == "STAGE2" ]] || die "Stage 2 apply was cancelled."
      ASSUME_YES=1
    else
      die "Stage 2 apply requires --yes after reviewing preflight."
    fi
  fi
  valid_github_host "$GITHUB_HOST" || die "GitHub host contains unsafe characters."
  SOURCE_ROOT="$(normalize_path "$SOURCE_ROOT")" || die "Stage 1 source path could not be resolved safely."
  MANAGED_ROOT="$(normalize_path "$MANAGED_ROOT")" || die "Managed root path could not be resolved safely."
  [[ -d "$SOURCE_ROOT" ]] || die "Stage 1 source folder was not found: $SOURCE_ROOT"
  [[ "$SOURCE_ROOT" != "/" && "$MANAGED_ROOT" != "/" ]] || die "Filesystem root cannot be used as a Stage 2 source or managed root."
  if path_is_within "$MANAGED_ROOT" "$SOURCE_ROOT" || path_is_within "$SOURCE_ROOT" "$MANAGED_ROOT"; then
    die "Stage 1 source and managed root must be separate folders."
  fi
  mkdir -p -- "$MANAGED_ROOT"
  MANAGED_ROOT="$(canonical_path "$MANAGED_ROOT")" || die "Managed root could not be canonicalized after creation."
  code_root="$(ensure_managed_directory "$MANAGED_ROOT/Code" "Managed Code root")" || die "Managed Code root failed canonical validation."
  import_parent="$(ensure_managed_directory "$MANAGED_ROOT/Import" "Managed Import root")" || die "Managed Import root failed canonical validation."
  runtime_parent="$(ensure_managed_directory "$MANAGED_ROOT/Runtime" "Managed Runtime root")" || die "Managed Runtime root failed canonical validation."
  MANAGED_TEMP="$(ensure_managed_directory "$MANAGED_ROOT/_temp" "Managed _temp root")" || die "Managed _temp must be a real directory inside the managed root."
  CODE_REPOS="$(ensure_managed_directory "$code_root/Repos" "Canonical Code/Repos root")" || die "Managed Code/Repos containment failed."
  IMPORT_ROOT="$(ensure_managed_directory "$import_parent/Stage2" "Stage 2 import root")" || die "Stage 2 import root failed canonical validation."
  archives_parent="$(ensure_managed_directory "$import_parent/Archives" "Managed archive root")" || die "Managed archive root failed canonical validation."
  ARCHIVES_ROOT="$(ensure_managed_directory "$archives_parent/Stage2" "Stage 2 archive root")" || die "Stage 2 archive root failed canonical validation."
  RUNTIME_REPOS="$(ensure_managed_directory "$runtime_parent/Repos" "Runtime/Repos root")" || die "Managed Runtime/Repos containment failed."
  reports_parent="$(ensure_managed_directory "$runtime_parent/Reports" "Managed reports root")" || die "Managed reports root failed canonical validation."
  REPORTS_DIR="$(ensure_managed_directory "$reports_parent/Stage2" "Stage 2 reports root")" || die "Stage 2 reports root failed canonical validation."
  receipts_parent="$(ensure_managed_directory "$runtime_parent/Receipts" "Managed receipts root")" || die "Managed receipts root failed canonical validation."
  RECEIPTS_ROOT="$(ensure_managed_directory "$receipts_parent/Stage2" "Stage 2 receipts root")" || die "Stage 2 receipts root failed canonical validation."
  TRANSACTION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  IMPORT_STAGE="$IMPORT_ROOT/$TRANSACTION_ID"
  ARCHIVES_DIR="$ARCHIVES_ROOT/$TRANSACTION_ID"
  RECEIPTS_DIR="$RECEIPTS_ROOT/$TRANSACTION_ID"
  TMP_PARENT="$(canonical_path "${TMPDIR:-/tmp}")" || die "Temporary directory root could not be resolved safely."
  [[ -d "$TMP_PARENT" ]] || die "Temporary directory root does not exist: $TMP_PARENT"
  TMP_ROOT="$(mktemp -d "$TMP_PARENT/csa-iem-stage2.XXXXXX")" || die "Could not create the Stage 2 working directory."
  TMP_ROOT="$(canonical_path "$TMP_ROOT")" || die "Could not canonicalize the Stage 2 working directory."
  require_strict_containment "$TMP_ROOT" "$TMP_PARENT" "Stage 2 working directory" || die "Unsafe Stage 2 working directory."
  PLAN_FILE="$TMP_ROOT/plan.tsv"
  GH_CATALOG="$TMP_ROOT/github-repositories.tsv"
  DESTINATION_INDEX="$TMP_ROOT/canonical-destinations.tsv"
  GITHUB_BINDINGS_FILE="$TMP_ROOT/github-account-bindings-verified.tsv"
  : > "$PLAN_FILE"
  if [[ -z "$REPORT_PATH" ]]; then
    REPORT_PATH="$REPORTS_DIR/stage2-$TRANSACTION_ID.md"
  else
    REPORT_PATH="$(normalize_path "$REPORT_PATH")"
  fi

  GIT_BIN="$(command -v git 2>/dev/null || true)"
  [[ -n "$GIT_BIN" && "$GIT_BIN" == /* && -x "$GIT_BIN" ]] || die "Git is required for Stage 2."
  PYTHON3_BIN="$(command -v python3 2>/dev/null || true)"
  [[ -n "$PYTHON3_BIN" && "$PYTHON3_BIN" == /* && -x "$PYTHON3_BIN" ]] || die "Python 3 is required for deterministic filesystem evidence."
  "$PYTHON3_BIN" -I -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1 ||
    die "Python 3.8 or newer with isolated startup support is required for filesystem evidence."
  command -v rsync >/dev/null 2>&1 || die "rsync is required for Stage 2."
  command -v shasum >/dev/null 2>&1 || die "shasum is required for Stage 2 Git snapshot evidence."
  command -v cmp >/dev/null 2>&1 || die "cmp is required for Stage 2 byte verification."
  command -v od >/dev/null 2>&1 || die "od is required for Stage 2 snapshot path encoding."
  [[ -x /usr/bin/base64 ]] || die "base64 is required for in-memory owner-scoped Git authentication."
  if [[ "$(uname -s)" == "Darwin" ]]; then
    [[ -x /usr/bin/ditto ]] || die "ditto is required for full Git administrative snapshots on macOS."
  fi
  if [[ "$CREATE_ARCHIVE" -eq 1 ]]; then
    command -v unzip >/dev/null 2>&1 || die "unzip is required for verified Stage 2 ZIP archives."
    if [[ "$(uname -s)" != "Darwin" ]]; then
      command -v zip >/dev/null 2>&1 || die "zip is required for verified Stage 2 ZIP archives."
    fi
  fi
  load_github_catalog && GITHUB_READY=1 || GITHUB_READY=0
  if [[ "$GITHUB_READY" -ne 1 ]]; then
    ACCOUNT="${ACCOUNT:-unavailable}"
  fi
  build_destination_index

  collect_candidates
  info "Stage 1 source: $SOURCE_ROOT"
  info "Managed root: $MANAGED_ROOT"
  info "GitHub identity: $GITHUB_HOST/${ACCOUNT:-unavailable}"
  while IFS= read -r candidate; do
    plan_project "$candidate"
  done < "$TMP_ROOT/candidates.txt"
  finalize_plan_safety

  if [[ "$ACTION" == "apply" ]]; then
    if ! apply_plan; then
      apply_status=1
    fi
  fi
  write_report "$ACTION"
  if [[ "$ACTION" == "apply" && "$apply_status" -ne 0 ]]; then
    return 1
  fi
}

if [[ "${CSA_IEM_STAGE2_LIBRARY_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
