param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $ManagerPath -LoadOnly
$CaseRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$SkillsRoot = Join-Path $CaseRoot 'skills'
$null = New-Item -ItemType Directory -Path $SkillsRoot -Force
$Entry = [pscustomobject]@{ name = 'fixture'; localFolder = 'fixture'; type = 'skills-cli'; autoUpdate = $true; repo = 'fixture/repo'; skill = 'fixture'; rawSkillUrl = 'https://raw.githubusercontent.com/fixture/repo/main/SKILL.md' }
$RoutingOverrides = @{ fixture = [pscustomobject]@{ skill = 'fixture'; codexPolicy = [pscustomobject]@{ allow_implicit_invocation = $false } } }
$LocalRoot = Join-Path $SkillsRoot 'fixture'
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
function Save-Fixture { param([string]$Relative, [string]$Text) $Path = Join-Path $LocalRoot $Relative; $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force; [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false))) }
$Text = "---`nname: fixture`ndescription: Fixture.`n---`n# Fixture`n"
$script:Snapshot = [pscustomobject]@{ Files = @{ 'SKILL.md' = (Get-PackageBytesHash -Bytes ([Text.Encoding]::UTF8.GetBytes($Text)) -RelativePath 'SKILL.md') }; EntryText = $Text; OpenAiYaml = ''; Commit = ('a' * 40) }
function Get-SkillCliSourceSnapshot { param([object]$Entry) return $script:Snapshot }
Save-Fixture 'SKILL.md' $Text
Save-Fixture 'notes/local.txt' 'user addition'
$null = Apply-RoutingOverrideToLocalSkill $Entry
Save-SkillManagedManifest $Entry
$Tracked = @{}
foreach ($File in Get-ChildItem -LiteralPath $LocalRoot -Recurse -File) { $Tracked[$File.FullName] = Get-FileHashValue $File.FullName }
foreach ($Path in @((Get-SkillManifestPath $Entry), (Get-CodexPolicyReceiptPath $Entry))) { $Tracked[$Path] = Get-FileHashValue $Path }

$script:Snapshot.OpenAiYaml = "interface:`n  display_name: New upstream label`n"
$script:Snapshot.Files['agents/openai.yaml'] = Get-PackageBytesHash -Bytes ([Text.Encoding]::UTF8.GetBytes($script:Snapshot.OpenAiYaml)) -RelativePath 'agents/openai.yaml'
$script:Snapshot.Files['scripts/new.txt'] = Get-PackageBytesHash -Bytes ([Text.Encoding]::UTF8.GetBytes('new resource')) -RelativePath 'scripts/new.txt'
function Invoke-ExternalCommand {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSec, [switch]$StreamOutput)
    Assert-Equal $FilePath 'cmd.exe' 'Only the simulated installer may run'
    Save-Fixture 'agents/openai.yaml' $script:Snapshot.OpenAiYaml
    Save-Fixture 'notes/local.txt' 'installer damaged user addition'
    Save-Fixture 'partial-install.txt' 'failed attempt'
    return [pscustomobject]@{ ExitCode = $(if ($script:FailureMode -eq 'nonzero') { 1 } else { 0 }); TimedOut = ($script:FailureMode -eq 'timeout'); Output = 'simulated result' }
}
foreach ($script:FailureMode in @('nonzero', 'timeout', 'validation')) {
    Assert-Equal (Get-SkillStatus $Entry).Status 'outdated' 'Upstream change needs update'
    $Result = Update-Skill $Entry
    Assert-Equal $Result.Action 'failed' ('Failed attempt remains visible: ' + $Result.Detail)
    Assert-Equal ($Result.Detail -match '已恢复更新前文件和客户端策略') $true ('Rollback confirmation: ' + $Result.Detail)
    foreach ($Path in $Tracked.Keys) { Assert-Equal (Get-FileHashValue $Path) $Tracked[$Path] ('Exact rollback: ' + $Path) }
    Assert-Equal (Test-Path -LiteralPath (Join-Path $LocalRoot 'partial-install.txt')) $false 'Failed-only file removed after backup'
    Assert-Equal ((Get-FileText (Join-Path $LocalRoot 'agents/openai.yaml')).Contains('allow_implicit_invocation: false')) $true 'Explicit-only policy restored'
    $Snapshots = @(Get-ChildItem -LiteralPath (Join-Path $CaseRoot 'external/skill-update-backups/fixture') -Directory)
    Assert-Equal (@($Snapshots | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'files/partial-install.txt') }).Count -gt 0) $true 'Failed state remains backed up'
    Write-Output ('PASS: ' + $script:FailureMode + ' update restores exact files, ownership and policy while preserving failed evidence')
}
Write-Output '3 update rollback scenarios passed.'
