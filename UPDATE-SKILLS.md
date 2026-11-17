# Skills 更新说明

## 2026-11-17：ECC 五个精选开发技能

- 登记 `codebase-onboarding`、`change-impact`、`verification-loop`、`search-first`、`frontend-patterns` 为 Git / `main` / `autoUpdate: true`。五项共享 `.agents\external\ecc-source`，仅同步各自 `skills/<name>` 与 MIT LICENSE。
- 中文触发、跨客户端执行边界、Windows 兼容补丁和 `allow_implicit_invocation: true` 由 `local-routing-overrides.json` 持久维护；源码保持干净。上游补丁锚点失效时报告 `patch-stale`，不默默丢弃本地适配。
- 复用计划任务 `SkillsAutoUpdate`（每三天 20:00），不另建任务。单项或五项检查/更新使用管理器的 `-Only`，逗号分隔名称即可。
- Codex、OpenCode 读取共用技能目录；Claude Code、WorkBuddy、Qoder CN 的入口以 Junction 指向同一份活动内容。新会话中的实际目录加载另行验证。
- 本次仅安装这五项独立 Skills，完整 ECC 插件、Hooks、Memory Vault 和其他语言包不属于本次分发内容。

## 2026-11-12：观察缓存与独立状态

人工维护来源的上游观察使用 `git ls-remote` 和 GitHub Git tree API，不执行 `git fetch`。普通检查不再每次联网观察这些来源：

| 入口/参数 | 行为 |
| --- | --- |
| `manage-skills.ps1 -Mode check` / 包装器 `-DryRun` | 默认 `-UpstreamWatchMode cached`，只读取观察缓存，不刷新或写入缓存 |
| `manage-skills.ps1 -Mode update` / 正常定时更新 | 默认 `due`，无缓存、缓存过期或上次刷新失败且退避结束时刷新 |
| `-UpstreamWatchMode force` | 无论有效期和退避，立即重新观察；不更新技能内容或审阅基线 |

缓存位于 `.agents/external/skill-upstream-watch/observations/<skill>.json`。默认有效期 72 小时；刷新失败保留上次成功观察，并退避 15 分钟。每个技能的 Git/HTTP 请求共享 30 秒刷新预算。来源、分支、子目录、基线类型或基线提交改变会使旧缓存失效；损坏缓存只作为观察不可用处理。缓存原子写入，不保存仓库副本。

到期后的下一次 `due` 运行才会刷新；`nextRefreshAt` 是最早应刷新/可重试的时间，不是一个新增计划任务。既有每三天运行的任务保持不变，期间的 cached 检查会明确标出过期观察。

- `LocalStatus` 是本次安装/同步检查结果；本地缺失、损坏、补丁漂移继续按原规则报告。
- `Upstream.status` 是 `up-to-date`、`review-required` 或 `unconfirmed`。无缓存、过期或网络刷新失败不会把正常安装改成 `error`；已有待审阅变化及提醒指纹持续保留。
- `source` 区分 `live`、`cache`、`configuration`、`none`；`checkedAt` 始终是上次成功远程观察时间，`freshness` 显示新鲜/过期/未核实。`lastKnownStatus`、`lastAttemptAt`、`lastError`、`nextRefreshAt` 和 `warning` 补充历史与重试信息。
- 包装器单列上游观察提示。仅有观察不可用时退出 0、步骤为 `upstream-unconfirmed`，不创建网络故障告警，也不清除既有待处理提示。有效的待审阅变化仍通知并去重。
- `-FailOnUnhealthy` 针对安装/同步故障及待审阅项；不因观察不可用单独失败。需要实时证明上游状态的调用方须显式 `force` 并检查结构化 `Upstream` 字段。

```powershell
# 只核对 OfficeCLI 的本地状态并读取观察缓存
& 'C:\Users\Computer\.agents\skills\manage-skills.ps1' -Mode check -Only officecli
# 立即重新观察 OfficeCLI 上游，不升级 OfficeCLI
& 'C:\Users\Computer\.agents\skills\manage-skills.ps1' -Mode check -Only officecli -UpstreamWatchMode force
```

这个模式只移除了人工维护来源的常态观察网络依赖。其他自动更新来源仍可能查询远端和下载临时包，完整逐文件校验保留；全量 `check` 不是离线模式。普通 cached 检查不写持久状态；显式 `due/force` 会写观察缓存，`-ResultPath` 会写结果文件。

## 2026-11-12：受保护来源观察与客户端策略

`manual` 或 `autoUpdate: false` 的 Agent-Reach、no-ai-slop、OfficeCLI、web-access 保持人工合并。`check` 默认读取观察缓存，`update` 按到期策略只读查询 GitHub skill 子目录；Impeccable 继续专用更新器。`-IncludeManual` 不再绕过这些保护。

- `upstreamSkillPath` / `upstreamWatch.path` 明确观察的子目录，避免其他仓库提交制造提醒。
- `upstreamCommit` 是确实安装/合并过的来源基线。`upstreamWatch.reviewedCommit` 是已审阅的参考版本，可用于有意保留本地实现的情形；不表示完整合并。
- 每次观察另存 `observedCommit`、子树标识、时间、错误与基线类型。未知基线或缺失入口是 `review-required`；网络失败记录在观察警告中，保留成功历史，不自动认领最新提交。
- 本地覆盖和上游状态分开显示。相同子树变化只提醒一次，持续保留待审阅状态；真正错误不进入去重。两种通知渠道都关闭时不登记“已通知”。

普通 `manage-skills.ps1 -Mode check` 不写持久状态、不 fetch、不修复 Git 索引锁。需要机器读取结果时显式传 `-ResultPath <JSON文件>`。自动包装器使用这个接口，把观测记录写入 `logs/last-check-skills.json` 或 `logs/last-update-skills.json`，并汇入既有状态 JSON/Markdown。提醒去重状态位于 `.agents/external/skill-upstream-watch/notifications.json`。

仅有 `review-required` 时包装器表示“检查成功，等待人工审阅”，退出 0，但状态不会写成“全部健康”，也不会清除待处理提示。执行错误仍按原规则分类。直接接入 CI 时可以加 `-FailOnUnhealthy`，安装/同步故障或待审阅项退出 1；上游观察未确认单独报告，不等同于安装故障。默认退出行为兼容旧入口。

`local-routing-overrides.json` 新增 `codexPolicy`，供三个中文参考技能及 oil-cover 设置显式调用。策略合并、完整包比较、重装重放和 Git 拉取恢复均复用 `skill-client-policy.ps1`；不要只手改 YAML。跨插件的 Codex 目的应用规则从顶层 `codexGlobalRouting` 显式重放：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides -SyncClientRouting
```

OfficeCLI 的独立更新器也受保护：`~/.officecli/config.json` 中 `autoUpdate: false`，用户环境 `OFFICECLI_SKIP_UPDATE=1`，每次代理调用使用 `.agents/external/officecli-runtime/Invoke-OfficeCli.ps1`。仅关闭 autoUpdate 并不足够：上游程序的 skill 刷新在这个条件之前执行。用户已授权升级时，可验证官方发行文件后更新二进制，再安装对应版本的 SKILL.md 并重放本地规则。当前用户已授权并验证的版本是 1.0.160，不因禁用后台更新而降级。

本地依赖保持在扫描目录外：归藏的 subset-font 2.9.0 位于 `.agents/external/guizang-node-runtime`，通过 `.agents/node_modules/subset-font` 映射解析；HV 的 Python/WeasyPrint/Pango 位于 `.agents/external/hv-analysis-runtime/env`，使用 `render-report.ps1`，精确依赖见 `environment-explicit.txt`。这是独立 Conda 环境，不是全局 Python 或 venv。脚本按当前任务目录输出；归藏渲染结果位于 `<task-dir>/output`。

## 更新链校验与归属清单（2026-11-11）

- `skills-cli` 的检查覆盖已登记路径下的完整技能包：脚本、资源、references、`agents/openai.yaml`、README、许可证与入口。每次检查先确定上游 commit，再读取该 commit 的 codeload ZIP；同一轮同仓库共享快照，避免混用不同版本。入口按本地 routing override 比较，文本归一化 UTF-8 BOM 与换行，二进制按字节比较。网络或快照读取失败会报告 `error`，不退回仅比入口。
- `skill-package-state.ps1` 是管理器与纳管脚本共用的实现，维护时应与这两个入口一起分发。归属清单保存在 `.agents\external\skill-package-state\<localFolder>.json`，只记录已验证来源内的文件与本地 SHA-256，不把活动目录里的未知新增文件纳入自动删除。
- `check` 不写活动 skill 或归属清单；它可能读取网络并使用临时 ZIP。成功的 `update`（含已验证为最新的首次运行）或 `skills-cli` 纳管会建立/更新归属清单；相同内容不重复改写清单。没有清单时，不猜测多余文件的历史归属。
- Git 目录同步和 skills-cli 更新发现上游删档时，仅清理“上一份清单登记过、当前来源已没有、且本地字节仍与清单一致”的文件，并先生成完整文件备份。已编辑的删档文件报 `error` 并保留；未知新增文件不由清理器删除。缺失来源目录、清单损坏、来源身份变化、路径越界或链接会停止相关操作，需按具体错误审阅。
- 不要为消除冲突而直接重建清单。先审阅本地修改和备份，决定保留为本地扩展、合并到新文件，或确认删除；清单是归属证据，不是任意目录的镜像开关。

### 重装与重新纳管

`install-and-register-skill.ps1` 在重装前保存文件备份，安装后复用 `manage-skills.ps1` 的 routing override 与完整包校验，全部通过才登记完成。`-SkipInstall` 可接受已经正确重放覆盖的入口，不要求恢复原始上游 description。重装保留来源登记的额外 metadata，现有 Git/人工项不会被通用安装转换为自动更新。

安装器与计划任务共享更新互斥锁，并在登记期间持有配置写入锁。普通安装失败或校验失败时，会先保存失败候选，再从本次安装前备份恢复文件、配置、归属状态和客户端策略凭据；通用 skills-cli 更新的命令失败、超时及安装后校验失败也使用同一文件恢复实现。恢复失败会明确报错并保留备份位置。首次安装没有原文件可恢复时，不登记失败候选。硬断电、强制终止和安装器对其他客户端入口的影响仍需结合日志核对，不能把备份当作跨进程事务保证。

### 严格复用现有 Impeccable 缓存

`auto-update-skills.ps1 -DryRun -NoCacheRepair` 会把已存在的源码路径明确传给专用 preview；不 clone、fetch、pull、reset 或 clean 该缓存。缓存不存在时报告 blocked，不会自动新建。非 DryRun 的 `-NoCacheRepair` 同样把该路径传给 apply；正常更新则在缓存修复后用 `-SkipFetch` 复用已验证版本。日志和临时候选仍会写入，`NoCacheRepair` 仅约束源码缓存。


## Agent-Reach 四平台读取定制（2026-10-24）

- 活动目录：`C:\Users\Computer\.agents\skills\agent-reach`；来源基线 `94f06c1969dfc1834001269d79d3ad0972d9dee6`，原始嵌套路径 `agent_reach/skill`。
- 全量源码与隔离后端在 `.agents\external`；当前固定 OpenCLI 2.0.2 和 bilibili-cli 0.6.2。未安装 Agent-Reach Python CLI，未新增 MCP。2026-10-24 按用户要求新增 `C:\Users\Computer\.workbuddy\skills\agent-reach` junction，指向 `.agents\skills\agent-reach`，共享同一份技能与后端。
- 大幅裁剪的本地版本按 `manual` / `autoUpdate: false` 管理，不用通用安装器覆盖。升级、卸载、认证边界及 Windows/Edge CDP 适配见活动技能 `references/maintenance.md`。
- 路由修改后仅运行 `apply-overrides -Only agent-reach` 和 `check -Only agent-reach`；`LocalStatus` 代表本地一致性，`Upstream` 代表已审阅参考与远端子目录的比较。平台可用性必须用真实内容另行验证。
- 安装前文件备份位于 `.agents\external\agent-reach-runtime\backups\20261024-before`；回退按本次条目合并，保留后续其他任务的修改。

## no-ai-slop 中文定制版（2026-10-18）

- 活动入口：`C:\Users\Computer\.agents\skills\no-ai-slop`。
- 源码：`C:\Users\Computer\.agents\external\no-ai-slop-source`，上游子目录 `skills/no-ai-slop`；登记的 `upstreamCommit` 是已合并基线。
- 原版 18 组模式的中文对应关系在 `references/original-patterns-zh.md`，每组含识别依据、常见变体、过度改写提示和保留边界；新增 32 组在 `references/chinese-patterns.md`，另有模式来源、组合诊断、误判总则、公众号流程（含编辑强度与过度改写对照）和中文 `eval.md`。
- `eval.md` 要求用三类样稿回归：改写、只检测、正常表达不误伤。第三类与第一类同等重要，正常样稿被改动即视为失败；修改模式库后应重跑三类，防止技能朝“改得多”漂移。
- `manual` / `autoUpdate: false` 用于保护用户授权的中文定制；通用 `update` 会跳过。`check` 同时报告本地覆盖一致性和上游子目录观察；整体 `up-to-date` 仍不代表中文编辑业务效果已经实测。
- 中文触发 description 先改 `local-routing-overrides.json`，再执行 `apply-overrides -Only no-ai-slop`；正文、模式参考和 UI 文案同步维护。
- 合并上游时：先在外部源码仓库确认无本地修改，再获取上游，在登记基线与待合并提交之间检查 skill 差异；逐项保留或补充中文对应模式和自检，不以重新安装覆盖活动目录。完成技能校验、事实保真和只检测行为复核后，更新登记基线并同步活动目录与备份。
- WorkBuddy 使用 `C:\Users\Computer\.workbuddy\skills\no-ai-slop` junction；活动内容更新后无需第二份复制。

这份文档说明全局 skill 的检查、更新、纳管和恢复方式。活动状态以磁盘和配置文件为准，不维护容易过期的静态数量清单。

## 关键路径

- 活动目录：`C:\Users\Computer\.agents\skills`
- 备份仓库：`C:\Users\Computer\Documents\GitHub\my-skills`（GitHub `88lin/my-skills`）
- 来源登记：`skills-sources.json`
- 本地持久规则：`local-routing-overrides.json`
- Claude Code 白名单：`C:\Users\Computer\.claude\skills`
- QoderWork skill 入口：当前不存在（`C:\Users\Computer\.qoderwork` 下无 `skills` 目录）
- WorkBuddy skill 入口：`C:\Users\Computer\.workbuddy\skills`
- 备份、缓存和外部仓库：`C:\Users\Computer\.agents\external`

## 动画与图文能力（2026-10-24 复核）

- 当前全局清单没有 GSAP 八项技能；旧安装记录保留在变更日志，不能据此判断仍已安装。
- `oil-motion` 的 Git 源与 Python 运行环境分别位于 `.agents\external\oil-motion-source` 和 `oil-motion-runtime\.venv`；活动目录只保留技能运行文件。
- 当前归藏图文入口为 `guizang-social-card-skill`，不是旧的产品宣传视频技能。源代码、Node 依赖和活动运行包按登记分离。
- Rare UI 是项目按需使用的组件注册表，不是全局 skill。客户端入口以实际 junction 和该客户端清单为准。

## 日常命令

### 检查全部

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check
```

默认 cached `check` 是只读操作：检查来源版本、目录完整性、override 是否同步以及 `bodyPatches` 是否仍能匹配。

### 应用本地规则

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides
```

修改 `local-routing-overrides.json` 后运行。它不会获取上游，只把已经登记的本地规则写回对应 `SKILL.md`。

### 更新允许自动更新的 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update
```

更新会获取上游、重放 override，再检查结果。日常更推荐先检查，再按需更新指定 skill。

### 只处理指定 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only ai-seo,seo-audit
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only ai-seo
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides -Only systematic-debugging
```

桌面上的 `更新 Skills.bat` 是日常图形入口，最终仍调用同一套管理脚本。

## 推荐更新流程

1. 运行 `check`，确认需要更新的目标。
2. 对重要或有本地规则的 skill，使用 `-Only` 单独更新。
3. 再运行一次目标 `check`。
4. 检查 `C:\Users\Computer\.claude\skills` 是否出现意外入口。
5. 遇到 `patch-stale` 时先审查上游变化，不要直接删除补丁或覆盖本地文件。

通过 symlink 映射到 WorkBuddy 的 skill 不需要单独复制或更新；更新 `C:\Users\Computer\.agents\skills` 后，客户端会读取同一份内容。客户端入口只需检查链接是否仍指向活动目录。

QoderWork 当前没有 skill 入口目录（`C:\Users\Computer\.qoderwork` 下不存在 `skills`），所以不需要为它做任何同步。如果以后重建了入口，按 WorkBuddy 的方式建 symlink 指向活动目录，不要复制实体目录。

`C:\Users\Computer\.workbuddy\skills` 下除 symlink 外还有几个实体目录（`checklist-design`、`frontend-dev`、`knowledge-base`、`wechat-cover`），它们不在本仓库纳管范围内。其中 `knowledge-base` 与活动目录里的同名 skill 是两份独立内容，改动其中一份不会同步到另一份。

不要使用宽泛的 `npx skills update`，也不要把整个多 skill 仓库一次性安装进全局目录。

## 来源类型

### `git`

- 用于本身就是独立 Git 仓库的 skill。
- 管理器按 `skills-sources.json` 登记的 remote 和 branch 检查、更新。
- `web-access` 保留 `git` 来源检查，设置 `autoUpdate: false` 以保护共享 Proxy 等本地补丁。发现上游差异时，上游观察显示 `review-required` 并通知人工合并（缓存来源和时间单列）；不会为拉取而丢弃改动。路由由 `local-routing-overrides.json` 维护。
- 如果 `SKILL.md` 依赖仓库内的脚本、参考资料或数据目录，必须保留完整工作树，不能只下载根目录的 `SKILL.md`。
- `img2threejs` 属于完整仓库型 skill，更新后必须确认 `forge/`、`grimoire/`、`scripts/` 和 `docs/` 仍存在。
- `xhs-visual-director` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\xhs-visual-director-source`；登记的 `syncSkillDirectory: skill` 会在 Git 更新后把上游 `skill` 子目录同步到活动 skill 根目录。
- `ian-xiaohei-illustrations` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\ian-xiaohei-illustrations-source`；活动目录只保留同步后的 skill 内容，避免 Codex 递归扫描出重复 skill。
- `modlens` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\modlens-source`；登记的 `syncSkillDirectory: skills\\modlens` 会同步入口、Windows/Unix 启动脚本和 references 到活动 skill 根目录。
- `archify` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\archify-source`；登记的 `syncSkillDirectory: archify` 会同步独立 HTML 技术图所需的 CLI、schemas、renderers、references 和资源，不把外层网站、研究文档、测试项目暴露为活动 skill。
- `guizang-social-card-skill`：完整源码位于 `.agents\external\guizang-social-card-skill-source`；活动目录按 `syncSkillFile`、`syncSkillDirectories` 和 `syncSkillFiles` 同步入口、资源、参考、脚本、校验器和许可证，实际清单见 `skills-sources.json`。
- Git 源仓库需要与活动目录分离时，使用 `repositoryFolder` 指向外部仓库，再用 `syncSkillDirectory` 把仓库内的 skill 子目录同步到活动目录；如果入口依赖仓库根部资料，再用 `syncSkillDirectories` 按目录名同步这些资源。不要手工把完整仓库复制回活动 skill 根目录。

### `skills-cli`

- 从 `skills-sources.json` 登记的仓库和单 skill 名获取更新。
- 更新后自动重放 `local-routing-overrides.json`。
- 可能在 `C:\Users\Computer\.claude\skills` 创建额外软链接或目录入口。

需要手动执行单项安装时，使用明确的仓库和 skill：

```powershell
npx -y skills add owner/repo@skill-name -g -y
```

不要省略 `@skill-name`，否则可能安装同仓库中不需要的其他 skill。

### `manual`

`manual` 表示不能由通用管理器盲目覆盖。`check` 仍会核对目录和本地规则，但不会自动拉取上游。

当前主要人工审核项：

- `impeccable`：使用专用 preview/apply 更新器。
- `officecli`：低层跨格式 Office 工具，按人工审核维护。

不要仅因为某项是 `manual` 就把它改成自动更新；先确认它是否能在不丢本地内容的情况下稳定重放。

## 检查状态

| 状态 | 含义 | 处理 |
|---|---|---|
| `up-to-date` | 来源、本地规则和结构正常 | 无需操作 |
| `outdated` | 上游或本地生成结果有差异 | 审查后更新或重放 override |
| `patch-stale` | `bodyPatches.find` 已无法匹配当前上游 | 对照上游修改补丁，再单项更新 |
| `error` | 自动更新来源不可达、本地校验或命令失败；不含独立上游观察网络故障 | 查看具体错误，不要批量覆盖 |
| `review-required` | 人工维护来源有待审阅变化或基线配置 | 审阅后决定合并/更新参考，自动覆盖仍关闭 |
| `skipped` | 人工管理或明确跳过 | 按对应专用流程处理 |

`manual` 型的 `LocalStatus: up-to-date` **不代表上游已实时核实**，它只表示本地 override 与本地 `SKILL.md` 一致（没有 override 的显示 `skipped`）。人工维护来源的远端状态另看 `Upstream.status`、`source` 和 `checkedAt`；`unconfirmed` 仅属于上游观察状态。`impeccable` 的真实上游状态只能用 `update-impeccable.ps1 -Mode preview` 得到，`check` 表格看不出它有没有待应用的上游更新。

`git` 型的 `check` 同时检查已登记的本地 description/Usage Rule 是否同步；出现 `local override 未同步` 时运行 `apply-overrides -Only <skill>`。该检查不代表本地代码补丁已经合并上游，也不证明所有 Git 正文补丁的上游锚点仍有效。

`web-access` 当前的代码/路径补丁保存在 `.agents\external\web-access-local-patches\`。合并上游时先保存并审查本地改动，在隔离副本验证补丁能重放后再更新活动目录，最后重放 routing override 并复查。不要为通过 Git 干净检查而直接丢弃这些补丁。

`git` 型出现 `outdated` 且 detail 提到 `local skill directory out of sync` 时，说明源仓库已经拉到最新、但 `syncSkillDirectory` 还没同步进活动目录，跑一次 `update -Only <skill>` 即可。同步会复制当前来源内容，并在备份后清理归属清单证明的未编辑旧文件；未知本地文件保持不变。若旧文件已有本地修改，更新会报告冲突而保留它。

`git` 型报 `缺少 Git 源仓库目录` 时，是 `.agents\external\<name>-source` 丢了而不是 skill 坏了。按 `skills-sources.json` 里登记的 remote 重新 clone 回去即可，活动目录内容不用动：

```powershell
git clone <remote> "C:\Users\Computer\.agents\external\<name>-source"
```

管理器检查通过只能证明配置和生成结果一致，不能替代对触发优先级是否符合使用习惯的人工判断。

## 外部命令超时

`manage-skills.ps1` 调用的 `git` 和 `npx` 都有墙钟超时，可按需覆盖：

| 参数 | 默认 | 用途 |
|---|---|---|
| `-GitTimeoutSec` | 180 | 状态探测（`rev-parse` / `ls-remote`） |
| `-GitPullTimeoutSec` | 900 | `pull` 的工作区重写阶段 |
| `-NpxTimeoutSec` | 600 | `npx skills add` |
| `-UpstreamWatchTimeoutSec` | 30 | 单个人工维护来源的上游观察刷新预算，Git/HTTP 共用 |

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -GitTimeoutSec 180 -GitPullTimeoutSec 900 -NpxTimeoutSec 900
```

**两者必须分开。** 状态探测只需要检测挂死，短超时即可；`pull` 在文件数多的仓库上要重写整个工作区，耗时完全不同。实测 `archify` 从 `a406594` 更新到 `7e45f36`（305 个文件）耗时 **330 秒**：fetch 几秒就完成，然后卡在 checkout，用 180 秒必然被杀，且每次都在同一位置反复失败。把 `-GitPullTimeoutSec` 调大后一次通过。

反过来也不能把所有 git 调用都调大：26 个 skill 各等 900 秒，断网时最坏要跑 6 小时。

`-GitPullTimeoutSec` 只作用于 `pull`；其余探测仍用 `-GitTimeoutSec`。

超时判定分两层。首选让 git 自己中止：调用时带上 `http.lowSpeedLimit` / `http.lowSpeedTime`，传输停滞即失败并返回 git 的真实错误信息；同时设 `GIT_TERMINAL_PROMPT=0` 并清空 askpass，避免凭据缺失时卡在无人应答的输入提示或弹窗上。墙钟超时是兜底，用于这些设置看不见的卡死（例如 DNS 或 TCP 连接阶段），触发时终止**整个进程树** —— git 与 npx 都会派生子进程，只杀父进程会留下仍占着网络句柄的孤儿。

超时表现为该 skill 一行 `error`，detail 写明"超过 N 秒未返回，已终止进程树"，不会中断其他 skill 的检查。`pull` 超时是安全的：git 要么尚未开始改写工作区，要么已整体回滚，仓库不会停在半完成状态；`manage-skills.ps1` 还会清理被强杀留下的 `.git\index.lock`，下一次运行可以继续。

`update-impeccable.ps1` 和 `install-and-register-skill.ps1` 目前还没有这层保护，它们都是人工触发、卡住可见，暂按现状保留。

## 无人值守自动更新

`auto-update-skills.ps1` 把 impeccable 与其余 skill 两条更新流串成一次无人值守运行，供计划任务调用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\Computer\.agents\skills\auto-update-skills.ps1"
```

先用 `-DryRun` 验证接线（impeccable 走 `preview`、其余走 `check`，不写入任何活动 skill 目录）。注意 `-DryRun` 仍会刷新 `.agents\external` 下的上游 Git 缓存（含 `reset --hard`、`clean -fdx`），因为 preview 必须对着当前上游才有意义；完全不想碰缓存就同时加 `-NoCacheRepair`。

安全模型是 impeccable 必须先 `preview` 通过才允许 `apply`；预检失败不写活动目录。应用前备份文件及原有版本锁；应用过程抛出异常时恢复本次备份和版本锁。硬断电、强制终止或恢复自身失败仍需按日志人工恢复，不能承诺事务级保护。

它带全局互斥锁，计划任务在上一次尚未跑完时再次触发会直接退出而不排队 —— 否则两个并发的 `npx skills add -g` 会同时写同一个全局 skill 目录。

判定结果时它解析 `manage-skills.ps1` 的汇总块，区分健康完成、待更新/待审阅和失败；`review-required` 会持续展示但不当成执行失败，且只对新的子目录变化提醒。其中 `patch-stale`、`missing` 以及"更新后仍 `outdated`"会置退出码 1 并触发通知；汇总块解析不出来时同样报错，不会默认当作健康。

`error` 需要看明细才能定性：它既可能是某个 skill 真的坏了，也可能只是状态探测时撞上网络抖动或超时（`unable to access`、`基础连接已经关闭`、`从传输流收到意外的 EOF`、`schannel`、`TLS connect error`、超过 N 秒未返回等）。脚本会从表格里取回每条 `error` 的 detail 逐条分类，只有**全部**属于瞬时故障、且 `error` 是唯一的问题类型时，才只记 `transient` 等下次自动重试 —— 不写桌面提示文件、不置失败退出码。任何无法判定或混合情况仍按需要人工处理。4xx（如 404）不算瞬时，那通常意味着 skill 源已迁移或删除。

另有一条自愈：git 被墙钟超时强杀时来不及删掉 `.git\index.lock`，残留的锁会让该仓库之后所有 git 命令都报 `Unable to create ...index.lock: File exists` —— 看起来像网络问题，而且永远不会自愈，一次超时就能把某个 skill 永久卡死。管理器仅在写入类 Git 操作之前和写入超时终止后检查该锁，前提是没有存活的 git 进程。status/show/diff/rev-parse 等只读探测使用 GIT_OPTIONAL_LOCKS=0，也不会删除已有锁。

### 出问题时怎么通知你

需要人工处理时，桌面会出现一个文件：

```
C:\Users\Computer\Desktop\Skills 需要处理.txt
```

里面写明原因、状态摘要路径和完整日志路径。**下一次完整且成功的实际更新后它会自动消失；DryRun、部分运行和未完成的网络检查都不能清除已有提示**，所以"桌面上有没有这个文件"本身就是信号，不用手动删，也不用记得去哪里查。路径可用 `-AttentionFlagPath` 改。

这个兜底信号走文件系统，不需要任何账号或密钥，也不受会话限制。之所以需要它，是因为气泡和 Toast 都**必须有交互会话**才能显示：计划任务如果配置成"不管用户是否登录都运行"，它会跑在 Session 0，Windows 不允许其向桌面弹任何东西 —— 这跟用哪个通知库无关，换成 BurntToast 之类同样弹不出来。此时脚本会在日志里记一行"无交互会话，跳过气泡通知"。

所以建任务时请选 **"只在用户登录时运行"**，气泡才会真正弹出来。两条通道的关系是：

| 通道 | 生效条件 | 关闭开关 | 作用 |
|---|---|---|---|
| 桌面提示文件 | 始终生效，**不受 `-NoNotify` 影响** | `-NoAttentionFlag` | 兜底，不会漏 |
| 气泡通知 | 仅用户已登录会话 | `-NoNotify` | 即时提醒 |

两者的开关是分开的，这是有意为之：`-NoNotify` 的意思是"别弹窗打扰我"，而桌面文件不是打扰，它是唯一能在无交互会话下送达的通道。如果把两者绑在一起，加个 `-NoNotify` 就会把安全网一并撤掉 —— 而那恰恰是最不能丢的一条。状态文件在任何情况下都照常写。

注意 `-NoAttentionFlag` 同时也关掉了自动清除，所以已经存在的提示文件不会被移除。

`-NotifyDwellSec` 控制气泡驻留秒数，默认 3 秒；手动运行时这段时间是阻塞的，所以没有设得更长。

还有一点：`-DryRun` 只要检测到需要人工处理的问题，**同样会写桌面提示文件**。手动验证时看到它冒出来不是出错，是它如实报告了发现的问题；下一次完整且成功的实际更新才会自动清掉。只想安静验证、不想留痕，就加 `-NoAttentionFlag`。

运行记录写在 `logs\`：实际更新使用 `LATEST-STATUS.md` / `last-status.json`，DryRun 单独使用 `LATEST-CHECK-STATUS.md` / `last-check-status.json`，健康的检查步骤标记为 `checked`。默认保留最近 40 份完整日志。该目录属运行期产物，已在备份仓库中被 `.gitignore` 排除。

### 更新前快照与恢复

通用管理器只在确实准备修改时，把目标技能文件复制到 `.agents\external\skill-update-backups\<skill>\<时间戳>\files`，逐文件校验 SHA256；`metadata.json` 同时记录来源条目、本地路由与 Git HEAD。备份失败、遇到无法安全复制的链接或补丁锚点失效时停止该项更新。`.git` 本体不复制，Git 历史仍保留在来源仓库。

这是可供人工恢复的文件快照，不是通用自动回滚。恢复前先对照 `metadata.json` 与更新后的差异，避免盖掉后续修改；Git 源提交和客户端入口需另外核对。快照暂不自动清理，防止按数量删除唯一可用版本；有明确空间需求时再审查保留。

计划任务 `SkillsAutoUpdate` 在本次复核时为每 3 天 20:00，已启用 `StartWhenAvailable`。不要套用“48 小时没运行即故障”的每日任务判断。

## 本地 Override

`local-routing-overrides.json` 是本地触发规则的权威来源。不要只编辑生成后的 `SKILL.md`，否则下一次更新会覆盖。

允许持久化的内容主要包括：

- 真实误触发或多个 skill 的职责冲突
- 需要长期保留的客户端兼容边界
- 已删除依赖、真实断链、无效命令或确认的兼容故障

正文默认保持上游原样。字段选择和 `patch-stale` 处理见 `LOCAL-ROUTING-OVERRIDES-USAGE.md`。

## Impeccable 专用更新

预览：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\update-impeccable.ps1" -Mode preview
```

确认预览后应用：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\update-impeccable.ps1" -Mode apply
```

专用更新器会检查上游 bundle、重放 `impeccable-local-patches.json` 和路由规则，再替换活动目录。不要直接覆盖 `impeccable/SKILL.md`——本地改动应写进 `impeccable-local-patches.json`，否则下次更新会被冲掉。

### 上游改结构或改文字时

这两种情况都会让 preview 失败，而失败是**安全的**：apply 根本不会执行，活动目录一字不动。

- **上游挪动了 skill 目录**：更新器会在来源里递归探测结构完整的 `impeccable` 目录（优先最短路径，跳过 `.git`），找到就打印 `Upstream layout changed; using detected skill directory: ...` 并继续。这个探测在 `update-impeccable.ps1` 内部，所以桌面 .bat 和无人值守任务两条入口都享受得到。真找不到才失败。
- **上游改写了补丁锚定的正文**：报 `local patch anchors missing: #<编号> <文件>: <该 patch 的 reason> [<find 预览>]`，需要人工按上游最新内容重写 `impeccable-local-patches.json` 里的 `find`。写 `find` 时尽量锚定不易变动的句子。

  报错里的 `#编号` 是该补丁在 JSON 数组中的位置（1 起算），`[<find 预览>]` 是 `find` 的前 80 字符。两者都不能省：多条补丁常常共用同一个文件、甚至同一条 `reason`，只靠文件名和 reason 无法区分是哪一条失败。

  **锚点必须恰好匹配一次。** 更新器统计 `find` 的出现次数，`0` 次（上游改写）和 `>1` 次（锚点有歧义）都算失败并拒绝应用——因为 `String.Replace` 会替换**所有**出现，匹配多处会静默改掉不该改的段落。歧义时的预览会显示 `[ambiguous: matched N times]`。

  **一次看全所有失效项**：

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\update-impeccable.ps1" -ValidatePatches
  ```

  该模式只读：把缓存里的上游复制到临时目录、在副本上重放全部补丁，逐条报告 `matched` / `failing`，不碰活动目录、不联网。preview 的报错在第一条校验未通过时就可能只给出一部分线索，用它可以在动手修改前拿到完整清单。退出码 `0` 表示全部恰好匹配一次。

失败时更新器会打印一个包含「原因」和「怎么处理」的块，不再抛出 PowerShell 原始堆栈。需要堆栈时设环境变量 `IMPECCABLE_UPDATER_DEBUG=1` 再运行。退出码为 1，桌面 .bat 据此拦住 apply。

## Claude Code 白名单

`C:\Users\Computer\.claude\skills` 是面向 Claude Code 的入口视图，不是第二份独立 skill 仓库。

`skills-cli` 安装或更新可能自动创建 Claude 入口，因此每次 update/install 后直接检查现场：

```powershell
Get-ChildItem -LiteralPath "C:\Users\Computer\.claude\skills" -Force
```

不需要暴露给 Claude 的入口应从白名单移除，但不要因此删除 `C:\Users\Computer\.agents\skills` 中仍供其他客户端使用的本体。不要依赖文档里的旧数量或旧名单判断当前状态。

## 安装并纳管新 Skill

交互入口：`C:\Users\Computer\Desktop\纳管新 Skill.bat`

底层脚本：`install-and-register-skill.ps1`

### 先预览

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" `
  -SourceType skills-cli `
  -Repo owner/repo `
  -Skill skill-name `
  -RawSkillUrl "https://raw.githubusercontent.com/owner/repo/main/path/SKILL.md" `
  -Preview
```

### 确认后安装并登记

去掉 `-Preview`。脚本会安装单个 skill、定位本地目录、核对上游并写入 `skills-sources.json`。

### 登记人工管理项

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" `
  -SourceType manual `
  -Skill skill-name `
  -LocalFolder skill-folder `
  -SkipInstall `
  -Reason "为什么不能自动覆盖"
```

只有来源明确、单 skill 路径稳定且能验证本地内容的项目才适合 `skills-cli` 自动更新。

### 完整 Git 仓库型 Skill

以下 Git 仓库型 skill 使用 Git 纳管，来源均为各自 GitHub 仓库的 `main` 分支：

- `xhs-visual-director`：源仓库为 `C:\Users\Computer\.agents\external\xhs-visual-director-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\xhs-visual-director`；活动目录保留入口、`agents` 以及运行所需的 `assets`、`docs`、`examples`、`templates`，不包含完整 Git 仓库。
- `oil-cover`：`C:\Users\Computer\.agents\skills\oil-cover`；上游入口为根目录 `SKILL.md`。
- `ian-xiaohei-illustrations`：源仓库为 `C:\Users\Computer\.agents\external\ian-xiaohei-illustrations-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\ian-xiaohei-illustrations`；活动目录只保留内层 skill 内容。
- `modlens`：源仓库为 `C:\Users\Computer\.agents\external\modlens-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\modlens`；活动目录同步 `skills\\modlens`，保留 `SKILL.md`、`scripts` 和 `references`，不包含完整项目源码。
- `archify`：源仓库为 `C:\Users\Computer\.agents\external\archify-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\archify`；活动目录同步仓库内的 `archify` 子目录，保留渲染、校验、导出和视觉检查所需的完整运行包。
- `guizang-social-card-skill`：完整源码位于 `.agents\external\guizang-social-card-skill-source`；活动目录按 `syncSkillFile`、`syncSkillDirectories` 和 `syncSkillFiles` 同步入口、资源、参考、脚本、校验器和许可证，实际清单见 `skills-sources.json`。
- `img2threejs`：`C:\Users\Computer\.agents\skills\img2threejs`；需要完整保留 `forge/`、`grimoire/`、`scripts/` 和 `docs/`。

日常检查和更新：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only img2threejs
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only img2threejs
```

不要把这些仓库改成只含 `SKILL.md` 的单文件安装；它们的 `references/`、`templates/`、`assets/`、脚本或数据目录都是运行和参考流程的一部分。

## 备份仓库

`C:\Users\Computer\Documents\GitHub\my-skills` 是活动目录的备份镜像，不是第二份活动 skill。唯一的权威内容在 `C:\Users\Computer\.agents\skills`。

同步方向固定为**活动目录 → 备份仓库**。反向复制会把旧内容盖回在用的 skill，`web-access` 曾因此在备份里停留在 v2.5.3、而活动目录已经是 v2.5.4。

需要修改配置、脚本或本地 override 时，先备份当前活动文件，再从当前活动版本创建隔离副本进行修改和验证；只把核对过的差异应用回活动目录。不要拿可能落后的备份仓库直接覆盖现网。管理脚本会调用外部安装器或读取外部来源，隔离测试需显式替换这些依赖，不能仅凭 `$ScriptRoot` 就认为无外部副作用。

注意备份仓库里跑 `git` 型 skill 会失败，因为 `repositoryFolder` 相对备份根解析不到 `.agents\external`。`git` 型只能在活动目录侧更新。

每次 update/apply-overrides 后可核对备份差异；同步前保留备份侧未提交改动，提交和推送仅在用户明确授权后进行。用下面这条**只列差异、不改文件**的命令核对（无输出即完全一致）：

```powershell
robocopy "C:\Users\Computer\.agents\skills" "C:\Users\Computer\Documents\GitHub\my-skills" /MIR /XD .git logs "C:\Users\Computer\Documents\GitHub\my-skills\desktop-launchers" /XF "C:\Users\Computer\Documents\GitHub\my-skills\.gitattributes" "C:\Users\Computer\Documents\GitHub\my-skills\.gitignore" /L /NDL /NJH /NJS /NP
```

去掉 `/L` 才会真正复制。此时务必先确认备份里没有尚未同步到活动目录的改动：`/MIR` 是单向镜像，会把备份独有的文件删掉、把备份里更新的内容盖回旧版。先逐项比较并合并双方有效改动，再决定是否执行镜像；不要整目录反向覆盖。

`/XF` 必须写**绝对路径**：它按文件名匹配，只写 `.gitignore` 会把 `oil-cover\.gitignore`、`web-access\.gitignore` 这些上游自带的同名文件一并排除，导致它们永远同步不过来。`/XD logs` 排除运行期日志；`.gitattributes`、`.gitignore` 和 `desktop-launchers` 只存在于备份侧，不排除就会被 `/MIR` 删掉。

`.agents\external` 下的源仓库和备份**不在**这个仓库里，丢了要按 `skills-sources.json` 的 remote 重新 clone。

备份仓库里不保留任何嵌套的 `.git`。`img2threejs` 和 `oil-cover` 曾因为带着自己的 `.git` 被 Git 记成 gitlink（模式 160000），仓库里只存了一个 commit 指针、实际内容一个文件都没备份，合计 432 个文件；又因为没有 `.gitmodules`，`git submodule update --init` 也救不回来，克隆出来只会是两个空目录。现在这三个曾含嵌套仓库的 skill（连同 `web-access`）都按普通文件追踪。

因此往这个目录里放新 skill 时，如果它本身是 Git 仓库，必须先删掉它的 `.git` 再提交，否则会重新退化成 gitlink。对应地，从备份还原 `git` 型 skill 时活动目录不会带 `.git`，需要按登记的 remote 重新 clone 或 init。

各 skill 自带的 `.gitignore` 依然生效，所以 `web-access\config.env`（本地浏览器偏好）和 `img2threejs\.cache\` 不进备份，这是预期行为。

桌面入口不在活动目录里，因此单独备份在 `desktop-launchers\`：`update-impeccable.bat`、`更新 Skills.bat`、`纳管新 Skill.bat`。改动这些入口时同样先改备份再复制回桌面。桌面上其他与 skills 无关的 .bat 不纳入。

所有 `.ps1` 必须存为 **UTF-8 带 BOM**。Windows PowerShell 5.1 会把无 BOM 的文件按 ANSI 读取，中文字符串会碎成乱码并导致解析失败——`update-impeccable.ps1` 曾因全文件仅含 ASCII 而长期掩盖了这个问题，直到往里加中文才暴露。

仓库里的 `.gitattributes` 用 `* -text` 关掉了 Git 的行尾转换，这样任何机器克隆都能逐字节还原活动目录。不要删掉它，否则 `core.autocrlf` 会重新在还原时改写行尾。

## 删除和恢复

删除一个 skill 时同步处理：

1. `C:\Users\Computer\.agents\skills` 活动目录。
2. `skills-sources.json` 来源登记。
3. `local-routing-overrides.json` 对应规则。
4. `C:\Users\Computer\.claude\skills` 入口。
5. 其他活动 skill 对它的依赖或 Related Skills 引用。

删除前把可恢复副本放到 `C:\Users\Computer\.agents\external`。恢复时不要只复制目录，还要恢复来源登记和需要的客户端入口，然后运行 `check`。

## 当前已移除

- 流程入口：`brainstorming`、`test-driven-development`、`verification-before-completion`、`using-git-worktrees`、`writing-plans`
- 通用或重复：`karpathy-guidelines`、本地 `skill-creator`
- 平台和低频：`health`、`workctl`、`workctl-operator`
- Vercel 组：`deploy-to-vercel`、`vercel-cli-with-tokens`、`vercel-composition-patterns`、`vercel-react-best-practices`
- 失效重流程：`extract-design`
- 已折叠进 `impeccable` 的旧设计辅助 skill

历史原因和具体变更保留在 `SKILL-ROUTING-CHANGELOG.md`，这里不重复展开。
