#!/usr/bin/env bash
set -euo pipefail

# Non-destructive release gate for the native CSA-iLEM repository.
# This script never installs, launches, mutates, uploads, or deletes projects.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/15] Swift regression tests"
swift test

echo "[2/15] Swift release build"
swift build -c release

echo "[3/15] SYSTEMX plan validation"
node .SYSTEMX/scripts/validate-10000-task-plan.mjs

echo "[4/15] Shell syntax"
bash -n CSA-iLEM.sh stage2-workspace.sh stage3-cleanup.sh install.sh build-gui-app.sh ".SYSTEMX/scripts/release-manifest-smoke.sh" ".SYSTEMX/scripts/github-live-readonly-smoke.sh" ".SYSTEMX/scripts/powershell-parse-smoke.sh" ".SYSTEMX/scripts/remote-install-live-smoke.sh" ".SYSTEMX/scripts/validate-macos-release-tag.sh" ".SYSTEMX/scripts/macos-release-tag-smoke.sh" ".SYSTEMX/scripts/verify-firebase-apple-config.sh"

echo "[5/15] PowerShell static syntax"
bash .SYSTEMX/scripts/powershell-parse-smoke.sh

echo "[6/15] SHA-256 manifest"
shasum -a 256 -c --strict SHA256SUMS

echo "[7/15] Firebase Apple configuration"
bash .SYSTEMX/scripts/verify-firebase-apple-config.sh

echo "[8/15] Git whitespace"
git diff --check

echo "[9/15] Repository boundary"
if git grep -n -i -E 'webapp[-_ ]?stack[-_ ]?g1|webstack[-_ ]?g1|webapp stack' -- ':!.SYSTEMX/scripts/release-preflight.sh'; then
  echo "FAIL: unrelated project boundary reference detected" >&2
  exit 1
fi

echo "[10/15] GitHub Actions exclusion"
if [[ -d .github/workflows ]]; then
  workflow_files="$(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print)"
  if [[ -n "$workflow_files" ]]; then
    echo "FAIL: this Firebase/Google Cloud project must not contain GitHub Actions workflows" >&2
    printf '%s\n' "$workflow_files" >&2
    exit 1
  fi
fi
echo "PASS: no GitHub Actions workflows are configured"

echo "[11/15] Release manifest smoke"
bash .SYSTEMX/scripts/release-manifest-smoke.sh

echo "[12/15] macOS release tag smoke"
bash .SYSTEMX/scripts/macos-release-tag-smoke.sh

echo "[13/15] Disposable lifecycle smoke"
bash .SYSTEMX/scripts/install-lifecycle-smoke.sh

echo "[14/15] Recovery safety smoke"
bash .SYSTEMX/scripts/recovery-safety-smoke.sh

echo "[15/15] GitHub identity-scope smoke"
bash .SYSTEMX/scripts/github-identity-scope-smoke.sh

echo "PASS: CSA-iLEM release preflight"
