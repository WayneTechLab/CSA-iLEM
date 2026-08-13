#!/usr/bin/env bash
set -euo pipefail

# Opt-in live provider smoke. Every operation is a GitHub GET through `gh api`:
# identity, rate-limit, organization, repository, branch, and content reads.
# This script never creates, edits, uploads, deletes, or changes gh auth state.

if [[ "${CSA_IEM_LIVE_GITHUB_SMOKE:-0}" != "1" ]]; then
  echo "Set CSA_IEM_LIVE_GITHUB_SMOKE=1 to run the live read-only GitHub smoke." >&2
  exit 2
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require_command gh

# owner=login bindings prevent a token from being silently used for another
# owner. Separate bindings may be supplied for personal or business accounts.
BINDINGS="${CSA_IEM_LIVE_GITHUB_BINDINGS:-WayneTechLab=WayneTechLab,DARQ-Labs-LLC=pdarq-labs-llc}"
REPOSITORIES="${CSA_IEM_LIVE_GITHUB_REPOSITORIES:-WayneTechLab/Flowers-Field-Guide,WayneTechLab/Space-Field-Guide,WayneTechLab/Birds-Field-Guide,DARQ-Labs-LLC/DarkLabResearch}"

echo "[1/4] account identity bindings"
OWNERS=()
TOKENS=()
LOGINS=()
IFS=',' read -ra binding_pairs <<< "$BINDINGS"
for pair in "${binding_pairs[@]}"; do
  owner="${pair%%=*}"
  login="${pair#*=}"
  [[ -n "$owner" && -n "$login" ]] || {
    echo "Invalid owner=login binding: $pair" >&2
    exit 1
  }
  token="$(gh auth token --user "$login")"
  [[ -n "$token" ]] || { echo "No token available for $login" >&2; exit 1; }
  actual_login="$(GH_TOKEN="$token" gh api user --jq .login)"
  [[ "$actual_login" == "$login" ]] || {
    echo "FAIL: token/login mismatch for owner $owner (expected $login, got $actual_login)" >&2
    exit 1
  }
  OWNERS+=("$owner")
  TOKENS+=("$token")
  LOGINS+=("$actual_login")
  printf '  %s -> %s (verified)\n' "$owner" "$actual_login"
done

echo "[2/4] rate-limit and organization reads"
for index in "${!OWNERS[@]}"; do
  owner="${OWNERS[$index]}"
  token="${TOKENS[$index]}"
  rate_remaining="$(GH_TOKEN="$token" gh api rate_limit --jq .rate.remaining)"
  printf '  %s rate-limit remaining: %s\n' "$owner" "$rate_remaining"
  GH_TOKEN="$token" gh api user/orgs --paginate --jq '.[].login' >/dev/null
done

echo "[3/4] repository identity and branch reads"
IFS=',' read -ra repositories <<< "$REPOSITORIES"
for repository in "${repositories[@]}"; do
  owner="${repository%%/*}"
  owner_index=-1
  for index in "${!OWNERS[@]}"; do
    if [[ "${OWNERS[$index]}" == "$owner" ]]; then
      owner_index="$index"
      break
    fi
  done
  [[ "$owner_index" -ge 0 ]] || {
    echo "No authenticated binding for repository owner $owner" >&2
    exit 1
  }
  token="${TOKENS[$owner_index]}"
  metadata="$(GH_TOKEN="$token" gh api "repos/$repository" --jq '[.full_name,.id,.owner.login,.default_branch,.private,.archived] | @tsv')"
  actual_owner="$(printf '%s\n' "$metadata" | cut -f3)"
  [[ "$actual_owner" == "$owner" ]] || {
    echo "FAIL: repository owner mismatch for $repository: $actual_owner" >&2
    exit 1
  }
  branch="$(printf '%s\n' "$metadata" | cut -f4)"
  ref="$(GH_TOKEN="$token" gh api "repos/$repository/git/ref/heads/$branch" --jq .object.sha)"
  entries="$(GH_TOKEN="$token" gh api "repos/$repository/contents" --jq length)"
  printf '  %s\tbranch=%s\thead=%s\tentries=%s\n' "$metadata" "$branch" "$ref" "$entries"
done

echo "[4/4] optional limited-token read"
if [[ -n "${CSA_IEM_LIVE_GITHUB_LIMITED_TOKEN:-}" ]]; then
  limited_login="$(GH_TOKEN="$CSA_IEM_LIVE_GITHUB_LIMITED_TOKEN" gh api user --jq .login)"
  rate_remaining="$(GH_TOKEN="$CSA_IEM_LIVE_GITHUB_LIMITED_TOKEN" gh api rate_limit --jq .rate.remaining)"
  printf '  limited token identity=%s rate-limit remaining=%s\n' "$limited_login" "$rate_remaining"
else
  echo "  not configured; no limited token was inferred or fabricated"
fi

echo "PASS: live GitHub identity, scope-bound reads, and repository reachability verified without mutation"
