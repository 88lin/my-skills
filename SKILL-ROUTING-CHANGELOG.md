# Skill Routing Changelog

这份文档记录本地 skills 路由治理的关键决策，重点回答 4 个问题：

1. 哪些 skill 加了路由规则
2. 为什么要加
3. 哪些 skill 明确保持默认，不额外加规则
4. 哪些判断已经经过人工确认

更新时间：2026-05-07（已同步当前保留文档状态）

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
- `web-artifacts-builder`
- `html-ppt`

加规则原因：

- 它们都可能产出 HTML、页面、展示物或视觉内容
- 用户表达经常模糊，例如“参考这个网站”“做个展示页”“PPT 风格单页”
- 不写边界就容易抢同一类任务

当前分工：

- `frontend-design`：正常网页 / UI / landing page / 产品界面
- `extract-design`：提取现有网站设计语言、颜色、字体、spacing、tokens
- `canvas-design`：静态视觉稿、海报、封面、PNG/PDF 物料
- `web-artifacts-builder`：复杂 React artifact，多组件、状态管理、routing
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

---

## 明确保持默认的 Skill

这些 skill 没有额外补路由规则，属于刻意保留默认状态。

### 工程 / 流程型

- `systematic-debugging`
- `test-driven-development`
- `verification-before-completion`
- `writing-plans`
- `using-git-worktrees`
- `karpathy-guidelines`
- `receiving-code-review`

原因：

- 它们更像工作方法或流程节点
- 不属于“多个 skill 抢同一个最终产物”的冲突类型

### 平台 / 工具型

- `web-access`
- `health`
- `mindos-zh`
- `mcp-builder`
- `skill-creator`

原因：

- 用途相对独立
- 大多数情况下没必要为了形式统一而强行加限制

### 研究 / 内容型

- `brainstorming`
- `hv-analysis`
- `khazix-writer`
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
- `teach-impeccable`

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
   - `web-artifacts-builder`
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

这些组之外的大多数 skill，不需要为了形式统一继续补更多路由规则。

### 当前无需额外加规则的 skill 组

以下这几类当前明确保持默认，不再继续硬加路由规则：

- 工程 / 流程型：`systematic-debugging`、`test-driven-development`、`verification-before-completion`、`writing-plans`、`using-git-worktrees`、`karpathy-guidelines`、`receiving-code-review`
- 平台 / 工具型：`web-access`、`health`、`mindos-zh`、`mcp-builder`、`skill-creator`
- 研究 / 内容型：`brainstorming`、`hv-analysis`、`khazix-writer`、`luo-xiang-perspective`、`create-crush`
- 设计辅助链：`adapt`、`animate`、`audit`、`clarify`、`critique`、`delight`、`distill`、`harden`、`optimize`、`polish`、`typeset`、`teach-impeccable`

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
