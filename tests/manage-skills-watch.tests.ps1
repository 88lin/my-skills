param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $ManagerPath -LoadOnly
if ($UpstreamWatchMode -ne 'cached') { throw 'Direct checks must default to cached observations.' }
$UpstreamWatchMode = 'force'
$CaseRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$UpstreamWatchCacheRoot = Join-Path $CaseRoot 'observations'
$script:WatchCalls = 0
$script:WatchTimeouts = @()
$SkillsRoot = Join-Path $CaseRoot 'skills'
$LocalRoot = Join-Path $SkillsRoot 'fixture'
$null = New-Item -ItemType Directory -Path $LocalRoot -Force
$SkillFile = Join-Path $LocalRoot 'SKILL.md'
[IO.File]::WriteAllText($SkillFile, "---`nname: fixture`ndescription: Retained local variant.`n---`n# Local custom content`n")
$Entry = [pscustomobject]@{ name = 'fixture'; localFolder = 'fixture'; type = 'manual'; autoUpdate = $false; remote = 'https://github.com/example/fixture.git'; branch = 'main'; upstreamSkillPath = 'skills/fixture'; upstreamCommit = ('a' * 40); reason = 'Keep local variant' }
$InitialEntryJson = $Entry | ConvertTo-Json -Depth 8
$RoutingOverrides = @{}
$script:WatchRemote = 'a' * 40
$script:WatchTree = '1' * 40
$script:WatchFail = $false
$script:WatchMissing = $false
function Get-GitRemoteHead { param([string]$Remote, [string]$Branch, [int]$TimeoutSec) $script:WatchCalls++; $script:WatchTimeouts += $TimeoutSec; if ($script:WatchFail) { throw 'network timeout' }; return $script:WatchRemote }
function Get-UpstreamTreeResponse {
    param([string]$Repo, [string]$Revision)
    if ($Revision -in @(('a' * 40), ('b' * 40))) { return [pscustomobject]@{ sha = ('5' * 40); truncated = $false; tree = @([pscustomobject]@{ path = 'skills'; type = 'tree'; sha = ('6' * 40) }) } }
    if ($Revision -eq ('6' * 40)) {
        $TreeSha = if ($script:WatchRemote -eq ('b' * 40)) { $script:WatchTree } else { '1' * 40 }
        return [pscustomobject]@{ sha = ('6' * 40); truncated = $false; tree = @([pscustomobject]@{ path = 'fixture'; type = 'tree'; sha = $TreeSha }) }
    }
    return [pscustomobject]@{ sha = $Revision; truncated = $false; tree = $(if ($script:WatchMissing) { @() } else { @([pscustomobject]@{ path = 'SKILL.md'; type = 'blob'; mode = '100644'; sha = ('7' * 40) }) }) }
}
# Keep tree traversal real; transport selects the per-commit subtree, including an unrelated-commit case.
$script:RealScopeReader = ${function:Get-UpstreamScopeTree}
function Get-UpstreamScopeTree {
    param([string]$Repo, [string]$Commit, [string]$Scope)
    $SavedRemote = $script:WatchRemote
    try { $script:WatchRemote = $Commit; return (& $script:RealScopeReader -Repo $Repo -Commit $Commit -Scope $Scope) }
    finally { $script:WatchRemote = $SavedRemote }
}
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
$InitialHash = Get-FileHashValue $SkillFile
$Same = Get-SkillUpstreamObservation $Entry
Assert-Equal $Same.status 'up-to-date' 'Same skill subtree is healthy'
$script:WatchRemote = 'b' * 40
$Unrelated = Get-SkillUpstreamObservation $Entry
Assert-Equal $Unrelated.status 'up-to-date' 'Other repository changes do not request review'
Assert-Equal $Same.fingerprint $Unrelated.fingerprint 'Fingerprint follows trees, not unrelated commit IDs'
Write-Output 'PASS: same revision and unrelated repository commits leave the skill observation healthy'

$script:WatchRootChanged = $false
function Get-UpstreamCommitTreeSha {
    param([string]$Repo, [string]$Commit)
    if ($Commit -eq ('b' * 40) -and $script:WatchRootChanged) { return ('8' * 40) }
    return ('5' * 40)
}
$RootEntry = [pscustomobject]@{ name = 'root-fixture'; localFolder = 'fixture'; type = 'manual'; autoUpdate = $false; remote = 'https://github.com/example/fixture.git'; branch = 'main'; upstreamSkillPath = ''; upstreamCommit = ('a' * 40) }
$RootSame = Get-SkillUpstreamObservation $RootEntry
Assert-Equal $RootSame.status 'up-to-date' 'Root scope compares content trees, not echoed commit IDs'
Assert-Equal $RootSame.observedTree ('5' * 40) 'Observed root is the resolved tree'
$script:WatchRootChanged = $true
Assert-Equal (Get-SkillUpstreamObservation $RootEntry).status 'review-required' 'Changed root tree requests review'
$script:WatchRootChanged = $false
Write-Output 'PASS: root scope resolves real tree IDs and ignores commits with identical content'

$script:WatchTree = '2' * 40
$Changed = Get-SkillStatus $Entry
Assert-Equal $Changed.Status 'review-required' 'No routing override must not suppress a manual upstream change'
Assert-Equal $Changed.LocalStatus 'skipped' 'Local consistency remains distinct from upstream review'
Assert-Equal $Changed.Upstream.observedCommit ('b' * 40) 'Observed revision recorded separately'
Assert-Equal $Entry.upstreamCommit ('a' * 40) 'Observation does not advance installed baseline'
Assert-Equal (Get-FileHashValue $SkillFile) $InitialHash 'Observation preserves local bytes'
Write-Output 'PASS: a changed skill subtree produces a separate read-only review-required observation'

$IncludeManual = $true
$Update = Update-Skill $Entry
Assert-Equal $Update.Status 'review-required' 'Manual review survives update mode'
Assert-Equal $Update.Action 'skipped' 'Protected skill cannot be overwritten by IncludeManual'
Assert-Equal (Get-FileHashValue $SkillFile) $InitialHash 'Protected update does not mutate content'
Write-Output 'PASS: update mode preserves review state and cannot bypass manual protection'

$Entry.upstreamCommit = ''
$Unknown = Get-SkillUpstreamObservation $Entry
Assert-Equal $Unknown.status 'review-required' 'Unknown historical baseline requests review'
Assert-Equal $Unknown.baselineKind 'unknown' 'Unknown is never relabeled installed'
Assert-Equal $Unknown.observedCommit ('b' * 40) 'Unknown baseline still records observation'
Write-Output 'PASS: unknown installed baseline remains explicit instead of adopting remote HEAD'

$Entry | Add-Member -NotePropertyName upstreamWatch -NotePropertyValue ([pscustomobject]@{ path = 'skills/fixture'; reviewedCommit = ('b' * 40) })
$Reviewed = Get-SkillUpstreamObservation $Entry
Assert-Equal $Reviewed.status 'up-to-date' 'Reviewed reference can track intentionally retained local code'
Assert-Equal $Reviewed.baselineKind 'reviewed-reference' 'Reviewed reference is not labeled installed'
Assert-Equal $Entry.upstreamCommit '' 'Prospective reference does not invent installation history'
Write-Output 'PASS: reviewed-reference tracking preserves the distinction from installed history'

$script:WatchMissing = $true
Assert-Equal (Get-SkillUpstreamObservation $Entry).status 'review-required' 'Missing SKILL.md does not appear healthy'
$script:WatchMissing = $false
$script:WatchFail = $true
$Failure = Get-SkillStatus $Entry
Assert-Equal $Failure.Status 'review-required' 'Refresh failure cannot discard known review state'
Assert-Equal $Failure.LocalStatus 'skipped' 'Refresh failure cannot change local status to error'
Assert-Equal $Failure.Upstream.lastKnownStatus 'review-required' 'Known review is retained separately'
Assert-Equal ($Failure.Upstream.lastError -match 'network timeout') $true 'Refresh failure stays visible'
Assert-Equal ($Failure.Upstream.fingerprint -match '^[0-9a-f]{64}$') $true 'Known review fingerprint survives a failed refresh'
Write-Output 'PASS: removed entry points remain under review even when a later network refresh fails'

$script:WatchFail = $false
$Entry.remote = ''
Assert-Equal (Get-SkillUpstreamObservation $Entry).status 'review-required' 'Unconfigured protected source requires setup'
$Entry.name = 'impeccable'
Assert-Equal (Test-SkillUpstreamWatch $Entry) $false 'Dedicated Impeccable updater is not duplicated'
Write-Output 'PASS: missing watch configuration is visible and Impeccable keeps its dedicated updater'

$Entry = $InitialEntryJson | ConvertFrom-Json
$Entry.name = 'cache-fixture'
$script:WatchRemote = 'a' * 40
$script:WatchTree = '1' * 40
$script:WatchFail = $false
$UpstreamWatchMode = 'cached'
$CallsBefore = $script:WatchCalls
$Empty = Get-SkillStatus $Entry
$CachePath = Get-UpstreamWatchCachePath $Entry
Assert-Equal $script:WatchCalls $CallsBefore 'A default cached check has zero remote calls'
Assert-Equal $Empty.Status 'skipped' 'An absent observation cache cannot imply local failure'
Assert-Equal $Empty.Upstream.status 'unconfirmed' 'An empty cache cannot claim a healthy upstream'
Assert-Equal $Empty.Upstream.source 'none' 'Missing observation source is explicit'
Assert-Equal (Test-Path -LiteralPath $CachePath) $false 'A cached check must not create observation files'
Write-Output 'PASS: cached checks with no observation perform no network calls or persistent writes'

$UpstreamWatchMode = 'due'
$Seed = Get-SkillUpstreamObservation $Entry
Assert-Equal $Seed.source 'live' 'Due checks refresh an empty cache'
Assert-Equal $Seed.status 'up-to-date' 'Successful observation is confirmed'
Assert-Equal $script:WatchCalls ($CallsBefore + 1) 'Empty cache is refreshed once'
$CacheHash = Get-FileHashValue $CachePath
$CacheStamp = (Get-Item -LiteralPath $CachePath).LastWriteTimeUtc
$Reused = Get-SkillUpstreamObservation $Entry
Assert-Equal $Reused.source 'cache' 'Due checks reuse fresh observations'
Assert-Equal $Reused.checkedAt $Seed.checkedAt 'Cache reuse preserves real successful observation time'
Assert-Equal $script:WatchCalls ($CallsBefore + 1) 'Fresh due checks do not contact upstream'
Assert-Equal (Get-FileHashValue $CachePath) $CacheHash 'Reuse never rewrites cached content'
Assert-Equal (Get-Item -LiteralPath $CachePath).LastWriteTimeUtc $CacheStamp 'Reuse never rewrites cache timestamp'
Write-Output 'PASS: due mode persists once and reuses fresh observations without rewriting time or bytes'

$UpstreamWatchMode = 'force'
$Forced = Get-SkillUpstreamObservation $Entry
Assert-Equal $Forced.refreshAttempted $true 'Force bypasses freshness'
Assert-Equal $script:WatchCalls ($CallsBefore + 2) 'Forced refresh contacts upstream'
Assert-Equal @($script:WatchTimeouts | Where-Object { $_ -lt 1 -or $_ -gt $UpstreamWatchTimeoutSec }).Count 0 'Watch requests use the bounded observation budget'
Write-Output 'PASS: force mode bypasses fresh cache and bounds transport timeouts'

function Age-Cache {
    param([switch]$Success, [switch]$Attempt)
    $State = [IO.File]::ReadAllText($CachePath) | ConvertFrom-Json
    if ($Success) { $State.lastSuccess.checkedAt = [DateTimeOffset]::UtcNow.AddHours(-73).ToString('o') }
    if ($Attempt) { $State.lastAttemptAt = [DateTimeOffset]::UtcNow.AddMinutes(-16).ToString('o') }
    Save-UpstreamWatchCache -Path $CachePath -State $State
}
Age-Cache -Success
$UpstreamWatchMode = 'cached'
$CallsBefore = $script:WatchCalls
$Expired = Get-SkillUpstreamObservation $Entry
Assert-Equal $Expired.status 'unconfirmed' 'Expired health is not current health'
Assert-Equal $Expired.lastKnownStatus 'up-to-date' 'Expired last-known state remains visible'
Assert-Equal $Expired.freshness 'stale' 'Expired timestamp is explicit'
Assert-Equal $script:WatchCalls $CallsBefore 'Expired cached checks still perform zero remote calls'
$UpstreamWatchMode = 'due'
Assert-Equal (Get-SkillUpstreamObservation $Entry).source 'live' 'Due mode refreshes an expired cache'
Assert-Equal $script:WatchCalls ($CallsBefore + 1) 'Expired observation has one refresh'
Write-Output 'PASS: expiry is visible without live queries until due mode is requested'

$Good = [IO.File]::ReadAllText($CachePath) | ConvertFrom-Json
$script:WatchFail = $true
$UpstreamWatchMode = 'force'
$Failed = Get-SkillStatus $Entry
Assert-Equal $Failed.Status 'skipped' 'An upstream failure is not a local error'
Assert-Equal $Failed.Upstream.status 'unconfirmed' 'Failed force cannot report currently confirmed health'
Assert-Equal $Failed.Upstream.checkedAt $Good.lastSuccess.checkedAt 'Failure preserves successful observation time'
Assert-Equal $Failed.Upstream.lastKnownStatus 'up-to-date' 'Failure retains successful history'
$CallsBefore = $script:WatchCalls
$UpstreamWatchMode = 'due'
$Deferred = Get-SkillUpstreamObservation $Entry
Assert-Equal $script:WatchCalls $CallsBefore 'Due mode backs off after failed refresh'
Assert-Equal $Deferred.lastError $Failed.Upstream.lastError 'Backoff preserves the actual refresh error'
$UpstreamWatchMode = 'force'
$null = Get-SkillUpstreamObservation $Entry
Assert-Equal $script:WatchCalls ($CallsBefore + 1) 'Force bypasses failure backoff'
Write-Output 'PASS: failed refresh preserves history and local status, with backoff and explicit retry'

Age-Cache -Attempt
$script:WatchFail = $false
$UpstreamWatchMode = 'due'
$CallsBefore = $script:WatchCalls
$Recovered = Get-SkillUpstreamObservation $Entry
Assert-Equal $Recovered.status 'up-to-date' 'Retry recovers after backoff ends'
Assert-Equal $Recovered.lastError '' 'Successful retry clears only refresh error'
Assert-Equal $script:WatchCalls ($CallsBefore + 1) 'Expired backoff attempts a refresh'
Write-Output 'PASS: a due retry succeeds after the backoff and clears stale error metadata'

$CachedEntry = $Entry | ConvertTo-Json -Depth 8
$UpstreamWatchMode = 'cached'
$CallsBefore = $script:WatchCalls
foreach ($Field in @('remote', 'branch', 'upstreamSkillPath', 'upstreamCommit', 'baselineKind')) {
    $ChangedEntry = $CachedEntry | ConvertFrom-Json
    switch ($Field) {
        'remote' { $ChangedEntry.remote = 'https://github.com/example/other.git' }
        'branch' { $ChangedEntry.branch = 'other' }
        'upstreamSkillPath' { $ChangedEntry.upstreamSkillPath = 'different' }
        'upstreamCommit' { $ChangedEntry.upstreamCommit = 'b' * 40 }
        'baselineKind' { $ChangedEntry | Add-Member upstreamWatch ([pscustomobject]@{ reviewedCommit = ('a' * 40) }) }
    }
    $Invalidated = Get-SkillUpstreamObservation $ChangedEntry
    Assert-Equal $Invalidated.status 'unconfirmed' ("Changed $Field invalidates observation identity")
    Assert-Equal $Invalidated.observedCommit '' ("Changed $Field cannot reuse the wrong upstream history")
}
Assert-Equal $script:WatchCalls $CallsBefore 'Invalidation is read-only in cached mode'
Write-Output 'PASS: remote, branch, scope, baseline commit and baseline kind all invalidate old observations'

$OriginalCache = [IO.File]::ReadAllBytes($CachePath)
foreach ($InvalidJson in @('{broken json', '{"schemaVersion": 99}')) {
    [IO.File]::WriteAllText($CachePath, $InvalidJson)
    $Broken = Get-SkillStatus $Entry
    Assert-Equal $Broken.Status 'skipped' 'Corrupt cache does not invalidate local content'
    Assert-Equal $Broken.Upstream.status 'unconfirmed' 'Corrupt cache cannot prove health'
    Assert-Equal ([IO.File]::ReadAllText($CachePath)) $InvalidJson 'Cached checks do not repair or rewrite corrupt state'
}
$UpstreamWatchMode = 'due'
Assert-Equal (Get-SkillUpstreamObservation $Entry).status 'up-to-date' 'Due refresh repairs corrupt observation state'
Assert-Equal @(Get-ChildItem -LiteralPath $UpstreamWatchCacheRoot -Filter '*.tmp').Count 0 'Atomic writes leave no temporary artifacts'
Write-Output 'PASS: corrupt caches stay explicit and read-only until refreshed, with atomic state replacement'

$Future = [IO.File]::ReadAllText($CachePath) | ConvertFrom-Json
$Future.lastSuccess.checkedAt = [DateTimeOffset]::UtcNow.AddDays(2).ToString('o')
Save-UpstreamWatchCache -Path $CachePath -State $Future
$UpstreamWatchMode = 'cached'
Assert-Equal (Get-SkillUpstreamObservation $Entry).status 'unconfirmed' 'A future timestamp cannot keep a cache fresh indefinitely'
[IO.File]::WriteAllBytes($CachePath, $OriginalCache)
Write-Output 'PASS: future cache timestamps are rejected instead of extending trust indefinitely'

$NoHistory = $CachedEntry | ConvertFrom-Json
$NoHistory.name = 'never-observed'
$script:WatchFail = $true
$UpstreamWatchMode = 'force'
$Never = Get-SkillStatus $NoHistory
Assert-Equal $Never.Status 'skipped' 'First failed observation leaves local status alone'
Assert-Equal $Never.Upstream.status 'unconfirmed' 'First failed observation has no invented successful state'
Assert-Equal $Never.Upstream.checkedAt '' 'First failure has no invented checkedAt'
Assert-Equal $Never.Upstream.fingerprint '' 'Failed observations never invent review fingerprints'
$script:WatchFail = $false
Write-Output 'PASS: first-ever failed refresh does not invent healthy history or a review fingerprint'

$Entry.upstreamSkillPath = '../unsafe'
$UpstreamWatchMode = 'cached'
$BadConfig = Get-SkillStatus $Entry
Assert-Equal $BadConfig.Status 'review-required' 'Invalid source configuration remains actionable'
Assert-Equal $BadConfig.Upstream.source 'configuration' 'Configuration review is distinct from a remote observation'
$Entry = $CachedEntry | ConvertFrom-Json
$Entry.upstreamCommit = ''
Assert-Equal (Get-SkillUpstreamObservation $Entry).status 'review-required' 'Unknown baseline needs review even without a cache'
$Entry = $CachedEntry | ConvertFrom-Json
Write-Output 'PASS: invalid configuration and unknown baselines require review even in cached mode'

$script:WatchRemote = 'b' * 40
$script:WatchTree = '2' * 40
$UpstreamWatchMode = 'force'
$Pending = Get-SkillUpstreamObservation $Entry
$script:WatchFail = $true
$PendingFailure = Get-SkillUpstreamObservation $Entry
Assert-Equal $PendingFailure.status 'review-required' 'A failed refresh cannot hide a known content change'
Assert-Equal $PendingFailure.fingerprint $Pending.fingerprint 'Notification identity survives failed refresh'
Age-Cache -Success
$UpstreamWatchMode = 'cached'
$StalePending = Get-SkillUpstreamObservation $Entry
Assert-Equal $StalePending.status 'review-required' 'Expiry cannot hide a pending review'
Assert-Equal $StalePending.freshness 'stale' 'Pending review still discloses stale observation time'
Assert-Equal $StalePending.fingerprint $Pending.fingerprint 'Expiry preserves review notification identity'
$script:WatchFail = $false
Write-Output 'PASS: known review state and fingerprint survive both refresh errors and cache expiry'

$script:LocalFixtureStatus = 'error'
function Get-SkillLocalStatus {
    param([object]$Entry, [switch]$LocalOnly)
    return [pscustomobject]@{ Name = $Entry.name; Type = $Entry.type; Installed = $true; Status = $script:LocalFixtureStatus; Detail = 'local fixture failure' }
}
foreach ($LocalFailure in @('error', 'missing', 'patch-stale', 'outdated')) {
    $script:LocalFixtureStatus = $LocalFailure
    $Status = Get-SkillStatus $Entry
    Assert-Equal $Status.Status $LocalFailure 'Real local failure or drift is never masked by review or observation availability'
    Assert-Equal $Status.LocalStatus $LocalFailure 'Local failure remains visible independently'
    Assert-Equal $Status.Upstream.status 'review-required' 'Known upstream review is also preserved'
}
Write-Output 'PASS: local error, missing content, stale patches and local drift are never hidden by upstream state'

$script:LocalFixtureStatus = 'skipped'
$script:WatchRemote = 'a' * 40
$script:WatchTree = '1' * 40
$UpstreamWatchMode = 'force'
function Save-UpstreamWatchCache { param([string]$Path, [object]$State) throw 'fixture cache write denied' }
$WriteFailure = Get-SkillStatus $Entry
Assert-Equal $WriteFailure.Status 'skipped' 'Cache persistence failure does not imply local failure'
Assert-Equal $WriteFailure.Upstream.source 'live' 'Successful live observation is still accurately labeled'
Assert-Equal ($WriteFailure.Upstream.warning -match 'cache write denied') $true 'Persistence failure must be surfaced'
Assert-Equal (Get-FileHashValue $SkillFile) $InitialHash 'All observation scenarios preserve local skill bytes'
Write-Output 'PASS: cache persistence failures are separate warnings and all watch modes preserve skill content'
Write-Output '22 upstream observation scenarios passed.'

