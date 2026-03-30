Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionFile = Join-Path $ScriptDir "VERSION"
$AppVersion = if (Test-Path $VersionFile) { (Get-Content -Path $VersionFile -TotalCount 1).Trim() } else { "0.3.2" }
$AppName = "CSA-iEM"
$AppVendor = "Wayne Tech Lab LLC"
$AppUrl = "https://www.WayneTechLab.com"

$InstallRoot = Join-Path $env:LOCALAPPDATA "CSA-iEM"
$BinDir = Join-Path $InstallRoot "bin"
$ForceInstall = $false
$BootstrapDeps = $true
$UpdatePath = $true
$ShowHelp = $false
$ShowVersion = $false

for ($Index = 0; $Index -lt $args.Count; $Index++) {
    switch ($args[$Index]) {
        "--help" { $ShowHelp = $true }
        "-h" { $ShowHelp = $true }
        "--version" { $ShowVersion = $true }
        "--install-root" {
            $Index++
            $InstallRoot = $args[$Index]
        }
        "--bin-dir" {
            $Index++
            $BinDir = $args[$Index]
        }
        "--force" { $ForceInstall = $true }
        "--no-deps" { $BootstrapDeps = $false }
        "--no-path-update" { $UpdatePath = $false }
        default { throw "Unknown argument: $($args[$Index])" }
    }
}

if ($ShowVersion) {
    Write-Host "$AppName $AppVersion"
    exit 0
}

if ($ShowHelp) {
    @"
$AppName Windows installer
Version: $AppVersion
Provider: $AppVendor
Website: $AppUrl

Usage:
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 --force
  powershell -ExecutionPolicy Bypass -File .\install.ps1 --no-deps
  powershell -ExecutionPolicy Bypass -File .\install.ps1 --install-root C:\Tools\CSA-iEM --bin-dir C:\Tools\CSA-iEM\bin
"@ | Write-Host
    exit 0
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows install is supported only on Windows."
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Test-Admin {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WingetPackageIfMissing {
    param(
        [string]$CommandName,
        [string]$WingetId,
        [string]$Label
    )

    if (Test-CommandAvailable $CommandName) {
        Write-Info "$Label is already available."
        return
    }

    if (-not (Test-CommandAvailable "winget")) {
        Write-WarnLine "winget is not available, so $Label could not be installed automatically."
        return
    }

    Write-Info "Installing $Label with winget..."
    & winget install --id $WingetId -e --accept-package-agreements --accept-source-agreements
}

function Ensure-DevcontainerCli {
    if (Test-CommandAvailable "devcontainer") {
        Write-Info "Dev Containers CLI is already available."
        return
    }

    if (-not (Test-CommandAvailable "npm")) {
        Write-WarnLine "npm is not available, so the Dev Containers CLI could not be installed automatically."
        return
    }

    Write-Info "Installing Dev Containers CLI with npm..."
    & npm install -g @devcontainers/cli
}

function Bootstrap-Dependencies {
    if (-not (Test-Admin)) {
        Write-WarnLine "Installer is not running as Administrator. Dependency bootstrap may prompt or fail for system packages."
    }

    Install-WingetPackageIfMissing -CommandName "git" -WingetId "Git.Git" -Label "Git"
    Install-WingetPackageIfMissing -CommandName "gh" -WingetId "GitHub.cli" -Label "GitHub CLI"
    Install-WingetPackageIfMissing -CommandName "node" -WingetId "OpenJS.NodeJS.LTS" -Label "Node.js"
    Install-WingetPackageIfMissing -CommandName "code" -WingetId "Microsoft.VisualStudioCode" -Label "Visual Studio Code"
    Install-WingetPackageIfMissing -CommandName "docker" -WingetId "Docker.DockerDesktop" -Label "Docker Desktop"
    Ensure-DevcontainerCli
}

function Copy-InstallTree {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot
    )

    $Files = @(
        "VERSION",
        "README.md",
        "LICENSE.txt",
        "NOTICE.md",
        "TERMS-OF-SERVICE.md",
        "PRIVACY-NOTICE.md",
        "DISCLAIMER.md",
        "CHANGELOG.md",
        "STATUS.md",
        "SECURITY.md",
        "PROJECT-INFO.md",
        "SHA256SUMS",
        "CSA-iEM.ps1",
        "install.ps1",
        "install-remote.ps1",
        "uninstall.ps1"
    )

    $Dirs = @(
        "docs",
        "assets"
    )

    Ensure-Directory $DestinationRoot
    foreach ($File in $Files) {
        $SourcePath = Join-Path $SourceRoot $File
        if (Test-Path $SourcePath) {
            Copy-Item -Path $SourcePath -Destination (Join-Path $DestinationRoot $File) -Force
        }
    }

    foreach ($Dir in $Dirs) {
        $SourcePath = Join-Path $SourceRoot $Dir
        if (Test-Path $SourcePath) {
            Copy-Item -Path $SourcePath -Destination (Join-Path $DestinationRoot $Dir) -Recurse -Force
        }
    }
}

function Set-UserPathIfMissing {
    param([string]$PathToAdd)
    $CurrentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $Parts = @($CurrentUserPath -split ";") | Where-Object { $_ }
    if ($Parts -contains $PathToAdd) {
        return
    }

    $NewPath = if ($CurrentUserPath) { "$CurrentUserPath;$PathToAdd" } else { $PathToAdd }
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
}

function Write-CmdShim {
    param(
        [string]$Path,
        [string]$ScriptAbsolutePath,
        [string[]]$DefaultArgs = @()
    )

    $ArgText = if ($DefaultArgs.Count -gt 0) { ($DefaultArgs -join " ") + " %*" } else { "%*" }
    $EscapedScriptPath = $ScriptAbsolutePath.Replace('"', '""')
    @"
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "$EscapedScriptPath" $ArgText
"@ | Set-Content -Path $Path -Encoding ASCII
}

if ($BootstrapDeps) {
    Bootstrap-Dependencies
}

$InstallDir = Join-Path $InstallRoot $AppVersion
if ((Test-Path $InstallDir) -and -not $ForceInstall) {
    Write-WarnLine "$AppName $AppVersion is already installed at $InstallDir"
    Write-Host "Use --force to reinstall."
    exit 0
}

Ensure-Directory $InstallRoot
Ensure-Directory $BinDir

if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
}

Copy-InstallTree -SourceRoot $ScriptDir -DestinationRoot $InstallDir

$CliScriptPath = Join-Path $InstallDir "CSA-iEM.ps1"
Write-CmdShim -Path (Join-Path $BinDir "csa-iem.cmd") -ScriptAbsolutePath $CliScriptPath
Write-CmdShim -Path (Join-Path $BinDir "csa-iem-open.cmd") -ScriptAbsolutePath $CliScriptPath -DefaultArgs @("--browse-projects", "--use-current-root")
Write-CmdShim -Path (Join-Path $BinDir "openproj.cmd") -ScriptAbsolutePath $CliScriptPath -DefaultArgs @("--browse-projects", "--use-current-root")

$CurrentPath = Join-Path $InstallRoot "current.txt"
$AppVersion | Set-Content -Path $CurrentPath -Encoding ASCII

if ($UpdatePath) {
    Set-UserPathIfMissing -PathToAdd $BinDir
}

Write-Host ""
Write-Host "$AppName $AppVersion installed for Windows 11."
Write-Host "Provider: $AppVendor"
Write-Host "Website: $AppUrl"
Write-Host "Install dir: $InstallDir"
Write-Host "Command dir: $BinDir"
Write-Host ""
Write-Host "Primary commands:"
Write-Host "  csa-iem"
Write-Host "  csa-iem-open"
Write-Host "  openproj"
Write-Host ""
Write-Host "Open a new PowerShell window, or refresh PATH in the current one with:"
Write-Host '  $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")'
Write-Host ""
Write-Host "Then verify:"
Write-Host "  csa-iem --version"
