Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionFile = Join-Path $ScriptDir "VERSION"
$AppVersion = if (Test-Path $VersionFile) { (Get-Content -Path $VersionFile -TotalCount 1).Trim() } else { "0.0.0" }
$AppName = "CSA-iEM"

$InstallRoot = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "CSA-iEM"
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "CSA-iEM"
}
$BinDir = Join-Path $InstallRoot "bin"
$ShowHelp = $false
$ShowVersion = $false
$RemoveAll = $false

for ($Index = 0; $Index -lt $args.Count; $Index++) {
    switch ($args[$Index]) {
        "--help" { $ShowHelp = $true }
        "-h" { $ShowHelp = $true }
        "--version" { $ShowVersion = $true }
        "--install-root" {
            $Index++
            $InstallRoot = $args[$Index]
            $BinDir = Join-Path $InstallRoot "bin"
        }
        "--bin-dir" {
            $Index++
            $BinDir = $args[$Index]
        }
        "--all" { $RemoveAll = $true }
        default { throw "Unknown argument: $($args[$Index])" }
    }
}

if ($ShowVersion) {
    Write-Host "$AppName $AppVersion"
    exit 0
}

if ($ShowHelp) {
    @"
$AppName Windows uninstaller

Usage:
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 --all

Only receipt-verified CSA-iEM versions and matching command shims are removed.
Unknown folders and files are preserved, including under --all.
"@ | Write-Host
    exit 0
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows uninstall is supported only on Windows."
}

function Assert-SafeInstallRoot {
    param([string]$Path)
    $FullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    if ((Split-Path -Path $FullPath -Leaf) -ine "CSA-iEM") {
        throw "Install root must be a dedicated CSA-iEM directory: $FullPath"
    }
    $Cursor = $FullPath
    while ($Cursor) {
        if (Test-Path -LiteralPath $Cursor) {
            $Entry = Get-Item -LiteralPath $Cursor -Force
            if (($Entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Install root traverses a link or junction: $Cursor"
            }
        }
        $Parent = Split-Path -Path $Cursor -Parent
        if (-not $Parent -or $Parent -eq $Cursor) { break }
        $Cursor = $Parent
    }
    return $FullPath
}

function Test-PhysicalInstallTree {
    param([string]$Path)
    $Pending = [System.Collections.Generic.Stack[string]]::new()
    $Pending.Push($Path)
    $Count = 0
    try {
        while ($Pending.Count -gt 0) {
            foreach ($Child in (Get-ChildItem -LiteralPath $Pending.Pop() -Force -ErrorAction Stop)) {
                $Count++
                if ($Count -gt 200000 -or ($Child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
                if ($Child.PSIsContainer) { $Pending.Push($Child.FullName) }
            }
        }
    } catch { return $false }
    return $true
}

function Test-OwnedVersionDir {
    param([string]$Path, [string]$Root)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    $Entry = Get-Item -LiteralPath $Path -Force
    if (($Entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    $Version = $Entry.Name
    if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?$') { return $false }
    $ExpectedPath = [System.IO.Path]::GetFullPath((Join-Path $Root $Version))
    if (-not [string]::Equals($Entry.FullName, $ExpectedPath, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    $Receipt = Join-Path $Path '.csa-iem-install-receipt.txt'
    $VersionFile = Join-Path $Path 'VERSION'
    $CliFile = Join-Path $Path 'CSA-iEM.ps1'
    if (-not (Test-Path -LiteralPath $Receipt -PathType Leaf) -or
        -not (Test-Path -LiteralPath $VersionFile -PathType Leaf) -or
        -not (Test-Path -LiteralPath $CliFile -PathType Leaf)) { return $false }
    foreach ($Candidate in @($Receipt, $VersionFile, $CliFile)) {
        if (((Get-Item -LiteralPath $Candidate -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    }
    $ExpectedReceipt = "com.waynetechlab.csa-iem|$Version|$Root"
    $ActualReceipt = (Get-Content -LiteralPath $Receipt -TotalCount 1).Trim()
    $ActualVersion = (Get-Content -LiteralPath $VersionFile -TotalCount 1).Trim()
    return ($ActualReceipt -ceq $ExpectedReceipt -and $ActualVersion -ceq $Version -and (Test-PhysicalInstallTree -Path $Path))
}

function Test-OwnedShim {
    param([string]$Path, [string]$Root, [string[]]$OwnedVersions)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if (((Get-Item -LiteralPath $Path -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    $Content = Get-Content -LiteralPath $Path -Raw
    if ($Content -notmatch '(?s)^@echo off\r?\nsetlocal\r?\npowershell -NoProfile -ExecutionPolicy Bypass -File "([^"]+)" ([^\r\n]*)\r?\n?$') { return $false }
    $Target = $Matches[1]
    $Arguments = $Matches[2]
    $TargetDirectory = Split-Path -Path $Target -Parent
    $Version = Split-Path -Path $TargetDirectory -Leaf
    if ($OwnedVersions -notcontains $Version) { return $false }
    $ExpectedDir = [System.IO.Path]::GetFullPath((Join-Path $Root $Version))
    if (-not [string]::Equals($TargetDirectory, $ExpectedDir, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    $Shim = Split-Path -Path $Path -Leaf
    $Script = Split-Path -Path $Target -Leaf
    switch ($Shim) {
        'csa-iem.cmd' { return ($Script -ceq 'CSA-iEM.ps1' -and $Arguments -ceq '%*') }
        'csa-iem-open.cmd' { return ($Script -ceq 'CSA-iEM.ps1' -and $Arguments -ceq '--browse-projects --use-current-root %*') }
        'openproj.cmd' { return ($Script -ceq 'CSA-iEM.ps1' -and $Arguments -ceq '--browse-projects --use-current-root %*') }
        'csa-iem-update.cmd' { return ($Script -ceq 'update-win.ps1' -and $Arguments -ceq '%*') }
        'csa-ilem-update.cmd' { return ($Script -ceq 'update-win.ps1' -and $Arguments -ceq '%*') }
        'csa-iem-tray.cmd' { return ($Script -ceq 'csa-iem-tray.ps1' -and $Arguments -ceq '%*') }
        default { return $false }
    }
}

$InstallRoot = Assert-SafeInstallRoot -Path $InstallRoot
$VersionDir = Join-Path $InstallRoot $AppVersion
$CurrentMarker = Join-Path $InstallRoot "current.txt"

if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
    Write-Host "$AppName is not installed at $InstallRoot"
    exit 0
}

$OwnedVersions = @(Get-ChildItem -LiteralPath $InstallRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-OwnedVersionDir -Path $_.FullName -Root $InstallRoot } |
    ForEach-Object { $_.Name })
$VersionsToRemove = if ($RemoveAll) { $OwnedVersions } elseif ($OwnedVersions -contains $AppVersion) { @($AppVersion) } else { @() }
$CurrentVersion = if ((Test-Path -LiteralPath $CurrentMarker) -and
    (((Get-Item -LiteralPath $CurrentMarker -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0)) {
    (Get-Content -LiteralPath $CurrentMarker -TotalCount 1).Trim()
} else { "" }

if ($CurrentVersion -and ($VersionsToRemove -contains $CurrentVersion)) {
    foreach ($Shim in @("csa-iem.cmd", "csa-iem-open.cmd", "csa-iem-update.cmd", "csa-ilem-update.cmd", "openproj.cmd", "csa-iem-tray.cmd")) {
        $ShimPath = Join-Path $BinDir $Shim
        if (Test-OwnedShim -Path $ShimPath -Root $InstallRoot -OwnedVersions $OwnedVersions) {
            Remove-Item -LiteralPath $ShimPath -Force
        }
    }
    Remove-Item -LiteralPath $CurrentMarker -Force
}

foreach ($Version in $VersionsToRemove) {
    $OwnedPath = Join-Path $InstallRoot $Version
    if (Test-OwnedVersionDir -Path $OwnedPath -Root $InstallRoot) {
        Remove-Item -LiteralPath $OwnedPath -Recurse -Force
    }
}

if ($VersionsToRemove.Count -eq 0) {
    Write-Host "No receipt-verified $AppName version matched. Unrecognized files were preserved."
} else {
    Write-Host "$AppName removed $($VersionsToRemove.Count) verified version(s) from $InstallRoot; unrecognized files were preserved."
}
