param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$UpdaterPath = Join-Path (Split-Path -Parent $ManagerPath) 'auto-update-skills.ps1'
$Code = [IO.File]::ReadAllText($UpdaterPath)
$Tokens = $null; $Errors = $null
$Ast = [Management.Automation.Language.Parser]::ParseFile($UpdaterPath, [ref]$Tokens, [ref]$Errors)
if ($Errors.Count) { throw ($Errors | Out-String) }
$Stubs = @{
    'Invoke-Step' = @'
function Invoke-Step {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSec)
    if ($FilePath -ne 'powershell.exe') { throw ('Unexpected external command: ' + $FilePath) }
    [ordered]@{ FilePath = $FilePath; Arguments = $Arguments } | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $ScriptRoot 'calls.jsonl') -Encoding UTF8
    return [pscustomobject]@{ ExitCode = 0; Output = 'fixture validation succeeded'; TimedOut = $false }
}
'@
    'Repair-GitCache' = @'
function Repair-GitCache {
    param([string]$CacheDir, [string]$RepoUrl, [string]$Branch, [int]$GitTimeoutSec)
    Add-Content -LiteralPath (Join-Path $ScriptRoot 'repair-calls.txt') -Value 'repair' -Encoding UTF8
    return [pscustomobject]@{ Ok = $true; Actions = @('fixture cache ready'); Output = '' }
}
'@
}
$Definitions = @($Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -in @('Invoke-Step', 'Repair-GitCache') }, $false) | Sort-Object { $_.Extent.StartOffset } -Descending)
if ($Definitions.Count -ne 2) { throw 'Cannot isolate updater transports' }
foreach ($Definition in $Definitions) { $Code = $Code.Remove($Definition.Extent.StartOffset, $Definition.Extent.EndOffset - $Definition.Extent.StartOffset).Insert($Definition.Extent.StartOffset, $Stubs[$Definition.Name]) }
$OldRoot = '$ExternalRoot = Join-Path ([Environment]::GetFolderPath(''UserProfile'')) ''.agents\external'''
if (-not $Code.Contains($OldRoot)) { throw 'Cannot isolate updater cache path' }
$Code = $Code.Replace($OldRoot, '$ExternalRoot = Join-Path $ScriptRoot ''external''')
$Code = $Code.Replace('Global\AgentsSkillsAutoUpdate', ('Local\SkillsNoCacheTest-' + [guid]::NewGuid().ToString('N')))
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
foreach ($Case in @('dryrun-existing', 'apply-existing', 'dryrun-missing', 'normal-preview', 'fallback-existing')) {
    $CaseRoot = Join-Path $WorkRoot ($Case + '-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $CaseRoot -Force
    [IO.File]::WriteAllText((Join-Path $CaseRoot 'auto-update-skills.ps1'), $Code, (New-Object Text.UTF8Encoding($true)))
    [IO.File]::WriteAllText((Join-Path $CaseRoot 'update-impeccable.ps1'), '# simulated subprocess; transport captured by test')
    $null = New-Item -ItemType Directory -Path (Join-Path $CaseRoot 'impeccable')
    [IO.File]::WriteAllText((Join-Path $CaseRoot 'impeccable/SKILL.md'), 'active marker')
    $Cache = Join-Path $CaseRoot 'external/impeccable-upstream'
    $Source = if ($Case -eq 'fallback-existing') { Join-Path $Cache 'moved/impeccable' } else { Join-Path $Cache '.agents/skills/impeccable' }
    if ($Case -ne 'dryrun-missing') {
        foreach ($Part in @('reference', 'scripts', 'agents')) { $null = New-Item -ItemType Directory -Path (Join-Path $Source $Part) -Force }
        [IO.File]::WriteAllText((Join-Path $Source 'SKILL.md'), 'source marker')
    }
    $ArgsList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $CaseRoot 'auto-update-skills.ps1'), '-ImpeccableOnly', '-NoNotify', '-NoAttentionFlag')
    if ($Case -ne 'apply-existing') { $ArgsList += '-DryRun' }
    if ($Case -ne 'normal-preview') { $ArgsList += '-NoCacheRepair' }
    & powershell.exe @ArgsList > (Join-Path $CaseRoot 'run.log') 2>&1
    $ActualExit = $LASTEXITCODE
    $ExpectedExit = if ($Case -eq 'dryrun-missing') { 1 } else { 0 }
    Assert-Equal $ActualExit $ExpectedExit ($Case + ': process exit; see ' + (Join-Path $CaseRoot 'run.log'))
    $CallsPath = Join-Path $CaseRoot 'calls.jsonl'
    $Calls = @(if (Test-Path -LiteralPath $CallsPath) { Get-Content -LiteralPath $CallsPath | ForEach-Object { $_ | ConvertFrom-Json } })
    $ExpectedCalls = if ($Case -eq 'dryrun-missing') { 0 } elseif ($Case -eq 'apply-existing') { 2 } else { 1 }
    Assert-Equal $Calls.Count $ExpectedCalls ($Case + ': subprocess count')
    Assert-Equal (Test-Path -LiteralPath (Join-Path $CaseRoot 'repair-calls.txt')) ($Case -eq 'normal-preview') ($Case + ': cache repair invocation')
    foreach ($Call in $Calls) {
        if ($Case -eq 'normal-preview') {
            Assert-Equal ($Call.Arguments -contains '-SkipFetch') $true 'Normal preview must reuse the already repaired revision'
        }
        else {
            $SourceIndex = [Array]::IndexOf($Call.Arguments, '-SourcePath')
            if ($SourceIndex -lt 0) { throw "$Case`: child updater must receive SourcePath" }
            Assert-Equal $Call.Arguments[$SourceIndex + 1] $Source ($Case + ': resolved source forwarded to child')
        }
    }
    if ($Case -eq 'dryrun-missing') { Assert-Equal (Test-Path -LiteralPath $Cache) $false 'Missing no-repair cache must not be cloned' }
    else { Assert-Equal ([IO.File]::ReadAllText((Join-Path $Source 'SKILL.md'))) 'source marker' 'Source bytes preserved' }
    Write-Output "PASS: $Case has the correct preview/apply arguments and cache behavior"
}
Write-Output '5 NoCacheRepair integration scenarios passed.'
