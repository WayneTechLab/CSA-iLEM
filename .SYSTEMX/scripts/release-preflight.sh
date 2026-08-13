#!/usr/bin/env bash
set -euo pipefail

# Non-destructive release gate for the native CSA-iLEM repository.
# This script never installs, launches, mutates, uploads, or deletes projects.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/11] Swift regression tests"
swift test

echo "[2/11] Swift release build"
swift build -c release

echo "[3/11] SYSTEMX plan validation"
node .SYSTEMX/scripts/validate-10000-task-plan.mjs

echo "[4/11] Shell syntax"
bash -n CSA-iLEM.sh stage2-workspace.sh stage3-cleanup.sh install.sh build-gui-app.sh ".SYSTEMX/scripts/release-manifest-smoke.sh" ".SYSTEMX/scripts/github-live-readonly-smoke.sh" ".SYSTEMX/scripts/powershell-parse-smoke.sh"

echo "[4b/11] PowerShell static syntax"
bash .SYSTEMX/scripts/powershell-parse-smoke.sh

echo "[5/11] SHA-256 manifest"
shasum -a 256 -c --strict SHA256SUMS

echo "[6/11] Git whitespace"
git diff --check

echo "[7/11] Repository boundary"
if git grep -n -i -E 'webapp[-_ ]?stack[-_ ]?g1|webstack[-_ ]?g1|webapp stack' HEAD -- ':!.github/workflows/csa-ilem-preflight.yml' ':!.SYSTEMX/scripts/release-preflight.sh'; then
  echo "FAIL: unrelated project boundary reference detected" >&2
  exit 1
fi

echo "[8/11] Release manifest smoke"
bash .SYSTEMX/scripts/release-manifest-smoke.sh

echo "[9/11] Disposable lifecycle smoke"
bash .SYSTEMX/scripts/install-lifecycle-smoke.sh

echo "[10/11] Recovery safety smoke"
bash .SYSTEMX/scripts/recovery-safety-smoke.sh

echo "[11/11] GitHub identity-scope smoke"
bash .SYSTEMX/scripts/github-identity-scope-smoke.sh

echo "PASS: CSA-iLEM release preflight"
