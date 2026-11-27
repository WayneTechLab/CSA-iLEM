Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repository = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $Repository 'install-remote.ps1'
$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('csa-iem-remote-trust-' + [guid]::NewGuid().ToString('N'))

function Assert-Refused {
    param([string[]]$Arguments, [string]$ExpectedMessage, [string]$ScriptPath = $Script)
    $Output = & pwsh -NoLogo -NoProfile -NonInteractive -File $ScriptPath @Arguments 2>&1 | Out-String
    # PowerShell's console error renderer may color and wrap the message.
    $Message = $Output -replace '\x1b\[[0-?]*[ -/]*[@-~]', '' -replace '\r?\n[ \t]*\|[ \t]*', ' '
    if ($LASTEXITCODE -eq 0 -or -not $Message.Contains($ExpectedMessage)) {
        throw "Remote installer did not refuse $($Arguments -join ' '): $Output"
    }
}

function Import-Functions {
    $Tokens = $null
    $Errors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile($Script, [ref]$Tokens, [ref]$Errors)
    if ($Errors.Count -ne 0) { throw "PowerShell parse error: $($Errors[0])" }
    foreach ($Definition in $Ast.FindAll({ param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        $ScriptScopedDefinition = $Definition.Extent.Text -replace ('^function\s+' + [regex]::Escape($Definition.Name)), ('function script:' + $Definition.Name)
        Invoke-Expression $ScriptScopedDefinition
    }
}

try {
    New-Item -ItemType Directory -Path $TemporaryRoot -Force | Out-Null
    $Commit = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $Hash = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    Assert-Refused -Arguments @() -ExpectedMessage 'requires --ref'
    Assert-Refused -Arguments @('--ref', 'main', '--archive-sha256', $Hash) -ExpectedMessage 'mutable branches and tags are refused'
    Assert-Refused -Arguments @('--ref', $Commit) -ExpectedMessage 'requires --archive-sha256'
    Assert-Refused -Arguments @('--ref', $Commit, '--archive-sha256', $Hash, '--repo', '../other') -ExpectedMessage 'valid owner/repository slug'
    Assert-Refused -Arguments @() -ExpectedMessage 'Remote update requires --ref' -ScriptPath (Join-Path $Repository 'update-win.ps1')

    Import-Functions
    $Archive = Join-Path $TemporaryRoot 'fixture.zip'
    'fixture archive bytes' | Set-Content -LiteralPath $Archive -NoNewline
    $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Archive).Hash.ToLowerInvariant()
    Assert-ArchiveDigest -ArchivePath $Archive -ExpectedSha256 $Actual
    $Rejected = $false
    try { Assert-ArchiveDigest -ArchivePath $Archive -ExpectedSha256 $Hash } catch { $Rejected = $true }
    if (-not $Rejected) { throw 'Incorrect complete archive digest was accepted.' }

    $Rejected = $false
    try { Save-HttpsArchive -Uri 'http://127.0.0.1/fixture.zip' -Destination (Join-Path $TemporaryRoot 'download.zip') } catch { $Rejected = $true }
    if (-not $Rejected -or (Test-Path -LiteralPath (Join-Path $TemporaryRoot 'download.zip'))) {
        throw 'Non-HTTPS archive URL was accepted.'
    }

    $Source = Join-Path $TemporaryRoot 'source'
    New-Item -ItemType Directory -Path $Source | Out-Null
    'payload' | Set-Content -LiteralPath (Join-Path $Source 'README.md') -NoNewline
    $FileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Source 'README.md')).Hash.ToLowerInvariant()
    "$FileHash  README.md" | Set-Content -LiteralPath (Join-Path $Source 'SHA256SUMS')
    Test-Checksums -SourceRoot $Source
    "$FileHash  ../outside" | Set-Content -LiteralPath (Join-Path $Source 'SHA256SUMS')
    $Rejected = $false
    try { Test-Checksums -SourceRoot $Source } catch { $Rejected = $true }
    if (-not $Rejected) { throw 'Traversal in embedded checksum manifest was accepted.' }
    Write-Host 'Windows remote installer trust: PASS (offline; Windows execution remains separate)'
} finally {
    if (Test-Path -LiteralPath $TemporaryRoot) { Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force }
}
