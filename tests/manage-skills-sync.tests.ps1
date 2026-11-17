param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $ManagerPath -LoadOnly
$CaseRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$SkillsRoot = Join-Path $CaseRoot 'skills'
$Upstream = Join-Path $CaseRoot 'upstream'
$Source = Join-Path $CaseRoot 'external/fixture-source'
$LocalRoot = Join-Path $SkillsRoot 'fixture'
foreach ($Dir in @($SkillsRoot, $Upstream, (Split-Path -Parent $Source), $LocalRoot)) { $null = New-Item -ItemType Directory -Path $Dir -Force }
$RoutingOverrides = @{ fixture = [pscustomobject]@{ skill = 'fixture'; codexPolicy = [pscustomobject]@{ allow_implicit_invocation = $false } } }
$Entry = [pscustomobject]@{ name = 'fixture'; localFolder = 'fixture'; type = 'git'; autoUpdate = $true; remote = $Upstream; branch = 'main'; repositoryFolder = '../external/fixture-source'; syncSkillDirectory = 'runtime' }
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
function Write-File { param([string]$Path, [string]$Text) $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force; [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false))) }
function Git-Fixture {
    param([string]$Path, [string[]]$GitArgs)
    $Result = Invoke-ExternalCommand -FilePath git -Arguments (@('-C', $Path, '-c', 'user.name=SkillRegression', '-c', 'user.email=skills-regression@example.invalid', '-c', 'commit.gpgsign=false', '-c', 'core.autocrlf=false') + $GitArgs) -TimeoutSec 30
    if ($Result.ExitCode -ne 0 -or $Result.TimedOut) { throw $Result.Output }
}
Git-Fixture $Upstream @('init', '--initial-branch=main')
Write-File (Join-Path $Upstream 'runtime/SKILL.md') "---`nname: fixture`ndescription: Regression fixture.`n---`n# Fixture`n"
Write-File (Join-Path $Upstream 'runtime/scripts/old.txt') 'upstream old file'
Write-File (Join-Path $Upstream 'runtime/agents/openai.yaml') "interface:`n  display_name: Initial label`n"
Git-Fixture $Upstream @('add', '.')
Git-Fixture $Upstream @('commit', '-m', 'Initial-runtime')
Git-Fixture $CaseRoot @('clone', '--quiet', $Upstream, $Source)
$null = Sync-LocalSkillDirectory $Entry
$null = Apply-RoutingOverrideToLocalSkill $Entry
Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Initial clone and runtime agree'
Assert-Equal (Update-Skill $Entry).Action 'unchanged' 'Verified initial runtime is adopted without pull'
$ManifestPath = Get-SkillManifestPath $Entry
Assert-Equal (Test-Path -LiteralPath $ManifestPath) $true 'Verified synced runtime records ownership'
Write-Output 'PASS: real local Git runtime is adopted only after a successful check'

Write-File (Join-Path $LocalRoot 'my-notes.txt') 'unmanaged local addition'
Git-Fixture $Upstream @('rm', 'runtime/scripts/old.txt')
Write-File (Join-Path $Upstream 'runtime/scripts/current.txt') 'upstream replacement'
Write-File (Join-Path $Upstream 'runtime/agents/openai.yaml') "interface:`n  display_name: New label`n"
Git-Fixture $Upstream @('add', '.')
Git-Fixture $Upstream @('commit', '-m', 'Replace-upstream-runtime-file')
$Result = Update-Skill $Entry
Assert-Equal $Result.Action 'updated' ('Real pull and prune: ' + $Result.Detail)
Assert-Equal (Test-Path -LiteralPath (Join-Path $LocalRoot 'scripts/old.txt')) $false 'Deleted upstream file is pruned'
Assert-Equal ([IO.File]::ReadAllText((Join-Path $LocalRoot 'my-notes.txt'))) 'unmanaged local addition' 'Unknown addition survives'
Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Prune completes to a healthy runtime'
Assert-Equal (Test-CodexSkillPolicy $Entry) $true 'Synced Git policy survives update'
Assert-Equal ((Get-FileText (Join-Path $LocalRoot 'agents/openai.yaml')).Contains('New label')) $true 'Synced Git metadata updates with policy'
Assert-Equal ((Get-FileText (Join-Path $Source 'runtime/agents/openai.yaml')).Contains('allow_implicit_invocation')) $false 'Runtime policy does not change source YAML'
Write-Output 'PASS: real git pull copies additions, prunes only owned deletions and preserves local additions'

Write-File (Join-Path $Upstream 'runtime/scripts/retired.txt') 'original retired bytes'
Git-Fixture $Upstream @('add', '.')
Git-Fixture $Upstream @('commit', '-m', 'Add-managed-file')
Assert-Equal (Update-Skill $Entry).Action 'updated' 'Add later-owned file'
Write-File (Join-Path $LocalRoot 'scripts/retired.txt') 'user edited this file'
Git-Fixture $Upstream @('rm', 'runtime/scripts/retired.txt')
Git-Fixture $Upstream @('commit', '-m', 'Remove-locally-edited-file')
$Result = Update-Skill $Entry
Assert-Equal $Result.Action 'failed' 'Locally modified upstream deletion blocks after pull'
if ($Result.Detail -notmatch 'local changes; preserved') { throw $Result.Detail }
Assert-Equal ([IO.File]::ReadAllText((Join-Path $LocalRoot 'scripts/retired.txt'))) 'user edited this file' 'Edited file is preserved'
Assert-Equal (Get-SkillStatus $Entry).Status 'error' 'Conflict remains visible on subsequent checks'
Write-Output 'PASS: an upstream deletion discovered after pull cannot delete a local edit'

Write-File (Join-Path $LocalRoot 'scripts/retired.txt') 'original retired bytes'
Assert-Equal (Update-Skill $Entry).Action 'updated' 'Confirmed original bytes allow a later prune'
Assert-Equal (Test-Path -LiteralPath (Join-Path $LocalRoot 'scripts/retired.txt')) $false 'Resolved deletion pruned'
$StateHash = Get-FileHashValue $ManifestPath
Assert-Equal (Update-Skill $Entry).Action 'unchanged' 'Completed update is idempotent'
Assert-Equal (Get-FileHashValue $ManifestPath) $StateHash 'Idempotent update preserves ownership bytes'
Write-Output 'PASS: a resolved conflict can be retried and the completed update is idempotent'
Write-Output '4 Git integration scenarios passed.'
