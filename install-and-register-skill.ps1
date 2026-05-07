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

if ($SourceType -eq 'skills-cli' -and [string]::IsNullOrWhiteSpace($Repo)) {
    throw '当 SourceType=skills-cli 时，必须提供 -Repo。'
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
    param(
        [string]$Path,
        [object[]]$Skills
    )

    $ConfigObject = [ordered]@{
        skills = $Skills
    }

    $Json = $ConfigObject | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $Json, [System.Text.UTF8Encoding]::new($true))
}

$Repo = if ($Repo) { $Repo.Trim().TrimEnd('/') -replace '^https://github.com/', '' -replace '\.git$', '' } else { $null }

Write-Host "纳管模式: $SourceType"
Write-Host "Skill 名称: $Skill"

if ($Repo) {
    Write-Host "仓库来源: $Repo"
}

if ($Preview) {
    Write-Host '当前为预览模式，不会安装，也不会写入配置。'
}

if ($SourceType -eq 'skills-cli' -and -not $SkipInstall -and -not $Preview) {
    Write-Host "正在安装 $Skill..."
    & npx -y skills add "$Repo@$Skill" -g -y
    if ($LASTEXITCODE -ne 0) {
        throw '安装 skill 失败。'
    }
}

$ResolvedFolder = Resolve-LocalFolder -SkillName $Skill -ExplicitFolder $LocalFolder -AllowMissing:$Preview
$LocalPath = Join-Path $SkillsRoot $ResolvedFolder
Write-Host "本地目录: $ResolvedFolder"

$Entry = $null

if ($SourceType -eq 'skills-cli') {
    $ResolvedRawSkillUrl = Resolve-RawSkillUrl -RepoName $Repo -SkillName $Skill -ExplicitUrl $RawSkillUrl
    Write-Host "上游 SKILL.md: $ResolvedRawSkillUrl"

    if (-not $Preview) {
        $LocalSkillFile = Join-Path $LocalPath 'SKILL.md'
        $LocalText = Get-FileText -Path $LocalSkillFile
        if ($null -eq $LocalText) {
            throw "缺少本地 SKILL.md: $LocalSkillFile"
        }

        $RemoteText = Get-WebText -Url $ResolvedRawSkillUrl
        if ($LocalText -ne $RemoteText) {
            throw '本地 skill 与上游 SKILL.md 不一致，暂不自动纳管。建议改用 -SourceType manual 登记，或者先人工确认来源和路径。'
        }
    }

    $Entry = [ordered]@{
        name       = $Skill
        localFolder = $ResolvedFolder
        type       = 'skills-cli'
        autoUpdate = $true
        repo       = $Repo
        skill      = $Skill
        rawSkillUrl = $ResolvedRawSkillUrl
    }
}
else {
    $Entry = [ordered]@{
        name       = $Skill
        localFolder = $ResolvedFolder
        type       = 'manual'
        autoUpdate = $false
        reason     = $Reason
    }
}

if ($Preview) {
    Write-Host ''
    Write-Host '预览结果（不会写入）:'
    $Entry | ConvertTo-Json -Depth 10
    exit 0
}

$Mutex = New-Object System.Threading.Mutex($false, 'Local\SkillsSourcesJsonLock')
$LockTaken = $false

try {
    $LockTaken = $Mutex.WaitOne(30000)
    if (-not $LockTaken) {
        throw '等待配置写入锁超时，请稍后重试。'
    }

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $BackupPath = "$ConfigPath.bak"
    Copy-Item -Path $ConfigPath -Destination $BackupPath -Force

    $Remaining = @(
        $Config.skills | Where-Object {
            $_.name -ne $Entry.name -and $_.localFolder -ne $Entry.localFolder
        }
    )

    $UpdatedSkills = @($Remaining + [pscustomobject]$Entry) | Sort-Object name
    Write-Config -Path $ConfigPath -Skills $UpdatedSkills
}
finally {
    if ($LockTaken) {
        $Mutex.ReleaseMutex()
    }
    $Mutex.Dispose()
}

Write-Host ''
Write-Host '纳管完成。'
Write-Host "已更新配置: $ConfigPath"
Write-Host "已生成备份: $BackupPath"
Write-Host ''
Write-Host '下一步建议：'
Write-Host '1. 运行检查命令确认状态'
Write-Host '2. 如有必要，把这个 skill 的来源和状态补到 UPDATE-SKILLS.md'
Write-Host ''
Write-Host '检查命令：'
Write-Host "powershell -ExecutionPolicy Bypass -File `"$ScriptRoot\manage-skills.ps1`" -Mode check -Only $Skill"
