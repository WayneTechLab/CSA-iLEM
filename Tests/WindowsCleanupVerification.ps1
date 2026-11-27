Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repository = Split-Path -Parent $PSScriptRoot
$TemporaryBase = [IO.Path]::GetTempPath()
if ($TemporaryBase.StartsWith('/var/')) { $TemporaryBase = '/private' + $TemporaryBase }
$Fixture = Join-Path $TemporaryBase ("csa-iem-windows-cleanup-test-" + [guid]::NewGuid().ToString('N'))
$Source = Join-Path $Fixture 'Stage 1'
$Destination = Join-Path $Fixture 'Canonical'
$RelativePath = Join-Path 'nested' 'license copy.txt'
$SourceFile = Join-Path $Source $RelativePath
$DestinationFile = Join-Path $Destination $RelativePath
$Archive = Join-Path $Fixture 'snapshot.zip'

function Assert-Result {
    param([bool]$Actual, [bool]$Expected, [string]$Description)
    if ($Actual -ne $Expected) { throw "$Description`: expected $Expected, got $Actual" }
}

if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    Set-Alias -Name 'tar.exe' -Value 'tar' -Scope Script
}

try {
    foreach ($File in @($SourceFile, $DestinationFile)) {
        New-Item -ItemType Directory -Path (Split-Path $File -Parent) -Force | Out-Null
        'preserved' | Set-Content -LiteralPath $File
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    [IO.Compression.ZipFile]::CreateFromDirectory($Source, $Archive)

    foreach ($ScriptName in @('stage2-workspace.ps1', 'stage3-cleanup.ps1')) {
        & {
            $ParseErrors = $null
            $Ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Repository $ScriptName), [ref]$null, [ref]$ParseErrors)
            if ($ParseErrors.Count -gt 0) { throw "Could not parse $ScriptName" }
            $FunctionNames = @('Test-SourceRepresented', 'Test-GitObjectsRepresented', 'Test-VerifiedZip', 'Get-FullNormalizedPath', 'Test-ExcludedContent')
            foreach ($Definition in $Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -in $FunctionNames }, $false)) {
                . ([scriptblock]::Create($Definition.Extent.Text))
            }
            Copy-Item -LiteralPath $SourceFile -Destination $DestinationFile -Force
            Assert-Result (Test-SourceRepresented -From $Source -To $Destination) $true "$ScriptName accepts a matching copy"
            Assert-Result (Test-SourceRepresented -From $Source -To $Destination -Archive $Archive) $true "$ScriptName accepts a matching copy and ZIP"
            Assert-Result (Test-SourceRepresented -From $Source -To $Destination -Archive (Join-Path $Fixture 'missing.zip')) $false "$ScriptName requires a declared ZIP to be readable"
            'different' | Set-Content -LiteralPath $DestinationFile
            Assert-Result (Test-SourceRepresented -From $Source -To $Destination -Archive $Archive) $false "$ScriptName blocks a changed nested file despite a readable ZIP"
            Remove-Item -LiteralPath $DestinationFile
            Assert-Result (Test-SourceRepresented -From $Source -To $Destination -Archive $Archive) $false "$ScriptName blocks a missing nested file despite a readable ZIP"
        }
    }
    Write-Host 'Windows cleanup canonical and ZIP verification: PASS'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force }
}
