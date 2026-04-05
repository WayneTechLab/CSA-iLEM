Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionFile = Join-Path $ScriptDir "VERSION"
$AppVersion = if (Test-Path $VersionFile) { (Get-Content -Path $VersionFile -TotalCount 1).Trim() } else { "0.0.0" }
$AppName = "CSA-iEM"

$InstallRoot = Join-Path $env:LOCALAPPDATA "CSA-iEM"
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
"@ | Write-Host
    exit 0
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows uninstall is supported only on Windows."
}

$VersionDir = Join-Path $InstallRoot $AppVersion
$CurrentMarker = Join-Path $InstallRoot "current.txt"

if ($RemoveAll) {
    if (Test-Path $InstallRoot) {
        Remove-Item -Path $InstallRoot -Recurse -Force
    }
    Write-Host "$AppName removed from $InstallRoot"
    exit 0
}

if (Test-Path $VersionDir) {
    Remove-Item -Path $VersionDir -Recurse -Force
}

$CurrentVersion = if (Test-Path $CurrentMarker) { (Get-Content -Path $CurrentMarker -TotalCount 1).Trim() } else { "" }
if ($CurrentVersion -eq $AppVersion) {
    foreach ($Shim in @("csa-iem.cmd", "csa-iem-open.cmd", "csa-iem-update.cmd", "csa-ilem-update.cmd", "openproj.cmd")) {
        $ShimPath = Join-Path $BinDir $Shim
        if (Test-Path $ShimPath) {
            Remove-Item -Path $ShimPath -Force
        }
    }
    if (Test-Path $CurrentMarker) {
        Remove-Item -Path $CurrentMarker -Force
    }
}

Write-Host "$AppName $AppVersion uninstalled."
