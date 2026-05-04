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

如果最终交付物是一个**正常网站 / 产品页面 / 应用界面**，优先归 `frontend-design`。
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
- `ppt-master`
- `canvas-design`
- `web-artifacts-builder`
- `schema-markup`
- `ai-seo`
- `vercel-cli-with-tokens`

### 5. 不是所有 skill 都要加路由规则

只有真正存在冲突的 skill，才值得加本地路由规则。

不要为了形式统一而给所有 skill 都补 `Usage Rule`。

下面这些通常不需要额外加路由规则：

- 工程 / 流程型 skill
- 平台 / 工具型 skill
- 研究 / 内容型 skill
- 设计辅助链里那些本来就协同使用的 skill

如果一个 skill：

- 职责足够独立
- 不会抢别的最终产物
- 不在高冲突簇里

那就保持默认，不要过度治理。

---

## 默认入口 Skill

这些 skill 可以作为各自领域的默认入口。

### 设计与前端默认入口

- `frontend-design`

适用：

- 普通网页
- 应用页面
- 组件
- dashboard
- landing page
- 正常的 UI 创建和迭代

不要默认切到这些：

- 提取设计语言：`extract-design`
- 静态海报：`canvas-design`
- HTML 演示稿：`html-ppt`
- 复杂 React artifact：`web-artifacts-builder`

判断口诀：

- 正常产品网页 / landing page / 应用界面 → `frontend-design`
- 演示型、PPT 风格、editorial 风格静态 HTML 页面 → `html-ppt`
- 复杂交互式 React artifact → `web-artifacts-builder`
- 静态视觉物料 → `canvas-design`
- 提取现有网站设计语言 → `extract-design`

### SEO 默认入口

- `seo-audit`

适用：

- “SEO 不太行”
- “为什么没排名”
- “流量掉了”
- “帮我做个 SEO 审计”
- 技术 SEO / 页面 SEO / 抓取索引问题

不要默认切到这些：

- 结构化数据：`schema-markup`
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

### `web-artifacts-builder`

只在这些情况触发：

- 多组件 React artifact
- 需要状态管理
- 需要 routing
- 更像交互 demo / mini-app

不要默认用于：

- 普通页面
- 普通网站 UI
- slide deck
- 静态海报

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

### `ppt-master`

只在这些情况触发：

- 从 PDF / DOCX / URL / Markdown 生成正式可编辑 `.pptx`
- 明确要 PowerPoint 成品
- 明确提到 `ppt-master`

不要默认用于：

- 普通演示需求
- HTML deck
- 改现有 `.pptx`

### `schema-markup`

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

除了这些之外，不要轻易再扩张本地路由规则范围。
- 从原始资料大规模生成新演示文稿时的重型流程

---

## 常见冲突对照

### 1. `frontend-design` vs `extract-design` vs `canvas-design` vs `web-artifacts-builder`

默认顺序：

1. 普通网页/UI：`frontend-design`
2. 提取设计语言：`extract-design`
3. 静态海报/封面：`canvas-design`
4. 复杂交互 artifact：`web-artifacts-builder`

一句话判断：

- 做网页：`frontend-design`
- 拆现有网站设计：`extract-design`
- 做视觉物料：`canvas-design`
- 做复杂交互 demo：`web-artifacts-builder`

### 2. `pptx` vs `html-ppt` vs `ppt-master`

默认顺序：

1. 改现有 `.pptx`：`pptx`
2. 做 HTML 演示稿：`html-ppt`
3. 从资料生成正式可编辑 `.pptx`：`ppt-master`

一句话判断：

- 要 `.pptx` 文件并编辑现成内容：`pptx`
- 要网页 deck：`html-ppt`
- 要正式可编辑 PPTX 成品：`ppt-master`

补充：

- `做一个 PPT 风格的单页网站`：如果重点是展示型静态 HTML 页面，`html-ppt` 可以是合适选择；如果重点是正常产品网站体验，归 `frontend-design`
- `做一套浏览器里翻页的 slides`：归 `html-ppt`

### 3. `seo-audit` vs `schema-markup` vs `ai-seo`

默认顺序：

1. 泛 SEO 问题：`seo-audit`
2. 结构化数据：`schema-markup`
3. AI 搜索和引用：`ai-seo`

一句话判断：

- SEO 先查病：`seo-audit`
- schema 落地：`schema-markup`
- AI 可见性：`ai-seo`

### 4. `deploy-to-vercel` vs `vercel-cli-with-tokens`

默认顺序：

1. 普通部署：`deploy-to-vercel`
2. token / CI / 非交互：`vercel-cli-with-tokens`

一句话判断：

- 正常发版：`deploy-to-vercel`
- token 特殊场景：`vercel-cli-with-tokens`

---

## 低优先级观察项

这些不是当前必须处理的冲突点，先观察即可：

- `clarify`
- `critique`
- `audit`
- `polish`
- `typeset`
- `adapt`
- `animate`
- `harden`
- `optimize`

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
- 剩下主要是设计链内部的柔性交集，不属于必须马上修的错误

如果后面再装新 skill，优先按这份文档判断它属于：

1. 默认入口
2. 按需触发
3. 格式驱动

再决定它的 `Usage Rule` 应该怎么写。
