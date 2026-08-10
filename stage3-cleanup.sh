#!/usr/bin/env bash
set -eo pipefail
umask 077
export LC_ALL=C

APP_REPOSITORY="WayneTechLab/CSA-iLEM"
LEGACY_APP_REPOSITORY="WayneTechLab/CSA-iEM"
SOURCE_ROOT="${CSA_IEM_STAGE2_SOURCE:-$HOME/CODEX PROJECTS}"
MANAGED_ROOT="${CSA_IEM_STAGE2_ROOT:-$HOME/CSA-iEM}"
GITHUB_HOST="${GH_HOST:-github.com}"
GH_BIN=""
ACTIVE_GITHUB_LOGIN=""
GITHUB_ACCOUNT_BINDINGS=()
GITHUB_BINDINGS_FILE=""
SCOPED_GITHUB_TOKEN=""
SCOPED_GITHUB_LOGIN=""
ACTION="preflight"
SELECT_ALL=0
DELETE_STAGE1_ORIGINALS=0
DELETE_STAGE2_INPUTS=0
CLEANUP_TRANSACTION_TEMP=0
CLEANUP_ALL_VERIFIED_TEMP=0
ASSUME_YES=0
DELETE_CONFIRMATION=""
REPORT_PATH=""
RECEIPT_SELECTORS=()
PROJECT_SELECTORS=()

TMP_ROOT=""
PLAN_FILE=""
TRANSACTION_ID=""
REPORTS_DIR=""
AUDIT_DIR=""
CANONICAL_REPOS_ROOT=""
MANAGED_TEMP_ROOT=""
MANAGED_TEMP_CANONICAL=""
MANAGED_TEMP_PRESENT=0
GIT_BIN=""
PYTHON3_BIN=""

CURRENT_STAGE3_FILESYSTEM_EVIDENCE=""
CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST=""
CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST=""
CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST=""
CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST=""
CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE=""
CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE=""
CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX=""
CURRENT_STAGE3_FILESYSTEM_EXACT_CATEGORIES=""
CURRENT_STAGE3_FILESYSTEM_RECORD_ONLY_CATEGORIES=""
CURRENT_STAGE3_FILESYSTEM_UNSUPPORTED_CATEGORIES=""
CURRENT_STAGE3_FILESYSTEM_DESTINATION_DEVICE=""
CURRENT_STAGE3_FILESYSTEM_DESTINATION_VOLUME_UUID=""
CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED=""
CURRENT_STAGE3_FILESYSTEM_BINDING_SOURCE=""
CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE=""
CURRENT_STAGE3_CHAIN_RECEIPT=""
CURRENT_STAGE3_FILESYSTEM_PACKAGE=""
CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST=""
CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST=""
CURRENT_STAGE3_FILESYSTEM_DURABLE=0
CURRENT_STAGE3_GITHUB_OWNER=""
CURRENT_STAGE3_GITHUB_LOGIN=""
CURRENT_STAGE3_GITHUB_ACCOUNT_BINDING_DIGEST=""
CURRENT_STAGE3_REPOSITORY_ROLE=""
CURRENT_STAGE3_PARENT_REPOSITORY=""
CURRENT_STAGE3_EXACT_GIT_REMOTE=""
CURRENT_STAGE3_WIKI_REF_DIGEST=""
CURRENT_STAGE3_WIKI_DEFAULT_BRANCH=""
CURRENT_STAGE3_WIKI_HEAD_OID=""
CURRENT_STAGE3_FINALIZATION_RECEIPT=""
CURRENT_STAGE3_FINALIZATION_DIGEST=""

CHAIN_DESTINATION=""
CHAIN_ARCHIVE=""
CHAIN_REPOSITORY=""
CHAIN_GIT_REF_NAMESPACE=""
CHAIN_RECEIPT=""
CHAIN_ERROR=""
VERIFICATION_FAILURE_REASON=""
COMPATIBILITY_LINK_PATH=""
COMPATIBILITY_LINK_TEMP=""
COMPATIBILITY_LINK_RETARGETED_PATH=""

cleanup() {
  [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]] && rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
CSA-iEM Stage 3 verified lifecycle cleanup

Usage:
  stage3-cleanup.sh --source PATH --managed-root PATH --preflight --all
  stage3-cleanup.sh --source PATH --managed-root PATH --apply --all [cleanup options] --yes --confirm-delete VERIFIED-STAGE3
  stage3-cleanup.sh --receipt PATH --preflight

Selection:
  --all                         Use every verified Stage 1 and Stage 2 receipt.
  --receipt PATH               Use one receipt; repeat for multi-select.
  --project NAME_OR_SLUG       Filter receipts by project/repository; repeatable.

Cleanup options:
  --delete-stage1-originals    Permanently remove verified original project folders.
  --delete-stage2-inputs       Permanently remove verified CODEX PROJECTS inputs.
  --cleanup-transaction-temp   Remove exact receipt-linked project staging/quarantine data.
  --cleanup-all-verified-temp  Also remove receipt-linked Stage 1 index artifacts.
  --confirm-delete VERIFIED-STAGE3
                                Required for every Stage 3 apply.

Actions:
  --preflight                  Verify and report without changing files (default).
  --apply                      Apply only when every planned cleanup row is ready.
  --yes                        Required for non-interactive apply.
  --report PATH                Write the Markdown report to an explicit path.

Identity:
  --host HOST                  GitHub host (default: github.com).
  --github-account OWNER=LOGIN Bind an owner to a stored gh login; repeatable.
                               Tokens remain in memory and global auth is unchanged.

Stage 3 never deletes backups, reports, receipts, canonical repositories, active
CSA-iEM workspaces, failed transactions, or unreferenced temporary directories.

Git cleanup contract:
  Every receipt for a Git source must declare git_snapshot and
  git_snapshot_digest. git_snapshot is a safe relative path beneath the final
  canonical repository's .csa-iem-recovery directory. The snapshot directory
  must preserve every source .git entry, path spelling, regular-file byte,
  symlink target, and permission mode, and its tree-sha256-v1 digest must equal
  git_snapshot_digest. A chained Stage 1 cleanup consumes this evidence from
  its matching Stage 2 receipt. git_ref_namespace is optional and, when
  present, may preserve source refs beneath that namespace.

Relocated recovery contract:
  A Stage 1 source's .csa-iem-recovery tree is captured by the fresh Stage 3
  original-source package. Legacy relocated-snapshot fields are supplemental
  only and never substitute for that live evidence.

Filesystem evidence contract:
  Stage 2 cleanup requires a format-2 csa-iem-filesystem-evidence-v2 package
  beneath the canonical repository's .csa-iem-recovery directory. It records
  every source path by byte-hex spelling, content/link/type, metadata, ACLs,
  xattrs, allocation, and hardlink topology, with an exact active or recovery
  representative. Ownership, access/time, BSD flags, sparse/allocation, and
  hardlink reproduction remain explicitly record-only where the destination
  filesystem cannot reproduce them. A chained Stage 1 original always receives
  a separate live package under managed _temp immediately before quarantine;
  Stage 2 copy metadata is never used as proof of the original's metadata.
EOF
}

die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
info() { printf '[INFO] %s\n' "$*"; }

normalize_path() {
  local value="${1/#\~/$HOME}"
  local parent=""
  local leaf=""
  if [[ -e "$value" || -L "$value" ]]; then
    realpath -- "$value" 2>/dev/null
    return
  fi
  parent="$(dirname "$value")"
  leaf="$(basename "$value")"
  if [[ -d "$parent" ]]; then
    printf '%s/%s' "$(realpath -- "$parent" 2>/dev/null)" "$leaf"
  else
    printf '%s' "$value"
  fi
}

canonical_existing_path() {
  local value="$1"
  [[ -e "$value" || -L "$value" ]] || return 1
  realpath -- "$value" 2>/dev/null
}

path_is_strictly_within() {
  local candidate=""
  local root=""
  candidate="$(canonical_existing_path "$1")" || return 1
  root="$(canonical_existing_path "$2")" || return 1
  [[ "$candidate" == "$root/"* ]]
}

paths_are_same() {
  local first=""
  local second=""
  first="$(canonical_existing_path "$1")" || return 1
  second="$(canonical_existing_path "$2")" || return 1
  [[ "$first" == "$second" ]]
}

device_id() {
  local path="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%d' "$path" 2>/dev/null
  else
    stat -c '%d' "$path" 2>/dev/null
  fi
}

cleanup_target_is_protected() {
  local candidate=""
  candidate="$(canonical_existing_path "$1")" || return 0

  # Canonical repositories are never Stage 3 deletion targets. The managed
  # _temp root and its ancestors are protected; only an exact receipt-bound
  # Stage2-Completed project descendant can be authorized elsewhere.
  if [[ "$candidate" == "$CANONICAL_REPOS_ROOT" ||
        "$candidate" == "$CANONICAL_REPOS_ROOT/"* ||
        "$CANONICAL_REPOS_ROOT" == "$candidate/"* ||
        "$candidate" == "$MANAGED_TEMP_ROOT/.csa-iem-recovery" ||
        "$candidate" == "$MANAGED_TEMP_ROOT/.csa-iem-recovery/"* ||
        "$candidate" == "$MANAGED_TEMP_ROOT" ||
        "$MANAGED_TEMP_ROOT" == "$candidate/"* ||
        "$candidate" == "$MANAGED_ROOT" ||
        "$MANAGED_ROOT" == "$candidate/"* ||
        "$candidate" == "$SOURCE_ROOT" ||
        "$SOURCE_ROOT" == "$candidate/"* ]]; then
    return 0
  fi
  return 1
}

managed_temp_is_preserved() {
  local current=""
  if [[ "$MANAGED_TEMP_PRESENT" -eq 1 ]]; then
    [[ -d "$MANAGED_TEMP_ROOT" && ! -L "$MANAGED_TEMP_ROOT" ]] || return 1
    current="$(canonical_existing_path "$MANAGED_TEMP_ROOT")" || return 1
    [[ "$current" == "$MANAGED_TEMP_CANONICAL" ]]
  else
    [[ ! -e "$MANAGED_TEMP_ROOT" && ! -L "$MANAGED_TEMP_ROOT" ]]
  fi
}

identity_key() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

is_reserved_project() {
  local path="$1"
  local repository="${2:-}"
  local key="$(identity_key "$(basename "$path")")"
  local normalized_repository="$(printf '%s' "$repository" | tr '[:upper:]' '[:lower:]')"
  [[ "$key" == "csaiem" || "$key" == "csailem" ]] && return 0
  [[ "$normalized_repository" == "$(printf '%s' "$APP_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ||
     "$normalized_repository" == "$(printf '%s' "$LEGACY_APP_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ]] && return 0
  return 1
}

receipt_value() {
  local receipt="$1"
  local key="$2"
  awk -v prefix="$key=" 'index($0,prefix)==1 { print substr($0,length(prefix)+1); exit }' "$receipt"
}

receipt_field_count() {
  local receipt="$1"
  local key="$2"
  awk -v prefix="$key=" 'index($0,prefix)==1 { count++ } END { print count+0 }' "$receipt"
}

receipt_optional_field_matches() {
  local receipt="$1"
  local evidence_receipt="$2"
  local key="$3"
  local count=""
  count="$(receipt_field_count "$receipt" "$key")"
  [[ "$count" -le 1 ]] || return 1
  [[ "$count" -eq 0 ]] && return 0
  [[ "$(receipt_field_count "$evidence_receipt" "$key")" == "1" ]] || return 1
  [[ "$(receipt_value "$receipt" "$key")" == "$(receipt_value "$evidence_receipt" "$key")" ]]
}

stage1_optional_stage2_evidence_matches() {
  local stage1_receipt="$1"
  local stage2_receipt="$2"
  local key=""
  local keys=(
    identity_contract github_host github_owner github_login github_account_binding_schema
    github_account_binding_digest repository_role parent_repository parent_repository_id
    exact_git_remote wiki_ref_digest wiki_default_branch wiki_head_oid
    repository_id filesystem_evidence_schema filesystem_evidence_version filesystem_evidence_status
    filesystem_evidence filesystem_evidence_digest filesystem_manifest filesystem_manifest_digest
    filesystem_binding filesystem_binding_digest filesystem_source_tree_digest
    filesystem_source_path_hex filesystem_source_device filesystem_source_inode
    filesystem_exact_categories filesystem_record_only_categories filesystem_unsupported_categories
    filesystem_destination_device filesystem_destination_volume_uuid
    filesystem_destination_owners_enabled final_stage2_proof
  )
  for key in "${keys[@]}"; do
    receipt_optional_field_matches "$stage1_receipt" "$stage2_receipt" "$key" || return 1
  done
}

receipt_declares_unsupported_local_quarantine() {
  local receipt="$1"
  local key=""
  for key in managed_evidence managed_evidence_digest local_quarantine local_quarantine_inode local_quarantine_device local_cleanup_eligible local_cleanup_token; do
    [[ "$(receipt_field_count "$receipt" "$key")" -eq 0 ]] || return 0
  done
  return 1
}

valid_sha256_digest() {
  local digest="$1"
  [[ "${#digest}" -eq 64 && "$digest" != *[!0-9a-f]* ]]
}

valid_git_object_id() {
  local object_id="$1"
  [[ ( "${#object_id}" -eq 40 || "${#object_id}" -eq 64 ) && "$object_id" != *[!0-9a-f]* ]]
}

valid_repository_slug() {
  local slug="$1"
  local owner=""
  local repository=""
  [[ "$slug" == */* && "$slug" != */*/* ]] || return 1
  owner="${slug%%/*}"
  repository="${slug#*/}"
  [[ -n "$owner" && -n "$repository" && "$owner" != "." && "$owner" != ".." &&
     "$repository" != "." && "$repository" != ".." &&
     "$owner" =~ ^[A-Za-z0-9_.-]+$ && "$repository" =~ ^[A-Za-z0-9_.-]+$ ]]
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
  local owner=""
  valid_github_host "$GITHUB_HOST" || return 1
  GH_BIN="$(command -v gh 2>/dev/null || true)"
  [[ -n "$GH_BIN" && "$GH_BIN" == /* && -x "$GH_BIN" ]] || return 1
  ACTIVE_GITHUB_LOGIN="$(ambient_authenticated_login 2>/dev/null || true)"
  [[ -z "$ACTIVE_GITHUB_LOGIN" ]] || valid_github_principal "$ACTIVE_GITHUB_LOGIN" || return 1
  if [[ "${#GITHUB_ACCOUNT_BINDINGS[@]}" -eq 0 ]]; then
    [[ -n "$ACTIVE_GITHUB_LOGIN" ]] || return 1
    register_github_account_binding "$ACTIVE_GITHUB_LOGIN=$ACTIVE_GITHUB_LOGIN" || return 1
  fi
  [[ -n "$GITHUB_BINDINGS_FILE" ]] && : > "$GITHUB_BINDINGS_FILE"
  for binding in "${GITHUB_ACCOUNT_BINDINGS[@]}"; do
    owner="${binding%%=*}"
    verify_github_account_binding "$owner" || return 1
  done
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
    rm -f -- "$raw" "$canonical"
    return 1
  fi
  if ! awk -F '\t' '
    $1 ~ /^ref: refs\/heads\/[A-Za-z0-9._\/-]+$/ && $2 == "HEAD" { print; next }
    $1 !~ /[^0-9a-f]/ && (length($1) == 40 || length($1) == 64) && ($2 == "HEAD" || $2 ~ /^refs\/(heads|tags)\/[A-Za-z0-9._\/-]+(\^\{\})?$/) { print; next }
    { bad=1 }
    END { exit(bad ? 1 : 0) }
  ' "$raw" | LC_ALL=C sort -u > "$canonical"; then
    rm -f -- "$raw" "$canonical"
    return 1
  fi
  symbolic="$(awk -F '\t' '$1 ~ /^ref: refs\/heads\/[A-Za-z0-9._\/-]+$/ && $2 == "HEAD" { sub(/^ref: /, "", $1); print $1; exit }' "$canonical")"
  [[ "$symbolic" == refs/heads/* ]] || { rm -f -- "$raw" "$canonical"; return 1; }
  branch="${symbolic#refs/heads/}"
  head_oid="$(awk -F '\t' '$2 == "HEAD" && $1 !~ /[^0-9a-f]/ { print $1; exit }' "$canonical")"
  branch_oid="$(awk -F '\t' -v ref="$symbolic" '$2 == ref && $1 !~ /[^0-9a-f]/ { print $1; exit }' "$canonical")"
  valid_git_object_id "$head_oid" && [[ "$head_oid" == "$branch_oid" ]] || { rm -f -- "$raw" "$canonical"; return 1; }
  digest="$(shasum -a 256 "$canonical" | awk '{print $1}')"
  rm -f -- "$raw" "$canonical"
  valid_sha256_digest "$digest" || return 1
  printf '%s\t%s\t%s' "$branch" "$head_oid" "$digest"
}

safe_recovery_relative_path() {
  local value="$1"
  local part=""
  local parts=()
  [[ -n "$value" && "$value" != /* && "$value" == .csa-iem-recovery/* &&
     "$value" != */ && "$value" != *//* &&
     "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *$'\t'* ]] || return 1
  IFS='/' read -r -a parts <<< "$value"
  [[ "${#parts[@]}" -ge 2 && "${parts[0]}" == ".csa-iem-recovery" ]] || return 1
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != "." && "$part" != ".." ]] || return 1
  done
}

verified_receipt_status() {
  case "$1" in
    verified-source-kept|source-kept|source-retired|source-deleted) return 0 ;;
    *) return 1 ;;
  esac
}

verified_zip() {
  local archive="$1"
  [[ -n "$archive" && -f "$archive" ]] || return 1
  command -v unzip >/dev/null 2>&1 || {
    warn "unzip is required because this receipt includes an archive: $archive"
    return 1
  }
  unzip -tq "$archive" >/dev/null 2>&1
}

normalize_remote_slug() {
  local remote="$1"
  local remainder=""
  local remote_host=""
  local remote_path=""
  local expected_host=""
  remote="${remote#"${remote%%[![:space:]]*}"}"
  remote="${remote%"${remote##*[![:space:]]}"}"
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
  remote_path="${remote_path#"${remote_path%%[![:space:]]*}"}"
  remote_path="${remote_path%"${remote_path##*[![:space:]]}"}"
  valid_repository_slug "$remote_path" || return 1
  printf '%s' "$remote_path"
}

executable_permission_bits() {
  local path="$1"
  local mode=""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    mode="$(stat -f '%Lp' "$path" 2>/dev/null)" || return 1
  else
    mode="$(stat -c '%a' "$path" 2>/dev/null)" || return 1
  fi
  case "$mode" in ""|*[!0-7]*) return 1 ;; esac
  printf '%03o' "$((8#$mode & 0111))"
}

permission_mode() {
  local path="$1"
  local mode=""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    mode="$(stat -f '%Lp' "$path" 2>/dev/null)" || return 1
  else
    mode="$(stat -c '%a' "$path" 2>/dev/null)" || return 1
  fi
  case "$mode" in ""|*[!0-7]*) return 1 ;; esac
  printf '%04o' "$((8#$mode & 07777))"
}

owner_id() {
  local path="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%u' "$path" 2>/dev/null
  else
    stat -c '%u' "$path" 2>/dev/null
  fi
}

trusted_system_git_is_available() {
  local component=""
  local mode=""
  local owner=""
  [[ "$GIT_BIN" == "/usr/bin/git" && -f "$GIT_BIN" && -x "$GIT_BIN" && ! -L "$GIT_BIN" ]] || return 1
  [[ "$(canonical_existing_path "$GIT_BIN" 2>/dev/null || true)" == "$GIT_BIN" ]] || return 1
  for component in /usr /usr/bin "$GIT_BIN"; do
    [[ -e "$component" && ! -L "$component" ]] || return 1
    owner="$(owner_id "$component")" || return 1
    mode="$(permission_mode "$component")" || return 1
    [[ "$owner" == "0" && "$mode" != *[!0-7]* ]] || return 1
    [[ "$((8#$mode & 0022))" -eq 0 ]] || return 1
  done
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

reset_current_stage3_filesystem_evidence() {
  CURRENT_STAGE3_FILESYSTEM_EVIDENCE=""
  CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST=""
  CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST=""
  CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST=""
  CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST=""
  CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE=""
  CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE=""
  CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX=""
  CURRENT_STAGE3_FILESYSTEM_EXACT_CATEGORIES=""
  CURRENT_STAGE3_FILESYSTEM_RECORD_ONLY_CATEGORIES=""
  CURRENT_STAGE3_FILESYSTEM_UNSUPPORTED_CATEGORIES=""
  CURRENT_STAGE3_FILESYSTEM_DESTINATION_DEVICE=""
  CURRENT_STAGE3_FILESYSTEM_DESTINATION_VOLUME_UUID=""
  CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED=""
  CURRENT_STAGE3_FILESYSTEM_BINDING_SOURCE=""
  CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE=""
  CURRENT_STAGE3_CHAIN_RECEIPT=""
  CURRENT_STAGE3_FILESYSTEM_PACKAGE=""
  CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST=""
  CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST=""
  CURRENT_STAGE3_FILESYSTEM_DURABLE=0
  CURRENT_STAGE3_GITHUB_OWNER=""
  CURRENT_STAGE3_GITHUB_LOGIN=""
  CURRENT_STAGE3_GITHUB_ACCOUNT_BINDING_DIGEST=""
  CURRENT_STAGE3_REPOSITORY_ROLE=""
  CURRENT_STAGE3_PARENT_REPOSITORY=""
  CURRENT_STAGE3_EXACT_GIT_REMOTE=""
  CURRENT_STAGE3_WIKI_REF_DIGEST=""
  CURRENT_STAGE3_WIKI_DEFAULT_BRANCH=""
  CURRENT_STAGE3_WIKI_HEAD_OID=""
  CURRENT_STAGE3_FINALIZATION_RECEIPT=""
  CURRENT_STAGE3_FINALIZATION_DIGEST=""
}

load_stage3_filesystem_evidence_result() {
  local result_file="$1"
  local key=""
  local value=""

  while IFS='=' read -r key value; do
    case "$key" in
      binding_digest) CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST="$value" ;;
      destination_device) CURRENT_STAGE3_FILESYSTEM_DESTINATION_DEVICE="$value" ;;
      destination_owners_enabled) CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED="$value" ;;
      destination_volume_uuid) CURRENT_STAGE3_FILESYSTEM_DESTINATION_VOLUME_UUID="$value" ;;
      evidence_digest) CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST="$value" ;;
      exact_categories) CURRENT_STAGE3_FILESYSTEM_EXACT_CATEGORIES="$value" ;;
      manifest_digest) CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST="$value" ;;
      record_only_categories) CURRENT_STAGE3_FILESYSTEM_RECORD_ONLY_CATEGORIES="$value" ;;
      source_device) CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE="$value" ;;
      source_inode) CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE="$value" ;;
      source_path_hex) CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX="$value" ;;
      source_tree_digest) CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST="$value" ;;
      unsupported_categories) CURRENT_STAGE3_FILESYSTEM_UNSUPPORTED_CATEGORIES="$value" ;;
      *) return 1 ;;
    esac
  done < "$result_file"
  valid_sha256_digest "$CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST" || return 1
  valid_sha256_digest "$CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST" || return 1
  [[ -n "$CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX" &&
     "$CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX" != *[!0-9a-f]* &&
     "$CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE" != *[!0-9]* &&
     "$CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE" != *[!0-9]* &&
     "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_DEVICE" != *[!0-9]* &&
     ( "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "true" ||
       "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "false" ||
       "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED" == "unknown" ) &&
     -n "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_VOLUME_UUID" &&
     -n "$CURRENT_STAGE3_FILESYSTEM_EXACT_CATEGORIES" &&
     -n "$CURRENT_STAGE3_FILESYSTEM_RECORD_ONLY_CATEGORIES" &&
     -n "$CURRENT_STAGE3_FILESYSTEM_UNSUPPORTED_CATEGORIES" ]]
}

sha256_regular_file() {
  local path="$1"
  local digest=""
  [[ -f "$path" && ! -L "$path" ]] || return 1
  digest="$(shasum -a 256 "$path" 2>/dev/null | awk 'NR == 1 { print $1 }')"
  valid_sha256_digest "$digest" || return 1
  printf '%s' "$digest"
}

valid_even_hex() {
  local value="$1"
  [[ -n "$value" && "$value" != *[!0-9a-f]* && $(( ${#value} % 2 )) -eq 0 ]]
}

prepare_git_fsmonitor_for_evidence() {
  local source="$1"
  local socket_path="$source/.git/fsmonitor--daemon.ipc"

  if [[ -S "$socket_path" ]]; then
    isolated_git -C "$source" fsmonitor--daemon stop >/dev/null 2>&1 || {
      VERIFICATION_FAILURE_REASON="Git fsmonitor daemon could not be stopped before evidence capture."
      return 1
    }
  fi
  if [[ -S "$socket_path" ]]; then
    VERIFICATION_FAILURE_REASON="Git fsmonitor socket remains after daemon stop."
    return 1
  fi
}

stage2_filesystem_evidence_fields_are_strict() {
  local receipt="$1"
  local key=""
  local transaction=""
  local repository=""
  local evidence=""
  local expected=""
  local value=""
  local required=(
    format stage transaction repository repository_id original_source current_source destination
    identity_contract github_host github_owner github_login github_account_binding_schema
    github_account_binding_digest repository_role parent_repository parent_repository_id
    exact_git_remote wiki_ref_digest wiki_default_branch wiki_head_oid
    filesystem_metadata_verification filesystem_evidence_schema filesystem_evidence_version
    filesystem_evidence_status filesystem_evidence filesystem_evidence_digest filesystem_manifest
    filesystem_manifest_digest filesystem_binding filesystem_binding_digest
    filesystem_source_tree_digest filesystem_source_path_hex filesystem_source_device
    filesystem_source_inode filesystem_exact_categories filesystem_record_only_categories
    filesystem_unsupported_categories filesystem_destination_device
    filesystem_destination_volume_uuid filesystem_destination_owners_enabled
    final_stage2_proof git_snapshot git_snapshot_digest git_ref_namespace
  )

  [[ -f "$receipt" && ! -L "$receipt" ]] || return 1
  for key in "${required[@]}"; do
    [[ "$(receipt_field_count "$receipt" "$key")" == "1" ]] || return 1
  done
  [[ "$(receipt_value "$receipt" format)" == "3" &&
     "$(receipt_value "$receipt" stage)" == "2" &&
     "$(receipt_value "$receipt" identity_contract)" == "github-owner-account-role-v1" &&
     "$(receipt_value "$receipt" github_host)" == "$GITHUB_HOST" &&
     "$(receipt_value "$receipt" github_account_binding_schema)" == "owner-login-v1" &&
     "$(receipt_value "$receipt" filesystem_metadata_verification)" == "complete-manifest-with-explicit-record-only" &&
     "$(receipt_value "$receipt" filesystem_evidence_schema)" == "csa-iem-filesystem-evidence-v2" &&
     "$(receipt_value "$receipt" filesystem_evidence_version)" == "2" &&
     "$(receipt_value "$receipt" filesystem_evidence_status)" == "final-verified" &&
     "$(receipt_value "$receipt" final_stage2_proof)" == "manifest-representatives-and-git-snapshot-verified" &&
     "$(receipt_value "$receipt" filesystem_exact_categories)" == "path-bytes,type,regular-content-sha256,symlink-target,xattr-values,acl-bytes,active-or-recovery-representative" &&
     "$(receipt_value "$receipt" filesystem_record_only_categories)" == "mode,uid,gid,bsd-flags,mtime,atime,birthtime,size-allocation-sparse,nlink-hardlink-topology" ]] || return 1
  transaction="$(receipt_value "$receipt" transaction)"
  repository="$(receipt_value "$receipt" repository)"
  safe_path_component "$transaction" || return 1
  safe_project_relative_path "$repository" || return 1
  valid_repository_slug "$repository" || return 1
  value="$(receipt_value "$receipt" github_owner)"
  valid_github_principal "$value" && [[ "$value" == "${repository%%/*}" ]] || return 1
  local github_owner="$value"
  local github_login="$(receipt_value "$receipt" github_login)"
  valid_github_principal "$github_login" || return 1
  [[ "$github_login" == "$(github_login_for_owner "$github_owner" 2>/dev/null || true)" ]] || return 1
  [[ "$(receipt_value "$receipt" github_account_binding_digest)" == "$(github_account_binding_digest "$github_owner" "$github_login")" ]] || return 1
  valid_sha256_digest "$(receipt_value "$receipt" github_account_binding_digest)" || return 1
  [[ "$(receipt_value "$receipt" parent_repository_id)" == "$(receipt_value "$receipt" repository_id)" ]] || return 1
  valid_repository_slug "$(receipt_value "$receipt" parent_repository)" || return 1
  [[ "$(receipt_value "$receipt" exact_git_remote)" == "https://$GITHUB_HOST/$repository.git" ]] || return 1
  case "$(receipt_value "$receipt" repository_role)" in
    repository)
      is_wiki_slug "$repository" && return 1
      [[ "$(receipt_value "$receipt" parent_repository)" == "$repository" &&
         "$(receipt_value "$receipt" wiki_ref_digest)" == "-" &&
         "$(receipt_value "$receipt" wiki_default_branch)" == "-" &&
         "$(receipt_value "$receipt" wiki_head_oid)" == "-" ]] || return 1
      ;;
    wiki)
      is_wiki_slug "$repository" || return 1
      [[ "$(receipt_value "$receipt" parent_repository).wiki" == "$repository" ]] || return 1
      valid_sha256_digest "$(receipt_value "$receipt" wiki_ref_digest)" || return 1
      valid_git_object_id "$(receipt_value "$receipt" wiki_head_oid)" || return 1
      [[ -n "$(receipt_value "$receipt" wiki_default_branch)" && "$(receipt_value "$receipt" wiki_default_branch)" != *[!A-Za-z0-9._/-]* ]] || return 1
      ;;
    *) return 1 ;;
  esac
  evidence="$(receipt_value "$receipt" filesystem_evidence)"
  expected=".csa-iem-recovery/filesystem-evidence/v2/$transaction/$repository/source"
  [[ "$evidence" == "$expected" ]] || return 1
  safe_recovery_relative_path "$evidence" || return 1
  [[ "$(receipt_value "$receipt" filesystem_manifest)" == "$evidence/manifest.jsonl" &&
     "$(receipt_value "$receipt" filesystem_binding)" == "$evidence/binding.json" ]] || return 1
  for key in filesystem_evidence_digest filesystem_manifest_digest filesystem_binding_digest filesystem_source_tree_digest; do
    valid_sha256_digest "$(receipt_value "$receipt" "$key")" || return 1
  done
  valid_even_hex "$(receipt_value "$receipt" filesystem_source_path_hex)" || return 1
  [[ "$(receipt_value "$receipt" filesystem_source_device)" != *[!0-9]* &&
     "$(receipt_value "$receipt" filesystem_source_inode)" != *[!0-9]* &&
     "$(receipt_value "$receipt" filesystem_destination_device)" != *[!0-9]* ]] || return 1
  value="$(receipt_value "$receipt" filesystem_destination_owners_enabled)"
  [[ "$value" == "true" || "$value" == "false" || "$value" == "unknown" ]] || return 1
  for key in repository_id filesystem_unsupported_categories filesystem_destination_volume_uuid; do
    value="$(receipt_value "$receipt" "$key")"
    [[ -n "$value" && "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *$'\t'* ]] || return 1
  done
  safe_recovery_relative_path "$(receipt_value "$receipt" git_snapshot)" || return 1
  valid_sha256_digest "$(receipt_value "$receipt" git_snapshot_digest)" || return 1
  safe_git_ref_namespace "$(receipt_value "$receipt" git_ref_namespace)" || return 1
  value="$(printf '%s' "$(receipt_value "$receipt" original_source)" | hex_encode)"
  [[ "$value" == "$(receipt_value "$receipt" filesystem_source_path_hex)" ]]
}

verify_receipt_github_identity_live() {
  local receipt="$1"
  local repository=""
  local repository_id=""
  local role=""
  local parent=""
  local owner=""
  local login=""
  local binding_digest=""
  local metadata=""
  local live_id=""
  local live_parent=""
  local live_archived=""
  local wiki_metadata=""
  local wiki_branch=""
  local wiki_head=""
  local wiki_digest=""

  stage2_filesystem_evidence_fields_are_strict "$receipt" || return 1
  repository="$(receipt_value "$receipt" repository)"
  repository_id="$(receipt_value "$receipt" repository_id)"
  role="$(receipt_value "$receipt" repository_role)"
  parent="$(receipt_value "$receipt" parent_repository)"
  owner="$(receipt_value "$receipt" github_owner)"
  login="$(receipt_value "$receipt" github_login)"
  binding_digest="$(receipt_value "$receipt" github_account_binding_digest)"
  verify_github_account_binding "$owner" || {
    VERIFICATION_FAILURE_REASON="GitHub owner/login binding is missing, unauthenticated, or resolves to the wrong gh account."
    return 1
  }
  [[ "$login" == "$(github_login_for_owner "$owner")" &&
     "$binding_digest" == "$(github_account_binding_digest "$owner" "$login")" ]] || return 1
  metadata="$(owner_scoped_gh "$owner" api "repos/$parent" \
    --jq '[.node_id,.full_name,(.archived|tostring)] | @tsv' 2>/dev/null)" || {
      VERIFICATION_FAILURE_REASON="The owner-bound GitHub API could not verify the exact parent repository identity."
      return 1
    }
  IFS=$'\t' read -r live_id live_parent live_archived <<< "$metadata"
  [[ "$live_id" == "$repository_id" && "$live_parent" == "$parent" && "$live_archived" == "false" ]] || {
    VERIFICATION_FAILURE_REASON="GitHub parent repository ID, casing, or archive state no longer matches the receipt."
    return 1
  }
  if [[ "$role" == "wiki" ]]; then
    wiki_metadata="$(wiki_remote_metadata "$owner" "$(receipt_value "$receipt" exact_git_remote)")" || {
      VERIFICATION_FAILURE_REASON="The exact authenticated GitHub wiki child remote or refs are unavailable."
      return 1
    }
    IFS=$'\t' read -r wiki_branch wiki_head wiki_digest <<< "$wiki_metadata"
    [[ "$wiki_branch" == "$(receipt_value "$receipt" wiki_default_branch)" &&
       "$wiki_head" == "$(receipt_value "$receipt" wiki_head_oid)" &&
       "$wiki_digest" == "$(receipt_value "$receipt" wiki_ref_digest)" ]] || {
      VERIFICATION_FAILURE_REASON="GitHub wiki refs drifted from the exact Stage 2 receipt; a new Stage 2 proof is required."
      return 1
    }
  fi
  CURRENT_STAGE3_GITHUB_OWNER="$owner"
  CURRENT_STAGE3_GITHUB_LOGIN="$login"
  CURRENT_STAGE3_GITHUB_ACCOUNT_BINDING_DIGEST="$binding_digest"
  CURRENT_STAGE3_REPOSITORY_ROLE="$role"
  CURRENT_STAGE3_PARENT_REPOSITORY="$parent"
  CURRENT_STAGE3_EXACT_GIT_REMOTE="$(receipt_value "$receipt" exact_git_remote)"
  CURRENT_STAGE3_WIKI_REF_DIGEST="$(receipt_value "$receipt" wiki_ref_digest)"
  CURRENT_STAGE3_WIKI_DEFAULT_BRANCH="$(receipt_value "$receipt" wiki_default_branch)"
  CURRENT_STAGE3_WIKI_HEAD_OID="$(receipt_value "$receipt" wiki_head_oid)"
}

resolve_stage2_filesystem_evidence_package() {
  local receipt="$1"
  local destination="$2"
  local relative=""
  local package=""

  stage2_filesystem_evidence_fields_are_strict "$receipt" || return 1
  relative="$(receipt_value "$receipt" filesystem_evidence)"
  package="$(resolve_receipt_snapshot_path "$destination" "$relative")" || return 1
  [[ "$package" == "$destination/$relative" ]] || return 1
  printf '%s' "$package"
}

verify_stage2_filesystem_evidence() {
  local receipt="$1"
  local source="${2:-}"
  local destination="$3"
  local package=""
  local actual_source="-"
  local git_snapshot="-"
  local git_snapshot_digest="-"
  local git_ref_namespace="-"
  local result_file=""
  local key=""
  local value=""
  local seen_file=""

  stage2_filesystem_evidence_fields_are_strict "$receipt" || {
    VERIFICATION_FAILURE_REASON="Stage 2 receipt is legacy, weak, duplicated, or missing the filesystem-evidence-v2 contract."
    return 1
  }
  verify_receipt_github_identity_live "$receipt" || return 1
  package="$(resolve_stage2_filesystem_evidence_package "$receipt" "$destination")" || {
    VERIFICATION_FAILURE_REASON="Stage 2 filesystem evidence package is missing, mis-cased, or outside canonical .csa-iem-recovery."
    return 1
  }
  if [[ -n "$source" ]]; then
    [[ -d "$source" && ! -L "$source" ]] || return 1
    prepare_git_fsmonitor_for_evidence "$source" || return 1
    actual_source="$source"
  fi
  [[ -z "$(receipt_value "$receipt" git_snapshot)" ]] || git_snapshot="$(receipt_value "$receipt" git_snapshot)"
  [[ -z "$(receipt_value "$receipt" git_snapshot_digest)" ]] || git_snapshot_digest="$(receipt_value "$receipt" git_snapshot_digest)"
  [[ -z "$(receipt_value "$receipt" git_ref_namespace)" ]] || git_ref_namespace="$(receipt_value "$receipt" git_ref_namespace)"
  result_file="$(mktemp "$TMP_ROOT/stage2-filesystem-evidence.XXXXXX")" || return 1
  seen_file="$(mktemp "$TMP_ROOT/stage2-filesystem-evidence-seen.XXXXXX")" || { rm -f -- "$result_file"; return 1; }
  if ! filesystem_evidence_helper verify \
      "$actual_source" "$destination" "$package" \
      "stage2-source" "$(receipt_value "$receipt" transaction)" "$(receipt_value "$receipt" repository)" \
      "$(receipt_value "$receipt" repository_id)" \
      "$(receipt_value "$receipt" github_owner)" "$(receipt_value "$receipt" github_login)" \
      "$(receipt_value "$receipt" github_account_binding_digest)" \
      "$(receipt_value "$receipt" repository_role)" "$(receipt_value "$receipt" parent_repository)" \
      "$(receipt_value "$receipt" exact_git_remote)" "$(receipt_value "$receipt" wiki_ref_digest)" \
      "$(receipt_value "$receipt" wiki_default_branch)" "$(receipt_value "$receipt" wiki_head_oid)" \
      "$(receipt_value "$receipt" original_source)" \
      "$(receipt_value "$receipt" filesystem_evidence)" \
      "$git_snapshot" "$git_snapshot_digest" "$git_ref_namespace" \
      "-" "-" "-" "-" \
      "$(receipt_value "$receipt" filesystem_manifest_digest)" \
      "$(receipt_value "$receipt" filesystem_evidence_digest)" \
      "$(receipt_value "$receipt" filesystem_binding_digest)" \
      "$(receipt_value "$receipt" filesystem_source_tree_digest)" \
      "$(receipt_value "$receipt" filesystem_source_device)" \
      "$(receipt_value "$receipt" filesystem_source_inode)" \
      "$(receipt_value "$receipt" filesystem_evidence)" > "$result_file"; then
    rm -f -- "$result_file" "$seen_file"
    VERIFICATION_FAILURE_REASON="Stage 2 filesystem evidence package, live manifest, source identity, or representative verification failed."
    return 1
  fi
  while IFS='=' read -r key value; do
    printf '%s\n' "$key" >> "$seen_file" || { rm -f -- "$result_file" "$seen_file"; return 1; }
    case "$key" in
      binding_digest) [[ "$value" == "$(receipt_value "$receipt" filesystem_binding_digest)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      destination_device) [[ "$value" == "$(receipt_value "$receipt" filesystem_destination_device)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      destination_owners_enabled) [[ "$value" == "$(receipt_value "$receipt" filesystem_destination_owners_enabled)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      destination_volume_uuid) [[ "$value" == "$(receipt_value "$receipt" filesystem_destination_volume_uuid)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      evidence_digest) [[ "$value" == "$(receipt_value "$receipt" filesystem_evidence_digest)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      exact_categories) [[ "$value" == "$(receipt_value "$receipt" filesystem_exact_categories)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      manifest_digest) [[ "$value" == "$(receipt_value "$receipt" filesystem_manifest_digest)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      record_only_categories) [[ "$value" == "$(receipt_value "$receipt" filesystem_record_only_categories)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      source_device) [[ "$value" == "$(receipt_value "$receipt" filesystem_source_device)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      source_inode) [[ "$value" == "$(receipt_value "$receipt" filesystem_source_inode)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      source_path_hex) [[ "$value" == "$(receipt_value "$receipt" filesystem_source_path_hex)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      source_tree_digest) [[ "$value" == "$(receipt_value "$receipt" filesystem_source_tree_digest)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      unsupported_categories) [[ "$value" == "$(receipt_value "$receipt" filesystem_unsupported_categories)" ]] || { rm -f -- "$result_file" "$seen_file"; return 1; } ;;
      *) rm -f -- "$result_file" "$seen_file"; return 1 ;;
    esac
  done < "$result_file"
  [[ "$(wc -l < "$seen_file" | tr -d ' ')" == "13" &&
     "$(LC_ALL=C sort -u "$seen_file" | wc -l | tr -d ' ')" == "13" ]] || {
    rm -f -- "$result_file" "$seen_file"
    return 1
  }
  rm -f -- "$result_file" "$seen_file"
  return 0
}

ensure_real_directory_chain() {
  local root="$1"
  local relative="$2"
  local current="$root"
  local part=""
  local parts=()

  [[ -d "$root" && ! -L "$root" && -n "$relative" && "$relative" != /* ]] || return 1
  IFS='/' read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != "." && "$part" != ".." ]] || return 1
    current="$current/$part"
    if [[ -e "$current" || -L "$current" ]]; then
      [[ -d "$current" && ! -L "$current" ]] || return 1
    else
      mkdir -m 700 -- "$current" || return 1
    fi
    [[ "$(canonical_existing_path "$current")" == "$current" ]] || return 1
  done
  printf '%s' "$current"
}

prepare_managed_stage3_evidence_root() {
  local root=""
  if [[ ! -e "$MANAGED_TEMP_ROOT" && ! -L "$MANAGED_TEMP_ROOT" ]]; then
    mkdir -m 700 -- "$MANAGED_TEMP_ROOT" || return 1
    MANAGED_TEMP_ROOT="$(canonical_existing_path "$MANAGED_TEMP_ROOT")" || return 1
    MANAGED_TEMP_CANONICAL="$MANAGED_TEMP_ROOT"
    MANAGED_TEMP_PRESENT=1
  fi
  [[ -d "$MANAGED_TEMP_ROOT" && ! -L "$MANAGED_TEMP_ROOT" ]] || return 1
  root="$(ensure_real_directory_chain "$MANAGED_TEMP_ROOT" ".csa-iem-recovery/filesystem-evidence/v2/stage3")" || return 1
  printf '%s' "$root"
}

emit_stage1_evidence_finalization() {
  local destination="$1"
  local stage1_receipt="$2"
  local stage2_receipt="$3"
  printf 'format=1\n'
  printf 'schema=csa-iem-stage3-evidence-finalization-v1\n'
  printf 'status=finalized\n'
  printf 'transaction=%s\n' "$TRANSACTION_ID"
  printf 'package_relative=%s\n' "$CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE"
  printf 'package_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST"
  printf 'manifest_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST"
  printf 'binding_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST"
  printf 'source_tree_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST"
  printf 'source_path_hex=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX"
  printf 'source_device=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE"
  printf 'source_inode=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE"
  printf 'destination_path_hex=%s\n' "$(printf '%s' "$destination" | hex_encode)"
  printf 'stage1_receipt_path_hex=%s\n' "$(printf '%s' "$stage1_receipt" | hex_encode)"
  printf 'stage1_receipt_digest=%s\n' "$CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST"
  printf 'stage2_receipt_path_hex=%s\n' "$(printf '%s' "$stage2_receipt" | hex_encode)"
  printf 'stage2_receipt_digest=%s\n' "$CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST"
  printf 'github_host=%s\n' "$GITHUB_HOST"
  printf 'github_owner=%s\n' "$CURRENT_STAGE3_GITHUB_OWNER"
  printf 'github_login=%s\n' "$CURRENT_STAGE3_GITHUB_LOGIN"
  printf 'github_account_binding_digest=%s\n' "$CURRENT_STAGE3_GITHUB_ACCOUNT_BINDING_DIGEST"
  printf 'repository_role=%s\n' "$CURRENT_STAGE3_REPOSITORY_ROLE"
  printf 'parent_repository=%s\n' "$CURRENT_STAGE3_PARENT_REPOSITORY"
  printf 'parent_repository_id=%s\n' "$(receipt_value "$stage2_receipt" repository_id)"
  printf 'exact_git_remote=%s\n' "$CURRENT_STAGE3_EXACT_GIT_REMOTE"
  printf 'wiki_ref_digest=%s\n' "$CURRENT_STAGE3_WIKI_REF_DIGEST"
  printf 'wiki_default_branch=%s\n' "$CURRENT_STAGE3_WIKI_DEFAULT_BRANCH"
  printf 'wiki_head_oid=%s\n' "$CURRENT_STAGE3_WIKI_HEAD_OID"
}

verify_stage1_evidence_finalization() {
  local destination="$1"
  local stage1_receipt="$2"
  local stage2_receipt="$3"
  local expected=""
  local actual_digest=""
  [[ "$CURRENT_STAGE3_FILESYSTEM_DURABLE" -eq 1 &&
     -d "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" && ! -L "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" &&
     -f "$CURRENT_STAGE3_FINALIZATION_RECEIPT" && ! -L "$CURRENT_STAGE3_FINALIZATION_RECEIPT" ]] || return 1
  [[ "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" == "$MANAGED_TEMP_ROOT/$CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE" &&
     "$CURRENT_STAGE3_FINALIZATION_RECEIPT" == "$CURRENT_STAGE3_FILESYSTEM_PACKAGE/final.receipt" ]] || return 1
  path_is_strictly_within "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" "$MANAGED_TEMP_ROOT/.csa-iem-recovery" || return 1
  expected="$(mktemp "$TMP_ROOT/stage1-evidence-finalization-expected.XXXXXX")" || return 1
  emit_stage1_evidence_finalization "$destination" "$stage1_receipt" "$stage2_receipt" > "$expected" || {
    rm -f -- "$expected"
    return 1
  }
  cmp -s "$expected" "$CURRENT_STAGE3_FINALIZATION_RECEIPT" || {
    rm -f -- "$expected"
    return 1
  }
  rm -f -- "$expected"
  actual_digest="$(sha256_regular_file "$CURRENT_STAGE3_FINALIZATION_RECEIPT")" || return 1
  [[ "$actual_digest" == "$CURRENT_STAGE3_FINALIZATION_DIGEST" ]]
}

write_stage1_evidence_finalization() {
  local destination="$1"
  local stage1_receipt="$2"
  local stage2_receipt="$3"
  local receipt="$CURRENT_STAGE3_FILESYSTEM_PACKAGE/final.receipt"
  local partial="$CURRENT_STAGE3_FILESYSTEM_PACKAGE/.final.receipt.partial.$$"
  [[ "$CURRENT_STAGE3_FILESYSTEM_DURABLE" -eq 0 &&
     -d "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" && ! -L "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" &&
     ! -e "$receipt" && ! -L "$receipt" && ! -e "$partial" && ! -L "$partial" ]] || return 1
  path_is_strictly_within "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" "$MANAGED_TEMP_ROOT/.csa-iem-recovery" || return 1
  emit_stage1_evidence_finalization "$destination" "$stage1_receipt" "$stage2_receipt" > "$partial" || {
    rm -f -- "$partial"
    return 1
  }
  chmod 600 "$partial" || { rm -f -- "$partial"; return 1; }
  mv -- "$partial" "$receipt" || { rm -f -- "$partial"; return 1; }
  CURRENT_STAGE3_FINALIZATION_RECEIPT="$receipt"
  CURRENT_STAGE3_FINALIZATION_DIGEST="$(sha256_regular_file "$receipt")" || return 1
  valid_sha256_digest "$CURRENT_STAGE3_FINALIZATION_DIGEST" || return 1
  CURRENT_STAGE3_FILESYSTEM_DURABLE=1
  verify_stage1_evidence_finalization "$destination" "$stage1_receipt" "$stage2_receipt"
}

verify_current_stage1_filesystem_evidence() {
  local source="$1"
  local destination="$2"
  local stage1_receipt="$3"
  local stage2_receipt="$4"
  local git_snapshot="-"
  local git_snapshot_digest="-"
  local git_ref_namespace="-"
  local result_file=""

  [[ -d "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" && ! -L "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" ]] || return 1
  [[ "$CURRENT_STAGE3_FILESYSTEM_BINDING_SOURCE" != "" &&
     "$CURRENT_STAGE3_CHAIN_RECEIPT" == "$stage2_receipt" &&
     "$CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST" == "$(sha256_regular_file "$stage1_receipt")" &&
     "$CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST" == "$(sha256_regular_file "$stage2_receipt")" ]] || return 1
  verify_receipt_github_identity_live "$stage2_receipt" || return 1
  if [[ "$source" != "-" ]]; then
    [[ -d "$source" && ! -L "$source" ]] || return 1
    prepare_git_fsmonitor_for_evidence "$source" || return 1
  fi
  [[ -z "$(receipt_value "$stage2_receipt" git_snapshot)" ]] || git_snapshot="$(receipt_value "$stage2_receipt" git_snapshot)"
  [[ -z "$(receipt_value "$stage2_receipt" git_snapshot_digest)" ]] || git_snapshot_digest="$(receipt_value "$stage2_receipt" git_snapshot_digest)"
  [[ -z "$(receipt_value "$stage2_receipt" git_ref_namespace)" ]] || git_ref_namespace="$(receipt_value "$stage2_receipt" git_ref_namespace)"
  result_file="$(mktemp "$TMP_ROOT/stage1-filesystem-evidence-verify.XXXXXX")" || return 1
  if ! filesystem_evidence_helper verify \
      "$source" "$destination" "$CURRENT_STAGE3_FILESYSTEM_PACKAGE" \
      "stage3-stage1-original" "$TRANSACTION_ID" "$(receipt_value "$stage2_receipt" repository)" \
      "$(receipt_value "$stage2_receipt" repository_id)" \
      "$(receipt_value "$stage2_receipt" github_owner)" "$(receipt_value "$stage2_receipt" github_login)" \
      "$(receipt_value "$stage2_receipt" github_account_binding_digest)" \
      "$(receipt_value "$stage2_receipt" repository_role)" "$(receipt_value "$stage2_receipt" parent_repository)" \
      "$(receipt_value "$stage2_receipt" exact_git_remote)" "$(receipt_value "$stage2_receipt" wiki_ref_digest)" \
      "$(receipt_value "$stage2_receipt" wiki_default_branch)" "$(receipt_value "$stage2_receipt" wiki_head_oid)" \
      "$CURRENT_STAGE3_FILESYSTEM_BINDING_SOURCE" \
      "$CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE" \
      "$git_snapshot" "$git_snapshot_digest" "$git_ref_namespace" \
      "$stage1_receipt" "$CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST" \
      "$stage2_receipt" "$CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST" \
      "$CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST" "$CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST" \
      "$CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST" "$CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST" \
      "$CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE" "$CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE" \
      "$CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE" > "$result_file"; then
    rm -f -- "$result_file"
    VERIFICATION_FAILURE_REASON="Fresh Stage 3 Stage1-original filesystem evidence drifted or no longer verifies."
    return 1
  fi
  rm -f -- "$result_file"
  if [[ "$CURRENT_STAGE3_FILESYSTEM_DURABLE" -eq 1 ]]; then
    verify_stage1_evidence_finalization "$destination" "$stage1_receipt" "$stage2_receipt" || {
      VERIFICATION_FAILURE_REASON="Durable Stage 1 evidence finalization receipt drifted or is missing."
      return 1
    }
  fi
}

capture_stage1_filesystem_evidence() {
  local source="$1"
  local destination="$2"
  local stage1_receipt="$3"
  local stage2_receipt="$4"
  local durable="${5:-0}"
  local repository=""
  local repository_id=""
  local stage1_digest=""
  local stage2_digest=""
  local receipt_token=""
  local package_relative=""
  local package_parent=""
  local package=""
  local partial=""
  local git_snapshot="-"
  local git_snapshot_digest="-"
  local git_ref_namespace="-"
  local result_file=""

  reset_current_stage3_filesystem_evidence
  verify_stage2_filesystem_evidence "$stage2_receipt" "" "$destination" || return 1
  repository="$(receipt_value "$stage2_receipt" repository)"
  repository_id="$(receipt_value "$stage2_receipt" repository_id)"
  safe_project_relative_path "$repository" || return 1
  stage1_digest="$(sha256_regular_file "$stage1_receipt")" || return 1
  stage2_digest="$(sha256_regular_file "$stage2_receipt")" || return 1
  receipt_token="$(printf '%s' "$stage1_digest:$stage2_digest" | shasum -a 256 | awk 'NR == 1 { print $1 }')"
  valid_sha256_digest "$receipt_token" || return 1
  package_relative=".csa-iem-recovery/filesystem-evidence/v2/stage3/$TRANSACTION_ID/$repository/stage1-$receipt_token"
  if [[ "$durable" == "1" ]]; then
    prepare_managed_stage3_evidence_root >/dev/null || return 1
    package_parent="$(ensure_real_directory_chain "$MANAGED_TEMP_ROOT" ".csa-iem-recovery/filesystem-evidence/v2/stage3/$TRANSACTION_ID/$repository")" || return 1
    package="$MANAGED_TEMP_ROOT/$package_relative"
    partial="$package.partial.$$"
    [[ ! -e "$package" && ! -L "$package" && ! -e "$partial" && ! -L "$partial" ]] || return 1
  else
    package_parent="$(mktemp -d "$TMP_ROOT/stage1-evidence.XXXXXX")" || return 1
    package="$package_parent/package"
    partial="$package"
  fi
  prepare_git_fsmonitor_for_evidence "$source" || return 1
  [[ -z "$(receipt_value "$stage2_receipt" git_snapshot)" ]] || git_snapshot="$(receipt_value "$stage2_receipt" git_snapshot)"
  [[ -z "$(receipt_value "$stage2_receipt" git_snapshot_digest)" ]] || git_snapshot_digest="$(receipt_value "$stage2_receipt" git_snapshot_digest)"
  [[ -z "$(receipt_value "$stage2_receipt" git_ref_namespace)" ]] || git_ref_namespace="$(receipt_value "$stage2_receipt" git_ref_namespace)"
  result_file="$(mktemp "$TMP_ROOT/stage1-filesystem-evidence-capture.XXXXXX")" || return 1
  if ! filesystem_evidence_helper capture \
      "$source" "$destination" "$partial" \
      "stage3-stage1-original" "$TRANSACTION_ID" "$repository" "$repository_id" \
      "$(receipt_value "$stage2_receipt" github_owner)" "$(receipt_value "$stage2_receipt" github_login)" \
      "$(receipt_value "$stage2_receipt" github_account_binding_digest)" \
      "$(receipt_value "$stage2_receipt" repository_role)" "$(receipt_value "$stage2_receipt" parent_repository)" \
      "$(receipt_value "$stage2_receipt" exact_git_remote)" "$(receipt_value "$stage2_receipt" wiki_ref_digest)" \
      "$(receipt_value "$stage2_receipt" wiki_default_branch)" "$(receipt_value "$stage2_receipt" wiki_head_oid)" \
      "$source" "$package_relative" \
      "$git_snapshot" "$git_snapshot_digest" "$git_ref_namespace" \
      "$stage1_receipt" "$stage1_digest" "$stage2_receipt" "$stage2_digest" > "$result_file"; then
    [[ "$durable" == "1" ]] && rm -rf -- "$partial"
    rm -f -- "$result_file"
    VERIFICATION_FAILURE_REASON="Fresh Stage1-original filesystem evidence capture failed."
    return 1
  fi
  load_stage3_filesystem_evidence_result "$result_file" || {
    [[ "$durable" == "1" ]] && rm -rf -- "$partial"
    rm -f -- "$result_file"
    return 1
  }
  rm -f -- "$result_file"
  if [[ "$durable" == "1" ]]; then
    mv -- "$partial" "$package" || return 1
  fi
  CURRENT_STAGE3_FILESYSTEM_EVIDENCE="$package_relative"
  CURRENT_STAGE3_FILESYSTEM_BINDING_SOURCE="$source"
  CURRENT_STAGE3_FILESYSTEM_PACKAGE_RELATIVE="$package_relative"
  CURRENT_STAGE3_CHAIN_RECEIPT="$stage2_receipt"
  CURRENT_STAGE3_FILESYSTEM_PACKAGE="$package"
  CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST="$stage1_digest"
  CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST="$stage2_digest"
  if ! verify_current_stage1_filesystem_evidence "$source" "$destination" "$stage1_receipt" "$stage2_receipt"; then
    return 1
  fi
  if [[ "$durable" == "1" ]]; then
    write_stage1_evidence_finalization "$destination" "$stage1_receipt" "$stage2_receipt" || return 1
    verify_current_stage1_filesystem_evidence "$source" "$destination" "$stage1_receipt" "$stage2_receipt" || return 1
  fi
}

directory_contains_exact_entry() {
  local parent="$1"
  local leaf="$2"
  local entries_file=""
  local entry=""
  [[ -d "$parent" && ! -L "$parent" && -n "$leaf" ]] || return 1
  entries_file="$(mktemp "$TMP_ROOT/exact-entries.XXXXXX")" || return 1
  if ! find "$parent" -mindepth 1 -maxdepth 1 -print0 > "$entries_file" 2>/dev/null; then
    rm -f -- "$entries_file"
    return 1
  fi
  while IFS= read -r -d '' entry; do
    if [[ "${entry##*/}" == "$leaf" ]]; then
      rm -f -- "$entries_file"
      return 0
    fi
  done < "$entries_file"
  rm -f -- "$entries_file"
  return 1
}

path_has_exact_relative_components() {
  local root="$1"
  local relative="$2"
  local current="$root"
  local part=""
  local parts=()
  [[ -d "$root" && ! -L "$root" && -n "$relative" && "$relative" != /* ]] || return 1
  IFS='/' read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != "." && "$part" != ".." ]] || return 1
    directory_contains_exact_entry "$current" "$part" || return 1
    current="$current/$part"
    [[ -e "$current" || -L "$current" ]] || return 1
  done
}

# tree-sha256-v1 is the SHA-256 of a C-locale sorted manifest. Each manifest
# row contains entry type, four-digit permission mode, hex-encoded relative
# path, and either a file SHA-256 or a hex-encoded symlink target. The root
# directory is represented by a D row with an empty path. This makes the
# receipt digest independent of enumeration order, timestamps, owners, and
# path control characters while preserving every byte and executable mode.
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
  root="$(canonical_existing_path "$requested_root")" || return 1
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

resolve_receipt_snapshot_path() {
  local destination="$1"
  local relative="$2"
  local recovery_root="$destination/.csa-iem-recovery"
  local requested_snapshot=""
  local canonical_recovery_root=""
  local canonical_snapshot=""

  safe_recovery_relative_path "$relative" || return 1
  [[ -d "$recovery_root" && ! -L "$recovery_root" ]] || return 1
  canonical_recovery_root="$(canonical_existing_path "$recovery_root")" || return 1
  [[ "$canonical_recovery_root" == "$recovery_root" ]] || return 1
  path_has_exact_relative_components "$destination" "$relative" || return 1
  requested_snapshot="$destination/$relative"
  [[ -d "$requested_snapshot" && ! -L "$requested_snapshot" ]] || return 1
  canonical_snapshot="$(canonical_existing_path "$requested_snapshot")" || return 1
  [[ "$canonical_snapshot" == "$requested_snapshot" ]] || return 1
  path_is_strictly_within "$canonical_snapshot" "$canonical_recovery_root" || return 1
  printf '%s' "$canonical_snapshot"
}

verify_tree_snapshot_evidence() {
  local source_tree="$1"
  local destination="$2"
  local receipt="$3"
  local path_field="$4"
  local digest_field="$5"
  local label="$6"
  local relative_snapshot=""
  local expected_digest=""
  local snapshot=""
  local source_digest=""
  local source_digest_after=""
  local snapshot_digest=""

  if [[ "$(receipt_field_count "$receipt" "$path_field")" != "1" ||
        "$(receipt_field_count "$receipt" "$digest_field")" != "1" ]]; then
    VERIFICATION_FAILURE_REASON="$label receipt evidence is missing or duplicated ($path_field and $digest_field are required exactly once)."
    return 1
  fi
  relative_snapshot="$(receipt_value "$receipt" "$path_field")"
  expected_digest="$(receipt_value "$receipt" "$digest_field")"
  valid_sha256_digest "$expected_digest" || {
    VERIFICATION_FAILURE_REASON="$label receipt digest must be exactly 64 lowercase hexadecimal SHA-256 characters."
    return 1
  }
  snapshot="$(resolve_receipt_snapshot_path "$destination" "$relative_snapshot")" || {
    VERIFICATION_FAILURE_REASON="$label snapshot is not a real canonical directory beneath destination/.csa-iem-recovery."
    return 1
  }
  source_digest="$(tree_digest "$source_tree")" || {
    VERIFICATION_FAILURE_REASON="$label source tree could not be deterministically digested."
    return 1
  }
  snapshot_digest="$(tree_digest "$snapshot")" || {
    VERIFICATION_FAILURE_REASON="$label snapshot tree could not be deterministically digested."
    return 1
  }
  source_digest_after="$(tree_digest "$source_tree")" || {
    VERIFICATION_FAILURE_REASON="$label source tree could not be re-digested after snapshot verification."
    return 1
  }
  if [[ "$source_digest" != "$expected_digest" || "$source_digest_after" != "$expected_digest" ||
        "$snapshot_digest" != "$expected_digest" ]]; then
    VERIFICATION_FAILURE_REASON="$label snapshot digest does not match both the live source tree and receipt evidence."
    return 1
  fi
}

verify_git_snapshot_evidence() {
  local source="$1"
  local destination="$2"
  local receipt="$3"
  verify_tree_snapshot_evidence "$source/.git" "$destination" "$receipt" "git_snapshot" "git_snapshot_digest" "Full Git"
}

verify_git_snapshot_integrity() {
  local destination="$1"
  local receipt="$2"
  local relative_snapshot=""
  local expected_digest=""
  local snapshot=""
  local actual_digest=""

  [[ "$(receipt_field_count "$receipt" git_snapshot)" == "1" &&
     "$(receipt_field_count "$receipt" git_snapshot_digest)" == "1" ]] || {
    VERIFICATION_FAILURE_REASON="Git snapshot receipt fields are missing or duplicated."
    return 1
  }
  relative_snapshot="$(receipt_value "$receipt" git_snapshot)"
  expected_digest="$(receipt_value "$receipt" git_snapshot_digest)"
  if [[ -z "$relative_snapshot" && -z "$expected_digest" ]]; then
    return 0
  fi
  valid_sha256_digest "$expected_digest" || return 1
  snapshot="$(resolve_receipt_snapshot_path "$destination" "$relative_snapshot")" || {
    VERIFICATION_FAILURE_REASON="Git snapshot is not a safe canonical recovery directory."
    return 1
  }
  actual_digest="$(tree_digest "$snapshot")" || return 1
  [[ "$actual_digest" == "$expected_digest" ]] || {
    VERIFICATION_FAILURE_REASON="Canonical Git snapshot digest changed."
    return 1
  }
}

verify_relocated_recovery_evidence() {
  local source="$1"
  local destination="$2"
  local receipt="$3"
  local source_recovery="$source/.csa-iem-recovery"
  if [[ ! -e "$source_recovery" && ! -L "$source_recovery" ]]; then
    return 0
  fi
  [[ -d "$source_recovery" && ! -L "$source_recovery" ]] || {
    VERIFICATION_FAILURE_REASON="Stage 1 source .csa-iem-recovery is not a real directory and cannot be cleanup-authoritative."
    return 1
  }
  verify_tree_snapshot_evidence "$source_recovery" "$destination" "$receipt" "source_recovery_snapshot" "source_recovery_snapshot_digest" "Relocated source recovery"
}

representation_path_is_excluded() {
  local relative="$1"
  local include_finder="$2"
  local include_dependencies="$3"
  local stage="$4"
  local leaf="${relative##*/}"
  if [[ "$stage" == "1" ]]; then
    if [[ "$relative" == "Transfer_Note.MD" || "$relative" == "Prompt_Inject.MD" ||
          "$relative" == ".csa-iem-recovery" || "$relative" == .csa-iem-recovery/* ]]; then
      return 0
    fi
  fi
  if [[ "$include_finder" != "1" && ( "$leaf" == ".DS_Store" || "$leaf" == ._* ) ]]; then
    return 0
  fi
  if [[ "$include_dependencies" != "1" ]]; then
    case "/$relative/" in
      */node_modules/*|*/vendor/*|*/.venv/*|*/venv/*|*/Pods/*|*/DerivedData/*|*/dist/*|*/build/*|*/.build/*|*/target/*|*/.next/*|*/.nuxt/*|*/.output/*|*/.turbo/*|*/coverage/*|*/.nyc_output/*|*/.cache/*|*/Caches/*|*/.parcel-cache/*|*/.vite/*|*/.npm/*|*/.pnpm-store/*|*/.swiftpm/*|*/.gradle/*|*/.terraform/*|*/.dart_tool/*|*/.pytest_cache/*|*/.tox/*|*/__pycache__/*)
        return 0
        ;;
    esac
  fi
  return 1
}

representation_path_manifest() {
  local root="$1"
  local include_finder="$2"
  local include_dependencies="$3"
  local stage="$4"
  local output="$5"
  local entries_file=""
  local entry=""
  local relative=""
  local path_hex=""
  local unsorted_file=""

  [[ -d "$root" && ! -L "$root" ]] || return 1
  entries_file="$(mktemp "$TMP_ROOT/representation-entries.XXXXXX")" || return 1
  unsorted_file="$(mktemp "$TMP_ROOT/representation-paths.XXXXXX")" || {
    rm -f -- "$entries_file"
    return 1
  }
  : > "$unsorted_file"
  if ! find "$root" -path "$root/.git" -prune -o -mindepth 1 -print0 > "$entries_file" 2>/dev/null; then
    rm -f -- "$entries_file" "$unsorted_file"
    return 1
  fi
  while IFS= read -r -d '' entry; do
    relative="${entry#"$root"/}"
    [[ "$relative" != "$entry" && -n "$relative" ]] || {
      rm -f -- "$entries_file" "$unsorted_file"
      return 1
    }
    representation_path_is_excluded "$relative" "$include_finder" "$include_dependencies" "$stage" && continue
    path_hex="$(printf '%s' "$relative" | hex_encode)" || {
      rm -f -- "$entries_file" "$unsorted_file"
      return 1
    }
    printf '%s\n' "$path_hex" >> "$unsorted_file"
  done < "$entries_file"
  if ! LC_ALL=C sort -u "$unsorted_file" > "$output"; then
    rm -f -- "$entries_file" "$unsorted_file"
    return 1
  fi
  rm -f -- "$entries_file" "$unsorted_file"
}

verify_exact_path_spelling_represented() {
  local source="$1"
  local destination="$2"
  local include_finder="$3"
  local include_dependencies="$4"
  local stage="$5"
  local source_manifest=""
  local destination_manifest=""
  local missing_manifest=""

  source_manifest="$(mktemp "$TMP_ROOT/source-paths.XXXXXX")" || return 1
  destination_manifest="$(mktemp "$TMP_ROOT/destination-paths.XXXXXX")" || return 1
  missing_manifest="$(mktemp "$TMP_ROOT/missing-paths.XXXXXX")" || return 1
  representation_path_manifest "$source" "$include_finder" "$include_dependencies" "$stage" "$source_manifest" || return 1
  representation_path_manifest "$destination" "$include_finder" "$include_dependencies" "$stage" "$destination_manifest" || return 1
  comm -23 "$source_manifest" "$destination_manifest" > "$missing_manifest" || return 1
  [[ ! -s "$missing_manifest" ]]
}

verify_filesystem_metadata_represented() {
  local source="$1"
  local destination="$2"
  local include_finder="$3"
  local include_dependencies="$4"
  local stage="$5"
  local entries_file=""
  local source_path=""
  local destination_path=""
  local relative=""
  local source_exec=""
  local destination_exec=""
  local source_target=""
  local destination_target=""

  entries_file="$(mktemp "$TMP_ROOT/filesystem-metadata.XXXXXX")" || return 1
  if ! find "$source" -path "$source/.git" -prune -o -print0 > "$entries_file" 2>/dev/null; then
    rm -f -- "$entries_file"
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
    representation_path_is_excluded "$relative" "$include_finder" "$include_dependencies" "$stage" && continue

    if [[ -L "$source_path" ]]; then
      [[ -L "$destination_path" ]] || { rm -f -- "$entries_file"; return 1; }
      source_target="$(readlink "$source_path")" || { rm -f -- "$entries_file"; return 1; }
      destination_target="$(readlink "$destination_path")" || { rm -f -- "$entries_file"; return 1; }
      [[ "$source_target" == "$destination_target" ]] || { rm -f -- "$entries_file"; return 1; }
      continue
    fi
    if [[ -d "$source_path" ]]; then
      [[ -d "$destination_path" && ! -L "$destination_path" ]] || { rm -f -- "$entries_file"; return 1; }
      continue
    fi
    [[ -f "$source_path" && ! -L "$source_path" && -f "$destination_path" && ! -L "$destination_path" ]] || {
      rm -f -- "$entries_file"
      return 1
    }
    if [[ "$stage" != "1" ]]; then
      source_exec="$(executable_permission_bits "$source_path")" || { rm -f -- "$entries_file"; return 1; }
      destination_exec="$(executable_permission_bits "$destination_path")" || { rm -f -- "$entries_file"; return 1; }
      [[ "$source_exec" == "$destination_exec" ]] || { rm -f -- "$entries_file"; return 1; }
    fi
  done < "$entries_file"
  rm -f -- "$entries_file"
}

git_environment_is_self_contained() {
  [[ -z "${GIT_DIR:-}" && -z "${GIT_WORK_TREE:-}" && -z "${GIT_COMMON_DIR:-}" &&
     -z "${GIT_OBJECT_DIRECTORY:-}" && -z "${GIT_ALTERNATE_OBJECT_DIRECTORIES:-}" &&
     -z "${GIT_INDEX_FILE:-}" && -z "${GIT_NAMESPACE:-}" &&
     -z "${GIT_REPLACE_REF_BASE:-}" && -z "${GIT_CONFIG_PARAMETERS:-}" &&
     -z "${GIT_CONFIG_COUNT:-}" && -z "${GIT_CONFIG_GLOBAL:-}" &&
     -z "${GIT_CONFIG_SYSTEM:-}" && -z "${GIT_CONFIG_NOSYSTEM:-}" &&
     -z "${GIT_ATTR_NOSYSTEM:-}" && -z "${GIT_NO_REPLACE_OBJECTS:-}" &&
     -z "${GIT_EXTERNAL_DIFF:-}" && -z "${GIT_DIFF_OPTS:-}" &&
     -z "${GIT_SHALLOW_FILE:-}" && -z "${GIT_GRAFT_FILE:-}" &&
     -z "${GIT_CEILING_DIRECTORIES:-}" && -z "${GIT_DISCOVERY_ACROSS_FILESYSTEM:-}" ]]
}

isolated_git() {
  [[ -n "$GIT_BIN" && -x "$GIT_BIN" && -n "$TMP_ROOT" ]] || return 1
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
    "$GIT_BIN" "$@"
}

git_output_path() {
  local repository="$1"
  local value="$2"
  case "$value" in
    /*) printf '%s' "$value" ;;
    *) printf '%s/%s' "$repository" "$value" ;;
  esac
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
  isolated_git config --no-includes --file "$config" --get-regexp '^fsck\.' >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get-regexp '^remote\..*\.promisor$' >/dev/null 2>&1 && return 1
  isolated_git config --no-includes --file "$config" --get-regexp '^(include|includeIf\..*)\.path$' >/dev/null 2>&1 && return 1
  return 0
}

git_repository_is_self_contained() {
  local repository="$1"
  local git_dir="$repository/.git"
  local canonical_git_dir=""
  local raw_git_dir=""
  local raw_common_dir=""
  local common_dir=""
  local raw_objects_dir=""
  local objects_dir=""
  local raw_index_path=""
  local index_path=""
  local top_level=""
  local superproject=""
  local config=""

  git_environment_is_self_contained || return 1
  [[ -d "$repository" && ! -L "$repository" && -d "$git_dir" && ! -L "$git_dir" ]] || return 1
  canonical_git_dir="$(canonical_existing_path "$git_dir")" || return 1
  [[ "$canonical_git_dir" == "$git_dir" ]] || return 1
  [[ -z "$(find "$git_dir" -type l -print -quit 2>/dev/null)" ]] || return 1
  [[ ! -e "$git_dir/commondir" && ! -L "$git_dir/commondir" ]] || return 1
  [[ ! -e "$git_dir/objects/info/alternates" && ! -L "$git_dir/objects/info/alternates" ]] || return 1
  [[ ! -e "$git_dir/objects/info/http-alternates" && ! -L "$git_dir/objects/info/http-alternates" ]] || return 1
  if [[ -d "$git_dir/worktrees" && -n "$(find "$git_dir/worktrees" -mindepth 1 -print -quit 2>/dev/null)" ]]; then return 1; fi
  if [[ -d "$git_dir/modules" && -n "$(find "$git_dir/modules" -mindepth 1 -print -quit 2>/dev/null)" ]]; then return 1; fi

  raw_git_dir="$(isolated_git -C "$repository" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  [[ "$(canonical_existing_path "$raw_git_dir" 2>/dev/null || true)" == "$git_dir" ]] || return 1
  raw_common_dir="$(isolated_git -C "$repository" rev-parse --git-common-dir 2>/dev/null)" || return 1
  common_dir="$(git_output_path "$repository" "$raw_common_dir")"
  [[ "$(canonical_existing_path "$common_dir" 2>/dev/null || true)" == "$git_dir" ]] || return 1
  raw_objects_dir="$(isolated_git -C "$repository" rev-parse --git-path objects 2>/dev/null)" || return 1
  objects_dir="$(git_output_path "$repository" "$raw_objects_dir")"
  [[ -d "$objects_dir" && ! -L "$objects_dir" ]] || return 1
  [[ "$(canonical_existing_path "$objects_dir" 2>/dev/null || true)" == "$git_dir/objects" ]] || return 1
  raw_index_path="$(isolated_git -C "$repository" rev-parse --git-path index 2>/dev/null)" || return 1
  index_path="$(git_output_path "$repository" "$raw_index_path")"
  [[ -f "$index_path" && ! -L "$index_path" ]] || return 1
  [[ "$(canonical_existing_path "$index_path" 2>/dev/null || true)" == "$git_dir/index" ]] || return 1
  top_level="$(isolated_git -C "$repository" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [[ "$(canonical_existing_path "$top_level" 2>/dev/null || true)" == "$repository" ]] || return 1
  [[ "$(isolated_git -C "$repository" rev-parse --is-inside-work-tree 2>/dev/null || true)" == "true" ]] || return 1
  [[ "$(isolated_git -C "$repository" rev-parse --is-bare-repository 2>/dev/null || true)" == "false" ]] || return 1
  superproject="$(isolated_git -C "$repository" rev-parse --show-superproject-working-tree 2>/dev/null || true)"
  [[ -z "$superproject" ]] || return 1

  git_local_config_is_self_contained "$git_dir/config" || return 1
  if [[ -e "$git_dir/config.worktree" || -L "$git_dir/config.worktree" ]]; then
    git_local_config_is_self_contained "$git_dir/config.worktree" || return 1
  fi
  return 0
}

git_index_is_clean_and_plain() {
  local repository="$1"
  local stage_file=""
  local tag_file=""
  local fsmonitor_file=""
  local resolve_undo_file=""
  local record=""
  local metadata=""
  local index_mode=""
  local object_id=""
  local stage_number=""

  [[ -z "$(find "$repository/.git" -maxdepth 1 -type f \( -name 'sharedindex.*' -o -name 'sharedindex.*.lock' \) -print -quit 2>/dev/null)" ]] || return 1
  isolated_git -C "$repository" diff --cached --quiet --no-ext-diff --no-textconv --ita-visible-in-index --ignore-submodules=none -- 2>/dev/null || return 1
  stage_file="$(mktemp "$TMP_ROOT/index-stage.XXXXXX")" || return 1
  isolated_git -C "$repository" ls-files --stage -z > "$stage_file" 2>/dev/null || return 1
  while IFS= read -r -d '' record; do
    [[ "$record" == *$'\t'* ]] || return 1
    metadata="${record%%$'\t'*}"
    set -- $metadata
    [[ "$#" -eq 3 ]] || return 1
    index_mode="$1"
    object_id="$2"
    stage_number="$3"
    [[ "$index_mode" != "040000" && "$stage_number" == "0" && -n "$object_id" && -n "${object_id//0/}" ]] || return 1
  done < "$stage_file"

  tag_file="$(mktemp "$TMP_ROOT/index-tags.XXXXXX")" || return 1
  isolated_git -C "$repository" ls-files -v -z > "$tag_file" 2>/dev/null || return 1
  while IFS= read -r -d '' record; do
    case "$record" in H\ *) ;; *) return 1 ;; esac
  done < "$tag_file"

  fsmonitor_file="$(mktemp "$TMP_ROOT/index-fsmonitor.XXXXXX")" || return 1
  isolated_git -C "$repository" ls-files -f -z > "$fsmonitor_file" 2>/dev/null || return 1
  while IFS= read -r -d '' record; do
    case "$record" in H\ *) ;; *) return 1 ;; esac
  done < "$fsmonitor_file"

  resolve_undo_file="$(mktemp "$TMP_ROOT/index-resolve-undo.XXXXXX")" || return 1
  isolated_git -C "$repository" ls-files --resolve-undo -z > "$resolve_undo_file" 2>/dev/null || return 1
  [[ ! -s "$resolve_undo_file" ]]
}

safe_git_ref_namespace() {
  local value="$1"
  [[ -z "$value" ]] && return 0
  [[ "$value" == refs/* && "$value" != */ &&
     "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *$'\t'* ]] || return 1
  isolated_git check-ref-format "$value/probe" >/dev/null 2>&1
}

destination_ref_matches_source() {
  local destination_refs_file="$1"
  local object_id="$2"
  local ref_name="$3"
  local git_ref_namespace="$4"
  local suffix=""
  local namespaced_ref=""

  [[ -n "$object_id" && "$ref_name" == refs/* ]] || return 1
  grep -Fqx -- "$object_id $ref_name" "$destination_refs_file" && return 0
  [[ -n "$git_ref_namespace" ]] || return 1
  suffix="${ref_name#refs/}"
  namespaced_ref="$git_ref_namespace/$suffix"
  isolated_git check-ref-format "$namespaced_ref" >/dev/null 2>&1 || return 1
  grep -Fqx -- "$object_id $namespaced_ref" "$destination_refs_file"
}

strict_source_git_fsck_once() {
  local source="$1"
  local key=""
  local marker=""
  local current_digest=""
  local recorded_digest=""
  local source_device=""
  local source_inode=""

  source_device="$(device_id "$source")" || return 1
  if [[ "$(uname -s)" == "Darwin" ]]; then
    source_inode="$(stat -f '%i' "$source" 2>/dev/null)" || return 1
  else
    source_inode="$(stat -c '%i' "$source" 2>/dev/null)" || return 1
  fi
  key="$(printf '%s:%s' "$source_device" "$source_inode" | shasum -a 256 | awk 'NR == 1 { print $1 }')"
  valid_sha256_digest "$key" || return 1
  marker="$TMP_ROOT/source-fsck-$key"
  current_digest="$(tree_digest "$source/.git")" || return 1
  if [[ -f "$marker" && ! -L "$marker" ]]; then
    recorded_digest="$(awk 'NR == 1 { print $1; exit }' "$marker")"
    [[ "$recorded_digest" == "$current_digest" ]]
    return
  fi
  isolated_git -c core.multiPackIndex=false -C "$source" fsck --full --strict --no-dangling >/dev/null 2>&1 || return 1
  printf '%s\n' "$current_digest" > "$marker"
}

final_destination_git_fsck_once() {
  local destination="$1"
  local receipt="$2"
  local key=""
  local marker=""
  local current_digest=""
  local recorded_digest=""

  key="$(printf '%s|%s|%s' "$destination" "$(receipt_value "$receipt" repository_id)" "$(receipt_value "$receipt" repository_role)" | shasum -a 256 | awk 'NR == 1 { print $1 }')"
  valid_sha256_digest "$key" || return 1
  marker="$TMP_ROOT/destination-fsck-$key"
  current_digest="$(tree_digest "$destination/.git")" || return 1
  if [[ -f "$marker" && ! -L "$marker" ]]; then
    recorded_digest="$(awk 'NR == 1 { print $1; exit }' "$marker")"
    [[ "$recorded_digest" == "$current_digest" ]]
    return
  fi
  isolated_git -c core.multiPackIndex=false -C "$destination" fsck --full --strict --no-dangling >/dev/null 2>&1 || return 1
  printf '%s\n' "$current_digest" > "$marker"
}

verify_git_objects_represented() {
  local source="$1"
  local destination="$2"
  local include_git="$3"
  local receipt="$4"
  local git_ref_namespace="$5"
  local stage="$6"
  local source_head=""
  local source_remote=""
  local destination_remote=""
  local object_id=""
  local ref_name=""
  local refs_file=""
  local destination_refs_file=""
  local objects_file=""
  local lfs_files=""
  local lfs_object=""
  local lfs_relative=""
  local operation_marker=""

  [[ "$stage" == "1" || "$stage" == "2" ]] || return 1
  if [[ ! -e "$source/.git" && ! -L "$source/.git" ]]; then return 0; fi
  prepare_git_fsmonitor_for_evidence "$source" || return 1
  prepare_git_fsmonitor_for_evidence "$destination" || return 1
  [[ -d "$source/.git" && ! -L "$source/.git" ]] || {
    VERIFICATION_FAILURE_REASON="Source .git exists but is not a real local directory."
    return 1
  }
  [[ "$include_git" == "1" ]] || {
    VERIFICATION_FAILURE_REASON="Git source cleanup requires include_git=1."
    return 1
  }
  [[ "$(receipt_field_count "$receipt" git_ref_namespace)" -le 1 ]] || {
    VERIFICATION_FAILURE_REASON="git_ref_namespace must appear at most once in a receipt."
    return 1
  }
  safe_git_ref_namespace "$git_ref_namespace" || {
    VERIFICATION_FAILURE_REASON="git_ref_namespace is not a valid Git refs namespace."
    return 1
  }
  git_repository_is_self_contained "$source" || {
    VERIFICATION_FAILURE_REASON="Source Git metadata uses a pointer, symlink, alternate, commondir, worktree/module store, partial clone, external config, or process-level Git dependency."
    return 1
  }
  git_repository_is_self_contained "$destination" || {
    VERIFICATION_FAILURE_REASON="Canonical Git metadata uses a pointer, symlink, alternate, commondir, worktree/module store, partial clone, external config, or process-level Git dependency."
    return 1
  }
  for operation_marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG rebase-apply rebase-merge sequencer index.lock; do
    [[ ! -e "$source/.git/$operation_marker" && ! -L "$source/.git/$operation_marker" ]] || {
      VERIFICATION_FAILURE_REASON="Source Git operation state is in progress: $operation_marker."
      return 1
    }
    [[ ! -e "$destination/.git/$operation_marker" && ! -L "$destination/.git/$operation_marker" ]] || {
      VERIFICATION_FAILURE_REASON="Canonical Git operation state is in progress: $operation_marker."
      return 1
    }
  done
  git_index_is_clean_and_plain "$source" || {
    VERIFICATION_FAILURE_REASON="Source Git index has staged, conflicted, intent-to-add, assume-unchanged, skip-worktree, fsmonitor-valid, or resolve-undo state."
    return 1
  }
  git_index_is_clean_and_plain "$destination" || {
    VERIFICATION_FAILURE_REASON="Canonical Git index has staged, conflicted, intent-to-add, assume-unchanged, skip-worktree, fsmonitor-valid, or resolve-undo state."
    return 1
  }
  if [[ "$stage" == "2" ]]; then
    verify_git_snapshot_evidence "$source" "$destination" "$receipt" || return 1
  else
    # A chained Stage 1 original is not metadata-equivalent to the Stage 2
    # source copy. Its fresh Stage 3 manifest preserves the original bytes and
    # metadata; the selected Stage 2 Git snapshot is verified independently.
    verify_git_snapshot_integrity "$destination" "$receipt" || return 1
    strict_source_git_fsck_once "$source" || {
      VERIFICATION_FAILURE_REASON="Stage 1 original Git object database failed its one strict fsck."
      return 1
    }
  fi
  source_head="$(isolated_git -C "$source" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$source_head" ]] || {
    VERIFICATION_FAILURE_REASON="Source Git HEAD is unavailable."
    return 1
  }
  isolated_git -C "$destination" cat-file -e "$source_head^{commit}" 2>/dev/null || {
    VERIFICATION_FAILURE_REASON="Canonical Git object database does not contain source HEAD."
    return 1
  }
  source_remote="$(normalize_remote_slug "$(isolated_git -C "$source" config --local --get remote.origin.url 2>/dev/null || true)" 2>/dev/null || true)"
  destination_remote="$(normalize_remote_slug "$(isolated_git -C "$destination" config --local --get remote.origin.url 2>/dev/null || true)" 2>/dev/null || true)"
  if [[ -n "$source_remote" ]]; then
    [[ -n "$destination_remote" ]] || {
      VERIFICATION_FAILURE_REASON="Canonical Git remote identity is missing."
      return 1
    }
    if [[ "$source_remote" != "$destination_remote" || "$source_remote" != "$(receipt_value "$receipt" repository)" ]]; then
      VERIFICATION_FAILURE_REASON="Source, canonical, and receipt-bound Git remote identities differ in owner/name or exact casing."
      return 1
    fi
  fi
  refs_file="$(mktemp "$TMP_ROOT/git-refs.XXXXXX")" || return 1
  destination_refs_file="$(mktemp "$TMP_ROOT/git-destination-refs.XXXXXX")" || return 1
  isolated_git -C "$source" for-each-ref --format='%(objectname) %(refname)' > "$refs_file" 2>/dev/null || {
    VERIFICATION_FAILURE_REASON="Source Git refs could not be enumerated."
    return 1
  }
  isolated_git -C "$destination" for-each-ref --format='%(objectname) %(refname)' > "$destination_refs_file" 2>/dev/null || {
    VERIFICATION_FAILURE_REASON="Canonical Git refs could not be enumerated."
    return 1
  }
  while IFS=' ' read -r object_id ref_name; do
    [[ -n "$object_id" ]] || continue
    isolated_git -C "$destination" cat-file -e "$object_id^{object}" 2>/dev/null || {
      VERIFICATION_FAILURE_REASON="Canonical Git object database is missing source ref object $object_id."
      return 1
    }
    destination_ref_matches_source "$destination_refs_file" "$object_id" "$ref_name" "$git_ref_namespace" || {
      VERIFICATION_FAILURE_REASON="Source ref $ref_name is not preserved exactly or beneath git_ref_namespace."
      return 1
    }
  done < "$refs_file"

  objects_file="$(mktemp "$TMP_ROOT/git-objects.XXXXXX")" || return 1
  isolated_git -C "$source" cat-file --batch-all-objects --batch-check='%(objectname)' > "$objects_file" 2>/dev/null || {
    VERIFICATION_FAILURE_REASON="Source Git objects could not be enumerated."
    return 1
  }
  while IFS= read -r object_id; do
    [[ -n "$object_id" ]] || continue
    isolated_git -C "$destination" cat-file -e "$object_id^{object}" 2>/dev/null || {
      VERIFICATION_FAILURE_REASON="Canonical Git object database is missing source object $object_id."
      return 1
    }
  done < "$objects_file"

  if [[ -d "$source/.git/lfs/objects" ]]; then
    command -v cmp >/dev/null 2>&1 || return 1
    lfs_files="$(mktemp "$TMP_ROOT/git-lfs-objects.XXXXXX")" || return 1
    find "$source/.git/lfs/objects" -type f -print0 > "$lfs_files" 2>/dev/null || return 1
    while IFS= read -r -d '' lfs_object; do
      lfs_relative="${lfs_object#"$source/.git/lfs/objects/"}"
      [[ "$lfs_relative" != "$lfs_object" && -f "$destination/.git/lfs/objects/$lfs_relative" ]] || {
        VERIFICATION_FAILURE_REASON="Canonical Git LFS store is missing a source-local object."
        return 1
      }
      cmp -s "$lfs_object" "$destination/.git/lfs/objects/$lfs_relative" || {
        VERIFICATION_FAILURE_REASON="Canonical Git LFS object differs from its source-local object."
        return 1
      }
    done < "$lfs_files"
  fi
  final_destination_git_fsck_once "$destination" "$receipt" || {
    VERIFICATION_FAILURE_REASON="Canonical Git object database failed strict fsck."
    return 1
  }
}

verify_stage2_cleanup_evidence() {
  local receipt="$1"
  local live_source="$2"
  local destination="$3"
  local require_source_identity="$4"
  [[ "$require_source_identity" == "0" || "$require_source_identity" == "1" ]] || return 1
  if [[ "$require_source_identity" == "1" ]]; then
    verify_stage2_filesystem_evidence "$receipt" "$live_source" "$destination"
  else
    verify_stage2_filesystem_evidence "$receipt" "" "$destination"
  fi
}

verify_source_represented() {
  local source="$1"
  local destination="$2"
  local archive="$3"
  local include_git="$4"
  local include_finder="$5"
  local include_dependencies="$6"
  local receipt="$7"
  local stage="$8"
  local git_ref_namespace="$9"
  local require_stage2_source_identity="${10:-1}"
  local differences=""
  local rsync_bin=""
  local args=(-rlcni --no-owner --no-group --no-perms)

  VERIFICATION_FAILURE_REASON=""
  [[ -d "$source" && -d "$destination" ]] || {
    VERIFICATION_FAILURE_REASON="Source or canonical destination is unavailable."
    return 1
  }
  [[ "$stage" == "1" || "$stage" == "2" ]] || {
    VERIFICATION_FAILURE_REASON="Receipt stage is unavailable to live verification."
    return 1
  }
  [[ "$require_stage2_source_identity" == "0" || "$require_stage2_source_identity" == "1" ]] || return 1
  if [[ "$stage" == "2" ]]; then
    if [[ "$require_stage2_source_identity" == "0" ]]; then
      # Import/Stage2 is a generated transaction copy, not the source named by
      # the Stage 2 evidence binding. Validate the authoritative source package
      # and canonical representatives without falsely equating copy inodes;
      # the live generated copy is still checksum, path, metadata, Git, fsck,
      # quarantine, and no-drift verified by the remaining gates below.
      :
    fi
    verify_stage2_cleanup_evidence "$receipt" "$source" "$destination" "$require_stage2_source_identity" || return 1
  else
    # For a chained Stage 1 original, the selected Stage 2 package proves its
    # own source and canonical representatives only. The original's metadata
    # is handled by a separate fresh Stage 3 package.
    verify_stage2_filesystem_evidence "$receipt" "" "$destination" || return 1
  fi
  args+=(--exclude='.git/')
  if [[ "$stage" == "1" ]]; then
    args+=(--exclude='/Transfer_Note.MD' --exclude='/Prompt_Inject.MD' --exclude='/.csa-iem-recovery/')
  fi
  if [[ "$include_finder" != "1" ]]; then args+=(--exclude='.DS_Store' --exclude='._*'); fi
  if [[ "$include_dependencies" != "1" ]]; then
    args+=(--exclude='node_modules/' --exclude='vendor/' --exclude='.venv/' --exclude='venv/' --exclude='Pods/' --exclude='DerivedData/' --exclude='dist/' --exclude='build/' --exclude='.build/' --exclude='target/' --exclude='.next/' --exclude='.nuxt/' --exclude='.output/' --exclude='.turbo/' --exclude='coverage/' --exclude='.nyc_output/' --exclude='.cache/' --exclude='Caches/' --exclude='.parcel-cache/' --exclude='.vite/' --exclude='.npm/' --exclude='.pnpm-store/' --exclude='.swiftpm/' --exclude='.gradle/' --exclude='.terraform/' --exclude='.dart_tool/' --exclude='.pytest_cache/' --exclude='.tox/' --exclude='__pycache__/')
  fi
  rsync_bin="$(command -v rsync)"
  if ! differences="$(COPYFILE_DISABLE=1 "$rsync_bin" "${args[@]}" "$source/" "$destination/" 2>&1)"; then
    VERIFICATION_FAILURE_REASON="Canonical checksum comparison could not complete."
    return 1
  fi
  differences="$(printf '%s\n' "$differences" | sed -e '/^[[:space:]]*$/d' -e '/^sending incremental file list$/d' -e '/^receiving incremental file list$/d' | awk '$1 !~ /^\.[^[:space:]]\.\.T\.\.\.\.$/ { print }')"
  [[ -z "$differences" ]] || {
    VERIFICATION_FAILURE_REASON="Canonical filesystem content differs from the source after receipt-declared exclusions."
    return 1
  }
  verify_exact_path_spelling_represented "$source" "$destination" "$include_finder" "$include_dependencies" "$stage" || {
    VERIFICATION_FAILURE_REASON="Canonical filesystem paths do not preserve every source directory-entry name with exact case and spelling."
    return 1
  }
  verify_filesystem_metadata_represented "$source" "$destination" "$include_finder" "$include_dependencies" "$stage" || {
    VERIFICATION_FAILURE_REASON="Canonical filesystem type, symlink target, or executable metadata differs from the source."
    return 1
  }
  # A chained Stage 1 source's entire .csa-iem-recovery tree is included in
  # its fresh Stage 3 manifest and receives an exact active/package recovery
  # representative. It is intentionally not inferred from Stage 2 metadata.
  verify_git_objects_represented "$source" "$destination" "$include_git" "$receipt" "$git_ref_namespace" "$stage" || return 1

  if [[ -n "$archive" ]] && ! verified_zip "$archive"; then
    VERIFICATION_FAILURE_REASON="Receipt-declared supplemental ZIP verification failed."
    return 1
  fi
}

selector_matches() {
  local receipt="$1"
  local repository="$2"
  local source="$3"
  local destination="$4"
  local selector=""
  [[ "${#PROJECT_SELECTORS[@]}" -eq 0 ]] && return 0
  for selector in "${PROJECT_SELECTORS[@]}"; do
    if [[ "$(identity_key "$selector")" == "$(identity_key "$repository")" ||
          "$(identity_key "$selector")" == "$(identity_key "$(basename "$source")")" ||
          "$(identity_key "$selector")" == "$(identity_key "$(basename "$destination")")" ]]; then
      return 0
    fi
  done
  return 1
}

receipt_is_trusted() {
  local receipt="$1"
  local stage="$2"
  [[ -f "$receipt" && ! -L "$receipt" ]] || return 1
  case "$stage" in
    1) path_is_strictly_within "$receipt" "$SOURCE_ROOT/_temp/Transfer-Receipts" ;;
    2) path_is_strictly_within "$receipt" "$MANAGED_ROOT/Runtime/Receipts/Stage2" ;;
    *) return 1 ;;
  esac
}

safe_project_relative_path() {
  local value="$1"
  local part=""
  local parts=()
  [[ -n "$value" && "$value" != /* && "$value" != */ &&
     "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *$'\t'* ]] || return 1
  IFS='/' read -r -a parts <<< "$value"
  [[ "${#parts[@]}" -eq 2 ]] || return 1
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != "." && "$part" != ".." && "$part" =~ ^[[:alnum:]_.-]+$ ]] || return 1
  done
}

safe_path_component() {
  local value="$1"
  [[ -n "$value" && "$value" != "." && "$value" != ".." &&
     "$value" != */* && "$value" =~ ^[[:alnum:]_.-]+$ ]]
}

stage2_managed_retired_source_is_allowed() {
  local receipt="$1"
  local source="$2"
  local status=""
  local transaction=""
  local repository=""
  local stage1_destination=""
  local git_ref_namespace=""
  local receipt_managed_temp=""
  local quarantine=""
  local canonical_source=""
  local canonical_receipt_managed_temp=""
  local expected_source=""

  status="$(receipt_value "$receipt" status)"
  transaction="$(receipt_value "$receipt" transaction)"
  repository="$(receipt_value "$receipt" repository)"
  receipt_managed_temp="$(receipt_value "$receipt" managed_temp)"
  quarantine="$(receipt_value "$receipt" quarantine)"
  [[ "$status" == "source-retired" ]] || return 1
  [[ "$(receipt_value "$receipt" stage3_cleanup_eligible)" == "1" ]] || return 1
  [[ "$(receipt_value "$receipt" content_verification)" == "full-checksum" ]] || return 1
  [[ "$(receipt_value "$receipt" cleanup_owner)" == "stage3" ]] || return 1
  [[ "$(receipt_value "$receipt" zip_authoritative)" == "0" ]] || return 1
  safe_path_component "$transaction" || return 1
  safe_project_relative_path "$repository" || return 1
  [[ -d "$receipt_managed_temp" && ! -L "$receipt_managed_temp" ]] || return 1
  canonical_receipt_managed_temp="$(canonical_existing_path "$receipt_managed_temp")" || return 1
  [[ "$canonical_receipt_managed_temp" == "$MANAGED_TEMP_ROOT" ]] || return 1
  canonical_source="$(canonical_existing_path "$source")" || return 1
  expected_source="$MANAGED_TEMP_ROOT/Stage2-Completed/$transaction/$repository"
  [[ "$canonical_source" == "$expected_source" ]] || return 1
  path_is_strictly_within "$canonical_source" "$MANAGED_TEMP_ROOT" || return 1
  [[ -n "$quarantine" ]] || return 1
  paths_are_same "$canonical_source" "$quarantine"
}

canonical_destination_allowed() {
  local destination="$1"
  [[ -d "$destination" && ! -L "$destination" ]] || return 1
  path_is_strictly_within "$destination" "$CANONICAL_REPOS_ROOT"
}

canonical_destination_matches_repository() {
  local destination="$1"
  local repository="$2"
  local canonical_destination=""
  local expected_destination=""
  safe_project_relative_path "$repository" || return 1
  [[ "$destination" == "$CANONICAL_REPOS_ROOT/$repository" ]] || return 1
  canonical_destination_allowed "$destination" || return 1
  path_has_exact_relative_components "$CANONICAL_REPOS_ROOT" "$repository" || return 1
  [[ -d "$CANONICAL_REPOS_ROOT/$repository" && ! -L "$CANONICAL_REPOS_ROOT/$repository" ]] || return 1
  canonical_destination="$(canonical_existing_path "$destination")" || return 1
  expected_destination="$(canonical_existing_path "$CANONICAL_REPOS_ROOT/$repository")" || return 1
  [[ "$canonical_destination" == "$expected_destination" ]]
}

resolve_stage1_chain() {
  local stage1_destination="$1"
  local normalized_stage1_destination=""
  local candidate=""
  local candidate_stage=""
  local candidate_status=""
  local candidate_source=""
  local candidate_destination=""
  local canonical_candidate_destination=""
  local candidate_archive=""
  local candidate_repository=""
  local candidate_git_ref_namespace=""
  local candidate_git_snapshot=""
  local candidate_git_snapshot_digest=""
  local candidate_source_recovery_snapshot=""
  local candidate_source_recovery_snapshot_digest=""
  local saw_matching_source=0
  local valid_matches=0
  CHAIN_DESTINATION=""
  CHAIN_ARCHIVE=""
  CHAIN_REPOSITORY=""
  CHAIN_GIT_REF_NAMESPACE=""
  CHAIN_RECEIPT=""
  CHAIN_ERROR=""
  [[ -n "$stage1_destination" && -f "$TMP_ROOT/receipts.txt" ]] || return 1
  normalized_stage1_destination="$(normalize_path "$stage1_destination")" || return 1
  while IFS= read -r candidate; do
    candidate_stage="$(receipt_value "$candidate" stage)"
    [[ "$candidate_stage" == "2" ]] || continue
    candidate_source="$(receipt_value "$candidate" original_source)"
    [[ -n "$candidate_source" ]] || continue
    [[ "$(normalize_path "$candidate_source" 2>/dev/null || true)" == "$normalized_stage1_destination" ]] || continue
    saw_matching_source=1
    if ! receipt_is_trusted "$candidate" "$candidate_stage"; then
      CHAIN_ERROR="A matching Stage 2 receipt is outside the trusted Stage 2 receipt root."
      continue
    fi
    if receipt_declares_unsupported_local_quarantine "$candidate"; then
      CHAIN_ERROR="A matching Stage 2 receipt declares the reserved unsupported cross-volume local-quarantine contract."
      continue
    fi
    candidate_status="$(receipt_value "$candidate" status)"
    if ! verified_receipt_status "$candidate_status" ||
       [[ "$(receipt_value "$candidate" content_verification)" != "full-checksum" ||
          "$(receipt_value "$candidate" cleanup_owner)" != "stage3" ||
          "$(receipt_value "$candidate" stage3_cleanup_eligible)" != "1" ||
          "$(receipt_value "$candidate" zip_authoritative)" != "0" ]]; then
      CHAIN_ERROR="A matching Stage 2 receipt is not final, full-checksum, and Stage 3 cleanup-eligible."
      continue
    fi
    candidate_destination="$(receipt_value "$candidate" destination)"
    candidate_repository="$(receipt_value "$candidate" repository)"
    [[ -n "$candidate_repository" ]] || candidate_repository="$(receipt_value "$candidate" project_name)"
    if ! canonical_destination_matches_repository "$candidate_destination" "$candidate_repository"; then
      CHAIN_ERROR="A matching Stage 2 receipt does not name an exact canonical owner/repository destination."
      continue
    fi
    canonical_candidate_destination="$(canonical_existing_path "$candidate_destination")" || {
      CHAIN_ERROR="A matching Stage 2 canonical destination cannot be resolved."
      continue
    }
    if ! stage2_filesystem_evidence_fields_are_strict "$candidate" ||
       ! verify_stage2_filesystem_evidence "$candidate" "" "$canonical_candidate_destination"; then
      CHAIN_ERROR="A matching Stage 2 receipt lacks a final receipt-bound filesystem-evidence-v2 package or its canonical representatives no longer verify."
      continue
    fi
    if [[ "$(receipt_field_count "$candidate" git_ref_namespace)" -gt 1 ]]; then
      CHAIN_ERROR="A matching Stage 2 receipt duplicates git_ref_namespace."
      continue
    fi
    candidate_git_ref_namespace="$(receipt_value "$candidate" git_ref_namespace)"
    if ! safe_git_ref_namespace "$candidate_git_ref_namespace"; then
      CHAIN_ERROR="A matching Stage 2 receipt has an invalid git_ref_namespace."
      continue
    fi
    candidate_git_snapshot="$(receipt_value "$candidate" git_snapshot)"
    candidate_git_snapshot_digest="$(receipt_value "$candidate" git_snapshot_digest)"
    candidate_source_recovery_snapshot="$(receipt_value "$candidate" source_recovery_snapshot)"
    candidate_source_recovery_snapshot_digest="$(receipt_value "$candidate" source_recovery_snapshot_digest)"
    candidate_archive="$(receipt_value "$candidate" archive)"
    if [[ "$valid_matches" -eq 0 ]]; then
      CHAIN_DESTINATION="$canonical_candidate_destination"
      CHAIN_ARCHIVE="$candidate_archive"
      CHAIN_REPOSITORY="$candidate_repository"
      CHAIN_GIT_REF_NAMESPACE="$candidate_git_ref_namespace"
      CHAIN_RECEIPT="$candidate"
    elif [[ "$CHAIN_DESTINATION" != "$canonical_candidate_destination" ||
            "$CHAIN_REPOSITORY" != "$candidate_repository" ||
            "$CHAIN_GIT_REF_NAMESPACE" != "$candidate_git_ref_namespace" ||
            "$(receipt_value "$CHAIN_RECEIPT" git_snapshot)" != "$candidate_git_snapshot" ||
            "$(receipt_value "$CHAIN_RECEIPT" git_snapshot_digest)" != "$candidate_git_snapshot_digest" ||
            "$(receipt_value "$CHAIN_RECEIPT" source_recovery_snapshot)" != "$candidate_source_recovery_snapshot" ||
            "$(receipt_value "$CHAIN_RECEIPT" source_recovery_snapshot_digest)" != "$candidate_source_recovery_snapshot_digest" ||
            "$(receipt_value "$CHAIN_RECEIPT" repository_id)" != "$(receipt_value "$candidate" repository_id)" ||
            "$(receipt_value "$CHAIN_RECEIPT" filesystem_evidence)" != "$(receipt_value "$candidate" filesystem_evidence)" ||
            "$(receipt_value "$CHAIN_RECEIPT" filesystem_evidence_digest)" != "$(receipt_value "$candidate" filesystem_evidence_digest)" ||
            "$(receipt_value "$CHAIN_RECEIPT" filesystem_manifest_digest)" != "$(receipt_value "$candidate" filesystem_manifest_digest)" ||
            "$(receipt_value "$CHAIN_RECEIPT" filesystem_binding_digest)" != "$(receipt_value "$candidate" filesystem_binding_digest)" ||
            "$(receipt_value "$CHAIN_RECEIPT" filesystem_source_tree_digest)" != "$(receipt_value "$candidate" filesystem_source_tree_digest)" ||
            ( -n "$CHAIN_ARCHIVE" && -n "$candidate_archive" && "$CHAIN_ARCHIVE" != "$candidate_archive" ) ]]; then
      CHAIN_ERROR="Matching Stage 2 receipts disagree about canonical destination, repository casing, ref namespace, snapshot evidence, relocated recovery evidence, or archive."
      return 1
    elif [[ -z "$CHAIN_ARCHIVE" && -n "$candidate_archive" ]]; then
      CHAIN_ARCHIVE="$candidate_archive"
    fi
    valid_matches=$((valid_matches + 1))
  done < "$TMP_ROOT/receipts.txt"
  if [[ "$valid_matches" -gt 0 ]]; then
    [[ -z "$CHAIN_ERROR" ]] || return 1
    return 0
  fi
  [[ "$saw_matching_source" -eq 0 ]] && CHAIN_ERROR=""
  return 1
}

canonical_entry_path_without_following() {
  local requested="$1"
  local parent=""
  local leaf=""
  local canonical_parent=""
  [[ "$requested" == /* && "$requested" != *$'\n'* && "$requested" != *$'\r'* && "$requested" != *$'\t'* ]] || return 1
  parent="$(dirname "$requested")"
  leaf="$(basename "$requested")"
  [[ -n "$leaf" && "$leaf" != "." && "$leaf" != ".." ]] || return 1
  [[ -d "$parent" ]] || return 1
  canonical_parent="$(canonical_existing_path "$parent")" || return 1
  printf '%s/%s' "$canonical_parent" "$leaf"
}

resolved_link_target_entry() {
  local link_path="$1"
  local raw_target=""
  local requested_target=""
  [[ -L "$link_path" ]] || return 1
  raw_target="$(readlink "$link_path")" || return 1
  [[ -n "$raw_target" && "$raw_target" != *$'\n'* && "$raw_target" != *$'\r'* && "$raw_target" != *$'\t'* ]] || return 1
  case "$raw_target" in
    /*) requested_target="$raw_target" ;;
    *) requested_target="$(dirname "$link_path")/$raw_target" ;;
  esac
  canonical_entry_path_without_following "$requested_target"
}

compatibility_link_points_to_path() {
  local link_path="$1"
  local expected_path="$2"
  local resolved_target=""
  local normalized_expected=""
  resolved_target="$(resolved_link_target_entry "$link_path")" || return 1
  normalized_expected="$(canonical_entry_path_without_following "$expected_path")" || return 1
  [[ "$resolved_target" == "$normalized_expected" ]]
}

stage1_compatibility_link_is_safe() {
  local receipt="$1"
  local cleanup_source="$2"
  local original_source=""
  local current_source=""
  local stage1_destination=""
  local receipt_source_root=""
  local canonical_original_entry=""
  local canonical_source_root=""
  local canonical_cleanup_source=""

  original_source="$(receipt_value "$receipt" original_source)"
  current_source="$(receipt_value "$receipt" current_source)"
  stage1_destination="$(receipt_value "$receipt" destination)"
  receipt_source_root="$(receipt_value "$receipt" source_root)"
  [[ -n "$original_source" ]] || return 0
  [[ "$original_source" != "$current_source" && "$original_source" != "$cleanup_source" ]] || return 0
  if [[ ! -e "$original_source" && ! -L "$original_source" ]]; then
    return 0
  fi
  [[ -L "$original_source" && -n "$stage1_destination" ]] || return 1
  canonical_original_entry="$(canonical_entry_path_without_following "$original_source")" || return 1
  canonical_source_root="$(canonical_existing_path "$receipt_source_root")" || return 1
  canonical_cleanup_source="$(canonical_entry_path_without_following "$cleanup_source")" || return 1
  [[ "$canonical_original_entry" == "$canonical_source_root/"* ]] || return 1
  [[ "$canonical_original_entry" != "$canonical_cleanup_source" &&
     "$canonical_original_entry" != "$canonical_cleanup_source/"* ]] || return 1
  compatibility_link_points_to_path "$original_source" "$stage1_destination"
}

prepare_stage1_compatibility_link_update() {
  local receipt="$1"
  local cleanup_source="$2"
  local final_destination="$3"
  local original_source=""
  local current_source=""
  local stage1_destination=""
  local temp_link=""

  COMPATIBILITY_LINK_PATH=""
  COMPATIBILITY_LINK_TEMP=""
  COMPATIBILITY_LINK_RETARGETED_PATH=""
  original_source="$(receipt_value "$receipt" original_source)"
  current_source="$(receipt_value "$receipt" current_source)"
  stage1_destination="$(receipt_value "$receipt" destination)"
  [[ -n "$original_source" && "$original_source" != "$current_source" && "$original_source" != "$cleanup_source" ]] || return 0
  [[ -e "$original_source" || -L "$original_source" ]] || return 0
  stage1_compatibility_link_is_safe "$receipt" "$cleanup_source" || return 1
  compatibility_link_points_to_path "$original_source" "$final_destination" && return 0
  [[ -n "$stage1_destination" ]] || return 1
  temp_link="$(dirname "$original_source")/.csa-iem-stage3-link-$TRANSACTION_ID-$(basename "$original_source")"
  [[ ! -e "$temp_link" && ! -L "$temp_link" ]] || return 1
  ln -s "$final_destination" "$temp_link" || return 1
  compatibility_link_points_to_path "$temp_link" "$final_destination" || {
    [[ -L "$temp_link" ]] && rm -f -- "$temp_link"
    return 1
  }
  COMPATIBILITY_LINK_PATH="$original_source"
  COMPATIBILITY_LINK_TEMP="$temp_link"
}

discard_prepared_compatibility_link() {
  if [[ -n "$COMPATIBILITY_LINK_TEMP" && -L "$COMPATIBILITY_LINK_TEMP" ]]; then
    rm -f -- "$COMPATIBILITY_LINK_TEMP" || true
  fi
  COMPATIBILITY_LINK_PATH=""
  COMPATIBILITY_LINK_TEMP=""
}

finalize_stage1_compatibility_link_update() {
  local receipt="$1"
  local cleanup_source="$2"
  local final_destination="$3"
  if [[ -z "$COMPATIBILITY_LINK_PATH" && -z "$COMPATIBILITY_LINK_TEMP" ]]; then
    return 0
  fi
  [[ -n "$COMPATIBILITY_LINK_PATH" && -n "$COMPATIBILITY_LINK_TEMP" &&
     -L "$COMPATIBILITY_LINK_PATH" && -L "$COMPATIBILITY_LINK_TEMP" ]] || return 1
  stage1_compatibility_link_is_safe "$receipt" "$cleanup_source" || return 1
  compatibility_link_points_to_path "$COMPATIBILITY_LINK_TEMP" "$final_destination" || return 1
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # BSD mv otherwise follows a destination symlink to a directory. -h makes
    # the exact link entry, rather than its target, the atomic rename target.
    mv -fh -- "$COMPATIBILITY_LINK_TEMP" "$COMPATIBILITY_LINK_PATH" || return 1
  else
    # GNU mv uses -T for the equivalent no-dereference destination behavior.
    mv -Tf -- "$COMPATIBILITY_LINK_TEMP" "$COMPATIBILITY_LINK_PATH" || return 1
  fi
  COMPATIBILITY_LINK_TEMP=""
  COMPATIBILITY_LINK_RETARGETED_PATH="$COMPATIBILITY_LINK_PATH"
  compatibility_link_points_to_path "$COMPATIBILITY_LINK_PATH" "$final_destination" || return 1
  COMPATIBILITY_LINK_PATH=""
}

rollback_stage1_compatibility_link_update() {
  local receipt="$1"
  local cleanup_source="$2"
  local final_destination="$3"
  local original_source=""
  local stage1_destination=""
  local receipt_source_root=""
  local canonical_original_entry=""
  local canonical_source_root=""
  local canonical_cleanup_source=""
  local rollback_temp=""

  [[ -n "$COMPATIBILITY_LINK_RETARGETED_PATH" ]] || return 0
  original_source="$(receipt_value "$receipt" original_source)"
  stage1_destination="$(receipt_value "$receipt" destination)"
  receipt_source_root="$(receipt_value "$receipt" source_root)"
  [[ "$original_source" == "$COMPATIBILITY_LINK_RETARGETED_PATH" &&
     -L "$original_source" && -n "$stage1_destination" ]] || return 1
  compatibility_link_points_to_path "$original_source" "$final_destination" || return 1
  canonical_original_entry="$(canonical_entry_path_without_following "$original_source")" || return 1
  canonical_source_root="$(canonical_existing_path "$receipt_source_root")" || return 1
  canonical_cleanup_source="$(canonical_entry_path_without_following "$cleanup_source")" || return 1
  [[ "$canonical_original_entry" == "$canonical_source_root/"* &&
     "$canonical_original_entry" != "$canonical_cleanup_source" &&
     "$canonical_original_entry" != "$canonical_cleanup_source/"* ]] || return 1
  rollback_temp="$(dirname "$original_source")/.csa-iem-stage3-link-rollback-$TRANSACTION_ID-$(basename "$original_source")"
  [[ ! -e "$rollback_temp" && ! -L "$rollback_temp" ]] || return 1
  ln -s "$stage1_destination" "$rollback_temp" || return 1
  compatibility_link_points_to_path "$rollback_temp" "$stage1_destination" || {
    [[ -L "$rollback_temp" ]] && rm -f -- "$rollback_temp"
    return 1
  }
  if [[ "$(uname -s)" == "Darwin" ]]; then
    mv -fh -- "$rollback_temp" "$original_source" || return 1
  else
    mv -Tf -- "$rollback_temp" "$original_source" || return 1
  fi
  compatibility_link_points_to_path "$original_source" "$stage1_destination" || return 1
  COMPATIBILITY_LINK_RETARGETED_PATH=""
}

append_receipt() {
  local receipt="$1"
  [[ -f "$receipt" ]] || return 0
  grep -Fqx "$receipt" "$TMP_ROOT/receipts.txt" 2>/dev/null || printf '%s\n' "$receipt" >> "$TMP_ROOT/receipts.txt"
}

collect_receipts() {
  local selector=""
  local candidate=""
  : > "$TMP_ROOT/receipts.txt"
  if [[ "$SELECT_ALL" -eq 1 ]]; then
    while IFS= read -r candidate; do append_receipt "$candidate"; done < <(
      find "$SOURCE_ROOT/_temp/Transfer-Receipts" "$MANAGED_ROOT/Runtime/Receipts/Stage2" -type f -name '*.receipt' -print 2>/dev/null | LC_ALL=C sort
    )
  fi
  for selector in "${RECEIPT_SELECTORS[@]}"; do
    selector="${selector/#\~/$HOME}"
    if [[ -f "$selector" ]]; then
      append_receipt "$(normalize_path "$selector")"
    else
      while IFS= read -r candidate; do append_receipt "$candidate"; done < <(
        find "$SOURCE_ROOT/_temp/Transfer-Receipts" "$MANAGED_ROOT/Runtime/Receipts/Stage2" -type f -name "*$selector*.receipt" -print 2>/dev/null | LC_ALL=C sort
      )
    fi
  done
  [[ -s "$TMP_ROOT/receipts.txt" ]] || die "No lifecycle receipts matched the Stage 3 selection."
}

append_plan() {
  local state="$1" stage="$2" receipt="$3" target="$4" source="$5" destination="$6" archive="$7" detail="$8"
  local value=""
  for value in "$state" "$stage" "$receipt" "$target" "$source" "$destination" "$archive" "$detail"; do
    [[ "$value" != *$'\x1f'* && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || return 1
  done
  printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$state" "$stage" "$receipt" "$target" "$source" "$destination" "$archive" "$detail" >> "$PLAN_FILE"
  printf 'PLAN | %-30s | stage=%s | %s\n' "$state" "$stage" "$target"
}

plan_receipt() {
  local receipt="$1"
  local stage status repository original_source current_source destination archive import_stage quarantine plan_path source_index destination_index
  local receipt_source_root deletion_eligible content_verification stage_path stage1_destination git_ref_namespace receipt_repository
  local verification_receipt="$receipt"
  local source_candidate=""
  local canonical_source=""
  local canonical_destination=""
  local canonical_receipt_source_root=""
  local canonical_import_stage=""
  local project_import_stage=""
  local expected_project_import_stage=""
  local canonical_candidate=""
  local stage2_source_allowed=0
  local include_git="1" include_finder="1" include_dependencies="1"
  stage="$(receipt_value "$receipt" stage)"
  status="$(receipt_value "$receipt" status)"
  receipt_repository="$(receipt_value "$receipt" repository)"
  repository="$receipt_repository"
  original_source="$(receipt_value "$receipt" original_source)"
  current_source="$(receipt_value "$receipt" current_source)"
  destination="$(receipt_value "$receipt" destination)"
  stage1_destination="$destination"
  archive="$(receipt_value "$receipt" archive)"
  import_stage="$(receipt_value "$receipt" import_stage)"
  quarantine="$(receipt_value "$receipt" quarantine)"
  plan_path="$(receipt_value "$receipt" plan)"
  source_index="$(receipt_value "$receipt" source_index)"
  destination_index="$(receipt_value "$receipt" destination_index)"
  receipt_source_root="$(receipt_value "$receipt" source_root)"
  deletion_eligible="$(receipt_value "$receipt" deletion_eligible)"
  content_verification="$(receipt_value "$receipt" content_verification)"
  stage_path="$(receipt_value "$receipt" stage_path)"
  [[ -n "$repository" ]] || repository="$(receipt_value "$receipt" project_name)"
  include_git="$(receipt_value "$receipt" include_git)"; [[ -n "$include_git" ]] || include_git="1"
  include_finder="$(receipt_value "$receipt" include_finder)"; [[ -n "$include_finder" ]] || include_finder="1"
  include_dependencies="$(receipt_value "$receipt" include_dependencies)"; [[ -n "$include_dependencies" ]] || include_dependencies="1"
  git_ref_namespace="$(receipt_value "$receipt" git_ref_namespace)"

  if [[ "$stage" != "1" && "$stage" != "2" ]]; then
    append_plan "blocked-unknown-receipt" "${stage:-?}" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "Receipt stage is not supported."
    return
  fi
  if ! receipt_is_trusted "$receipt" "$stage"; then
    append_plan "blocked-untrusted-receipt" "$stage" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "Receipt is not a regular file inside the canonical receipt root for its stage."
    return
  fi
  if receipt_declares_unsupported_local_quarantine "$receipt"; then
    append_plan "blocked-unsupported-local-quarantine" "$stage" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "Cross-volume managed-evidence/local-quarantine cleanup is reserved but unsupported; Stage 3 will not scan for or delete that quarantine."
    return
  fi
  if [[ "$stage" == "2" ]] && ! stage2_filesystem_evidence_fields_are_strict "$receipt"; then
    append_plan "blocked-legacy-stage2-evidence" "$stage" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "Stage 2 receipt is not format 2 with a final filesystem-evidence-v2 package; weak or legacy receipts are never deletion eligible."
    return
  fi
  if ! verified_receipt_status "$status"; then
    append_plan "blocked-unverified-receipt" "$stage" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "Receipt status is $status."
    return
  fi
  if [[ "$stage" == "1" && ( "$deletion_eligible" != "1" || "$content_verification" != "full-checksum" ) ]]; then
    append_plan "blocked-ineligible-stage1-receipt" "$stage" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "Stage 1 receipt must explicitly declare deletion_eligible=1 and content_verification=full-checksum."
    return
  fi
  if [[ "$(receipt_field_count "$receipt" git_ref_namespace)" -gt 1 ]] || ! safe_git_ref_namespace "$git_ref_namespace"; then
    append_plan "blocked-invalid-git-ref-namespace" "$stage" "$receipt" "$receipt" "$original_source" "$destination" "$archive" "git_ref_namespace must be absent or appear once as a valid refs namespace."
    return
  fi
  if [[ "$stage" == "1" ]]; then
    if resolve_stage1_chain "$stage1_destination"; then
      if [[ -n "$receipt_repository" &&
            "$(printf '%s' "$receipt_repository" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$CHAIN_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ]]; then
        append_plan "blocked-stage1-chain" "$stage" "$receipt" "$stage1_destination" "$original_source" "$destination" "$archive" "Stage 1 and Stage 2 receipts disagree about repository identity."
        return
      fi
      if [[ -n "$git_ref_namespace" && -n "$CHAIN_GIT_REF_NAMESPACE" && "$git_ref_namespace" != "$CHAIN_GIT_REF_NAMESPACE" ]]; then
        append_plan "blocked-stage1-chain" "$stage" "$receipt" "$stage1_destination" "$original_source" "$destination" "$archive" "Stage 1 and Stage 2 receipts disagree about git_ref_namespace."
        return
      fi
      if ! receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" git_snapshot ||
         ! receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" git_snapshot_digest ||
         ! receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" source_recovery_snapshot ||
         ! receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" source_recovery_snapshot_digest ||
         ! stage1_optional_stage2_evidence_matches "$receipt" "$CHAIN_RECEIPT"; then
        append_plan "blocked-stage1-chain" "$stage" "$receipt" "$stage1_destination" "$original_source" "$destination" "$archive" "Stage 1 and Stage 2 receipts disagree about snapshot or relocated recovery evidence."
        return
      fi
      repository="$CHAIN_REPOSITORY"
      destination="$CHAIN_DESTINATION"
      verification_receipt="$CHAIN_RECEIPT"
      [[ -n "$archive" ]] || archive="$CHAIN_ARCHIVE"
      [[ -n "$git_ref_namespace" ]] || git_ref_namespace="$CHAIN_GIT_REF_NAMESPACE"
    elif [[ -n "$CHAIN_ERROR" ]]; then
      append_plan "blocked-stage1-chain" "$stage" "$receipt" "$stage1_destination" "$original_source" "$destination" "$archive" "$CHAIN_ERROR"
      return
    fi
  fi
  selector_matches "$receipt" "$repository" "$original_source" "$destination" || return 0
  if [[ ! -d "$destination" ]]; then
    append_plan "blocked-destination-missing" "$stage" "$receipt" "$destination" "$original_source" "$destination" "$archive" "Verified destination is unavailable."
    return
  fi
  if ! canonical_destination_matches_repository "$destination" "$repository"; then
    append_plan "blocked-destination-boundary" "$stage" "$receipt" "$destination" "$original_source" "$destination" "$archive" "Destination is not the exact canonical owner/repository directory named by the receipt."
    return
  fi
  canonical_destination="$(canonical_existing_path "$destination")" || {
    append_plan "blocked-destination-boundary" "$stage" "$receipt" "$destination" "$original_source" "$destination" "$archive" "Destination could not be canonicalized."
    return
  }
  destination="$canonical_destination"
  if is_reserved_project "$original_source" "$repository" || is_reserved_project "$destination" "$repository"; then
    append_plan "blocked-active-project" "$stage" "$receipt" "$original_source" "$original_source" "$destination" "$archive" "The active CSA-iEM project is never cleaned automatically."
    return
  fi

  source_candidate="$current_source"
  [[ -e "$source_candidate" ]] || source_candidate="$original_source"
  if [[ "$stage" == "1" && "$DELETE_STAGE1_ORIGINALS" -eq 1 ]]; then
    if [[ -L "$source_candidate" ]]; then
      append_plan "blocked-source-symlink" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 1 cleanup never follows or removes a source symlink."
    elif [[ -d "$source_candidate" ]]; then
      if [[ ! -d "$receipt_source_root" ]] || ! path_is_strictly_within "$source_candidate" "$receipt_source_root"; then
        append_plan "blocked-source-boundary" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 1 source is not strictly inside its canonical receipt source_root."
      else
        canonical_source="$(canonical_existing_path "$source_candidate")" || canonical_source=""
        canonical_receipt_source_root="$(canonical_existing_path "$receipt_source_root")" || canonical_receipt_source_root=""
        if [[ -z "$canonical_source" || -z "$canonical_receipt_source_root" ]] ||
           path_is_strictly_within "$canonical_source" "$MANAGED_TEMP_ROOT" ||
           cleanup_target_is_protected "$canonical_source" || paths_are_same "$canonical_source" "$destination"; then
          append_plan "blocked-protected-target" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 1 source resolves to a protected or canonical destination path."
        elif ! stage1_compatibility_link_is_safe "$receipt" "$canonical_source"; then
          append_plan "blocked-compatibility-link" "$stage" "$receipt" "$original_source" "$canonical_source" "$destination" "$archive" "The original Stage 1 path is not absent and is not the exact receipt-bound compatibility symlink."
        elif verify_source_represented "$canonical_source" "$destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" &&
             capture_stage1_filesystem_evidence "$canonical_source" "$destination" "$receipt" "$verification_receipt" "0"; then
          append_plan "ready-delete-stage1-original" "$stage" "$receipt" "$canonical_source" "$canonical_source" "$destination" "$archive" "Canonical content/Git representation and a disposable fresh Stage1-original metadata-evidence preflight passed; apply must create and finalize durable managed _temp evidence before quarantine."
        else
          append_plan "blocked-live-verification" "$stage" "$receipt" "$canonical_source" "$canonical_source" "$destination" "$archive" "${VERIFICATION_FAILURE_REASON:-Canonical full-checksum, Git representation, or supplemental declared-ZIP verification failed.}"
        fi
      fi
    elif [[ "$status" != "source-deleted" ]]; then
      append_plan "blocked-source-missing" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 1 receipt says the source is retained, but no real source directory exists."
    fi
  elif [[ "$stage" == "2" && "$DELETE_STAGE2_INPUTS" -eq 1 ]]; then
    if [[ -L "$source_candidate" ]]; then
      append_plan "blocked-source-symlink" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 2 cleanup never follows or removes a source symlink."
    elif [[ -d "$source_candidate" ]]; then
      if [[ -z "$receipt_source_root" ]] || ! paths_are_same "$receipt_source_root" "$SOURCE_ROOT"; then
        append_plan "blocked-source-root-mismatch" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 2 receipt source_root does not match the selected Stage 1 source root."
      else
        stage2_source_allowed=0
        if path_is_strictly_within "$source_candidate" "$SOURCE_ROOT"; then
          stage2_source_allowed=1
        elif stage2_managed_retired_source_is_allowed "$receipt" "$source_candidate"; then
          stage2_source_allowed=1
        fi
        canonical_source="$(canonical_existing_path "$source_candidate")" || canonical_source=""
        if [[ "$stage2_source_allowed" -ne 1 || -z "$canonical_source" ]]; then
          append_plan "blocked-source-boundary" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 2 input is neither inside the canonical Stage 1 source root nor the exact authorized managed _temp retirement path."
        elif cleanup_target_is_protected "$canonical_source" || paths_are_same "$canonical_source" "$destination"; then
          append_plan "blocked-protected-target" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 2 input resolves to a protected or canonical destination path."
        elif verify_source_represented "$canonical_source" "$destination" "$archive" "1" "1" "1" "$receipt" "$stage" "$git_ref_namespace"; then
          append_plan "ready-delete-stage2-input" "$stage" "$receipt" "$canonical_source" "$canonical_source" "$destination" "$archive" "Canonical full-checksum and Git representation passed; any declared ZIP also tested as supplemental evidence."
        else
          append_plan "blocked-live-verification" "$stage" "$receipt" "$canonical_source" "$canonical_source" "$destination" "$archive" "${VERIFICATION_FAILURE_REASON:-Canonical full-checksum, Git representation, or supplemental declared-ZIP verification failed.}"
        fi
      fi
    elif [[ "$status" != "source-deleted" ]]; then
      append_plan "blocked-source-missing" "$stage" "$receipt" "$source_candidate" "$source_candidate" "$destination" "$archive" "Stage 2 receipt says the input is retained, but no real source directory exists."
    fi
  fi

  if [[ "$stage" == "2" && "$CLEANUP_TRANSACTION_TEMP" -eq 1 && ( -e "$import_stage" || -L "$import_stage" ) ]]; then
    if [[ -L "$import_stage" || ! -d "$import_stage" ]] || ! path_is_strictly_within "$import_stage" "$MANAGED_ROOT/Import/Stage2"; then
      append_plan "blocked-temp-boundary" "$stage" "$receipt" "$import_stage" "$source_candidate" "$destination" "$archive" "Transaction staging is not a real directory strictly inside managed Import/Stage2."
    elif ! safe_project_relative_path "$repository"; then
      append_plan "blocked-project-stage-path" "$stage" "$receipt" "$import_stage" "$source_candidate" "$destination" "$archive" "Repository identity cannot form an exact project-specific staging path."
    else
      canonical_import_stage="$(canonical_existing_path "$import_stage")" || canonical_import_stage=""
      expected_project_import_stage="$canonical_import_stage/code/$repository"
      project_import_stage="$stage_path"
      [[ -n "$project_import_stage" ]] || project_import_stage="$expected_project_import_stage"
      if [[ -e "$project_import_stage" || -L "$project_import_stage" ]]; then
        if [[ -L "$project_import_stage" || ! -d "$project_import_stage" ]]; then
          append_plan "blocked-project-stage-path" "$stage" "$receipt" "$project_import_stage" "$source_candidate" "$destination" "$archive" "Project staging target is not a real directory."
        else
          canonical_candidate="$(canonical_existing_path "$project_import_stage")" || canonical_candidate=""
          if [[ -z "$canonical_candidate" || "$canonical_candidate" != "$expected_project_import_stage" ]] ||
             ! path_is_strictly_within "$canonical_candidate" "$canonical_import_stage/code" ||
             ! path_is_strictly_within "$canonical_candidate" "$MANAGED_ROOT/Import/Stage2" ||
             cleanup_target_is_protected "$canonical_candidate"; then
            append_plan "blocked-project-stage-path" "$stage" "$receipt" "$project_import_stage" "$source_candidate" "$destination" "$archive" "Only the exact receipt-linked project staging directory may be removed; the transaction import root is protected."
          elif verify_source_represented "$canonical_candidate" "$destination" "$archive" "1" "1" "1" "$receipt" "$stage" "$git_ref_namespace" "0"; then
            append_plan "ready-remove-stage2-temp" "$stage" "$receipt" "$canonical_candidate" "$source_candidate" "$destination" "$archive" "Exact project staging passed canonical full-checksum/Git verification; its transaction root remains."
          else
            append_plan "blocked-project-stage-verification" "$stage" "$receipt" "$canonical_candidate" "$source_candidate" "$destination" "$archive" "${VERIFICATION_FAILURE_REASON:-Project staging is not fully represented by the canonical destination; the transaction root and project staging remain.}"
          fi
        fi
      fi
    fi
  fi

  if [[ "$stage" == "2" && "$CLEANUP_TRANSACTION_TEMP" -eq 1 && "$status" == "source-deleted" && -n "$quarantine" ]]; then
    if [[ -e "$quarantine" || -L "$quarantine" ]]; then
      if [[ -d "$quarantine" && ! -L "$quarantine" && -z "$(find "$quarantine" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
        canonical_candidate="$(canonical_existing_path "$quarantine")" || canonical_candidate=""
        if [[ -n "$canonical_candidate" ]] && path_is_strictly_within "$canonical_candidate" "$SOURCE_ROOT/_temp/Stage2-Delete" && ! cleanup_target_is_protected "$canonical_candidate"; then
          append_plan "ready-remove-stage2-delete-temp" "$stage" "$receipt" "$canonical_candidate" "$source_candidate" "$destination" "$archive" "Exact receipt-linked empty project quarantine can be removed; its transaction root remains."
        else
          append_plan "blocked-temp-boundary" "$stage" "$receipt" "$quarantine" "$source_candidate" "$destination" "$archive" "Project quarantine is outside the canonical Stage 2 delete-temp root."
        fi
      else
        append_plan "blocked-nonempty-quarantine" "$stage" "$receipt" "$quarantine" "$source_candidate" "$destination" "$archive" "A per-project delete quarantine must be an empty real directory before cleanup."
      fi
    fi
  fi

  if [[ "$CLEANUP_ALL_VERIFIED_TEMP" -eq 1 ]]; then
    for candidate in "$plan_path" "$source_index" "$destination_index"; do
      [[ -e "$candidate" || -L "$candidate" ]] || continue
      if [[ -f "$candidate" && ! -L "$candidate" ]]; then
        canonical_candidate="$(canonical_existing_path "$candidate")" || canonical_candidate=""
      else
        canonical_candidate=""
      fi
      if [[ -n "$canonical_candidate" ]] && path_is_strictly_within "$canonical_candidate" "$SOURCE_ROOT/_temp/Transfer-Indexes" && ! cleanup_target_is_protected "$canonical_candidate"; then
        append_plan "ready-remove-stage1-index" "$stage" "$receipt" "$canonical_candidate" "$source_candidate" "$destination" "$archive" "Exact receipt-linked Stage 1 index artifact can be removed."
      else
        append_plan "blocked-temp-boundary" "$stage" "$receipt" "$candidate" "$source_candidate" "$destination" "$archive" "Index artifact is outside the Stage 1 index root."
      fi
    done
  fi
}

write_audit_receipt() {
  local action="$1" target="$2" source_receipt="$3" result="$4"
  local audit="$AUDIT_DIR/$(printf '%s' "$action-$target-$result" | shasum -a 256 | awk '{print $1}').receipt"
  mkdir -p "$AUDIT_DIR"
  {
    printf 'format=3\n'
    printf 'stage=3\n'
    printf 'transaction=%s\n' "$TRANSACTION_ID"
    printf 'action=%s\n' "$action"
    printf 'target=%s\n' "$target"
    printf 'source_receipt=%s\n' "$source_receipt"
    printf 'result=%s\n' "$result"
    if [[ "$CURRENT_STAGE3_FILESYSTEM_DURABLE" -eq 1 && -n "$CURRENT_STAGE3_FILESYSTEM_EVIDENCE" ]]; then
      printf 'stage1_filesystem_evidence_schema=csa-iem-filesystem-evidence-v2\n'
      printf 'stage1_filesystem_evidence_status=final-verified\n'
      printf 'stage1_filesystem_evidence=%s\n' "$CURRENT_STAGE3_FILESYSTEM_EVIDENCE"
      printf 'stage1_filesystem_evidence_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_EVIDENCE_DIGEST"
      printf 'stage1_filesystem_manifest_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_MANIFEST_DIGEST"
      printf 'stage1_filesystem_binding_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_BINDING_DIGEST"
      printf 'stage1_filesystem_source_tree_digest=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_TREE_DIGEST"
      printf 'stage1_filesystem_source_path_hex=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_PATH_HEX"
      printf 'stage1_filesystem_source_device=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_DEVICE"
      printf 'stage1_filesystem_source_inode=%s\n' "$CURRENT_STAGE3_FILESYSTEM_SOURCE_INODE"
      printf 'stage1_filesystem_exact_categories=%s\n' "$CURRENT_STAGE3_FILESYSTEM_EXACT_CATEGORIES"
      printf 'stage1_filesystem_record_only_categories=%s\n' "$CURRENT_STAGE3_FILESYSTEM_RECORD_ONLY_CATEGORIES"
      printf 'stage1_filesystem_unsupported_categories=%s\n' "$CURRENT_STAGE3_FILESYSTEM_UNSUPPORTED_CATEGORIES"
      printf 'stage1_filesystem_destination_device=%s\n' "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_DEVICE"
      printf 'stage1_filesystem_destination_volume_uuid=%s\n' "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_VOLUME_UUID"
      printf 'stage1_filesystem_destination_owners_enabled=%s\n' "$CURRENT_STAGE3_FILESYSTEM_DESTINATION_OWNERS_ENABLED"
      printf 'bound_stage1_receipt_digest=%s\n' "$CURRENT_STAGE3_STAGE1_RECEIPT_DIGEST"
      printf 'bound_stage2_receipt=%s\n' "$CURRENT_STAGE3_CHAIN_RECEIPT"
      printf 'bound_stage2_receipt_digest=%s\n' "$CURRENT_STAGE3_STAGE2_RECEIPT_DIGEST"
      printf 'evidence_finalization_schema=csa-iem-stage3-evidence-finalization-v1\n'
      printf 'evidence_finalization_receipt=%s\n' "$CURRENT_STAGE3_FINALIZATION_RECEIPT"
      printf 'evidence_finalization_digest=%s\n' "$CURRENT_STAGE3_FINALIZATION_DIGEST"
      printf 'github_host=%s\n' "$GITHUB_HOST"
      printf 'github_owner=%s\n' "$CURRENT_STAGE3_GITHUB_OWNER"
      printf 'github_login=%s\n' "$CURRENT_STAGE3_GITHUB_LOGIN"
      printf 'github_account_binding_digest=%s\n' "$CURRENT_STAGE3_GITHUB_ACCOUNT_BINDING_DIGEST"
      printf 'repository_role=%s\n' "$CURRENT_STAGE3_REPOSITORY_ROLE"
      printf 'parent_repository=%s\n' "$CURRENT_STAGE3_PARENT_REPOSITORY"
      printf 'exact_git_remote=%s\n' "$CURRENT_STAGE3_EXACT_GIT_REMOTE"
      printf 'wiki_ref_digest=%s\n' "$CURRENT_STAGE3_WIKI_REF_DIGEST"
      printf 'wiki_default_branch=%s\n' "$CURRENT_STAGE3_WIKI_DEFAULT_BRANCH"
      printf 'wiki_head_oid=%s\n' "$CURRENT_STAGE3_WIKI_HEAD_OID"
    fi
    printf 'completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$audit"
}

ready_action_target_is_valid() {
  local state="$1" stage="$2" receipt="$3" target="$4" destination="$5" archive="$6"
  local canonical_target=""
  local canonical_destination=""
  local receipt_source_root=""
  local import_stage=""
  local canonical_import_stage=""
  local repository=""
  local receipt_repository=""
  local quarantine=""
  local expected_target=""
  local git_ref_namespace=""
  local stage1_destination=""
  local verification_receipt="$receipt"
  local include_git="1" include_finder="1" include_dependencies="1"

  receipt_declares_unsupported_local_quarantine "$receipt" && return 1
  [[ -e "$target" && ! -L "$target" ]] || return 1
  canonical_target="$(canonical_existing_path "$target")" || return 1
  [[ "$canonical_target" == "$target" ]] || return 1
  cleanup_target_is_protected "$canonical_target" && return 1
  receipt_repository="$(receipt_value "$receipt" repository)"
  repository="$receipt_repository"
  [[ -n "$repository" ]] || repository="$(receipt_value "$receipt" project_name)"
  git_ref_namespace="$(receipt_value "$receipt" git_ref_namespace)"
  [[ "$(receipt_field_count "$receipt" git_ref_namespace)" -le 1 ]] || return 1
  safe_git_ref_namespace "$git_ref_namespace" || return 1
  if [[ "$stage" == "1" ]]; then
    stage1_destination="$(receipt_value "$receipt" destination)"
    if resolve_stage1_chain "$stage1_destination"; then
      [[ "$destination" == "$CHAIN_DESTINATION" ]] || return 1
      [[ -z "$receipt_repository" ||
         "$(printf '%s' "$receipt_repository" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$CHAIN_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ]] || return 1
      [[ -z "$git_ref_namespace" || -z "$CHAIN_GIT_REF_NAMESPACE" || "$git_ref_namespace" == "$CHAIN_GIT_REF_NAMESPACE" ]] || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" git_snapshot || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" git_snapshot_digest || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" source_recovery_snapshot || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" source_recovery_snapshot_digest || return 1
      stage1_optional_stage2_evidence_matches "$receipt" "$CHAIN_RECEIPT" || return 1
      repository="$CHAIN_REPOSITORY"
      verification_receipt="$CHAIN_RECEIPT"
      [[ -n "$git_ref_namespace" ]] || git_ref_namespace="$CHAIN_GIT_REF_NAMESPACE"
    elif [[ -n "$CHAIN_ERROR" ]]; then
      return 1
    fi
  fi
  canonical_destination_matches_repository "$destination" "$repository" || return 1
  canonical_destination="$(canonical_existing_path "$destination")" || return 1
  [[ "$canonical_destination" == "$destination" ]] || return 1

  case "$state" in
    ready-delete-stage1-original)
      [[ "$stage" == "1" ]] || return 1
      receipt_is_trusted "$receipt" "1" || return 1
      [[ "$(receipt_value "$receipt" deletion_eligible)" == "1" ]] || return 1
      [[ "$(receipt_value "$receipt" content_verification)" == "full-checksum" ]] || return 1
      receipt_source_root="$(receipt_value "$receipt" source_root)"
      [[ -d "$receipt_source_root" ]] || return 1
      path_is_strictly_within "$canonical_target" "$receipt_source_root" || return 1
      path_is_strictly_within "$canonical_target" "$MANAGED_TEMP_ROOT" && return 1
      paths_are_same "$canonical_target" "$canonical_destination" && return 1
      include_git="$(receipt_value "$receipt" include_git)"; [[ -n "$include_git" ]] || include_git="1"
      include_finder="$(receipt_value "$receipt" include_finder)"; [[ -n "$include_finder" ]] || include_finder="1"
      include_dependencies="$(receipt_value "$receipt" include_dependencies)"; [[ -n "$include_dependencies" ]] || include_dependencies="1"
      stage1_compatibility_link_is_safe "$receipt" "$canonical_target" || return 1
      verify_source_represented "$canonical_target" "$canonical_destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" &&
        capture_stage1_filesystem_evidence "$canonical_target" "$canonical_destination" "$receipt" "$verification_receipt" "0"
      ;;
    ready-delete-stage2-input)
      [[ "$stage" == "2" ]] || return 1
      receipt_is_trusted "$receipt" "2" || return 1
      receipt_source_root="$(receipt_value "$receipt" source_root)"
      [[ -n "$receipt_source_root" ]] || return 1
      paths_are_same "$receipt_source_root" "$SOURCE_ROOT" || return 1
      if ! path_is_strictly_within "$canonical_target" "$SOURCE_ROOT" &&
         ! stage2_managed_retired_source_is_allowed "$receipt" "$canonical_target"; then
        return 1
      fi
      paths_are_same "$canonical_target" "$canonical_destination" && return 1
      verify_source_represented "$canonical_target" "$canonical_destination" "$archive" "1" "1" "1" "$receipt" "$stage" "$git_ref_namespace"
      ;;
    ready-remove-stage2-temp)
      [[ "$stage" == "2" && -d "$canonical_target" ]] || return 1
      receipt_is_trusted "$receipt" "2" || return 1
      safe_project_relative_path "$repository" || return 1
      import_stage="$(receipt_value "$receipt" import_stage)"
      [[ -d "$import_stage" && ! -L "$import_stage" ]] || return 1
      path_is_strictly_within "$import_stage" "$MANAGED_ROOT/Import/Stage2" || return 1
      canonical_import_stage="$(canonical_existing_path "$import_stage")" || return 1
      expected_target="$canonical_import_stage/code/$repository"
      [[ "$canonical_target" == "$expected_target" ]] || return 1
      path_is_strictly_within "$canonical_target" "$canonical_import_stage/code" || return 1
      path_is_strictly_within "$canonical_target" "$MANAGED_ROOT/Import/Stage2" || return 1
      verify_source_represented "$canonical_target" "$canonical_destination" "$archive" "1" "1" "1" "$receipt" "$stage" "$git_ref_namespace" "0"
      ;;
    ready-remove-stage2-delete-temp)
      [[ "$stage" == "2" && -d "$canonical_target" ]] || return 1
      receipt_is_trusted "$receipt" "2" || return 1
      [[ "$(receipt_value "$receipt" status)" == "source-deleted" ]] || return 1
      quarantine="$(receipt_value "$receipt" quarantine)"
      [[ -n "$quarantine" ]] || return 1
      paths_are_same "$canonical_target" "$quarantine" || return 1
      path_is_strictly_within "$canonical_target" "$SOURCE_ROOT/_temp/Stage2-Delete" || return 1
      [[ -z "$(find "$canonical_target" -mindepth 1 -print -quit 2>/dev/null)" ]]
      ;;
    ready-remove-stage1-index)
      [[ -f "$canonical_target" ]] || return 1
      receipt_is_trusted "$receipt" "$stage" || return 1
      path_is_strictly_within "$canonical_target" "$SOURCE_ROOT/_temp/Transfer-Indexes"
      ;;
    *) return 1 ;;
  esac
}

validate_apply_plan() {
  local state stage receipt target source destination archive detail
  local canonical_target=""
  local existing_target=""
  local targets_file="$TMP_ROOT/apply-targets.txt"
  : > "$targets_file"

  managed_temp_is_preserved || {
    warn "Managed _temp changed before apply validation."
    return 1
  }
  while IFS=$'\x1f' read -r state stage receipt target source destination archive detail; do
    [[ -n "$state" ]] || continue
    case "$state" in ready-*) ;; *) return 1 ;; esac
    if ! ready_action_target_is_valid "$state" "$stage" "$receipt" "$target" "$destination" "$archive"; then
      warn "Ready action failed immediate pre-mutation validation: $state | $target"
      return 1
    fi
    canonical_target="$(canonical_existing_path "$target")" || return 1
    while IFS= read -r existing_target; do
      [[ -n "$existing_target" ]] || continue
      if [[ "$canonical_target" == "$existing_target" ||
            "$canonical_target" == "$existing_target/"* ||
            "$existing_target" == "$canonical_target/"* ]]; then
        warn "Cleanup plan contains duplicate or overlapping targets: $canonical_target | $existing_target"
        return 1
      fi
    done < "$targets_file"
    printf '%s\n' "$canonical_target" >> "$targets_file"
  done < "$PLAN_FILE"
}

delete_verified_source() {
  local source="$1" destination="$2" archive="$3" stage="$4" receipt="$5"
  local action="${6:-}"
  local include_git="1" include_finder="1" include_dependencies="1"
  local require_stage2_source_identity=1
  local git_ref_namespace=""
  local stage1_destination=""
  local receipt_repository=""
  local verification_receipt="$receipt"
  local quarantine="$(dirname "$source")/.csa-iem-stage3-quarantine-$TRANSACTION_ID-$(basename "$source")"
  local canonical_quarantine=""
  local source_device=""
  local quarantine_parent_device=""
  local quarantine_digest_before=""
  local quarantine_digest_after=""
  local source_restored=0
  discard_prepared_compatibility_link
  reset_current_stage3_filesystem_evidence
  receipt_declares_unsupported_local_quarantine "$receipt" && return 1
  if [[ "$stage" == "2" && "$action" == "ready-remove-stage2-temp" ]]; then
    require_stage2_source_identity=0
  fi
  receipt_repository="$(receipt_value "$receipt" repository)"
  git_ref_namespace="$(receipt_value "$receipt" git_ref_namespace)"
  [[ "$(receipt_field_count "$receipt" git_ref_namespace)" -le 1 ]] || return 1
  safe_git_ref_namespace "$git_ref_namespace" || return 1
  if [[ "$stage" == "1" ]]; then
    include_git="$(receipt_value "$receipt" include_git)"; [[ -n "$include_git" ]] || include_git="1"
    include_finder="$(receipt_value "$receipt" include_finder)"; [[ -n "$include_finder" ]] || include_finder="1"
    include_dependencies="$(receipt_value "$receipt" include_dependencies)"; [[ -n "$include_dependencies" ]] || include_dependencies="1"
    stage1_destination="$(receipt_value "$receipt" destination)"
    if resolve_stage1_chain "$stage1_destination"; then
      [[ "$destination" == "$CHAIN_DESTINATION" ]] || return 1
      [[ -z "$receipt_repository" ||
         "$(printf '%s' "$receipt_repository" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$CHAIN_REPOSITORY" | tr '[:upper:]' '[:lower:]')" ]] || return 1
      [[ -z "$git_ref_namespace" || -z "$CHAIN_GIT_REF_NAMESPACE" || "$git_ref_namespace" == "$CHAIN_GIT_REF_NAMESPACE" ]] || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" git_snapshot || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" git_snapshot_digest || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" source_recovery_snapshot || return 1
      receipt_optional_field_matches "$receipt" "$CHAIN_RECEIPT" source_recovery_snapshot_digest || return 1
      stage1_optional_stage2_evidence_matches "$receipt" "$CHAIN_RECEIPT" || return 1
      verification_receipt="$CHAIN_RECEIPT"
      [[ -n "$git_ref_namespace" ]] || git_ref_namespace="$CHAIN_GIT_REF_NAMESPACE"
    elif [[ -n "$CHAIN_ERROR" ]]; then
      return 1
    fi
  fi
  # Reverify the exact live source immediately before quarantine. A chained
  # Stage 1 original additionally receives a distinct durable evidence package
  # under managed _temp; Stage 2 evidence is never substituted for it.
  if [[ "$stage" == "1" ]]; then
    capture_stage1_filesystem_evidence "$source" "$destination" "$receipt" "$verification_receipt" "1" || return 1
    verify_source_represented "$source" "$destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" "$require_stage2_source_identity" || return 1
    verify_current_stage1_filesystem_evidence "$source" "$destination" "$receipt" "$verification_receipt" || return 1
  else
    verify_source_represented "$source" "$destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" "$require_stage2_source_identity" || return 1
  fi
  [[ ! -e "$quarantine" && ! -L "$quarantine" ]] || return 1
  source_device="$(device_id "$source")" || return 1
  quarantine_parent_device="$(device_id "$(dirname "$quarantine")")" || return 1
  [[ "$source_device" == "$quarantine_parent_device" ]] || return 1
  if [[ "$stage" == "1" ]] && ! prepare_stage1_compatibility_link_update "$receipt" "$source" "$destination"; then
    discard_prepared_compatibility_link
    return 1
  fi
  # Recompute the complete live proof after every preparatory step. This is
  # intentionally the final source-reading gate before the same-volume rename.
  if ! verify_source_represented "$source" "$destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" "$require_stage2_source_identity"; then
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "1" ]]; then
    verify_current_stage1_filesystem_evidence "$source" "$destination" "$receipt" "$verification_receipt" || {
      discard_prepared_compatibility_link
      return 1
    }
    write_audit_receipt "evidence-finalized-stage1" "$source" "$receipt" "evidence-finalized" || {
      discard_prepared_compatibility_link
      return 1
    }
    # Writing the durable audit receipt is outside the source tree, but the
    # live manifest is recomputed once more so no mutation window remains.
    verify_current_stage1_filesystem_evidence "$source" "$destination" "$receipt" "$verification_receipt" || {
      discard_prepared_compatibility_link
      return 1
    }
  else
    verify_stage2_cleanup_evidence "$verification_receipt" "$source" "$destination" "$require_stage2_source_identity" || {
      discard_prepared_compatibility_link
      return 1
    }
  fi
  if ! mv "$source" "$quarantine"; then
    if [[ ! -e "$source" && ! -L "$source" && -d "$quarantine" && ! -L "$quarantine" ]]; then
      mv "$quarantine" "$source" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ -e "$source" || -L "$source" || ! -d "$quarantine" || -L "$quarantine" ]]; then
    if [[ -d "$quarantine" && ! -e "$source" && ! -L "$source" ]]; then
      mv "$quarantine" "$source" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  fi
  canonical_quarantine="$(canonical_existing_path "$quarantine")" || {
    mv "$quarantine" "$source" 2>/dev/null || true
    discard_prepared_compatibility_link
    return 1
  }
  cleanup_target_is_protected "$canonical_quarantine" && {
    mv "$quarantine" "$source" 2>/dev/null || true
    discard_prepared_compatibility_link
    return 1
  }
  if ! verify_source_represented "$quarantine" "$destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" "$require_stage2_source_identity"; then
    mv "$quarantine" "$source" 2>/dev/null || true
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "1" ]] &&
     ! verify_current_stage1_filesystem_evidence "$quarantine" "$destination" "$receipt" "$verification_receipt"; then
    mv "$quarantine" "$source" 2>/dev/null || true
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "2" ]] &&
     ! verify_stage2_cleanup_evidence "$verification_receipt" "$quarantine" "$destination" "$require_stage2_source_identity"; then
    mv "$quarantine" "$source" 2>/dev/null || true
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "1" ]] && ! finalize_stage1_compatibility_link_update "$receipt" "$source" "$destination"; then
    if mv "$quarantine" "$source" 2>/dev/null; then
      rollback_stage1_compatibility_link_update "$receipt" "$source" "$destination" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  fi
  quarantine_digest_before="$(tree_digest "$quarantine")" || {
    mv "$quarantine" "$source" 2>/dev/null || true
    if [[ -d "$source" && ! -L "$source" ]]; then
      rollback_stage1_compatibility_link_update "$receipt" "$source" "$destination" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  }
  # Final no-drift gate immediately before permanent removal. This repeats the
  # live manifest/representative/snapshot checks after quarantine and after any
  # compatibility-link update, but reuses the one-per-source/destination fsck
  # markers while the byte fingerprints remain unchanged.
  if ! verify_source_represented "$quarantine" "$destination" "$archive" "$include_git" "$include_finder" "$include_dependencies" "$verification_receipt" "$stage" "$git_ref_namespace" "$require_stage2_source_identity"; then
    mv "$quarantine" "$source" 2>/dev/null || true
    if [[ -d "$source" && ! -L "$source" ]]; then
      rollback_stage1_compatibility_link_update "$receipt" "$source" "$destination" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "1" ]] &&
     ! verify_current_stage1_filesystem_evidence "$quarantine" "$destination" "$receipt" "$verification_receipt"; then
    mv "$quarantine" "$source" 2>/dev/null || true
    if [[ -d "$source" && ! -L "$source" ]]; then
      rollback_stage1_compatibility_link_update "$receipt" "$source" "$destination" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "2" ]] &&
     ! verify_stage2_cleanup_evidence "$verification_receipt" "$quarantine" "$destination" "$require_stage2_source_identity"; then
    mv "$quarantine" "$source" 2>/dev/null || true
    discard_prepared_compatibility_link
    return 1
  fi
  rm -rf "$quarantine" 2>/dev/null || true
  if [[ -e "$quarantine" || -L "$quarantine" ]]; then
    if [[ -d "$quarantine" && ! -L "$quarantine" && ! -e "$source" && ! -L "$source" ]]; then
      quarantine_digest_after="$(tree_digest "$quarantine" 2>/dev/null || true)"
      if [[ -n "$quarantine_digest_after" && "$quarantine_digest_after" == "$quarantine_digest_before" ]]; then
        if mv "$quarantine" "$source" 2>/dev/null; then
          source_restored=1
        fi
      fi
    fi
    if [[ "$source_restored" -eq 1 ]]; then
      rollback_stage1_compatibility_link_update "$receipt" "$source" "$destination" 2>/dev/null || true
    fi
    discard_prepared_compatibility_link
    return 1
  fi
  if [[ "$stage" == "1" ]]; then
    verify_current_stage1_filesystem_evidence "-" "$destination" "$receipt" "$verification_receipt" || return 1
  else
    verify_stage2_filesystem_evidence "$verification_receipt" "" "$destination" || return 1
  fi
  COMPATIBILITY_LINK_RETARGETED_PATH=""
  discard_prepared_compatibility_link
  managed_temp_is_preserved
}

apply_plan() {
  local total=0 ready=0 blockers=0 index=0 applied=0 skipped=0 failed=0
  local state stage receipt target source destination archive detail
  total="$(awk 'NF { count++ } END { print count+0 }' "$PLAN_FILE")"
  ready="$(awk -F '\037' '$1 ~ /^ready-/ { count++ } END { print count+0 }' "$PLAN_FILE")"
  blockers="$(awk -F '\037' '$1 !~ /^ready-/ && NF { count++ } END { print count+0 }' "$PLAN_FILE")"
  printf '0\n' > "$TMP_ROOT/applied-count"
  printf '0\n' > "$TMP_ROOT/skipped-count"
  printf '0\n' > "$TMP_ROOT/failed-count"

  if [[ "$blockers" -ne 0 ]]; then
    printf '%s\n' "$blockers" > "$TMP_ROOT/skipped-count"
    warn "Stage 3 apply aborted before cleanup mutation because the plan contains $blockers blocker(s)."
    return 1
  fi
  if [[ "$ready" -eq 0 ]]; then
    warn "Stage 3 apply has no ready cleanup actions."
    return 1
  fi
  if ! validate_apply_plan; then
    printf '1\n' > "$TMP_ROOT/failed-count"
    warn "Stage 3 apply aborted before cleanup mutation because ready-action validation failed."
    return 1
  fi

  while IFS=$'\x1f' read -r state stage receipt target source destination archive detail; do
    [[ -n "$state" ]] || continue
    index=$((index + 1))
    printf 'PROGRESS | %s/%s | %s | %s\n' "$index" "$total" "$state" "$target"
    if ! ready_action_target_is_valid "$state" "$stage" "$receipt" "$target" "$destination" "$archive"; then
      warn "Cleanup target changed after whole-plan validation: $target"
      failed=$((failed + 1))
      break
    fi
    if ! write_audit_receipt "$state" "$target" "$receipt" "delete-pending"; then
      warn "Could not write the pending Stage 3 audit receipt: $target"
      failed=$((failed + 1))
      break
    fi
    case "$state" in
      ready-delete-stage1-original|ready-delete-stage2-input|ready-remove-stage2-temp)
        if delete_verified_source "$target" "$destination" "$archive" "$stage" "$receipt" "$state"; then
          if write_audit_receipt "$state" "$target" "$receipt" "deleted"; then
            applied=$((applied + 1))
          else
            failed=$((failed + 1))
            break
          fi
        else
          warn "Verified source cleanup failed; the exact source path or receipt-bound quarantine remains the recovery authority: $target"
          write_audit_receipt "$state" "$target" "$receipt" "delete-failed" 2>/dev/null || true
          failed=$((failed + 1))
          break
        fi
        ;;
      ready-remove-stage2-delete-temp)
        if rmdir "$target" && [[ ! -e "$target" && ! -L "$target" ]] && managed_temp_is_preserved; then
          if write_audit_receipt "$state" "$target" "$receipt" "deleted"; then
            applied=$((applied + 1))
          else
            failed=$((failed + 1))
            break
          fi
        else
          write_audit_receipt "$state" "$target" "$receipt" "delete-failed" 2>/dev/null || true
          failed=$((failed + 1))
          break
        fi
        ;;
      ready-remove-stage1-index)
        if rm -f "$target" && [[ ! -e "$target" && ! -L "$target" ]] && managed_temp_is_preserved; then
          if write_audit_receipt "$state" "$target" "$receipt" "deleted"; then
            applied=$((applied + 1))
          else
            failed=$((failed + 1))
            break
          fi
        else
          write_audit_receipt "$state" "$target" "$receipt" "delete-failed" 2>/dev/null || true
          failed=$((failed + 1))
          break
        fi
        ;;
      *)
        skipped=$((skipped + 1))
        failed=$((failed + 1))
        break
        ;;
    esac
  done < "$PLAN_FILE"
  printf '%s\n' "$applied" > "$TMP_ROOT/applied-count"
  printf '%s\n' "$skipped" > "$TMP_ROOT/skipped-count"
  printf '%s\n' "$failed" > "$TMP_ROOT/failed-count"
  if [[ "$applied" -ne "$ready" || "$failed" -ne 0 ]] || ! managed_temp_is_preserved; then
    warn "Stage 3 apply incomplete: ready=$ready applied=$applied failed=$failed."
    return 1
  fi
}

write_report() {
  local total ready blocked applied skipped failed
  local state stage receipt target source destination archive detail
  total="$(awk 'NF { count++ } END { print count+0 }' "$PLAN_FILE")"
  ready="$(awk -F '\037' '$1 ~ /^ready-/ { count++ } END { print count+0 }' "$PLAN_FILE")"
  blocked="$(awk -F '\037' '$1 !~ /^ready-/ && NF { count++ } END { print count+0 }' "$PLAN_FILE")"
  applied="$(cat "$TMP_ROOT/applied-count" 2>/dev/null || printf '0')"
  skipped="$(cat "$TMP_ROOT/skipped-count" 2>/dev/null || printf '0')"
  failed="$(cat "$TMP_ROOT/failed-count" 2>/dev/null || printf '0')"
  mkdir -p "$(dirname "$REPORT_PATH")"
  {
    printf '# CSA-iEM Stage 3 Cleanup Report\n\n'
    printf -- '- Transaction: `%s`\n' "$TRANSACTION_ID"
    printf -- '- Action: `%s`\n' "$ACTION"
    printf -- '- Stage 1 source: `%s`\n' "$SOURCE_ROOT"
    printf -- '- Managed root: `%s`\n' "$MANAGED_ROOT"
    printf -- '- Plans: %s total, %s ready, %s blocked\n' "$total" "$ready" "$blocked"
    printf -- '- Execution: %s applied, %s skipped, %s failed\n\n' "$applied" "$skipped" "$failed"
    printf '| State | Stage | Target | Destination | Receipt | Detail |\n'
    printf '|---|---|---|---|---|---|\n'
    while IFS=$'\x1f' read -r state stage receipt target source destination archive detail; do
      printf '| %s | %s | `%s` | `%s` | `%s` | %s |\n' "$state" "$stage" "$target" "$destination" "$receipt" "$detail"
    done < "$PLAN_FILE"
    printf '\nStage 3 never deletes canonical repositories, backup ZIP files, reports, receipts, the managed _temp root, active CSA-iEM workspaces, failed transactions, broad transaction import roots, or unreferenced temporary folders. Only an exact authorized Stage2-Completed project descendant may be cleaned beneath managed _temp.\n'
  } > "$REPORT_PATH"
  info "Stage 3 report: $REPORT_PATH"
  printf 'SUMMARY | total=%s ready=%s blocked=%s applied=%s skipped=%s failed=%s\n' "$total" "$ready" "$blocked" "$applied" "$skipped" "$failed"
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
      --github-account) shift; [[ "$#" -gt 0 ]] || die "--github-account requires OWNER=LOGIN"; register_github_account_binding "$1" || die "Invalid or duplicate --github-account binding: $1" ;;
      --github-account=*) register_github_account_binding "${1#*=}" || die "Invalid or duplicate --github-account binding: ${1#*=}" ;;
      --all) SELECT_ALL=1 ;;
      --receipt) shift; [[ "$#" -gt 0 ]] || die "--receipt requires a path or transaction"; RECEIPT_SELECTORS+=("$1") ;;
      --receipt=*) RECEIPT_SELECTORS+=("${1#*=}") ;;
      --project) shift; [[ "$#" -gt 0 ]] || die "--project requires a name or slug"; PROJECT_SELECTORS+=("$1") ;;
      --project=*) PROJECT_SELECTORS+=("${1#*=}") ;;
      --preflight|--scan) ACTION="preflight" ;;
      --apply) ACTION="apply" ;;
      --delete-stage1-originals) DELETE_STAGE1_ORIGINALS=1 ;;
      --delete-stage2-inputs) DELETE_STAGE2_INPUTS=1 ;;
      --cleanup-transaction-temp) CLEANUP_TRANSACTION_TEMP=1 ;;
      --cleanup-all-verified-temp) CLEANUP_ALL_VERIFIED_TEMP=1; CLEANUP_TRANSACTION_TEMP=1 ;;
      --confirm-delete) shift; [[ "$#" -gt 0 ]] || die "--confirm-delete requires VERIFIED-STAGE3"; DELETE_CONFIRMATION="$1" ;;
      --yes) ASSUME_YES=1 ;;
      --report) shift; [[ "$#" -gt 0 ]] || die "--report requires a path"; REPORT_PATH="$1" ;;
      *) die "Unknown Stage 3 argument: $1" ;;
    esac
    shift
  done
}

main() {
  local receipt=""
  local apply_failed=0
  local ready=0
  local applied=0
  local failed=0
  parse_args "$@"
  valid_github_host "$GITHUB_HOST" || die "GitHub host contains unsafe characters."
  [[ "$SELECT_ALL" -eq 1 || "${#RECEIPT_SELECTORS[@]}" -gt 0 ]] || die "Choose --all or at least one --receipt."
  [[ "$DELETE_STAGE1_ORIGINALS" -eq 1 || "$DELETE_STAGE2_INPUTS" -eq 1 || "$CLEANUP_TRANSACTION_TEMP" -eq 1 || "$CLEANUP_ALL_VERIFIED_TEMP" -eq 1 ]] || die "Choose at least one Stage 3 cleanup option."
  if [[ "$ACTION" == "apply" ]]; then
    [[ "$DELETE_CONFIRMATION" == "VERIFIED-STAGE3" ]] || die "Stage 3 apply requires --confirm-delete VERIFIED-STAGE3."
    if [[ "$ASSUME_YES" -ne 1 ]]; then
      if [[ -t 0 ]]; then
        local confirmation=""
        read -r -p "Type STAGE3 to permanently clean only receipt-verified data: " confirmation
        [[ "$confirmation" == "STAGE3" ]] || die "Stage 3 cleanup was cancelled."
      else
        die "Stage 3 apply requires --yes."
      fi
    fi
  fi
  [[ -d "$SOURCE_ROOT" ]] || die "Stage 1 source folder was not found: $SOURCE_ROOT"
  [[ -d "$MANAGED_ROOT" ]] || die "Managed root was not found: $MANAGED_ROOT"
  command -v rsync >/dev/null 2>&1 || die "rsync is required for Stage 3 verification."
  command -v realpath >/dev/null 2>&1 || die "realpath is required for canonical Stage 3 path validation."
  command -v shasum >/dev/null 2>&1 || die "shasum is required for receipt-bound snapshot verification."
  command -v od >/dev/null 2>&1 || die "od is required for canonical snapshot path encoding."
  command -v comm >/dev/null 2>&1 || die "comm is required for exact source path-spelling verification."
  [[ -x /usr/bin/base64 ]] || die "base64 is required for in-memory owner-scoped Git authentication."
  PYTHON3_BIN="$(command -v python3 2>/dev/null || true)"
  [[ -n "$PYTHON3_BIN" && "$PYTHON3_BIN" == /* && -x "$PYTHON3_BIN" ]] || die "Python 3 is required for deterministic filesystem evidence."
  "$PYTHON3_BIN" -I -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1 ||
    die "Python 3.8 or newer with isolated startup support is required for filesystem evidence."
  git_environment_is_self_contained || die "External Git routing/configuration environment variables are not allowed during Stage 3 verification."
  GIT_BIN="/usr/bin/git"
  trusted_system_git_is_available || die "Stage 3 requires the root-owned, non-writable system Git executable at /usr/bin/git."

  SOURCE_ROOT="$(normalize_path "$SOURCE_ROOT")" || die "Stage 1 source folder could not be canonicalized."
  MANAGED_ROOT="$(normalize_path "$MANAGED_ROOT")" || die "Managed root could not be canonicalized."
  [[ "$SOURCE_ROOT" != "$MANAGED_ROOT" ]] || die "Stage 1 source and managed root must be different directories."
  if path_is_strictly_within "$SOURCE_ROOT" "$MANAGED_ROOT" || path_is_strictly_within "$MANAGED_ROOT" "$SOURCE_ROOT"; then
    die "Stage 1 source and managed root must not contain one another."
  fi
  CANONICAL_REPOS_ROOT="$MANAGED_ROOT/Code/Repos"
  [[ -d "$CANONICAL_REPOS_ROOT" && ! -L "$CANONICAL_REPOS_ROOT" ]] || die "Canonical repository root is unavailable or unsafe: $CANONICAL_REPOS_ROOT"
  CANONICAL_REPOS_ROOT="$(canonical_existing_path "$CANONICAL_REPOS_ROOT")" || die "Canonical repository root could not be resolved."
  MANAGED_TEMP_ROOT="$MANAGED_ROOT/_temp"
  if [[ -L "$MANAGED_TEMP_ROOT" ]]; then
    die "Managed _temp must not be a symlink: $MANAGED_TEMP_ROOT"
  elif [[ -e "$MANAGED_TEMP_ROOT" ]]; then
    [[ -d "$MANAGED_TEMP_ROOT" ]] || die "Managed _temp exists but is not a directory: $MANAGED_TEMP_ROOT"
    MANAGED_TEMP_CANONICAL="$(canonical_existing_path "$MANAGED_TEMP_ROOT")" || die "Managed _temp could not be resolved."
    MANAGED_TEMP_ROOT="$MANAGED_TEMP_CANONICAL"
    MANAGED_TEMP_PRESENT=1
  else
    MANAGED_TEMP_ROOT="$(normalize_path "$MANAGED_TEMP_ROOT")"
    MANAGED_TEMP_PRESENT=0
  fi
  TRANSACTION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  REPORTS_DIR="$MANAGED_ROOT/Runtime/Reports/Stage3"
  AUDIT_DIR="$MANAGED_ROOT/Runtime/Receipts/Stage3/$TRANSACTION_ID"
  TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-stage3.XXXXXX")"
  mkdir -m 700 "$TMP_ROOT/git-home" "$TMP_ROOT/git-xdg" || die "Could not create the isolated Git configuration directories."
  GITHUB_BINDINGS_FILE="$TMP_ROOT/github-account-bindings-verified.tsv"
  PLAN_FILE="$TMP_ROOT/plan.tsv"
  : > "$PLAN_FILE"
  [[ -n "$REPORT_PATH" ]] || REPORT_PATH="$REPORTS_DIR/stage3-$TRANSACTION_ID.md"

  initialize_github_accounts || die "GitHub owner/account bindings could not be authenticated without changing global gh state."

  collect_receipts
  while IFS= read -r receipt; do plan_receipt "$receipt"; done < "$TMP_ROOT/receipts.txt"
  [[ -s "$PLAN_FILE" ]] || die "No Stage 3 actions matched the selected receipts and project filters."
  if [[ "$ACTION" == "apply" ]]; then
    if ! apply_plan; then apply_failed=1; fi
  fi
  write_report
  if [[ "$ACTION" == "apply" ]]; then
    ready="$(awk -F '\037' '$1 ~ /^ready-/ { count++ } END { print count+0 }' "$PLAN_FILE")"
    applied="$(awk 'NR == 1 { print $1+0 }' "$TMP_ROOT/applied-count" 2>/dev/null || printf '0')"
    failed="$(awk 'NR == 1 { print $1+0 }' "$TMP_ROOT/failed-count" 2>/dev/null || printf '0')"
    if [[ "$apply_failed" -ne 0 || "$applied" -ne "$ready" || "$failed" -ne 0 ]] || ! managed_temp_is_preserved; then
      return 1
    fi
  fi
}

if [[ "${CSA_IEM_STAGE3_LIBRARY_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
