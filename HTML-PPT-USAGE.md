# html-ppt 使用说明

## 这是什么

`html-ppt` 是一个专门做 **演示型静态 HTML 页面和 HTML 演示文稿** 的 skill。

它适合生成：

- 网页版 PPT
- PPT 风格的单页展示页
- 分享稿
- 演讲 slides
- pitch deck
- 技术分享页
- 多页图文演示

它的强项不是输出 `.pptx`，而是输出 **静态 HTML 演示稿**。

## 它和你现有 skill 的区别

- `pptx`：偏 PowerPoint 文件本身，适合直接创建、修改、整理 `.pptx`
- `html-ppt`：偏网页演示系统，适合做 HTML slides，也适合做演示型、展示型、PPT 风格的静态单页
- `web-artifacts-builder`：偏复杂前端 artifact，更像交互 demo 或小应用
- `canvas-design`：偏静态视觉稿，不是多页演示文稿

一句话理解：

- 要 `.pptx` 文件：先想 `pptx` 或 `ppt-master`
- 要演示型静态 HTML 页面或网页演示稿：先想 `html-ppt`

## 什么时候用

下面这些场景优先考虑 `html-ppt`：

- 你要做一份可以浏览器直接打开的演示稿
- 你要的是网页 slides，不是 PowerPoint 文件
- 你想做主题感很强的分享 deck
- 你想做一份适合现场演讲或远程展示的 HTML PPT
- 你要 presenter mode、讲稿、计时器、键盘翻页这类网页演示体验
- 你要做一个 PPT 风格、editorial 风格、展示型的静态单页页面

## 不适合什么时候用

- 你最后必须交付 `.pptx` 文件
- 对方只认 PowerPoint，可继续编辑每个元素
- 你只是想改一个现有 `.pptx`
- 你要的是静态海报、封面或单页视觉稿

这些情况下，不要优先用它：

- 改现有 PPT：用 `pptx`
- 生成正式可编辑 PPTX 成品：用 `ppt-master`
- 做海报封面：用 `canvas-design`
- 做正常产品官网、正常 landing page、正常应用页面：优先看 `frontend-design`

## 推荐触发方式

可以直接这样说：

```text
用 html-ppt 做一份网页演示稿
```

```text
做一个 PPT 风格的单页网站，浏览器里直接展示，用 html-ppt
```

```text
做一份适合技术分享的 HTML slides，走 html-ppt
```

```text
我不要 pptx，我要浏览器直接打开的演讲 deck，用 html-ppt
```

```text
帮我把这份分享提纲做成一套网页 PPT，用 html-ppt
```

## 更适合你的描述方式

为了少触发错 skill，建议你在提需求时说清楚这些点：

1. 最终产物是不是静态 HTML
2. 是分享、汇报、路演，还是课程讲稿
3. 要不要演讲者模式感
4. 想要什么风格
5. 是偏正式、偏科技、偏媒体，还是偏杂志感 / 演示稿感

例如：

```text
用 html-ppt 做一份网页版分享稿。
主题是 AI Coding 工作流变化。
要求：深色、克制、适合现场演讲，信息密度中等。
```

## 它的优势

- 主题和模板很多
- 适合做完整 deck，不只是单页
- 适合展示而不是编辑 PowerPoint
- 更容易做出演讲稿感和舞台感
- 比普通临时拼的 HTML 页面更像完整演示系统

## 它的局限

- 不是 `.pptx`
- 不是给 PowerPoint 用户继续改元素用的
- 更像“展示成品”，不是 Office 文档交换格式
- 不适合普通产品网页或常规应用界面实现

## 在你这套系统里的定位

- 管理方式：已纳入本地 skills 系统
- 更新方式：可用 `manage-skills.ps1` 统一更新
- 推荐优先级：高

## 更新命令

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only html-ppt
```

## 检查命令

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only html-ppt
```
