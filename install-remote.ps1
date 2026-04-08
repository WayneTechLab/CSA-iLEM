Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AppName = "CSA-iEM"
$AppVendor = "Wayne Tech Lab LLC"
$LocalVersionFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "VERSION"
$InstallerVersion = if (Test-Path $LocalVersionFile) { (Get-Content -Path $LocalVersionFile -TotalCount 1).Trim() } else { "0.0.0" }
$RepoSlug = "WayneTechLab/CSA-iLEM"
$RefValue = "main"
$InstallRoot = ""
$BinDir = ""
$ForceInstall = $false
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
        }
        "--bin-dir" {
            $Index++
            $BinDir = $args[$Index]
        }
        "--force" { $ForceInstall = $true }
        "--no-deps" { $BootstrapDeps = $false }
        "--no-path-update" { $UpdatePath = $false }
        "--keep-temp" { $KeepTemp = $true }
        default { throw "Unknown argument: $($args[$Index])" }
    }
}

if ($ShowVersion) {
    Write-Host "$AppName Windows remote installer $InstallerVersion"
    exit 0
}

if ($ShowHelp) {
    @"
$AppName Windows remote installer
Version: $InstallerVersion
Provider: $AppVendor

Usage:
  # Windows 11 PowerShell / Windows Terminal
  powershell -ExecutionPolicy Bypass -File .\install-remote.ps1
  powershell -ExecutionPolicy Bypass -File .\install-remote.ps1 --force
  powershell -ExecutionPolicy Bypass -File .\install-remote.ps1 --ref 0.3.5
"@ | Write-Host
    exit 0
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows install is supported only on Windows."
}

function Test-Checksums {
    param([string]$SourceRoot)
    $ChecksumPath = Join-Path $SourceRoot "SHA256SUMS"
    if (-not (Test-Path $ChecksumPath)) {
        throw "The downloaded archive does not contain SHA256SUMS."
    }

    foreach ($Line in (Get-Content -Path $ChecksumPath)) {
        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }
        $Parts = $Line -split "\s+", 2
        if ($Parts.Count -lt 2) {
            continue
        }
        $ExpectedHash = $Parts[0].Trim().ToLowerInvariant()
        $RelativePath = $Parts[1].Trim().TrimStart("*").Trim()
        $TargetPath = Join-Path $SourceRoot $RelativePath
        if (-not (Test-Path $TargetPath)) {
            throw "Missing file from checksum manifest: $RelativePath"
        }
        $ActualHash = (Get-FileHash -Algorithm SHA256 -Path $TargetPath).Hash.ToLowerInvariant()
        if ($ExpectedHash -ne $ActualHash) {
            throw "Checksum mismatch for $RelativePath"
        }
    }
}

$TempRoot = Join-Path $env:TEMP ("csa-iem-install-" + [guid]::NewGuid().ToString("N"))
$ZipPath = Join-Path $TempRoot "csa-iem.zip"
$ApiUrl = "https://api.github.com/repos/$RepoSlug/zipball/$RefValue"

New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

try {
    Write-Host "Downloading $AppName from $RepoSlug ($RefValue)..."
    Invoke-WebRequest -Uri $ApiUrl -OutFile $ZipPath

    Write-Host "Extracting installer bundle..."
    Expand-Archive -Path $ZipPath -DestinationPath $TempRoot -Force

    $SourceDir = Get-ChildItem -Path $TempRoot -Directory | Where-Object { $_.Name -notlike "*.zip" } | Select-Object -First 1
    if (-not $SourceDir) {
        throw "The downloaded archive did not extract correctly."
    }

    $VersionFile = Join-Path $SourceDir.FullName "VERSION"
    if (-not (Test-Path $VersionFile)) {
        throw "The downloaded archive does not contain a VERSION file."
    }

    $ArchiveVersion = (Get-Content -Path $VersionFile -TotalCount 1).Trim()
    if ($RefValue -match "^[0-9]+\.[0-9]+\.[0-9]+$" -and $ArchiveVersion -ne $RefValue) {
        throw "Requested ref $RefValue, but the archive reports VERSION $ArchiveVersion."
    }

    Write-Host "Verifying installer bundle checksums..."
    Test-Checksums -SourceRoot $SourceDir.FullName

    $InstallArgs = @()
    if ($InstallRoot) {
        $InstallArgs += @("--install-root", $InstallRoot)
    }
    if ($BinDir) {
        $InstallArgs += @("--bin-dir", $BinDir)
    }
    if ($ForceInstall) {
        $InstallArgs += "--force"
    }
    if (-not $BootstrapDeps) {
        $InstallArgs += "--no-deps"
    }
    if (-not $UpdatePath) {
        $InstallArgs += "--no-path-update"
    }

    Write-Host "Running local installer..."
    & (Join-Path $SourceDir.FullName "install.ps1") @InstallArgs
} finally {
    if (-not $KeepTemp -and (Test-Path $TempRoot)) {
        Remove-Item -Path $TempRoot -Recurse -Force
    }
}

Write-Host ""
Write-Host "$AppName Windows remote install finished."
Write-Host "Verify with:"
Write-Host "  csa-iem --version"
