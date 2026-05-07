param(
    [ValidateSet('check', 'update', 'apply-overrides')]
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
$OverridesPath = Join-Path $ScriptRoot 'local-routing-overrides.json'
$RoutingOverrideStart = '<!-- LOCAL ROUTING OVERRIDE START -->'
$RoutingOverrideEnd = '<!-- LOCAL ROUTING OVERRIDE END -->'

if (-not (Test-Path $ConfigPath)) {
    throw "缺少配置文件: $ConfigPath"
}

function Read-JsonFileUtf8 {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    $RawText = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($RawText | ConvertFrom-Json)
}

$Config = Read-JsonFileUtf8 -Path $ConfigPath
$Entries = @($Config.skills)

$RoutingOverrides = @{}
if (Test-Path $OverridesPath) {
    try {
        $OverridesConfig = Read-JsonFileUtf8 -Path $OverridesPath
        foreach ($Override in @($OverridesConfig.overrides)) {
            if ($null -eq $Override) {
                continue
            }

            $Key = if ($Override.localFolder) { $Override.localFolder } elseif ($Override.skill) { $Override.skill } else { $null }
            if ($null -ne $Key -and $Key -ne '') {
                $RoutingOverrides[$Key.ToLowerInvariant()] = $Override
            }
        }
    }
    catch {
        throw "读取本地路由覆盖配置失败: $OverridesPath`n$($_.Exception.Message)"
    }
}

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
    return $Text.TrimStart([char]0xFEFF).Replace("`r`n", "`n").Replace("`r", "`n")
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

function Get-RoutingOverride {
    param([object]$Entry)

    $Keys = @()
    if ($Entry.PSObject.Properties.Name -contains 'localFolder' -and $Entry.localFolder) {
        $Keys += $Entry.localFolder.ToLowerInvariant()
    }
    if ($Entry.PSObject.Properties.Name -contains 'skill' -and $Entry.skill) {
        $Keys += $Entry.skill.ToLowerInvariant()
    }
    if ($Entry.PSObject.Properties.Name -contains 'name' -and $Entry.name) {
        $Keys += $Entry.name.ToLowerInvariant()
    }

    foreach ($Key in $Keys | Select-Object -Unique) {
        if ($RoutingOverrides.ContainsKey($Key)) {
            return $RoutingOverrides[$Key]
        }
    }

    return $null
}

function Get-FrontMatterMatch {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    return [regex]::Match($Text, '(?ms)^---\s*(.*?)\s*---')
}

function Set-FrontMatterDescription {
    param(
        [string]$FrontMatter,
        [string]$Value
    )

    $Lines = $FrontMatter -split "`n"
    $OutputLines = New-Object System.Collections.Generic.List[string]
    $SingleLineValue = ((Get-NormalizedText -Text $Value) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join ' '
    $DescriptionLines = @(
        'description: >-',
        ('  ' + $SingleLineValue)
    )
    $Inserted = $false
    $SkippingDescription = $false

    foreach ($Line in $Lines) {
        if ($SkippingDescription) {
            if ($Line -match '^\s' -and $Line -notmatch '^[A-Za-z0-9_-]+:\s*') {
                continue
            }

            $SkippingDescription = $false
        }

        if ($Line -match '^description:\s*') {
            foreach ($DescriptionLine in $DescriptionLines) {
                $OutputLines.Add($DescriptionLine)
            }
            $Inserted = $true
            $SkippingDescription = $true
            continue
        }

        $OutputLines.Add($Line)
    }

    if (-not $Inserted) {
        foreach ($DescriptionLine in $DescriptionLines) {
            $OutputLines.Add($DescriptionLine)
        }
    }

    return (($OutputLines -join "`n").TrimEnd())
}

function Apply-RoutingOverrideToText {
    param(
        [string]$Text,
        [object]$Override
    )

    if ($null -eq $Override -or [string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    $TrailingNewlines = [regex]::Match($Text, '(\r?\n*)$').Groups[1].Value
    $Result = $Text
    $FrontMatterMatch = Get-FrontMatterMatch -Text $Result
    if ($null -eq $FrontMatterMatch) {
        return $Result
    }

    $FrontMatterContent = $FrontMatterMatch.Groups[1].Value
    if ($Override.PSObject.Properties.Name -contains 'description' -and -not [string]::IsNullOrWhiteSpace($Override.description)) {
        $FrontMatterContent = Set-FrontMatterDescription -FrontMatter $FrontMatterContent -Value $Override.description
    }

    $Result = $Result.Substring(0, $FrontMatterMatch.Groups[1].Index) + $FrontMatterContent + $Result.Substring($FrontMatterMatch.Groups[1].Index + $FrontMatterMatch.Groups[1].Length)

    if ($Override.PSObject.Properties.Name -contains 'usageRule' -and -not [string]::IsNullOrWhiteSpace($Override.usageRule)) {
        $UsageRuleText = Get-NormalizedText -Text $Override.usageRule
        $ManagedBlock = $RoutingOverrideStart + "`n" + $UsageRuleText + "`n" + $RoutingOverrideEnd
        $ManagedPattern = '(?ms)^<!-- LOCAL ROUTING OVERRIDE START -->\s*.*?^<!-- LOCAL ROUTING OVERRIDE END -->\s*'
        $UsagePattern = '(?ms)^## Usage Rule\s*.*?(?=^## |^# [^#]|\Z)'

        if ([regex]::IsMatch($Result, $ManagedPattern)) {
            $Result = [regex]::Replace($Result, $ManagedPattern, ($ManagedBlock + "`n`n"))
        }
        elseif ([regex]::IsMatch($Result, $UsagePattern)) {
            $Result = [regex]::Replace($Result, $UsagePattern, ($ManagedBlock + "`n`n"))
        }
        else {
            $FrontMatterEnd = [regex]::Match($Result, '(?ms)^---\s*.*?\s*---')
            if ($FrontMatterEnd.Success) {
                $InsertAt = $FrontMatterEnd.Index + $FrontMatterEnd.Length
                $Result = $Result.Substring(0, $InsertAt) + "`n`n" + $ManagedBlock + "`n`n" + $Result.Substring($InsertAt).TrimStart("`r", "`n")
            }
        }
    }

    $Result = [regex]::Replace($Result, '(\n){3,}', "`n`n")

    return ($Result.TrimEnd("`r", "`n") + $TrailingNewlines)
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-TextHash {
    param([string]$Text)

    $Normalized = if ($null -eq $Text) { '' } else { $Text.TrimEnd("`r", "`n") }
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Normalized)
    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $HashBytes = $Sha.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($HashBytes) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $Sha.Dispose()
    }
}

function Apply-RoutingOverrideToLocalSkill {
    param([object]$Entry)

    $Override = Get-RoutingOverride -Entry $Entry
    if ($null -eq $Override) {
        return $false
    }

    $SkillFile = Get-LocalSkillFile -Entry $Entry
    $LocalText = Get-FileText -Path $SkillFile
    if ($null -eq $LocalText) {
        throw "缺少本地文件: $SkillFile"
    }

    $UpdatedText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
    if ($UpdatedText -ne $LocalText) {
        Write-TextFile -Path $SkillFile -Text $UpdatedText
        return $true
    }

    return $false
}

function Invoke-ApplyOverrides {
    param([object[]]$TargetEntries)

    $ApplyResults = @()

    foreach ($Entry in $TargetEntries) {
        $Override = Get-RoutingOverride -Entry $Entry
        if ($null -eq $Override) {
            $ApplyResults += [pscustomobject]@{
                Name      = $Entry.name
                Type      = $Entry.type
                Installed = (Test-Path (Get-LocalSkillPath -Entry $Entry))
                Action    = 'skipped'
                Status    = 'skipped'
                Detail    = '没有本地 override'
            }
            continue
        }

        try {
            $Changed = Apply-RoutingOverrideToLocalSkill -Entry $Entry
            $ApplyResults += [pscustomobject]@{
                Name      = $Entry.name
                Type      = $Entry.type
                Installed = (Test-Path (Get-LocalSkillPath -Entry $Entry))
                Action    = if ($Changed) { 'applied' } else { 'unchanged' }
                Status    = 'up-to-date'
                Detail    = '已应用本地 override'
            }
        }
        catch {
            $ApplyResults += [pscustomobject]@{
                Name      = $Entry.name
                Type      = $Entry.type
                Installed = (Test-Path (Get-LocalSkillPath -Entry $Entry))
                Action    = 'failed'
                Status    = 'error'
                Detail    = $_.Exception.Message
            }
        }
    }

    return $ApplyResults
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
                $Override = Get-RoutingOverride -Entry $Entry
                $NormalizedLocalText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
                $ExpectedLocalText = Apply-RoutingOverrideToText -Text $RemoteText -Override $Override
                $LocalVersion = Get-FrontMatterVersion -Text $LocalText
                $RemoteVersion = Get-FrontMatterVersion -Text $RemoteText
                $Status = if ((Get-TextHash -Text $NormalizedLocalText) -eq (Get-TextHash -Text $ExpectedLocalText)) { 'up-to-date' } else { 'outdated' }

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

                $null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
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
elseif ($Mode -eq 'apply-overrides') {
    $Results = @(Invoke-ApplyOverrides -TargetEntries $Entries)
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
