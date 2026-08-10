[CmdletBinding()]
param(
    [Parameter()][string]$Source = $(if ($env:CSA_IEM_STAGE2_SOURCE) { $env:CSA_IEM_STAGE2_SOURCE } else { Join-Path $HOME "CODEX PROJECTS" }),
    [Parameter()][Alias("managed-root", "Root")][string]$ManagedRoot = $(if ($env:CSA_IEM_STAGE2_ROOT) { $env:CSA_IEM_STAGE2_ROOT } else { Join-Path $HOME "CSA-iEM" }),
    [Parameter()][string[]]$Receipt = @(),
    [Parameter()][string[]]$Project = @(),
    [Parameter()][switch]$All,
    [Parameter()][switch]$Preflight,
    [Parameter()][switch]$Apply,
    [Parameter()][Alias("delete-stage1-originals")][switch]$DeleteStage1Originals,
    [Parameter()][Alias("delete-stage2-inputs")][switch]$DeleteStage2Inputs,
    [Parameter()][Alias("cleanup-transaction-temp")][switch]$CleanupTransactionTemp,
    [Parameter()][Alias("cleanup-all-verified-temp")][switch]$CleanupAllVerifiedTemp,
    [Parameter()][Alias("confirm-delete")][string]$ConfirmDelete = "",
    [Parameter()][switch]$Yes,
    [Parameter()][string]$Report = "",
    [Parameter()][Alias("h")][switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$AppRepository = "WayneTechLab/CSA-iLEM"
$LegacyAppRepository = "WayneTechLab/CSA-iEM"
$ActionName = if ($Apply) { "apply" } else { "preflight" }

if ($Help) {
    @"
CSA-iEM Stage 3 verified lifecycle cleanup

Usage:
  stage3-cleanup.ps1 --source PATH --managed-root PATH --preflight --all
  stage3-cleanup.ps1 --source PATH --managed-root PATH --apply --all [cleanup options] --yes --confirm-delete VERIFIED-STAGE3
  stage3-cleanup.ps1 --receipt PATH --preflight

Selection:
  --all                         Use every verified Stage 1 and Stage 2 receipt.
  --receipt PATH               Use one receipt; repeat for multi-select.
  --project NAME_OR_SLUG       Filter receipts by project/repository; repeatable.

Cleanup options:
  --delete-stage1-originals    Permanently remove verified original project folders.
  --delete-stage2-inputs       Permanently remove verified CODEX PROJECTS inputs.
  --cleanup-transaction-temp   Remove receipt-linked Stage 2 transaction data.
  --cleanup-all-verified-temp  Also remove receipt-linked Stage 1 index artifacts.
  --confirm-delete VERIFIED-STAGE3
                                Required for every Stage 3 apply.

Stage 3 never deletes backups, reports, receipts, canonical repositories, active
CSA-iEM workspaces, failed transactions, or unreferenced temporary directories.
"@ | Write-Host
    exit 0
}

function Write-InfoLine { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-WarnLine { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }

function Get-FullNormalizedPath {
    param([string]$Path)
    $RealPathCommand = Get-Command realpath -ErrorAction SilentlyContinue
    if ($RealPathCommand -and (Test-Path -LiteralPath $Path)) {
        $Resolved = (& $RealPathCommand.Source $Path 2>$null | Select-Object -First 1)
        if ($Resolved) { return ([string]$Resolved).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) }
    }
    if ($RealPathCommand) {
        $Parent = Split-Path $Path -Parent
        if ($Parent -and (Test-Path -LiteralPath $Parent -PathType Container)) {
            $ResolvedParent = (& $RealPathCommand.Source $Parent 2>$null | Select-Object -First 1)
            if ($ResolvedParent) { return (Join-Path ([string]$ResolvedParent) (Split-Path $Path -Leaf)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) }
        }
    }
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-PathWithin {
    param([string]$Candidate, [string]$Root)
    if (-not $Candidate -or -not $Root) { return $false }
    $CandidatePath = Get-FullNormalizedPath $Candidate
    $RootPath = Get-FullNormalizedPath $Root
    if ($CandidatePath.Equals($RootPath, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $CandidatePath.StartsWith($RootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Get-IdentityKey {
    param([string]$Value)
    if (-not $Value) { return "" }
    return (($Value.ToLowerInvariant()) -replace '[^a-z0-9]', '')
}

function Test-ReservedProject {
    param([string]$Path, [string]$Repository)
    $NameKey = Get-IdentityKey (Split-Path $Path -Leaf)
    if ($NameKey -in @("csaiem", "csailem")) { return $true }
    return (Get-IdentityKey $Repository) -in @((Get-IdentityKey $AppRepository), (Get-IdentityKey $LegacyAppRepository))
}

function Read-LifecycleReceipt {
    param([string]$Path)
    $Values = @{}
    foreach ($Line in @(Get-Content -LiteralPath $Path -ErrorAction Stop)) {
        $Separator = $Line.IndexOf('=')
        if ($Separator -lt 1) { continue }
        $Key = $Line.Substring(0, $Separator)
        if (-not $Values.ContainsKey($Key)) { $Values[$Key] = $Line.Substring($Separator + 1) }
    }
    return $Values
}

function Get-ReceiptValue {
    param([hashtable]$Values, [string]$Key, [string]$Default = "")
    if ($Values.ContainsKey($Key)) { return [string]$Values[$Key] }
    return $Default
}

function Test-VerifiedReceiptStatus {
    param([string]$Status)
    return $Status -match '^(verified-.+|source-kept|source-retired|source-deleted)$'
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

function Invoke-GitText {
    param([string]$Path, [string[]]$Arguments)
    $Output = & git -C $Path @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return "" }
    return (($Output | Out-String).Trim())
}

function Test-VerifiedZip {
    param([string]$Archive)
    if (-not $Archive -or -not (Test-Path -LiteralPath $Archive -PathType Leaf)) { return $false }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $Zip = [IO.Compression.ZipFile]::OpenRead($Archive)
        try { return $Zip.Entries.Count -gt 0 } finally { $Zip.Dispose() }
    } catch { return $false }
}

function Test-GitObjectsRepresented {
    param([string]$From, [string]$To, [bool]$IncludeGit)
    if (-not $IncludeGit -or -not (Test-Path -LiteralPath (Join-Path $From ".git"))) { return $true }
    if (-not (Test-Path -LiteralPath (Join-Path $To ".git"))) { return $false }
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
    return $LASTEXITCODE -eq 0
}

function Test-ExcludedContent {
    param([string]$Relative, [bool]$IncludeFinder, [bool]$IncludeDependencies)
    $Normalized = $Relative.Replace([IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar)
    $Parts = @($Normalized.Split([IO.Path]::DirectorySeparatorChar))
    if ($Parts.Count -gt 0 -and $Parts[0] -eq ".git") { return $true }
    if (-not $IncludeFinder -and (($Parts | Where-Object { $_ -eq ".DS_Store" -or $_.StartsWith("._") }).Count -gt 0)) { return $true }
    if (-not $IncludeDependencies) {
        $Excluded = @("node_modules", ".venv", "venv", "dist", "build", ".build", "DerivedData", ".next", ".turbo", "coverage", ".cache")
        if (($Parts | Where-Object { $_ -in $Excluded }).Count -gt 0) { return $true }
    }
    return $false
}

function Test-SourceRepresented {
    param(
        [string]$From,
        [string]$To,
        [string]$Archive = "",
        [bool]$IncludeGit = $true,
        [bool]$IncludeFinder = $true,
        [bool]$IncludeDependencies = $true
    )
    if (-not (Test-Path -LiteralPath $From -PathType Container) -or -not (Test-Path -LiteralPath $To -PathType Container)) { return $false }
    $ContentMatches = $true
    $SourcePrefix = (Get-FullNormalizedPath $From) + [IO.Path]::DirectorySeparatorChar
    foreach ($Item in @(Get-ChildItem -LiteralPath $From -Recurse -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer })) {
        $Relative = $Item.FullName.Substring($SourcePrefix.Length)
        if (Test-ExcludedContent -Relative $Relative -IncludeFinder $IncludeFinder -IncludeDependencies $IncludeDependencies) { continue }
        $DestinationPath = Join-Path $To $Relative
        if (-not (Test-Path -LiteralPath $DestinationPath)) { $ContentMatches = $false; break }
        $DestinationItem = Get-Item -LiteralPath $DestinationPath -Force -ErrorAction Stop
        if ($Item.PSObject.Properties.Name -contains "LinkType" -and $Item.LinkType) {
            if (-not $DestinationItem.LinkType -or (@($Item.Target) -join '|') -ne (@($DestinationItem.Target) -join '|')) { $ContentMatches = $false; break }
            continue
        }
        if ($Item.Length -ne $DestinationItem.Length) { $ContentMatches = $false; break }
        if ((Get-FileHash -LiteralPath $Item.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash) { $ContentMatches = $false; break }
    }
    $GitMatches = Test-GitObjectsRepresented -From $From -To $To -IncludeGit $IncludeGit
    if ($ContentMatches -and $GitMatches) { return $true }
    return Test-VerifiedZip $Archive
}

function Test-SelectorMatch {
    param([string]$Repository, [string]$SourcePath, [string]$Destination)
    if ($Project.Count -eq 0) { return $true }
    foreach ($Selector in $Project) {
        $Key = Get-IdentityKey $Selector
        if ($Key -eq (Get-IdentityKey $Repository) -or $Key -eq (Get-IdentityKey (Split-Path $SourcePath -Leaf)) -or $Key -eq (Get-IdentityKey (Split-Path $Destination -Leaf))) { return $true }
    }
    return $false
}

function Get-Stage2ReceiptChain {
    param([string]$Stage1Destination)
    if (-not $Stage1Destination) { return $null }
    foreach ($Candidate in @($script:ReceiptPaths)) {
        $CandidateValues = Read-LifecycleReceipt $Candidate
        if ((Get-ReceiptValue $CandidateValues "stage") -ne "2") { continue }
        if (-not (Test-VerifiedReceiptStatus (Get-ReceiptValue $CandidateValues "status"))) { continue }
        if ((Get-FullNormalizedPath (Get-ReceiptValue $CandidateValues "original_source")) -ine (Get-FullNormalizedPath $Stage1Destination)) { continue }
        $CandidateDestination = Get-ReceiptValue $CandidateValues "destination"
        if (-not (Test-Path -LiteralPath $CandidateDestination -PathType Container)) { continue }
        return [pscustomobject]@{ Destination = $CandidateDestination; Archive = Get-ReceiptValue $CandidateValues "archive" }
    }
    return $null
}

function Add-Plan {
    param(
        [System.Collections.Generic.List[object]]$Plans,
        [string]$State,
        [string]$Stage,
        [string]$ReceiptPath,
        [string]$Target,
        [string]$SourcePath,
        [string]$Destination,
        [string]$Archive,
        [string]$Detail
    )
    $Key = "$State|$Target"
    if (@($Plans | Where-Object Key -eq $Key).Count -gt 0) { return }
    $Plans.Add([pscustomobject]@{ Key = $Key; State = $State; Stage = $Stage; Receipt = $ReceiptPath; Target = $Target; Source = $SourcePath; Destination = $Destination; Archive = $Archive; Detail = $Detail })
    Write-Host ("PLAN | {0,-30} | stage={1} | {2}" -f $State, $Stage, $Target)
}

function Add-ReceiptPlan {
    param([System.Collections.Generic.List[object]]$Plans, [string]$ReceiptPath)
    $Values = Read-LifecycleReceipt $ReceiptPath
    $Stage = Get-ReceiptValue $Values "stage"
    $Status = Get-ReceiptValue $Values "status"
    $Repository = Get-ReceiptValue $Values "repository" (Get-ReceiptValue $Values "project_name")
    $OriginalSource = Get-ReceiptValue $Values "original_source"
    $CurrentSource = Get-ReceiptValue $Values "current_source"
    $Destination = Get-ReceiptValue $Values "destination"
    $Archive = Get-ReceiptValue $Values "archive"
    $ImportStage = Get-ReceiptValue $Values "import_stage"
    $Quarantine = Get-ReceiptValue $Values "quarantine"
    $IncludeGit = (Get-ReceiptValue $Values "include_git" "1") -eq "1"
    $IncludeFinder = (Get-ReceiptValue $Values "include_finder" "1") -eq "1"
    $IncludeDependencies = (Get-ReceiptValue $Values "include_dependencies" "1") -eq "1"
    if (-not (Test-SelectorMatch $Repository $OriginalSource $Destination)) { return }
    if ($Stage -notin @("1", "2")) { Add-Plan $Plans "blocked-unknown-receipt" $Stage $ReceiptPath $ReceiptPath $OriginalSource $Destination $Archive "Receipt stage is not supported."; return }
    if (-not (Test-VerifiedReceiptStatus $Status)) { Add-Plan $Plans "blocked-unverified-receipt" $Stage $ReceiptPath $ReceiptPath $OriginalSource $Destination $Archive "Receipt status is $Status."; return }
    if ($Stage -eq "1" -and -not (Test-Path -LiteralPath $Destination -PathType Container)) {
        $Chain = Get-Stage2ReceiptChain $Destination
        if ($Chain) {
            $Destination = $Chain.Destination
            if (-not $Archive) { $Archive = $Chain.Archive }
        }
    }
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) { Add-Plan $Plans "blocked-destination-missing" $Stage $ReceiptPath $Destination $OriginalSource $Destination $Archive "Verified destination is unavailable."; return }
    if ((Test-ReservedProject $OriginalSource $Repository) -or (Test-ReservedProject $Destination $Repository)) { Add-Plan $Plans "blocked-active-project" $Stage $ReceiptPath $OriginalSource $OriginalSource $Destination $Archive "The active CSA-iEM project is never cleaned automatically."; return }
    $SourceCandidate = $CurrentSource
    if (-not $SourceCandidate -or -not (Test-Path -LiteralPath $SourceCandidate)) { $SourceCandidate = $OriginalSource }
    if ($Stage -eq "1" -and $DeleteStage1Originals -and (Test-Path -LiteralPath $SourceCandidate -PathType Container)) {
        if (Test-SourceRepresented $SourceCandidate $Destination $Archive $IncludeGit $IncludeFinder $IncludeDependencies) { Add-Plan $Plans "ready-delete-stage1-original" $Stage $ReceiptPath $SourceCandidate $SourceCandidate $Destination $Archive "Receipt and live source-to-destination verification passed." }
        else { Add-Plan $Plans "blocked-live-verification" $Stage $ReceiptPath $SourceCandidate $SourceCandidate $Destination $Archive "The original no longer matches the verified destination or tested ZIP." }
    }
    if ($Stage -eq "2" -and $DeleteStage2Inputs -and (Test-Path -LiteralPath $SourceCandidate -PathType Container)) {
        if ((Test-PathWithin $SourceCandidate $Source) -and (Test-SourceRepresented $SourceCandidate $Destination $Archive $true $true $true)) { Add-Plan $Plans "ready-delete-stage2-input" $Stage $ReceiptPath $SourceCandidate $SourceCandidate $Destination $Archive "Receipt and live canonical verification passed." }
        else { Add-Plan $Plans "blocked-live-verification" $Stage $ReceiptPath $SourceCandidate $SourceCandidate $Destination $Archive "The Stage 2 input is outside its source root or no longer verifies." }
    }
    if ($Stage -eq "2" -and $CleanupTransactionTemp -and $ImportStage -and (Test-Path -LiteralPath $ImportStage -PathType Container)) {
        $ImportRoot = Join-Path $ManagedRoot "Import\Stage2"
        if (Test-PathWithin $ImportStage $ImportRoot) { Add-Plan $Plans "ready-remove-stage2-temp" $Stage $ReceiptPath $ImportStage $SourceCandidate $Destination $Archive "Receipt-linked transaction staging can be removed." }
        else { Add-Plan $Plans "blocked-temp-boundary" $Stage $ReceiptPath $ImportStage $SourceCandidate $Destination $Archive "Transaction staging is outside the managed Import/Stage2 root." }
    }
    if ($Stage -eq "2" -and $CleanupTransactionTemp -and $Status -eq "source-deleted" -and $Quarantine) {
        $DeleteTransaction = Split-Path $Quarantine -Parent
        $DeleteRoot = Join-Path $Source "_temp\Stage2-Delete"
        if ((Test-Path -LiteralPath $DeleteTransaction -PathType Container) -and @(Get-ChildItem -LiteralPath $DeleteTransaction -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            if (Test-PathWithin $DeleteTransaction $DeleteRoot) { Add-Plan $Plans "ready-remove-stage2-delete-temp" $Stage $ReceiptPath $DeleteTransaction $SourceCandidate $Destination $Archive "Receipt-linked empty delete quarantine can be removed." }
            else { Add-Plan $Plans "blocked-temp-boundary" $Stage $ReceiptPath $DeleteTransaction $SourceCandidate $Destination $Archive "Delete quarantine is outside the Stage 2 source temp root." }
        }
    }
    if ($CleanupAllVerifiedTemp) {
        $IndexRoot = Join-Path $Source "_temp\Transfer-Indexes"
        foreach ($Key in @("plan", "source_index", "destination_index")) {
            $Candidate = Get-ReceiptValue $Values $Key
            if (-not $Candidate -or -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { continue }
            if (Test-PathWithin $Candidate $IndexRoot) { Add-Plan $Plans "ready-remove-stage1-index" $Stage $ReceiptPath $Candidate $SourceCandidate $Destination $Archive "Receipt-linked Stage 1 index artifact can be removed." }
            else { Add-Plan $Plans "blocked-temp-boundary" $Stage $ReceiptPath $Candidate $SourceCandidate $Destination $Archive "Index artifact is outside the Stage 1 index root." }
        }
    }
}

function Write-AuditReceipt {
    param([string]$Action, [string]$Target, [string]$SourceReceipt, [string]$Result)
    New-Item -ItemType Directory -Path $script:AuditDir -Force | Out-Null
    $Bytes = [Text.Encoding]::UTF8.GetBytes("$Action-$Target")
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { $Name = ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $Hasher.Dispose() }
    @(
        "format=1",
        "stage=3",
        "transaction=$($script:TransactionId)",
        "action=$Action",
        "target=$Target",
        "source_receipt=$SourceReceipt",
        "result=$Result",
        "completed_at=$((Get-Date).ToUniversalTime().ToString('o'))"
    ) | Set-Content -LiteralPath (Join-Path $script:AuditDir "$Name.receipt") -Encoding UTF8
}

function Remove-VerifiedSource {
    param([object]$Entry)
    $Values = Read-LifecycleReceipt $Entry.Receipt
    $IncludeGit = if ($Entry.Stage -eq "1") { (Get-ReceiptValue $Values "include_git" "1") -eq "1" } else { $true }
    $IncludeFinder = if ($Entry.Stage -eq "1") { (Get-ReceiptValue $Values "include_finder" "1") -eq "1" } else { $true }
    $IncludeDependencies = if ($Entry.Stage -eq "1") { (Get-ReceiptValue $Values "include_dependencies" "1") -eq "1" } else { $true }
    $Parent = Split-Path $Entry.Target -Parent
    $Leaf = Split-Path $Entry.Target -Leaf
    $Quarantine = Join-Path $Parent ".csa-iem-stage3-quarantine-$($script:TransactionId)-$Leaf"
    if (Test-Path -LiteralPath $Quarantine) { throw "Quarantine path already exists: $Quarantine" }
    Move-Item -LiteralPath $Entry.Target -Destination $Quarantine
    if (-not (Test-SourceRepresented $Quarantine $Entry.Destination $Entry.Archive $IncludeGit $IncludeFinder $IncludeDependencies)) {
        Move-Item -LiteralPath $Quarantine -Destination $Entry.Target -ErrorAction SilentlyContinue
        throw "The second verification failed; source cleanup was rolled back."
    }
    Remove-Item -LiteralPath $Quarantine -Recurse -Force
}

if (-not $All -and $Receipt.Count -eq 0) { throw "Choose --all or at least one --receipt." }
if (-not ($DeleteStage1Originals -or $DeleteStage2Inputs -or $CleanupTransactionTemp -or $CleanupAllVerifiedTemp)) { throw "Choose at least one Stage 3 cleanup option." }
if ($CleanupAllVerifiedTemp) { $CleanupTransactionTemp = $true }
if ($ActionName -eq "apply") {
    if ($ConfirmDelete -ne "VERIFIED-STAGE3") { throw "Stage 3 apply requires --confirm-delete VERIFIED-STAGE3." }
    if (-not $Yes) {
        $Confirmation = Read-Host "Type STAGE3 to permanently clean only receipt-verified data"
        if ($Confirmation -ne "STAGE3") { throw "Stage 3 cleanup was cancelled." }
    }
}
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Stage 1 source folder was not found: $Source" }
if (-not (Test-Path -LiteralPath $ManagedRoot -PathType Container)) { throw "Managed root was not found: $ManagedRoot" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required for Stage 3 verification." }

$Source = Get-FullNormalizedPath $Source
$ManagedRoot = Get-FullNormalizedPath $ManagedRoot
$script:TransactionId = "$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))-$PID"
$ReportsDir = Join-Path $ManagedRoot "Runtime\Reports\Stage3"
$script:AuditDir = Join-Path $ManagedRoot "Runtime\Receipts\Stage3\$($script:TransactionId)"
if (-not $Report) { $Report = Join-Path $ReportsDir "stage3-$($script:TransactionId).md" }

$ReceiptPaths = [System.Collections.Generic.List[string]]::new()
if ($All) {
    foreach ($Root in @((Join-Path $Source "_temp\Transfer-Receipts"), (Join-Path $ManagedRoot "Runtime\Receipts\Stage2"))) {
        if (-not (Test-Path -LiteralPath $Root -PathType Container)) { continue }
        foreach ($Item in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File -Filter "*.receipt" | Sort-Object FullName)) {
            if (-not $ReceiptPaths.Contains($Item.FullName)) { $ReceiptPaths.Add($Item.FullName) }
        }
    }
}
foreach ($Selector in $Receipt) {
    if (Test-Path -LiteralPath $Selector -PathType Leaf) {
        $Path = Get-FullNormalizedPath $Selector
        if (-not $ReceiptPaths.Contains($Path)) { $ReceiptPaths.Add($Path) }
        continue
    }
    foreach ($Root in @((Join-Path $Source "_temp\Transfer-Receipts"), (Join-Path $ManagedRoot "Runtime\Receipts\Stage2"))) {
        if (-not (Test-Path -LiteralPath $Root -PathType Container)) { continue }
        foreach ($Item in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File -Filter "*$Selector*.receipt")) {
            if (-not $ReceiptPaths.Contains($Item.FullName)) { $ReceiptPaths.Add($Item.FullName) }
        }
    }
}
if ($ReceiptPaths.Count -eq 0) { throw "No lifecycle receipts matched the Stage 3 selection." }
$script:ReceiptPaths = @($ReceiptPaths)

$Plans = [System.Collections.Generic.List[object]]::new()
foreach ($ReceiptPath in $ReceiptPaths) { Add-ReceiptPlan -Plans $Plans -ReceiptPath $ReceiptPath }
if ($Plans.Count -eq 0) { throw "No Stage 3 actions matched the selected receipts and project filters." }

$Applied = 0
$Skipped = 0
$Failed = 0
if ($ActionName -eq "apply") {
    $Index = 0
    foreach ($Entry in $Plans) {
        $Index++
        Write-Host "PROGRESS | $Index/$($Plans.Count) | $($Entry.State) | $($Entry.Target)"
        try {
            switch -Wildcard ($Entry.State) {
                "ready-delete-*" { Remove-VerifiedSource $Entry; Write-AuditReceipt $Entry.State $Entry.Target $Entry.Receipt "deleted"; $Applied++; break }
                "ready-remove-*" { Remove-Item -LiteralPath $Entry.Target -Recurse -Force; Write-AuditReceipt $Entry.State $Entry.Target $Entry.Receipt "deleted"; $Applied++; break }
                default { $Skipped++ }
            }
        } catch {
            Write-WarnLine "$($Entry.Target): $($_.Exception.Message)"
            $Failed++
        }
    }
}

$Ready = @($Plans | Where-Object State -like 'ready-*').Count
$Blocked = @($Plans | Where-Object State -like 'blocked-*').Count
New-Item -ItemType Directory -Path (Split-Path $Report -Parent) -Force | Out-Null
$Lines = [System.Collections.Generic.List[string]]::new()
$Lines.Add("# CSA-iEM Stage 3 Cleanup Report")
$Lines.Add("")
$Lines.Add("- Transaction: ``$($script:TransactionId)``")
$Lines.Add("- Action: ``$ActionName``")
$Lines.Add("- Stage 1 source: ``$Source``")
$Lines.Add("- Managed root: ``$ManagedRoot``")
$Lines.Add("- Plans: $($Plans.Count) total, $Ready ready, $Blocked blocked")
$Lines.Add("- Execution: $Applied applied, $Skipped skipped, $Failed failed")
$Lines.Add("")
$Lines.Add("| State | Stage | Target | Destination | Receipt | Detail |")
$Lines.Add("|---|---|---|---|---|---|")
foreach ($Entry in $Plans) { $Lines.Add("| $($Entry.State) | $($Entry.Stage) | ``$($Entry.Target)`` | ``$($Entry.Destination)`` | ``$($Entry.Receipt)`` | $($Entry.Detail) |") }
$Lines.Add("")
$Lines.Add("Stage 3 never deletes canonical repositories, backup ZIP files, reports, receipts, active CSA-iEM workspaces, failed transactions, or unreferenced temporary folders.")
$Lines | Set-Content -LiteralPath $Report -Encoding UTF8
Write-InfoLine "Stage 3 report: $Report"
Write-Host "SUMMARY | total=$($Plans.Count) ready=$Ready blocked=$Blocked applied=$Applied skipped=$Skipped failed=$Failed"
