# Skills 分类清单

这份清单把你当前本地纳管的 skills 按用途重新整理，方便以后快速判断“这次任务该叫谁”。

## 设计与前端

- `frontend-design`：高质量前端界面设计主 skill，适合做页面、组件、应用界面和整体视觉方向。
- `adapt`：处理响应式适配、断点、移动端布局、跨设备体验。
- `animate`：负责动画、转场、微交互，让界面更有动感。
- `audit`：做前端质量审计，覆盖无障碍、性能、主题、响应式和反模式检查。
- `clarify`：优化 UX 文案、标签、提示语、错误信息。
- `critique`：从 UX 视角做设计评审，指出层级、结构、认知负担、情绪表达问题。
- `delight`：增加趣味性、微妙惊喜和更有记忆点的细节。
- `distill`：去噪、做减法、收敛界面复杂度。
- `extract-design`：从网站提取设计语言、tokens、字体、颜色和设计系统信息。
- `harden`：补错误态、边界条件、i18n、溢出处理，让界面更稳。
- `optimize`：解决前端性能、加载速度、渲染卡顿、动画不顺等问题。
- `polish`：做最终润色，修对齐、间距、一致性和细节问题。
- `teach-impeccable`：一次性采集设计上下文，建立持久的设计基线。
- `typeset`：优化字体、字号、字重、层级和整体可读性。
- `canvas-design`：做海报、封面、单页视觉稿、PNG/PDF 视觉物料。
- `web-artifacts-builder`：做复杂前端 artifact，适合多组件、带状态管理的交互式演示。

## 工程与交付

- `systematic-debugging`：遇到 bug、测试失败、异常行为时先做系统化排查。
- `test-driven-development`：实现功能或修复 bug 前先走测试驱动思路。
- `verification-before-completion`：在说“完成了”之前强制做验证，避免口头成功。
- `writing-plans`：对小中型多步骤任务做轻量计划拆解。
- `using-git-worktrees`：需要隔离工作区时使用，适合并行任务、热修、实验分支。
- `karpathy-guidelines`：约束改动范围、减少过度设计、强调最小正确改动。
- `receiving-code-review`：收到代码审查反馈后，先做技术判断和验证，再决定怎么改。
- `chinese-code-review`：中文代码审查风格指导，更贴近国内团队沟通语境。
- `chinese-commit-conventions`：中文 Git 提交规范，适合本地团队使用习惯。
- `chinese-documentation`：中文技术文档写作规范，避免机翻感和结构混乱。

## 平台与工具

- `web-access`：所有联网、网页抓取、登录后网页操作、动态页面访问，都优先走这个 skill。
- `find-skills`：当你想找某类 skill、判断有没有现成 skill 可装时使用。
- `health`：排查 Claude Code 配置层、指令层、hook 和 MCP 运行环境问题。
- `mcp-builder`：构建生产级 MCP 服务的方法论，适合做可被 AI 调用的工具服务。
- `skill-creator`：创建、优化、评估和 benchmark 现有 skill。
- `mindos-zh`：本地知识库和跨会话记忆系统，适合记录决策、经验、SOP、上下文。

## 文档与办公文件

- `pdf`：处理 PDF，适合提取、OCR、表单、拆分、合并、水印等任务。
- `docx`：处理 Word 文档，适合创建、整理、修改正式文稿。
- `pptx`：处理演示文稿，适合创建、重组、修改汇报材料。
- `html-ppt`：处理 HTML 演示稿，适合网页 slides、浏览器演讲 deck 和多页静态展示内容。
- `ppt-master`：处理正式可编辑 PPTX 成品生成，适合从 PDF、DOCX、URL、Markdown 资料出发制作完整演示文稿。
- `xlsx`：处理 Excel、CSV、TSV，适合清洗数据、做图表、补公式、导出正式表格。

## 部署与框架专项

- `deploy-to-vercel`：处理 Vercel 部署动作，适合“帮我发上去”这种请求。
- `vercel-cli-with-tokens`：处理基于 token 的 Vercel CLI 操作，适合环境变量、部署配置等任务。
- `vercel-composition-patterns`：React 组件组合模式，适合重构组件 API 和避免布尔 prop 膨胀。
- `vercel-react-best-practices`：React/Next.js 性能和最佳实践，适合页面、组件、数据获取优化。

## SEO 与增长

- `seo-audit`：做 SEO 审计，适合排查不收录、不排名、流量下跌、技术 SEO 问题。
- `schema-markup`：做结构化数据和富摘要优化。
- `ai-seo`：做面向 AI 搜索和 LLM 引用的内容优化。

## 研究与内容

- `brainstorming`：做创造性任务前先探索需求、意图和方向。
- `hv-analysis`：做深度研究，结合纵向历史梳理和横向竞品对比。
- `khazix-writer`：写公众号长文、扩写素材、整理内容为完整文章。
- `luo-xiang-perspective`：用罗翔式的法律与人生视角看问题。
- `create-crush`：把暗恋对象沉淀成可持续演化的关系型 skill。

## 一句话导航

- 做网页和设计：先看“设计与前端”
- 做实现、修 bug、交付验证：先看“工程与交付”
- 做联网、抓网页、找 skill、管知识库：先看“平台与工具”
- 处理 PDF、Word、PPT、Excel：先看“文档与办公文件”
- 做网页演示稿优先想 `html-ppt`，做正式可编辑 PPTX 优先想 `ppt-master`
- 做部署和 React/Next 专项：先看“部署与框架专项”
- 做 SEO 和 AI 可见性：先看“SEO 与增长”
- 做调研、写稿、观点型内容：先看“研究与内容”
