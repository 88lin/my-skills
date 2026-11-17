[CmdletBinding()]
param(
    [ValidateSet('skills-cli', 'manual')]
    [string]$SourceType = 'skills-cli',

    [Parameter(Mandatory = $true)]
    [string]$Skill,

    [string]$Repo,

    [string]$RawSkillUrl,

    [string]$LocalFolder,

    [string]$Reason = 'Manually managed; do not overwrite automatically',

    [switch]$SkipInstall,

    [switch]$Preview
)


$ReasonWasSupplied = $PSBoundParameters.ContainsKey('Reason')
. (Join-Path $PSScriptRoot 'manage-skills.ps1') -LoadOnly

if ($SourceType -eq 'skills-cli' -and [string]::IsNullOrWhiteSpace($Repo)) {
    throw '当 SourceType=skills-cli 时，必须提供 -Repo。'
}

function Get-FrontMatterName {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $FrontMatterMatch = [regex]::Match($Text, '(?ms)^---\s*(.*?)\s*---')
    if (-not $FrontMatterMatch.Success) {
        return $null
    }

    $NameMatch = [regex]::Match($FrontMatterMatch.Groups[1].Value, '(?m)^\s*name:\s*"?([^"\r\n]+)"?')
    if ($NameMatch.Success) {
        return $NameMatch.Groups[1].Value.Trim()
    }

    return $null
}

function Resolve-LocalFolder {
    param(
        [string]$SkillName,
        [string]$ExplicitFolder,
        [switch]$AllowMissing
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitFolder)) {
        return $ExplicitFolder
    }

    $Matches = @()
    foreach ($Dir in Get-ChildItem -Path $SkillsRoot -Directory) {
        $SkillFile = Join-Path $Dir.FullName 'SKILL.md'
        if (-not (Test-Path $SkillFile)) {
            continue
        }

        $Text = Get-FileText -Path $SkillFile
        $Name = Get-FrontMatterName -Text $Text
        if ($Name -eq $SkillName) {
            $Matches += $Dir.Name
        }
    }

    if ($Matches.Count -eq 1) {
        return $Matches[0]
    }

    if ($Matches.Count -gt 1) {
        throw ('找到多个匹配的本地目录，请手动指定 -LocalFolder: ' + ($Matches -join ', '))
    }

    if (Test-Path (Join-Path $SkillsRoot $SkillName)) {
        return $SkillName
    }

    if ($AllowMissing) {
        return $SkillName
    }

    throw '无法自动判断本地目录，请手动提供 -LocalFolder。'
}

function Resolve-RawSkillUrl {
    param(
        [string]$RepoName,
        [string]$SkillName,
        [string]$ExplicitUrl
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitUrl)) {
        return $ExplicitUrl
    }

    $Candidates = @(
        "https://raw.githubusercontent.com/$RepoName/main/skills/$SkillName/SKILL.md",
        "https://raw.githubusercontent.com/$RepoName/main/SKILL.md",
        "https://raw.githubusercontent.com/$RepoName/main/$SkillName/SKILL.md"
    )

    foreach ($Candidate in $Candidates) {
        try {
            $null = Get-WebText -Url $Candidate
            return $Candidate
        }
        catch {
        }
    }

    throw '无法自动判断上游 SKILL.md 地址，请手动提供 -RawSkillUrl。'
}


function Write-Config {
    param([string]$Path, [object]$ConfigObject)
    $TempPath = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($TempPath, ($ConfigObject | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($true)))
        [IO.File]::Replace($TempPath, $Path, [NullString]::Value)
    }
    finally {
        if (Test-Path -LiteralPath $TempPath) { Remove-Item -LiteralPath $TempPath -Force }
    }
}


$Repo = if ($Repo) { $Repo.Trim().TrimEnd('/') -replace '^https://github.com/', '' -replace '\.git$', '' } else { $null }
$UpdateMutex = New-Object Threading.Mutex($false, 'Global\AgentsSkillsAutoUpdate')
$UpdateLockTaken = $false
$ConfigMutex = New-Object Threading.Mutex($false, 'Local\SkillsSourcesJsonLock')
$LockTaken = $false
$InstallBackup = ''
$MutationStarted = $false
$OriginalPolicyBytes = $null
$PolicyStatePath = $null
$OriginalStateBytes = $null
$OriginalConfigBytes = $null
$StatePath = $null
$RegistrationCommitted = $false

try {
    # Share the scheduled updater's lock so a reinstall/rollback cannot race it.
    try { $UpdateLockTaken = $UpdateMutex.WaitOne(30000) }
    catch [Threading.AbandonedMutexException] { $UpdateLockTaken = $true }
    if (-not $UpdateLockTaken) { throw '已有技能更新任务在运行，未开始安装；请在更新结束后重试。' }
    try { $LockTaken = $ConfigMutex.WaitOne(30000) }
    catch [Threading.AbandonedMutexException] { $LockTaken = $true }
    if (-not $LockTaken) { throw '等待配置写入锁超时，请稍后重试。' }

    # Read under the lock and preserve all existing entry/root metadata.
    $Config = Read-JsonFileUtf8 -Path $ConfigPath
    $ExistingEntries = @($Config.skills | Where-Object {
        $_.name -eq $Skill -or ($LocalFolder -and $_.localFolder -eq $LocalFolder)
    })
    if ($ExistingEntries.Count -gt 1) { throw '名称与目录匹配到不同的登记项，请先核对配置。' }
    $Existing = if ($ExistingEntries.Count -eq 1) { $ExistingEntries[0] } else { $null }
    if ($null -ne $Existing) {
        if ($Existing.name -ne $Skill -or $Existing.type -ne $SourceType) {
            throw '现有登记项的名称或来源类型不同；安装器不会覆盖 Git/人工维护策略。'
        }
        if ($LocalFolder -and $LocalFolder -ne $Existing.localFolder) { throw '现有登记项的目录不同。' }
        if ($SourceType -eq 'skills-cli' -and (-not $Existing.autoUpdate -or $Existing.repo -ne $Repo)) {
            throw '现有来源或人工维护策略不允许通用重装，请先人工审阅来源迁移。'
        }
        $ResolvedFolder = $Existing.localFolder
        $Entry = $Existing | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    }
    else {
        $ResolvedFolder = Resolve-LocalFolder -SkillName $Skill -ExplicitFolder $LocalFolder -AllowMissing:($Preview -or -not $SkipInstall)
        $Entry = [pscustomobject][ordered]@{
            name = $Skill; localFolder = $ResolvedFolder; type = $SourceType; autoUpdate = ($SourceType -eq 'skills-cli')
        }
        if (@($Config.skills | Where-Object { $_.localFolder -eq $ResolvedFolder }).Count -gt 0) {
            throw '该目录已由其他技能登记，停止安装。'
        }
    }
    $LocalSkillFile = Get-SafeSkillFilePath -Entry $Entry -Relative 'SKILL.md'
    $LocalPath = Get-LocalSkillPath -Entry $Entry

    if ($SourceType -eq 'skills-cli') {
        if (-not $RawSkillUrl -and $null -ne $Existing) { $RawSkillUrl = $Existing.rawSkillUrl }
        $ResolvedRawSkillUrl = Resolve-RawSkillUrl -RepoName $Repo -SkillName $Skill -ExplicitUrl $RawSkillUrl
        if ($null -ne $Existing -and $ResolvedRawSkillUrl -ne $Existing.rawSkillUrl) {
            throw '上游路径与现有登记不同，请先人工审阅来源迁移。'
        }
        foreach ($Pair in @{ repo = $Repo; skill = $Skill; rawSkillUrl = $ResolvedRawSkillUrl }.GetEnumerator()) {
            $Entry | Add-Member -NotePropertyName $Pair.Key -NotePropertyValue $Pair.Value -Force
        }
        $null = Get-SkillCliSourceLocation -Entry $Entry
    }
    elseif ($null -eq $Existing -or $ReasonWasSupplied) {
        $Entry | Add-Member -NotePropertyName reason -NotePropertyValue $Reason -Force
    }

    Write-Host "纳管模式: $SourceType；Skill: $Skill；本地目录: $ResolvedFolder"
    if ($Preview) {
        Write-Host '预览结果（不安装、不写入配置或归属清单）:'
        $Entry | ConvertTo-Json -Depth 20
        return
    }

    if ($SourceType -eq 'skills-cli') {
        if (Test-Path -LiteralPath (Join-Path $LocalPath '.git')) { throw 'skills-cli 目标含 Git 元数据，请使用 Git 管理流程。' }
        # Resolve exactly one upstream revision before any local mutation.
        $Package = Get-SkillCliSourceSnapshot -Entry $Entry
        $script:CurrentApplyMissingPatches = @()
        $ExpectedText = Apply-RoutingOverrideToText -Text $Package.EntryText -Override (Get-RoutingOverride -Entry $Entry)
        if (@($script:CurrentApplyMissingPatches).Count -gt 0) { throw '上游正文不再匹配本地补丁（patch-stale），未安装或登记。' }
        $script:CurrentApplyMissingPatches = @()
        $Plan = Get-SkillManagedRemovalPlan -Entry $Entry -ExpectedPaths @((Get-SkillCliExpectedFiles -Entry $Entry -Snapshot $Package).Keys)
        Assert-SkillRemovalPlan -Plan $Plan
    }

    $OriginalConfigBytes = [IO.File]::ReadAllBytes($ConfigPath)
    $PolicyStatePath = Get-CodexPolicyReceiptPath -Entry $Entry
    if (Test-Path -LiteralPath $PolicyStatePath) { $OriginalPolicyBytes = [IO.File]::ReadAllBytes($PolicyStatePath) }
    $StatePath = Get-SkillManifestPath -Entry $Entry
    if (Test-Path -LiteralPath $StatePath) { $OriginalStateBytes = [IO.File]::ReadAllBytes($StatePath) }
    if (Test-Path -LiteralPath $LocalPath) { $InstallBackup = New-SkillUpdateBackup -Entry $Entry }
    elseif ($SkipInstall -or $SourceType -eq 'manual') { throw "缺少本地 skill: $LocalPath" }

    if ($SourceType -eq 'skills-cli') {
        if (-not $SkipInstall) {
            $MutationStarted = $true
            Write-Host "正在安装 $Skill..."
            & npx -y skills add "$Repo@$Skill" -g -y
            if ($LASTEXITCODE -ne 0) { throw '安装 skill 失败。' }
        }
        $LocalText = Get-FileText -Path $LocalSkillFile
        if ($null -eq $LocalText -or ((Get-TextHash -Text $LocalText) -ne (Get-TextHash -Text $Package.EntryText) -and
            (Get-TextHash -Text $LocalText) -ne (Get-TextHash -Text $ExpectedText))) {
            throw '本地入口既不匹配上游，也不匹配已重放的本地覆盖；未登记。'
        }
        $MutationStarted = $true
        # Use the same routing and ownership implementation as scheduled updates.
        $null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
        $Plan = Get-SkillManagedRemovalPlan -Entry $Entry -ExpectedPaths @((Get-SkillCliExpectedFiles -Entry $Entry -Snapshot $Package).Keys)
        Remove-StaleManagedSkillFiles -Entry $Entry -Plan $Plan
        $Status = Get-SkillStatus -Entry $Entry
        if ($Status.Status -ne 'up-to-date') { throw ("安装后校验失败 [$($Status.Status)]: " + $Status.Detail) }
        Save-SkillManagedManifest -Entry $Entry
    }
    elseif (-not (Test-Path -LiteralPath $LocalSkillFile -PathType Leaf)) {
        throw "缺少本地 SKILL.md: $LocalSkillFile"
    }

    $BackupPath = "$ConfigPath.bak"
    Copy-Item -LiteralPath $ConfigPath -Destination $BackupPath -Force
    $Remaining = @($Config.skills | Where-Object { $_.name -ne $Entry.name -and $_.localFolder -ne $Entry.localFolder })
    $Config.skills = @($Remaining + $Entry | Sort-Object name)
    Write-Config -Path $ConfigPath -ConfigObject $Config
    $RegistrationCommitted = $true
    if ($SourceType -eq 'skills-cli') { Write-Host '纳管完成；已校验本地入口、资源包及适用的路由覆盖。' }
    else { Write-Host '人工纳管完成；已校验本地入口并保留人工更新策略。' }
    Write-Host "已更新配置: $ConfigPath"
    if ($InstallBackup) { Write-Host "安装前文件备份: $InstallBackup" }
}
catch {
    $Failure = $_.Exception.Message
    if (-not $RegistrationCommitted -and $MutationStarted) {
        try {
            if ($InstallBackup) { Restore-SkillUpdateBackup -Entry $Entry -BackupDirectory $InstallBackup }
            if ($PolicyStatePath) {
                if ($null -ne $OriginalPolicyBytes) { [IO.File]::WriteAllBytes($PolicyStatePath, $OriginalPolicyBytes) }
                elseif (Test-Path -LiteralPath $PolicyStatePath) { Remove-Item -LiteralPath $PolicyStatePath -Force }
            }
            if ($StatePath) {
                if ($null -ne $OriginalStateBytes) { [IO.File]::WriteAllBytes($StatePath, $OriginalStateBytes) }
                elseif (Test-Path -LiteralPath $StatePath) { Remove-Item -LiteralPath $StatePath -Force }
            }
            if ($null -ne $OriginalConfigBytes) { [IO.File]::WriteAllBytes($ConfigPath, $OriginalConfigBytes) }
        }
        catch { $Failure += '; 自动恢复未完成: ' + $_.Exception.Message }
    }
    if ($InstallBackup) { $Failure += '; 安装前备份: ' + $InstallBackup }
    throw $Failure
}
finally {
    Close-SkillPackageSession
    if ($LockTaken) { $ConfigMutex.ReleaseMutex() }
    $ConfigMutex.Dispose()
    if ($UpdateLockTaken) { $UpdateMutex.ReleaseMutex() }
    $UpdateMutex.Dispose()
}
