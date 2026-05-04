param(
    [ValidateSet('check', 'update')]
    [string]$Mode = 'check',

    [string[]]$Only = @(),

    [switch]$IncludeManual
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [Console]::OutputEncoding

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsRoot = $ScriptRoot
$ConfigPath = Join-Path $ScriptRoot 'skills-sources.json'

if (-not (Test-Path $ConfigPath)) {
    throw "缺少配置文件: $ConfigPath"
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$Entries = @($Config.skills)

if ($Only.Count -gt 0) {
    $Wanted = @(
        $Only |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' } |
            ForEach-Object { $_.ToLowerInvariant() }
    )

    $Entries = @(
        $Entries | Where-Object {
            $Wanted -contains $_.name.ToLowerInvariant() -or
            $Wanted -contains $_.localFolder.ToLowerInvariant() -or
            ($_.PSObject.Properties.Name -contains 'skill' -and $Wanted -contains $_.skill.ToLowerInvariant())
        }
    )

    if ($Entries.Count -eq 0) {
        throw '没有匹配到 -Only 指定的 skill。'
    }
}

function Get-LocalSkillPath {
    param([object]$Entry)
    return (Join-Path $SkillsRoot $Entry.localFolder)
}

function Get-LocalSkillFile {
    param([object]$Entry)
    return (Join-Path (Get-LocalSkillPath -Entry $Entry) 'SKILL.md')
}

function Get-NormalizedText {
    param([string]$Text)
    if ($null -eq $Text) {
        return $null
    }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-FileText {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    return (Get-NormalizedText -Text ([System.IO.File]::ReadAllText($Path)))
}

function Get-WebText {
    param([string]$Url)
    $Response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 60
    return (Get-NormalizedText -Text $Response.Content)
}

function Get-FrontMatterVersion {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $FrontMatterMatch = [regex]::Match($Text, '(?ms)^---\s*(.*?)\s*---')
    if (-not $FrontMatterMatch.Success) {
        return $null
    }

    $VersionMatch = [regex]::Match($FrontMatterMatch.Groups[1].Value, '(?m)^\s*version:\s*"?([^"\r\n]+)"?')
    if ($VersionMatch.Success) {
        return $VersionMatch.Groups[1].Value.Trim()
    }

    return $null
}

function Invoke-Git {
    param(
        [string]$Path,
        [string[]]$Arguments
    )

    $Output = & git -C $Path @Arguments 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = (($Output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }
}

function Get-GitRemoteHead {
    param(
        [string]$Remote,
        [string]$Branch
    )

    $Output = & git ls-remote $Remote "refs/heads/$Branch" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (($Output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }

    $Line = ($Output | Select-Object -First 1).ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($Line)) {
        throw "No remote ref found for $Branch"
    }

    return ($Line -split "\s+")[0]
}

function Get-SkillStatus {
    param([object]$Entry)

    $FolderPath = Get-LocalSkillPath -Entry $Entry
    $SkillFile = Get-LocalSkillFile -Entry $Entry
    $Installed = Test-Path $FolderPath

    if (-not $Installed) {
        return [pscustomobject]@{
            Name      = $Entry.name
            LocalPath = $FolderPath
            Type      = $Entry.type
            Installed = $false
            Status    = 'missing'
            Detail    = 'not installed locally'
        }
    }

    switch ($Entry.type) {
        'manual' {
            return [pscustomobject]@{
                Name      = $Entry.name
                LocalPath = $FolderPath
                Type      = $Entry.type
                Installed = $true
                Status    = 'skipped'
                Detail    = $Entry.reason
            }
        }
        'git' {
            try {
                $Head = Invoke-Git -Path $FolderPath -Arguments @('rev-parse', 'HEAD')
                if ($Head.ExitCode -ne 0) {
                    throw $Head.Output
                }

                $Branch = if ($Entry.branch) { $Entry.branch } else { 'main' }
                $RemoteHead = Get-GitRemoteHead -Remote $Entry.remote -Branch $Branch
                $Dirty = Invoke-Git -Path $FolderPath -Arguments @('status', '--porcelain')
                $DirtySuffix = if (-not [string]::IsNullOrWhiteSpace($Dirty.Output)) { '; local changes present' } else { '' }
                $Status = if ($Head.Output -eq $RemoteHead) { 'up-to-date' } else { 'outdated' }

                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = $Status
                    Detail    = ("local {0}; remote {1}{2}" -f $Head.Output.Substring(0, 7), $RemoteHead.Substring(0, 7), $DirtySuffix)
                }
            }
            catch {
                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = 'error'
                    Detail    = $_.Exception.Message
                }
            }
        }
        'skills-cli' {
            try {
                $LocalText = Get-FileText -Path $SkillFile
                if ($null -eq $LocalText) {
                    throw "缺少本地文件: $SkillFile"
                }

                $RemoteText = Get-WebText -Url $Entry.rawSkillUrl
                $LocalVersion = Get-FrontMatterVersion -Text $LocalText
                $RemoteVersion = Get-FrontMatterVersion -Text $RemoteText
                $Status = if ($LocalText -eq $RemoteText) { 'up-to-date' } else { 'outdated' }

                $LocalVersionText = if ($null -ne $LocalVersion -and $LocalVersion -ne '') { $LocalVersion } else { 'n/a' }
                $RemoteVersionText = if ($null -ne $RemoteVersion -and $RemoteVersion -ne '') { $RemoteVersion } else { 'n/a' }

                $VersionDetail = if ($LocalVersion -or $RemoteVersion) {
                    "local $LocalVersionText; remote $RemoteVersionText"
                }
                else {
                    '未声明版本号'
                }

                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = $Status
                    Detail    = $VersionDetail
                }
            }
            catch {
                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = 'error'
                    Detail    = $_.Exception.Message
                }
            }
        }
        default {
            return [pscustomobject]@{
                Name      = $Entry.name
                LocalPath = $FolderPath
                Type      = $Entry.type
                Installed = $true
                Status    = 'unknown'
                Detail    = "不支持的类型: $($Entry.type)"
            }
        }
    }
}

function Update-Skill {
    param([object]$Entry)

    $Current = Get-SkillStatus -Entry $Entry
    if ($Current.Status -in @('missing', 'error')) {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'skipped'
            Status    = $Current.Status
            Detail    = $Current.Detail
        }
    }

    if ($Entry.type -eq 'manual' -and -not $IncludeManual) {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'skipped'
            Status    = 'skipped'
            Detail    = $Entry.reason
        }
    }

    if (-not $Entry.autoUpdate -and -not $IncludeManual) {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'skipped'
            Status    = 'skipped'
            Detail    = '已禁用自动更新'
        }
    }

    if ($Current.Status -eq 'up-to-date') {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'unchanged'
            Status    = 'up-to-date'
            Detail    = $Current.Detail
        }
    }

    Write-Host "正在更新 $($Entry.name)..."

    try {
        switch ($Entry.type) {
            'git' {
                $FolderPath = Get-LocalSkillPath -Entry $Entry
                $Dirty = Invoke-Git -Path $FolderPath -Arguments @('status', '--porcelain')
                if (-not [string]::IsNullOrWhiteSpace($Dirty.Output)) {
                    throw '检测到本地 Git 改动，已跳过更新'
                }

                $Branch = if ($Entry.branch) { $Entry.branch } else { 'main' }
                $Pull = Invoke-Git -Path $FolderPath -Arguments @('pull', '--ff-only', 'origin', $Branch)
                if ($Pull.ExitCode -ne 0) {
                    throw $Pull.Output
                }
            }
            'skills-cli' {
                & npx skills add "$($Entry.repo)@$($Entry.skill)" -g -y
                if ($LASTEXITCODE -ne 0) {
                    throw 'skills add 命令执行失败'
                }
            }
            default {
                throw "不支持的更新类型: $($Entry.type)"
            }
        }

        $After = Get-SkillStatus -Entry $Entry
        $Action = if ($After.Status -eq 'up-to-date') { 'updated' } else { 'failed' }

        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = $Action
            Status    = $After.Status
            Detail    = $After.Detail
        }
    }
    catch {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'failed'
            Status    = 'error'
            Detail    = $_.Exception.Message
        }
    }
}

Write-Host "Skill 管理模式: $Mode"
Write-Host "配置文件: $ConfigPath"

if ($Only.Count -gt 0) {
    Write-Host ('仅处理: ' + ($Only -join ', '))
}

$Results = @()

if ($Mode -eq 'check') {
    foreach ($Entry in $Entries) {
        $Status = Get-SkillStatus -Entry $Entry
        $Results += [pscustomobject]@{
            Name      = $Status.Name
            Type      = $Status.Type
            Installed = $Status.Installed
            Action    = 'checked'
            Status    = $Status.Status
            Detail    = $Status.Detail
        }
    }
}
else {
    foreach ($Entry in $Entries) {
        $Results += (Update-Skill -Entry $Entry)
    }
}

$SortedResults = $Results | Sort-Object Name

""
Write-Host '结果:'
$SortedResults | Format-Table Name, Type, Installed, Action, Status, Detail -AutoSize

""
Write-Host '汇总:'
$SortedResults |
    Group-Object Status |
    Sort-Object Name |
    ForEach-Object { "- $($_.Name): $($_.Count)" } |
    ForEach-Object { Write-Host $_ }
