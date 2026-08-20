#!/usr/bin/env bash
set -euo pipefail

# Non-destructive release gate for the native CSA-iLEM repository.
# This script never installs, launches, mutates, uploads, or deletes projects.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/13] Swift regression tests"
swift test

echo "[2/13] Swift release build"
swift build -c release

echo "[3/13] SYSTEMX plan validation"
node .SYSTEMX/scripts/validate-10000-task-plan.mjs

echo "[4/13] Shell syntax"
bash -n CSA-iLEM.sh stage2-workspace.sh stage3-cleanup.sh install.sh build-gui-app.sh ".SYSTEMX/scripts/release-manifest-smoke.sh" ".SYSTEMX/scripts/github-live-readonly-smoke.sh" ".SYSTEMX/scripts/powershell-parse-smoke.sh" ".SYSTEMX/scripts/remote-install-live-smoke.sh" ".SYSTEMX/scripts/validate-macos-release-tag.sh" ".SYSTEMX/scripts/macos-release-tag-smoke.sh"

echo "[5/13] PowerShell static syntax"
bash .SYSTEMX/scripts/powershell-parse-smoke.sh

echo "[6/13] SHA-256 manifest"
shasum -a 256 -c --strict SHA256SUMS

echo "[7/13] Git whitespace"
git diff --check

echo "[8/13] Repository boundary"
if git grep -n -i -E 'webapp[-_ ]?stack[-_ ]?g1|webstack[-_ ]?g1|webapp stack' HEAD -- ':!.github/workflows/csa-ilem-preflight.yml' ':!.SYSTEMX/scripts/release-preflight.sh'; then
  echo "FAIL: unrelated project boundary reference detected" >&2
  exit 1
fi

echo "[9/13] Release manifest smoke"
bash .SYSTEMX/scripts/release-manifest-smoke.sh

echo "[10/13] macOS release tag smoke"
bash .SYSTEMX/scripts/macos-release-tag-smoke.sh

echo "[11/13] Disposable lifecycle smoke"
bash .SYSTEMX/scripts/install-lifecycle-smoke.sh

echo "[12/13] Recovery safety smoke"
bash .SYSTEMX/scripts/recovery-safety-smoke.sh

echo "[13/13] GitHub identity-scope smoke"
bash .SYSTEMX/scripts/github-identity-scope-smoke.sh

echo "PASS: CSA-iLEM release preflight"
