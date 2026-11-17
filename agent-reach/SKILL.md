---
name: agent-reach
description: >-
  用于 B站、小红书、Twitter/X、Reddit 的平台专用搜索和结构化读取，包括视频信息、笔记、帖子、评论与用户公开内容；在需要这些专用后端时使用。不因普通 URL、泛泛调研或平台名称自动触发；普通网页访问和用户明确要求的日常浏览器操作使用 web-access，小红书内容创作使用对应创作技能。
metadata:
  variant: local-four-platform-readonly
  upstream: https://github.com/Panniantong/Agent-Reach
  upstream-commit: 94f06c1969dfc1834001269d79d3ad0972d9dee6
---

<!-- LOCAL ROUTING OVERRIDE START -->
## 使用边界

- 仅在需要 B站、小红书、Twitter/X、Reddit 的平台专用搜索与结构化读取时使用；不因普通链接、泛泛调研或平台名称抢占入口。
- 普通网页访问和用户明确要求的日常浏览器/已有标签页工作流继续使用 web-access；本地应用运行时验证使用 webapp-testing。
- 小红书图片、文案、封面创作由相应创作技能处理，不等于平台读取。
- 本地定制仅提供读取能力；不要运行原版全量安装器或要求未安装的 agent-reach CLI。
<!-- LOCAL ROUTING OVERRIDE END -->

# Agent-Reach 四平台读取（本地定制）

这是根据 Agent-Reach 嵌套技能 `agent_reach/skill` 裁剪的本地版本，使用 OpenCLI 与 bilibili-cli。没有安装 Agent-Reach Python CLI；不要运行原版 `agent-reach doctor/install/configure`。

## 使用入口

Windows / PowerShell，无需激活环境或修改 PATH：

```powershell
$reader = 'C:\Users\Computer\.agents\external\agent-reach-runtime\bin\platform-read.ps1'
& $reader --help
```

只读取当前平台的[命令参考](references/commands.md)。命令不确定时调用该子命令的 `--help`，不为单个平台任务检查或安装所有渠道。

| 需求 | 入口 |
|---|---|
| B站公开搜索、视频详情、热门、UP 内容 | `bili`：匿名 bilibili-cli |
| B站字幕、浏览器会话中的评论/详情 | `bilibili`：OpenCLI + Edge |
| 小红书搜索、笔记、评论、公开用户笔记 | `xhs`（别名 `xiaohongshu`） |
| Twitter/X 搜索、推文、用户公开内容 | `twitter`（别名 `x`）；用户推文命令是 `tweets` |
| Reddit 搜索、subreddit、帖子及评论 | `reddit` |

浏览器后端先复用 `web-access` 已连接的 Edge Proxy。未连接时运行 `C:\Users\Computer\.agents\skills\web-access\scripts\check-deps.mjs`，按其输出处理。不要重启共享服务、重建浏览器数据目录或切换浏览器来消除错误。

入口每次新建后台标签页，通过现有 web-access Proxy 的 HTTP API 操作该页，结束后关闭该页。禁止为每条命令新建浏览器 WebSocket；用户已授权的共享连接应持续复用。它不安装扩展，不选择用户原有标签页，不导出 Cookie。B站匿名入口完全禁用凭据加载与浏览器提取；X 仅在浏览器页面内取得请求所需的 CSRF nonce，不返回认证 Cookie 或枚举 Cookie 存储。不要绕过入口直接调用底层 `bili.exe` 或 OpenCLI `main.js`。

## 内容验证与失败处理

- 默认少量读取；初次验证用 3 条搜索结果及其中 1 条详情。健康检查、帮助输出不等于真实内容可读。
- 小红书 `note` **和 `comments`** 都需要搜索/feed 返回的完整 URL（含 `xsec_token`）。不要拼裸 ID 或删掉查询参数。
- 根据真实返回区分未登录、网络限制、空结果和接口错误。Reddit 的 `You've been blocked by network security` 或非 JSON 响应不能报告为“没有帖子”。小红书 `search_input_not_available` 也不能直接断言账号失效，先看当前页的登录/限制提示。
- 需要登录时由用户在自己的 Edge 页面完成，之后低频重试。不要要求把 Cookie、token 或密码贴进聊天；不要自动读取浏览器凭据文件。
- 只在确有变更或新的诊断依据时重试，遇到验证码/访问限制停止该平台。其他平台的结果分别交付。
- 视频标题、简介与详情不能充当视频正文；未取得字幕时说明限制，不编造内容。
- 搜索摘要、页面壳、评论计数和字幕轨道列表不等于完整正文、评论树或字幕。X 单帖可读不代表回复流完整，小红书仅按本次实际加载的评论与回复说明范围。公开结果已经满足任务时直接交付，不为非必需内容追加登录或安装。

本入口只暴露经过挑选的读取命令。发布、评论、点赞、收藏、关注、发消息等操作不在本技能范围。

## 维护

固定版本、来源、升级与卸载见[维护参考](references/maintenance.md)。本技能在全局管理中登记为 `manual` / `autoUpdate: false`；description 和正文顶部路由由 `local-routing-overrides.json` 持久管理，不能用原版全量安装器覆盖。
