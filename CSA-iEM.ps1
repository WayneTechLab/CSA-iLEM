Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AppName = "CSA-iEM"
$AppVendor = "Wayne Tech Lab LLC"
$AppUrl = "https://www.WayneTechLab.com"
$AppVersion = "0.0.0"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionFile = Join-Path $ScriptDir "VERSION"
if (Test-Path $VersionFile) {
    $ReadVersion = (Get-Content -Path $VersionFile -TotalCount 1 -ErrorAction SilentlyContinue)
    if ($ReadVersion) {
        $AppVersion = $ReadVersion.Trim()
    }
}

$LocalAppRoot = Join-Path $env:LOCALAPPDATA "CSA-iEM"
$SettingsPath = Join-Path $LocalAppRoot "windows-settings.json"

$State = [ordered]@{
    GitHubHost = "github.com"
    Account = ""
    Repo = ""
    ImportMode = ""
    ImportFullAuto = $false
    ImportCleanupPreview = $false
    BrowseProjects = $false
    UseCurrentRoot = $false
    DisableWorkflows = $false
    DeleteRuns = $false
    DeleteArtifacts = $false
    DeleteCaches = $false
    DeleteCodespaces = $false
    All = $false
    Yes = $false
    DryRun = $false
    NoColor = $false
    Help = $false
    ShowVersion = $false
    CleanupOnly = $false
    SingleRoot = ""
    CodeRoot = ""
    ImportRoot = ""
    RuntimeRoot = ""
    RunFilter = ""
    RunId = ""
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrLine {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Section {
    param([string]$Title)
    $Rule = "=" * 80
    Write-Host ""
    Write-Host $Rule
    Write-Host $Title
    Write-Host $Rule
}

function Confirm-Action {
    param(
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    if ($State.Yes) {
        return $true
    }

    $Suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $Answer = Read-Host "$Prompt $Suffix"
    if ([string]::IsNullOrWhiteSpace($Answer)) {
        return $DefaultYes
    }

    return $Answer.Trim().ToLowerInvariant() -in @("y", "yes")
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Sanitize-Label {
    param([string]$Value)
    return (($Value -replace "[^A-Za-z0-9\-]+", "-").Trim("-")).ToLowerInvariant()
}

function Get-Timestamp {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Get-DefaultBaseRoot {
    return (Join-Path $HOME "CSA-iEM")
}

function Get-DefaultSingleRoot {
    return (Get-DefaultBaseRoot)
}

function Get-DefaultCodeRoot {
    return (Join-Path (Get-DefaultBaseRoot) "Code")
}

function Get-DefaultImportRoot {
    return (Join-Path (Get-DefaultBaseRoot) "Import")
}

function Get-DefaultRuntimeRoot {
    return (Join-Path (Get-DefaultBaseRoot) "Runtime")
}

function Get-DefaultSettings {
    return @{
        WorkspaceModel = "three-root"
        BaseRoot = (Get-DefaultBaseRoot)
        CodeRoot = (Get-DefaultCodeRoot)
        ImportRoot = (Get-DefaultImportRoot)
        RuntimeRoot = (Get-DefaultRuntimeRoot)
        GitHubHost = "github.com"
        Account = ""
    }
}

function Get-JsonStringValue {
    param(
        $Content,
        [string]$Name
    )

    if ($null -ne $Content -and $null -ne $Content.PSObject.Properties[$Name]) {
        return [string]$Content.$Name
    }

    return ""
}

function Get-PathLeafSafe {
    param([string]$Path)

    if (-not $Path) {
        return ""
    }

    $Trimmed = $Path.TrimEnd("\", "/")
    if (-not $Trimmed) {
        return ""
    }

    return [System.IO.Path]::GetFileName($Trimmed)
}

function Get-PathParentSafe {
    param([string]$Path)

    if (-not $Path) {
        return ""
    }

    $Trimmed = $Path.TrimEnd("\", "/")
    if (-not $Trimmed) {
        return ""
    }

    $Parent = [System.IO.Path]::GetDirectoryName($Trimmed)
    if ($null -eq $Parent) {
        return ""
    }

    return $Parent
}

function Join-PathSafe {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )

    if (-not $BasePath) {
        return $ChildPath
    }

    if (-not $ChildPath) {
        return $BasePath
    }

    return [System.IO.Path]::Combine($BasePath, $ChildPath)
}

function Get-ComparablePath {
    param([string]$Path)

    if (-not $Path) {
        return ""
    }

    $Trimmed = $Path.Trim()
    if (-not $Trimmed) {
        return ""
    }

    if ($Trimmed.Length -gt 3) {
        return $Trimmed.TrimEnd("\", "/")
    }

    return $Trimmed.TrimEnd("/")
}

function Normalize-WorkspaceLayout {
    param(
        [string]$BaseRoot,
        [string]$CodeRoot,
        [string]$ImportRoot,
        [string]$RuntimeRoot
    )

    $ComparableCodeRoot = Get-ComparablePath $CodeRoot
    $ComparableImportRoot = Get-ComparablePath $ImportRoot
    $ComparableRuntimeRoot = Get-ComparablePath $RuntimeRoot

    if (
        $ComparableCodeRoot -and
        $ComparableCodeRoot -eq $ComparableImportRoot -and
        $ComparableCodeRoot -eq $ComparableRuntimeRoot
    ) {
        $CandidateBaseRoot = $CodeRoot
        if (-not $CandidateBaseRoot) {
            $CandidateBaseRoot = $BaseRoot
        }

        if ($CandidateBaseRoot) {
            $CandidateLeaf = Get-PathLeafSafe $CandidateBaseRoot
            if ($CandidateLeaf -in @("Code", "Import", "Runtime")) {
                $CandidateBaseRoot = Get-PathParentSafe $CandidateBaseRoot
            }
        }

        if ($CandidateBaseRoot) {
            return @{
                BaseRoot = $CandidateBaseRoot
                CodeRoot = Join-PathSafe -BasePath $CandidateBaseRoot -ChildPath "Code"
                ImportRoot = Join-PathSafe -BasePath $CandidateBaseRoot -ChildPath "Import"
                RuntimeRoot = Join-PathSafe -BasePath $CandidateBaseRoot -ChildPath "Runtime"
                Changed = $true
            }
        }
    }

    return @{
        BaseRoot = $BaseRoot
        CodeRoot = $CodeRoot
        ImportRoot = $ImportRoot
        RuntimeRoot = $RuntimeRoot
        Changed = $false
    }
}

function Get-BaseRootFromRoots {
    param(
        [string]$SingleRoot,
        [string]$CodeRoot,
        [string]$ImportRoot,
        [string]$RuntimeRoot
    )

    if ($SingleRoot) {
        return $SingleRoot
    }

    $Pairs = @(
        @{ Path = $CodeRoot; Name = "Code" },
        @{ Path = $ImportRoot; Name = "Import" },
        @{ Path = $RuntimeRoot; Name = "Runtime" }
    )

    $Parents = @()
    foreach ($Pair in $Pairs) {
        if (-not $Pair.Path) {
            return ""
        }

        if ((Get-PathLeafSafe $Pair.Path) -ne $Pair.Name) {
            return ""
        }

        $Parents += (Get-PathParentSafe $Pair.Path)
    }

    $UniqueParents = @($Parents | Select-Object -Unique)
    if ($UniqueParents.Count -eq 1) {
        return $UniqueParents[0]
    }

    return ""
}

function Get-LegacyImportRoot {
    param(
        [string]$SingleRoot,
        [string]$CodeRoot,
        [string]$RuntimeRoot
    )

    if ($SingleRoot) {
        return (Join-PathSafe -BasePath $SingleRoot -ChildPath "Import")
    }

    $CodeParent = if ($CodeRoot) { Get-PathParentSafe $CodeRoot } else { "" }
    $RuntimeParent = if ($RuntimeRoot) { Get-PathParentSafe $RuntimeRoot } else { "" }

    if ($CodeParent -and $CodeParent -eq $RuntimeParent) {
        return (Join-PathSafe -BasePath $CodeParent -ChildPath "Import")
    }

    if ($RuntimeParent) {
        return (Join-PathSafe -BasePath $RuntimeParent -ChildPath "Import")
    }

    if ($CodeParent) {
        return (Join-PathSafe -BasePath $CodeParent -ChildPath "Import")
    }

    return (Get-DefaultImportRoot)
}

function Convert-SettingsToCurrent {
    param($Content)

    $Defaults = Get-DefaultSettings
    $SingleRoot = Get-JsonStringValue -Content $Content -Name "SingleRoot"
    $CodeRoot = Get-JsonStringValue -Content $Content -Name "CodeRoot"
    $ImportRoot = Get-JsonStringValue -Content $Content -Name "ImportRoot"
    $RuntimeRoot = Get-JsonStringValue -Content $Content -Name "RuntimeRoot"
    $BaseRoot = Get-JsonStringValue -Content $Content -Name "BaseRoot"
    $GitHubHost = Get-JsonStringValue -Content $Content -Name "GitHubHost"
    $Account = Get-JsonStringValue -Content $Content -Name "Account"

    if (-not $CodeRoot -and $SingleRoot) {
        $CodeRoot = Join-PathSafe -BasePath $SingleRoot -ChildPath "Code"
    }

    if (-not $RuntimeRoot -and $SingleRoot) {
        $RuntimeRoot = Join-PathSafe -BasePath $SingleRoot -ChildPath "Runtime"
    }

    if (-not $ImportRoot) {
        $ImportRoot = Get-LegacyImportRoot -SingleRoot $SingleRoot -CodeRoot $CodeRoot -RuntimeRoot $RuntimeRoot
    }

    if (-not $BaseRoot) {
        $BaseRoot = Get-BaseRootFromRoots -SingleRoot $SingleRoot -CodeRoot $CodeRoot -ImportRoot $ImportRoot -RuntimeRoot $RuntimeRoot
    }

    $NormalizedLayout = Normalize-WorkspaceLayout -BaseRoot $BaseRoot -CodeRoot $CodeRoot -ImportRoot $ImportRoot -RuntimeRoot $RuntimeRoot
    $BaseRoot = $NormalizedLayout.BaseRoot
    $CodeRoot = $NormalizedLayout.CodeRoot
    $ImportRoot = $NormalizedLayout.ImportRoot
    $RuntimeRoot = $NormalizedLayout.RuntimeRoot

    return @{
        WorkspaceModel = "three-root"
        BaseRoot = if ($BaseRoot) { $BaseRoot } else { $Defaults.BaseRoot }
        CodeRoot = if ($CodeRoot) { $CodeRoot } else { $Defaults.CodeRoot }
        ImportRoot = if ($ImportRoot) { $ImportRoot } else { $Defaults.ImportRoot }
        RuntimeRoot = if ($RuntimeRoot) { $RuntimeRoot } else { $Defaults.RuntimeRoot }
        GitHubHost = if ($GitHubHost) { $GitHubHost } else { $Defaults.GitHubHost }
        Account = if ($Account) { $Account } else { $Defaults.Account }
    }
}

function Load-Settings {
    if (-not (Test-Path $SettingsPath)) {
        return (Get-DefaultSettings)
    }

    try {
        $Content = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json
        $CurrentSettings = Convert-SettingsToCurrent -Content $Content
        $ShouldSave = $false
        if (
            $null -eq $Content.PSObject.Properties["WorkspaceModel"] -or
            $null -eq $Content.PSObject.Properties["BaseRoot"] -or
            $null -eq $Content.PSObject.Properties["ImportRoot"]
        ) {
            $ShouldSave = $true
        }
        if ((Get-JsonStringValue -Content $Content -Name "WorkspaceModel") -ne $CurrentSettings.WorkspaceModel) { $ShouldSave = $true }
        if ((Get-JsonStringValue -Content $Content -Name "BaseRoot") -ne $CurrentSettings.BaseRoot) { $ShouldSave = $true }
        if ((Get-JsonStringValue -Content $Content -Name "CodeRoot") -ne $CurrentSettings.CodeRoot) { $ShouldSave = $true }
        if ((Get-JsonStringValue -Content $Content -Name "ImportRoot") -ne $CurrentSettings.ImportRoot) { $ShouldSave = $true }
        if ((Get-JsonStringValue -Content $Content -Name "RuntimeRoot") -ne $CurrentSettings.RuntimeRoot) { $ShouldSave = $true }
        if ((Get-JsonStringValue -Content $Content -Name "GitHubHost") -ne $CurrentSettings.GitHubHost) { $ShouldSave = $true }
        if ((Get-JsonStringValue -Content $Content -Name "Account") -ne $CurrentSettings.Account) { $ShouldSave = $true }
        if ($ShouldSave) {
            Save-Settings $CurrentSettings
        }
        return $CurrentSettings
    } catch {
        Write-WarnLine "Settings file could not be read. Using defaults."
        return (Get-DefaultSettings)
    }
}

function Save-Settings {
    param([hashtable]$Settings)

    Ensure-Directory $LocalAppRoot
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -Path $SettingsPath -Encoding UTF8
}

function Resolve-Roots {
    $Settings = Load-Settings

    $CodeRoot = if ($State.CodeRoot) { $State.CodeRoot } else { $Settings.CodeRoot }
    $ImportRoot = if ($State.ImportRoot) { $State.ImportRoot } else { $Settings.ImportRoot }
    $RuntimeRoot = if ($State.RuntimeRoot) { $State.RuntimeRoot } else { $Settings.RuntimeRoot }

    if ($State.SingleRoot) {
        $CodeRoot = Join-Path $State.SingleRoot "Code"
        $ImportRoot = Join-Path $State.SingleRoot "Import"
        $RuntimeRoot = Join-Path $State.SingleRoot "Runtime"
    }

    Ensure-Directory $CodeRoot
    Ensure-Directory $ImportRoot
    Ensure-Directory $RuntimeRoot
    Ensure-Directory (Join-Path $ImportRoot "Repos")
    Ensure-Directory (Join-Path $RuntimeRoot "Reports")
    Ensure-Directory (Join-Path $RuntimeRoot "Backups")
    Ensure-Directory (Join-Path $RuntimeRoot "Logs")
    Ensure-Directory (Join-Path $RuntimeRoot "Runners")

    return @{
        CodeRoot = $CodeRoot
        ImportRoot = $ImportRoot
        RuntimeRoot = $RuntimeRoot
        Settings = $Settings
    }
}

function Save-WorkspaceChoice {
    param(
        [string]$CodeRoot,
        [string]$ImportRoot,
        [string]$RuntimeRoot,
        [string]$GitHubHost,
        [string]$Account
    )

    $BaseRoot = Get-BaseRootFromRoots -SingleRoot "" -CodeRoot $CodeRoot -ImportRoot $ImportRoot -RuntimeRoot $RuntimeRoot
    if (-not $BaseRoot) {
        $BaseRoot = Get-DefaultBaseRoot
    }

    Save-Settings @{
        WorkspaceModel = "three-root"
        BaseRoot = $BaseRoot
        CodeRoot = $CodeRoot
        ImportRoot = $ImportRoot
        RuntimeRoot = $RuntimeRoot
        GitHubHost = $GitHubHost
        Account = $Account
    }
}

function Get-ReportPath {
    param(
        [string]$RuntimeRoot,
        [string]$Slug
    )

    $SafeSlug = Sanitize-Label $Slug
    return (Join-Path (Join-Path $RuntimeRoot "Reports") "$SafeSlug-$(Get-Timestamp).txt")
}

function Test-CommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-CommandChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$CaptureOutput
    )

    $InvocationId = [guid]::NewGuid().ToString("N")
    $StdErrPath = Join-Path ([System.IO.Path]::GetTempPath()) "csa-iem-$InvocationId.stderr.log"
    $StdOutPath = $null

    try {
        $StdOutPath = Join-Path ([System.IO.Path]::GetTempPath()) "csa-iem-$InvocationId.stdout.log"
        $Process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath

        $ExitCode = $Process.ExitCode
        $StdErr = if (Test-Path $StdErrPath) { Get-Content -Path $StdErrPath -Raw -ErrorAction SilentlyContinue } else { "" }
        $StdOut = if ($StdOutPath -and (Test-Path $StdOutPath)) { Get-Content -Path $StdOutPath -Raw -ErrorAction SilentlyContinue } else { "" }

        if ($ExitCode -ne 0) {
            $MessageParts = @()
            if ($StdOut) {
                $MessageParts += $StdOut.TrimEnd()
            }
            if ($StdErr) {
                $MessageParts += $StdErr.TrimEnd()
            }

            $Message = if ($MessageParts.Count -gt 0) {
                ($MessageParts -join [Environment]::NewLine).Trim()
            } else {
                "$FilePath failed with exit code $ExitCode."
            }

            throw $Message
        }

        if (-not $CaptureOutput -and $StdErr) {
            $TrimmedStdErr = $StdErr.Trim()
            if ($TrimmedStdErr) {
                Write-Host $TrimmedStdErr
            }
        }

        if ($CaptureOutput) {
            if ($StdOut) {
                return $StdOut
            }

            if ($StdErr) {
                return $StdErr
            }

            return ""
        }
    } finally {
        if ($StdOutPath -and (Test-Path $StdOutPath)) {
            Remove-Item -LiteralPath $StdOutPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $StdErrPath) {
            Remove-Item -LiteralPath $StdErrPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Normalize-RepoSlug {
    param([string]$Value)

    $Trimmed = $Value.Trim()
    $Trimmed = $Trimmed -replace "^https://github\.com/", ""
    $Trimmed = $Trimmed -replace "^http://github\.com/", ""
    $Trimmed = $Trimmed.Trim("/")

    if ($Trimmed -notmatch "^[^/]+/[^/]+$") {
        throw "Repository must be in OWNER/REPO format."
    }

    return $Trimmed
}

function Get-GitHubCurrentAccount {
    param([string]$GitHubHost)
    try {
        return ((Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "--hostname", $GitHubHost, "user", "--jq", ".login") -CaptureOutput).Trim())
    } catch {
        return ""
    }
}

function Ensure-GitHubAuth {
    param([string]$GitHubHost)

    if (-not (Test-CommandAvailable "gh")) {
        throw "GitHub CLI is not installed."
    }

    & gh auth status -h $GitHubHost *> $null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-WarnLine "GitHub CLI is not signed in for $GitHubHost."
    if (-not (Confirm-Action "Run gh auth login now?")) {
        throw "GitHub authentication is required."
    }

    & gh auth login -h $GitHubHost
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub authentication did not complete."
    }
}

function Test-CommandExitZero {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    try {
        & $FilePath @Arguments 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-DockerDesktopPath {
    $Candidates = @(
        (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Docker\Docker\Docker Desktop.exe"),
        (Join-Path $env:LocalAppData "Programs\Docker\Docker\Docker Desktop.exe")
    ) | Where-Object { $_ }

    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) {
            return $Candidate
        }
    }

    return ""
}

function Start-DockerDesktop {
    $DockerDesktopPath = Get-DockerDesktopPath
    if ($DockerDesktopPath) {
        Start-Process -FilePath $DockerDesktopPath | Out-Null
        return $true
    }

    try {
        Start-Process -FilePath "Docker Desktop" -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Offer-DockerDesktopStartup {
    param(
        [string]$Reason = "Docker Desktop is installed but the engine is not running."
    )

    if (-not (Test-CommandAvailable "docker")) {
        return $false
    }

    if (Test-CommandExitZero -FilePath "docker" -Arguments @("info")) {
        return $true
    }

    Write-WarnLine $Reason

    if ($State.Yes -or $State.ImportFullAuto) {
        if (Start-DockerDesktop) {
            Write-Info "Started Docker Desktop."
        } else {
            Write-WarnLine "Docker Desktop could not be started automatically."
        }
        return $false
    }

    if (-not (Confirm-Action "Open Docker Desktop now?")) {
        return $false
    }

    if (-not (Start-DockerDesktop)) {
        Write-WarnLine "Docker Desktop could not be started automatically. Start it manually and retry."
        return $false
    }

    Write-Info "Docker Desktop is starting. Finish any onboarding, then retry when the engine shows as running."
    while ($true) {
        if (Confirm-Action "Retry the Docker engine check now?") {
            if (Test-CommandExitZero -FilePath "docker" -Arguments @("info")) {
                Write-Info "Docker engine is running."
                return $true
            }

            Write-WarnLine "Docker engine still looks unavailable."
            continue
        }

        return $false
    }
}

function Offer-PreflightActions {
    param($Scan)

    if ($null -eq $Scan) {
        $Scan = Get-PreflightScan
    }

    if ($Scan.Docker -eq "available" -and $Scan.DockerEngine -ne "running") {
        [void](Offer-DockerDesktopStartup -Reason "Docker Desktop is installed but the engine is not running.")
    }
}

function Get-PreflightScan {
    $GitHubHost = $State.GitHubHost
    if (-not $GitHubHost) {
        $GitHubHost = "github.com"
    }

    $GitHubSignedIn = $false
    if (Test-CommandAvailable "gh") {
        & gh auth status -h $GitHubHost *> $null
        $GitHubSignedIn = ($LASTEXITCODE -eq 0)
    }

    $DockerEngine = "not running"
    if (Test-CommandAvailable "docker") {
        if (Test-CommandExitZero -FilePath "docker" -Arguments @("info")) {
            $DockerEngine = "running"
        }
    }

    return [ordered]@{
        Winget = if (Test-CommandAvailable "winget") { "available" } else { "missing" }
        Git = if (Test-CommandAvailable "git") { "available" } else { "missing" }
        GitHubCli = if (Test-CommandAvailable "gh") { "available" } else { "missing" }
        GitHubAuth = if ($GitHubSignedIn) { "signed in" } else { "not signed in" }
        VSCode = if (Test-CommandAvailable "code") { "available" } else { "missing" }
        Docker = if (Test-CommandAvailable "docker") { "available" } else { "missing" }
        DockerEngine = $DockerEngine
        Node = if (Test-CommandAvailable "node") { "available" } else { "missing" }
        Npm = if (Test-CommandAvailable "npm") { "available" } else { "missing" }
        Devcontainer = if (Test-CommandAvailable "devcontainer") { "available" } else { "missing" }
        PowerShell = $PSVersionTable.PSVersion.ToString()
    }
}

function Show-Preflight {
    Write-Section "Preflight Scan"
    $Scan = Get-PreflightScan
    foreach ($Key in $Scan.Keys) {
        "{0,-18} {1}" -f $Key, $Scan[$Key] | Write-Host
    }
    return $Scan
}

function Get-OwnerRepoPaths {
    param(
        [string]$Root,
        [string]$Slug
    )
    $Parts = $Slug.Split("/")
    return (Join-Path (Join-Path (Join-Path $Root "Repos") $Parts[0]) $Parts[1])
}

function Clone-Or-UpdateRepo {
    param(
        [string]$Slug,
        [string]$TargetPath
    )

    $Parent = Split-Path -Parent $TargetPath
    Ensure-Directory $Parent

    if (-not (Test-Path (Join-Path $TargetPath ".git"))) {
        Write-Info "Cloning $Slug into $TargetPath"
        Invoke-CommandChecked -FilePath "gh" -Arguments @("repo", "clone", $Slug, $TargetPath)
        return
    }

    Write-Info "Repository already exists at $TargetPath"
    Invoke-CommandChecked -FilePath "git" -Arguments @("-C", $TargetPath, "fetch", "origin", "--prune")

    $Status = (Invoke-CommandChecked -FilePath "git" -Arguments @("-C", $TargetPath, "status", "--porcelain") -CaptureOutput).Trim()
    if ($Status) {
        Write-WarnLine "Local changes are present in $TargetPath. Skipping pull."
        return
    }

    $DefaultBranch = (Invoke-CommandChecked -FilePath "gh" -Arguments @("repo", "view", $Slug, "--json", "defaultBranchRef", "-q", ".defaultBranchRef.name") -CaptureOutput).Trim()
    if (-not $DefaultBranch) {
        Write-WarnLine "$Slug does not report a default branch. Treating it as an empty mirror."
        return
    }

    & git -C $TargetPath checkout $DefaultBranch *> $null
    Invoke-CommandChecked -FilePath "git" -Arguments @("-C", $TargetPath, "pull", "--ff-only", "origin", $DefaultBranch)
}

function Ensure-DevcontainerStarter {
    param([string]$WorkspacePath)

    $DevcontainerDir = Join-Path $WorkspacePath ".devcontainer"
    $DevcontainerJson = Join-Path $DevcontainerDir "devcontainer.json"
    $Marker = Join-Path $DevcontainerDir ".csa-iem-generated"

    if (Test-Path $DevcontainerJson) {
        Write-Info ".devcontainer/devcontainer.json already exists."
        return
    }

    Ensure-Directory $DevcontainerDir

    $HasNodeProject = (Test-Path (Join-Path $WorkspacePath "package.json"))
    if ($HasNodeProject) {
        @'
{
  "name": "local-devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:bookworm",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20"
    }
  },
  "forwardPorts": [3000, 5173, 8080],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-azuretools.vscode-docker",
        "github.vscode-github-actions"
      ]
    }
  }
}
'@ | Set-Content -Path $DevcontainerJson -Encoding UTF8
    } else {
        @'
{
  "name": "local-devcontainer",
  "image": "mcr.microsoft.com/devcontainers/base:bookworm",
  "forwardPorts": [8000, 8080],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-azuretools.vscode-docker",
        "github.vscode-github-actions"
      ]
    }
  }
}
'@ | Set-Content -Path $DevcontainerJson -Encoding UTF8
    }

    $AppName | Set-Content -Path $Marker -Encoding UTF8
    Write-Info "Created starter .devcontainer/devcontainer.json"
}

function Test-DevcontainerQuickStart {
    param(
        [string]$WorkspacePath,
        [string]$ReportPath
    )

    $ConfigPath = Join-Path $WorkspacePath ".devcontainer\devcontainer.json"
    if (-not (Test-Path $ConfigPath)) {
        Write-WarnLine "No devcontainer file found. Skipping local devcontainer test."
        return
    }

    if (-not (Test-CommandAvailable "devcontainer")) {
        Write-WarnLine "The devcontainer CLI is not installed."
        return
    }

    if (-not (Test-CommandAvailable "docker")) {
        Write-WarnLine "Docker is not installed."
        return
    }

    if (-not (Test-CommandExitZero -FilePath "docker" -Arguments @("info"))) {
        if (-not (Offer-DockerDesktopStartup -Reason "Docker is installed but the engine is not ready for devcontainer startup checks.")) {
            Write-WarnLine "Docker is installed but the engine is not ready."
            return
        }
    }

    $ReportsDir = Split-Path -Parent $ReportPath
    Ensure-Directory $ReportsDir
    $LogPath = Join-Path $ReportsDir "$(Sanitize-Label (Split-Path -Leaf $WorkspacePath))-devcontainer-$(Get-Timestamp).log"

    $SupportsSkipPostCreate = (& devcontainer up --help 2>$null | Select-String -- "--skip-post-create")
    $Args = @("up")
    if ($SupportsSkipPostCreate) {
        $Args += "--skip-post-create"
    }
    $Args += @("--workspace-folder", $WorkspacePath)

    Write-Info "Running quick devcontainer startup check..."
    & devcontainer @Args 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -eq 0) {
        "Devcontainer startup check: SUCCESS" | Tee-Object -FilePath $ReportPath -Append | Out-Null
    } else {
        "Devcontainer startup check: FAILED" | Tee-Object -FilePath $ReportPath -Append | Out-Null
        Write-WarnLine "Devcontainer startup check failed. Log: $LogPath"
    }
}

function Get-RunnerRootPath {
    param(
        [string]$RuntimeRoot,
        [string]$Slug
    )
    $Parts = $Slug.Split("/")
    return (Join-Path (Join-Path (Join-Path $RuntimeRoot "Runners") $Parts[0]) $Parts[1])
}

function Get-LocalRunnerLabel {
    param([string]$Slug)
    return "$(Sanitize-Label $Slug)-windows"
}

function Get-RunnerServiceForSlug {
    param([string]$Slug)
    $Parts = $Slug.Split("/")
    $Owner = $Parts[0]
    $Repo = $Parts[1]
    $Needle = "$Owner-$Repo"

    $Services = Get-Service | Where-Object { $_.Name -like "actions.runner.*$Needle*" }
    if ($Services) {
        return $Services | Select-Object -First 1
    }

    return $null
}

function Install-RepoRunner {
    param(
        [string]$Slug,
        [string]$RuntimeRoot,
        [string]$GitHubHost,
        [string]$ReportPath
    )

    if (-not $State.ImportFullAuto) {
        if (-not (Confirm-Action "Install and register a repo-level self-hosted runner for $Slug on this Windows machine?")) {
            return
        }
    } else {
        Write-Info "FULL AUTO: yes -> Install and register a repo-level self-hosted runner for $Slug on this Windows machine?"
    }

    $RunnerPath = Get-RunnerRootPath -RuntimeRoot $RuntimeRoot -Slug $Slug
    Ensure-Directory $RunnerPath

    $RunnerConfig = Join-Path $RunnerPath ".runner"
    $Label = Get-LocalRunnerLabel -Slug $Slug
    $RunnerName = "$env:COMPUTERNAME-$Label"

    if (-not (Test-Path $RunnerConfig)) {
        $OsArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
        $ApiArch = if ($OsArch -eq "arm64") { "arm64" } else { "x64" }
        $TagName = (Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "repos/actions/runner/releases/latest", "--jq", ".tag_name") -CaptureOutput).Trim()
        $Version = $TagName.TrimStart("v")
        $Archive = "actions-runner-win-$ApiArch-$Version.zip"
        $ArchivePath = Join-Path $RunnerPath $Archive

        "Using runner version: $Version" | Tee-Object -FilePath $ReportPath -Append | Out-Null
        Write-Info "Downloading runner package..."
        Push-Location $RunnerPath
        try {
            Invoke-CommandChecked -FilePath "gh" -Arguments @("release", "download", $TagName, "--repo", "actions/runner", "--pattern", $Archive, "--clobber")
            if (-not (Test-Path $ArchivePath)) {
                throw "Runner archive was not downloaded."
            }

            Expand-Archive -Path $ArchivePath -DestinationPath $RunnerPath -Force

            Write-Info "Requesting repo registration token..."
            $Token = (Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "--hostname", $GitHubHost, "-X", "POST", "repos/$Slug/actions/runners/registration-token", "--jq", ".token") -CaptureOutput).Trim()

            Write-Info "Configuring runner..."
            Invoke-CommandChecked -FilePath (Join-Path $RunnerPath "config.cmd") -Arguments @(
                "--url", "https://$GitHubHost/$Slug",
                "--token", $Token,
                "--name", $RunnerName,
                "--labels", $Label,
                "--work", "_work",
                "--unattended",
                "--replace",
                "--runasservice"
            )
        } finally {
            Pop-Location
        }
    } else {
        Write-Info "Runner already configured at $RunnerPath"
    }

    $Service = Get-RunnerServiceForSlug -Slug $Slug
    if ($Service) {
        if ($Service.Status -ne "Running") {
            try {
                Start-Service -Name $Service.Name
                $Service.WaitForStatus("Running", "00:00:15")
            } catch {
                Write-WarnLine "Runner service did not start cleanly."
            }
        }
        "Runner configured: $RunnerName" | Tee-Object -FilePath $ReportPath -Append | Out-Null
        "Runner label: $Label" | Tee-Object -FilePath $ReportPath -Append | Out-Null
        "Runner path: $RunnerPath" | Tee-Object -FilePath $ReportPath -Append | Out-Null
    } else {
        Write-WarnLine "Runner service was not detected after configuration."
    }
}

function Backup-Workflows {
    param(
        [string]$RepoDir,
        [string]$RuntimeRoot,
        [string]$Slug
    )

    $WorkflowDir = Join-Path $RepoDir ".github\workflows"
    if (-not (Test-Path $WorkflowDir)) {
        return $null
    }

    $BackupRoot = Join-Path $RuntimeRoot "Backups"
    Ensure-Directory $BackupRoot
    $BackupPath = Join-Path $BackupRoot "$(Sanitize-Label $Slug)-workflows-$(Get-Timestamp)"
    Copy-Item -Path $WorkflowDir -Destination $BackupPath -Recurse -Force
    return $BackupPath
}

function Patch-WorkflowsForSelfHostedWindows {
    param(
        [string]$Slug,
        [string]$RepoDir,
        [string]$RuntimeRoot,
        [string]$ReportPath
    )

    $WorkflowDir = Join-Path $RepoDir ".github\workflows"
    if (-not (Test-Path $WorkflowDir)) {
        Write-Info "No workflow folder found. Skipping workflow patch."
        return
    }

    if (-not $State.ImportFullAuto) {
        if (-not (Confirm-Action "Patch workflow files to use the self-hosted Windows runner for $Slug?")) {
            return
        }
    } else {
        Write-Info "FULL AUTO: yes -> Patch workflow files to use the self-hosted Windows runner for $Slug?"
    }

    $Label = Get-LocalRunnerLabel -Slug $Slug
    $BackupPath = Backup-Workflows -RepoDir $RepoDir -RuntimeRoot $RuntimeRoot -Slug $Slug
    if ($BackupPath) {
        "Workflow backup created at: $BackupPath" | Tee-Object -FilePath $ReportPath -Append | Out-Null
    }

    $Changed = $false
    Get-ChildItem -Path $WorkflowDir -Recurse -Include *.yml,*.yaml | ForEach-Object {
        $Path = $_.FullName
        $Content = Get-Content -Path $Path -Raw
        $Updated = $Content `
            -replace "runs-on:\s*ubuntu-latest", "runs-on: [self-hosted, Windows, $Label]" `
            -replace "runs-on:\s*windows-latest", "runs-on: [self-hosted, Windows, $Label]" `
            -replace "runs-on:\s*windows-2022", "runs-on: [self-hosted, Windows, $Label]" `
            -replace "runs-on:\s*windows-2025", "runs-on: [self-hosted, Windows, $Label]" `
            -replace "runs-on:\s*macos-latest", "runs-on: [self-hosted, Windows, $Label]"

        if ($Updated -ne $Content) {
            Set-Content -Path $Path -Value $Updated -Encoding UTF8
            $Changed = $true
        }
    }

    if ($Changed) {
        "Patched workflow runs-on values for self-hosted Windows runner label $Label" | Tee-Object -FilePath $ReportPath -Append | Out-Null
    } else {
        Write-WarnLine "No common GitHub-hosted runs-on values were found to patch."
    }
}

function Invoke-RepoCleanup {
    param(
        [string]$Slug,
        [string]$ReportPath
    )

    $DoDisable = $State.DisableWorkflows -or $State.All -or $State.ImportCleanupPreview
    $DoRuns = $State.DeleteRuns -or $State.All -or $State.ImportCleanupPreview
    $DoArtifacts = $State.DeleteArtifacts -or $State.All -or $State.ImportCleanupPreview
    $DoCaches = $State.DeleteCaches -or $State.All -or $State.ImportCleanupPreview
    $DoCodespaces = $State.DeleteCodespaces -or $State.All -or $State.ImportCleanupPreview
    $EffectiveDryRun = $State.DryRun -or $State.ImportCleanupPreview

    if (-not ($DoDisable -or $DoRuns -or $DoArtifacts -or $DoCaches -or $DoCodespaces)) {
        return
    }

    Write-Section "Cleanup Summary"
    Write-Host ("Repository: {0}" -f $Slug)
    Write-Host ("Disable workflows: {0}" -f ($(if ($DoDisable) { "yes" } else { "no" })))
    Write-Host ("Delete runs: {0}" -f ($(if ($DoRuns) { "yes" } else { "no" })))
    Write-Host ("Delete artifacts: {0}" -f ($(if ($DoArtifacts) { "yes" } else { "no" })))
    Write-Host ("Delete caches: {0}" -f ($(if ($DoCaches) { "yes" } else { "no" })))
    Write-Host ("Delete Codespaces: {0}" -f ($(if ($DoCodespaces) { "yes" } else { "no" })))
    Write-Host ("Dry run: {0}" -f ($(if ($EffectiveDryRun) { "yes" } else { "no" })))

    if (-not $State.Yes -and -not $State.ImportCleanupPreview) {
        if (-not (Confirm-Action "Proceed with cleanup for $Slug?")) {
            return
        }
    }

    if ($DoDisable) {
        $WorkflowJson = Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "repos/$Slug/actions/workflows") -CaptureOutput
        $Workflows = (ConvertFrom-Json $WorkflowJson).workflows
        foreach ($Workflow in $Workflows) {
            if ($Workflow.state -eq "active") {
                if ($EffectiveDryRun) {
                    Write-Host "dry-run disable workflow $($Workflow.name) ($($Workflow.id))"
                } else {
                    & gh workflow disable $Workflow.id --repo $Slug | Out-Null
                }
            }
        }
    }

    if ($DoRuns) {
        $RunsJson = Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "repos/$Slug/actions/runs?per_page=100") -CaptureOutput
        $Runs = (ConvertFrom-Json $RunsJson).workflow_runs
        if ($State.RunFilter) {
            $Runs = $Runs | Where-Object { $_.display_title -like "*$($State.RunFilter)*" -or $_.name -like "*$($State.RunFilter)*" }
        }
        foreach ($Run in $Runs) {
            if ($State.RunId -and ([string]$Run.id) -ne $State.RunId) {
                continue
            }
            if ($EffectiveDryRun) {
                Write-Host "dry-run delete run $($Run.id)"
            } else {
                & gh api -X DELETE "repos/$Slug/actions/runs/$($Run.id)" | Out-Null
            }
        }
    }

    if ($DoArtifacts) {
        $ArtifactsJson = Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "repos/$Slug/actions/artifacts?per_page=100") -CaptureOutput
        $Artifacts = (ConvertFrom-Json $ArtifactsJson).artifacts
        foreach ($Artifact in $Artifacts) {
            if ($EffectiveDryRun) {
                Write-Host "dry-run delete artifact $($Artifact.id)"
            } else {
                & gh api -X DELETE "repos/$Slug/actions/artifacts/$($Artifact.id)" | Out-Null
            }
        }
    }

    if ($DoCaches) {
        try {
            $CachesJson = Invoke-CommandChecked -FilePath "gh" -Arguments @("api", "repos/$Slug/actions/caches?per_page=100") -CaptureOutput
            $Caches = (ConvertFrom-Json $CachesJson).actions_caches
            foreach ($Cache in $Caches) {
                if ($EffectiveDryRun) {
                    Write-Host "dry-run delete cache $($Cache.id)"
                } else {
                    & gh api -X DELETE "repos/$Slug/actions/caches/$($Cache.id)" | Out-Null
                }
            }
        } catch {
            Write-WarnLine "Cache cleanup reported an issue."
        }
    }

    if ($DoCodespaces) {
        try {
            $Codespaces = (& gh codespace list --repo $Slug --json name 2>$null | ConvertFrom-Json)
            foreach ($Codespace in $Codespaces) {
                if ($EffectiveDryRun) {
                    Write-Host "dry-run delete codespace $($Codespace.name)"
                } else {
                    & gh codespace delete -c $Codespace.name --force | Out-Null
                }
            }
        } catch {
            Write-WarnLine "Codespace cleanup is unavailable with the current GitHub token."
        }
    }

    "Cleanup complete for $Slug" | Tee-Object -FilePath $ReportPath -Append | Out-Null
}

function Get-ImportedProjects {
    param(
        [string]$CodeRoot,
        [string]$RuntimeRoot
    )

    $Map = @{}
    foreach ($BaseRoot in @($CodeRoot, $RuntimeRoot)) {
        $ReposRoot = Join-Path $BaseRoot "Repos"
        if (-not (Test-Path $ReposRoot)) {
            continue
        }

        Get-ChildItem -Path $ReposRoot -Directory | ForEach-Object {
            $OwnerDir = $_.FullName
            $OwnerName = $_.Name
            Get-ChildItem -Path $OwnerDir -Directory | ForEach-Object {
                $Slug = "$OwnerName/$($_.Name)"
                if (-not $Map.ContainsKey($Slug)) {
                    $Map[$Slug] = [ordered]@{
                        Slug = $Slug
                        CodePath = ""
                        RuntimePath = ""
                    }
                }

                if ($BaseRoot -eq $CodeRoot) {
                    $Map[$Slug].CodePath = $_.FullName
                } else {
                    $Map[$Slug].RuntimePath = $_.FullName
                }
            }
        }
    }

    return ($Map.Values | Sort-Object Slug)
}

function Browse-ImportedProjects {
    param(
        [string]$CodeRoot,
        [string]$RuntimeRoot
    )

    $Projects = Get-ImportedProjects -CodeRoot $CodeRoot -RuntimeRoot $RuntimeRoot
    if (-not $Projects -or $Projects.Count -eq 0) {
        Write-WarnLine "No imported projects were detected."
        return
    }

    while ($true) {
        Write-Section "Imported Projects"
        for ($Index = 0; $Index -lt $Projects.Count; $Index++) {
            $Project = $Projects[$Index]
            $Tags = @()
            if ($Project.CodePath) { $Tags += "code" }
            if ($Project.RuntimePath) { $Tags += "runtime" }
            if ($Project.RuntimePath -and (Test-Path (Join-Path $Project.RuntimePath ".devcontainer\devcontainer.json"))) { $Tags += "devcontainer" }
            "{0,2}) {1} [{2}]" -f ($Index + 1), $Project.Slug, ($Tags -join ", ") | Write-Host
        }
        Write-Host " 0) Back"

        $Choice = Read-Host "Choose a project number"
        if ($Choice -eq "0") {
            return
        }

        $Selection = 0
        if (-not [int]::TryParse($Choice, [ref]$Selection)) {
            continue
        }
        if ($Selection -lt 1 -or $Selection -gt $Projects.Count) {
            continue
        }

        $Project = $Projects[$Selection - 1]
        Write-Section $Project.Slug
        Write-Host "1) Open code workspace in VS Code"
        Write-Host "2) Open runtime workspace in VS Code"
        Write-Host "3) Open in File Explorer"
        Write-Host "4) Start or update devcontainer"
        Write-Host "5) Back"
        $Action = Read-Host "Choose action"

        switch ($Action) {
            "1" {
                if ($Project.CodePath -and (Test-CommandAvailable "code")) {
                    & code $Project.CodePath
                } else {
                    Write-WarnLine "Code workspace or VS Code CLI is unavailable."
                }
            }
            "2" {
                if ($Project.RuntimePath -and (Test-CommandAvailable "code")) {
                    & code $Project.RuntimePath
                } else {
                    Write-WarnLine "Runtime workspace or VS Code CLI is unavailable."
                }
            }
            "3" {
                $Target = if ($Project.RuntimePath) { $Project.RuntimePath } else { $Project.CodePath }
                if ($Target) {
                    Start-Process explorer.exe $Target
                }
            }
            "4" {
                if ($Project.RuntimePath) {
                    $ReportPath = Get-ReportPath -RuntimeRoot $RuntimeRoot -Slug $Project.Slug
                    Test-DevcontainerQuickStart -WorkspacePath $Project.RuntimePath -ReportPath $ReportPath
                }
            }
            default { }
        }
    }
}

function Show-HelpText {
    @"
$AppName $AppVersion
Provided by $AppVendor
Website: $AppUrl
Use at your own risk.

Windows 11 admin-shell usage:
  powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1
  powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --repo OWNER/REPO --import-mode repo-plus --import-full-auto
  powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --repo OWNER/REPO --all --dry-run --yes
  powershell -ExecutionPolicy Bypass -File .\CSA-iEM.ps1 --browse-projects --use-current-root

Options:
  --repo OWNER/REPO
  --import-mode codespace|repo|repo-plus
  --import-full-auto
  --import-cleanup-preview
  --browse-projects
  --use-current-root
  --single-root PATH
  --code-root PATH
  --import-root PATH
  --runtime-root PATH
  --host HOSTNAME
  --account LOGIN
  --disable-workflows
  --delete-runs
  --run ID
  --run-filter TEXT
  --delete-artifacts
  --delete-caches
  --delete-codespaces
  --all
  --dry-run
  --yes
  --version
  --help
"@ | Write-Host
}

function Parse-Args {
    param([string[]]$ArgsList)

    for ($Index = 0; $Index -lt $ArgsList.Count; $Index++) {
        $Arg = $ArgsList[$Index]
        switch ($Arg) {
            "--help" { $State.Help = $true }
            "-h" { $State.Help = $true }
            "--version" { $State.ShowVersion = $true }
            "--browse-projects" { $State.BrowseProjects = $true }
            "--use-current-root" { $State.UseCurrentRoot = $true }
            "--import-full-auto" { $State.ImportFullAuto = $true }
            "--import-cleanup-preview" { $State.ImportCleanupPreview = $true }
            "--disable-workflows" { $State.DisableWorkflows = $true; $State.CleanupOnly = $true }
            "--delete-runs" { $State.DeleteRuns = $true; $State.CleanupOnly = $true }
            "--delete-artifacts" { $State.DeleteArtifacts = $true; $State.CleanupOnly = $true }
            "--delete-caches" { $State.DeleteCaches = $true; $State.CleanupOnly = $true }
            "--delete-codespaces" { $State.DeleteCodespaces = $true; $State.CleanupOnly = $true }
            "--all" { $State.All = $true; $State.CleanupOnly = $true }
            "--dry-run" { $State.DryRun = $true }
            "--yes" { $State.Yes = $true }
            "--no-color" { $State.NoColor = $true }
            "--host" {
                $Index++
                $State.GitHubHost = $ArgsList[$Index]
            }
            "--account" {
                $Index++
                $State.Account = $ArgsList[$Index]
            }
            "--repo" {
                $Index++
                $State.Repo = Normalize-RepoSlug $ArgsList[$Index]
            }
            "--import-mode" {
                $Index++
                $State.ImportMode = $ArgsList[$Index]
            }
            "--single-root" {
                $Index++
                $State.SingleRoot = $ArgsList[$Index]
            }
            "--code-root" {
                $Index++
                $State.CodeRoot = $ArgsList[$Index]
            }
            "--import-root" {
                $Index++
                $State.ImportRoot = $ArgsList[$Index]
            }
            "--runtime-root" {
                $Index++
                $State.RuntimeRoot = $ArgsList[$Index]
            }
            "--run" {
                $Index++
                $State.RunId = $ArgsList[$Index]
            }
            "--run-filter" {
                $Index++
                $State.RunFilter = $ArgsList[$Index]
            }
            default {
                throw "Unknown argument: $Arg"
            }
        }
    }
}

function Select-WorkspaceInteractively {
    param(
        [string]$GitHubHost,
        [string]$Account
    )

    $Settings = Load-Settings
    while ($true) {
        Write-Section "Workspace Roots"
        Write-Host "1) Use current saved workspace roots"
        Write-Host "   Code root: $($Settings.CodeRoot)"
        Write-Host "   Import root: $($Settings.ImportRoot)"
        Write-Host "   Runtime root: $($Settings.RuntimeRoot)"
        Write-Host "2) Set a single base workspace folder"
        Write-Host "3) Set custom code/import/runtime folders"
        Write-Host "4) Reset to the standard Code/Import/Runtime defaults"
        $Choice = Read-Host "Enter choice [1-4] (Enter = 1)"
        if ([string]::IsNullOrWhiteSpace($Choice)) { $Choice = "1" }

        switch ($Choice) {
            "1" {
                Save-WorkspaceChoice -CodeRoot $Settings.CodeRoot -ImportRoot $Settings.ImportRoot -RuntimeRoot $Settings.RuntimeRoot -GitHubHost $GitHubHost -Account $Account
                return (Resolve-Roots)
            }
            "2" {
                $SingleRoot = Read-Host "Enter the base workspace folder"
                if (-not [string]::IsNullOrWhiteSpace($SingleRoot)) {
                    $CodeRoot = Join-Path $SingleRoot "Code"
                    $ImportRoot = Join-Path $SingleRoot "Import"
                    $RuntimeRoot = Join-Path $SingleRoot "Runtime"
                    Save-WorkspaceChoice -CodeRoot $CodeRoot -ImportRoot $ImportRoot -RuntimeRoot $RuntimeRoot -GitHubHost $GitHubHost -Account $Account
                    return (Resolve-Roots)
                }
            }
            "3" {
                $CodeRoot = Read-Host "Enter the code root"
                $ImportRoot = Read-Host "Enter the import root"
                $RuntimeRoot = Read-Host "Enter the runtime root"
                if (-not [string]::IsNullOrWhiteSpace($CodeRoot) -and -not [string]::IsNullOrWhiteSpace($ImportRoot) -and -not [string]::IsNullOrWhiteSpace($RuntimeRoot)) {
                    Save-WorkspaceChoice -CodeRoot $CodeRoot -ImportRoot $ImportRoot -RuntimeRoot $RuntimeRoot -GitHubHost $GitHubHost -Account $Account
                    return (Resolve-Roots)
                }
            }
            "4" {
                Save-WorkspaceChoice -CodeRoot (Get-DefaultCodeRoot) -ImportRoot (Get-DefaultImportRoot) -RuntimeRoot (Get-DefaultRuntimeRoot) -GitHubHost $GitHubHost -Account $Account
                return (Resolve-Roots)
            }
            default { }
        }
    }
}

function Get-RepoListForOwner {
    param([string]$Owner)
    $Output = Invoke-CommandChecked -FilePath "gh" -Arguments @("repo", "list", $Owner, "--limit", "1000", "--json", "nameWithOwner", "-q", ".[].nameWithOwner") -CaptureOutput
    return @($Output -split "`r?`n" | Where-Object { $_.Trim() })
}

function Select-RepositoriesInteractively {
    param([string]$DefaultOwner)

    while ($true) {
        Write-Section "Repository Selection"
        Write-Host "1) One repo at a time from a GitHub owner or org"
        Write-Host "2) All repos one by one from a GitHub owner or org"
        Write-Host "3) All repos one by one (FULL AUTO)"
        Write-Host "4) All repos one by one (FULL AUTO + CLEANUP PREVIEW)"
        Write-Host "5) Enter one repo manually"
        $Choice = Read-Host "Enter choice [1-5]"

        switch ($Choice) {
            "1" {
                $Owner = Read-Host "GitHub owner or org"
                if (-not $Owner) { $Owner = $DefaultOwner }
                $Repos = Get-RepoListForOwner -Owner $Owner
                if (-not $Repos) { continue }
                for ($Index = 0; $Index -lt $Repos.Count; $Index++) {
                    "{0,2}) {1}" -f ($Index + 1), $Repos[$Index] | Write-Host
                }
                $Pick = Read-Host "Choose repo number"
                $Number = 0
                if ([int]::TryParse($Pick, [ref]$Number) -and $Number -ge 1 -and $Number -le $Repos.Count) {
                    return @{
                        Repos = @($Repos[$Number - 1])
                        FullAuto = $false
                        CleanupPreview = $false
                    }
                }
            }
            "2" {
                $Owner = Read-Host "GitHub owner or org"
                if (-not $Owner) { $Owner = $DefaultOwner }
                return @{
                    Repos = @(Get-RepoListForOwner -Owner $Owner)
                    FullAuto = $false
                    CleanupPreview = $false
                }
            }
            "3" {
                $Owner = Read-Host "GitHub owner or org"
                if (-not $Owner) { $Owner = $DefaultOwner }
                return @{
                    Repos = @(Get-RepoListForOwner -Owner $Owner)
                    FullAuto = $true
                    CleanupPreview = $false
                }
            }
            "4" {
                $Owner = Read-Host "GitHub owner or org"
                if (-not $Owner) { $Owner = $DefaultOwner }
                return @{
                    Repos = @(Get-RepoListForOwner -Owner $Owner)
                    FullAuto = $true
                    CleanupPreview = $true
                }
            }
            "5" {
                $RepoValue = Read-Host "Enter OWNER/REPO or full GitHub URL"
                if ($RepoValue) {
                    return @{
                        Repos = @((Normalize-RepoSlug $RepoValue))
                        FullAuto = $false
                        CleanupPreview = $false
                    }
                }
            }
            default { }
        }
    }
}

function Process-Repo {
    param(
        [string]$Slug,
        [string]$Mode,
        [hashtable]$Roots
    )

    $CodeRoot = $Roots.CodeRoot
    $ImportRoot = $Roots.ImportRoot
    $RuntimeRoot = $Roots.RuntimeRoot
    $ReportPath = Get-ReportPath -RuntimeRoot $RuntimeRoot -Slug $Slug

    Write-Section "Processing: $Slug"

    $CodeRepoPath = Get-OwnerRepoPaths -Root $CodeRoot -Slug $Slug
    $ImportRepoPath = Get-OwnerRepoPaths -Root $ImportRoot -Slug $Slug
    $RuntimeRepoPath = Get-OwnerRepoPaths -Root $RuntimeRoot -Slug $Slug

    Clone-Or-UpdateRepo -Slug $Slug -TargetPath $CodeRepoPath
    Clone-Or-UpdateRepo -Slug $Slug -TargetPath $ImportRepoPath
    Clone-Or-UpdateRepo -Slug $Slug -TargetPath $RuntimeRepoPath

    @"
CSA-iEM Report
Version: $AppVersion
Time: $(Get-Date)
Host: $($State.GitHubHost)
Account: $($State.Account)
Mode: $Mode
Repo: $Slug
Code Path: $CodeRepoPath
Import Path: $ImportRepoPath
Runtime Path: $RuntimeRepoPath
"@ | Set-Content -Path $ReportPath -Encoding UTF8

    if ($Mode -eq "repo-plus" -or $Mode -eq "codespace") {
        Ensure-DevcontainerStarter -WorkspacePath $RuntimeRepoPath
        Test-DevcontainerQuickStart -WorkspacePath $RuntimeRepoPath -ReportPath $ReportPath
    }

    if ($Mode -eq "repo-plus") {
        Install-RepoRunner -Slug $Slug -RuntimeRoot $RuntimeRoot -GitHubHost $State.GitHubHost -ReportPath $ReportPath
        Patch-WorkflowsForSelfHostedWindows -Slug $Slug -RepoDir $CodeRepoPath -RuntimeRoot $RuntimeRoot -ReportPath $ReportPath
    }

    if ($State.ImportCleanupPreview) {
        Invoke-RepoCleanup -Slug $Slug -ReportPath $ReportPath
    } elseif ($State.CleanupOnly) {
        Invoke-RepoCleanup -Slug $Slug -ReportPath $ReportPath
    }

    Write-Host "Done: $Slug"
    Write-Host "Report saved to: $ReportPath"
}

function Run-DirectAction {
    $Roots = Resolve-Roots
    Ensure-GitHubAuth -GitHubHost $State.GitHubHost
    if (-not $State.Account) {
        $State.Account = Get-GitHubCurrentAccount -GitHubHost $State.GitHubHost
    }

    if ($State.BrowseProjects) {
        Browse-ImportedProjects -CodeRoot $Roots.CodeRoot -RuntimeRoot $Roots.RuntimeRoot
        return
    }

    if ($State.Repo -and $State.ImportMode) {
        if ($State.ImportMode -notin @("codespace", "repo", "repo-plus")) {
            throw "Import mode must be one of: codespace, repo, repo-plus."
        }
        Process-Repo -Slug $State.Repo -Mode $State.ImportMode -Roots $Roots
        return
    }

    if ($State.Repo -and $State.CleanupOnly) {
        $ReportPath = Get-ReportPath -RuntimeRoot $Roots.RuntimeRoot -Slug $State.Repo
        Invoke-RepoCleanup -Slug $State.Repo -ReportPath $ReportPath
        return
    }

    throw "A direct repo action requires either --import-mode or cleanup flags."
}

function Run-Interactive {
    $Scan = Show-Preflight
    Offer-PreflightActions -Scan $Scan

    $Settings = Load-Settings
    if (-not $State.GitHubHost) {
        $State.GitHubHost = $Settings.GitHubHost
    }

    Ensure-GitHubAuth -GitHubHost $State.GitHubHost

    if (-not $State.Account) {
        $State.Account = if ($Settings.Account) { $Settings.Account } else { Get-GitHubCurrentAccount -GitHubHost $State.GitHubHost }
    }

    $Roots = if ($State.UseCurrentRoot) { Resolve-Roots } else { Select-WorkspaceInteractively -GitHubHost $State.GitHubHost -Account $State.Account }

    while ($true) {
        Write-Section "Main Menu"
        Write-Host "1) Run migration or cleanup"
        Write-Host "2) Change workspace root"
        Write-Host "3) Switch GitHub host/account"
        Write-Host "4) Show preflight scan"
        Write-Host "5) Browse imported projects"
        Write-Host "6) Exit"
        $Choice = Read-Host "Enter choice [1-6]"

        switch ($Choice) {
            "1" {
                $State.CleanupOnly = $false
                $State.All = $false
                $State.DisableWorkflows = $false
                $State.DeleteRuns = $false
                $State.DeleteArtifacts = $false
                $State.DeleteCaches = $false
                $State.DeleteCodespaces = $false
                $State.ImportFullAuto = $false
                $State.ImportCleanupPreview = $false
                $State.RunFilter = ""
                $State.RunId = ""

                Write-Section "Migration Mode"
                Write-Host "1) Codespace -> Local"
                Write-Host "2) Repo -> Local"
                Write-Host "3) Repo -> Local + local devcontainer + local Actions prep"
                Write-Host "4) Cleanup only"
                $ModeChoice = Read-Host "Enter choice [1-4]"
                $Mode = switch ($ModeChoice) {
                    "1" { "codespace" }
                    "2" { "repo" }
                    "3" { "repo-plus" }
                    "4" { "cleanup" }
                    default { "" }
                }
                if (-not $Mode) { continue }

                $Selection = Select-RepositoriesInteractively -DefaultOwner $State.Account
                $State.ImportFullAuto = [bool]$Selection.FullAuto
                $State.ImportCleanupPreview = [bool]$Selection.CleanupPreview
                foreach ($Slug in $Selection.Repos) {
                    if (-not $Slug) { continue }
                    if ($Mode -eq "cleanup") {
                        $State.CleanupOnly = $true
                        $State.All = $true
                        $ReportPath = Get-ReportPath -RuntimeRoot $Roots.RuntimeRoot -Slug $Slug
                        Invoke-RepoCleanup -Slug $Slug -ReportPath $ReportPath
                    } else {
                        Process-Repo -Slug $Slug -Mode $Mode -Roots $Roots
                    }
                }
            }
            "2" {
                $Roots = Select-WorkspaceInteractively -GitHubHost $State.GitHubHost -Account $State.Account
            }
            "3" {
                $HostValue = Read-Host "GitHub host (Enter = github.com)"
                if (-not $HostValue) { $HostValue = "github.com" }
                $State.GitHubHost = $HostValue
                Ensure-GitHubAuth -GitHubHost $State.GitHubHost
                $State.Account = Get-GitHubCurrentAccount -GitHubHost $State.GitHubHost
                Save-WorkspaceChoice -CodeRoot $Roots.CodeRoot -ImportRoot $Roots.ImportRoot -RuntimeRoot $Roots.RuntimeRoot -GitHubHost $State.GitHubHost -Account $State.Account
            }
            "4" {
                $Scan = Show-Preflight
                Offer-PreflightActions -Scan $Scan
            }
            "5" { Browse-ImportedProjects -CodeRoot $Roots.CodeRoot -RuntimeRoot $Roots.RuntimeRoot }
            "6" { return }
            default { }
        }
    }
}

Parse-Args -ArgsList $args

if ($State.ShowVersion) {
    Write-Host "$AppName $AppVersion"
    exit 0
}

if ($State.Help) {
    Show-HelpText
    exit 0
}

Write-Section "$AppName v$AppVersion"
Write-Host "Container Setup & Action Import Engine Manager"
Write-Host "Provider: $AppVendor"
Write-Host "Website: $AppUrl"
Write-Host "Use at your own risk."

if ($State.BrowseProjects -or ($State.Repo -and ($State.ImportMode -or $State.CleanupOnly))) {
    Run-DirectAction
} else {
    Run-Interactive
}
