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

for script in install.ps1 update-win.ps1 uninstall.ps1; do
  version_output="$(pwsh -NoLogo -NoProfile -NonInteractive -File "./$script" --version)"
  help_output="$(pwsh -NoLogo -NoProfile -NonInteractive -File "./$script" --help)"
  [[ -n "$version_output" && -n "$help_output" ]] || {
    echo "FAIL: $script inspection path returned empty output" >&2
    exit 1
  }
done

platform="$(pwsh -NoLogo -NoProfile -NonInteractive -Command '[System.Environment]::OSVersion.Platform')"
if [[ "$platform" != "Win32NT" ]]; then
  mutation_output="$(mktemp "${TMPDIR:-/tmp}/csa-ilem-powershell-mutation.XXXXXX")"
  set +e
  pwsh -NoLogo -NoProfile -NonInteractive -File ./install.ps1 --no-deps >"$mutation_output" 2>&1
  mutation_status=$?
  set -e
  rm -f "$mutation_output"
  [[ "$mutation_status" -ne 0 ]] || {
    echo "FAIL: install.ps1 mutation unexpectedly succeeded outside Windows" >&2
    exit 1
  }
  echo "PASS: Windows CLI inspection paths and non-Windows mutation guard verified"
else
  echo "PASS: Windows CLI inspection paths verified; Windows mutation runtime remains separate"
fi

echo "PASS: PowerShell parser validated $count script(s); Windows runtime coverage remains separate"
