Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [Console]::OutputEncoding

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Installer = Join-Path $ScriptRoot 'install-and-register-skill.ps1'

if (-not (Test-Path $Installer)) {
    throw "缺少脚本: $Installer"
}

Write-Host ''
Write-Host '================================' -ForegroundColor Cyan
Write-Host '       注册并纳管新 Skill' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '说明：'
Write-Host '1. 适合来源明确、只安装单个 skill 的情况'
Write-Host '2. 会调用 install-and-register-skill.ps1'
Write-Host '3. 建议先输入 GitHub 仓库，例如：tw93/Waza'
Write-Host '4. 再输入 skill 名，例如：health'
Write-Host ''
Write-Host '仓库正确示例：' -ForegroundColor Green
Write-Host '  tw93/Waza'
Write-Host '  https://github.com/tw93/Waza'
Write-Host '  https://github.com/tw93/Waza.git'
Write-Host ''
Write-Host '仓库错误示例：' -ForegroundColor Yellow
Write-Host '  health'
Write-Host '  https://raw.githubusercontent.com/tw93/Waza/main/skills/health/SKILL.md'
Write-Host '  https://skills.sh/tw93/Waza/health'
Write-Host ''
Write-Host 'skill 名正确示例：' -ForegroundColor Green
Write-Host '  health'
Write-Host '  create-crush'
Write-Host '  luo-xiang-perspective'
Write-Host ''

function Test-LooksLikeRepo {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $Trimmed = $Value.Trim()
    if ($Trimmed -match '^https://github\.com/[^/]+/[^/]+/?(?:\.git)?$') {
        return $true
    }

    if ($Trimmed -match '^[^/\s]+/[^/\s]+/?$') {
        return $true
    }

    return $false
}

function Test-LooksLikeWrongRepoInput {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $Trimmed = $Value.Trim()
    return (
        $Trimmed -match '^https://raw\.githubusercontent\.com/' -or
        $Trimmed -match '^https://skills\.sh/' -or
        ($Trimmed -notmatch '/' -and $Trimmed -notmatch '^https://github\.com/')
    )
}

function Test-LooksLikeSkillName {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return $Value.Trim() -match '^[A-Za-z0-9][A-Za-z0-9\-]*$'
}

$Repo = Read-Host '请输入 GitHub 仓库（owner/repo）'
if ([string]::IsNullOrWhiteSpace($Repo)) {
    Write-Host ''
    Write-Host '未输入仓库，已取消。' -ForegroundColor Yellow
    exit 1
}

if (Test-LooksLikeWrongRepoInput -Value $Repo) {
    Write-Host ''
    Write-Host '你填的内容看起来不像 GitHub 仓库。' -ForegroundColor Yellow
    Write-Host '仓库这里应填写 owner/repo 或完整 GitHub 仓库链接。' -ForegroundColor Yellow
    Write-Host '例如：tw93/Waza 或 https://github.com/tw93/Waza' -ForegroundColor Yellow
    exit 1
}

if (-not (Test-LooksLikeRepo -Value $Repo)) {
    Write-Host ''
    Write-Host '仓库格式无法识别，已取消。' -ForegroundColor Yellow
    Write-Host '请填写 owner/repo 或完整 GitHub 仓库链接。' -ForegroundColor Yellow
    exit 1
}

$Skill = Read-Host '请输入 skill 名'
if ([string]::IsNullOrWhiteSpace($Skill)) {
    Write-Host ''
    Write-Host '未输入 skill 名，已取消。' -ForegroundColor Yellow
    exit 1
}

if (-not (Test-LooksLikeSkillName -Value $Skill)) {
    Write-Host ''
    Write-Host 'skill 名格式看起来不对，已取消。' -ForegroundColor Yellow
    Write-Host '这里通常填写 health、create-crush、seo-audit 这种 skill 名。' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host '是否只做预览，不真正写入配置？'
Write-Host '输入 Y 表示只预览，直接回车表示真实执行。'
$PreviewInput = Read-Host '预览模式 [Y/N]'

$Arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $Installer,
    '-SourceType', 'skills-cli',
    '-Repo', $Repo.Trim(),
    '-Skill', $Skill.Trim()
)

if ($PreviewInput -match '^(?i)y(?:es)?$') {
    $Arguments += '-Preview'
}

Write-Host ''
& powershell @Arguments
exit $LASTEXITCODE
