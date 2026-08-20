#!/usr/bin/env bash
set -euo pipefail

# Non-destructive release gate for the native CSA-iLEM repository.
# This script never installs, launches, mutates, uploads, or deletes projects.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/14] Swift regression tests"
swift test

echo "[2/14] Swift release build"
swift build -c release

echo "[3/14] SYSTEMX plan validation"
node .SYSTEMX/scripts/validate-10000-task-plan.mjs

echo "[4/14] Shell syntax"
bash -n CSA-iLEM.sh stage2-workspace.sh stage3-cleanup.sh install.sh build-gui-app.sh ".SYSTEMX/scripts/release-manifest-smoke.sh" ".SYSTEMX/scripts/github-live-readonly-smoke.sh" ".SYSTEMX/scripts/powershell-parse-smoke.sh" ".SYSTEMX/scripts/remote-install-live-smoke.sh" ".SYSTEMX/scripts/validate-macos-release-tag.sh" ".SYSTEMX/scripts/macos-release-tag-smoke.sh"

echo "[5/14] PowerShell static syntax"
bash .SYSTEMX/scripts/powershell-parse-smoke.sh

echo "[6/14] SHA-256 manifest"
shasum -a 256 -c --strict SHA256SUMS

echo "[7/14] Git whitespace"
git diff --check

echo "[8/14] Repository boundary"
if git grep -n -i -E 'webapp[-_ ]?stack[-_ ]?g1|webstack[-_ ]?g1|webapp stack' HEAD -- ':!.github/workflows/csa-ilem-preflight.yml' ':!.SYSTEMX/scripts/release-preflight.sh'; then
  echo "FAIL: unrelated project boundary reference detected" >&2
  exit 1
fi

echo "[9/14] GitHub Actions dependency pins"
CHECKOUT_SHA="3d3c42e5aac5ba805825da76410c181273ba90b1"
for workflow in .github/workflows/csa-ilem-preflight.yml .github/workflows/csa-ilem-macos-release.yml; do
  grep -Fq "uses: actions/checkout@$CHECKOUT_SHA # v7.0.1" "$workflow" || {
    echo "FAIL: $workflow must pin actions/checkout v7.0.1 to $CHECKOUT_SHA" >&2
    exit 1
  }
  grep -Fq "persist-credentials: false" "$workflow" || {
    echo "FAIL: $workflow must disable persisted checkout credentials" >&2
    exit 1
  }
done
if git grep -n -E 'uses:[[:space:]]+actions/checkout@v[0-9]+' -- '.github/workflows/*.yml' '.github/workflows/*.yaml'; then
  echo "FAIL: floating actions/checkout major references are not allowed" >&2
  exit 1
fi
echo "PASS: native workflows pin actions/checkout v7.0.1 with no persisted credentials"

echo "[10/14] Release manifest smoke"
bash .SYSTEMX/scripts/release-manifest-smoke.sh

echo "[11/14] macOS release tag smoke"
bash .SYSTEMX/scripts/macos-release-tag-smoke.sh

echo "[12/14] Disposable lifecycle smoke"
bash .SYSTEMX/scripts/install-lifecycle-smoke.sh

echo "[13/14] Recovery safety smoke"
bash .SYSTEMX/scripts/recovery-safety-smoke.sh

echo "[14/14] GitHub identity-scope smoke"
bash .SYSTEMX/scripts/github-identity-scope-smoke.sh

echo "PASS: CSA-iLEM release preflight"
