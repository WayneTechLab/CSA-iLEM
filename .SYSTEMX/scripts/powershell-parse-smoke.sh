#!/usr/bin/env bash
set -euo pipefail

# Cross-platform static syntax gate for the Windows backend. This does not
# execute Windows operations or claim Windows hardware/runtime coverage.

if ! command -v pwsh >/dev/null 2>&1; then
  echo "SKIP: pwsh is unavailable; Windows runtime validation remains open"
  exit 0
fi

count=0
while IFS= read -r -d '' file; do
  PS_TARGET="$file" pwsh -NoLogo -NoProfile -NonInteractive -Command '
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($env:PS_TARGET, [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
      $errors | ForEach-Object { Write-Error $_.Message }
      exit 1
    }
  '
  count=$((count + 1))
done < <(find . -type f -name '*.ps1' -not -path './.git/*' -print0 | sort -z)

echo "PASS: PowerShell parser validated $count script(s); Windows runtime coverage remains separate"
