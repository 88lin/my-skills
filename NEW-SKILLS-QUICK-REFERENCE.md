# 新增 Skills 速查表

这份速查表主要覆盖最近新增、最近补强、并且和你日常工作流关系最密切的 skills，方便你以后直接查“这个 skill 是干嘛的、什么时候该叫它、怎么触发更顺手”。

## `html-ppt`

- 定位：用于生成 HTML 演示文稿，适合网页 slides、分享 deck、演讲稿、浏览器直接打开的多页演示内容。
- 来源：`lewislulu/html-ppt-skill`
- 本地目录：`C:\Users\Computer\.agents\skills\html-ppt`
- 什么时候用：你要的是网页演示稿，不是 `.pptx` 文件。
- 怎么触发：
  - `用 html-ppt 做一份网页演示稿`
  - `我不要 pptx，我要浏览器直接打开的演讲 deck，用 html-ppt`
- 补充：它适合和 `pptx`、`ppt-master` 做分工，不替代它们。

## `ppt-master`

- 定位：用于从 PDF、DOCX、URL、Markdown 等资料生成正式、可编辑的 `.pptx` 成品，是重型 PPT 生产工作流。
- 来源：`hugohe3/ppt-master`
- 本地目录：`C:\Users\Computer\.agents\external\ppt-master`
- 什么时候用：你最后必须交付 `.pptx`，而且希望在 PowerPoint 里继续编辑每页元素。
- 怎么触发：
  - `用 ppt-master 把这份 PDF 做成正式可编辑 PPTX`
  - `这次不要 HTML，我要最终能在 PowerPoint 里继续改的 PPTX，用 ppt-master`
- 补充：它是外部独立仓库，不走普通单 skill 自动更新。

## `webapp-testing`

- 定位：用于本地 Web 应用测试和页面验收，重点是跑真实浏览器流程、检查交互、查看报错、截图留证据。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\webapp-testing`
- 什么时候用：本地 Web 应用验收、按钮流程检查、浏览器报错排查。
- 怎么触发：
  - `用 webapp-testing 检查这个本地注册流程是否可用`
  - `用 webapp-testing 跑一遍登录到下单流程，帮我找前端报错`
- 补充：适合和 `verification-before-completion` 搭配，用它来执行真实页面验证。

## `pdf`

- 定位：处理 PDF 文件，覆盖提取文字、表格、图片、OCR、表单、拆分、合并、水印等常见任务。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\pdf`
- 什么时候用：PDF 提取、OCR、表单、拆分合并。
- 怎么触发：
  - `用 pdf skill 提取这份 PDF 的表格和关键信息`
  - `把这 3 个 PDF 合并成一个，并保留顺序`
- 补充：适合处理合同、扫描件、资料包、带表单的 PDF 文档。

## `xlsx`

- 定位：处理 Excel、CSV、TSV 一类表格文件，适合清洗数据、补公式、修格式、做图表、导出正式表格。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\xlsx`
- 什么时候用：Excel/CSV 清洗、公式、图表、导出。
- 怎么触发：
  - `用 xlsx skill 清洗这个 CSV，补齐表头并导出成 xlsx`
  - `把销售数据做成透视表，再加一张趋势图`
- 补充：适合数据清洗和最终交付正式表格文件。

## `skill-creator`

- 定位：用于创建新 skill、修改旧 skill、优化触发说明、做评估和 benchmark，适合把 skill 当成产品来打磨。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\skill-creator`
- 什么时候用：写新 skill、改旧 skill、评估触发准确率。
- 怎么触发：
  - `用 skill-creator 帮我优化这个 skill 的 description，让触发更准`
  - `帮我评估这个 skill 是否容易误触发`
- 补充：你现在有自己的 skill 管理体系，这个会非常实用。

## `docx`

- 定位：处理 Word 文档，适合创建、整理、修改、重排 `.docx` 文件，也适合把零散内容整理成正式文档。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\docx`
- 什么时候用：需要产出或修改 Word 文档。
- 怎么触发：
  - `用 docx skill 把这份提纲整理成正式 Word 文档`
  - `修改这个 docx 的结构和格式，但保留原文内容`
- 补充：适合报告、备忘录、说明文档、模板、正式文稿。

## `pptx`

- 定位：处理演示文稿，适合创建、修改、拆分、合并 `.pptx` 文件，也适合把内容整理成可汇报的幻灯片。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\pptx`
- 什么时候用：需要产出或修改演示文稿。
- 怎么触发：
  - `用 pptx skill 把这份周报做成 10 页汇报稿`
  - `根据这份文案生成一套演示文稿`
- 补充：适合汇报 deck、演讲稿、培训材料、项目汇报页。

## `canvas-design`

- 定位：做静态视觉设计，适合海报、封面、单页图、PNG/PDF 视觉稿，不是网页 UI skill。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\canvas-design`
- 什么时候用：需要静态视觉稿，不是网页界面。
- 怎么触发：
  - `用 canvas-design 给这篇文章做一张封面海报`
  - `做一张适合分享的单页视觉图`
- 补充：它补的是海报、封面、视觉物料，不替代 `frontend-design`。

## `web-artifacts-builder`

- 定位：用于制作复杂前端 artifact，适合多组件、带状态管理、带结构的交互式 HTML 演示，不是普通单文件页面。
- 来源：`anthropics/skills`
- 本地目录：`C:\Users\Computer\.agents\skills\web-artifacts-builder`
- 什么时候用：需要复杂前端 artifact，不是普通单文件 HTML。
- 怎么触发：
  - `用 web-artifacts-builder 做一个复杂的交互式 HTML demo`
  - `做一个带状态管理和多组件的前端 artifact`
- 补充：它比普通 HTML demo 更偏完整前端结构，适合复杂演示场景。
