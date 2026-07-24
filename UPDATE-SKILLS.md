# Skills 更新说明

这个文件用来说明：如何只更新你本地已经安装的 skill，而不是把整个仓库里的所有 skill 都装下来。

## 一键命令

日常维护优先用这个目录里的管理脚本。

### 一键检查所有安全 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check
```

### 一键更新所有安全 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update
```

### 只检查或更新指定 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only ai-seo,seo-audit
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only web-access,html-ppt
```

### 说明

- 管理脚本使用同目录下的 `skills-sources.json` 作为来源配置。
- `skills-cli` / `git` 且 `autoUpdate=true` 的条目会自动检查，更新时按各自来源方式更新。
- `manual` 条目不会自动拉上游；如果它同时用了 `local-routing-overrides.json`，`check` 会检查 override 是否已经同步到本地文件。
- 如果你刚改了 `local-routing-overrides.json`，记得额外运行一次 `manage-skills.ps1 -Mode apply-overrides`。
- 设计系那批本地定制 skill 默认不自动覆盖上游。
- `web-access` 用 Git 更新，其余已确认来源的 skill 用单 skill 的 `npx -y skills add owner/repo@skill -g -y` 更新。

## 当前收手点与维护边界

当前这套管理系统已经处于稳定可用状态，后续维护优先用真实问题驱动，不要为了形式统一继续扩张规则。

先不要继续动这些地方：

- `manage-skills.ps1`：只在出现真实检查、更新、override 回写错误时修改，不为了“更优雅”重构
- `local-routing-overrides.json`：只给真冲突、真误触发、真需要保住本地规则的 skill 新增 override
- `skills-sources.json`：不要轻易改变现有 `manual` / `skills-cli` / `git` 分类

这些点当前可以继续观察，不作为必须修复项：

- `ppt-master`：作为外部相关能力出现在路由文档里，边界复杂但已经说明清楚
- `web-access`：真实目录是独立 Git 仓库，GitHub 备份里缺少 `.git` 不代表它不能正常更新
- `officecli`：保留为手动管理的低层 Office CLI，不让它覆盖普通格式 skill

以后只有出现真实误触发、真实漏触发、高冲突新 skill、或上游结构大改时，再重新修改规则。记录问题时至少写清：用户原话、期望触发的 skill、实际触发的 skill、造成的影响。

## 备份仓库注意

这个 GitHub 仓库主要是备份和说明用途，不等于每个 skill 在真实运行环境里的原生安装目录。

- 本文里的命令路径默认以真实运行目录 `C:\Users\Computer\.agents\skills` 为准
- `web-access` 的真实运行目录是 `C:\Users\Computer\.agents\skills\web-access`
- 真实目录里保留独立 `.git`，可以按 Git 方式和上游同步
- 上传到 GitHub 的备份目录可能不保留嵌套 `.git` 元数据，不要用备份目录判断 `web-access` 是否能更新
- 真正执行 `git pull`、检查远端 HEAD、或处理脏工作区时，应以真实本地 skills 目录为准

## Claude Code 主 skill 清单

Claude Code 启动时扫描 `~/.claude/skills/` 下所有子目录，把每个 `SKILL.md` 注册成可用 skill。这个目录里挂的是软链接，指向 `~/.agents/skills/` 的对应目录。也就是说：

- `~/.agents/skills/` 是统一 skill 仓库（实际数量以 `skills-sources.json` 为准，给 OpenCode / Codex / Claude Code 共用）
- `~/.claude/skills/` 只是 Claude Code 的"白名单视图"——挂多少软链，Claude Code 就看得到多少 skill
- `manage-skills.ps1` 的 `check` 和 `apply-overrides` 模式完全不动 `~/.claude/skills/`；但 `update` 模式会调用 `npx -y skills add` 子进程，**skills CLI 会作为副作用在 `~/.claude/skills/` 创建软链**。同理 `install-and-register-skill.ps1` 在 `-SourceType skills-cli` 时也调用 skills CLI，也会创建软链
- 所以"白名单视图"不是脚本自动维护的：跑完 update / install 之后必须用 `ls ~/.claude/skills/` 复查，手工 `rm` 不想暴露给 Claude Code 的软链（具体警示见下面"npx skills add 的副作用警示"段）

**当前挂在 Claude Code 的入口**（以磁盘现场为准）：

| 软链 | 用途 |
|---|---|
| `ai-seo` | AI 搜索、AI Overviews、LLM 引用优化 |
| `chinese-code-review` | 显式调用的中文 review 沟通参考 |
| `chinese-commit-conventions` | 显式调用的中文 commit 规范参考 |
| `chinese-documentation` | 显式调用的中文文档排版参考 |
| `docx` | Word 文档读写、编辑、tracked changes、TOC |
| `extract-design` | 从网站 URL 提取设计语言，生成 design tokens / Tailwind / shadcn |
| `impeccable` | 需要设计判断的前端专项入口，含 craft / shape / audit / critique / polish / adapt 等子命令 |
| `html-ppt` | 浏览器 HTML 演示稿、reveal deck、小红书图文 |
| `mcp-builder` | MCP 服务器构建方法论 |
| `officecli` | 显式 officecli、OpenXML、校验修复和跨格式 CLI |
| `pdf` | PDF 读取、OCR、表单、合并/拆分、生成 |
| `pptx` | PowerPoint 文件读写、编辑、模板 |
| `receiving-code-review` | 收到 code review 后的技术核验流程 |
| `seo-audit` | 默认 SEO 诊断、技术 SEO / 页面 SEO 审计 |
| `systematic-debugging` | 调试流程入口（先找根因再修） |
| `web-access` | 联网 / 网页抓取 / 真实浏览器交互 |
| `webapp-testing` | Playwright 本地 Web app 验证（给 Claude 一双眼睛） |
| `writing-plans` | 明确多步骤需求的实施计划 |
| `xlsx` | Excel / CSV 表格读写、公式、图表 |

未挂 Claude Code 的技能仍保留在 `~/.agents/skills/`，由 OpenCode / Codex 使用。不要用旧的固定“挂载 / 未挂载”名单推断现场；更新或安装后应直接检查 `~/.claude/skills/`。旧设计辅助链独立目录已折叠进 `impeccable/reference/*.md` 和 `$impeccable <command>` 子命令。

### 增删 Claude Code skill 的标准命令

**加挂**（让 Claude Code 看到一个已经存在于 `~/.agents/skills/` 的 skill）：

```bash
# git bash
ln -s /c/Users/Computer/.agents/skills/<skill-name> /c/Users/Computer/.claude/skills/<skill-name>
```

```powershell
# PowerShell（如果 git bash 软链有兼容问题）
cmd /c mklink /D "C:\Users\Computer\.claude\skills\<skill-name>" "C:\Users\Computer\.agents\skills\<skill-name>"
```

**撤掉**（不让 Claude Code 看到，`~/.agents/skills/` 本体保留给 OpenCode/Codex）：

```bash
rm /c/Users/Computer/.claude/skills/<skill-name>
```

### npx skills add 的副作用警示

直接跑 `npx -y skills add owner/repo@skill -g -y` 或 `manage-skills.ps1 -Mode update -Only <skill>` 时，skills CLI **会自动**在 `~/.claude/skills/` 创建一条软链——也就是说**任何 update 都可能顺手把新 skill 注册到 Claude Code**。

发生过的例子：2026-05-12 跑 `update -Only writing-plans`，writing-plans 被自动注册到 Claude Code（虽然你只想 update，并不想让它在 Claude Code 触发）。

**应对**：跑完 update 之后检查 `ls ~/.claude/skills/` 是否多出意外的软链；多出来的用 `rm /c/Users/Computer/.claude/skills/<skill>` 撤掉。把白名单维护好。

## 新 Skill 安装与纳管

以后如果你让 AI 帮你安装一个新 skill，推荐不要只停在“装上”，而是顺手把它纳入当前这套管理系统。

### 自动纳管脚本

文件位置：

```text
C:\Users\Computer\.agents\skills\install-and-register-skill.ps1
```

桌面快捷入口：

```text
C:\Users\Computer\Desktop\纳管新 Skill.bat
```

双击后会依次让你输入：

1. GitHub 仓库，例如 `coreyhaines31/marketingskills`
2. skill 名，例如 `seo-audit`
3. 是否只做预览

仓库正确示例：

```text
coreyhaines31/marketingskills
https://github.com/coreyhaines31/marketingskills
https://github.com/coreyhaines31/marketingskills.git
```

仓库错误示例：

```text
seo-audit
https://raw.githubusercontent.com/coreyhaines31/marketingskills/main/skills/seo-audit/SKILL.md
https://skills.sh/coreyhaines31/marketingskills/seo-audit
```

skill 名正确示例：

```text
seo-audit
create-crush
luo-xiang-perspective
```

适合你平时直接双击操作，不想自己手打一长串 PowerShell 命令的情况。

说明：桌面这个 `.bat` 现在只负责启动 PowerShell 交互，真正的中文输入和逻辑在 `register-skill-interactive.ps1` 里处理，这样能避开 `cmd` 对中文批处理的乱码问题。

### 适合自动纳管的情况

- 来源仓库明确
- skill 名明确
- 能定位上游 `SKILL.md`
- 本地 `SKILL.md` 和上游一致

### 自动纳管示例

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" -SourceType skills-cli -Repo coreyhaines31/marketingskills -Skill seo-audit -RawSkillUrl "https://raw.githubusercontent.com/coreyhaines31/marketingskills/main/skills/seo-audit/SKILL.md"
```

这个脚本会做这些事：

1. 安装指定 skill（除非你加了 `-SkipInstall`）
2. 自动识别本地目录
3. 核对本地 `SKILL.md` 和上游 `SKILL.md`
4. 把它写入 `skills-sources.json`
5. 以后它就会进入一键检查 / 一键更新体系

### 手动纳管示例

如果你判断某个 skill 只是想记录来源，但不适合自动更新，可以这样登记为手动管理：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" -SourceType manual -Skill impeccable -LocalFolder impeccable -SkipInstall -Reason "本地定制版本，不自动覆盖更新"
```

### 预览模式

如果你只想先看看会写入什么配置，不想真正落盘，可以加 `-Preview`：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" -SourceType skills-cli -Repo coreyhaines31/marketingskills -Skill seo-audit -Preview
```

## 基本规则

- 一次只更新一个 skill，或者用安全白名单批量更新。
- 不要直接使用 `npx skills update`。
- 不要在没有确认的情况下安装整个多 skill 仓库。
- Git 管理的 skill 用 `git pull --ff-only`。
- Skills CLI 管理的 skill 用 `npx -y skills add owner/repo@skill -g -y`。
- 即使某个上游 skill 正文里提到 `npx skills update`，在你这套本地环境里也不要照做。

## Git 管理的 Skill

这类 skill 本身就是一个独立 Git 仓库。

### web-access

```powershell
git -C "C:\Users\Computer\.agents\skills\web-access" pull --ff-only origin main
```

补充：

- 真实的 `web-access` 目录在 `C:\Users\Computer\.agents\skills\web-access`，并保留独立 `.git`
- GitHub 备份里的 `web-access/` 可能没有 `.git`，不要以备份目录的状态判断更新能力
- 真正执行 `git pull` 时，应在你实际的 skills 目录里操作上面这条路径

## Skills CLI 管理的 Skill

下面这些命令只会更新指定 skill，不会把同仓库的其他 skill 一起装到你的本地目录里。

### 其他已确认来源的 Skill

这些 skill 的来源已经确认，而且状态也已经核对过。

```powershell
npx -y skills add xiaoheizi8/crush-skills@create-crush -g -y
npx -y skills add YixiaJack/luo-xiang-skill@luo-xiang-perspective -g -y
npx -y skills add KKKKhazix/khazix-skills@hv-analysis -g -y
npx -y skills add KKKKhazix/khazix-skills@khazix-writer -g -y
```

### Superpowers-ZH 精选 Skill

这些 skill 来自 `jnMetaCode/superpowers-zh`，只安装了当前选定的单个 skill，没有安装整仓库其他 skill。

```powershell
npx -y skills add jnMetaCode/superpowers-zh@systematic-debugging -g -y
npx -y skills add jnMetaCode/superpowers-zh@chinese-documentation -g -y
npx -y skills add jnMetaCode/superpowers-zh@chinese-commit-conventions -g -y
npx -y skills add jnMetaCode/superpowers-zh@mcp-builder -g -y
npx -y skills add jnMetaCode/superpowers-zh@receiving-code-review -g -y
npx -y skills add jnMetaCode/superpowers-zh@chinese-code-review -g -y
npx -y skills add jnMetaCode/superpowers-zh@writing-plans -g -y
```

当前状态：

- `systematic-debugging`：来源已确认，已纳入管理系统，自动更新
- `chinese-documentation`：来源已确认，已纳入管理系统，自动更新
- `chinese-commit-conventions`：来源已确认，已纳入管理系统，自动更新
- `mcp-builder`：来源已确认，已纳入管理系统，自动更新
- `receiving-code-review`：来源已确认，已纳入管理系统，自动更新
- `chinese-code-review`：来源已确认，已纳入管理系统，自动更新
- `writing-plans`：来源已确认，已纳入管理系统，自动更新；本地 override 会保留 OpenCode 交接方式，避免依赖未安装的 superpowers execution skills

定位说明：

- `writing-plans` 只作为实施计划补充。已有明确规格或多步骤需求时可以用它拆步骤；小修直接用 todo / 直接执行 / 验证命令，不默认写计划文档。

当前状态：

- `create-crush`：来源已确认，当前已是最新
- `luo-xiang-perspective`：来源已确认，当前已是最新
- `hv-analysis`：来源已确认，已纳入管理系统；本地 override 会保留“研究内容生成和研究报告产出才触发；已有 PDF / 文档处理走格式 skill”的边界
- `khazix-writer`：来源已确认，已纳入管理系统；本地 override 会保留“最终产物是公众号文章 / 长文 / 稿子才触发”的边界
### 适合公众号写作的 Khazix Skills

这两个 skill 很适合你现在的使用场景。

#### `khazix-writer`

用途：公众号长文写作、扩写、续写、把素材整理成完整文章。

使用边界：最终产物必须是公众号文章、长文、稿子、续写或扩写。不要仅因为输入是 PDF、brief、新闻链接或语音转文字就触发；如果最终要研究报告、Word/PDF/PPT、SEO 审计、表格或简单摘要，优先用对应 skill 或普通分析流程。

适合你这样用：

```text
帮我用 khazix-writer 写一篇公众号文章。
主题是：Claude Code 为什么会改变个人开发者的工作流。
下面是我的素材：
1. 我自己的使用经历
2. 几个亮点
3. 几个槽点
4. 和 Cursor / Codex 的对比
要求：写成长文，要有人话感和个人判断，不要写成参数说明书。
```

你也可以这样触发：

- `帮我把这份素材写成公众号文章`
- `按 khazix-writer 的风格扩写一下`
- `帮我续写这篇公众号长文`

#### `hv-analysis`

用途：深度研究一个产品、公司、概念、技术或人物，做纵向历史梳理 + 横向竞品对比。

使用边界：用于研究内容生成和研究报告产出。不要用于简单名词解释、普通代码分析、bug 排查、公众号文章写作、SEO 审计、已有 PDF / 文档处理、文档/PPT 转换或轻量问答；这些文件处理和格式转换任务走对应格式 skill。

适合你这样用：

```text
帮我用 hv-analysis 深度研究一下 Claude Code。
我想写一篇公众号文章，重点想看：
1. 它是怎么发展起来的
2. 它和 Cursor / Codex / Windsurf 的区别
3. 它现在的生态位
4. 哪些判断最值得写进文章里
```

你也可以这样触发：

- `帮我用横纵分析法研究一下 Manus`
- `调研一下 OpenAI 现在的竞品格局`
- `帮我深度研究这个 AI 产品，最后给我一个能写稿的结论`

### 推荐工作流

如果你要写深度公众号长文，最推荐这样用：

1. 先用 `hv-analysis` 做研究和竞品梳理
2. 再把研究结果 + 你自己的真实体验喂给 `khazix-writer`
3. 最后你自己再做一轮人工改写，保留你自己的口吻和判断

一句话理解：

- `hv-analysis` 负责“搞明白”
- `khazix-writer` 负责“写成稿”

### SEO 系

这些 skill 的上游来源已经确认，可以单独更新。

```powershell
npx -y skills add coreyhaines31/marketingskills@seo-audit -g -y
npx -y skills add coreyhaines31/marketingskills@schema -g -y
npx -y skills add coreyhaines31/marketingskills@ai-seo -g -y
```

当前状态：

- `seo-audit`：来源已确认，已更新到最新
- `schema`：来源已确认，当前已是最新
- `ai-seo`：来源已确认，已更新到最新

### Anthropic Skills 精选

这些 skill 来自 `anthropics/skills`，本次只安装了指定的单个 skill，没有把同仓库其他 skill 一起装下来。

```powershell
npx -y skills add anthropics/skills@webapp-testing -g -y
npx -y skills add anthropics/skills@pdf -g -y
npx -y skills add anthropics/skills@xlsx -g -y
npx -y skills add anthropics/skills@docx -g -y
npx -y skills add anthropics/skills@pptx -g -y
npx -y skills add anthropics/skills@canvas-design -g -y
```

当前状态：

- `webapp-testing`：来源已确认，已纳入管理系统，自动更新
- `pdf`：来源已确认，已纳入管理系统，自动更新
- `xlsx`：来源已确认，已纳入管理系统，自动更新
- `docx`：来源已确认，已纳入管理系统，自动更新
- `pptx`：来源已确认，已纳入管理系统，自动更新
- `canvas-design`：来源已确认，已纳入管理系统，自动更新

定位说明：

- `webapp-testing`：本地 Web 应用验证和 Playwright 流程检查
- `pdf`：PDF 读取、提取、拆分、合并、表单与 OCR
- `xlsx`：表格清洗、编辑、公式、图表和格式修复
- `docx`：Word 文档创建和编辑
- `pptx`：演示文稿创建和编辑
- `canvas-design`：静态视觉稿、海报、PNG/PDF 设计产物

### 其他已确认来源的 Presentation Skills

这批 skill 不都适合同一种管理方式，需要分开看。

```powershell
npx -y skills add lewislulu/html-ppt-skill@html-ppt -g -y
```

当前状态：

- `html-ppt`：来源已确认，已纳入管理系统，自动更新
- `ppt-master`：来源已确认，但按外部独立仓库管理，不纳入普通 skills-cli 自动更新

定位说明：

- `html-ppt`：专业 HTML 演示稿系统，适合做网页 slides、分享 deck、演讲稿、静态 HTML PPT，也适合做演示型、PPT 风格、editorial 风格的静态单页页面
- `ppt-master`：原生可编辑 PPTX 生成工作流，适合从 PDF / DOCX / URL / Markdown 生成正式可编辑演示文稿

#### `html-ppt`

- 来源仓库：`lewislulu/html-ppt-skill`
- 真实 skill 名：`html-ppt`
- 上游 `SKILL.md`：`https://raw.githubusercontent.com/lewislulu/html-ppt-skill/main/SKILL.md`
- 管理方式：纳入当前 skills 管理系统，自动更新

使用策略：

- 适合浏览器直接打开的网页演示稿
- 适合分享稿、技术演讲 slides、静态 HTML deck
- 也适合演示型、PPT 风格、editorial 风格的静态单页页面
- 不适合作为需要设计判断的产品官网或应用页面 skill；这类任务再考虑 `impeccable`，目标明确的局部维护直接处理

更新命令：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only html-ppt
```

#### `ppt-master`

- 来源仓库：`hugohe3/ppt-master`
- 真实 skill 名：`ppt-master`
- 本地仓库：`C:\Users\Computer\.agents\external\ppt-master`
- skill 入口：`C:\Users\Computer\.agents\external\ppt-master\skills\ppt-master\SKILL.md`
- 管理方式：整仓库独立管理，不走普通单 skill 纳管脚本
- 原因：它依赖仓库根目录结构、Python 依赖和仓库级工作流，不适合当成普通 skills-cli 单文件 skill 管理

使用策略：

- 适合从 PDF / DOCX / URL / Markdown 等资料直接生成正式可编辑 `.pptx`
- 适合最终必须交付 PowerPoint 文件，并且后续还要在 Microsoft PowerPoint 里继续编辑的场景
- 不适合 HTML 演示稿，也不适合作为修改现有 `.pptx` 的默认 skill

更新命令：

```powershell
git -C "C:\Users\Computer\.agents\external\ppt-master" pull --ff-only origin main
& "C:\Users\Computer\.agents\external\ppt-master\.venv\Scripts\python.exe" -m pip install -r "C:\Users\Computer\.agents\external\ppt-master\skills\ppt-master\requirements.txt"
```

补充说明：

- `ppt-master` 已建立独立虚拟环境：`C:\Users\Computer\.agents\external\ppt-master\.venv`
- 这样可以避免它的 Python 依赖继续污染你机器上的其他工具环境

### 当前路由理解

演示文稿相关 skill 现在建议这样理解：

- `pptx`：修改、拆分、整理现有 `.pptx`
- `ppt-master`：从资料生成正式可编辑 `.pptx`
- `html-ppt`：浏览器展示用的 HTML 演示稿，或演示型静态 HTML 页面

前端展示相关 skill 现在建议这样理解：

- `impeccable`：正常网页 / landing page / 产品界面；复杂交互 Web app / React demo / mini-app 的 UI / 功能实现
- `html-ppt`：演示型、PPT 风格、editorial 风格的静态 HTML 页面或 deck
- `canvas-design`：静态视觉稿、海报、封面
- `extract-design`：提取现有网站设计语言

## 当前不建议盲更

以下这类 skill 暂时不要直接用 `npx skills add ...` 覆盖更新：

- `impeccable`

原因：

- `impeccable` 当前是从 `pbakaus/impeccable` 的 `.agents/skills/impeccable` 镜像过来的本地全局安装。
- 它还承载本地 `local-routing-overrides.json` 里的触发边界，不能直接用 `npx skills add` 覆盖。

## 安全 / 风险分类

### 可以安全单独更新

- `web-access`
- `create-crush`
- `luo-xiang-perspective`
- `hv-analysis`
- `khazix-writer`
- `systematic-debugging`
- `chinese-documentation`
- `chinese-commit-conventions`
- `mcp-builder`
- `receiving-code-review`
- `chinese-code-review`
- `writing-plans`
- `seo-audit`
- `schema`
- `ai-seo`
- `extract-design`
- `webapp-testing`
- `pdf`
- `xlsx`
- `docx`
- `pptx`
- `canvas-design`
- `html-ppt`

### 来源已确认，但不要盲更

- `impeccable`：来源为 `pbakaus/impeccable` 的 `.agents/skills/impeccable` 生成目录，作为本地全局 skill 镜像管理。

原因：`impeccable` 既包含上游 `SKILL.md`、`reference/`、`scripts/`，也叠加了本地路由 override。更新时应从已审查的上游包同步，再运行 `apply-overrides` 和 `check`。

当前不再保留 Impeccable 拆分增强项：旧的 `adapt`、`animate`、`audit`、`clarify`、`critique`、`delight`、`distill`、`harden`、`optimize`、`polish`、`typeset` 独立目录已删除，统一使用 `impeccable/reference/*.md` 和 `$impeccable <command>` 子命令。

### 手动管理，不参加统一自动更新

- `officecli`

### 单独说明：`officecli`

- 本地目录：`C:\Users\Computer\.agents\skills\officecli`
- 当前状态：手动管理，不参加统一自动更新
- 使用策略：只在显式 officecli、OpenXML、校验修复或跨格式 CLI 场景触发；普通 Office 文件按 `docx` / `xlsx` / `pptx` 路由
- 原因：它有独特工具能力，但原始描述过宽；直接盲更可能冲掉本地触发边界

### 单独说明：`extract-design`

- 来源仓库：`Manavarya09/design-extract`
- 真实 skill 名：`extract-design`
- 当前状态：已纳入管理系统，自动更新
- 上游 `SKILL.md`：`https://raw.githubusercontent.com/Manavarya09/design-extract/main/skills/extract-design/SKILL.md`
- 同时已全局安装 CLI：`designlang@12.1.0`
- 使用策略：按需触发，不作为默认设计 skill

维护方式：

- 更新 skill：`manage-skills.ps1 -Mode update -Only extract-design`
- 更新 CLI：`npm update -g designlang`

定位：

- `extract-design` 负责让 AI 触发网站设计语言提取。
- `designlang` 负责实际执行网页设计系统分析、token 导出和报告生成。

### 已移除且不再纳管

- `verification-before-completion`、`brainstorming`、`test-driven-development`、`using-git-worktrees`：用户选择移除强制流程链，日常任务按风险和范围直接处理。
- `karpathy-guidelines`：与 Agent 基础工程规则重复，已移除。
- `skill-creator`：本地重复副本已移除；Codex 系统内置版本不受影响。
- `health`：用户不再保留 Claude 配置审计 skill。
- `deploy-to-vercel`、`vercel-cli-with-tokens`、`vercel-composition-patterns`、`vercel-react-best-practices`：Vercel 技能组已整体移除。
- `workctl`、`workctl-operator`：用户确认不使用 Work Agent 平台，两个入口均已退出活动 skills。
- `overdrive`：低频炫技视觉 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `quieter`：低频视觉降噪 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `colorize`：低频配色增强 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `layout`：低频布局专项 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `onboard`：低频 onboarding 专项 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `seo-audit-full`：与 `seo-audit` 重叠的深度 SEO 审计 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `web-design-guidelines`：与 `audit` / `critique` 重叠的规则化 UI 审查 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `vercel-react-native-skills`：React Native / Expo 专用 skill，当前不作为 Web/Next 主流程保留，已删除本地目录并从 `skills-sources.json` 移除。
- `bolder`：低频视觉增强 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `normalize`：低频设计系统一致性 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `extract`：低频组件/tokens 提取 skill，已删除本地目录并从 `skills-sources.json` 移除。
- `find-skills`：开放生态 skill 发现入口，与当前本地纳管流程重叠，已删除本地目录并从 `skills-sources.json` 移除。
- `adapt`、`animate`、`audit`、`clarify`、`critique`、`delight`、`distill`、`harden`、`optimize`、`polish`、`typeset`：已折叠进 `impeccable` 的 reference/sub-command 体系，独立目录和 `skills-sources.json` 条目已删除。

## 怎么判断该用哪种更新方式

### 如果 skill 目录里有自己的 `.git`

用：

```powershell
git -C "C:\Users\Computer\.agents\skills\<skill-name>" pull --ff-only origin main
```

### 如果这个 skill 是通过 Skills CLI 安装的

用仓库 + skill 名的写法：

```powershell
npx -y skills add owner/repo@skill-name -g -y
```

## 示例

```powershell
git -C "C:\Users\Computer\.agents\skills\web-access" pull --ff-only origin main
```

## 不建议这样做

```powershell
npx skills update
npx -y skills add vercel-labs/agent-skills -g -y
```

原因：

- 前者太宽泛，不适合你现在这套环境。
- 后者可能会把整仓库里不需要的 skill 一起拉下来。
