---
name: verification-loop
description: >-
  在重要功能、行为修复、重构完成或创建 PR 前，按项目配置和改动风险验证构建、类型、Lint、测试、安全线索及实际 Diff，并报告真实证据。普通文案、CSS 或小范围可逆修改只做相关检查，不默认跑全套或强制覆盖率。
license: MIT
metadata:
  origin: ECC
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

用于用户明确要求的交付验证，或重要功能、行为修复和重构后的质量核对。先看任务完成标准、实际 Diff、项目已有脚本和当前 shell，再选择检查。

- Windows 原生使用 PowerShell；不要照抄 Bash 的 pipefail、tail、sed、head 或重定向语法。保留真实退出码。
- 复用已通过且仍有效的检查；小改动直接做相关静态检查或最小运行验证，不新增镜像测试、不强制 80% 覆盖率。
- 测试、覆盖率、类型或 Lint 工具缺失时，根据项目和请求判断是否相关；不为了填满模板临时安装工具。
- 安全线索只报告位置和类别，不输出凭证原文；本地通过与部署环境验收分别报告。
- 只有确需交互或渲染证据时才用现有 webapp-testing；已完成的测试不在多个技能之间重复运行。
<!-- LOCAL ROUTING OVERRIDE END -->

# Verification Loop Skill

Evidence-based verification for work in the current coding client and shell.

## When to Use

Invoke this skill:
- After completing a feature or significant code change
- Before creating a PR
- When you want to ensure quality gates pass
- After refactoring

## Verification Phases

Choose the applicable checks from the six areas below using the requested outcome, actual diff, existing project commands, and risk. A missing unrelated phase is not a failure. Required checks that cannot run remain NOT PERFORMED with the actual dependency.

### 1. Build

Inspect the package manifest, lockfile, CI, and project instructions first. Run the existing build command when the change affects a built artifact. Use the actual shell and capture the command's exit status before formatting output.

For a project that really defines an npm build script, a native PowerShell example is:

```powershell
npm run build
$verificationBuildExit = $LASTEXITCODE
if ($verificationBuildExit -ne 0) { throw "Build failed: $verificationBuildExit" }
```

### 2. Types

Use a configured type-check script, or an existing local checker appropriate to the stack. Do not install a compiler just to make a template phase run. For a TypeScript project with local tsc already installed, use `npx --no-install tsc --noEmit` and inspect its exit status.

### 3. Lint

Run the project's existing lint command when relevant. Preserve existing findings separately from regressions caused by this change. Missing unrelated lint tooling is NOT APPLICABLE, not a reason to add a toolchain.

### 4. Tests and behavior

Run the smallest existing tests or reproduction that establishes the requested behavior, plus checks required by the project. Add meaningful tests when changed logic or regression risk warrants them. Copy-only, CSS-only, and other narrow reversible changes do not automatically require new tests or a coverage suite.

Use coverage only when configured or relevant; follow the project's threshold. Do not impose a universal 80% target, install a new framework, or mirror implementation details in tests.

When interaction, rendering, responsiveness, or console output requires runtime evidence, use the currently available local webapp-testing workflow. Ordinary static edits do not automatically start a server or browser.

### 5. Security and diagnostics

Inspect relevant changed code for accidental credentials, unsafe input or output, missing authorization, and unintended logs. Use available scanners or filename-only targeted searches; never print credential values or raw matching lines containing secrets. A heuristic search is not a complete security certification. Report file locations and issue categories.

### 6. Diff and scope

Check the task's actual working, staged, or requested commit diff. Preserve unrelated user and other-agent edits. For an uncommitted task, these read-only commands are useful:

```powershell
git status --short
git diff --stat
git diff --cached --stat
git diff --check
```

Then inspect the relevant changed lines for intended behavior, edge cases, and errors. A `HEAD~1` comparison is appropriate only when that commit range is the requested review scope.

Fix failures in the changed scope and rerun the affected check. Separate confirmed pre-existing failures and unavailable environments from regressions; do not rerun passing unrelated suites without a reason.

## Target Acceptance

When the requested outcome requires deployment or target-environment verification,
report target acceptance separately from local checks. Record the environment and
installed version when known, the evidence, and the next permitted check or precise
access dependency. Passing local checks, review, merge, or release does not establish
target acceptance. Report VERIFIED or FAILED for an executed target check, with its evidence.
Do not access production or make external changes without authorization. For
local-only tasks, mark target acceptance as not applicable.

For example: local checks PASS; staging verification NOT PERFORMED (no access);
next step: an authorized maintainer runs the staging smoke test.

## Output Format

Report applicable checks as PASS or FAIL with concise evidence. Mark irrelevant checks NOT APPLICABLE and unavailable required checks NOT PERFORMED with the precise dependency. Do not invent test counts, coverage, deployment results, or a readiness claim.

For an ordinary task, use a short result in the delivery response. A larger change may use a table covering build, types, lint, tests or behavior, security findings, diff scope, and target acceptance. State remaining work when it affects the requested outcome. Report local and target-environment results separately.

## Checkpoints

Verify after meaningful implementation milestones or before delivery when relevant. Reuse already valid evidence; do not impose a timer, repeat checks after every small edit, or require a `/verify` command that the current client has not installed.

## Integration with Hooks

This standalone skill can complement existing hooks, but does not require or install them. Use the tools and commands already available in the current environment.
