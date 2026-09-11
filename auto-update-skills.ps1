<#
.SYNOPSIS
    Unattended updater for the global .agents skill tree.

.DESCRIPTION
    Runs the two update flows that are currently driven by desktop shortcuts:
      1. impeccable  -> update-impeccable.ps1 (preview, then apply)
      2. everything  -> manage-skills.ps1 -Mode update

    Designed to be launched by a Scheduled Task with no console attached, so it
    never prompts, never pauses, and never waits for stdin.

    Safety model (deliberately conservative):
      * impeccable is validated in `preview` mode FIRST. Preview builds a
        candidate copy in %TEMP% and checks bundle structure, command
        references, local patch anchors, routing overrides and node syntax.
        Only a clean preview is allowed to reach `apply`.
      * Any validation failure ABORTS the update. The installed copy under
        .agents\skills\impeccable is left exactly as it was.
      * Failures are classified and written to logs\LATEST-STATUS.md plus
        logs\last-status.json, and surfaced as a Windows balloon tip when they
        need a human (e.g. upstream restructured and broke a patch anchor).
      * Transient conditions (network down, timeout) are logged but stay quiet,
        because the next scheduled run will retry on its own.

    This script does NOT modify update-impeccable.ps1 or manage-skills.ps1.

.PARAMETER DryRun
    Validate only. Runs impeccable `preview` and manage-skills `check`.
    No active skill directory is written to.

    Note that the upstream Git cache under .agents\external is still refreshed,
    including `reset --hard` and `clean -fdx` when it is dirty — preview has to
    run against current upstream to mean anything. Pass -NoCacheRepair as well
    if the cache must not be touched at all.

.PARAMETER ImpeccableOnly / SkillsOnly
    Restrict the run to one of the two flows.

.PARAMETER NoNotify
    Suppress the Windows balloon tip (the status files are still written).

.PARAMETER NoCacheRepair
    Skip the upstream Git cache self-heal pass.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\auto-update-skills.ps1 -DryRun

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File .\auto-update-skills.ps1
#>
param(
    [switch]$DryRun,
    [switch]$ImpeccableOnly,
    [switch]$SkillsOnly,
    [switch]$NoNotify,
    [switch]$NoCacheRepair,
    [int]$GitTimeoutSec = 180,
    [int]$ImpeccableTimeoutSec = 900,
    [int]$SkillsTimeoutSec = 2400,
    [int]$LogRetention = 40,

    # Seconds to keep the tray icon alive so the balloon stays on screen.
    # Only applies to interactive runs; disposing sooner would hide the balloon.
    [int]$NotifyDwellSec = 3,

    # Session-independent attention signal. Appears only when a run needs a
    # human and is cleared automatically once a run comes back clean.
    [string]$AttentionFlagPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Skills 需要处理.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [Console]::OutputEncoding

# ---------------------------------------------------------------- paths ----
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$UpdateImpeccablePath = Join-Path $ScriptRoot 'update-impeccable.ps1'
$ManageSkillsPath     = Join-Path $ScriptRoot 'manage-skills.ps1'
$LocalSkillDir        = Join-Path $ScriptRoot 'impeccable'
$SkillName            = 'impeccable'

$RepoUrl        = 'https://github.com/pbakaus/impeccable.git'
$Branch         = 'main'
$UpstreamSubdir = '.agents/skills/impeccable'

$ExternalRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\external'
$CacheDir     = Join-Path $ExternalRoot 'impeccable-upstream'
$BackupRoot   = Join-Path $ExternalRoot 'impeccable-backups'

$LogDir      = Join-Path $ScriptRoot 'logs'
$LogPath     = Join-Path $LogDir ('auto-update-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$StatusJson  = Join-Path $LogDir 'last-status.json'
$StatusMarkdown = Join-Path $LogDir 'LATEST-STATUS.md'

if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ------------------------------------------------------------- logging ----
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $Line = ('[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message)
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
    Write-Host $Line
}

function Write-LogBlock {
    param([string]$Text)

    # Full, unabridged output goes to the log file; the console gets the same
    # short tail the status report uses. Get-Excerpt alone would have thrown
    # away the evidence — the 32-row manage-skills table is exactly what
    # someone needs when diagnosing a failed unattended run — while writing the
    # whole thing to the console would bury the step markers.
    if ([string]::IsNullOrWhiteSpace($Text)) {
        # Record the silence explicitly. An empty gap in the log is ambiguous:
        # it could mean the child printed nothing, or that the logging itself
        # was skipped.
        Add-Content -LiteralPath $LogPath -Value '(无输出)' -Encoding UTF8
        Write-Host '(无输出)'
        return
    }
    Add-Content -LiteralPath $LogPath -Value $Text -Encoding UTF8
    Write-Host (Get-Excerpt -Text $Text)
}

function ConvertTo-CommandLineArgument {
    param([string]$Value)

    # ProcessStartInfo.Arguments is a single string on .NET Framework, so
    # quoting has to be done by hand: double any backslash run that precedes a
    # quote, then wrap in quotes when the value contains whitespace or a quote.
    if ($Value -notmatch '[\s"]') { return $Value }

    $Escaped = $Value -replace '(\\*)"', '$1$1\"'

    # A trailing backslash run must also be doubled, otherwise the closing quote
    # we are about to append gets escaped by it and the argument swallows
    # whatever follows: C:\some path\ would become "C:\some path\" -> the quote
    # is consumed and parsing runs on into the next argument.
    $Escaped = $Escaped -replace '(\\+)$', '$1$1'

    return '"' + $Escaped + '"'
}

function Invoke-Step {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [int]$TimeoutSec = 600,
        [string]$WorkingDirectory = $ScriptRoot
    )

    # Built on System.Diagnostics.Process instead of Start-Process on purpose.
    # Start-Process -RedirectStandardOutput throws "An item with the same key
    # has already been added" whenever the inherited environment carries a
    # case-duplicated PATH (a host that injects `PATH` alongside Windows'
    # `Path`). That is fatal here, because this function is used to spawn
    # nested processes. ProcessStartInfo is left otherwise untouched, so the
    # environment is inherited verbatim with no dictionary copy.
    $ArgumentLine = (@($Arguments | ForEach-Object { ConvertTo-CommandLineArgument -Value $_ })) -join ' '

    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $FilePath
    $StartInfo.Arguments = $ArgumentLine
    $StartInfo.WorkingDirectory = $WorkingDirectory
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $StartInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo

    try {
        $null = $Process.Start()

        # Both streams are drained concurrently. Reading them one after the
        # other deadlocks as soon as the child fills one pipe buffer while we
        # are blocked waiting on the other.
        $StdOutTask = $Process.StandardOutput.ReadToEndAsync()
        $StdErrTask = $Process.StandardError.ReadToEndAsync()

        $TimedOut = -not $Process.WaitForExit($TimeoutSec * 1000)
        if ($TimedOut) {
            try { $null = & taskkill /T /F /PID $Process.Id 2>&1 } catch {}
            $null = $Process.WaitForExit(5000)
        }

        # Bounded drain. GetAwaiter().GetResult() waits forever, and the pipe
        # only closes once every handle to it is gone — a surviving grandchild
        # that inherited the handle would therefore hang the very function that
        # exists to enforce a timeout.
        $StdOutText = if ($StdOutTask.Wait(10000)) { $StdOutTask.Result } else { '' }
        $StdErrText = if ($StdErrTask.Wait(10000)) { $StdErrTask.Result } else { '' }

        $ExitCode = if ($TimedOut) { $null } else { $Process.ExitCode }

        $Segments = New-Object System.Collections.Generic.List[string]
        foreach ($Text in @($StdOutText, $StdErrText)) {
            if (-not [string]::IsNullOrWhiteSpace($Text)) {
                $Segments.Add($Text.Trim())
            }
        }

        $Output = ($Segments -join "`n").Trim()
        if ($TimedOut) {
            $Note = "$FilePath 超过 $TimeoutSec 秒未返回，已终止进程树"
            $Output = if ([string]::IsNullOrWhiteSpace($Output)) { $Note } else { "$Note`n$Output" }
        }

        return [pscustomobject]@{
            ExitCode = $ExitCode
            Output   = $Output
            TimedOut = $TimedOut
        }
    }
    finally {
        try { $Process.Dispose() } catch {}
    }
}

# --------------------------------------------------- failure taxonomy -----
# Each category maps to whether a human has to intervene. Transient conditions
# (network, timeout) self-heal on the next scheduled run, so they are logged but
# never surfaced as a notification.
$FailureCatalog = @{
    'cache-dirty'                = @{ NeedsHuman = $false; Hint = '上游 Git 缓存有本地改动，已自动重置；下次运行即恢复。' }
    'network'                    = @{ NeedsHuman = $false; Hint = '网络不可用或传输中断，属于瞬时故障，下次计划运行会自动重试。' }
    'timeout'                    = @{ NeedsHuman = $false; Hint = '步骤超时被终止，下次计划运行会自动重试。' }
    'upstream-layout-changed'    = @{ NeedsHuman = $true;  Hint = '上游仓库变更了目录结构，已找不到 .agents/skills/impeccable。需要人工确认新路径后更新本脚本的候选路径。' }
    'upstream-structure-invalid' = @{ NeedsHuman = $true;  Hint = '上游 skill 包结构不完整（缺少必需目录或命令参考文件），已拒绝覆盖本地版本。' }
    'upstream-script-broken'     = @{ NeedsHuman = $true;  Hint = '上游 scripts 下的 .mjs/.js 未通过 node --check，已拒绝覆盖本地版本。' }
    'patch-anchor-drift'         = @{ NeedsHuman = $true;  Hint = '本地补丁的 find 锚点在上游正文中已匹配不到（上游改写了对应内容）。需要人工重写 impeccable-local-patches.json 中的锚点。' }
    'routing-anchor-drift'       = @{ NeedsHuman = $true;  Hint = 'local-routing-overrides.json 里 impeccable 的 bodyPatch 锚点已失效，需要人工重写。' }
    'git-diverged'               = @{ NeedsHuman = $true;  Hint = '上游缓存与远端分叉，自动修复未成功，需要人工检查该缓存仓库。' }
    'env-git-missing'            = @{ NeedsHuman = $true;  Hint = '找不到 git，无法拉取上游。' }
    'env-node-missing'           = @{ NeedsHuman = $true;  Hint = '找不到 node，无法完成脚本语法校验。' }
    'missing-dependency'         = @{ NeedsHuman = $true;  Hint = '缺少被依赖的脚本文件。' }
    'unknown'                    = @{ NeedsHuman = $true;  Hint = '未分类错误，请查看日志。' }
}

function Test-NeedsHuman {
    param([string]$Category)

    if ([string]::IsNullOrWhiteSpace($Category)) { return $false }
    if (-not $FailureCatalog.ContainsKey($Category)) { return $true }
    return [bool]$FailureCatalog[$Category].NeedsHuman
}

function Get-FailureHint {
    param([string]$Category)

    if ([string]::IsNullOrWhiteSpace($Category)) { return '' }
    if (-not $FailureCatalog.ContainsKey($Category)) { return [string]$FailureCatalog['unknown'].Hint }
    return [string]$FailureCatalog[$Category].Hint
}

function Get-FailureCategory {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return 'unknown' }

    if ($Text -match 'Git cache has local changes')                       { return 'cache-dirty' }
    if ($Text -match 'does not contain expected skill directory')         { return 'upstream-layout-changed' }
    if ($Text -match 'local patch anchors missing')                       { return 'patch-anchor-drift' }
    if ($Text -match 'routing bodyPatch anchors missing')                 { return 'routing-anchor-drift' }
    if ($Text -match 'missing command references')                        { return 'upstream-structure-invalid' }
    if ($Text -match 'missing required paths')                            { return 'upstream-structure-invalid' }
    if ($Text -match 'bundle structure is invalid')                       { return 'upstream-structure-invalid' }
    if ($Text -match 'script syntax failures')                            { return 'upstream-script-broken' }
    if ($Text -match 'node executable not found')                         { return 'env-node-missing' }
    if ($Text -match 'git is required')                                   { return 'env-git-missing' }
    if ($Text -match 'Missing update script|Missing manage-skills')       { return 'missing-dependency' }
    if ($Text -match 'non-fast-forward|would clobber|not possible to fast-forward') { return 'git-diverged' }
    if ($Text -match 'Could not resolve host|Failed to connect|timed out|Operation too slow|early EOF|RPC failed|unable to access') { return 'network' }
    if ($Text -match '超过 \d+ 秒未返回')                                  { return 'timeout' }

    return 'unknown'
}

function Get-Excerpt {
    param(
        [string]$Text,
        [int]$MaxLength = 600,
        [int]$MaxLines = 12
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return '(无输出)' }

    $Lines = @($Text -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' })
    $Joined = ($Lines | Select-Object -Last $MaxLines) -join "`n"
    if ($Joined.Length -gt $MaxLength) {
        return ($Joined.Substring($Joined.Length - $MaxLength))
    }
    return $Joined
}

# ------------------------------------------------------ git cache care ----
function Repair-GitCache {
    param(
        [string]$CacheDir,
        [string]$RepoUrl,
        [string]$Branch,
        [int]$GitTimeoutSec
    )

    $Actions = New-Object System.Collections.Generic.List[string]
    $GitArgs = @('-c', 'http.lowSpeedLimit=1000', '-c', "http.lowSpeedTime=$GitTimeoutSec")
    $EnvVars = @{ GIT_TERMINAL_PROMPT = '0'; GIT_ASKPASS = ''; SSH_ASKPASS = '' }

    # Restore happens in a finally block because the child processes inherit
    # this process environment.
    $Saved = @{}
    foreach ($Key in $EnvVars.Keys) {
        $Saved[$Key] = [Environment]::GetEnvironmentVariable($Key, 'Process')
        [Environment]::SetEnvironmentVariable($Key, $EnvVars[$Key], 'Process')
    }

    try {
        $CacheExists = Test-Path -LiteralPath $CacheDir
        if ($CacheExists -and -not (Test-Path -LiteralPath (Join-Path $CacheDir '.git'))) {
            Write-Log '缓存目录存在但不是 Git 仓库，删除后重新克隆。' 'WARN'
            Remove-Item -LiteralPath $CacheDir -Recurse -Force
            $CacheExists = $false
            $Actions.Add('removed-invalid-cache')
        }

        if (-not $CacheExists) {
            Write-Log "首次克隆上游缓存: $RepoUrl -> $CacheDir"
            $Clone = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('clone', '--branch', $Branch, '--single-branch', $RepoUrl, $CacheDir)) -TimeoutSec ($GitTimeoutSec * 3)
            if ($Clone.ExitCode -ne 0) {
                return [pscustomobject]@{
                    Ok      = $false
                    Actions = $Actions.ToArray()
                    Output  = $Clone.Output
                }
            }
            $Actions.Add('cloned')
        }
        else {
            $Dirty = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('-C', $CacheDir, 'status', '--porcelain')) -TimeoutSec $GitTimeoutSec
            if ($Dirty.ExitCode -ne 0) {
                return [pscustomobject]@{ Ok = $false; Actions = $Actions.ToArray(); Output = $Dirty.Output }
            }
            if (-not [string]::IsNullOrWhiteSpace($Dirty.Output)) {
                Write-Log '缓存存在本地改动，执行 reset --hard + clean -fdx。' 'WARN'
                $null = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('-C', $CacheDir, 'reset', '--hard', 'HEAD')) -TimeoutSec $GitTimeoutSec
                $null = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('-C', $CacheDir, 'clean', '-fdx')) -TimeoutSec $GitTimeoutSec
                $Actions.Add('reset-dirty-cache')
            }
        }

        $Fetch = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('-C', $CacheDir, 'fetch', '--prune', 'origin', $Branch)) -TimeoutSec ($GitTimeoutSec * 2)
        if ($Fetch.ExitCode -ne 0) {
            return [pscustomobject]@{ Ok = $false; Actions = $Actions.ToArray(); Output = $Fetch.Output }
        }
        $Actions.Add('fetched')

        # reset --hard origin/<branch> instead of pull --ff-only: the cache is a
        # pure mirror we never edit, so this also survives an upstream
        # force-push, which is exactly what `pull --ff-only` would die on.
        $null = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('-C', $CacheDir, 'checkout', '-f', $Branch)) -TimeoutSec $GitTimeoutSec
        $Reset = Invoke-Step -FilePath 'git' -Arguments ($GitArgs + @('-C', $CacheDir, 'reset', '--hard', "origin/$Branch")) -TimeoutSec $GitTimeoutSec
        if ($Reset.ExitCode -ne 0) {
            return [pscustomobject]@{ Ok = $false; Actions = $Actions.ToArray(); Output = $Reset.Output }
        }
        $Actions.Add('reset-to-origin')

        return [pscustomobject]@{ Ok = $true; Actions = $Actions.ToArray(); Output = '' }
    }
    finally {
        foreach ($Key in $Saved.Keys) {
            [Environment]::SetEnvironmentVariable($Key, $Saved[$Key], 'Process')
        }
    }
}

function Test-ImpeccableSourceDir {
    param([string]$Path)

    return (
        (Test-Path -LiteralPath (Join-Path $Path 'SKILL.md')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'reference')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'scripts')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'agents'))
    )
}

function Resolve-UpstreamSkillDir {
    param(
        [string]$CacheDir,
        [string]$UpstreamSubdir
    )

    $Primary = Join-Path $CacheDir ($UpstreamSubdir -replace '/', '\')
    if (Test-ImpeccableSourceDir -Path $Primary) {
        return [pscustomobject]@{ Path = $Primary; Fallback = $false }
    }

    # Upstream restructured. Look for any directory named `impeccable` that
    # still has the expected shape, excluding .git internals.
    $Candidates = @(
        Get-ChildItem -LiteralPath $CacheDir -Recurse -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'impeccable' -and $_.FullName -notmatch '\\\.git\\' } |
            Sort-Object { $_.FullName.Length }
    )

    foreach ($Candidate in $Candidates) {
        if (Test-ImpeccableSourceDir -Path $Candidate.FullName) {
            return [pscustomobject]@{ Path = $Candidate.FullName; Fallback = $true }
        }
    }

    return $null
}

# ---------------------------------------------------------- roll-back ----
function Restore-LatestBackup {
    param(
        [string]$BackupRoot,
        [string]$LocalSkillDir
    )

    if (-not (Test-Path -LiteralPath $BackupRoot)) {
        return [pscustomobject]@{ Ok = $false; Detail = '备份目录不存在，无法回滚。' }
    }

    $Latest = @(
        Get-ChildItem -LiteralPath $BackupRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1
    )

    if ($Latest.Count -eq 0) {
        return [pscustomobject]@{ Ok = $false; Detail = '备份目录为空，无法回滚。' }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $Latest[0].FullName 'SKILL.md'))) {
        return [pscustomobject]@{ Ok = $false; Detail = "最新备份不完整: $($Latest[0].FullName)" }
    }

    if (Test-Path -LiteralPath $LocalSkillDir) {
        Remove-Item -LiteralPath $LocalSkillDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $LocalSkillDir -Force | Out-Null
    Get-ChildItem -LiteralPath $Latest[0].FullName -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $LocalSkillDir -Recurse -Force
    }

    return [pscustomobject]@{ Ok = $true; Detail = "已从备份恢复: $($Latest[0].FullName)" }
}

function Set-AttentionFlag {
    param(
        [string]$Path,
        [string[]]$Messages,
        [string]$StatusMarkdown,
        [string]$LogPath
    )

    # Session-independent fallback for "a human needs to look at this".
    #
    # Balloons and toasts both require an interactive session, so a task running
    # under "whether or not the user is logged on" (Session 0) can never reach
    # the desktop — the run would fail silently no matter which notification
    # library is used. A file, on the other hand, always lands. It sits on the
    # Desktop where it cannot be missed, and is removed again automatically on
    # the next healthy run, so its mere presence is the signal.
    try {
        if ($Messages.Count -eq 0) {
            if (Test-Path -LiteralPath $Path) {
                Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
                Write-Log '本次无需人工处理，已移除桌面提示文件。'
            }
            return
        }

        $Body = New-Object System.Collections.Generic.List[string]
        $Body.Add('Skills 自动更新需要你处理')
        $Body.Add('')
        $Body.Add(('发现时间: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
        $Body.Add('')
        $Body.Add('原因:')
        foreach ($Message in $Messages) { $Body.Add("  - $Message") }
        $Body.Add('')
        $Body.Add('怎么看:')
        $Body.Add("  状态摘要  $StatusMarkdown")
        $Body.Add("  完整日志  $LogPath")
        $Body.Add('')
        $Body.Add('处理完成后本文件会在下一次正常运行时自动消失，不用手动删。')

        [System.IO.File]::WriteAllText($Path, ($Body -join "`r`n"), (New-Object System.Text.UTF8Encoding $true))
        Write-Log "已写出桌面提示文件: $Path" 'WARN'
    }
    catch {
        Write-Log ('桌面提示文件处理失败: ' + $_.Exception.Message) 'WARN'
    }
}

# --------------------------------------------------------- notification --
function Show-BalloonTip {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    # Best effort only. A scheduled task that runs with no interactive session
    # simply gets no toast; the status files are the durable record.
    #
    # Bail out before doing anything when there is no interactive session: the
    # balloon cannot appear there, so loading WinForms and then sleeping just to
    # keep an invisible tray icon alive is pure dead time on every run.
    if (-not [Environment]::UserInteractive) {
        Write-Log '无交互会话，跳过气泡通知（状态文件仍已写入）。' 'WARN'
        return
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $Notify = New-Object System.Windows.Forms.NotifyIcon
        $Notify.Icon = [System.Drawing.SystemIcons]::Information
        $Notify.BalloonTipTitle = $Title
        $Notify.BalloonTipText = $Message
        $Notify.BalloonTipIcon = $Level
        $Notify.Visible = $true
        $Notify.ShowBalloonTip(20000)
        # Disposing removes the balloon, so the icon has to outlive the call
        # briefly. Kept short: this blocks an otherwise finished manual run.
        Start-Sleep -Seconds $NotifyDwellSec
        $Notify.Dispose()
    }
    catch {
        Write-Log ("通知不可用（无交互会话或缺少程序集）: " + $_.Exception.Message) 'WARN'
    }
}

# ============================================================== main ======
# Single-instance guard. This script is meant to run from a Scheduled Task, so
# a slow run (a cold npm install can take minutes) can still be going when the
# next trigger fires. Two concurrent runs would both invoke
# `manage-skills.ps1 -Mode update`, and therefore two concurrent
# `npx skills add -g` writing into the same global skill tree.
#
# WaitOne(0) means "take it or leave immediately" — a second instance exits
# quietly rather than queueing up. AbandonedMutexException must be handled:
# when a previous run is force-killed the mutex is abandoned, and the next
# WaitOne throws instead of returning. Catching it means we inherit the lock,
# which is the correct outcome — the previous owner is gone.
#
# The constructor is inside the try as well: under "run whether or not the user
# is logged on" the task lands in Session 0, where creating a Global\ object can
# be denied. An exception there would escape before any status file is written,
# turning a permission problem into a silent no-op. Losing the lock is far less
# bad than losing the run, so that case degrades to running unlocked.
$UpdateMutex = $null
$HasMutex = $false
try {
    $UpdateMutex = New-Object System.Threading.Mutex($false, 'Global\AgentsSkillsAutoUpdate')
    $HasMutex = $UpdateMutex.WaitOne(0)
}
catch [System.Threading.AbandonedMutexException] {
    $HasMutex = $true
}
catch {
    Write-Log ('无法建立单实例互斥锁，降级为不加锁运行: ' + $_.Exception.Message) 'WARN'
    if ($null -ne $UpdateMutex) {
        try { $UpdateMutex.Dispose() } catch {}
        $UpdateMutex = $null
    }
    $HasMutex = $true
}

if (-not $HasMutex) {
    Write-Log '已有一个自动更新实例在运行，本次退出（不排队）。' 'WARN'
    $UpdateMutex.Dispose()
    exit 0
}

try {

$Steps = New-Object System.Collections.Generic.List[object]
$StartedAt = Get-Date
$ExitCode = 0
$NotifyTitle = 'Skills 自动更新'
$NotifyMessages = New-Object System.Collections.Generic.List[string]

Write-Log '=================================================================='
Write-Log "Skills 自动更新开始 (DryRun=$DryRun, ImpeccableOnly=$ImpeccableOnly, SkillsOnly=$SkillsOnly)"
Write-Log "脚本目录: $ScriptRoot"
Write-Log "日志文件: $LogPath"

function Add-Step {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Category = '',
        [string]$Detail = ''
    )

    $script:Steps.Add([pscustomobject]@{
        Name     = $Name
        Status   = $Status
        Category = $Category
        Detail   = $Detail
    })
}

# ------------------------------------------------------- 1. impeccable ---
if (-not $SkillsOnly) {
    Write-Log '--- 步骤 1/2: impeccable ---'

    try {

    if (-not (Test-Path -LiteralPath $UpdateImpeccablePath)) {
        Add-Step -Name 'impeccable' -Status 'error' -Category 'missing-dependency' -Detail "缺少脚本: $UpdateImpeccablePath"
        $ExitCode = 1
    }
    else {
        $SourcePath = ''
        $LayoutFallback = $false
        $SkipImpeccable = $false

        if (-not $NoCacheRepair) {
            Write-Log '刷新上游 Git 缓存（自动修复脏缓存 / 分叉 / 强制推送）。'
            $Repair = Repair-GitCache -CacheDir $CacheDir -RepoUrl $RepoUrl -Branch $Branch -GitTimeoutSec $GitTimeoutSec
            if ($Repair.Ok) {
                Write-Log ("缓存就绪: " + (@($Repair.Actions) -join ', ')) 'OK'
            }
            else {
                $Category = Get-FailureCategory -Text $Repair.Output
                Write-Log "缓存刷新失败 [$Category]" 'ERROR'
                Write-Log (Get-Excerpt -Text $Repair.Output)
                Add-Step -Name 'impeccable' -Status 'blocked' -Category $Category -Detail (Get-Excerpt -Text $Repair.Output -MaxLength 400)
                if (Test-NeedsHuman -Category $Category) {
                    $NotifyMessages.Add("impeccable 未更新：上游缓存刷新失败（$Category）。")
                }
                $ExitCode = 1
                $SkipImpeccable = $true
            }
        }

        if (-not $SkipImpeccable) {
            $Resolved = Resolve-UpstreamSkillDir -CacheDir $CacheDir -UpstreamSubdir $UpstreamSubdir
            if ($null -eq $Resolved) {
                Write-Log '上游缓存中找不到符合预期的 skill 目录，停止更新，本地版本保持不变。' 'ERROR'
                Add-Step -Name 'impeccable' -Status 'blocked' -Category 'upstream-layout-changed' -Detail "在 $CacheDir 中未找到包含 SKILL.md/reference/scripts/agents 的 impeccable 目录"
                $NotifyMessages.Add('impeccable 未更新：上游目录结构已变更。')
                $ExitCode = 1
                $SkipImpeccable = $true
            }
            elseif ($Resolved.Fallback) {
                # Upstream moved the skill. Pass the new location explicitly:
                # update-impeccable.ps1 accepts a direct skill directory.
                Write-Log "上游目录结构已变更，改用探测到的路径: $($Resolved.Path)" 'WARN'
                $SourcePath = $Resolved.Path
                $LayoutFallback = $true
            }
        }

        if (-not $SkipImpeccable) {
            $PreviewArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $UpdateImpeccablePath, '-Mode', 'preview')
            if ($SourcePath -ne '') { $PreviewArgs += @('-SourcePath', $SourcePath) }

            Write-Log '运行 impeccable preview（只读校验，不改动本地文件）。'
            $Preview = Invoke-Step -FilePath 'powershell.exe' -Arguments $PreviewArgs -TimeoutSec $ImpeccableTimeoutSec
            Write-LogBlock -Text $Preview.Output

            if ($Preview.ExitCode -ne 0) {
                $Category = Get-FailureCategory -Text $Preview.Output
                Write-Log "preview 校验未通过 [$Category]，已停止，本地 impeccable 保持不变。" 'ERROR'
                Add-Step -Name 'impeccable' -Status 'blocked' -Category $Category -Detail (Get-Excerpt -Text $Preview.Output -MaxLength 400)
                if (Test-NeedsHuman -Category $Category) {
                    $NotifyMessages.Add("impeccable 未更新：$Category（已保留当前版本）。")
                }
                $ExitCode = 1
            }
            elseif ($DryRun) {
                Write-Log 'preview 通过；DryRun 模式，跳过 apply。' 'OK'
                Add-Step -Name 'impeccable' -Status 'preview-ok' -Detail 'preview 通过（DryRun，未应用）'
            }
            else {
                $ApplyArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $UpdateImpeccablePath, '-Mode', 'apply')
                if ($SourcePath -ne '') { $ApplyArgs += @('-SourcePath', $SourcePath) }

                Write-Log 'preview 通过，运行 apply。'
                $Apply = Invoke-Step -FilePath 'powershell.exe' -Arguments $ApplyArgs -TimeoutSec $ImpeccableTimeoutSec
                Write-LogBlock -Text $Apply.Output

                if ($Apply.ExitCode -ne 0) {
                    $Category = Get-FailureCategory -Text $Apply.Output
                    Write-Log "apply 失败 [$Category]" 'ERROR'
                    Add-Step -Name 'impeccable' -Status 'error' -Category $Category -Detail (Get-Excerpt -Text $Apply.Output -MaxLength 400)
                    if (Test-NeedsHuman -Category $Category) {
                        $NotifyMessages.Add("impeccable 更新失败：$Category。")
                    }
                    $ExitCode = 1
                }
                else {
                    Write-Log 'impeccable apply 完成。' 'OK'

                    # Post-apply sanity: if the installed copy lost its entry
                    # point, roll back to the most recent backup.
                    if (-not (Test-Path -LiteralPath (Join-Path $LocalSkillDir 'SKILL.md'))) {
                        Write-Log 'apply 后 SKILL.md 缺失，尝试回滚。' 'ERROR'
                        $Rollback = Restore-LatestBackup -BackupRoot $BackupRoot -LocalSkillDir $LocalSkillDir
                        Write-Log $Rollback.Detail
                        Add-Step -Name 'impeccable' -Status 'error' -Category 'unknown' -Detail ("apply 后入口文件缺失；" + $Rollback.Detail)
                        $NotifyMessages.Add('impeccable 更新后异常，已回滚到上一个备份。')
                        $ExitCode = 1
                    }
                    else {
                        $Suffix = if ($LayoutFallback) { '；已适配上游新目录结构' } else { '' }
                        Add-Step -Name 'impeccable' -Status 'updated' -Detail ("已应用更新$Suffix")
                    }
                }
            }
        }
    }
    }
    catch {
        Write-Log ("impeccable 步骤未捕获异常: " + $_.Exception.Message) 'ERROR'
        if ($_.ScriptStackTrace) { Write-Log $_.ScriptStackTrace }
        Add-Step -Name 'impeccable' -Status 'error' -Category 'unknown' -Detail $_.Exception.Message
        $NotifyMessages.Add('impeccable 更新过程异常，已终止；本地版本保持不变。')
        $ExitCode = 1
    }
}

# --------------------------------------------------- 2. other skills -----
if (-not $ImpeccableOnly) {
    Write-Log '--- 步骤 2/2: 其余 skills ---'

    try {

    if (-not (Test-Path -LiteralPath $ManageSkillsPath)) {
        Add-Step -Name 'skills' -Status 'error' -Category 'missing-dependency' -Detail "缺少脚本: $ManageSkillsPath"
        $ExitCode = 1
    }
    else {
        $Mode = if ($DryRun) { 'check' } else { 'update' }
        Write-Log "运行 manage-skills.ps1 -Mode $Mode"
        $Skills = Invoke-Step -FilePath 'powershell.exe' -Arguments @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $ManageSkillsPath, '-Mode', $Mode) -TimeoutSec $SkillsTimeoutSec
        Write-LogBlock -Text $Skills.Output

        if ($Skills.ExitCode -ne 0) {
            $Category = Get-FailureCategory -Text $Skills.Output
            Write-Log "manage-skills 返回非零退出码 [$Category]" 'ERROR'
            Add-Step -Name 'skills' -Status 'error' -Category $Category -Detail (Get-Excerpt -Text $Skills.Output -MaxLength 400)
            $ExitCode = 1
        }
        else {
            # manage-skills.ps1 always exits 0 and reports per-skill outcomes in
            # its summary block, so the counts are the only signal. Treat every
            # status that is not a healthy terminal state as a problem: an
            # `outdated` or `patch-stale` row surviving an update run means the
            # update did NOT converge, which is precisely how archify and
            # modlens silently drifted for weeks while this step logged "OK".
            $HealthyStatuses = @('up-to-date', 'skipped', 'unchanged', 'updated', 'applied')
            $NeedsHumanStatuses = @('patch-stale', 'error', 'missing')

            $Counts = @{}
            foreach ($Match in [regex]::Matches($Skills.Output, '(?m)^-\s*([a-z][a-z-]*):\s*(\d+)\s*$')) {
                $Counts[$Match.Groups[1].Value] = [int]$Match.Groups[2].Value
            }

            if ($Counts.Count -eq 0) {
                # Never assume health from an unreadable report.
                Write-Log 'manage-skills 输出中找不到汇总块，无法判定结果。' 'ERROR'
                Add-Step -Name 'skills' -Status 'error' -Category 'unknown' -Detail 'manage-skills 汇总块解析失败，无法确认各 skill 状态'
                $NotifyMessages.Add('skills 状态未知：manage-skills 汇总块无法解析。')
                $ExitCode = 1
            }
            else {
                # `outdated` means opposite things per mode. In `check` it is
                # simply "upstream has new commits" — the normal resting state
                # between runs, and reporting it as unhealthy trains the reader
                # to ignore this step. After an `update` run it means the update
                # did not converge, which is a real failure.
                $PendingStatuses = if ($Mode -eq 'update') { @() } else { @('outdated') }

                $Problems = @{}
                $Pending = @{}
                foreach ($Key in $Counts.Keys) {
                    if ($HealthyStatuses -contains $Key -or $Counts[$Key] -le 0) { continue }
                    if ($PendingStatuses -contains $Key) {
                        $Pending[$Key] = $Counts[$Key]
                    }
                    else {
                        $Problems[$Key] = $Counts[$Key]
                    }
                }

                $PendingSummary = (($Pending.Keys | Sort-Object | ForEach-Object { "$_=$($Pending[$_])" }) -join ', ')

                if ($Problems.Count -eq 0) {
                    if ($Pending.Count -gt 0) {
                        Write-Log "manage-skills 完成，无异常；有待更新项：$PendingSummary" 'OK'
                        Add-Step -Name 'skills' -Status 'update-available' -Detail "mode=$Mode，待更新：$PendingSummary"
                    }
                    else {
                        Write-Log ('manage-skills 完成，全部为健康状态：' + (($Counts.Keys | Sort-Object | ForEach-Object { "$_=$($Counts[$_])" }) -join ', ')) 'OK'
                        Add-Step -Name 'skills' -Status 'updated' -Detail "mode=$Mode，全部健康"
                    }
                }
                else {
                    $Summary = (($Problems.Keys | Sort-Object | ForEach-Object { "$_=$($Problems[$_])" }) -join ', ')
                    $HumanNeeded = @($Problems.Keys | Where-Object { $NeedsHumanStatuses -contains $_ })
                    $Detail = "mode=$Mode，非健康状态：$Summary"
                    if ($Pending.Count -gt 0) { $Detail += "；另有待更新：$PendingSummary" }

                    Write-Log "manage-skills 存在非健康状态：$Summary" 'WARN'
                    Add-Step -Name 'skills' -Status 'partial' -Detail $Detail

                    if ($HumanNeeded.Count -gt 0) {
                        $NotifyMessages.Add("skills 需要人工处理：$Summary（详见状态文件）。")
                        $ExitCode = 1
                    }
                    elseif ($Mode -eq 'update') {
                        # `outdated` after an update run means the update ran but
                        # did not converge — not a transient condition.
                        $NotifyMessages.Add("skills 更新后仍有未收敛项：$Summary。")
                        $ExitCode = 1
                    }
                }
            }
        }
    }
    }
    catch {
        Write-Log ("skills 步骤未捕获异常: " + $_.Exception.Message) 'ERROR'
        if ($_.ScriptStackTrace) { Write-Log $_.ScriptStackTrace }
        Add-Step -Name 'skills' -Status 'error' -Category 'unknown' -Detail $_.Exception.Message
        $ExitCode = 1
    }
}

# ------------------------------------------------------------ report -----
$FinishedAt = Get-Date
$Duration = [math]::Round(($FinishedAt - $StartedAt).TotalSeconds, 1)

Write-Log "运行结束，耗时 ${Duration}s，退出码 $ExitCode"

$StatusObject = [ordered]@{
    startedAt   = $StartedAt.ToString('o')
    finishedAt  = $FinishedAt.ToString('o')
    durationSec = $Duration
    dryRun      = [bool]$DryRun
    exitCode    = $ExitCode
    logFile     = $LogPath
    steps       = @($Steps.ToArray())
}

($StatusObject | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $StatusJson -Encoding UTF8

$MarkdownLines = New-Object System.Collections.Generic.List[string]
$MarkdownLines.Add('# Skills 自动更新状态')
$MarkdownLines.Add('')
$MarkdownLines.Add(('- 运行时间: {0}' -f $StartedAt.ToString('yyyy-MM-dd HH:mm:ss')))
$MarkdownLines.Add(('- 耗时: {0}s' -f $Duration))
$MarkdownLines.Add(('- 模式: {0}' -f $(if ($DryRun) { 'DryRun（只校验，未写入）' } else { '正常更新' })))
$MarkdownLines.Add(('- 退出码: {0}' -f $ExitCode))
$MarkdownLines.Add(('- 日志: `{0}`' -f $LogPath))
$MarkdownLines.Add('')
$MarkdownLines.Add('| 步骤 | 状态 | 分类 | 说明 |')
$MarkdownLines.Add('| --- | --- | --- | --- |')

foreach ($Step in $Steps) {
    $Hint = ''
    if ($Step.Category -and $FailureCatalog.ContainsKey($Step.Category)) {
        $Hint = $FailureCatalog[$Step.Category].Hint
    }
    $Cell = if ($Hint -ne '') { "$($Step.Detail) <br> 处理建议: $Hint" } else { $Step.Detail }
    $Cell = $Cell.Replace('|', '\|').Replace("`n", ' ').Replace("`r", ' ')
    $MarkdownLines.Add(('| {0} | {1} | {2} | {3} |' -f $Step.Name, $Step.Status, $(if ($Step.Category) { $Step.Category } else { '-' }), $Cell))
}

$MarkdownLines.Add('')

($MarkdownLines -join "`n") | Set-Content -LiteralPath $StatusMarkdown -Encoding UTF8

# Housekeeping: only the newest $LogRetention run logs are kept.
$OldLogs = @(
    Get-ChildItem -LiteralPath $LogDir -Filter 'auto-update-*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -Skip $LogRetention
)
foreach ($Old in $OldLogs) {
    Remove-Item -LiteralPath $Old.FullName -Force -ErrorAction SilentlyContinue
}

if (-not $NoNotify) {
    # The flag file runs unconditionally: it is the only channel that survives a
    # non-interactive session, and it clears itself when the run comes back
    # clean.
    Set-AttentionFlag -Path $AttentionFlagPath -Messages @($NotifyMessages.ToArray()) -StatusMarkdown $StatusMarkdown -LogPath $LogPath

    if ($NotifyMessages.Count -gt 0) {
        Show-BalloonTip -Title $NotifyTitle -Message (($NotifyMessages -join ' ') + " 详见 $StatusMarkdown") -Level 'Warning'
    }
}

exit $ExitCode

}
finally {
    # Released even on an unhandled failure, otherwise the lock would only be
    # cleared when the process dies and the next run would have to recover from
    # an abandoned mutex. Null when the lock could not be created at all and the
    # run continued unlocked.
    if ($null -ne $UpdateMutex) {
        try { $UpdateMutex.ReleaseMutex() } catch {}
        try { $UpdateMutex.Dispose() } catch {}
    }
}
