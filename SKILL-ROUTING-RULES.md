# Skill Routing Rules

这份文档不是介绍 skill 是什么，而是专门解决一个问题：

**当多个 skill 都“好像能做”时，默认应该先用谁。**

目标是减少误触发、减少抢活、减少风格漂移。

---

## 总原则

### 1. 默认 skill 要少

不是每个 skill 都适合当默认入口。

- 默认入口 skill：负责先接住模糊需求
- 按需触发 skill：只有用户目标非常明确时才启用
- 格式驱动 skill：只有输入或输出格式明确时才启用

### 2. 优先按“最终产物”路由

先问自己：用户最后到底要什么？

- 要网页
- 要 `.pptx`
- 要 HTML 演示稿
- 要 PDF
- 要 Word
- 要表格
- 要海报
- 要设计提取结果

不要只看关键词，要看**最后交付物**。

特别注意：

- 出现 `HTML` 不等于一定应该走 `html-ppt`
- 但如果用户明确要的是**展示型、演示型、PPT 风格、编辑部排版感**的静态 HTML 页面，`html-ppt` 也可能是正确选择

判断关键不是“它是不是网站”这一点，而是：

- 它更像正常产品网页/UI
- 还是更像演示稿式的展示页面

如果最终交付物是一个**正常网站 / 产品页面 / 应用界面**，优先归 `impeccable`。
如果最终交付物是一个**展示型、演示型、PPT 风格的静态 HTML 页面或 deck**，`html-ppt` 可以是合理选择。

### 3. 关键词命中不等于应该触发

例如：

- 用户说“做个 PPT”
  - 不代表一定是 `html-ppt`
  - 也不代表一定是 `ppt-master`
  - 先看是要网页演示，还是要 `.pptx`

- 用户说“帮我看设计”
  - 不代表一定是 `extract-design`
  - 先看是提取现有网站设计语言，还是在做正常 UI 设计

### 3.5 不要要求用户说出“标准咒语”

路由规则不能依赖用户必须说出某几个固定词。

要按这些层次判断：

1. 最终产物是什么
2. 工作流更像哪一类
3. 用户真实目标是什么
4. 关键词只是辅助，不是硬门槛

例如：

- `参考这个网站的风格做一个页面`
  - 不需要出现 `extract design`
  - 也能判断它和设计语言参考有关

- `把这份 PDF 做成正式汇报 PPT`
  - 不需要出现 `.pptx`
  - 也能判断它可能更适合 `ppt-master`

- `帮我整理成一个客户还能继续编辑的 Word 文档`
  - 不需要出现 `.docx`
  - 也能判断 `docx` 合适

如果用户说法模糊，但**最终交付物或工作流已经足够清楚**，就可以触发对应 skill。

### 4. 专项 skill 默认按需触发

这些 skill 默认不要抢普通请求：

- `extract-design`
- `html-ppt`
- `ppt-master`（外部相关能力）
- `canvas-design`
- `schema`
- `ai-seo`
- `vercel-cli-with-tokens`
- `brainstorming`
- `writing-plans`
- `using-git-worktrees`
- `vercel-react-best-practices`
- `hv-analysis`
- `khazix-writer`
- `officecli`

### 5. 不是所有 skill 都要加路由规则

只有真正存在冲突的 skill，才值得加本地路由规则。

不要为了形式统一而给所有 skill 都补 `Usage Rule`。

下面这些通常不需要额外加路由规则：

- 工程 / 流程型 skill（除非真实案例显示它会误拦其他流程）
- 平台 / 工具型 skill
- 研究 / 内容型 skill
- 设计辅助链里那些本来就协同使用的 skill

补充：

- 本文默认描述这个仓库里纳管的 skill；若出现 `ppt-master`，均按外部相关能力理解，只用于界定演示文稿路由边界，不代表它是这个仓库的镜像成员

如果一个 skill：

- 职责足够独立
- 不会抢别的最终产物
- 不在高冲突簇里

那就保持默认，不要过度治理。

---

## 默认入口 Skill

这些 skill 可以作为各自领域的默认入口。

### 设计与前端默认入口

- `impeccable`

适用：

- 普通网页
- 应用页面
- 组件
- dashboard
- landing page
- 复杂交互 Web app / React demo / mini-app
- 正常的 UI 创建和迭代

不要默认切到这些：

- 提取设计语言：`extract-design`
- 静态海报：`canvas-design`
- HTML 演示稿：`html-ppt`

判断口诀：

- 正常产品网页 / landing page / 应用界面 / 复杂交互 Web app → `impeccable`
- 演示型、PPT 风格、editorial 风格静态 HTML 页面 → `html-ppt`
- 静态视觉物料 → `canvas-design`
- 提取现有网站设计语言 → `extract-design`

`impeccable` 也是原设计辅助链的统一入口。旧的 `adapt`、`animate`、`audit`、`clarify`、`critique`、`delight`、`distill`、`harden`、`optimize`、`polish`、`typeset` 独立 skill 已删除；`bolder`、`quieter`、`colorize`、`layout`、`onboard`、`overdrive`、`live`、`init`、`document`、`extract` 等上游命令也通过 `impeccable/reference/*.md` 和 `$impeccable <command>` 子命令承接。`teach` 仅作为 `init` 的 deprecated alias 兼容旧说法。

### SEO 默认入口

- `seo-audit`

适用：

- “SEO 不太行”
- “为什么没排名”
- “流量掉了”
- “帮我做个 SEO 审计”
- 技术 SEO / 页面 SEO / 抓取索引问题

不要默认切到这些：

- 结构化数据：`schema`
- AI 搜索优化：`ai-seo`

### Vercel 默认入口

- `deploy-to-vercel`

适用：

- 普通部署
- preview deployment
- 链接项目
- 给我一个线上地址

不要默认切到：

- token 登录/CI/token automation：`vercel-cli-with-tokens`

---

## 按需触发 Skill

这些 skill 只有在目标很明确时才应该触发。

### `brainstorming`

只在这些情况触发：

- 创造性产品或设计工作
- 创建新功能、新组件、新工作流或新产品界面
- 添加新能力，且用户意图、约束或成功标准还需要探索
- 有意改变既定产品行为或 UX
- 实现前需要比较多个设计方案

不要用于：

- Bug 修复
- 测试失败或构建失败
- 回归修复
- 恢复已有行为
- 预期行为已经明确的直接实现任务

这些情况优先走工程修复流程：

- `systematic-debugging`：先定位根因
- `test-driven-development`：先建立失败的回归测试或可复现检查
- `verification-before-completion`：完成前用新鲜验证证据支撑结论

关键区分：

- 恢复既有预期行为 → 调试流程
- 设计新的预期行为 → 头脑风暴流程

### `writing-plans`

只在这些情况触发：

- 已有明确规格或多步骤需求，需要拆成实施计划
- 多文件、多阶段或多依赖的任务需要先规划
- 需要保存可交接的计划文档
- 需要给后续 agent 或未来会话做执行交接

不要默认用于：

- 单个简单代码改动
- 普通 bug 修复
- 用户已经要求直接实现的任务
- 可以用当前会话 todo list 管住的小型任务

OpenCode 中的本地边界：

- 不要假设必须存在 `superpowers:subagent-driven-development` 或 `superpowers:executing-plans`
- 如果上游正文提到未安装的执行 skill，改用 OpenCode 可用的 `todowrite`、`task`、直接编辑和验证命令
- 不要默认写计划文档或 commit，除非用户明确要保存计划或任务规模确实需要持久交接

### `using-git-worktrees`

只在这些情况触发：

- 并行开发需要隔离当前工作区
- 临时 hotfix、PR 检查或多方案实验
- 多 agent 并行或大型实施计划需要隔离基线
- 用户明确要求开独立 worktree

不要默认用于：

- 只读调查
- 小 bug 修复
- 单文件改动
- 简单配置或文档更新
- 当前工作区就是预期编辑位置的任务

关键判断：隔离有价值才开 worktree；普通小修直接在当前工作区做，同时尊重已有未提交改动。

### `vercel-react-best-practices`

只在这些情况触发：

- React / Next.js 性能问题
- data fetching、server/client rendering、hydration、bundle size
- React 过度渲染、waterfall、jank、加载慢
- 性能导向的 React / Next.js code review 或 refactor

不要默认用于：

- 纯视觉 UI 创建
- landing page 或产品界面的美术方向
- 普通 impeccable 任务
- 没有性能证据支撑的大范围重构

相邻 skill 边界：

- 视觉和产品界面质量 → `impeccable`
- 组件 API、boolean props、compound components → `vercel-composition-patterns`
- 最小改动和避免过度设计 → `karpathy-guidelines`

### `hv-analysis`

只在这些情况触发：

- 系统性研究产品、公司、概念、技术、市场或人物
- 需要横纵分析：纵向历史 + 横向竞品/同类对比
- 需要深度研究、竞品分析或结构化调研
- 负责研究内容生成和研究报告产出，PDF 可作为输出格式

不要默认用于：

- 简单解释“XX 是什么”
- 普通代码库分析、bug 调试或实现规划
- SEO / schema / AI 搜索优化
- 公众号文章写作
- 已有 PDF、DOCX、PPTX、表格或 HTML 交付物的处理、转换或编辑

关键判断：研究内容生成和研究报告产出 → `hv-analysis`；文章/稿子 → `khazix-writer`；已有文件处理、转换或编辑 → 格式 skill；快速解释或技术回答 → 不默认用深度研究 skill。

### `khazix-writer`

只在这些情况触发：

- 公众号文章
- 长文、稿子、出稿
- 续写、扩写、改写成文章
- 按数字生命卡兹克风格写作
- 把素材整理成可发布的文章或 essay

不要仅因为输入是 PDF、brief、新闻链接、语音转文字或散乱素材就触发。

按最终产物路由：

- 研究内容生成和研究报告产出 → `hv-analysis`
- PDF 处理或最终 PDF 交付 → `pdf`
- 可编辑 Word 文档 → `docx`
- PowerPoint / PPTX → `pptx` 或 `ppt-master`
- HTML 演示稿 → `html-ppt`
- SEO / schema / AI 搜索 → 对应 SEO skill
- 短帖、标题生成、简单摘要 → 不默认用 `khazix-writer`

### `extract-design`

只在这些情况触发：

- 提取网站设计语言
- 提取 colors / fonts / spacing / shadows / tokens
- 生成 Tailwind config / CSS variables / Figma variables
- 从现有网站反推设计系统

不要默认用于：

- 日常 UI 创建
- polish
- critique
- typography 优化

### `canvas-design`

只在这些情况触发：

- 海报
- 封面
- 单页视觉稿
- PNG / PDF 静态视觉物料

不要默认用于：

- 网页 UI
- HTML 演示稿
- `.pptx` 文稿

### `html-ppt`

只在这些情况触发：

- HTML 演示稿
- 浏览器 slides
- reveal-style deck
- 网页分享稿
- 小红书图文风多页演示
- presenter mode / keyboard navigation 是目标的一部分
- 演示型、PPT 风格、editorial 风格的静态 HTML 页面

不要默认用于：

- 泛化“做个 PPT”请求
- 最终必须交付 `.pptx` 的请求

### `ppt-master`（外部相关能力）

只在这些情况触发：

- 从 PDF / DOCX / URL / Markdown 生成正式可编辑 `.pptx`
- 明确要 PowerPoint 成品
- 明确提到 `ppt-master`

不要默认用于：

- 普通演示需求
- HTML deck
- 改现有 `.pptx`

补充说明：

- `ppt-master` 当前按外部独立仓库管理，不是这个仓库收录的普通 skill 目录成员，也不在这个仓库的普通 skills 镜像 / override 自动回写范围内

### `schema`

只在这些情况触发：

- JSON-LD
- schema.org
- structured data
- rich results
- FAQ / Product / Review / Breadcrumb schema

不要默认用于：

- 泛 SEO 审计
- AI SEO

### `ai-seo`

只在这些情况触发：

- AI SEO
- AEO / GEO / LLMO
- AI Overviews
- ChatGPT / Perplexity / Claude / Gemini 引用
- LLM citations

不要默认用于：

- 泛 SEO 审计
- schema 实现

### `vercel-cli-with-tokens`

只在这些情况触发：

- `VERCEL_TOKEN`
- token auth
- CI / non-interactive deploy
- token automation

不要默认用于：

- 普通 Vercel 部署

### `officecli`

只在这些情况触发：

- 用户显式要求使用 `officecli` 或需要具体命令
- 需要 `validate`、`view issues`、原始 OpenXML、XPath 式编辑等 officecli 专属能力
- 需要一个 CLI 工作流同时处理 DOCX / XLSX / PPTX
- 某个格式 skill 已明确选择 officecli 作为实现工具

不要默认用于：

- 普通 Word 创建或编辑：优先 `docx`
- 普通表格创建或编辑：优先 `xlsx`
- 普通 PowerPoint 创建或编辑：优先 `pptx`

判断关键不是“有没有 Office 文件”，而是“用户是否需要 officecli 这层工具能力”。

---

## 格式驱动 Skill

这些 skill 的触发判断优先看**输入输出格式**。

### `pdf`

触发条件：

- 明确输入是 PDF
- 明确输出要 PDF
- 明确要 OCR / 表单 / 拆分 / 合并 / 水印 / 提取

不要默认用于：

- 泛写作
- 普通文档润色

### `docx`

触发条件：

- 明确输入是 `.docx`
- 明确输出要 `.docx`
- Word 文档结构、格式、批注、目录相关任务

不要默认用于：

- 只是“帮我写一份报告”但并没有要求 Word 文件

### `xlsx`

触发条件：

- 明确输入是 `.xlsx` / `.csv` / `.tsv`
- 明确输出要表格文件
- 清洗表格、补公式、做图表、转格式

不要默认用于：

- 只是做数据分析结论
- 不需要交付电子表格文件的请求

### `pptx`

触发条件：

- 明确输入是 `.pptx`
- 明确输出要 `.pptx`
- 修改、拆分、合并、整理 PowerPoint 文件

不要默认用于：

- HTML 演示稿

---

## 当前高冲突簇

为了方便以后继续维护，当前真正需要重点关注的冲突簇只有这些：

1. 前端展示簇
2. 演示文稿簇
3. 文档格式簇
4. SEO 簇
5. Vercel 簇
6. 流程入口簇
7. React 工程簇
8. 内容研究 / 写作簇
9. Office 格式 / 工具簇

除了这些之外，不要轻易再扩张本地路由规则范围。

---

## 常见冲突对照

### 1. `impeccable` vs `extract-design` vs `canvas-design`

默认顺序：

1. 普通网页/UI：`impeccable`
2. 提取设计语言：`extract-design`
3. 静态海报/封面：`canvas-design`

一句话判断：

- 做网页：`impeccable`
- 拆现有网站设计：`extract-design`
- 做视觉物料：`canvas-design`

### 2. `pptx` vs `html-ppt` vs `ppt-master`

默认顺序：

1. 改现有 `.pptx`：`pptx`
2. 做 HTML 演示稿：`html-ppt`
3. 从资料生成正式可编辑 `.pptx`：`ppt-master`（外部相关能力）

一句话判断：

- 要 `.pptx` 文件并编辑现成内容：`pptx`
- 要网页 deck：`html-ppt`
- 要正式可编辑 PPTX 成品：`ppt-master`（外部相关能力）

补充：

- `做一个 PPT 风格的单页网站`：如果重点是展示型静态 HTML 页面，`html-ppt` 可以是合适选择；如果重点是正常产品网站体验，归 `impeccable`
- `做一套浏览器里翻页的 slides`：归 `html-ppt`

### 3. `seo-audit` vs `schema` vs `ai-seo`

默认顺序：

1. 泛 SEO 问题：`seo-audit`
2. 结构化数据：`schema`
3. AI 搜索和引用：`ai-seo`

一句话判断：

- SEO 先查病：`seo-audit`
- schema 落地：`schema`
- AI 可见性：`ai-seo`

### 4. `deploy-to-vercel` vs `vercel-cli-with-tokens`

默认顺序：

1. 普通部署：`deploy-to-vercel`
2. token / CI / 非交互：`vercel-cli-with-tokens`

一句话判断：

- 正常发版：`deploy-to-vercel`
- token 特殊场景：`vercel-cli-with-tokens`

### 5. `brainstorming` vs 工程修复流程

默认顺序：

1. Bug、回归、测试失败、构建失败、恢复已有行为：`systematic-debugging` → `test-driven-development` → `verification-before-completion`
2. 新功能、新组件、新能力、有意改变产品行为：`brainstorming`

一句话判断：

- 恢复本来就该有的行为：不要走 `brainstorming`
- 需要决定未来应该是什么行为：走 `brainstorming`

补充：

- `修改行为` 不是充分触发条件；要先判断是“修复偏离预期”还是“重新定义预期”
- 如果调试过程中发现预期行为本身不明确，再暂停并转入 `brainstorming`

### 6. `writing-plans` / `using-git-worktrees` vs 直接执行

默认顺序：

1. 小型直接任务：当前工作区 + todo list + 验证命令
2. 多步骤但不需要隔离：`writing-plans` 或直接 todo list，按任务规模判断
3. 需要隔离、并行、hotfix、实验：`using-git-worktrees`

一句话判断：

- 需要想清楚怎么做：考虑 `writing-plans`
- 需要隔离在哪里做：考虑 `using-git-worktrees`
- 只是小修小改：不要默认触发这两个

补充：

- OpenCode 中不要因为上游正文提到未安装的 execution skill 就阻塞
- 可以把计划交接翻译成 `todowrite`、`task`、直接编辑和验证命令

### 7. `impeccable` vs `vercel-react-best-practices` vs `vercel-composition-patterns`

默认顺序：

1. 视觉 / 页面 / 产品界面 / 交互功能实现：`impeccable`
2. React / Next 性能、渲染、数据获取、bundle：`vercel-react-best-practices`
3. 组件 API、组合模式、boolean props：`vercel-composition-patterns`

一句话判断：

- 看起来如何、页面如何设计、交互功能如何实现：`impeccable`
- 跑得快不快、渲染/加载是否健康：`vercel-react-best-practices`
- 组件 API 是否可扩展：`vercel-composition-patterns`

补充：

- 复杂交互 React demo、mini-app、多组件 Web app，如果目标是 UI / 功能实现，归 `impeccable`
- 如果目标是 React / Next 性能、渲染、bundle、hydration 或 data fetching，才归 `vercel-react-best-practices`

### 8. `hv-analysis` vs `khazix-writer` vs 文档格式 skill

默认顺序：

1. 需要研究内容生成并产出研究报告：`hv-analysis`
2. 公众号文章 / 长文 / 稿子：`khazix-writer`
3. 已有文件处理、格式转换、编辑文件：`pdf` / `docx` / `pptx` / `xlsx` / `html-ppt` / `ppt-master`
4. 简单解释、摘要、技术回答：不用默认触发深度研究或写作风格 skill

一句话判断：

- 需要研究内容生成并产出报告：`hv-analysis`
- 最终是文章：`khazix-writer`
- 已有文件处理、格式转换、编辑文件：格式 skill 优先
- 最终只是回答问题：普通回答优先

特别注意：

- `hv-analysis` 的 PDF 研究报告指“先做研究内容，再生成报告”
- `pdf` 指“已有 PDF 的读取、OCR、拆分、合并、表单、转换、编辑或最终 PDF 文件处理”

### 9. `officecli` vs `docx` vs `xlsx` vs `pptx`

默认顺序：

1. 明确的 Word / Excel / PowerPoint 交付物：按格式使用 `docx` / `xlsx` / `pptx`
2. 明确要求 officecli 命令、OpenXML、校验修复或跨格式 CLI：使用 `officecli`

一句话判断：

- 目标是把文件做好：格式 skill 优先
- 目标是用 officecli 检查、修复或自动化：`officecli`

不要因为 `officecli` 同时支持三种格式，就让它接管所有 Office 文件任务。

---

## Impeccable 子命令边界

旧设计辅助链不再作为独立 skill 目录存在。下列请求都归 `impeccable`，并按其子命令或 reference 文件执行：

- `craft`：先 shape 再端到端构建功能
- `shape`：实现前做 UX/UI 方案
- `init`：建立 PRODUCT.md / DESIGN.md / live config 设计上下文；`teach` 仅作为 deprecated alias
- `document`：从现有前端代码生成或刷新 DESIGN.md
- `extract`：从当前前端项目中抽取可复用设计系统资产；不要用于 live-site 设计语言提取
- `adapt`：响应式、跨设备、断点、触摸目标
- `animate`：动效、过渡、micro-interactions
- `audit`：前端技术质量检查、a11y、性能、响应式、anti-patterns
- `critique`：UX / 视觉层级 / 信息架构评审
- `clarify`：UX copy、错误文案、标签、说明
- `distill`：简化、去噪、减少复杂度
- `harden`：错误状态、i18n、文本溢出、边界数据
- `optimize`：UI 体感性能、加载速度、动画流畅度、图片重量和布局稳定性
- `polish`：上线前细节、对齐、间距、一致性
- `bolder`：放大保守或无记忆点的设计
- `quieter`：压低过度刺激或过强的设计
- `onboard`：首次使用、空状态、激活路径
- `colorize`：给单调 UI 增加有策略的色彩
- `typeset`：字体、层级、字号、可读性
- `layout`：间距、节奏、视觉层级和版式
- `delight`：愉悦感、人格化细节、记忆点
- `overdrive`：把已成立的方向推到更强表达
- `live`：浏览器里选择元素并生成视觉变体

边界仍然保留：

- 设计语言提取 / tokens / CSS variables / Tailwind config → `extract-design`
- 静态海报、封面、PNG/PDF 视觉物料 → `canvas-design`
- HTML/browser slide deck → `html-ppt`
- React / Next 性能、渲染、bundle、hydration、data fetching → `vercel-react-best-practices`
- 组件 API、compound components、boolean props → `vercel-composition-patterns`

原因：

- 这些本来就是你设计工作流里的协同 skill
- 它们有交集是正常的
- 现在不适合为了“绝对互斥”而写死太多规则

---

## 当前结论

你本地这套 skill 路由目前已经达到一个比较稳的状态：

- 默认入口已经明确
- 高冲突专项 skill 已经改成按需触发
- 格式型 skill 已经改成格式明确再触发
- 已按真实误触发风险补上 `brainstorming` 与工程修复流程的边界
- 已收窄 `writing-plans`、`using-git-worktrees`、`vercel-react-best-practices`、`hv-analysis`、`khazix-writer` 的触发边界
- 已把 `officecli` 收窄为按需工具层，普通 Office 文件继续按最终格式路由
- `workctl` 与 `workctl-operator` 均已停用，不再提供 Work Agent 平台入口
- 剩下主要是设计链内部的柔性交集，不属于必须马上修的错误

如果后面再装新 skill，优先按这份文档判断它属于：

1. 默认入口
2. 按需触发
3. 格式驱动

再决定它的 `Usage Rule` 应该怎么写。
