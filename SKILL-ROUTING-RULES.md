# Skill Routing Rules

这份文档用于解决多个 skill 都能处理同一请求时的默认路由问题。它是维护参考，不直接参与运行时触发。

真正参与触发的是各 skill `SKILL.md` frontmatter 中的 `description`。需要长期保留本地边界时，修改 `local-routing-overrides.json`，再运行 `manage-skills.ps1 -Mode apply-overrides`。

## 总原则

### 1. 先看最终产物和真实工作流

不要只按关键词匹配。先判断用户最终要的是：

- 正常网页或应用界面
- HTML 演示稿
- Word、Excel、PowerPoint 或 PDF 文件
- 静态海报或视觉物料
- 研究报告、文章或普通回答
- 调试、网页交互或底层工具能力

同一个词可能对应不同工作流。例如“PPT”可能是 `.pptx`，也可能是浏览器 deck；“设计”可能是创建 UI，也可能只是分析现有页面。

### 2. 不要求用户说出标准关键词

用户不需要准确说出 skill 名或文件扩展名。最终产物、输入格式和真实目标足够清楚时，就可以选择对应 skill。

反过来，出现某个关键词也不代表必须触发对应 skill。`HTML` 不自动等于 `html-ppt`，`PDF` 作为输入也不自动等于最终要交付 PDF。

### 3. 默认入口要少，专项能力按需触发

- 默认入口：接住所属领域的模糊需求。
- 格式驱动：输入或输出格式明确时触发。
- 专项能力：只有其独特工作流确实需要时触发。
- 显式参考：通常只在用户点名时触发。

不要为了形式统一给每个 skill 添加 override。职责独立、没有真实误触发记录的 skill 保持上游默认。

### 4. 小任务不等于不验证

目标明确、影响面小的修改可以直接处理，不必为了“走流程”加载额外 skill。验证仍然要做，但深度与风险、改动范围和可观察性相称。

- 能用静态检查确认的，不默认启动服务器或浏览器。
- 交互、响应式、渲染或运行时问题无法从代码判断时，再使用浏览器验证。
- 涉及部署、数据迁移、生产行为或较大影响面时，扩大验证范围。

### 5. 多个候选同时匹配时选择最小完整集合

优先选择能完整覆盖目标、同时引入最少额外流程的 skill。只有任务确实包含多个独立交付物时才组合使用多个 skill。

## 路由边界

### 前端与设计

#### `impeccable`

用于需要设计判断的前端工作：

- 新页面、组件、dashboard、landing page 或应用界面
- 显著重构、全新视觉方向或交互模型
- 设计系统、UX 方向、设计审查或明确的 Impeccable 命令

目标已经明确的文案替换、单点样式、直接 CSS 修复和现有组件小改通常直接处理。外部网站的颜色、字体或设计语言分析使用轻量网页读取和分析，不再生成独立设计提取工程。

#### `canvas-design`

只用于海报、封面、单页视觉稿以及 PNG/PDF 静态设计物料，不接管网页 UI、HTML deck 或 `.pptx`。

#### `html-ppt`

用于浏览器交付的 HTML deck、reveal-style slides、演示型多页网页、小红书图文或 PPT 风格静态展示页。

普通产品网站和应用界面归 `impeccable`；最终需要可编辑 `.pptx` 时归 PowerPoint 工作流。

#### `webapp-testing`

只在以下情况触发：

- 用户明确要求浏览器或运行时验证
- 需要复现运行时 UI bug
- 交互、响应式、渲染或控制台行为无法从代码和静态检查判断

优先复用已有服务器。只有目标场景确实需要时才启动开发服务器、Playwright 或截图流程。

### 调试

#### `systematic-debugging`

用于需要系统化根因调查的故障：

- 根因不明确或复现不稳定
- 已有多次修复尝试仍失败
- 涉及多个组件、进程或环境边界
- 生产事故或复杂测试、构建失败

原因和修复都已经清楚、影响面很小的 bug 不自动触发。此类任务直接确认原因、实施最小修复并运行相称验证。

`systematic-debugging` 不依赖已删除的 TDD、完成验证或计划类 skill。删除这些 skill 不代表跳过测试或验证，而是由当前任务的风险决定具体检查方式。

### SEO

默认顺序：

1. 泛 SEO、排名、索引、抓取和流量问题：`seo-audit`
2. JSON-LD、schema.org 和 rich results：`schema`
3. AI Overviews、AEO/GEO/LLMO 和 LLM 引用：`ai-seo`

三个 skill 可以在复杂项目中协作，但模糊的“SEO 有问题”默认先由 `seo-audit` 诊断。

### 研究与写作

#### `hv-analysis`

用于深度研究、横纵分析、竞品分析和研究报告内容生成。简单解释、普通技术分析、已有文件编辑或格式转换不触发。

#### `khazix-writer`

用于公众号文章、长文、稿子、续写和卡兹克风格写作。输入是 PDF、链接、brief 或转写稿不会自动触发，最终产物必须是文章。

如果同时需要研究与文章，先完成必要研究，再进入文章写作；不必因为最终导出 PDF 就把整个内容工作流交给 `pdf`。

#### `luo-xiang-perspective`

仅在用户明确要求罗翔视角或命中相关触发词时使用，不替代律师的个案法律意见。

### Office 与文件格式

按最终文件格式路由：

- Word / `.docx`：`docx`
- Excel / `.xlsx` / `.xlsm` / `.csv` / `.tsv`：`xlsx`
- PowerPoint / `.pptx`：`pptx`
- PDF：`pdf`

Codex 当前环境存在对应的第一方 artifact skill 时优先使用第一方能力；本地格式 skill 保留为显式调用、后备以及 Claude/OpenCode 等客户端入口。

仅写作、分析或整理内容而不需要文件交付时，不因“报告”“表格”“PPT”等泛称自动加载格式 skill。

#### `officecli`

只用于以下独特能力：

- 用户显式要求 officecli 命令
- OpenXML 检查、schema 验证、`view issues` 或原始 XML/XPath 编辑
- 一个 CLI 工作流需要同时处理 DOCX、XLSX 和 PPTX
- 格式 skill 明确选择 officecli 作为实现工具

普通 Office 文件创建和编辑仍按最终格式路由。

### 网络

#### `web-access`

按上游原始规则作为统一联网入口，覆盖搜索、网页读取、公开资源、登录态、动态 JavaScript、反爬平台、浏览器交互和本机浏览器书签/历史。

加载后由 skill 自己根据任务选择 WebSearch、WebFetch、curl、Jina 或浏览器 CDP。恢复上游规则后，不再维护本地窄 description 或 Usage Rule。

### 显式参考 Skill

以下 skill 不根据普通上下文自动触发：

- `chinese-code-review`
- `chinese-commit-conventions`
- `chinese-documentation`
- `officecli`，除非任务需要其独特底层能力

## 常见冲突对照

### 网页、HTML 演示和静态视觉

| 目标 | 默认路由 |
|---|---|
| 正常产品网页、应用界面、交互 UI | `impeccable` |
| 浏览器 slides、HTML deck、PPT 风格展示页 | `html-ppt` |
| 海报、封面、PNG/PDF 静态视觉稿 | `canvas-design` |
| 仅分析外部网站设计语言 | 轻量网页读取与直接分析 |

### PowerPoint 与 HTML deck

| 目标 | 默认路由 |
|---|---|
| 修改现有 `.pptx` 或交付可编辑 PowerPoint | Codex 第一方 presentation skill；本地 `pptx` 为后备 |
| 浏览器中翻页或分享的 deck | `html-ppt` |
| 从 PDF/DOCX/URL/Markdown 生成正式 PPTX | 外部 `ppt-master` 工作流 |

`ppt-master` 位于 `C:\Users\Computer\.agents\external\ppt-master`，不是当前全局 skill 清单成员。

### SEO

| 目标 | 默认路由 |
|---|---|
| 泛 SEO 诊断 | `seo-audit` |
| 结构化数据落地 | `schema` |
| AI 搜索可见性和引用 | `ai-seo` |

### 研究、文章和文件处理

| 目标 | 默认路由 |
|---|---|
| 研究内容生成和研究报告 | `hv-analysis` |
| 公众号文章、长文和稿子 | `khazix-writer` |
| 已有文件读取、编辑、转换 | 对应格式 skill |
| 简单解释、摘要或技术回答 | 直接回答 |

### Office 文件与底层工具

| 目标 | 默认路由 |
|---|---|
| 把 Word、Excel、PowerPoint 文件做好 | 对应第一方 artifact skill 或本地格式 skill |
| OpenXML、校验、原始 XML、跨格式 CLI | `officecli` |

### Bug 与运行时验证

| 场景 | 默认处理 |
|---|---|
| 根因明确、影响面小 | 直接修复并做相称验证 |
| 根因不明确、反复失败或跨组件 | `systematic-debugging` |
| 必须观察浏览器运行时行为 | `webapp-testing` |

## Impeccable 子命令边界

旧设计辅助 skill 已折叠进 `impeccable/reference` 和 `$impeccable <command>`：

| 类型 | 命令 |
|---|---|
| 项目上下文 | `init`、`document`、`extract` |
| 方案与实现 | `shape`、`craft` |
| 评审与收尾 | `audit`、`critique`、`polish` |
| 适配与质量 | `adapt`、`animate`、`harden`、`optimize` |
| 清晰度与版式 | `clarify`、`distill`、`typeset`、`layout` |
| 表达和体验 | `bolder`、`quieter`、`colorize`、`delight`、`overdrive`、`onboard`、`live` |

`teach` 只作为 `init` 的兼容别名。静态艺术仍归 `canvas-design`，HTML deck 仍归 `html-ppt`。

## 已移除的入口

以下 skill 不应继续出现在活动依赖链或推荐中：

- 流程入口：`brainstorming`、`test-driven-development`、`verification-before-completion`、`using-git-worktrees`、`writing-plans`
- 通用或重复：`karpathy-guidelines`、本地 `skill-creator`
- 平台和低频：`health`、`workctl`、`workctl-operator`
- Vercel 组：`deploy-to-vercel`、`vercel-cli-with-tokens`、`vercel-composition-patterns`、`vercel-react-best-practices`
- 失效重流程：`extract-design`
- 已折叠到 Impeccable 的旧设计辅助 skill

计划和任务跟踪使用当前 agent 自带能力；测试、验证、工作区隔离和部署按任务实际需要执行，不再由已删除 skill 强制串联。

## 维护规则

- `skills-sources.json`：登记来源、活动目录和更新方式。
- `local-routing-overrides.json`：保存触发描述和需要持久重放的本地规则。
- `manage-skills.ps1 -Mode apply-overrides`：把已登记规则写入生成后的 `SKILL.md`。
- `manage-skills.ps1 -Mode check`：检查来源漂移、缺失目录和补丁是否仍能匹配。
- 上游正文默认不改；仅对已删除依赖、真实断链、无效命令/依赖或已确认兼容故障使用最小 `bodyPatches`。
- 新增 override 前必须有真实冲突、误触发或客户端兼容理由；不要追求所有 skill 形式统一。
- 备份、缓存和外部仓库放在 `C:\Users\Computer\.agents\external`，不要放进活动 skill 根目录。
