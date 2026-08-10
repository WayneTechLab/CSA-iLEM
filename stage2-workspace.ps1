[CmdletBinding()]
param(
    [Parameter()][string]$Source = $(if ($env:CSA_IEM_STAGE2_SOURCE) { $env:CSA_IEM_STAGE2_SOURCE } else { Join-Path $HOME "CODEX PROJECTS" }),
    [Parameter()][Alias("managed-root", "Root")][string]$ManagedRoot = $(if ($env:CSA_IEM_STAGE2_ROOT) { $env:CSA_IEM_STAGE2_ROOT } else { Join-Path $HOME "CSA-iEM" }),
    [Parameter()][string[]]$Project = @(),
    [Parameter()][switch]$All,
    [Parameter()][switch]$Preflight,
    [Parameter()][switch]$Apply,
    [Parameter()][Alias("full-auto")][switch]$FullAuto,
    [Parameter()][Alias("create-missing-repos")][switch]$CreateMissingRepos,
    [Parameter()][Alias("repo-visibility")][ValidateSet("private", "public")][string]$RepoVisibility = "private",
    [Parameter()][Alias("retire-sources")][switch]$RetireSources,
    [Parameter()][Alias("delete-sources")][switch]$DeleteSources,
    [Parameter()][Alias("confirm-delete")][string]$ConfirmDelete = "",
    [Parameter()][Alias("archive-sources")][switch]$ArchiveSources,
    [Parameter()][Alias("cleanup-transaction-temp")][switch]$CleanupTransactionTemp,
    [Parameter()][Alias("prepare-runtime")][switch]$PrepareRuntime,
    [Parameter()][switch]$Yes,
    [Parameter()][Alias("Host")][string]$HostName = $(if ($env:GH_HOST) { $env:GH_HOST } else { "github.com" }),
    [Parameter()][string]$Account = "",
    [Parameter()][Alias("exclude-path")][string[]]$ExcludePath = @(),
    [Parameter()][ValidateSet("", "codex", "code", "copilot", "finder", "devcontainer")][string]$Open = "",
    [Parameter()][string]$Report = "",
    [Parameter()][Alias("h")][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$env:GH_HOST = $HostName

$AppRepository = "WayneTechLab/CSA-iLEM"
$LegacyAppRepository = "WayneTechLab/CSA-iEM"
$ActionName = if ($Apply -or $FullAuto) { "apply" } else { "preflight" }
if ($FullAuto) { $All = $true }

if ($Help) {
    @"
CSA-iEM Stage 2 workspace reconciliation

Usage:
  stage2-workspace.ps1 --source PATH --managed-root PATH --preflight --all
  stage2-workspace.ps1 --source PATH --managed-root PATH --preflight --project PATH
  stage2-workspace.ps1 --source PATH --managed-root PATH --apply --project PATH --yes
  stage2-workspace.ps1 --source PATH --managed-root PATH --full-auto --yes

Options:
  --create-missing-repos        Create an empty repository without uploading files.
  --repo-visibility private|public
  --retire-sources              Move completed Stage 1 folders under _temp.
  --delete-sources              Permanently remove verified Stage 1 inputs.
  --confirm-delete VERIFIED-STAGE2
  --archive-sources             Create and test a full ZIP before cleanup.
  --cleanup-transaction-temp    Remove this run's verified staging data.
  --prepare-runtime             Prepare Runtime/Repos mirrors.
  --exclude-path PATH           Exclude an active project path.
  --open codex|code|copilot|finder|devcontainer
"@ | Write-Host
    exit 0
}

function Write-InfoLine {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Get-IdentityKey {
    param([string]$Value)
    return (($Value.ToLowerInvariant()) -replace '[^a-z0-9]', '')
}

function Get-RemoteSlug {
    param([string]$Remote)
    if ([string]::IsNullOrWhiteSpace($Remote)) { return "" }
    $Value = $Remote.Trim()
    $Value = $Value -replace '^git@', ''
    $Value = $Value -replace '^ssh://git@', ''
    $Value = $Value -replace '^ssh://', ''
    $Value = $Value -replace '^https?://', ''
    $Value = $Value -replace '^www\.', ''
    if ($Value -match '^[^/:]+[:/](.+)$') { $Value = $Matches[1] }
    $Value = $Value.TrimStart('/').TrimEnd('/') -replace '\.git$', ''
    if ($Value -match '^[^/]+/[^/]+$') { return $Value }
    return ""
}

function Get-RepoNameCandidate {
    param([string]$Name)
    $Value = ($Name -replace '\s+', '-') -replace '[^A-Za-z0-9_.-]', ''
    $Value = ($Value -replace '-{2,}', '-').Trim('-')
    if (-not $Value) { return "imported-project" }
    return $Value
}

function Test-ProjectEvidence {
    param([string]$Path)
    if (Test-Path (Join-Path $Path ".git")) { return $true }
    foreach ($Marker in @("package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "pyproject.toml", "requirements.txt", "Cargo.toml", "go.mod", "Gemfile", "composer.json", "Package.swift", "firebase.json", "pom.xml", "build.gradle", "build.gradle.kts", "mix.exs", "pubspec.yaml", "deno.json", "deno.jsonc", "Transfer_Note.md", "Prompt_Inject.md")) {
        if (Test-Path (Join-Path $Path $Marker)) { return $true }
    }
    foreach ($Folder in @("src", "app", "lib", "server", "client", "functions", "ios", "android", "packages", "apps", ".devcontainer", ".SYSTEMX")) {
        if (Test-Path (Join-Path $Path $Folder)) { return $true }
    }
    return $false
}

function Test-SkippedFolder {
    param([string]$Name)
    if ($Name.StartsWith(".")) { return $true }
    if ($Name -in @("_temp", "_backup", "_backups")) { return $true }
    return $Name -match '(\.csa-iem-stage-|\.migrate-|\.moved-|\.partial-|\.transfer-candidate$|\.admin-verified$|\.data-copy$)'
}

function Invoke-GitText {
    param([string]$Path, [string[]]$Arguments)
    $Output = & git -C $Path @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return "" }
    return (($Output | Out-String).Trim())
}

function Get-GitSnapshot {
    param([string]$Path)
    $GitPath = Join-Path $Path ".git"
    if (-not (Test-Path $GitPath)) {
        return [pscustomobject]@{ HasGit = $false; Branch = ""; Head = ""; Upstream = ""; Staged = 0; Unstaged = 0; Untracked = 0; RemoteSlug = ""; RemoteUrl = ""; IsDirty = $false }
    }
    $Staged = 0
    $Unstaged = 0
    $Untracked = 0
    $StatusLines = @(& git -C $Path status --porcelain=v1 --untracked-files=normal 2>$null)
    foreach ($Line in $StatusLines) {
        if (-not $Line) { continue }
        if ($Line -in @("?? Transfer_Note.MD", "?? Prompt_Inject.MD")) { continue }
        if ($Line.StartsWith("??")) { $Untracked++; continue }
        if ($Line.Length -ge 1 -and $Line[0] -ne ' ') { $Staged++ }
        if ($Line.Length -ge 2 -and $Line[1] -ne ' ') { $Unstaged++ }
    }
    $RemoteUrl = Invoke-GitText -Path $Path -Arguments @("config", "--get", "remote.origin.url")
    return [pscustomobject]@{
        HasGit = $true
        Branch = Invoke-GitText -Path $Path -Arguments @("branch", "--show-current")
        Head = Invoke-GitText -Path $Path -Arguments @("rev-parse", "HEAD")
        Upstream = Invoke-GitText -Path $Path -Arguments @("rev-parse", "--abbrev-ref", "@{upstream}")
        Staged = $Staged
        Unstaged = $Unstaged
        Untracked = $Untracked
        RemoteSlug = Get-RemoteSlug $RemoteUrl
        RemoteUrl = $RemoteUrl
        IsDirty = (($Staged + $Unstaged + $Untracked) -gt 0)
    }
}

function Get-GitHubRepository {
    param([string]$Slug)
    if (-not $Slug) { return $null }
    $Existing = @($script:Catalog | Where-Object { $_ -and $_.nameWithOwner -ieq $Slug })
    if ($Existing.Count -eq 1) { return $Existing[0] }
    $Json = & gh repo view $Slug --json id,nameWithOwner,name,url,defaultBranchRef,isPrivate,isArchived,pushedAt,updatedAt 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $Json) { return $null }
    return ($Json | ConvertFrom-Json)
}

function Get-HintedRemoteSlug {
    param([string]$Path)
    foreach ($Name in @("Transfer_Note.md", "TRANSFER_NOTE.md", "Prompt_Inject.md", "PROMPT_INJECT.md", "package.json", "pyproject.toml", "README.md")) {
        $File = Join-Path $Path $Name
        if (-not (Test-Path $File -PathType Leaf)) { continue }
        $Content = Get-Content -Path $File -Raw -ErrorAction SilentlyContinue
        if ($Content -match 'https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?') {
            return (Get-RemoteSlug $Matches[0])
        }
    }
    return ""
}

function Resolve-RepositoryIdentity {
    param([string]$Path)
    $Name = Split-Path -Leaf $Path
    $Snapshot = Get-GitSnapshot $Path
    $Slug = $Snapshot.RemoteSlug
    $Evidence = if ($Slug) { "origin" } else { "none" }
    if (-not $Slug) {
        $Slug = Get-HintedRemoteSlug $Path
        if ($Slug) { $Evidence = "project metadata" }
    }
    if (-not $Slug) {
        $Key = Get-IdentityKey $Name
        $Matches = @($script:Catalog | Where-Object { $_ -and (Get-IdentityKey $_.name) -eq $Key })
        if ($Matches.Count -gt 1) {
            return [pscustomobject]@{ Ambiguous = $true; Exists = $false; Slug = "unresolved/$(Get-RepoNameCandidate $Name)"; Repository = $null; Evidence = "ambiguous GitHub name"; Snapshot = $Snapshot }
        }
        if ($Matches.Count -eq 1) {
            $Slug = $Matches[0].nameWithOwner
            $Evidence = "unique GitHub name"
        }
    }
    if (-not $Slug) {
        $Slug = "$Account/$(Get-RepoNameCandidate $Name)"
        $Evidence = "new repository candidate"
    }
    $Repository = Get-GitHubRepository $Slug
    if ($Repository) { $Slug = $Repository.nameWithOwner }
    return [pscustomobject]@{ Ambiguous = $false; Exists = [bool]$Repository; Slug = $Slug; Repository = $Repository; Evidence = $Evidence; Snapshot = $Snapshot }
}

function Test-ReservedProject {
    param([string]$Path, [string]$Slug)
    $NameKey = Get-IdentityKey (Split-Path -Leaf $Path)
    if ($NameKey -in @("csaiem", "csailem")) { return $true }
    if ((Get-IdentityKey $Slug) -in @((Get-IdentityKey $AppRepository), (Get-IdentityKey $LegacyAppRepository))) { return $true }
    $FullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    foreach ($Excluded in $ExcludePath) {
        if (-not $Excluded) { continue }
        $ExcludedFull = [IO.Path]::GetFullPath($Excluded).TrimEnd('\')
        if ($FullPath -eq $ExcludedFull -or $FullPath.StartsWith($ExcludedFull + '\', [StringComparison]::OrdinalIgnoreCase) -or $ExcludedFull.StartsWith($FullPath + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-DestinationMatches {
    param($Identity)
    $Expected = Join-Path $script:CodeRepos ($Identity.Slug -replace '/', '\')
    $Matches = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $Expected) { $Matches.Add($Expected) }
    if (Test-Path $script:CodeRepos) {
        foreach ($OwnerDir in @(Get-ChildItem -Path $script:CodeRepos -Directory -ErrorAction SilentlyContinue)) {
            foreach ($RepoDir in @(Get-ChildItem -Path $OwnerDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                if ($RepoDir.FullName -eq $Expected -or (Test-SkippedFolder $RepoDir.Name)) { continue }
                $Remote = Invoke-GitText -Path $RepoDir.FullName -Arguments @("config", "--get", "remote.origin.url")
                $RemoteSlug = Get-RemoteSlug $Remote
                if (-not $RemoteSlug) { continue }
                if ($RemoteSlug -ieq $Identity.Slug) { $Matches.Add($RepoDir.FullName); continue }
                if ($Identity.Repository) {
                    $Other = Get-GitHubRepository $RemoteSlug
                    if ($Other -and $Other.id -eq $Identity.Repository.id) { $Matches.Add($RepoDir.FullName) }
                }
            }
        }
    }
    return [pscustomobject]@{ Expected = $Expected; Paths = @($Matches | Select-Object -Unique) }
}

function Test-GitAncestor {
    param([string]$Path, [string]$Ancestor, [string]$Descendant)
    & git -C $Path cat-file -e "$Ancestor`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    & git -C $Path merge-base --is-ancestor $Ancestor $Descendant 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-CommitRelation {
    param([string]$SourcePath, [string]$DestinationPath, [string]$SourceHead, [string]$DestinationHead, [string]$Slug)
    if (-not $SourceHead -or -not $DestinationHead) { return "unknown" }
    if ($SourceHead -eq $DestinationHead) { return "identical" }
    if (Test-GitAncestor -Path $SourcePath -Ancestor $DestinationHead -Descendant $SourceHead) { return "source-ahead" }
    if (Test-GitAncestor -Path $SourcePath -Ancestor $SourceHead -Descendant $DestinationHead) { return "destination-ahead" }
    if (Test-GitAncestor -Path $DestinationPath -Ancestor $DestinationHead -Descendant $SourceHead) { return "source-ahead" }
    if (Test-GitAncestor -Path $DestinationPath -Ancestor $SourceHead -Descendant $DestinationHead) { return "destination-ahead" }
    $Comparison = & gh api "repos/$Slug/compare/$DestinationHead...$SourceHead" --hostname $HostName --jq '.status' 2>$null
    if ($LASTEXITCODE -ne 0) { return "unknown" }
    switch ($Comparison) {
        "ahead" { return "source-ahead" }
        "behind" { return "destination-ahead" }
        "identical" { return "identical" }
        "diverged" { return "diverged" }
        default { return "unknown" }
    }
}

function Get-RemoteHead {
    param([string]$Slug, [string]$Branch)
    if (-not $Slug -or -not $Branch) { return "" }
    $Value = & gh api "repos/$Slug/commits/$Branch" --hostname $HostName --jq '.sha' 2>$null
    if ($LASTEXITCODE -ne 0) { return "" }
    return (($Value | Out-String).Trim())
}

function New-PlanEntry {
    param([string]$State, $Identity, [string]$SourcePath, [string]$DestinationPath, $DestinationSnapshot, [string]$RemoteHead, [string]$Detail)
    $SourceSnapshot = $Identity.Snapshot
    return [pscustomobject]@{
        State = $State
        Slug = $Identity.Slug
        Source = $SourcePath
        Destination = $DestinationPath
        SourceHead = $SourceSnapshot.Head
        DestinationHead = if ($DestinationSnapshot) { $DestinationSnapshot.Head } else { "" }
        RemoteHead = $RemoteHead
        SourceStatus = "staged:$($SourceSnapshot.Staged) unstaged:$($SourceSnapshot.Unstaged) untracked:$($SourceSnapshot.Untracked)"
        DestinationStatus = if ($DestinationSnapshot) { "staged:$($DestinationSnapshot.Staged) unstaged:$($DestinationSnapshot.Unstaged) untracked:$($DestinationSnapshot.Untracked)" } else { "missing" }
        DefaultBranch = if ($Identity.Repository -and $Identity.Repository.defaultBranchRef) { $Identity.Repository.defaultBranchRef.name } else { "main" }
        RepoExists = $Identity.Exists
        Detail = $Detail
    }
}

function Get-ProjectPlan {
    param([string]$SourcePath)
    $Identity = Resolve-RepositoryIdentity $SourcePath
    if ($Identity.Ambiguous) { return New-PlanEntry -State "blocked-ambiguous-identity" -Identity $Identity -SourcePath $SourcePath -DestinationPath $script:CodeRepos -DestinationSnapshot $null -RemoteHead "" -Detail "More than one GitHub repository matched the folder name." }
    if (Test-ReservedProject -Path $SourcePath -Slug $Identity.Slug) { return New-PlanEntry -State "blocked-active-project" -Identity $Identity -SourcePath $SourcePath -DestinationPath (Join-Path $script:CodeRepos ($Identity.Slug -replace '/', '\')) -DestinationSnapshot $null -RemoteHead "" -Detail "The active CSA-iEM project is excluded from Stage 2." }
    if (-not $Identity.Exists -and $Identity.Slug.Split('/')[-1] -like '*.wiki') { return New-PlanEntry -State "blocked-github-wiki-remote" -Identity $Identity -SourcePath $SourcePath -DestinationPath (Join-Path $script:CodeRepos ($Identity.Slug -replace '/', '\')) -DestinationSnapshot $null -RemoteHead "" -Detail "A GitHub wiki Git remote is not a standalone repository. Select the parent repository or keep a manual archive." }
    if (-not $Identity.Exists -and -not $CreateMissingRepos) { return New-PlanEntry -State "needs-github-repository" -Identity $Identity -SourcePath $SourcePath -DestinationPath (Join-Path $script:CodeRepos ($Identity.Slug -replace '/', '\')) -DestinationSnapshot $null -RemoteHead "" -Detail "No unique GitHub repository was verified. Enable explicit repository creation or resolve identity manually." }
    if ($Identity.Repository -and $Identity.Repository.isArchived) { return New-PlanEntry -State "blocked-archived-repository" -Identity $Identity -SourcePath $SourcePath -DestinationPath (Join-Path $script:CodeRepos ($Identity.Slug -replace '/', '\')) -DestinationSnapshot $null -RemoteHead "" -Detail "GitHub reports that this repository is archived." }

    $Destinations = Get-DestinationMatches $Identity
    if ($Destinations.Paths.Count -gt 1) { return New-PlanEntry -State "blocked-duplicate-destinations" -Identity $Identity -SourcePath $SourcePath -DestinationPath $Destinations.Paths[0] -DestinationSnapshot $null -RemoteHead "" -Detail "Multiple canonical folders have the same GitHub identity." }
    $DestinationPath = if ($Destinations.Paths.Count -eq 1) { $Destinations.Paths[0] } else { $Destinations.Expected }
    $RemoteHead = Get-RemoteHead -Slug $Identity.Slug -Branch $(if ($Identity.Repository -and $Identity.Repository.defaultBranchRef) { $Identity.Repository.defaultBranchRef.name } else { "main" })
    if (-not (Test-Path $DestinationPath)) {
        $State = if ($Identity.Exists) { "ready-new-canonical" } else { "ready-new-private-repo" }
        $Detail = if ($Identity.Exists) { "Verified by $($Identity.Evidence). The complete project will be staged and promoted without changing Stage 1." } else { "A $RepoVisibility empty GitHub repository will be created without uploading project files." }
        return New-PlanEntry -State $State -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $null -RemoteHead $RemoteHead -Detail $Detail
    }

    $DestinationSnapshot = Get-GitSnapshot $DestinationPath
    if (-not $DestinationSnapshot.HasGit) { return New-PlanEntry -State "blocked-destination-not-git" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "The canonical destination exists but is not a Git worktree." }
    if ($DestinationSnapshot.RemoteSlug -and $Identity.Repository) {
        $Other = Get-GitHubRepository $DestinationSnapshot.RemoteSlug
        if ($Other -and $Other.id -ne $Identity.Repository.id) { return New-PlanEntry -State "blocked-identity-conflict" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "The destination belongs to a different GitHub repository ID." }
    }
    if ($DestinationSnapshot.IsDirty) { return New-PlanEntry -State "blocked-destination-dirty" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "Canonical files are staged, modified, or untracked. No overwrite is allowed." }
    if ($Identity.Snapshot.IsDirty) { return New-PlanEntry -State "blocked-source-dirty" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "Stage 1 has local changes and canonical already exists. Preserve both for manual reconciliation." }
    if (-not $Identity.Snapshot.HasGit -or -not $Identity.Snapshot.Head -or -not $DestinationSnapshot.Head) { return New-PlanEntry -State "blocked-history-unavailable" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "Both existing copies need readable Git history before an automatic merge." }
    $Relation = Get-CommitRelation -SourcePath $SourcePath -DestinationPath $DestinationPath -SourceHead $Identity.Snapshot.Head -DestinationHead $DestinationSnapshot.Head -Slug $Identity.Slug
    switch ($Relation) {
        "identical" { return New-PlanEntry -State "ready-additive-heal" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "Git heads match. Only missing non-.git paths may be added." }
        "source-ahead" { return New-PlanEntry -State "ready-fast-forward" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "Stage 1 is a clean descendant. Git can fast-forward locally before additive healing." }
        "destination-ahead" { return New-PlanEntry -State "ready-destination-newer" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "Canonical history is newer. Git remains unchanged; only missing non-.git paths may be added." }
        "diverged" { return New-PlanEntry -State "blocked-diverged-history" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "The clean worktrees have diverged commit history." }
        default { return New-PlanEntry -State "blocked-unverified-history" -Identity $Identity -SourcePath $SourcePath -DestinationPath $DestinationPath -DestinationSnapshot $DestinationSnapshot -RemoteHead $RemoteHead -Detail "GitHub and local objects could not prove safe ancestry." }
    }
}

function Copy-CompleteProject {
    param([string]$From, [string]$To)
    if (Test-Path $To) { Remove-Item -Path $To -Recurse -Force }
    New-Item -ItemType Directory -Path $To -Force | Out-Null
    & robocopy $From $To /MIR /COPY:DAT /DCOPY:DAT /SL /R:2 /W:1 /NFL /NDL /NP | Out-Host
    if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }
}

function Test-CompleteProject {
    param([string]$From, [string]$To)
    $SourceFiles = @(Get-ChildItem -LiteralPath $From -Recurse -Force -File -ErrorAction SilentlyContinue)
    $DestinationFiles = @(Get-ChildItem -LiteralPath $To -Recurse -Force -File -ErrorAction SilentlyContinue)
    $SourceBytes = ($SourceFiles | Measure-Object -Property Length -Sum).Sum
    $DestinationBytes = ($DestinationFiles | Measure-Object -Property Length -Sum).Sum
    if ($SourceFiles.Count -ne $DestinationFiles.Count -or $SourceBytes -ne $DestinationBytes) { return $false }
    $SourceGit = Get-GitSnapshot $From
    if ($SourceGit.HasGit) {
        $DestinationGit = Get-GitSnapshot $To
        if (-not $DestinationGit.HasGit -or $SourceGit.Head -ne $DestinationGit.Head) { return $false }
        & git -C $To fsck --no-dangling 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return $true
}

function Add-MissingProjectFiles {
    param([string]$From, [string]$To)
    & robocopy $From $To /E /XC /XN /XO /COPY:DAT /DCOPY:DAT /SL /XD .git /R:2 /W:1 /NFL /NDL /NP | Out-Host
    if ($LASTEXITCODE -gt 7) { throw "robocopy additive heal failed with exit code $LASTEXITCODE" }
}

function Add-OriginIfNeeded {
    param([string]$Path, [string]$Slug)
    if (-not (Test-Path (Join-Path $Path ".git"))) { & git -C $Path init -b main | Out-Null }
    $Current = Invoke-GitText -Path $Path -Arguments @("remote", "get-url", "origin")
    if (-not $Current) { & git -C $Path remote add origin "https://$HostName/$Slug.git" }
}

function Invoke-SafeRemoteFastForward {
    param([string]$Path, [string]$Branch, [string]$RemoteHead)
    if (-not $RemoteHead) { return }
    $Current = Invoke-GitText -Path $Path -Arguments @("rev-parse", "HEAD")
    if (-not $Current -or $Current -eq $RemoteHead) { return }
    & git -C $Path fetch origin $Branch --prune 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return }
    & git -C $Path merge-base --is-ancestor HEAD "origin/$Branch" 2>$null
    if ($LASTEXITCODE -eq 0) { & git -C $Path merge --ff-only "origin/$Branch" | Out-Null }
}

function Invoke-OpenProject {
    param([string]$Path)
    switch ($Open) {
        "codex" { Start-Process "codex" -ArgumentList @($Path) -ErrorAction SilentlyContinue }
        "code" { Start-Process "code" -ArgumentList @($Path) -ErrorAction SilentlyContinue }
        "copilot" { Start-Process "GitHub Copilot" -ArgumentList @($Path) -ErrorAction SilentlyContinue }
        "finder" { Start-Process "explorer.exe" -ArgumentList @($Path) }
        "devcontainer" { & devcontainer up --workspace-folder $Path }
    }
}

function Test-VerifiedZip {
    param([string]$Archive)
    if (-not $Archive -or -not (Test-Path $Archive -PathType Leaf)) { return $false }
    & tar.exe -tf $Archive *> $null
    return ($LASTEXITCODE -eq 0)
}

function New-VerifiedStage2Archive {
    param([string]$Path, [string]$Slug)
    $Archive = Join-Path $script:ArchivesDir (($Slug -replace '/', '\') + ".zip")
    $Partial = "$Archive.partial.zip"
    New-Item -ItemType Directory -Path (Split-Path $Archive -Parent) -Force | Out-Null
    Remove-Item -LiteralPath $Partial -Force -ErrorAction SilentlyContinue
    $Parent = Split-Path $Path -Parent
    $Leaf = Split-Path $Path -Leaf
    & tar.exe -a -cf $Partial -C $Parent $Leaf
    if ($LASTEXITCODE -ne 0 -or -not (Test-VerifiedZip $Partial)) {
        Remove-Item -LiteralPath $Partial -Force -ErrorAction SilentlyContinue
        throw "Verified ZIP creation failed for $Path"
    }
    Move-Item -LiteralPath $Partial -Destination $Archive -Force
    return $Archive
}

function Test-GitObjectsRepresented {
    param([string]$From, [string]$To)
    if (-not (Test-Path (Join-Path $From ".git"))) { return $true }
    if (-not (Test-Path (Join-Path $To ".git"))) { return $false }
    $SourceHead = Invoke-GitText -Path $From -Arguments @("rev-parse", "HEAD")
    if (-not $SourceHead) { return $false }
    & git -C $To cat-file -e "$SourceHead`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $SourceRemote = Get-RemoteSlug (Invoke-GitText -Path $From -Arguments @("config", "--get", "remote.origin.url"))
    $DestinationRemote = Get-RemoteSlug (Invoke-GitText -Path $To -Arguments @("config", "--get", "remote.origin.url"))
    if ($SourceRemote -and $DestinationRemote -and $SourceRemote -ine $DestinationRemote) { return $false }
    foreach ($ObjectId in @(& git -C $From for-each-ref --format='%(objectname)' 2>$null)) {
        if (-not $ObjectId) { continue }
        & git -C $To cat-file -e "$ObjectId`^{object}" 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    & git -C $To fsck --no-dangling 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-SourceRepresented {
    param([string]$From, [string]$To, [string]$Archive = "")
    if (-not (Test-Path $From -PathType Container) -or -not (Test-Path $To -PathType Container)) { return $false }
    $ContentMatches = $true
    $SourcePrefix = $From.TrimEnd('\') + '\'
    foreach ($Item in @(Get-ChildItem -LiteralPath $From -Recurse -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer })) {
        $Relative = $Item.FullName.Substring($SourcePrefix.Length)
        if ($Relative -eq '.git' -or $Relative.StartsWith('.git\', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $DestinationPath = Join-Path $To $Relative
        if (-not (Test-Path -LiteralPath $DestinationPath)) { $ContentMatches = $false; break }
        $DestinationItem = Get-Item -LiteralPath $DestinationPath -Force -ErrorAction Stop
        if ($Item.LinkType) {
            if (-not $DestinationItem.LinkType -or (@($Item.Target) -join '|') -ne (@($DestinationItem.Target) -join '|')) { $ContentMatches = $false; break }
            continue
        }
        if ($Item.Length -ne $DestinationItem.Length) { $ContentMatches = $false; break }
        if ((Get-FileHash -LiteralPath $Item.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash) { $ContentMatches = $false; break }
    }
    $GitMatches = Test-GitObjectsRepresented -From $From -To $To
    if ($ContentMatches -and $GitMatches) { return $true }
    if (Test-VerifiedZip $Archive) {
        Write-WarnLine "Canonical state differs from part of the source; the tested ZIP remains the recovery copy."
        return $true
    }
    return $false
}

function Write-Stage2Receipt {
    param(
        [string]$Status,
        [string]$Slug,
        [string]$OriginalSource,
        [string]$CurrentSource,
        [string]$Destination,
        [string]$Archive,
        [string]$Quarantine,
        [string]$Detail
    )
    foreach ($Value in @($Status, $Slug, $OriginalSource, $CurrentSource, $Destination, $Archive, $Quarantine, $Detail)) {
        if ($Value -match "[`r`n]") { throw "Receipt values cannot contain line breaks." }
    }
    $Receipt = Join-Path $script:ReceiptsDir (($Slug -replace '/', '\') + ".receipt")
    New-Item -ItemType Directory -Path (Split-Path $Receipt -Parent) -Force | Out-Null
    @(
        "format=1",
        "stage=2",
        "status=$Status",
        "transaction=$($script:TransactionId)",
        "repository=$Slug",
        "source_root=$Source",
        "original_source=$OriginalSource",
        "current_source=$CurrentSource",
        "destination=$Destination",
        "archive=$Archive",
        "quarantine=$Quarantine",
        "import_stage=$($script:ImportStage)",
        "report=$Report",
        "verified_at=$((Get-Date).ToUniversalTime().ToString('o'))",
        "detail=$Detail"
    ) | Set-Content -LiteralPath $Receipt -Encoding UTF8
    return $Receipt
}

function Remove-VerifiedStage1Source {
    param([string]$Path, [string]$Destination, [string]$Slug, [string]$Archive)
    $DeleteRoot = Join-Path $Source "_temp\Stage2-Delete\$($script:TransactionId)"
    New-Item -ItemType Directory -Path $DeleteRoot -Force | Out-Null
    $Quarantine = Join-Path $DeleteRoot (Split-Path $Path -Leaf)
    if (Test-Path $Quarantine) { $Quarantine = "$Quarantine-$(Get-Date -Format HHmmss)" }
    Write-Stage2Receipt -Status "verified-delete-pending" -Slug $Slug -OriginalSource $Path -CurrentSource $Path -Destination $Destination -Archive $Archive -Quarantine $Quarantine -Detail "Canonical and optional archive verification passed before quarantine." | Out-Null
    Move-Item -LiteralPath $Path -Destination $Quarantine
    if (-not (Test-SourceRepresented -From $Quarantine -To $Destination -Archive $Archive)) {
        Move-Item -LiteralPath $Quarantine -Destination $Path -ErrorAction SilentlyContinue
        Write-Stage2Receipt -Status "delete-rolled-back" -Slug $Slug -OriginalSource $Path -CurrentSource $Path -Destination $Destination -Archive $Archive -Quarantine $Quarantine -Detail "The quarantine verification failed; source deletion was rolled back." | Out-Null
        throw "The second verification failed; source deletion was rolled back."
    }
    try {
        Remove-Item -LiteralPath $Quarantine -Recurse -Force
    } catch {
        Write-Stage2Receipt -Status "verified-quarantined" -Slug $Slug -OriginalSource $Path -CurrentSource $Quarantine -Destination $Destination -Archive $Archive -Quarantine $Quarantine -Detail "Verification passed, but permanent removal of quarantine failed." | Out-Null
        throw
    }
    Write-Stage2Receipt -Status "source-deleted" -Slug $Slug -OriginalSource $Path -CurrentSource "" -Destination $Destination -Archive $Archive -Quarantine $Quarantine -Detail "The Stage 1 input was permanently removed after two verification passes." | Out-Null
}

function Invoke-PlanEntry {
    param($Entry, [string]$TransactionId)
    if ($Entry.State -notmatch '^ready-') { return "skipped" }
    if ($Entry.State -in @("ready-new-canonical", "ready-new-private-repo")) {
        $StagePath = Join-Path $script:ImportStage ("code\" + ($Entry.Slug -replace '/', '\'))
        New-Item -ItemType Directory -Path (Split-Path $StagePath -Parent) -Force | Out-Null
        Copy-CompleteProject -From $Entry.Source -To $StagePath
        if (-not (Test-CompleteProject -From $Entry.Source -To $StagePath)) { Remove-Item -Path $StagePath -Recurse -Force; return "failed" }
        if ($Entry.State -eq "ready-new-private-repo") {
            $VisibilityFlag = if ($RepoVisibility -eq "public") { "--public" } else { "--private" }
            Write-InfoLine "Creating $RepoVisibility empty GitHub repository $($Entry.Slug); no files are uploaded."
            & gh repo create $Entry.Slug $VisibilityFlag | Out-Null
            if ($LASTEXITCODE -ne 0) { Remove-Item -Path $StagePath -Recurse -Force; return "failed" }
            Add-OriginIfNeeded -Path $StagePath -Slug $Entry.Slug
        }
        if (Test-Path $Entry.Destination) { Remove-Item -Path $StagePath -Recurse -Force; return "failed" }
        New-Item -ItemType Directory -Path (Split-Path $Entry.Destination -Parent) -Force | Out-Null
        Move-Item -Path $StagePath -Destination $Entry.Destination
        Invoke-SafeRemoteFastForward -Path $Entry.Destination -Branch $Entry.DefaultBranch -RemoteHead $Entry.RemoteHead
    } elseif ($Entry.State -eq "ready-fast-forward") {
        & git -C $Entry.Destination fetch $Entry.Source $Entry.SourceHead 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return "failed" }
        & git -C $Entry.Destination merge --ff-only FETCH_HEAD 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return "failed" }
        Add-MissingProjectFiles -From $Entry.Source -To $Entry.Destination
        Invoke-SafeRemoteFastForward -Path $Entry.Destination -Branch $Entry.DefaultBranch -RemoteHead $Entry.RemoteHead
    } else {
        Add-MissingProjectFiles -From $Entry.Source -To $Entry.Destination
        Invoke-SafeRemoteFastForward -Path $Entry.Destination -Branch $Entry.DefaultBranch -RemoteHead $Entry.RemoteHead
    }
    $ArchivePath = ""
    if ($ArchiveSources) {
        $ArchivePath = New-VerifiedStage2Archive -Path $Entry.Source -Slug $Entry.Slug
        Write-InfoLine "Verified Stage 2 source archive: $ArchivePath"
    }
    if (-not (Test-SourceRepresented -From $Entry.Source -To $Entry.Destination -Archive $ArchivePath)) {
        throw "Final canonical verification failed; the Stage 1 source was retained."
    }
    $Receipt = Write-Stage2Receipt -Status "verified-source-kept" -Slug $Entry.Slug -OriginalSource $Entry.Source -CurrentSource $Entry.Source -Destination $Entry.Destination -Archive $ArchivePath -Quarantine "" -Detail "Canonical and optional archive verification passed."
    Write-InfoLine "Stage 2 receipt: $Receipt"
    if ($PrepareRuntime) {
        $RuntimePath = Join-Path $script:RuntimeRepos ($Entry.Slug -replace '/', '\')
        if (-not (Test-Path $RuntimePath)) {
            $RuntimeStage = Join-Path $script:ImportStage ("runtime\" + ($Entry.Slug -replace '/', '\'))
            New-Item -ItemType Directory -Path (Split-Path $RuntimeStage -Parent) -Force | Out-Null
            Copy-CompleteProject -From $Entry.Destination -To $RuntimeStage
            if (Test-CompleteProject -From $Entry.Destination -To $RuntimeStage) {
                New-Item -ItemType Directory -Path (Split-Path $RuntimePath -Parent) -Force | Out-Null
                Move-Item $RuntimeStage $RuntimePath
            }
        } else {
            $RuntimeSnapshot = Get-GitSnapshot $RuntimePath
            if ($RuntimeSnapshot.HasGit -and -not $RuntimeSnapshot.IsDirty) { Add-MissingProjectFiles -From $Entry.Destination -To $RuntimePath }
        }
    }
    if ($DeleteSources) {
        Remove-VerifiedStage1Source -Path $Entry.Source -Destination $Entry.Destination -Slug $Entry.Slug -Archive $ArchivePath
        Write-InfoLine "Permanently removed verified Stage 1 source: $($Entry.Source)"
    } elseif ($RetireSources) {
        $CompletedRoot = Join-Path $Source "_temp\Stage2-Completed\$TransactionId"
        New-Item -ItemType Directory -Path $CompletedRoot -Force | Out-Null
        $Target = Join-Path $CompletedRoot (Split-Path -Leaf $Entry.Source)
        if (Test-Path $Target) { $Target = "$Target-$(Get-Date -Format HHmmss)" }
        Move-Item -Path $Entry.Source -Destination $Target
        Write-Stage2Receipt -Status "source-retired" -Slug $Entry.Slug -OriginalSource $Entry.Source -CurrentSource $Target -Destination $Entry.Destination -Archive $ArchivePath -Quarantine "" -Detail "The verified Stage 1 input was moved under _temp/Stage2-Completed." | Out-Null
    }
    if ($Open) { Invoke-OpenProject $Entry.Destination }
    return "applied"
}

if ($RetireSources -and $DeleteSources) { throw "Choose either --retire-sources or --delete-sources, not both." }
if ($ActionName -eq "apply" -and $DeleteSources -and $ConfirmDelete -ne "VERIFIED-STAGE2") {
    throw "Permanent Stage 1 deletion requires --confirm-delete VERIFIED-STAGE2."
}
if ($ActionName -eq "apply" -and -not $Yes) {
    $Confirmation = Read-Host "Type STAGE2 to run safety-gated workspace reconciliation"
    if ($Confirmation -ne "STAGE2") { throw "Stage 2 apply was cancelled." }
    $Yes = $true
}
if (-not $All -and $Project.Count -eq 0) { throw "Choose --all or at least one --project." }
if (-not (Test-Path $Source -PathType Container)) { throw "Stage 1 source folder was not found: $Source" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required for Stage 2." }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI is required for Stage 2." }
if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) { throw "robocopy is required for Stage 2 on Windows." }
if ($ArchiveSources -and -not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw "tar.exe is required for verified Stage 2 ZIP archives." }

$Source = [IO.Path]::GetFullPath($Source).TrimEnd('\')
$ManagedRoot = [IO.Path]::GetFullPath($ManagedRoot).TrimEnd('\')
if ($ManagedRoot.StartsWith($Source + '\', [StringComparison]::OrdinalIgnoreCase) -or $Source.StartsWith($ManagedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Stage 1 source and managed root must be separate folders." }
$script:CodeRepos = Join-Path $ManagedRoot "Code\Repos"
$script:RuntimeRepos = Join-Path $ManagedRoot "Runtime\Repos"
$ReportsDir = Join-Path $ManagedRoot "Runtime\Reports\Stage2"
$TransactionId = "$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))-$PID"
$script:TransactionId = $TransactionId
$script:ImportStage = Join-Path $ManagedRoot "Import\Stage2\$TransactionId"
$script:ArchivesDir = Join-Path $ManagedRoot "Import\Archives\Stage2\$TransactionId"
$script:ReceiptsDir = Join-Path $ManagedRoot "Runtime\Receipts\Stage2\$TransactionId"
foreach ($Path in @($script:CodeRepos, $script:RuntimeRepos, $ReportsDir, $script:ReceiptsDir, (Split-Path $script:ImportStage -Parent), (Split-Path $script:ArchivesDir -Parent))) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
if (-not $Report) { $Report = Join-Path $ReportsDir "stage2-$TransactionId.md" }

& gh auth status --hostname $HostName 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI is not logged in to $HostName." }
if (-not $Account) { $Account = ((& gh api user --hostname $HostName --jq '.login') | Out-String).Trim() }
$CatalogJson = & gh repo list $Account --limit 1000 --json id,nameWithOwner,name,url,defaultBranchRef,isPrivate,isArchived,pushedAt,updatedAt
$script:Catalog = @($CatalogJson | ConvertFrom-Json | Where-Object { $_ })

$Candidates = [System.Collections.Generic.List[string]]::new()
if ($All) {
    foreach ($Directory in @(Get-ChildItem -LiteralPath $Source -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ((Test-SkippedFolder $Directory.Name) -or -not (Test-ProjectEvidence $Directory.FullName)) { continue }
        $Candidates.Add($Directory.FullName)
    }
}
foreach ($Selector in $Project) {
    $Candidate = if (Test-Path $Selector -PathType Container) { [IO.Path]::GetFullPath($Selector) } else { Join-Path $Source $Selector }
    if (-not (Test-Path $Candidate -PathType Container)) { Write-WarnLine "Selected project was not found: $Selector"; continue }
    if ((Test-SkippedFolder (Split-Path -Leaf $Candidate)) -or -not (Test-ProjectEvidence $Candidate)) { Write-WarnLine "Skipped temporary folder or path without project evidence: $Candidate"; continue }
    if (-not $Candidates.Contains($Candidate)) { $Candidates.Add($Candidate) }
}
if ($Candidates.Count -eq 0) { throw "No eligible Stage 2 projects were found under $Source" }

Write-InfoLine "Stage 1 source: $Source"
Write-InfoLine "Managed root: $ManagedRoot"
Write-InfoLine "GitHub identity: $HostName/$Account"
$Plans = [System.Collections.Generic.List[object]]::new()
foreach ($Candidate in $Candidates) {
    $Entry = Get-ProjectPlan $Candidate
    $Plans.Add($Entry)
    Write-Host ("PLAN | {0,-27} | {1,-42} | {2}" -f $Entry.State, $Entry.Slug, (Split-Path -Leaf $Entry.Source))
}

$Applied = 0
$Skipped = 0
$Failed = 0
if ($ActionName -eq "apply") {
    New-Item -ItemType Directory -Path $script:ImportStage -Force | Out-Null
    $Index = 0
    foreach ($Entry in $Plans) {
        $Index++
        Write-Host "PROGRESS | $Index/$($Plans.Count) | $($Entry.State) | $($Entry.Slug)"
        try {
            $Result = Invoke-PlanEntry -Entry $Entry -TransactionId $TransactionId
            switch ($Result) { "applied" { $Applied++ } "failed" { $Failed++ } default { $Skipped++ } }
        } catch {
            Write-WarnLine "$($Entry.Slug): $($_.Exception.Message)"
            $Failed++
        }
    }
    if ($CleanupTransactionTemp) {
        if ($Failed -eq 0 -and $script:ImportStage.StartsWith((Join-Path $ManagedRoot "Import\Stage2") + '\', [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $script:ImportStage -Recurse -Force -ErrorAction SilentlyContinue
            Write-InfoLine "Removed verified Stage 2 transaction data: $($script:ImportStage)"
        } else {
            Write-WarnLine "Stage 2 transaction data was retained because at least one apply failed."
        }
    }
}

$Ready = @($Plans | Where-Object State -like 'ready-*').Count
$Blocked = @($Plans | Where-Object State -like 'blocked-*').Count
$NeedsRepo = @($Plans | Where-Object State -like 'needs-*').Count
$Lines = [System.Collections.Generic.List[string]]::new()
$Lines.Add("# CSA-iEM Stage 2 Report")
$Lines.Add("")
$Lines.Add("- Transaction: ``$TransactionId``")
$Lines.Add("- Action: ``$ActionName``")
$Lines.Add("- GitHub host/account: ``$HostName`` / ``$Account``")
$Lines.Add("- Stage 1 source: ``$Source``")
$Lines.Add("- Managed root: ``$ManagedRoot``")
$Lines.Add("- Plans: $($Plans.Count) total, $Ready ready, $Blocked blocked, $NeedsRepo needing a repository")
$Lines.Add("- Execution: $Applied applied, $Skipped skipped, $Failed failed")
$Lines.Add("- Verified ZIP archives: $(if ($ArchiveSources) { 'enabled' } else { 'disabled' })")
$Lines.Add("- Stage 1 retention: $(if ($DeleteSources) { 'permanently-delete-after-verify' } elseif ($RetireSources) { 'retire-to-temp' } else { 'keep' })")
$Lines.Add("- Current transaction cleanup: $(if ($CleanupTransactionTemp) { 'enabled' } else { 'disabled' })")
$Lines.Add("")
$Lines.Add("| State | Repository | Source | Destination | Source status | Destination status | Detail |")
$Lines.Add("|---|---|---|---|---|---|---|")
foreach ($Entry in $Plans) { $Lines.Add("| $($Entry.State) | ``$($Entry.Slug)`` | ``$($Entry.Source)`` | ``$($Entry.Destination)`` | $($Entry.SourceStatus) | $($Entry.DestinationStatus) | $($Entry.Detail) |") }
$Lines.Add("")
$Lines.Add("Existing dirty, staged, divergent, ambiguous, archived, or identity-conflicting destinations are never overwritten. New repositories are empty and $RepoVisibility; Stage 2 does not upload project files. Permanent deletion requires a receipt plus canonical verification before and after same-volume quarantine.")
$Lines | Set-Content -Path $Report -Encoding UTF8
Write-InfoLine "Stage 2 report: $Report"
Write-Host "SUMMARY | total=$($Plans.Count) ready=$Ready blocked=$Blocked needs_repo=$NeedsRepo applied=$Applied skipped=$Skipped failed=$Failed"
