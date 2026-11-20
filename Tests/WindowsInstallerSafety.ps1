Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repository = Split-Path -Parent $PSScriptRoot
$TemporaryBase = [System.IO.Path]::GetTempPath()
if ($TemporaryBase.StartsWith('/var/')) { $TemporaryBase = '/private' + $TemporaryBase }
$TemporaryRoot = Join-Path $TemporaryBase ("csa-iem-windows-installer-test-" + [guid]::NewGuid().ToString('N'))
$InstallRoot = Join-Path $TemporaryRoot 'CSA-iEM'

function Import-Functions {
    param([string]$ScriptPath)
    $Tokens = $null
    $Errors = $null
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$Tokens, [ref]$Errors)
    if ($Errors.Count -ne 0) { throw "PowerShell parse error in $ScriptPath`: $($Errors[0])" }
    foreach ($Definition in $Ast.FindAll({ param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        $ScriptScopedDefinition = $Definition.Extent.Text -replace ("^function\s+" + [regex]::Escape($Definition.Name)), ("function script:" + $Definition.Name)
        Invoke-Expression $ScriptScopedDefinition
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Description)
    if ($Actual -cne $Expected) { throw "$Description`: expected '$Expected', got '$Actual'" }
}

try {
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    $Owned = Join-Path $InstallRoot '0.8.0'
    $Unmarked = Join-Path $InstallRoot '0.7.0'
    $Unrelated = Join-Path $InstallRoot 'photos'
    foreach ($Path in @($Owned, $Unmarked, $Unrelated)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    '0.8.0' | Set-Content -LiteralPath (Join-Path $Owned 'VERSION')
    'test CLI' | Set-Content -LiteralPath (Join-Path $Owned 'CSA-iEM.ps1')
    "com.waynetechlab.csa-iem|0.8.0|$InstallRoot" | Set-Content -LiteralPath (Join-Path $Owned '.csa-iem-install-receipt.txt')
    '0.7.0' | Set-Content -LiteralPath (Join-Path $Unmarked 'VERSION')
    'test CLI' | Set-Content -LiteralPath (Join-Path $Unmarked 'CSA-iEM.ps1')

    Import-Functions (Join-Path $Repository 'install.ps1')
    Assert-Equal (Assert-SafeInstallRoot $InstallRoot) $InstallRoot 'dedicated root accepted'
    Assert-Equal (Test-OwnedVersionDir -Path $Owned -Root $InstallRoot) $true 'owned version recognized'
    Assert-Equal (Test-OwnedVersionDir -Path $Unmarked -Root $InstallRoot) $false 'unmarked version preserved'
    Assert-Equal (Test-OwnedVersionDir -Path $Unrelated -Root $InstallRoot) $false 'unrelated child preserved'
    $Receipt = Join-Path $Owned '.csa-iem-install-receipt.txt'
    'other-product|0.8.0' | Set-Content -LiteralPath $Receipt
    Assert-Equal (Test-OwnedVersionDir -Path $Owned -Root $InstallRoot) $false 'tampered receipt rejected'
    "com.waynetechlab.csa-iem|0.8.0|$InstallRoot" | Set-Content -LiteralPath $Receipt
    $Rejected = $false
    try { Assert-SafeInstallRoot $TemporaryRoot | Out-Null } catch { $Rejected = $true }
    Assert-Equal $Rejected $true 'arbitrary parent root rejected'
    $LinkedRoot = Join-Path $TemporaryRoot 'linked'
    New-Item -ItemType SymbolicLink -Path $LinkedRoot -Target $InstallRoot | Out-Null
    $Rejected = $false
    try { Assert-PhysicalDirectoryPath $LinkedRoot | Out-Null } catch { $Rejected = $true }
    Assert-Equal $Rejected $true 'junction or symlink rejected'
    $LinkedChild = Join-Path $Owned 'linked-child'
    New-Item -ItemType SymbolicLink -Path $LinkedChild -Target $Unrelated | Out-Null
    Assert-Equal (Test-OwnedVersionDir -Path $Owned -Root $InstallRoot) $false 'linked child blocks recursive deletion'
    Remove-Item -LiteralPath $LinkedChild -Force

    $Bin = Join-Path $InstallRoot 'bin'
    New-Item -ItemType Directory -Path $Bin | Out-Null
    $Shim = Join-Path $Bin 'csa-iem.cmd'
    Write-CmdShim -Path $Shim -ScriptAbsolutePath (Join-Path $Owned 'CSA-iEM.ps1')
    Assert-Equal (Test-OwnedShim -Path $Shim -Root $InstallRoot) $true 'owned shim recognized'
    'unrelated command' | Set-Content -LiteralPath $Shim
    Assert-Equal (Test-OwnedShim -Path $Shim -Root $InstallRoot) $false 'unrelated shim preserved'
    Write-CmdShim -Path $Shim -ScriptAbsolutePath (Join-Path $Owned 'CSA-iEM.ps1')

    $OwnedCandidates = @(Get-ChildItem -LiteralPath $InstallRoot -Directory | Where-Object { Test-OwnedVersionDir -Path $_.FullName -Root $InstallRoot })
    Assert-Equal $OwnedCandidates.Count 1 'cleanup selects only owned version'
    Assert-Equal $OwnedCandidates[0].Name '0.8.0' 'cleanup selects expected version'

    Import-Functions (Join-Path $Repository 'uninstall.ps1')
    Assert-Equal (Test-OwnedVersionDir -Path $Owned -Root $InstallRoot) $true 'uninstall recognizes owned version'
    Assert-Equal (Test-OwnedShim -Path $Shim -Root $InstallRoot -OwnedVersions @('0.8.0')) $true 'uninstall recognizes owned shim'
    $OwnedCandidates = @(Get-ChildItem -LiteralPath $InstallRoot -Directory | Where-Object { Test-OwnedVersionDir -Path $_.FullName -Root $InstallRoot })
    foreach ($Candidate in $OwnedCandidates) { Remove-Item -LiteralPath $Candidate.FullName -Recurse -Force }
    Assert-Equal (Test-Path -LiteralPath $Owned) $false 'verified version removed'
    Assert-Equal (Test-Path -LiteralPath $Unmarked) $true 'unmarked version retained'
    Assert-Equal (Test-Path -LiteralPath $Unrelated) $true 'unrelated folder retained'
    Write-Host 'Windows installer ownership safety: PASS'
} finally {
    if (Test-Path -LiteralPath $TemporaryRoot) { Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force }
}
