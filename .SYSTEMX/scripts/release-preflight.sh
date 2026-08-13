#!/usr/bin/env bash
set -euo pipefail

# Non-destructive release gate for the native CSA-iLEM repository.
# This script never installs, launches, mutates, uploads, or deletes projects.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/7] Swift regression tests"
swift test

echo "[2/7] Swift release build"
swift build -c release

echo "[3/7] SYSTEMX plan validation"
node .SYSTEMX/scripts/validate-10000-task-plan.mjs

echo "[4/7] Shell syntax"
bash -n CSA-iLEM.sh stage2-workspace.sh stage3-cleanup.sh install.sh build-gui-app.sh

echo "[5/7] SHA-256 manifest"
shasum -a 256 -c --strict SHA256SUMS

echo "[6/7] Git whitespace"
git diff --check

echo "[7/7] Repository boundary"
if git grep -n -i -E 'webapp[-_ ]?stack[-_ ]?g1|webstack[-_ ]?g1|webapp stack' HEAD -- ':!.github/workflows/csa-ilem-preflight.yml' ':!.SYSTEMX/scripts/release-preflight.sh'; then
  echo "FAIL: unrelated project boundary reference detected" >&2
  exit 1
fi

echo "PASS: CSA-iLEM release preflight"
