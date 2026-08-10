Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppName = "CSA-iEM"
$InstallRoot = if ($env:CSA_IEM_ROOT) { $env:CSA_IEM_ROOT } else { $ScriptDir }
$CliScript = Join-Path $InstallRoot "CSA-iEM.ps1"

function Get-CsaIemWorkspaceSummary {
    $LocalRoot = Join-Path $env:USERPROFILE "CSA-iEM"
    $CodeRoot = Join-Path $LocalRoot "Code"
    $ImportRoot = Join-Path $LocalRoot "Import"
    $RuntimeRoot = Join-Path $LocalRoot "Runtime"
    $SettingsPath = Join-Path (Join-Path $env:LOCALAPPDATA "CSA-iEM") "windows-settings.json"

    if (Test-Path $SettingsPath) {
        try {
            $Settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json
            if ($Settings.CodeRoot) { $CodeRoot = [string]$Settings.CodeRoot }
            if ($Settings.ImportRoot) { $ImportRoot = [string]$Settings.ImportRoot }
            if ($Settings.RuntimeRoot) { $RuntimeRoot = [string]$Settings.RuntimeRoot }
        } catch { }
    }

    $ManagedRoot = Split-Path $CodeRoot -Parent
    $Stage2Source = if ((Split-Path $ManagedRoot -Leaf) -eq "CSA-iEM") {
        Join-Path (Split-Path $ManagedRoot -Parent) "CODEX PROJECTS"
    } else {
        Join-Path $env:USERPROFILE "CODEX PROJECTS"
    }

    return [ordered]@{
        Install = $InstallRoot
        Code = $CodeRoot
        Import = $ImportRoot
        Runtime = $RuntimeRoot
        Stage2Source = $Stage2Source
        ManagedRoot = $ManagedRoot
    }
}

function Start-CsaIemPowerShell {
    param([string[]]$Arguments = @())

    $ArgumentList = @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$CliScript`""
    ) + $Arguments

    Start-Process -FilePath "powershell.exe" -ArgumentList $ArgumentList | Out-Null
}

function Open-CsaIemFolder {
    param([string]$Path)

    if (Test-Path $Path) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$Path`"" | Out-Null
    }
}

function Get-GitHubRunnerServices {
    Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue |
        Sort-Object -Property DisplayName
}

function Get-GitHubBillingSummary {
    $Default = [ordered]@{
        Account = "GitHub login required"
        Actions = "Usage unavailable"
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        $Default.Account = "GitHub CLI not installed"
        return $Default
    }

    try {
        $Account = (& gh api user --jq ".login" 2>$null).Trim()
        if (-not $Account) { return $Default }
        $Default.Account = $Account
        $Actions = & gh api "user/settings/billing/actions" 2>$null | ConvertFrom-Json
        if ($Actions -and $null -ne $Actions.total_minutes_used) {
            $Paid = if ($null -ne $Actions.total_paid_minutes_used) { " · paid $($Actions.total_paid_minutes_used)" } else { "" }
            $Default.Actions = "$($Actions.total_minutes_used) Actions min$Paid"
        } else {
            $Default.Actions = "Open GitHub Billing for usage"
        }
    } catch {
        $Default.Actions = "Open GitHub Billing for usage"
    }

    return $Default
}

function Open-GitHubBilling {
    Start-Process -FilePath "https://github.com/settings/billing" | Out-Null
}

function Invoke-RunnerServiceAction {
    param(
        [System.ServiceProcess.ServiceController]$Service,
        [ValidateSet("Start", "Stop", "Restart")]
        [string]$Action
    )

    try {
        switch ($Action) {
            "Start" {
                if ($Service.Status -ne "Running") {
                    Start-Service -Name $Service.Name
                }
            }
            "Stop" {
                if ($Service.Status -ne "Stopped") {
                    Stop-Service -Name $Service.Name
                }
            }
            "Restart" {
                if ($Service.Status -ne "Stopped") {
                    Stop-Service -Name $Service.Name
                    $Service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(20))
                }
                Start-Service -Name $Service.Name
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not $($Action.ToLowerInvariant()) $($Service.DisplayName).`n`n$($_.Exception.Message)",
            "$AppName Runner Control",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
}

function New-MenuItem {
    param(
        [string]$Text,
        [scriptblock]$OnClick,
        [bool]$Enabled = $true
    )

    $Item = [System.Windows.Forms.ToolStripMenuItem]::new($Text)
    $Item.Enabled = $Enabled
    if ($OnClick) {
        $Item.Add_Click($OnClick)
    }
    return $Item
}

function Build-CsaIemContextMenu {
    param([System.Windows.Forms.NotifyIcon]$NotifyIcon)

    $Menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $Workspace = Get-CsaIemWorkspaceSummary
    $RunnerServices = @(Get-GitHubRunnerServices)
    $RunningCount = @($RunnerServices | Where-Object { $_.Status -eq "Running" }).Count
    $Billing = Get-GitHubBillingSummary

    [void]$Menu.Items.Add((New-MenuItem -Text "Loaded Workspace" -Enabled $false))
    [void]$Menu.Items.Add((New-MenuItem -Text "Install: $($Workspace.Install)" -Enabled $false))
    [void]$Menu.Items.Add((New-MenuItem -Text "Code: $($Workspace.Code)" -Enabled $false))
    [void]$Menu.Items.Add((New-MenuItem -Text "Import: $($Workspace.Import)" -Enabled $false))
    [void]$Menu.Items.Add((New-MenuItem -Text "Runtime: $($Workspace.Runtime)" -Enabled $false))
    [void]$Menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())
    [void]$Menu.Items.Add((New-MenuItem -Text "$RunningCount/$($RunnerServices.Count) GitHub Action runners running" -Enabled $false))
    [void]$Menu.Items.Add((New-MenuItem -Text "Open CSA-iEM CLI" -OnClick { Start-CsaIemPowerShell }))
    [void]$Menu.Items.Add((New-MenuItem -Text "Open Project Browser" -OnClick { Start-CsaIemPowerShell -Arguments @("--browse-projects", "--use-current-root") }))
    [void]$Menu.Items.Add((New-MenuItem -Text "Reveal Install Folder" -OnClick { Open-CsaIemFolder -Path $InstallRoot }))

    $Stage2Item = [System.Windows.Forms.ToolStripMenuItem]::new("CODEX ~ GPT Stage 2")
    [void]$Stage2Item.DropDownItems.Add((New-MenuItem -Text "Source: $($Workspace.Stage2Source)" -Enabled $false))
    [void]$Stage2Item.DropDownItems.Add((New-MenuItem -Text "Root: $($Workspace.ManagedRoot)" -Enabled $false))
    [void]$Stage2Item.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new())
    $Stage2Payload = [pscustomobject]@{ Source = [string]$Workspace.Stage2Source; Root = [string]$Workspace.ManagedRoot }
    $Stage2PreflightItem = New-MenuItem -Text "Preflight All" -OnClick {
        param($Sender)
        $Payload = $Sender.Tag
        Start-CsaIemPowerShell -Arguments @("stage2", "--source", "`"$($Payload.Source)`"", "--managed-root", "`"$($Payload.Root)`"", "--preflight", "--all")
    }
    $Stage2PreflightItem.Tag = $Stage2Payload
    [void]$Stage2Item.DropDownItems.Add($Stage2PreflightItem)
    $Stage2FullAutoItem = New-MenuItem -Text "Stage 2 Full Auto" -OnClick {
        param($Sender)
        $Payload = $Sender.Tag
        $Choice = [System.Windows.Forms.MessageBox]::Show(
            "Run Stage 2 Full Auto? Dirty, staged, divergent, ambiguous, archived, and active projects remain blocked. Stage 1 folders stay in place.",
            "$AppName Stage 2",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($Choice -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-CsaIemPowerShell -Arguments @("stage2", "--source", "`"$($Payload.Source)`"", "--managed-root", "`"$($Payload.Root)`"", "--full-auto", "--yes")
        }
    }
    $Stage2FullAutoItem.Tag = $Stage2Payload
    [void]$Stage2Item.DropDownItems.Add($Stage2FullAutoItem)
    [void]$Stage2Item.DropDownItems.Add((New-MenuItem -Text "Open Stage 2 CLI" -OnClick { Start-CsaIemPowerShell -Arguments @("stage2", "--help") }))
    [void]$Stage2Item.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new())
    $OpenStage2SourceItem = New-MenuItem -Text "Open Stage 1 Source" -OnClick { param($Sender) Open-CsaIemFolder -Path ([string]$Sender.Tag) }
    $OpenStage2SourceItem.Tag = [string]$Workspace.Stage2Source
    [void]$Stage2Item.DropDownItems.Add($OpenStage2SourceItem)
    $OpenStage2RootItem = New-MenuItem -Text "Open Managed Root" -OnClick { param($Sender) Open-CsaIemFolder -Path ([string]$Sender.Tag) }
    $OpenStage2RootItem.Tag = [string]$Workspace.ManagedRoot
    [void]$Stage2Item.DropDownItems.Add($OpenStage2RootItem)
    [void]$Menu.Items.Add($Stage2Item)

    $Stage3Item = [System.Windows.Forms.ToolStripMenuItem]::new("CODEX ~ GPT Stage 3")
    [void]$Stage3Item.DropDownItems.Add((New-MenuItem -Text "Receipt source: $($Workspace.Stage2Source)" -Enabled $false))
    [void]$Stage3Item.DropDownItems.Add((New-MenuItem -Text "Managed root: $($Workspace.ManagedRoot)" -Enabled $false))
    [void]$Stage3Item.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new())
    $Stage3Payload = [pscustomobject]@{ Source = [string]$Workspace.Stage2Source; Root = [string]$Workspace.ManagedRoot }
    $Stage3PreflightItem = New-MenuItem -Text "Preflight Verified Temp Cleanup" -OnClick {
        param($Sender)
        $Payload = $Sender.Tag
        Start-CsaIemPowerShell -Arguments @("stage3", "--source", "`"$($Payload.Source)`"", "--managed-root", "`"$($Payload.Root)`"", "--preflight", "--all", "--cleanup-all-verified-temp")
    }
    $Stage3PreflightItem.Tag = $Stage3Payload
    [void]$Stage3Item.DropDownItems.Add($Stage3PreflightItem)
    $Stage3TempItem = New-MenuItem -Text "Clean Receipt-Linked Temp" -OnClick {
        param($Sender)
        $Payload = $Sender.Tag
        $Choice = [System.Windows.Forms.MessageBox]::Show(
            "Delete only receipt-linked Stage 1 indexes and Stage 2 transaction data? Backups, reports, receipts, canonical repositories, and unreferenced temp folders stay protected.",
            "$AppName Stage 3",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($Choice -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-CsaIemPowerShell -Arguments @("stage3", "--source", "`"$($Payload.Source)`"", "--managed-root", "`"$($Payload.Root)`"", "--apply", "--all", "--cleanup-all-verified-temp", "--yes", "--confirm-delete", "VERIFIED-STAGE3")
        }
    }
    $Stage3TempItem.Tag = $Stage3Payload
    [void]$Stage3Item.DropDownItems.Add($Stage3TempItem)
    $Stage3FullItem = New-MenuItem -Text "Full Verified Source + Temp Cleanup" -OnClick {
        param($Sender)
        $Payload = $Sender.Tag
        $First = [System.Windows.Forms.MessageBox]::Show(
            "This can permanently delete receipt-verified Stage 1 originals, Stage 2 inputs, and linked temporary data after live verification. Continue to the second confirmation?",
            "$AppName Stage 3",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($First -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $Second = [System.Windows.Forms.MessageBox]::Show(
            "Final confirmation: run Stage 3 Full Verified Cleanup now?",
            "$AppName Stage 3 Final Confirmation",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Stop
        )
        if ($Second -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-CsaIemPowerShell -Arguments @("stage3", "--source", "`"$($Payload.Source)`"", "--managed-root", "`"$($Payload.Root)`"", "--apply", "--all", "--delete-stage1-originals", "--delete-stage2-inputs", "--cleanup-all-verified-temp", "--yes", "--confirm-delete", "VERIFIED-STAGE3")
        }
    }
    $Stage3FullItem.Tag = $Stage3Payload
    [void]$Stage3Item.DropDownItems.Add($Stage3FullItem)
    [void]$Stage3Item.DropDownItems.Add((New-MenuItem -Text "Open Stage 3 CLI" -OnClick { Start-CsaIemPowerShell -Arguments @("stage3", "--help") }))
    [void]$Menu.Items.Add($Stage3Item)

    $BillingItem = [System.Windows.Forms.ToolStripMenuItem]::new("GitHub Billing")
    [void]$BillingItem.DropDownItems.Add((New-MenuItem -Text "$($Billing.Account): $($Billing.Actions)" -Enabled $false))
    [void]$BillingItem.DropDownItems.Add((New-MenuItem -Text "Open GitHub Billing Report" -OnClick { Open-GitHubBilling }))
    [void]$BillingItem.DropDownItems.Add((New-MenuItem -Text "Open CSA-iEM Billing Reports" -OnClick { Start-CsaIemPowerShell -Arguments @("--billing-report", "--use-current-root") }))
    [void]$Menu.Items.Add($BillingItem)

    $RootsItem = [System.Windows.Forms.ToolStripMenuItem]::new("Workspace Roots")
    foreach ($Key in @("Code", "Import", "Runtime")) {
        $RootPath = [string]$Workspace[$Key]
        $CapturedRootPath = $RootPath
        [void]$RootsItem.DropDownItems.Add((New-MenuItem -Text "Open $Key Root" -OnClick { Open-CsaIemFolder -Path $CapturedRootPath }))
    }
    [void]$Menu.Items.Add($RootsItem)

    $ExternalItem = [System.Windows.Forms.ToolStripMenuItem]::new("External Drives")
    [void]$ExternalItem.DropDownItems.Add((New-MenuItem -Text "List External Drives" -OnClick { Start-CsaIemPowerShell -Arguments @("--list-external-drives") }))
    [void]$ExternalItem.DropDownItems.Add((New-MenuItem -Text "Open External Drive Command Help" -OnClick { Start-CsaIemPowerShell -Arguments @("--help") }))
    [void]$ExternalItem.DropDownItems.Add((New-MenuItem -Text "Restore Internal Default Paths" -OnClick { Start-CsaIemPowerShell -Arguments @("--restore-internal-default") }))
    [void]$Menu.Items.Add($ExternalItem)

    $RunnersItem = [System.Windows.Forms.ToolStripMenuItem]::new("GitHub Action Runners")
    if ($RunnerServices.Count -eq 0) {
        [void]$RunnersItem.DropDownItems.Add((New-MenuItem -Text "No actions.runner.* services detected" -Enabled $false))
    } else {
        [void]$RunnersItem.DropDownItems.Add((New-MenuItem -Text "Stop All Active Runners" -OnClick {
            Get-GitHubRunnerServices | Where-Object { $_.Status -eq "Running" } | ForEach-Object { Stop-Service -Name $_.Name -ErrorAction SilentlyContinue }
            $NotifyIcon.ContextMenuStrip = Build-CsaIemContextMenu -NotifyIcon $NotifyIcon
        }))
        [void]$RunnersItem.DropDownItems.Add([System.Windows.Forms.ToolStripSeparator]::new())
        foreach ($Service in $RunnerServices) {
            $ServiceItem = [System.Windows.Forms.ToolStripMenuItem]::new("$($Service.DisplayName) ($($Service.Status))")
            $StartItem = New-MenuItem -Text "Start" -OnClick {
                param($Sender)
                Invoke-RunnerServiceAction -Service (Get-Service -Name ([string]$Sender.Tag)) -Action "Start"
                $NotifyIcon.ContextMenuStrip = Build-CsaIemContextMenu -NotifyIcon $NotifyIcon
            }
            $StopItem = New-MenuItem -Text "Stop" -OnClick {
                param($Sender)
                Invoke-RunnerServiceAction -Service (Get-Service -Name ([string]$Sender.Tag)) -Action "Stop"
                $NotifyIcon.ContextMenuStrip = Build-CsaIemContextMenu -NotifyIcon $NotifyIcon
            }
            $RestartItem = New-MenuItem -Text "Restart" -OnClick {
                param($Sender)
                Invoke-RunnerServiceAction -Service (Get-Service -Name ([string]$Sender.Tag)) -Action "Restart"
                $NotifyIcon.ContextMenuStrip = Build-CsaIemContextMenu -NotifyIcon $NotifyIcon
            }
            $StartItem.Tag = $Service.Name
            $StopItem.Tag = $Service.Name
            $RestartItem.Tag = $Service.Name
            [void]$ServiceItem.DropDownItems.Add($StartItem)
            [void]$ServiceItem.DropDownItems.Add($StopItem)
            [void]$ServiceItem.DropDownItems.Add($RestartItem)
            [void]$RunnersItem.DropDownItems.Add($ServiceItem)
        }
    }
    [void]$Menu.Items.Add($RunnersItem)

    [void]$Menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())
    [void]$Menu.Items.Add((New-MenuItem -Text "Refresh" -OnClick { $NotifyIcon.ContextMenuStrip = Build-CsaIemContextMenu -NotifyIcon $NotifyIcon }))
    [void]$Menu.Items.Add((New-MenuItem -Text "Exit Toolbar" -OnClick {
        $NotifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    }))

    return $Menu
}

$NotifyIcon = [System.Windows.Forms.NotifyIcon]::new()
$NotifyIcon.Text = "$AppName Toolbar"
$NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$NotifyIcon.Visible = $true
$NotifyIcon.ContextMenuStrip = Build-CsaIemContextMenu -NotifyIcon $NotifyIcon
$NotifyIcon.Add_DoubleClick({ Start-CsaIemPowerShell })

[System.Windows.Forms.Application]::Run()
