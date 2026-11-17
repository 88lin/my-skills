param(
    [Parameter(Mandatory = $true)][string]$ManagerPath,
    [Parameter(Mandatory = $true)][string]$WorkRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load only the manager's real functions. Never run its network-facing main.
$Tokens = $null
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile($ManagerPath, [ref]$Tokens, [ref]$ParseErrors)
if ($ParseErrors.Count -gt 0) { throw ($ParseErrors | Out-String) }
foreach ($Definition in $Ast.FindAll({ param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([scriptblock]::Create($Definition.Extent.Text))
}

. (Join-Path (Split-Path -Parent $ManagerPath) 'skill-package-state.ps1')
. (Join-Path (Split-Path -Parent $ManagerPath) 'skill-client-policy.ps1')
. (Join-Path (Split-Path -Parent $ManagerPath) 'skill-upstream-watch.ps1')

$SkillsRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$FolderPath = Join-Path $SkillsRoot 'fixture'
$null = New-Item -ItemType Directory -Path $FolderPath -Force
$SkillPath = Join-Path $FolderPath 'SKILL.md'
$RoutingOverrideStart = '<!-- LOCAL ROUTING OVERRIDE START -->'
$RoutingOverrideEnd = '<!-- LOCAL ROUTING OVERRIDE END -->'
$script:CurrentApplyMissingPatches = @()
$RoutingOverrides = @{
    fixture = [pscustomobject]@{
        skill = 'fixture'
        localFolder = 'fixture'
        description = 'Local runtime verification.'
        usageRule = "## Usage Rule`n`nUse the local test browser."
    }
}
$Entry = [pscustomobject]@{
    name = 'fixture'
    localFolder = 'fixture'
    type = 'git'
    autoUpdate = $true
    remote = 'test-only-remote'
    branch = 'main'
}
$script:RemoteHead = '1111111111111111111111111111111111111111'
$script:Dirty = ''
$script:PullCalls = 0

# Stub only Git/network transport; routing/check/update logic is production code.
function Invoke-Git {
    param([string]$Path, [string[]]$Arguments)
    switch ($Arguments[0]) {
        'rev-parse' { return [pscustomobject]@{ ExitCode = 0; Output = '1111111111111111111111111111111111111111' } }
        'status' { return [pscustomobject]@{ ExitCode = 0; Output = $script:Dirty } }
        'pull' { $script:PullCalls++; throw 'Unexpected pull against fixture' }
        default { throw "Unexpected Git command: $Arguments" }
    }
}
function Get-GitRemoteHead { param([string]$Remote, [string]$Branch) return $script:RemoteHead }
function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" }
}
function Save-Skill { param([string]$Text) [System.IO.File]::WriteAllText($SkillPath, $Text, (New-Object System.Text.UTF8Encoding($false))) }

$Original = "---`nname: fixture`ndescription: Upstream description.`nmetadata:`n  version: '1.0'`n---`n`n# Fixture`n`nKeep this upstream body.`n"
Save-Skill $Original

$Result = Get-SkillStatus -Entry $Entry
Assert-Equal $Result.Status 'outdated' 'Matching Git HEAD must not hide missing routing'
if ($Result.Detail -notmatch 'apply-overrides -Only fixture') { throw 'Missing actionable override repair hint' }
Assert-Equal ([System.IO.File]::ReadAllText($SkillPath)) $Original 'Check must not mutate local skill'
Write-Output 'PASS: same commit with missing override is outdated and check is read-only'

$null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
$Applied = [System.IO.File]::ReadAllText($SkillPath)
Assert-Equal (Get-SkillStatus -Entry $Entry).Status 'up-to-date' 'Applied routing must be healthy'
if (-not $Applied.Contains("metadata:`n  version: '1.0'")) { throw 'Unrelated metadata changed' }
if (-not $Applied.Contains('# Fixture')) { throw 'Upstream body lost' }
Assert-Equal (Apply-RoutingOverrideToLocalSkill -Entry $Entry) $false 'Second apply must be idempotent'
Assert-Equal ([System.IO.File]::ReadAllText($SkillPath)) $Applied 'Second apply must preserve bytes'
Write-Output 'PASS: applying routing repairs status, preserves metadata/body, and is idempotent'

Save-Skill ($Applied.Replace('Local runtime verification.', 'Stale description.'))
Assert-Equal (Get-SkillStatus -Entry $Entry).Status 'outdated' 'Description drift must be detected'
Write-Output 'PASS: description drift is detected at the same commit'

Save-Skill ($Applied.Replace('Use the local test browser.', 'Stale workflow.'))
Assert-Equal (Get-SkillStatus -Entry $Entry).Status 'outdated' 'Usage Rule drift must be detected'
Write-Output 'PASS: Usage Rule drift is detected at the same commit'

Save-Skill $Applied
$script:Dirty = ' M scripts/existing-local-fix.mjs'
$Result = Get-SkillStatus -Entry $Entry
Assert-Equal $Result.Status 'up-to-date' 'Existing dirty-worktree status behavior must be preserved'
if ($Result.Detail -notmatch 'local changes present') { throw 'Existing local-change evidence lost' }
$script:RemoteHead = '2222222222222222222222222222222222222222'
$BeforeHash = Get-FileHashValue -Path $SkillPath
$Result = Update-Skill -Entry $Entry
Assert-Equal $Result.Status 'error' 'Dirty Git worktree must still block updates'
Assert-Equal $script:PullCalls 0 'Protected worktree must never reach pull'
Assert-Equal (Get-FileHashValue -Path $SkillPath) $BeforeHash 'Blocked update must preserve local routing'
Write-Output 'PASS: existing local patches remain visible and block pull without mutation'

$RoutingOverrides = @{}
$script:Dirty = ''
$script:RemoteHead = '1111111111111111111111111111111111111111'
Save-Skill $Original
Assert-Equal (Get-SkillStatus -Entry $Entry).Status 'up-to-date' 'Skills without overrides retain existing behavior'
Write-Output 'PASS: Git skills without overrides retain existing behavior'

$RoutingOverrides = @{ fixture = [pscustomobject]@{ skill = 'fixture'; localFolder = 'fixture'; description = 'Local runtime verification.' } }
[System.IO.File]::Move($SkillPath, (Join-Path $FolderPath 'missing-skill.fixture'))
Assert-Equal (Get-SkillStatus -Entry $Entry).Status 'error' 'Missing local entry with an override must not pass'
Write-Output 'PASS: missing local entry is reported as an error'
Write-Output '7 routing regression scenarios passed.'
