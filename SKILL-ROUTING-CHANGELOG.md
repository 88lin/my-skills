# Skill Routing Changelog

这份文档记录本地 skills 路由治理的关键决策，重点回答 4 个问题：

1. 哪些 skill 加了路由规则
2. 为什么要加
3. 哪些 skill 明确保持默认，不额外加规则
4. 哪些判断已经经过人工确认

更新时间：2026-05-12（已同步流程入口、React 工程、内容研究 / 写作边界；本轮追加：设计辅助链与 frontend-design 的边界、writing-plans / brainstorming 去 superpowers/elements-of-style 死链、新增 bodyPatches override 机制）

---

## 本轮治理目标

这轮治理不是为了“让所有 skill 都变得更严”，而是为了避免两种问题：

- 高冲突 skill 互相抢触发
- 规则写得过死，导致真正该触发的时候又漏掉

最终采用的原则是：

- 真正有冲突的 skill 才加路由规则
- 没必要互斥的 skill 保持默认
- 不靠固定关键词死触发，优先看最终产物、工作流类型、真实意图

---

## 已加路由规则的 Skill

这些 skill 之间存在真实冲突，已经补了 `Usage Rule` 或等价的触发收窄说明。

### 前端展示簇

- `frontend-design`
- `extract-design`
- `canvas-design`
- `html-ppt`

加规则原因：

- 它们都可能产出 HTML、页面、展示物或视觉内容
- 用户表达经常模糊，例如“参考这个网站”“做个展示页”“PPT 风格单页”
- 不写边界就容易抢同一类任务

当前分工：

- `frontend-design`：正常网页 / UI / landing page / 产品界面；复杂交互 Web app / React demo / mini-app 的 UI / 功能实现
- `extract-design`：提取现有网站设计语言、颜色、字体、spacing、tokens
- `canvas-design`：静态视觉稿、海报、封面、PNG/PDF 物料
- `html-ppt`：演示型、展示型、PPT 风格、editorial 风格的静态 HTML 页面或 deck

### 演示文稿簇（含外部相关能力）

- `pptx`
- `ppt-master`（外部相关能力）
- `html-ppt`

加规则原因：

- 都会碰到 `PPT` / `slides` / `deck` / `演示文稿` 这种词
- 但最终交付物差异极大

当前分工：

- `pptx`：修改、拆分、整理现有 `.pptx`
- `ppt-master`（外部相关能力）：从 PDF / DOCX / URL / Markdown 等资料生成正式可编辑 `.pptx`
- `html-ppt`：浏览器展示用的 HTML 演示稿

补充说明：

- `ppt-master` 当前按外部独立仓库管理，不在这个仓库的普通 skills 镜像和 override 自动回写范围内
- 这里把它写进变更记录，只是为了说明演示文稿路由边界，不代表它已经被纳入这个仓库的普通 skill 成员列表

### 文档格式簇

- `pdf`
- `docx`
- `xlsx`
- `pptx`

加规则原因：

- 都是文件交付型 skill
- 用户经常不会直接说扩展名，而是说“给我一个能继续编辑的文档”“发个表格给财务”
- 如果不写规则，容易互相误吞

当前分工：

- `pdf`：PDF、扫描件、OCR、表单、合并拆分、PDF 导出
- `docx`：Word 文档、正式报告、备忘录、可继续编辑文档
- `xlsx`：工作簿、CSV/Excel、公式、图表、表格交付
- `pptx`：PowerPoint 文件本体处理

### SEO 簇

- `seo-audit`
- `schema-markup`
- `ai-seo`

加规则原因：

- 用户一说 SEO，三个 skill 都有可能抢
- 必须明确默认入口和专项分工

当前分工：

- `seo-audit`：默认 SEO 入口，泛 SEO 审计和诊断
- `schema-markup`：结构化数据 / JSON-LD / rich results
- `ai-seo`：AI 搜索可见性 / AI Overviews / LLM citations / AEO / GEO / LLMO

### Vercel 簇

- `deploy-to-vercel`
- `vercel-cli-with-tokens`

加规则原因：

- 普通部署请求和 token/CI 类请求容易混在一起

当前分工：

- `deploy-to-vercel`：默认 Vercel 部署入口
- `vercel-cli-with-tokens`：`VERCEL_TOKEN` / CI / 非交互 token 场景

### 流程入口簇

- `brainstorming`
- `systematic-debugging`
- `test-driven-development`
- `verification-before-completion`
- `writing-plans`
- `using-git-worktrees`

加规则原因：

- `brainstorming` 的原始描述包含“修改行为”，容易误吞 bug 修复、回归修复、恢复已有行为这类任务
- 真实使用中已经出现需要明确“不走创意功能设计流程”的案例
- 工程修复流程本身不需要互斥规则，但需要防止被 `brainstorming` 的 HARD-GATE 拦住
- `writing-plans` 和 `using-git-worktrees` 上游正文引用了部分本地未安装的执行 skill，需要明确 OpenCode 本地交接方式

当前分工：

- `brainstorming`：新功能、新组件、新能力、有意改变产品行为或 UX，需要先探索设计
- `systematic-debugging`：bug、异常行为、测试失败、构建失败、回归修复，先查根因
- `test-driven-development`：实现修复前建立失败测试或可复现检查
- `verification-before-completion`：完成前运行验证命令并用证据支撑结论
- `writing-plans`：已有明确规格或多步骤需求时，拆成可执行计划；小修不默认触发
- `using-git-worktrees`：只有隔离有价值时使用；日常小修不默认创建 worktree

### React 工程簇

- `frontend-design`
- `vercel-react-best-practices`
- `vercel-composition-patterns`
- `optimize`

加规则原因：

- `vercel-react-best-practices` 原始描述覆盖 writing / reviewing / refactoring React/Next.js code，范围偏宽
- 它容易把纯视觉 UI 任务导向性能和工程重构
- 需要保留它在 React / Next 性能、渲染、数据获取和 bundle 场景的价值，同时避免抢 `frontend-design`

当前分工：

- `frontend-design`：视觉、页面、产品界面、landing page、正常 UI 创建；复杂交互 Web app / React demo / mini-app 的 UI / 功能实现
- `vercel-react-best-practices`：React / Next 性能、渲染、hydration、data fetching、bundle、性能导向 review/refactor
- `vercel-composition-patterns`：组件 API、boolean props、compound components、可复用组件架构
- `optimize`：更泛的 UI 性能、加载速度、动画流畅度、图片和 bundle 诊断

### 内容研究 / 写作簇

- `hv-analysis`
- `khazix-writer`
- `pdf`
- `docx`
- `pptx`
- `xlsx`
- `html-ppt`
- `ppt-master`（外部相关能力）

加规则原因：

- `hv-analysis` 原始描述中的“研究一下 / 帮我分析 / 调研一下”容易覆盖轻量解释和普通分析
- `khazix-writer` 可以接收 PDF、brief、新闻链接、语音转文字等素材，容易和文件格式 skill 或深度研究 skill 交叠
- 这些任务必须优先按最终产物判断，而不是按输入材料判断

当前分工：

- `hv-analysis`：深度研究、横纵分析、竞品分析，负责研究内容生成和研究报告产出
- `khazix-writer`：公众号文章、长文、稿子、续写扩写，最终产物是文章
- 文件格式 skill：已有 PDF / DOCX / PPTX / XLSX / HTML deck 的处理、转换或编辑

---

## 明确保持默认的 Skill

这些 skill 没有额外补路由规则，属于刻意保留默认状态。

### 工程 / 流程型

- `systematic-debugging`
- `test-driven-development`
- `verification-before-completion`
- `karpathy-guidelines`
- `receiving-code-review`

原因：

- 它们更像工作方法或流程节点
- 不属于“多个 skill 抢同一个最终产物”的冲突类型

### 平台 / 工具型

- `web-access`
- `health`
- `mcp-builder`
- `skill-creator`

原因：

- 用途相对独立
- 大多数情况下没必要为了形式统一而强行加限制

### 研究 / 内容型

- `luo-xiang-perspective`
- `create-crush`

原因：

- 各自场景已经足够专
- 没有必要做互斥型路由规则

### 设计辅助链

- `adapt`
- `animate`
- `audit`
- `clarify`
- `critique`
- `delight`
- `distill`
- `harden`
- `optimize`
- `polish`
- `typeset`

原因：

- 它们是协同链，不是严格互斥链
- 现在强行加很多 `Do not use...` 反而会把设计工作流写死

---

## 已纠正的重要错误

### `html-ppt` 边界判断过窄

曾出现过一次关键误判：

- 把 `html-ppt` 错当成“只适合真正的 slides/deck”
- 进而把 `PPT 风格单页网站` 这类请求一律推给 `frontend-design`

这个判断已经修正。

当前正确理解：

- `html-ppt` 不只适合多页 slides
- 也适合演示型、PPT 风格、editorial 风格的静态 HTML 页面
- 判断关键不是“它是不是网站”，而是“它更像正常产品网页，还是更像展示型演示页面”

这条已经纳入：

- `html-ppt/SKILL.md`
- `frontend-design/SKILL.md`
- `SKILL-ROUTING-RULES.md`

### `brainstorming` 抢工程修复流程

曾出现过一个流程入口风险：

- `brainstorming` 原始描述中的“修改行为”会覆盖一部分 bug 修复语义
- 例如“恢复已有放大/翻页行为”本质是修复偏离预期，而不是重新设计行为
- 如果误触发 `brainstorming`，它的 HARD-GATE 会要求设计审批、规格文档和实现计划，导致普通修复流程变重

这个判断已经修正。

当前正确理解：

- 恢复既有预期行为 → `systematic-debugging` → `test-driven-development` → `verification-before-completion`
- 设计新的预期行为 → `brainstorming`
- `修改行为` 不是充分触发条件，必须判断是“修复偏离预期”还是“重新定义预期”

这条已经纳入：

- `brainstorming/SKILL.md`
- `local-routing-overrides.json`
- `SKILL-ROUTING-RULES.md`

### 流程 / React / 内容写作边界过宽

本轮补充修正了几类轻中度风险：

- `writing-plans`：不再默认接管普通小修；在 OpenCode 中不假设必须使用未安装的 superpowers execution skills
- `using-git-worktrees`：不再默认用于小 bug、只读调查、单文件改动；只有隔离有价值时触发
- `vercel-react-best-practices`：不再抢纯视觉 `frontend-design`；只在 React / Next 性能和工程质量任务中触发
- `hv-analysis`：不再抢简单解释、普通代码分析、SEO、公众号文章或格式交付任务
- `khazix-writer`：不再仅因输入是 PDF / brief / 新闻链接 / 转写稿就触发，必须看最终产物是否是文章

这些规则已经纳入：

- 对应 skill 的 `SKILL.md`
- `local-routing-overrides.json`
- `SKILL-ROUTING-RULES.md`

### 设计辅助链不再强制 invoke /frontend-design

曾经的做法是设计链 9 个 skill（adapt / animate / audit / clarify / critique / delight / distill / polish / typeset）顶部都写 "## MANDATORY PREPARATION: Invoke /frontend-design"。在 OpenCode 这种 skill 描述被同时加载到上下文的环境里，每个局部设计任务都会被迫先扫一遍完整 frontend-design 上下文 + 询问 design context，污染单点任务。

当前正确理解：

- 局部任务（如 typeset 调字体、clarify 改文案、adapt 加断点）只需要本任务的最小上下文
- 完整 frontend-design 上下文只在重新定义视觉方向 / 整体 UI 重做 / 新页面立项时加载
- 每个设计链 skill 在自己的 `## Preparation` 段定义"最小上下文清单"
- `harden`、`optimize` 本来就没有 invoke /frontend-design 的硬依赖，无需改动
- `frontend-design` 自身的 `.impeccable.md` 强依赖也已软化：找不到时参考 `~/.agents/skills/frontend-design/impeccable-template.md` 并当面询问最小字段，不阻塞

这条已经纳入：

- 各设计链 skill 的 `SKILL.md` 主体
- `frontend-design/SKILL.md` 的 Gathering order 段
- 新增 `frontend-design/impeccable-template.md`
- `SKILL-ROUTING-RULES.md` 新增"设计辅助链与 frontend-design 的边界"章节

### writing-plans / brainstorming 去掉未安装上游依赖

曾经的做法是 writing-plans 在主体里硬编码 "必需子技能：使用 superpowers:subagent-driven-development 或 superpowers:executing-plans"，brainstorming 在主体引用 "如果可用，使用 elements-of-style:writing-clearly-and-concisely 技能"。这些上游 skill 在 OpenCode / Codex / Claude Code 任何一个环境里都未安装。

当前正确理解：

- writing-plans 生成的计划文档不再要求特定执行子 skill；改为说"按当前 agent 环境可用的方式（todowrite、task、直接编辑、验证命令）逐任务推进"
- brainstorming 的写作风格指引改为普通原则（"用简洁、具体的语言；避免冗余、含糊和形容词堆叠"），不再引用 elements-of-style 上游 skill
- 修复通过新增的 `bodyPatches` override 机制实现，下次 `manage-skills.ps1 -Mode update` 拉新上游也会自动重新应用

这条已经纳入：

- `writing-plans/SKILL.md` 主体（通过 bodyPatches 回写）
- `brainstorming/SKILL.md` 主体（通过 bodyPatches 回写）
- `local-routing-overrides.json` 新增 `bodyPatches` 字段
- `manage-skills.ps1` 新增 bodyPatches 应用逻辑
- `LOCAL-ROUTING-OVERRIDES-USAGE.md` 增补 bodyPatches 字段说明

**追加修订（同期）：**

- writing-plans 执行交接的列表项再次中性化：去掉 `todowrite（OpenCode）/ TaskCreate（Claude Code）` 的环境绑定，改为 "用当前 agent 自带的任务清单 / todo 机制把计划落地为可勾选的进度（如果有这种工具的话）"；去掉 "每步完成后 commit" 的默认动作，改为 "是否在每步之间 commit，按用户偏好或项目 commit 策略决定，不要默认 commit"。
- brainstorming HARD-GATE 与反模式段的 scope 收窄：HARD-GATE 的 "适用于所有项目" 措辞改为 "适用于所有真正进入 brainstorming 的项目；bug 修复、回归恢复、build 失败、恢复已有行为不属于 brainstorming 的适用范围，应当走 systematic-debugging → test-driven-development → verification-before-completion"；反模式段同样补一段 "如果用户的请求是修复偏离预期的既有行为，按上文边界，应当退出 brainstorming，转入调试流程"。
- 这两条同样通过 `bodyPatches` 实现（writing-plans 第 2 条 patch 的 replace 文本被修订；brainstorming 新增 2 条 patch）；上游下次 update 不会冲掉。

---

## 已完成人工确认

本轮高冲突路由样本已经做过一轮人工 review，当前判断为“都对”。

补充说明：

- 当时用于 review 的评测辅助文件已按要求删除
- 当前保留的是规则结论和使用说明文件，不再保留那批测试辅助文档

这意味着：

- 当前高冲突场景的主路由判断已经过一轮人工确认
- 现阶段不用再继续大面积抽象加规则
- 后续应优先基于真实新案例增量修正

---

## 当前状态判断

当前这套不是“理论上已证明最优”，但已经是：

- 经过高冲突簇治理
- 修过明显错误
- 做过人工样本审查
- 可持续增量维护

更准确地说，它是：

**当前最佳已知方案**

而不是：

**永远不需要再调整的终极方案**

### 当前冲突簇判断

当前真正需要路由治理的，主要只有这几组：

1. 前端展示簇
   - `frontend-design`
   - `extract-design`
   - `canvas-design`
   - `html-ppt`
2. 演示文稿簇
   - `pptx`
   - `ppt-master`（外部相关能力）
   - `html-ppt`
3. 文档格式簇
   - `pdf`
   - `docx`
   - `xlsx`
   - `pptx`
4. SEO 簇
    - `seo-audit`
    - `schema-markup`
    - `ai-seo`
5. Vercel 簇
    - `deploy-to-vercel`
    - `vercel-cli-with-tokens`
6. 流程入口簇
   - `brainstorming`
   - `systematic-debugging`
   - `test-driven-development`
   - `verification-before-completion`
   - `writing-plans`
   - `using-git-worktrees`
7. React 工程簇
   - `frontend-design`
   - `vercel-react-best-practices`
   - `vercel-composition-patterns`
   - `optimize`
8. 内容研究 / 写作簇
   - `hv-analysis`
   - `khazix-writer`
   - 文档格式相关 skill

这些组之外的大多数 skill，不需要为了形式统一继续补更多路由规则。

### 当前无需额外加规则的 skill 组

以下这几类当前明确保持默认，不再继续硬加路由规则：

- 工程 / 流程型：`systematic-debugging`、`test-driven-development`、`verification-before-completion`、`karpathy-guidelines`、`receiving-code-review`
- 平台 / 工具型：`web-access`、`health`、`mcp-builder`、`skill-creator`
- 研究 / 内容型：`luo-xiang-perspective`、`create-crush`
- 设计辅助链：`adapt`、`animate`、`audit`、`clarify`、`critique`、`delight`、`distill`、`harden`、`optimize`、`polish`、`typeset`

理由很简单：

- 它们要么职责天然独立
- 要么本来就是协同链
- 没必要为了“看起来规范”而继续补互斥规则

---

## 后续维护方式

以后如果出现下面情况，再继续改：

1. 真实使用中发生误触发
2. 明显漏触发
3. 新装了和现有 skill 重叠的高冲突新 skill
4. 某个上游 skill 描述、frontmatter、仓库结构或安装方式有重大变化

推荐步骤：

1. 先记录真实错例：用户原话、期望触发、实际触发、造成的影响
2. 人工确认你真正想要的主 skill 和最终交付物
3. 再反推是否需要改某个 skill 的 `description` 或 `Usage Rule`

不要直接跳到第 3 步。

当前不再继续大修：

- 不继续扩张 `local-routing-overrides.json`
- 不为了统一风格重构路由文档结构
- 不把 `ppt-master` 强行纳入这个仓库的普通 skill 成员范围
- `web-access` 以真实本地目录 `C:\Users\Computer\.agents\skills\web-access` 的 Git 状态为准

---

## 相关文件

- 总路由规则：`C:\Users\Computer\.agents\skills\SKILL-ROUTING-RULES.md`
- html-ppt 本地 skill：`C:\Users\Computer\.agents\skills\html-ppt\SKILL.md`
- ppt-master 外部 skill：`C:\Users\Computer\.agents\external\ppt-master\skills\ppt-master\SKILL.md`

已删除的测试辅助文件：

- `ROUTING-EVALS.json`
- `ROUTING-EVALS.md`
- `ROUTING-EVALS-REVIEW.md`

删除原因：

- 这些文件主要用于阶段性评测和人工审查
- 当前你只保留正式规则和说明文件，不长期保留测试辅助文档
