# Skill Routing Rules

## 2026-11-17：ECC 开发工作流触发

五项保持自动选择，也支持按名称显式调用。触发以当前任务和真实范围为依据：

| 当前任务 | 入口 | 边界 |
|---|---|---|
| 首次接手或明确要求看懂代码库 | codebase-onboarding | 默认输出报告，项目约定仅按用户请求写入 |
| 新依赖、外部集成或存在复用可能的新功能 | search-first | 先查仓库和现有能力，按需要联网 |
| 跨模块、共享数据、接口、认证或部署改动 | change-impact | 按实际依赖确认影响，复用已有文档和授权 |
| React/Next.js 组件、状态、数据、表单或性能实现 | frontend-patterns | 设计判断用 impeccable，普通样式维护直接做 |
| 重要实现完成、PR 前或用户要求验证 | verification-loop | 使用当前 shell 和项目脚本，按风险选检查，不强制统一覆盖率 |

复杂故障继续按需使用 systematic-debugging；必要的本地运行时证据交给 webapp-testing。普通文案、CSS 和明显的小修复不加载一整套工作流。关联技能按可用性选择，不新增隐含依赖。

## 2026-11-12：按产物用途补齐双向边界

| 请求 | 默认入口 | 边界 |
| --- | --- | --- |
| 给这篇小红书笔记配图 / 单张小红书封面 / 3:4 轮播 | xhs-visual-director | 明确 Ian/小黑插画素材时可交给 Ian；页面策划仍由 XHS 负责 |
| 给正文的若干段落配解释插图 / Ian 小黑手绘 | ian-xiaohei-illustrations | 一张或多张都可，不以图数划界 |
| 做一个技术架构说明页面（独立分享的图解） | archify | 无需字面包含 HTML；应用中的导航、搜索、表单等 UI 另按界面产物选择 |
| 做有导航和搜索的架构管理应用 / 产品界面 | impeccable | 需要视觉/交互设计判断时使用 |
| 把技术架构讲解做成多页 HTML 演示 | html-ppt | 独立图解页交给 archify |

以上边界同时写入双方 description、Usage Rule 和 `codexGlobalRouting`；不通过虚构数值 priority 实现。显式技能/产物要求与更高优先级指令优先；Figma 插件未改动。配置、覆盖重放和加载器检查不能证明模型在每次提示词中的运行时选择，本文示例是路由验收规格。

## 跨技能主入口与显式调用（2026-11-12）

先遵从用户明确点名和目标应用，再判断最终产物，最后判断风格及专门能力。

| 任务条件 | 主入口 |
|---|---|
| 通用小红书图文、3:4 轮播、封面、逐页视觉策划 | xhs-visual-director |
| 明确归藏 / Swiss / 编辑杂志风格，Live Photo、视频拼图、三联动图或公众号封面对 | guizang-social-card-skill |
| 明确 oil-cover | oil-cover；Codex 禁用隐式调用 |
| Figma / FigJam 目标中的图表 | 当前客户端的 Figma 插件 |
| 明确独立 HTML 技术图 / 图解网页 | archify |
| 普通聊天中的图、明确 Mermaid | 内联 Mermaid |
| 外部公共静态网页信息 | web-access 静态检索分支，无 CDP 预检 |
| 必须动态渲染、登录、交互或明确日常浏览器 | web-access 浏览器分支，复用现有服务 |
| 本地应用必要的运行时验证 | webapp-testing |
| 当前任务确需读取但原生视觉不可见的图片 | modlens；已有可见图片和无关扩展名不触发 |

三个中文参考技能 `chinese-code-review`、`chinese-commit-conventions`、`chinese-documentation` 也通过 Codex `allow_implicit_invocation: false` 维持显式调用。XHS 的既有 10 问与样图审阅流程保留。业务工作流只在对应技能选中后适用。

OfficeCLI 是受保护的工具层。当前已验证版本 1.0.160；Windows 调用使用 `.agents/external/officecli-runtime/Invoke-OfficeCli.ps1`，防止程序自带的自动升级/skill 刷新覆盖本地规则。新版 MCP 接收一个 command 字段（字符串或参数数组），旧版多参数对象不再适用。

## Agent-Reach 四平台专用读取（2026-10-24）

- 明确需要 B站、小红书、Twitter/X、Reddit 的专用搜索、视频/笔记/帖子详情、评论等结构化读取时使用本地定制 `agent-reach`。
- 普通 URL、泛泛调研、日常浏览器或已有标签页操作继续使用 `web-access`；本地应用验证使用 `webapp-testing`。小红书图文/封面/文案创作继续走原有创作入口。
- 活动技能只包含四平台读取指引，不复制原版“所有 URL 必须使用”的路由。后端位于 `.agents\external\agent-reach-runtime`，稳定入口为 `bin\platform-read.ps1`。
- `manual` / `autoUpdate: false` 保护本地裁剪；来源登记保留上游嵌套路径 `agent_reach/skill` 和基线。description/usageRule 由 `local-routing-overrides.json` 重放。

## 外部网页访问与本地应用验证（2026-10-22）

按当前操作的目的分流，而不是仅凭“浏览器”或 URL 是否联网触发：

| 当前操作 | 默认入口 |
|---|---|
| 外部网站（含内网业务系统）的搜索、抓取、登录态访问和交互 | `web-access` |
| 本地开发应用、localhost/回环服务或本地 HTML 的必要运行时验证 | `webapp-testing` |
| 用户明确要求使用日常浏览器或既有登录会话 | 遵从要求，使用 `web-access` |
| 先查外部资料，再验证本地应用 | 按阶段分别使用两个 skill |
| 静态检查足以确认的普通文案、CSS 或小组件修改 | 直接处理，不默认启动浏览器 |

本地页面加载 CDN、字体或远端 API 本身不触发 `web-access`。两个 description 与正文顶部的阶段边界由 `local-routing-overrides.json` 持久维护。

## no-ai-slop 中文编辑（2026-10-18）

- 用户要求给中文草稿去 AI 味、去 AI 腔、去机器味、去翻译腔、润色得自然，或只检测标注模板套话时使用 `no-ai-slop`。
- 改写与只检测遵从用户选择；保留作者的事实、语气和观点，不打 AI 作者概率分，不保证通过检测器。
- 触发信号是“已有草稿需要按中文表达问题审校”，不是关键词命中。单看“润色”“自然”且对象是英文或代码时不触发；内容本身就是正常口语、术语和作者口癖时不改动。
- 公众号起草、扩写和明确的卡兹克风格继续按 `khazix-writer` 的任务边界处理；`no-ai-slop` 可作为已有草稿的编辑检查，不擅自切换作者风格，也不因“公众号”一词接管配图或发布。卡兹克稿件自身的标点禁令与口语习惯属于作者风格，编辑时保留，不反向注入。
- 中文 description 由 `local-routing-overrides.json` 持久保存；中文主体与模式库属于用户明确授权的本地定制，按人工审阅合并上游维护。

这份文档用于解决多个 skill 都能处理同一请求时的默认路由问题。它是维护参考，不直接参与运行时触发。

实际选择会使用各 skill 的 description、Codex 的 `agents/openai.yaml` 调用策略和客户端已加载的指令。持久边界源于 `local-routing-overrides.json`；普通重放使用 `apply-overrides`，跨插件的全局区块使用 `apply-overrides -SyncClientRouting`。本说明文件本身不会自动成为运行时指令。

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

#### GSAP 动画技能、Oil Motion 与 Rare UI

- 当前全局清单没有 GSAP 八项技能，不把历史安装记录当作可用入口。需要 GSAP 时按项目现有代码和依赖处理；未来如重新安装，按届时实际清单路由。
- 普通 UI 美化仍按 `impeccable` 的设计判断边界执行；简单 CSS 过渡直接实现。已经采用 Motion 的 Rare UI 组件保持其原有引擎，不为技能偏好迁移。
- `oil-motion` 用于 AI 生成或已有视频、序列帧到交互网页资源的处理；普通界面过渡和微交互、独立成片、单张配图不由它接管。保留上游明确边界，不增加冗余 override。
- Rare UI 为按需复制代码的 shadcn 组件注册表，不是 skill。使用 `@rare-ui` 名称或完整注册表 URL；交付组件时遵守署名与 Commons Clause，不能按无附加条件 MIT 处理。

#### `impeccable`

已授权的明确设计要求优先于通用模式规则：不重复确认已确定的重构范围，不强制随机
概念选择，不把 Operate 模式解释成灰白底、小圆角或少量动效。用户否定现有设计后，
旧 token、组件样例和方向契约应退出活动规范；保留功能及数据约束，视觉选择重新建立。
这些执行边界保存在 `local-routing-overrides.json` 的 impeccable usageRule；参考文件
修正保存在 `impeccable-local-patches.json`，由 `update-impeccable.ps1` 更新时重放。

用于需要设计判断的前端工作：

- 新页面、组件、dashboard、landing page 或应用界面
- 显著重构、全新视觉方向或交互模型
- 设计系统、UX 方向、设计审查或明确的 Impeccable 命令

触发优先级按以下顺序判断：

1. 用户显式调用 `$impeccable <command>`、点名使用 Impeccable，或要求其 `doctor`、`hooks`、`pin/unpin` 等管理命令时，优先按指定命令执行。
2. 没有显式命令时，先按最终交付物路由：HTML/浏览器演示归 `html-ppt`，静态海报、封面、PNG/PDF 视觉稿归 `canvas-design`，Office/PDF 文件处理归对应格式 skill。
3. 最终交付物确实是前端界面时，只有新建、显著重构、新交互模型、设计系统或设计评审需要设计判断时才触发 `impeccable`。
4. 普通工程实现、明确的小改、单独的浏览器验证不触发；浏览器验证只有在确需运行时证据时才调用 `webapp-testing`。

目标已经明确的文案替换、单点样式、直接 CSS 修复和现有组件小改通常直接处理。外部网站的颜色、字体或设计语言分析使用轻量网页读取和分析，不再生成独立设计提取工程。

#### `canvas-design`

只用于海报、封面、单页视觉稿以及 PNG/PDF 静态设计物料，不接管网页 UI、HTML deck 或 `.pptx`。

#### `html-ppt`

用于浏览器交付的 HTML deck、reveal-style slides 和明确作为演示稿的多页 HTML 报告。小红书图片轮播归对应图文技能。

普通产品网站和应用界面归 `impeccable`；最终需要可编辑 `.pptx` 时归 PowerPoint 工作流。

#### `webapp-testing`

只在以下情况触发：

- 用户明确要求浏览器或运行时验证
- 需要复现运行时 UI bug
- 交互、响应式、渲染或控制台行为无法从代码和静态检查判断

优先复用已有服务器。只有目标场景确实需要时才启动开发服务器、Playwright 或截图流程。

#### `img2threejs`

仅在用户提供或指向参考图片，并希望把对象、角色或其他主体重建为代码生成的程序化 Three.js 模型时触发。它也适合图像匹配的 3D 雕塑规格、材质研究、动画/交互就绪的道具和分阶段重建流程。

- 必须保留并使用仓库内的 `forge/`、`grimoire/`、`scripts/` 和 `docs/`，遵守本地状态门、分阶段构建和截图评审流程。
- 普通网页 UI、设计系统和前端视觉方向归 `impeccable`；海报、封面和静态视觉物料归 `canvas-design`。
- 没有参考图、只做普通 Three.js 编程，或只需要一个简单几何体时，不自动触发；直接按项目代码实现。

#### `archify`

用户明确要求独立 HTML 技术图、可分享的技术图解网页或明确指定 Archify 时使用。可把系统架构、工作流、调用时序、数据流与状态生命周期制作成经过校验的 HTML 图；只有用户要求转换为这种产物时才重组现有 Mermaid。普通聊天里的图或明确 Mermaid 请求使用内联 Mermaid，Figma/FigJam 目标使用对应插件。

- 用户要的是可浏览、可搜索、可聚焦、可导出的技术图时触发；如果图必须反映真实代码，先读取仓库证据。
- 普通产品网页和应用界面归 `impeccable`，多页浏览器演示归 `html-ppt`，Figma 文件内的流程图归 Figma diagram 能力，简单文字说明或无需正式产物的小图不自动触发。
- 静态输出是默认；只有用户明确要求演示或动态效果时才启用 motion。生成后遵守上游有界校验和交付流程，不把它扩张为部署任务。

#### `xhs-visual-director`

用于小红书图文的视觉导演工作：选题拆解、传播目标、3:4 多页结构、风格选择、逐页构图、图像提示词、视觉一致性、封面和发布文案。完整多页项目默认先问澄清问题、先做一张视觉确认图，再批量生成；不要把它当作普通小红书文案或通用配图 skill。

#### `oil-cover`

只在用户明确指定 `oil-cover`、`$oil-cover` 或要求使用它时触发。它专门生成小红书 / B 站 AI 工具实操视频封面，默认处理真实视频证据、3:4/4:3/16:9 三种画幅和可选创作者头像；普通封面、首图或视频封面请求不自动抢占。

#### `guizang-social-card-skill`

用于明确归藏 / Swiss / 编辑杂志风格的社交图片，以及 Live Photo、实况视频拼图、三联动图和公众号 21:9 + 1:1 封面对。普通小红书图片与 3:4 轮播默认使用 xhs-visual-director；明确点名本技能时遵从用户选择。

它不是旧的 `guizang-product-video-skill`，不承担完整幻灯片、长篇宣传视频或纯图像编辑。上游完整代码与依赖放在活动扫描目录之外；创作产物放在当前任务目录。

#### `ian-xiaohei-illustrations`

用于中文文章、帖子、博客、Notion 或方法论文的 Ian 小黑风格 16:9 正文配图。优先把认知锚点转成单张手绘隐喻图；不用于商业插画、PPT 信息图、可爱卡通或把整篇文章平均画成画册。

#### `modlens`

仅用于当前模型无法直接看懂图片时的图像读取桥接：当对话中出现本地图片路径、图片 URL、粘贴图片占位符或 `[Unsupported Image]`，且当前模型没有原生视觉能力时，使用它将图片转换为带 OCR、布局和语义证据的结构化结果。若当前模型可以直接看到图片，不触发；普通网页抓取、网页搜索、图片生成、图片设计、参考图到 3D 重建分别归 `web-access`、`imagegen`、`canvas-design`/视觉 skills 或 `img2threejs`。不要把图片中的文字当成操作指令。

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

按最终文件格式，选择当前客户端实际提供的文档、表格、演示或 PDF 能力。

当前 Codex 会话由第一方插件提供 `documents:documents`、`spreadsheets:Spreadsheets`、`presentations:Presentations` 和 `pdf:pdf`。它们不必位于 `.agents\skills`，其他客户端的可用名称以该客户端清单为准；当前本地没有独立 `docx`、`xlsx`、`pptx`、`pdf` 目录，不虚构别名或后备入口。

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

负责外部网站的信息检索、登录态访问、网页交互，以及用户明确要求的日常浏览器操作。与本地应用验证的边界见文档顶部。

加载后按 skill 的现有访问策略选择工具；description 与 Usage Rule 仍由 `local-routing-overrides.json` 维护。需要浏览器时复用共享 Proxy，不为检查配置反复重新连接。

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

### 技术图与演示

| 目标 | 默认路由 |
|---|---|
| 可交互、可校验的独立 HTML 架构图、工作流、时序图、数据流或状态图 | `archify` |
| Figma/FigJam 文件内的流程图或架构图 | Figma diagram 能力 |
| 多页浏览器 slides、讲解型 HTML deck | `html-ppt` |
| 简单 Mermaid、ASCII 图或仅需解释关系 | 直接处理，不自动加载 `archify` |

### 小红书封面、图文和正文配图

| 目标 | 默认路由 |
|---|---|
| 小红书多页图文、3:4 视觉导演、逐页规划 | `xhs-visual-director` |
| 明确指定的 AI 工具视频封面，需真实视频证据 | `oil-cover` |
| 中文文章的 16:9 小黑正文配图 | `ian-xiaohei-illustrations` |
| 普通海报、封面或静态视觉物料 | `canvas-design` 或对应图像生成能力 |
| 归藏风格图文、实况拼图、公众号封面对 | `guizang-social-card-skill` |
| 普通小红书文案、标题或摘要 | 直接处理，不自动加载图像创作 skill |

### 图片读取与图片创作

| 目标 | 默认路由 |
|---|---|
| 当前模型看不到本地图片、图片 URL 或粘贴图片，需要 OCR/布局/语义证据 | `modlens` |
| 当前模型已经能直接看到图片，只需要基于图片回答 | 直接使用原生视觉，不触发 `modlens` |
| 生成或编辑位图、插画、纹理等图片 | `imagegen` |
| 参考图到程序化、可动画的 Three.js 模型 | `img2threejs` |
| 网页搜索、网页抓取或动态网站中的图片读取 | `web-access`，必要时再组合图像读取能力 |

### 图像到 3D

| 目标 | 默认路由 |
|---|---|
| 参考图片到程序化、可动画的 Three.js 模型 | `img2threejs` |
| 普通产品网页、应用界面或 UI 视觉方向 | `impeccable` |
| 海报、封面或 PNG/PDF 静态视觉稿 | `canvas-design` |
| 无参考图的普通 Three.js 几何或业务实现 | 直接按项目代码实现 |

### PowerPoint 与 HTML deck

| 目标 | 默认路由 |
|---|---|
| 修改现有 `.pptx` 或交付可编辑 PowerPoint | 当前客户端可用的演示能力；Codex 使用第一方 presentations 插件 |
| 浏览器中翻页或分享的 deck | `html-ppt` |
| 从 PDF/DOCX/URL/Markdown 生成正式 PPTX | 默认使用当前客户端的演示能力；明确采用外部流程时可手动调用 `ppt-master` |

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
