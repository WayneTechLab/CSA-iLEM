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

    return [ordered]@{
        Install = $InstallRoot
        Code = $CodeRoot
        Import = $ImportRoot
        Runtime = $RuntimeRoot
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

    $RootsItem = [System.Windows.Forms.ToolStripMenuItem]::new("Workspace Roots")
    foreach ($Key in @("Code", "Import", "Runtime")) {
        $RootPath = [string]$Workspace[$Key]
        $CapturedRootPath = $RootPath
        [void]$RootsItem.DropDownItems.Add((New-MenuItem -Text "Open $Key Root" -OnClick { Open-CsaIemFolder -Path $CapturedRootPath }))
    }
    [void]$Menu.Items.Add($RootsItem)

    $RunnersItem = [System.Windows.Forms.ToolStripMenuItem]::new("GitHub Action Runners")
    if ($RunnerServices.Count -eq 0) {
        [void]$RunnersItem.DropDownItems.Add((New-MenuItem -Text "No actions.runner.* services detected" -Enabled $false))
    } else {
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
