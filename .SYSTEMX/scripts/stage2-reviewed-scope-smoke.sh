#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/csa-iem-stage2-reviewed.XXXXXX")"
trap 'rm -rf -- "$FIXTURE"' EXIT

SOURCE="$FIXTURE/source"
mkdir -p "$SOURCE/Alpha" "$SOURCE/Beta"
: > "$SOURCE/Alpha/package.json"
: > "$SOURCE/Beta/package.json"

(
  export CSA_IEM_STAGE2_LIBRARY_ONLY=1
  # shellcheck disable=SC1090
  source "$ROOT_DIR/stage2-workspace.sh"
  set +u
  parse_args --source "$SOURCE" --managed-root "$FIXTURE/managed" --full-auto --yes \
    --require-reviewed-scope --reviewed-source "$SOURCE/Alpha" \
    --reviewed-source="$SOURCE/Beta" --exclude-path "$SOURCE/Beta"
  [[ "$ACTION" == apply && "$SELECT_ALL" -eq 1 && "$REQUIRE_REVIEWED_SCOPE" -eq 1 ]]
  [[ "${#REVIEWED_SOURCE_PATHS[@]}" -eq 2 && "${#EXCLUDED_PATHS[@]}" -eq 1 ]]
  is_reserved_project "$SOURCE/Beta" "unrelated/example"
  ! is_reserved_project "$SOURCE/Alpha" "unrelated/example"
)

check_case() (
  local expected="$1"
  shift
  local output="$FIXTURE/result-$RANDOM.txt"
  export CSA_IEM_STAGE2_LIBRARY_ONLY=1
  # shellcheck disable=SC1090
  source "$ROOT_DIR/stage2-workspace.sh"
  # The Stage 2 script intentionally supports Bash 3 empty arrays without nounset.
  set +u
  SOURCE_ROOT="$(cd -P -- "$SOURCE" && pwd -P)"
  TMP_ROOT="$(mktemp -d "$FIXTURE/work.XXXXXX")"
  PLAN_FILE="$TMP_ROOT/plan.tsv"
  CODE_REPOS="$FIXTURE/managed/Code/Repos"
  SELECT_ALL=1
  REQUIRE_REVIEWED_SCOPE=1
  REVIEWED_SOURCE_PATHS=("$@")
  : > "$PLAN_FILE"

  if (collect_candidates && require_reviewed_scope) > "$output" 2>&1; then
    [[ "$expected" == pass ]] || {
      printf 'Unexpected reviewed-scope acceptance: %s\n' "$*" >&2
      exit 1
    }
  else
    [[ "$expected" == reject ]] || {
      cat "$output" >&2
      exit 1
    }
    if ! grep -Eiq 'reviewed|eligible source|immediate child' "$output"; then
      printf 'Stage 2 rejection did not explain the reviewed-scope mismatch:\n' >&2
      cat "$output" >&2
      exit 1
    fi
  fi
)

check_case pass "$SOURCE/Alpha" "$SOURCE/Beta"
check_case reject "$SOURCE/Alpha"
check_case reject "$SOURCE/Alpha" "$SOURCE/Beta" "$SOURCE/Beta"
check_case reject "$SOURCE/Alpha" "$SOURCE/Beta" "$SOURCE/Missing"

# A project-marked scan root is not an immediate Stage 2 candidate even though
# the GUI may have presented that root as a single project and skipped children.
: > "$SOURCE/package.json"
check_case reject "$SOURCE"

printf 'PASS: Stage 2 reviewed-scope match and mismatch smoke\n'
