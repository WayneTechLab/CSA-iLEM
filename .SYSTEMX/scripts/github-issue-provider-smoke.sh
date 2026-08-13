#!/usr/bin/env bash
set -euo pipefail

# This harness is intentionally narrow and never deletes issues or repositories.
# It is not part of the release preflight because it performs remote writes to
# explicitly authorized temporary test repositories.

usage() {
  cat <<'EOF'
Usage:
  github-issue-provider-smoke.sh --confirm-retained-test-repos [--all]
  github-issue-provider-smoke.sh --confirm-retained-test-repos --repo OWNER/REPO

Allowed repositories are the retained CSA-iLEM test repositories:
  WayneTechLab/Flowers-Field-Guide
  WayneTechLab/Space-Field-Guide
  WayneTechLab/Birds-Field-Guide

The harness creates or reuses one marked test issue, comments, adds the
standard bug label, closes, reopens, and verifies the final provider state.
It never deletes an issue, repository, label, or local project.
EOF
}

confirmed=0
run_all=0
selected_repos=()

while (($# > 0)); do
  case "$1" in
    --confirm-retained-test-repos) confirmed=1 ;;
    --all) run_all=1 ;;
    --repo)
      (($# >= 2)) || { usage >&2; exit 2; }
      selected_repos+=("$2")
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

((confirmed == 1)) || { echo "Refusing remote test writes without --confirm-retained-test-repos." >&2; exit 2; }
command -v gh >/dev/null || { echo "GitHub CLI (gh) is required." >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required." >&2; exit 2; }

allowed_repos=(
  "WayneTechLab/Flowers-Field-Guide"
  "WayneTechLab/Space-Field-Guide"
  "WayneTechLab/Birds-Field-Guide"
)

if ((run_all == 1)); then
  selected_repos=("${allowed_repos[@]}")
fi
(( ${#selected_repos[@]} > 0 )) || { usage >&2; exit 2; }

for repo in "${selected_repos[@]}"; do
  case " ${allowed_repos[*]} " in
    *" $repo "*) ;;
    *) echo "Refusing non-allowlisted repository: $repo" >&2; exit 2 ;;
  esac
done

comment_body="CSA-iLEM provider verification comment fixture: read-back required."
title="[CSA-iLEM TEST] Provider verification retained"

for repo in "${selected_repos[@]}"; do
  echo "[provider-smoke] $repo"
  issue_number="$(gh issue list --repo "$repo" --state all --limit 100 --search "$title in:title" --json number,title --jq 'map(select(.title == "[CSA-iLEM TEST] Provider verification retained")) | .[0].number // empty')"
  if [[ -z "$issue_number" ]]; then
    issue_number="$(gh issue create --repo "$repo" --title "$title" --body $'Temporary CSA-iLEM provider verification fixture.\n\nThis issue is intentionally retained for controlled comment, label, close, reopen, read-back, failure, and retry testing. Do not delete without operator confirmation.' | sed -E 's#.*/issues/##')"
  fi

  current_json="$(gh issue view "$issue_number" --repo "$repo" --json state,labels,comments)"
  if ! jq -e --arg comment "$comment_body" 'any(.comments[]; .body == $comment)' <<<"$current_json" >/dev/null; then
    gh issue comment "$issue_number" --repo "$repo" --body "$comment_body" >/dev/null
  fi
  if ! jq -e 'any(.labels[]; .name == "bug")' <<<"$current_json" >/dev/null; then
    gh issue edit "$issue_number" --repo "$repo" --add-label bug >/dev/null
  fi

  state="$(gh issue view "$issue_number" --repo "$repo" --json state --jq '.state')"
  if [[ "$state" == "OPEN" ]]; then
    gh issue close "$issue_number" --repo "$repo" --reason completed >/dev/null
  fi
  gh issue reopen "$issue_number" --repo "$repo" >/dev/null

  final_json="$(gh issue view "$issue_number" --repo "$repo" --json number,state,labels,comments)"
  jq -e --arg comment "$comment_body" '(.state == "OPEN") and (any(.labels[]; .name == "bug")) and (any(.comments[]; .body == $comment))' <<<"$final_json" >/dev/null
  echo "PASS $repo#$issue_number state=OPEN label=bug comment=verified retained=true"
done

echo "PASS: provider smoke completed; no remote test data was deleted."
