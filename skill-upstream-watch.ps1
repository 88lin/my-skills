# Protected-source observations never fetch, checkout, or advance reviewed baselines.
# cached is read-only; due/force may atomically persist a small observation outside skills.
function Test-SkillUpstreamWatch {
    param([object]$Entry)
    if ($Entry.name -eq 'impeccable') { return $false } # Dedicated reviewed updater.
    return ($Entry.type -eq 'manual' -or -not $Entry.autoUpdate)
}

function Get-UpstreamWatchConfig {
    param([object]$Entry)
    $Watch = if ($Entry.PSObject.Properties.Name -contains 'upstreamWatch') { $Entry.upstreamWatch } else { $null }
    $Remote = if ($Entry.PSObject.Properties.Name -contains 'remote') { [string]$Entry.remote } else { '' }
    $Repo = ''
    if ($Remote -match '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?/?$') { $Repo = $Matches[1] }
    $Scope = if ($null -ne $Watch -and $Watch.PSObject.Properties.Name -contains 'path') { [string]$Watch.path }
        elseif ($Entry.PSObject.Properties.Name -contains 'upstreamSkillPath') { [string]$Entry.upstreamSkillPath }
        elseif ($Entry.type -eq 'git') { '' } else { $null }
    if ($null -ne $Scope) {
        $Scope = $Scope.Replace('\', '/').Trim('/')
        if ($Scope -ne '' -and ($Scope -notmatch '^[A-Za-z0-9._/-]+$' -or @($Scope.Split('/') | Where-Object { $_ -in @('', '.', '..', '.git') }).Count -gt 0)) {
            throw "Unsafe upstream observation scope: $Scope"
        }
    }
    $Baseline = ''
    $Kind = 'unknown'
    if ($null -ne $Watch -and $Watch.PSObject.Properties.Name -contains 'reviewedCommit' -and $Watch.reviewedCommit) {
        $Baseline = [string]$Watch.reviewedCommit
        $Kind = 'reviewed-reference'
    }
    elseif ($Entry.PSObject.Properties.Name -contains 'upstreamCommit' -and $Entry.upstreamCommit) {
        $Baseline = [string]$Entry.upstreamCommit
        $Kind = 'installed'
    }
    elseif ($Entry.type -eq 'git') {
        $Head = Invoke-Git -Path (Get-GitRepositoryPath -Entry $Entry) -Arguments @('rev-parse', 'HEAD')
        if ($Head.ExitCode -ne 0) { throw $Head.Output }
        $Baseline = $Head.Output.Trim()
        $Kind = 'local-git-head'
    }
    if ($Baseline -ne '' -and $Baseline -notmatch '^[0-9a-f]{40}$') { throw 'Invalid observation baseline commit.' }
    $Branch = if ($Entry.PSObject.Properties.Name -contains 'branch' -and $Entry.branch) { [string]$Entry.branch } else { 'main' }
    return [pscustomobject]@{ Repo = $Repo; Remote = $Remote; Scope = $Scope; Branch = $Branch; Baseline = $Baseline; BaselineKind = $Kind }
}

function Get-UpstreamTreeResponse {
    param([string]$Repo, [string]$Revision)
    if (-not (Get-Variable -Name SkillWatchTrees -Scope Script -ErrorAction SilentlyContinue)) { $script:SkillWatchTrees = @{} }
    $Key = $Repo + '@' + $Revision
    if (-not $script:SkillWatchTrees.ContainsKey($Key)) {
        $script:SkillWatchTrees[$Key] = Invoke-RestMethod -Uri ("https://api.github.com/repos/$Repo/git/trees/$Revision") -Headers @{ 'User-Agent' = 'local-skills-upstream-watch'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec (Get-UpstreamWatchRequestTimeout)
    }
    return $script:SkillWatchTrees[$Key]
}

function Get-UpstreamCommitTreeSha {
    param([string]$Repo, [string]$Commit)
    if (-not (Get-Variable -Name SkillWatchCommitTrees -Scope Script -ErrorAction SilentlyContinue)) { $script:SkillWatchCommitTrees = @{} }
    $Key = $Repo + '@' + $Commit
    if (-not $script:SkillWatchCommitTrees.ContainsKey($Key)) {
        $CommitInfo = Invoke-RestMethod -Uri ("https://api.github.com/repos/$Repo/git/commits/$Commit") -Headers @{ 'User-Agent' = 'local-skills-upstream-watch'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec (Get-UpstreamWatchRequestTimeout)
        if ($CommitInfo.tree.sha -notmatch '^[0-9a-f]{40}$') { throw 'Invalid root tree in upstream commit response.' }
        $script:SkillWatchCommitTrees[$Key] = [string]$CommitInfo.tree.sha
    }
    return $script:SkillWatchCommitTrees[$Key]
}

function Get-UpstreamScopeTree {
    param([string]$Repo, [string]$Commit, [AllowEmptyString()][string]$Scope)
    if ($Commit -notmatch '^[0-9a-f]{40}$') { throw 'Observation requires a pinned commit.' }
    # The tree endpoint may echo a commit-ish in sha. Resolve the actual root
    # tree first when the watched scope is the repository root.
    $Revision = if ($Scope -eq '') { Get-UpstreamCommitTreeSha -Repo $Repo -Commit $Commit } else { $Commit }
    $Tree = Get-UpstreamTreeResponse -Repo $Repo -Revision $Revision
    foreach ($Part in @($Scope.Split('/') | Where-Object { $_ -ne '' })) {
        $Children = @($Tree.tree | Where-Object { $_.path -ceq $Part })
        if ($Children.Count -eq 0) { return [pscustomobject]@{ Exists = $false; Sha = 'missing'; HasEntry = $false } }
        if ($Children.Count -ne 1 -or $Children[0].type -ne 'tree') { throw "Upstream scope is not a directory: $Scope" }
        $Tree = Get-UpstreamTreeResponse -Repo $Repo -Revision $Children[0].sha
    }
    if ($Tree.sha -notmatch '^[0-9a-f]{40}$' -or $Tree.truncated) { throw 'Invalid or truncated upstream tree response.' }
    $HasEntry = @($Tree.tree | Where-Object { $_.path -ceq 'SKILL.md' -and $_.type -eq 'blob' -and $_.mode -ne '120000' }).Count -eq 1
    return [pscustomobject]@{ Exists = $true; Sha = [string]$Tree.sha; HasEntry = $HasEntry }
}

function Get-UpstreamWatchRequestTimeout {
    $Remaining = [double]$UpstreamWatchTimeoutSec
    if (Get-Variable -Name SkillWatchTimer -Scope Script -ErrorAction SilentlyContinue) {
        if ($null -ne $script:SkillWatchTimer) { $Remaining -= $script:SkillWatchTimer.Elapsed.TotalSeconds }
    }
    if ($Remaining -le 0) { throw 'upstream observation refresh timeout' }
    return [Math]::Max(1, [int][Math]::Ceiling($Remaining))
}

function New-UpstreamWatchResult {
    param([object]$Entry)
    return [pscustomobject][ordered]@{
        skill = $Entry.name; checkedAt = ''; status = 'unconfirmed'
        repo = ''; scope = $null; baselineKind = 'unknown'; baselineCommit = ''; baselineTree = ''
        observedCommit = ''; observedTree = ''; fingerprint = ''; detail = ''
    }
}

function Set-UpstreamWatchFingerprint {
    param([object]$Result)
    # Ignore unrelated commit IDs while preserving the content identities under review.
    $Result.fingerprint = Get-TextHash -Text (([ordered]@{
        skill = $Result.skill; repo = $Result.repo; scope = $Result.scope
        base = $Result.baselineTree; observed = $Result.observedTree
        kind = $Result.baselineKind; status = $Result.status
    }) | ConvertTo-Json -Compress)
}

function Invoke-SkillUpstreamObservation {
    param([object]$Entry, [object]$Watch)
    $Result = New-UpstreamWatchResult -Entry $Entry
    $Result.repo = $Watch.Repo; $Result.scope = $Watch.Scope
    $Result.baselineKind = $Watch.BaselineKind; $Result.baselineCommit = $Watch.Baseline
    $Result.status = 'review-required'
    $Result.observedCommit = Get-GitRemoteHead -Remote $Watch.Remote -Branch $Watch.Branch -TimeoutSec (Get-UpstreamWatchRequestTimeout)
    $Observed = Get-UpstreamScopeTree -Repo $Watch.Repo -Commit $Result.observedCommit -Scope $Watch.Scope
    $Result.observedTree = $Observed.Sha
    if ($Watch.Baseline -eq '') {
        $Result.detail = '历史安装基线未知；本次观察不代表已经安装、审阅或合并'
    }
    else {
        $Base = if ($Watch.Baseline -ceq $Result.observedCommit) { $Observed }
            else { Get-UpstreamScopeTree -Repo $Watch.Repo -Commit $Watch.Baseline -Scope $Watch.Scope }
        $Result.baselineTree = $Base.Sha
        if (-not $Observed.Exists -or -not $Observed.HasEntry -or -not $Base.Exists -or -not $Base.HasEntry) {
            $Result.detail = '上游 skill 子目录或 SKILL.md 缺失；需要审阅来源布局变化'
        }
        elseif ($Base.Sha -ceq $Observed.Sha) {
            $Result.status = 'up-to-date'
            $Result.detail = 'skill 子目录相对基线没有变化'
        }
        else { $Result.detail = 'skill 子目录有上游变化；人工审阅合并，自动更新保持关闭' }
    }
    $Result.checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    Set-UpstreamWatchFingerprint -Result $Result
    return $Result
}

function Get-UpstreamWatchCachePath {
    param([object]$Entry)
    if ($Entry.name -cnotmatch '^[a-z0-9][a-z0-9-]*$') { throw 'Unsafe upstream observation cache name.' }
    return Join-Path $UpstreamWatchCacheRoot ($Entry.name + '.json')
}

function ConvertTo-UpstreamWatchTime {
    param([string]$Text)
    if (-not $Text) { throw 'Missing observation timestamp.' }
    $Value = [DateTimeOffset]::Parse($Text, [Globalization.CultureInfo]::InvariantCulture)
    if ($Value -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) { throw 'Observation timestamp is in the future.' }
    return $Value
}

function Read-UpstreamWatchCache {
    param([string]$Path, [string]$SourceKey)
    $Outcome = [pscustomobject]@{ state = $null; reason = '尚无上游观察缓存' }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $Outcome }
    try {
        $State = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($State.schemaVersion -ne 1) { throw 'Unknown observation schema.' }
        if ($State.sourceKey -cne $SourceKey) { $Outcome.reason = '来源、分支、范围或审阅基线已改变，旧观察缓存失效'; return $Outcome }
        $null = ConvertTo-UpstreamWatchTime $State.lastAttemptAt
        if ($null -ne $State.lastSuccess) {
            $Saved = $State.lastSuccess
            foreach ($Field in @('skill', 'checkedAt', 'status', 'repo', 'scope', 'baselineKind', 'baselineCommit', 'baselineTree', 'observedCommit', 'observedTree', 'fingerprint', 'detail')) {
                if ($Saved.PSObject.Properties.Name -notcontains $Field) { throw "Missing cached observation field: $Field" }
            }
            if ($Saved.status -notin @('up-to-date', 'review-required') -or $Saved.fingerprint -notmatch '^[0-9a-f]{64}$' -or $Saved.observedCommit -notmatch '^[0-9a-f]{40}$') { throw 'Invalid cached observation.' }
            $null = ConvertTo-UpstreamWatchTime $Saved.checkedAt
        }
        $null = $State.lastError
        $Outcome.state = $State; $Outcome.reason = ''
    }
    catch { $Outcome.reason = '观察缓存不可用: ' + $_.Exception.Message }
    return $Outcome
}

function Save-UpstreamWatchCache {
    param([string]$Path, [object]$State)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    $Temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($Temp, ($State | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($Temp, $Path, [NullString]::Value) }
        else { [IO.File]::Move($Temp, $Path) }
    }
    finally { if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Force } }
}

function Get-SkillUpstreamObservation {
    param([object]$Entry)
    $Now = [DateTimeOffset]::UtcNow
    $Result = New-UpstreamWatchResult -Entry $Entry
    $Meta = [ordered]@{
        evaluatedAt = $Now.ToString('o'); mode = $UpstreamWatchMode; source = 'none'
        freshness = 'unconfirmed'; lastKnownStatus = ''; lastAttemptAt = ''; lastError = ''
        refreshAttempted = $false; nextRefreshAt = ''; warning = ''
    }
    $Watch = $null
    try {
        $Watch = Get-UpstreamWatchConfig -Entry $Entry
        $Result.repo = $Watch.Repo; $Result.scope = $Watch.Scope
        $Result.baselineKind = $Watch.BaselineKind; $Result.baselineCommit = $Watch.Baseline
        if ($Watch.Repo -eq '' -or $null -eq $Watch.Scope) { throw '未配置 GitHub 来源或 skill 子目录' }
    }
    catch {
        $Result.status = 'review-required'; $Result.detail = '上游观察配置需要审阅: ' + $_.Exception.Message
        $Meta.source = 'configuration'
        Set-UpstreamWatchFingerprint -Result $Result
        foreach ($Key in $Meta.Keys) { $Result | Add-Member -NotePropertyName $Key -NotePropertyValue $Meta[$Key] }
        return $Result
    }
    $SourceKey = Get-TextHash -Text (([ordered]@{
        skill = $Entry.name; remote = $Watch.Remote; repo = $Watch.Repo; scope = $Watch.Scope
        branch = $Watch.Branch; baselineKind = $Watch.BaselineKind; baselineCommit = $Watch.Baseline
    }) | ConvertTo-Json -Compress)
    $CachePath = Get-UpstreamWatchCachePath -Entry $Entry
    $Cache = Read-UpstreamWatchCache -Path $CachePath -SourceKey $SourceKey
    $State = $Cache.state
    $Fresh = $false; $Backoff = $false
    if ($null -ne $State) {
        if ($null -ne $State.lastSuccess) { $Fresh = $Now -lt (ConvertTo-UpstreamWatchTime $State.lastSuccess.checkedAt).AddHours($UpstreamWatchFreshHours) }
        if ($State.lastError) { $Backoff = $Now -lt (ConvertTo-UpstreamWatchTime $State.lastAttemptAt).AddMinutes($UpstreamWatchRetryMinutes) }
    }
    $Refresh = $UpstreamWatchMode -eq 'force' -or ($UpstreamWatchMode -eq 'due' -and -not $Backoff -and (-not $Fresh -or ($null -ne $State -and $State.lastError)))
    $SaveWarning = ''
    if ($Refresh) {
        $Meta.refreshAttempted = $true
        if ($null -eq $State) { $State = [pscustomobject]@{ schemaVersion = 1; sourceKey = $SourceKey; lastAttemptAt = ''; lastError = ''; lastSuccess = $null } }
        $State.lastAttemptAt = $Now.ToString('o')
        $script:SkillWatchTimer = [Diagnostics.Stopwatch]::StartNew()
        try {
            $State.lastSuccess = Invoke-SkillUpstreamObservation -Entry $Entry -Watch $Watch
            $State.lastError = ''; $Meta.source = 'live'
        }
        catch { $State.lastError = 'upstream watch refresh failed: ' + $_.Exception.Message }
        finally { $script:SkillWatchTimer = $null }
        try { Save-UpstreamWatchCache -Path $CachePath -State $State }
        catch { $SaveWarning = '观察结果未持久化: ' + $_.Exception.Message }
    }
    if ($null -ne $State) {
        $Meta.lastAttemptAt = $State.lastAttemptAt; $Meta.lastError = [string]$State.lastError
        if ($null -ne $State.lastSuccess) {
            # Copy so added presentation fields can never mutate the stored successful observation.
            $Result = $State.lastSuccess | Select-Object *
            $Meta.lastKnownStatus = $Result.status
            if ($Meta.source -ne 'live') { $Meta.source = 'cache' }
            $ExpiresAt = (ConvertTo-UpstreamWatchTime $Result.checkedAt).AddHours($UpstreamWatchFreshHours)
            $Meta.freshness = if ([DateTimeOffset]::UtcNow -lt $ExpiresAt) { 'fresh' } else { 'stale' }
            $Meta.nextRefreshAt = $ExpiresAt.ToString('o')
        }
        if ($State.lastError) { $Meta.nextRefreshAt = (ConvertTo-UpstreamWatchTime $State.lastAttemptAt).AddMinutes($UpstreamWatchRetryMinutes).ToString('o') }
    }
    $Warnings = @()
    if ($Meta.source -eq 'none') { $Warnings += $Cache.reason; $Result.detail = '尚未核实上游；本地文件检查单独报告' }
    elseif ($Meta.freshness -eq 'stale') { $Warnings += '上次成功观察已过期，当前上游状态未核实' }
    if ($Meta.lastError) { $Warnings += $Meta.lastError }
    if ($SaveWarning) { $Warnings += $SaveWarning }
    if ($Watch.Baseline -eq '' -and $Result.status -ne 'review-required') {
        $Result.status = 'review-required'; $Result.detail = '历史安装基线未知；需要人工建立审阅基线'
        Set-UpstreamWatchFingerprint -Result $Result
    }
    if (($Meta.freshness -ne 'fresh' -or $Meta.lastError) -and $Result.status -eq 'up-to-date') { $Result.status = 'unconfirmed' }
    $Meta.warning = (@($Warnings | Where-Object { $_ }) -join '; ')
    foreach ($Key in $Meta.Keys) { $Result | Add-Member -NotePropertyName $Key -NotePropertyValue $Meta[$Key] -Force }
    return $Result
}

function Get-SkillStatus {
    param([object]$Entry)
    $Protected = Test-SkillUpstreamWatch -Entry $Entry
    $Local = Get-SkillLocalStatus -Entry $Entry -LocalOnly:$Protected
    if ($Local.Installed -and $Local.Status -notin @('missing', 'error', 'patch-stale')) {
        try {
            if (-not (Test-CodexSkillPolicy -Entry $Entry)) { $Local.Status = 'outdated'; $Local.Detail += '; Codex policy 未同步，请重放本地覆盖' }
        }
        catch { $Local.Status = 'error'; $Local.Detail += '; ' + $_.Exception.Message }
    }
    $Local | Add-Member -NotePropertyName LocalStatus -NotePropertyValue $Local.Status -Force
    if ($Protected -and $Local.Installed) {
        $Watch = Get-SkillUpstreamObservation -Entry $Entry
        $Local | Add-Member -NotePropertyName Upstream -NotePropertyValue $Watch -Force
        # Observation availability cannot turn an intact local installation into an error,
        # and review must not hide actual local drift or corruption.
        if ($Local.Status -in @('up-to-date', 'skipped', 'unchanged') -and $Watch.status -eq 'review-required') {
            $Local.Status = 'review-required'
        }
        $ScopeLabel = if ($null -eq $Watch.scope) { '(unset)' } elseif ($Watch.scope -eq '') { '(repository root)' } else { $Watch.scope }
        $Local.Detail += "; local=$($Local.LocalStatus); upstream=$($Watch.status); source=$($Watch.source); freshness=$($Watch.freshness); checkedAt=$($Watch.checkedAt); scope=$ScopeLabel; $($Watch.detail)"
        if ($Watch.warning) { $Local.Detail += '; observation warning: ' + $Watch.warning }
        if ($Watch.observedCommit) { $Local.Detail += '; observed=' + $Watch.observedCommit.Substring(0, 7) }
    }
    return $Local
}
