param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$UpdaterPath = Join-Path (Split-Path -Parent $ManagerPath) 'auto-update-skills.ps1'
$Code = [IO.File]::ReadAllText($UpdaterPath)
$Tokens = $null; $Errors = $null
$Ast = [Management.Automation.Language.Parser]::ParseFile($UpdaterPath, [ref]$Tokens, [ref]$Errors)
if ($Errors.Count) { throw ($Errors | Out-String) }
$Definition = @($Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq 'Invoke-Step' }, $false))[0]
$Stub = @'
function Invoke-Step {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSec)
    $Index = [Array]::IndexOf($Arguments, '-ResultPath')
    if ($Index -lt 0) { return [pscustomobject]@{ ExitCode = 0; Output = 'fixture impeccable preview/apply'; TimedOut = $false } }
    $WatchIndex = [Array]::IndexOf($Arguments, '-UpstreamWatchMode')
    $ExpectedWatchMode = if ($DryRun) { 'cached' } else { 'due' }
    if ($WatchIndex -lt 0 -or $Arguments[$WatchIndex + 1] -ne $ExpectedWatchMode) { throw 'Wrong wrapper observation mode.' }
    $Fixture = [IO.File]::ReadAllText((Join-Path $ScriptRoot 'fixture.json')) | ConvertFrom-Json
    $ModeIndex = [Array]::IndexOf($Arguments, '-Mode')
    $Sidecar = [ordered]@{ schemaVersion = 1; mode = $Arguments[$ModeIndex + 1]; results = @($Fixture.rows) }
    [IO.File]::WriteAllText($Arguments[$Index + 1], ($Sidecar | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    $Lines = @($Fixture.rows | Group-Object Status | ForEach-Object { '- ' + $_.Name + ': ' + $_.Count })
    foreach ($Row in $Fixture.rows) { if ($Row.Status -eq 'error') { $Lines += 'SKILL_ERROR_DETAIL: ' + ($Row.Detail | ConvertTo-Json -Compress) } }
    return [pscustomobject]@{ ExitCode = 0; Output = ($Lines -join "`n"); TimedOut = $false }
}
'@
$Code = $Code.Remove($Definition.Extent.StartOffset, $Definition.Extent.EndOffset - $Definition.Extent.StartOffset).Insert($Definition.Extent.StartOffset, $Stub)
$Code = $Code.Replace('$ExternalRoot = Join-Path ([Environment]::GetFolderPath(''UserProfile'')) ''.agents\external''', '$ExternalRoot = Join-Path $ScriptRoot ''external''')
$Code = $Code.Replace('Global\AgentsSkillsAutoUpdate', ('Local\SkillsReviewTest-' + [guid]::NewGuid().ToString('N')))
$CaseRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $CaseRoot -Force
$TestUpdater = Join-Path $CaseRoot 'auto-update-skills.ps1'
[IO.File]::WriteAllText($TestUpdater, $Code, (New-Object Text.UTF8Encoding($true)))
[IO.File]::WriteAllText((Join-Path $CaseRoot 'manage-skills.ps1'), '# mocked subprocess transport')
$Flag = Join-Path $CaseRoot 'attention.txt'
$FixturePath = Join-Path $CaseRoot 'fixture.json'
$StatePath = Join-Path $CaseRoot 'external/skill-upstream-watch/notifications.json'
$Row = [pscustomobject]@{ Name = 'manual-fixture'; Status = 'review-required'; LocalStatus = 'up-to-date'; Detail = 'upstream subtree changed'; Upstream = [pscustomobject]@{ status = 'review-required'; baselineKind = 'installed'; observedCommit = ('a' * 40); fingerprint = ('1' * 64) } }
function Save-Rows { param([object[]]$Rows) [IO.File]::WriteAllText($FixturePath, ([ordered]@{ rows = $Rows } | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false))) }
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
function Run-Fixture {
    param([switch]$SuppressFlag, [switch]$DryRun, [switch]$FullRun, [int]$ExpectedExit = 0)
    $Arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $TestUpdater, '-NoNotify', '-AttentionFlagPath', $Flag)
    if ($FullRun) { $Arguments += '-NoCacheRepair' } else { $Arguments += '-SkillsOnly' }
    if ($SuppressFlag) { $Arguments += '-NoAttentionFlag' }
    if ($DryRun) { $Arguments += '-DryRun' }
    & powershell.exe @Arguments > (Join-Path $CaseRoot 'run.log') 2>&1
    Assert-Equal $LASTEXITCODE $ExpectedExit ('Wrapper exit; see ' + (Join-Path $CaseRoot 'run.log'))
    $StatusPath = Join-Path $CaseRoot $(if ($DryRun) { 'logs/last-check-status.json' } else { 'logs/last-status.json' })
    return ([IO.File]::ReadAllText($StatusPath, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}
Save-Rows @($Row)
$First = Run-Fixture -SuppressFlag -DryRun
Assert-Equal @($First.newReviewNotices).Count 1 'First review is eligible for notification'
Assert-Equal (Test-Path -LiteralPath $StatePath) $false 'Both delivery switches suppressed must not mark notified'
Assert-Equal @($First.steps)[0].Status 'review-required' 'DryRun retains visible review state'
Write-Output 'PASS: suppressed deliveries do not consume a review notification'

$Delivered = Run-Fixture
Assert-Equal @($Delivered.newReviewNotices).Count 1 'Undelivered review is retried'
Assert-Equal (Test-Path -LiteralPath $Flag) $true 'Non-popup durable alert delivered to isolated file'
Assert-Equal (Test-Path -LiteralPath $StatePath) $true 'Only successful delivery records notification'
Write-Output 'PASS: a delivered durable review alert is recorded separately from the baseline'

$Again = Run-Fixture
Assert-Equal @($Again.newReviewNotices).Count 0 'Same subtree review is not alerted twice'
Assert-Equal @($Again.steps)[0].Status 'review-required' 'Deduplication never hides persistent review state'
Assert-Equal (Test-Path -LiteralPath $Flag) $true 'An unresolved durable alert is not cleared'
Write-Output 'PASS: repeated review alerts are deduplicated while status and attention remain visible'

$Row.Upstream.observedCommit = 'b' * 40
Save-Rows @($Row)
$Unrelated = Run-Fixture
Assert-Equal @($Unrelated.newReviewNotices).Count 0 'Changed repo commit with identical subtree fingerprint stays deduplicated'
$Row.Upstream.fingerprint = '2' * 64
Save-Rows @($Row)
$New = Run-Fixture
Assert-Equal @($New.newReviewNotices).Count 1 'A new subtree change generates a new alert'
Write-Output 'PASS: notification identity follows relevant subtree changes instead of unrelated commits'

$Failure = [pscustomobject]@{ Name = 'failed-fixture'; Status = 'error'; LocalStatus = 'error'; Detail = 'local patch malformed; review needed' }
Save-Rows @($Row, $Failure)
$Mixed = Run-Fixture -ExpectedExit 1
Assert-Equal @($Mixed.newReviewNotices).Count 0 'Known review stays deduplicated during failure'
Assert-Equal @($Mixed.steps)[0].Status 'partial' 'A separate failure remains unhealthy'
Assert-Equal (([IO.File]::ReadAllText($Flag)).Contains('error=1')) $true 'Failure alert is not suppressed by review deduplication'
Write-Output 'PASS: failures remain visible and notify even when all review notices are duplicates'

$ObservationWarning = [pscustomobject]@{
    Name = 'offline-fixture'; Status = 'up-to-date'; LocalStatus = 'up-to-date'; Detail = 'local intact; upstream unconfirmed'
    Upstream = [pscustomobject]@{ status = 'unconfirmed'; baselineKind = 'installed'; observedCommit = ('c' * 40); fingerprint = ''; source = 'cache'; freshness = 'stale'; checkedAt = '2026-01-01T00:00:00Z'; warning = 'fixture TLS connection error; last observation expired' }
}
Save-Rows @($ObservationWarning)
$FlagBefore = [IO.File]::ReadAllText($Flag)
$Quiet = Run-Fixture -DryRun
Assert-Equal $Quiet.upstreamWatchMode 'cached' 'Wrapper DryRun defaults to cached observations'
Assert-Equal $Quiet.steps[0].Status 'upstream-unconfirmed' 'Observation warnings have a distinct wrapper state'
Assert-Equal @($Quiet.upstreamWarnings).Count 1 'Structured report includes separate observation warnings'
Assert-Equal @($Quiet.newReviewNotices).Count 0 'Network warning is not a fabricated review alert'
Assert-Equal ([IO.File]::ReadAllText($Flag)) $FlagBefore 'Observation warning neither replaces nor clears existing attention'
$Markdown = [IO.File]::ReadAllText((Join-Path $CaseRoot 'logs/LATEST-CHECK-STATUS.md'), [Text.Encoding]::UTF8)
Assert-Equal ($Markdown.Contains('cache / stale') -and $Markdown.Contains('2026-01-01')) $true 'Markdown discloses source and real observation time'
Write-Output 'PASS: upstream warnings keep exit zero, retain attention and disclose stale observation time'

$Row.Upstream | Add-Member warning 'refresh failed while a known review is pending' -Force
Save-Rows @($Row)
$KnownPending = Run-Fixture
Assert-Equal $KnownPending.upstreamWatchMode 'due' 'Real update defaults to due observations'
Assert-Equal $KnownPending.steps[0].Status 'review-required' 'Cached known review remains visible after refresh error'
Assert-Equal @($KnownPending.newReviewNotices).Count 0 'Network error does not duplicate known review alert'
Assert-Equal @($KnownPending.upstreamWarnings).Count 1 'Pending review does not suppress refresh warnings'
Write-Output 'PASS: known review notifications stay deduplicated while refresh warnings remain visible'

Save-Rows @($ObservationWarning, $Failure)
$LocalBroken = Run-Fixture -ExpectedExit 1
Assert-Equal $LocalBroken.steps[0].Status 'partial' 'Local failure still fails the run alongside observation warnings'
Assert-Equal ([IO.File]::ReadAllText($Flag).Contains('error=1')) $true 'Local failure still delivers attention'
Write-Output 'PASS: local failures remain actionable alongside independent upstream warnings'

$CacheSkill = Join-Path $CaseRoot 'external/impeccable-upstream/.agents/skills/impeccable'
foreach ($Dir in @($CacheSkill, (Join-Path $CacheSkill 'reference'), (Join-Path $CacheSkill 'scripts'), (Join-Path $CacheSkill 'agents'), (Join-Path $CaseRoot 'impeccable'))) { $null = New-Item -ItemType Directory -Path $Dir -Force }
[IO.File]::WriteAllText((Join-Path $CacheSkill 'SKILL.md'), '# upstream fixture')
[IO.File]::WriteAllText((Join-Path $CaseRoot 'impeccable/SKILL.md'), '# local fixture')
[IO.File]::WriteAllText((Join-Path $CaseRoot 'update-impeccable.ps1'), '# mocked updater')
Save-Rows @($ObservationWarning)
$FlagBefore = [IO.File]::ReadAllText($Flag)
$FullWarning = Run-Fixture -FullRun
Assert-Equal $FullWarning.steps[1].Status 'upstream-unconfirmed' 'Complete update still records unresolved observation warning'
Assert-Equal ([IO.File]::ReadAllText($Flag)) $FlagBefore 'Even complete actual update cannot clear attention with unconfirmed observations'
Write-Output 'PASS: a complete actual update cannot clear prior attention while upstream observations are unconfirmed'

$Healthy = [pscustomobject]@{ Name = 'healthy-fixture'; Status = 'up-to-date'; LocalStatus = 'up-to-date'; Detail = 'verified local fixture' }
Save-Rows @($Healthy)
$FullClean = Run-Fixture -FullRun
Assert-Equal $FullClean.steps[1].Status 'updated' 'Complete clean update still reaches its successful terminal state'
Assert-Equal (Test-Path -LiteralPath $Flag) $false 'Complete confirmed clean update clears resolved attention'
Write-Output 'PASS: attention still clears after a complete confirmed successful actual update'
Write-Output '10 review-notification integration scenarios passed.'

