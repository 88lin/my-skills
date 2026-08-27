# sync-skills.ps1 - 同步 my-skills 仓库到本地 skills 目录（加固版）
#
# 相比原版的修复:
#   1. 全局互斥锁: 已有实例运行时立即退出, 杜绝多实例堆积
#   2. git pull 超时保护: 网络/代理异常时最多等待 $GitTimeoutSec 秒
#   3. 失败容忍: 单次拉取失败直接退出, 不影响下次调度

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- 防多实例: 全局互斥锁 ---
$MutexName = 'Global\SyncMySkillsLock'
$mutex = New-Object System.Threading.Mutex($false, $MutexName)
if (-not $mutex.WaitOne(0)) {
    Write-Host '[sync] 另一个同步实例正在运行, 本次直接退出。' -ForegroundColor Yellow
    exit 0
}

try {
    $RepoDir       = Join-Path $HOME '.agents\repos\my-skills'
    $SkillsDir     = Join-Path $HOME '.agents\skills'
    $GitTimeoutSec = 60    # git pull 最长等待秒数, 超时视为失败

    $SkillNames = @(
      'chinese-commit-conventions','chinese-documentation','systematic-debugging',
      'verification-before-completion','brainstorming','writing-plans','impeccable',
      'canvas-design','html-ppt','extract-design','chinese-code-review',
      'karpathy-guidelines','skill-creator','mcp-builder','hv-analysis',
      'test-driven-development','receiving-code-review','using-git-worktrees',
      'webapp-testing','health','seo-audit','ai-seo','schema'
    )

    # --- Step 1: git pull 带超时 ---
    Write-Host '=== Step 1: git pull ===' -ForegroundColor Cyan
    $gitOut = Join-Path $env:TEMP 'sync-skills-git.out'
    $gitErr = Join-Path $env:TEMP 'sync-skills-git.err'
    $git = Start-Process -FilePath 'git' `
        -ArgumentList @('-C', $RepoDir, 'pull', '--ff-only', 'origin', 'main') `
        -NoNewWindow -PassThru `
        -RedirectStandardOutput $gitOut -RedirectStandardError $gitErr

    if (-not $git.WaitForExit($GitTimeoutSec * 1000)) {
        try { $git.Kill(); $git.WaitForExit(5000) | Out-Null } catch {}
        Write-Host "[sync] git pull 超时(${GitTimeoutSec}s), 已终止, 跳过本次同步。" -ForegroundColor Red
        exit 0
    }
    if ($git.ExitCode -ne 0) {
        Write-Host "[sync] git pull 失败 (exit=$($git.ExitCode)):" -ForegroundColor Red
        Get-Content $gitErr -ErrorAction SilentlyContinue | Write-Host
        exit 0
    }
    Get-Content $gitOut -ErrorAction SilentlyContinue | Write-Host

    # --- Step 2: 同步 skills ---
    Write-Host ''
    Write-Host '=== Step 2: sync skills ===' -ForegroundColor Cyan
    $updated = 0
    $skipped = 0
    foreach ($name in $SkillNames) {
      $source = Join-Path $RepoDir $name
      $target = Join-Path $SkillsDir $name
      if (-not (Test-Path $source)) {
        Write-Host "  MISSING in repo: $name" -ForegroundColor Yellow
        continue
      }
      $srcHash = (Get-FileHash (Join-Path $source 'SKILL.md') -Algorithm SHA256).Hash
      $tgtFile = Join-Path $target 'SKILL.md'
      if (Test-Path $tgtFile) {
        $tgtHash = (Get-FileHash $tgtFile -Algorithm SHA256).Hash
        if ($srcHash -eq $tgtHash) {
          $skipped++
          continue
        }
      }
      if (Test-Path $target) { Remove-Item $target -Recurse -Force }
      Copy-Item $source $target -Recurse
      Write-Host "  UPDATED: $name" -ForegroundColor Green
      $updated++
    }

    Write-Host ''
    Write-Host "Done! Updated: $updated, Already up-to-date: $skipped" -ForegroundColor Cyan
}
finally {
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
