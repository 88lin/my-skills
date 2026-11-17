param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $ManagerPath -LoadOnly
$CaseRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$SkillsRoot = Join-Path $CaseRoot 'skills'
$null = New-Item -ItemType Directory -Path $SkillsRoot -Force
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
function Save-Fixture { param([string]$Path, [string]$Text) $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force; [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false))) }
function Git-Fixture {
    param([string]$Path, [string[]]$GitArgs)
    $Result = Invoke-ExternalCommand -FilePath git -Arguments (@('-C', $Path, '-c', 'user.name=SkillRegression', '-c', 'user.email=skills-regression@example.invalid', '-c', 'commit.gpgsign=false', '-c', 'core.autocrlf=false') + $GitArgs) -TimeoutSec 30
    if ($Result.ExitCode -ne 0 -or $Result.TimedOut) { throw $Result.Output }
}
$Policy = [pscustomobject]@{ allow_implicit_invocation = $false }
$Yaml = "interface:`n  display_name: `"Example`"`n  default_prompt: |`n    Keep the prompt.`npolicy:`n  allow_implicit_invocation: true # keep this comment`n  other_setting: false`ndependencies:`n  tools: []`n"
$Merged = Merge-CodexPolicyYaml -Text $Yaml -Policy $Policy
Assert-Equal $Merged ($Yaml.Replace('allow_implicit_invocation: true', 'allow_implicit_invocation: false')) 'Only the configured YAML leaf changes'
Assert-Equal (Merge-CodexPolicyYaml -Text $Merged -Policy $Policy) $Merged 'YAML merge is idempotent'
Write-Output 'PASS: policy merge preserves interface, comments, unrelated policy fields and dependencies'
foreach ($Unsupported in @('policy: { allow_implicit_invocation: true }', '"policy": {}', "'policy': {}", "policy:`n  allow_implicit_invocation: true`npolicy:`n  allow_implicit_invocation: false`n", "policy:`n  <<: *defaults`n")) {
    $Threw = $false
    try { $null = Merge-CodexPolicyYaml -Text $Unsupported -Policy $Policy } catch { $Threw = $true }
    Assert-Equal $Threw $true 'Ambiguous YAML must fail safely'
}
Write-Output 'PASS: ambiguous, duplicate and merged YAML mappings are refused'

$Entry = [pscustomobject]@{ name = 'cli-fixture'; localFolder = 'cli-fixture'; type = 'skills-cli'; autoUpdate = $true; repo = 'fixture/repo'; skill = 'cli-fixture'; rawSkillUrl = 'https://raw.githubusercontent.com/fixture/repo/main/SKILL.md' }
$RoutingOverrides = @{ 'cli-fixture' = [pscustomobject]@{ skill = 'cli-fixture'; codexPolicy = $Policy } }
$Text = "---`nname: cli-fixture`ndescription: Fixture.`n---`n# Fixture`n"
$SkillPath = Join-Path $SkillsRoot 'cli-fixture/SKILL.md'
$YamlPath = Join-Path $SkillsRoot 'cli-fixture/agents/openai.yaml'
Save-Fixture $SkillPath $Text
$script:PolicyFixtureSnapshot = [pscustomobject]@{ Files = @{ 'SKILL.md' = (Get-PackageBytesHash -Bytes ([Text.Encoding]::UTF8.GetBytes($Text)) -RelativePath 'SKILL.md') }; EntryText = $Text; OpenAiYaml = $null; Commit = ('a' * 40) }
function Get-SkillCliSourceSnapshot { param([object]$Entry) return $script:PolicyFixtureSnapshot }
$null = Apply-RoutingOverrideToLocalSkill $Entry
Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Generated policy is part of the expected CLI package'
Save-SkillManagedManifest $Entry
Assert-Equal (@((Read-SkillManagedManifest $Entry).files | Where-Object { $_.path -eq 'agents/openai.yaml' }).Count) 1 'Generated policy has ownership'
$ReceiptHash = Get-FileHashValue (Get-CodexPolicyReceiptPath $Entry)
Assert-Equal (Apply-RoutingOverrideToLocalSkill $Entry) $false 'Policy replay is idempotent'
Assert-Equal (Get-FileHashValue (Get-CodexPolicyReceiptPath $Entry)) $ReceiptHash 'Idempotent replay preserves receipt'
Write-Output 'PASS: generated CLI policy is verified, owned, and replayed idempotently'

# Model an installer replacing the package with a newer upstream YAML.
$script:PolicyFixtureSnapshot.OpenAiYaml = "interface:`n  display_name: `"New upstream label`"`n"
$script:PolicyFixtureSnapshot.Files['agents/openai.yaml'] = Get-PackageBytesHash -Bytes ([Text.Encoding]::UTF8.GetBytes($script:PolicyFixtureSnapshot.OpenAiYaml)) -RelativePath 'agents/openai.yaml'
Save-Fixture $YamlPath $script:PolicyFixtureSnapshot.OpenAiYaml
$null = Apply-RoutingOverrideToLocalSkill $Entry
Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Reinstall replays policy onto new upstream metadata'
Assert-Equal ((Get-FileText $YamlPath).Contains('New upstream label')) $true 'New upstream interface preserved'
Write-Output 'PASS: reinstall retains newly supplied upstream metadata and restores explicit-only policy'

$RoutingOverrides = @{}
$null = Apply-RoutingOverrideToLocalSkill $Entry
Assert-Equal (Get-FileText $YamlPath) $script:PolicyFixtureSnapshot.OpenAiYaml 'Policy removal restores upstream YAML, not deletion'
Assert-Equal (Test-Path -LiteralPath (Get-CodexPolicyReceiptPath $Entry)) $false 'Removed policy receipt retired'
Write-Output 'PASS: removing a local policy restores an existing upstream YAML safely'

$Source = Join-Path $CaseRoot 'upstream'
$LocalRoot = Join-Path $SkillsRoot 'git-fixture'
$null = New-Item -ItemType Directory -Path $Source -Force
Git-Fixture $Source @('init', '--initial-branch=main')
Save-Fixture (Join-Path $Source 'SKILL.md') "---`nname: git-fixture`ndescription: Git fixture.`n---`n# Fixture`n"
Save-Fixture (Join-Path $Source 'agents/openai.yaml') "interface:`n  display_name: `"Original label`"`n"
Git-Fixture $Source @('add', '.')
Git-Fixture $Source @('commit', '-m', 'Initial')
Git-Fixture $CaseRoot @('clone', '--quiet', $Source, $LocalRoot)
Git-Fixture $LocalRoot @('config', 'core.autocrlf', 'false')
$Entry = [pscustomobject]@{ name = 'git-fixture'; localFolder = 'git-fixture'; type = 'git'; autoUpdate = $true; remote = $Source; branch = 'main' }
$RoutingOverrides = @{ 'git-fixture' = [pscustomobject]@{ skill = 'git-fixture'; codexPolicy = $Policy } }
$null = Apply-RoutingOverrideToLocalSkill $Entry
Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Policy-only Git dirt is healthy'
Save-Fixture (Join-Path $Source 'agents/openai.yaml') "interface:`n  display_name: `"Updated label`"`n"
Save-Fixture (Join-Path $Source 'resource.txt') 'new upstream resource'
Git-Fixture $Source @('add', '.')
Git-Fixture $Source @('commit', '-m', 'Update')
$Result = Update-Skill $Entry
Assert-Equal $Result.Action 'updated' ('Generated Git overlay must not freeze updates: ' + $Result.Detail)
Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Updated Git policy is healthy'
Assert-Equal ((Get-FileText (Join-Path $LocalRoot 'agents/openai.yaml')).Contains('Updated label')) $true 'New upstream metadata survives Git update'
Assert-Equal (Get-GeneratedPolicyGitChanges $Entry) $true 'Remaining dirt is exactly regenerated YAML'
Write-Output 'PASS: a real git pull crosses generated YAML safely and preserves new upstream metadata'

Save-Fixture (Join-Path $Source 'resource.txt') 'next upstream resource'
Git-Fixture $Source @('add', '.')
Git-Fixture $Source @('commit', '-m', 'Next')
Save-Fixture (Join-Path $LocalRoot 'agents/unrelated.txt') 'user work'
$Before = (Invoke-Git $LocalRoot @('rev-parse', 'HEAD')).Output
$Result = Update-Skill $Entry
Assert-Equal $Result.Status 'error' 'Untracked file beside generated YAML blocks pull'
Assert-Equal (Invoke-Git $LocalRoot @('rev-parse', 'HEAD')).Output $Before 'Blocked pull does not advance HEAD'
Remove-Item -LiteralPath (Join-Path $LocalRoot 'agents/unrelated.txt')
Git-Fixture $LocalRoot @('add', 'agents/openai.yaml')
$Result = Update-Skill $Entry
Assert-Equal $Result.Status 'error' 'Staged YAML is not an automatic overlay'
Git-Fixture $LocalRoot @('restore', '--staged', '--', 'agents/openai.yaml')
Write-Output 'PASS: unrelated untracked files and staged metadata remain protected from Git updates'

Git-Fixture $LocalRoot @('remote', 'set-url', 'origin', (Join-Path $CaseRoot 'missing-origin'))
$BeforeYaml = [IO.File]::ReadAllBytes((Join-Path $LocalRoot 'agents/openai.yaml'))
$Result = Update-Skill $Entry
Assert-Equal $Result.Status 'error' 'Broken origin causes a visible failure'
Assert-Equal (Get-FileHashValue (Join-Path $LocalRoot 'agents/openai.yaml')) (Get-PackageBytesHash -Bytes $BeforeYaml -RelativePath 'agents/openai.yaml') 'Failed pull restores policy bytes'
Assert-Equal (Test-CodexSkillPolicy $Entry) $true 'Failed pull does not disable the explicit-only policy'
Git-Fixture $LocalRoot @('remote', 'set-url', 'origin', $Source)
Write-Output 'PASS: failed Git pull restores the generated policy without resetting other files'

$Lock = Join-Path $LocalRoot '.git/index.lock'
Save-Fixture $Lock 'simulated stale lock'
$null = Get-SkillStatus $Entry
Assert-Equal (Get-FileText $Lock) 'simulated stale lock' 'Read-only status leaves an existing Git lock alone'
Remove-Item -LiteralPath $Lock
Write-Output 'PASS: read-only Git status does not delete or repair repository locks'

$RoutingOverrides = @{}
$null = Apply-RoutingOverrideToLocalSkill $Entry
Assert-Equal (Test-Path -LiteralPath (Join-Path $LocalRoot 'agents/openai.yaml')) $true 'Tracked YAML survives policy removal'
Assert-Equal (Invoke-Git $LocalRoot @('status', '--porcelain')).Output '' 'Removing the overlay restores a clean Git file'
Write-Output 'PASS: removing a direct-Git policy restores HEAD metadata without deleting tracked YAML'

$OverridesPath = Join-Path $CaseRoot 'routing.json'
$GlobalPath = Join-Path $CaseRoot 'AGENTS.md'
Save-Fixture $OverridesPath '{"codexGlobalRouting":"Use destination-based routing."}'
Save-Fixture $GlobalPath "Existing user instructions.`n"
$null = Sync-CodexRoutingInstructions -Path $GlobalPath
Assert-Equal ((Get-FileText $GlobalPath).StartsWith("Existing user instructions.`n")) $true 'Global user instructions are preserved'
Assert-Equal (Sync-CodexRoutingInstructions -Path $GlobalPath) $false 'Global routing replay idempotent'
Assert-Equal (Sync-CodexRoutingInstructions -Path $GlobalPath -CheckOnly) $true 'Global routing validates read-only'
Write-Output 'PASS: managed global routing preserves existing user guidance and replays idempotently'
Write-Output '11 client policy scenarios passed.'
