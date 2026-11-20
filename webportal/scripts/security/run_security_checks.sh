#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .SYSTEMX/scripts/security-check.mjs ]]; then
  node .SYSTEMX/scripts/security-check.mjs
  [[ -f .SYSTEMX/scripts/account-level-check.mjs ]] && node .SYSTEMX/scripts/account-level-check.mjs
else
  echo "INFO: .SYSTEMX security checker is not installed in this standalone starter copy."
  echo "Run npm audit --audit-level=high as the fallback security gate."
  npm audit --audit-level=high || {
    echo "WARN: npm audit reported issues; install the full .SYSTEMX checker or run npm run ci:audit for strict enforcement."
  }
fi
