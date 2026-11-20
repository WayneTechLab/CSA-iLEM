Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AppName = "CSA-iEM"
$AppVendor = "Wayne Tech Lab LLC"
$LocalVersionFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "VERSION"
$InstallerVersion = if (Test-Path $LocalVersionFile) { (Get-Content -Path $LocalVersionFile -TotalCount 1).Trim() } else { "0.0.0" }
$RepoSlug = "WayneTechLab/CSA-iLEM"
$RefValue = ""
$ExpectedArchiveSha256 = ""
$InstallRoot = ""
$BinDir = ""
$ForceInstall = $false
$BootstrapDeps = $false
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
        "--archive-sha256" {
            $Index++
            $ExpectedArchiveSha256 = $args[$Index]
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
        "--with-deps" { $BootstrapDeps = $true }
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
  # Run a reviewed local script with independently obtained release evidence.
  powershell -ExecutionPolicy Bypass -File .\install-remote.ps1 --ref <40-character-commit-sha> --archive-sha256 <trusted-archive-sha256>

Options:
  --ref <sha>              Exact lowercase Git commit SHA; branches and tags are refused.
  --archive-sha256 <sha>   SHA-256 of the complete GitHub ZIP, obtained independently.
  --with-deps              Explicitly allow winget/npm dependency bootstrap.
"@ | Write-Host
    exit 0
}

if ($RefValue -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Remote install requires --ref with an exact lowercase 40-character commit SHA; mutable branches and tags are refused.'
}
if ($ExpectedArchiveSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'Remote install requires --archive-sha256 from an independent trusted release record.'
}
if ($RepoSlug -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$' -or $RepoSlug.Contains('..')) {
    throw 'Remote install requires a valid owner/repository slug.'
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "$AppName Windows install is supported only on Windows."
}

function Save-HttpsArchive {
    param([string]$Uri, [string]$Destination)
    Add-Type -AssemblyName System.Net.Http
    $Current = [uri]$Uri
    $Handler = [System.Net.Http.HttpClientHandler]::new()
    $Handler.AllowAutoRedirect = $false
    $Client = [System.Net.Http.HttpClient]::new($Handler)
    $Client.DefaultRequestHeaders.UserAgent.ParseAdd('CSA-iEM-Installer/0.8.0')
    try {
        for ($Redirect = 0; $Redirect -le 8; $Redirect++) {
            if ($Current.Scheme -cne 'https') { throw "Archive download refused a non-HTTPS URL: $Current" }
            $Response = $Client.GetAsync($Current, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            try {
                $Status = [int]$Response.StatusCode
                if ($Status -in @(301, 302, 303, 307, 308)) {
                    if (-not $Response.Headers.Location) { throw 'Archive redirect had no Location header.' }
                    $Current = [uri]::new($Current, $Response.Headers.Location)
                    continue
                }
                if (-not $Response.IsSuccessStatusCode) { throw "Archive download failed with HTTP $Status." }
                $InputStream = $Response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $OutputStream = [System.IO.FileStream]::new($Destination, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try { $InputStream.CopyTo($OutputStream) }
                finally { $OutputStream.Dispose(); $InputStream.Dispose() }
                return
            } finally {
                $Response.Dispose()
            }
        }
        throw 'Archive download exceeded the redirect limit.'
    } finally {
        $Client.Dispose()
        $Handler.Dispose()
    }
}

function Assert-ArchiveDigest {
    param([string]$ArchivePath, [string]$ExpectedSha256)
    $Actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath).Hash.ToLowerInvariant()
    if ($Actual -cne $ExpectedSha256) {
        throw 'Downloaded archive digest does not match the independently supplied SHA-256; nothing was extracted or installed.'
    }
}

function Test-Checksums {
    param([string]$SourceRoot)
    $ChecksumPath = Join-Path $SourceRoot "SHA256SUMS"
    if (-not (Test-Path -LiteralPath $ChecksumPath -PathType Leaf)) {
        throw "The downloaded archive does not contain SHA256SUMS."
    }

    $RootFull = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd([char[]]@('\', '/'))
    foreach ($Line in (Get-Content -LiteralPath $ChecksumPath)) {
        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }
        if ($Line -cnotmatch '^([0-9a-fA-F]{64})\s+\*?(.+)$') { throw 'Malformed SHA256SUMS entry.' }
        $ExpectedHash = $Matches[1].ToLowerInvariant()
        $RelativePath = $Matches[2].Trim()
        if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.?(?=[\\/]|$)' -or $RelativePath.Contains(':')) {
            throw "Unsafe checksum path: $RelativePath"
        }
        $TargetPath = [System.IO.Path]::GetFullPath((Join-Path $RootFull $RelativePath))
        if (-not $TargetPath.StartsWith(($RootFull + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Checksum path escaped archive root: $RelativePath"
        }
        if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
            throw "Missing file from checksum manifest: $RelativePath"
        }
        $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $TargetPath).Hash.ToLowerInvariant()
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
    Save-HttpsArchive -Uri $ApiUrl -Destination $ZipPath

    Assert-ArchiveDigest -ArchivePath $ZipPath -ExpectedSha256 $ExpectedArchiveSha256

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
    if ($BootstrapDeps) {
        $InstallArgs += "--with-deps"
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
