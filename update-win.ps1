Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionFile = Join-Path $ScriptDir "VERSION"
$AppVersion = if (Test-Path $VersionFile) { (Get-Content -Path $VersionFile -TotalCount 1).Trim() } else { "0.0.0" }
$AppName = "CSA-iEM"
$AppVendor = "Wayne Tech Lab LLC"

function Get-DefaultInstallRoot {
    $Candidate = Split-Path -Parent $ScriptDir
    if ($Candidate -and (Test-Path (Join-Path $Candidate "current.txt"))) {
        return $Candidate
    }

    return (Join-Path $env:LOCALAPPDATA "CSA-iEM")
}

$InstallRoot = Get-DefaultInstallRoot
$BinDir = Join-Path $InstallRoot "bin"
$RepoSlug = "WayneTechLab/CSA-iLEM"
$RefValue = "main"
$BootstrapDeps = $true
$UpdatePath = $true
$KeepTemp = $false
$ShowHelp = $false
$ShowVersion = $false

for ($Index = 0; $Index -lt $args.Count; $Index++) {
    switch ($args[$Index]) {
        "--help" { $ShowHelp = $true }
        "-h" { $ShowHelp = $true }
        "--version" { $ShowVersion = $true }
        "--repo" {
            $Index++
            $RepoSlug = $args[$Index]
        }
        "--ref" {
            $Index++
            $RefValue = $args[$Index]
        }
        "--install-root" {
            $Index++
            $InstallRoot = $args[$Index]
            $BinDir = Join-Path $InstallRoot "bin"
        }
        "--bin-dir" {
            $Index++
            $BinDir = $args[$Index]
        }
        "--no-deps" { $BootstrapDeps = $false }
        "--no-path-update" { $UpdatePath = $false }
        "--keep-temp" { $KeepTemp = $true }
        default { throw "Unknown argument: $($args[$Index])" }
    }
}

if ($ShowVersion) {
    Write-Host "$AppName Windows updater $AppVersion"
    exit 0
}

if ($ShowHelp) {
    @"
$AppName Windows updater
Version: $AppVersion
Provider: $AppVendor

Usage:
  csa-iem-update
  csa-iem-update --ref 0.3.5
  powershell -ExecutionPolicy Bypass -File .\update-win.ps1

Options:
  --ref VERSION_OR_BRANCH
  --repo OWNER/REPO
  --install-root PATH
  --bin-dir PATH
  --no-deps
  --no-path-update
  --keep-temp
  --version
  --help

Note:
  csa-iem-update pulls from the published GitHub repo.
  If you want to keep newer local repo changes that are not pushed yet,
  run the repo-local installer instead:
    cd H:\WTL-CODE-X\CSA-iEM
    powershell -ExecutionPolicy Bypass -File .\install.ps1 --force
"@ | Write-Host
    exit 0
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows update is supported only on Windows."
}

$RemoteInstallerPath = Join-Path $ScriptDir "install-remote.ps1"
if (-not (Test-Path $RemoteInstallerPath)) {
    throw "install-remote.ps1 was not found next to update-win.ps1."
}

$UpdateArgs = @(
    "--repo", $RepoSlug,
    "--ref", $RefValue,
    "--install-root", $InstallRoot,
    "--bin-dir", $BinDir,
    "--force"
)

if (-not $BootstrapDeps) {
    $UpdateArgs += "--no-deps"
}
if (-not $UpdatePath) {
    $UpdateArgs += "--no-path-update"
}
if ($KeepTemp) {
    $UpdateArgs += "--keep-temp"
}

Write-Host "$AppName Windows update"
Write-Host "Install root: $InstallRoot"
Write-Host "Command dir: $BinDir"
Write-Host "Target repo: $RepoSlug"
Write-Host "Target ref: $RefValue"
Write-Host ""

& $RemoteInstallerPath @UpdateArgs
