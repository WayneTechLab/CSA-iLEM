Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionFile = Join-Path $ScriptDir "VERSION"
$AppVersion = if (Test-Path $VersionFile) { (Get-Content -Path $VersionFile -TotalCount 1).Trim() } else { "0.0.0" }
$AppName = "CSA-iEM"
$AppVendor = "Wayne Tech Lab LLC"
$AppUrl = "https://www.WayneTechLab.com"

$InstallRoot = if ($env:LOCALAPPDATA) {
    Join-Path $env:LOCALAPPDATA "CSA-iEM"
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "CSA-iEM"
}
$BinDir = Join-Path $InstallRoot "bin"
$ForceInstall = $true
$BootstrapDeps = $true
$UpdatePath = $true
$ShowHelp = $false
$ShowVersion = $false
$BinDirExplicit = $false

for ($Index = 0; $Index -lt $args.Count; $Index++) {
    switch ($args[$Index]) {
        "--help" { $ShowHelp = $true }
        "-h" { $ShowHelp = $true }
        "--version" { $ShowVersion = $true }
        "--install-root" {
            $Index++
            $InstallRoot = $args[$Index]
            if (-not $BinDirExplicit) { $BinDir = Join-Path $InstallRoot "bin" }
        }
        "--bin-dir" {
            $Index++
            $BinDir = $args[$Index]
            $BinDirExplicit = $true
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
  # Windows 11 PowerShell / Windows Terminal
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 --force
  powershell -ExecutionPolicy Bypass -File .\install.ps1 --no-deps
  powershell -ExecutionPolicy Bypass -File .\install.ps1 --install-root C:\Tools\CSA-iEM --bin-dir C:\Tools\CSA-iEM\bin

Install behavior:
  Installs and updates replace the target version by default, update current.txt,
  and remove only receipt-verified older CSA-iEM versions. Unknown folders stay.
"@ | Write-Host
    exit 0
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows install is supported only on Windows."
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

function Assert-PhysicalDirectoryPath {
    param([string]$Path)
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $Cursor = $FullPath
    while ($Cursor) {
        if (Test-Path -LiteralPath $Cursor) {
            $Entry = Get-Item -LiteralPath $Cursor -Force
            if (($Entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Directory path traverses a link or junction: $Cursor"
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
    param([string]$Path, [string]$Root)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if (((Get-Item -LiteralPath $Path -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    $Content = Get-Content -LiteralPath $Path -Raw
    if ($Content -notmatch '(?s)^@echo off\r?\nsetlocal\r?\npowershell -NoProfile -ExecutionPolicy Bypass -File "([^"]+)" ([^\r\n]*)\r?\n?$') { return $false }
    $Target = $Matches[1]
    $Arguments = $Matches[2]
    $TargetDirectory = Split-Path -Path $Target -Parent
    if (-not (Test-OwnedVersionDir -Path $TargetDirectory -Root $Root)) { return $false }
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
        "stage2-workspace.ps1",
        "stage2-workspace.sh",
        "stage3-cleanup.ps1",
        "stage3-cleanup.sh",
        "csa-iem-tray.ps1",
        "install.ps1",
        "install-remote.ps1",
        "update-win.ps1",
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

$InstallRoot = Assert-SafeInstallRoot -Path $InstallRoot
$BinDir = Assert-PhysicalDirectoryPath -Path $BinDir
$InstallDir = Join-Path $InstallRoot $AppVersion
if ((Test-Path $InstallDir) -and -not $ForceInstall) {
    Write-WarnLine "$AppName $AppVersion is already installed at $InstallDir"
    Write-Host "Use --force to reinstall."
    exit 0
}

if ((Test-Path -LiteralPath $InstallDir) -and -not (Test-OwnedVersionDir -Path $InstallDir -Root $InstallRoot)) {
    throw "Refusing to replace an unverified directory: $InstallDir"
}

$CurrentPath = Join-Path $InstallRoot "current.txt"
if (Test-Path -LiteralPath $CurrentPath) {
    if (((Get-Item -LiteralPath $CurrentPath -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to overwrite a linked current installation marker: $CurrentPath"
    }
    $CurrentVersion = (Get-Content -LiteralPath $CurrentPath -TotalCount 1).Trim()
    if (-not (Test-OwnedVersionDir -Path (Join-Path $InstallRoot $CurrentVersion) -Root $InstallRoot)) {
        throw "Refusing to overwrite an unverified current installation marker: $CurrentPath"
    }
}

$ShimNames = @("csa-iem.cmd", "csa-iem-open.cmd", "csa-iem-update.cmd", "csa-ilem-update.cmd", "openproj.cmd", "csa-iem-tray.cmd")
foreach ($Shim in $ShimNames) {
    $ShimPath = Join-Path $BinDir $Shim
    if ((Test-Path -LiteralPath $ShimPath) -and -not (Test-OwnedShim -Path $ShimPath -Root $InstallRoot)) {
        throw "Refusing to replace an unverified command shim: $ShimPath"
    }
}

Ensure-Directory $InstallRoot
Ensure-Directory $BinDir

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
}

Copy-InstallTree -SourceRoot $ScriptDir -DestinationRoot $InstallDir
"com.waynetechlab.csa-iem|$AppVersion|$InstallRoot" | Set-Content -LiteralPath (Join-Path $InstallDir '.csa-iem-install-receipt.txt') -Encoding ASCII

$CliScriptPath = Join-Path $InstallDir "CSA-iEM.ps1"
$TrayScriptPath = Join-Path $InstallDir "csa-iem-tray.ps1"
$UpdateScriptPath = Join-Path $InstallDir "update-win.ps1"
Write-CmdShim -Path (Join-Path $BinDir "csa-iem.cmd") -ScriptAbsolutePath $CliScriptPath
Write-CmdShim -Path (Join-Path $BinDir "csa-iem-open.cmd") -ScriptAbsolutePath $CliScriptPath -DefaultArgs @("--browse-projects", "--use-current-root")
Write-CmdShim -Path (Join-Path $BinDir "csa-iem-update.cmd") -ScriptAbsolutePath $UpdateScriptPath
Write-CmdShim -Path (Join-Path $BinDir "csa-ilem-update.cmd") -ScriptAbsolutePath $UpdateScriptPath
Write-CmdShim -Path (Join-Path $BinDir "openproj.cmd") -ScriptAbsolutePath $CliScriptPath -DefaultArgs @("--browse-projects", "--use-current-root")
Write-CmdShim -Path (Join-Path $BinDir "csa-iem-tray.cmd") -ScriptAbsolutePath $TrayScriptPath

$AppVersion | Set-Content -Path $CurrentPath -Encoding ASCII

Get-ChildItem -LiteralPath $InstallRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne $AppVersion -and (Test-OwnedVersionDir -Path $_.FullName -Root $InstallRoot) } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }

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
Write-Host "  csa-iem-tray"
Write-Host "  csa-iem-update"
Write-Host ""
Write-Host "Open a new PowerShell window, or refresh PATH in the current one with:"
Write-Host '  $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")'
Write-Host ""
Write-Host "Then verify:"
Write-Host "  csa-iem --version"
Write-Host "  csa-iem-update --help"
Write-Host ""
Write-Host "Update to a specific tag, branch, or commit:"
Write-Host "  csa-iem-update --ref your-tag-or-branch"
