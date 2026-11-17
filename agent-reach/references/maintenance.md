# 来源、运行环境和维护

## 来源与版本

| 组件 | 来源 / 固定版本 |
|---|---|
| Agent-Reach 设计与嵌套 skill | `Panniantong/Agent-Reach`，`agent_reach/skill`，提交 `94f06c1969dfc1834001269d79d3ad0972d9dee6` |
| OpenCLI | npm `@jackwener/opencli@2.0.2`，官方源 `jackwener/opencli` |
| bilibili-cli | PyPI `bilibili-cli==0.6.2`，官方源 `public-clis/bilibili-cli`（包 metadata 仍列旧属主 `jackwener`） |
| 本地适配 | `platform-read.mjs`、`opencli-read.mjs`、`proxy-page.mjs`、`bili-public.py`、`read-commands.json`、`apply-local-patches.py` |

运行目录：`C:\Users\Computer\.agents\external\agent-reach-runtime`。
完整源码分别在 `.agents\external\agent-reach-source`、`agent-reach-opencli-source`、`agent-reach-bilibili-source`，不进入活动技能扫描目录。

Node 依赖锁定于 `package-lock.json`；Python 环境位于 `.venv`，完整版本记录于 `requirements.lock.txt`。使用系统 `C:\Program Files\nodejs\node.exe` 和隔离环境的 Python，入口不依赖 shell 激活状态。没有修改 PATH、Codex MCP 或浏览器配置。2026-10-24 按用户要求新增 WorkBuddy 入口 `C:\Users\Computer\.workbuddy\skills\agent-reach`，以 junction 指向本活动技能目录；更新活动文件后映射同步可见，不维护第二份副本。

OpenCLI 用 `--ignore-scripts` 安装，跳过会修改 `~/.opencli` 的安装脚本。定制启动器加载固定包内的适配器并筛选四平台只读命令；不调用上游 `main.js` 的用户目录同步、插件加载、升级提醒及 daemon 启动。`proxy-page.mjs` 将 OpenCLI 的页面接口接到已连接的 web-access Proxy（127.0.0.1:3456）；只调用 /health、/new、/navigate、/eval、/close 等现有 HTTP API。它在进程内替换固定版本 CDPBridge 的 connect/close，不调用原连接方法，不读取 DevToolsActivePort，不建立新的浏览器 WebSocket或监听服务。每条命令清理自己的标签页，共享 Proxy 保持运行。若健康检查失败，入口报错；不要自行退回直连、重启浏览器或要求每条命令重新授权。

小红书当前页面的新搜索区隐藏旧 `#search-input`，改用可见的 `#search-input-in-feeds` / `#search-input-ai` textarea；站内实际导航到 `/search_result_ai`，关键词多编码一层。`apply-local-patches.py` 以带预期次数校验的精确匹配把兼容版生成到外部 `overrides/xiaohongshu-search.mjs`，并保留源文件 SHA256、替换项和理由；不修改已安装包。补丁兼容这两种搜索页及关键词表示，保留原有可见性、登录、风控和歧义检查，只在实际 textarea 所属输入区选择提交按钮。后台计时器超时后只复核当前页，不重放搜索；已提取足够数量真实条目时不因瀑布流高度为零而重建标签页。少于所需条目且布局异常仍报告限制，不能伪造补足结果。

Windows 入口使用 `.ps1` 将参数数组直接传给 node.exe。不要改回 `.cmd` 的 `%*` 转发，否则笔记 URL 中的 `&` 可能被命令解释器拆分，丢失查询参数及后续 `--limit` 等选项。

X 后端所需 `ct0` 从当前 X 页面取得，仅留在本次进程中；不会读取 `auth_token`、Cookie 数据库或导出凭据。其他 Cookie 存储和浏览器全局 CDP 调用被入口拒绝。公开浏览当然会让浏览器按网站正常行为使用自身会话。

## 更新

先在外部源码目录审查目标版本，尤其关注命令参数、认证、标签页管理和安装脚本。不要运行原版 `agent-reach install --system` 或整库 skills 安装。

重装当前锁定版本（实际升级时用已审查的明确版本替换）：

```powershell
npm ci --prefix 'C:\Users\Computer\.agents\external\agent-reach-runtime' --ignore-scripts --no-fund --no-audit
uv pip sync --python 'C:\Users\Computer\.agents\external\agent-reach-runtime\.venv\Scripts\python.exe' 'C:\Users\Computer\.agents\external\agent-reach-runtime\requirements.lock.txt'
python -X utf8 'C:\Users\Computer\.agents\external\agent-reach-runtime\apply-local-patches.py'
```

本地入口依赖 OpenCLI 2.0.2 的内部模块，升级必须检查模块导出、manifest 和命令名，不能直接改锁文件后宣称兼容。重跑入口的帮助/拒绝写入测试、匿名 B站搜索及详情，以及具备会话条件的平台少量实测。检查任务结束时 Proxy `managedTabs` 回到调用前状态。

修改 description/usageRule 后：

```powershell
powershell -ExecutionPolicy Bypass -File 'C:\Users\Computer\.agents\skills\manage-skills.ps1' -Mode apply-overrides -Only agent-reach
powershell -ExecutionPolicy Bypass -File 'C:\Users\Computer\.agents\skills\manage-skills.ps1' -Mode check -Only agent-reach
```

`manual` 项的 `up-to-date` 只证明本地管理一致，不代表远端最新或平台可读。本文及运行脚本属于本地定制，人工合并上游；保留许可证。

## 卸载 / 回退

卸载时只删除 `skills-sources.json` 中 `name=agent-reach` 和 `local-routing-overrides.json` 中 `skill=agent-reach` 的条目，以及对应路由/更新说明段落。删除活动目录 `.agents\skills\agent-reach` 即停止技能发现；不会影响其他技能。

底层包可分别卸载：

```powershell
npm uninstall --prefix 'C:\Users\Computer\.agents\external\agent-reach-runtime' --ignore-scripts '@jackwener/opencli'
uv pip uninstall --python 'C:\Users\Computer\.agents\external\agent-reach-runtime\.venv\Scripts\python.exe' bilibili-cli
```

如果要清除整套隔离依赖，先确认没有本入口运行，再核对绝对目录严格等于上述 runtime，才递归删除该目录；这也会删除本次管理文件备份。三个 `agent-reach-*-source` 源码目录可单独保留或按准确路径删除。不要删除 `~/.opencli`、`~/.web-access`、浏览器数据、共享 Proxy 或其他技能目录。

安装前管理文件备份位于 `agent-reach-runtime\backups\20261024-before`。回退按本次条目合并，不直接拿备份覆盖未来其他任务的配置。
