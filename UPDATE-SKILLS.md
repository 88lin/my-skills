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
- `web-access` 用 Git 更新，其余已确认来源的 skill 用单 skill 的 `npx skills add owner/repo@skill -g -y` 更新。

## 当前收手点与维护边界

当前这套管理系统已经处于稳定可用状态，后续维护优先用真实问题驱动，不要为了形式统一继续扩张规则。

先不要继续动这些地方：

- `manage-skills.ps1`：只在出现真实检查、更新、override 回写错误时修改，不为了“更优雅”重构
- `local-routing-overrides.json`：只给真冲突、真误触发、真需要保住本地规则的 skill 新增 override
- `skills-sources.json`：不要轻易改变现有 `manual` / `skills-cli` / `git` 分类，尤其保留 `health` 当前 `manual` 策略

这些点当前可以继续观察，不作为必须修复项：

- `ppt-master`：作为外部相关能力出现在路由文档里，边界复杂但已经说明清楚
- `web-access`：真实目录是独立 Git 仓库，GitHub 备份里缺少 `.git` 不代表它不能正常更新

以后只有出现真实误触发、真实漏触发、高冲突新 skill、或上游结构大改时，再重新修改规则。记录问题时至少写清：用户原话、期望触发的 skill、实际触发的 skill、造成的影响。

## 备份仓库注意

这个 GitHub 仓库主要是备份和说明用途，不等于每个 skill 在真实运行环境里的原生安装目录。

- 本文里的命令路径默认以真实运行目录 `C:\Users\Computer\.agents\skills` 为准
- `web-access` 的真实运行目录是 `C:\Users\Computer\.agents\skills\web-access`
- 真实目录里保留独立 `.git`，可以按 Git 方式和上游同步
- 上传到 GitHub 的备份目录可能不保留嵌套 `.git` 元数据，不要用备份目录判断 `web-access` 是否能更新
- 真正执行 `git pull`、检查远端 HEAD、或处理脏工作区时，应以真实本地 skills 目录为准

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
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" -SourceType manual -Skill frontend-design -LocalFolder frontend-design -SkipInstall -Reason "本地定制版本，不自动覆盖更新"
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
- Skills CLI 管理的 skill 用 `npx skills add owner/repo@skill -g -y`。
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

### Vercel 系

```powershell
npx skills add vercel-labs/agent-skills@deploy-to-vercel -g -y
npx skills add vercel-labs/agent-skills@vercel-cli-with-tokens -g -y
npx skills add vercel-labs/agent-skills@vercel-composition-patterns -g -y
npx skills add vercel-labs/agent-skills@vercel-react-best-practices -g -y
```

### 工具类

```powershell
npx skills add GeminiLight/MindOS@mindos-zh -g -y
```

### 其他已确认来源的 Skill

这些 skill 的来源已经确认，而且状态也已经核对过。

```powershell
npx skills add xiaoheizi8/crush-skills@create-crush -g -y
npx skills add YixiaJack/luo-xiang-skill@luo-xiang-perspective -g -y
npx skills add KKKKhazix/khazix-skills@hv-analysis -g -y
npx skills add KKKKhazix/khazix-skills@khazix-writer -g -y
npx skills add forrestchang/andrej-karpathy-skills@karpathy-guidelines -g -y
```

注意：`health` 已转为手动管理，当前不要再用 `npx skills add tw93/Waza@health -g -y` 直接覆盖，见后面的单独说明。

### Superpowers-ZH 精选 Skill

这些 skill 来自 `jnMetaCode/superpowers-zh`，只安装了当前选定的单个 skill，没有安装整仓库其他 skill。

```powershell
npx skills add jnMetaCode/superpowers-zh@systematic-debugging -g -y
npx skills add jnMetaCode/superpowers-zh@test-driven-development -g -y
npx skills add jnMetaCode/superpowers-zh@verification-before-completion -g -y
npx skills add jnMetaCode/superpowers-zh@chinese-documentation -g -y
npx skills add jnMetaCode/superpowers-zh@chinese-commit-conventions -g -y
npx skills add jnMetaCode/superpowers-zh@mcp-builder -g -y
npx skills add jnMetaCode/superpowers-zh@receiving-code-review -g -y
npx skills add jnMetaCode/superpowers-zh@chinese-code-review -g -y
npx skills add jnMetaCode/superpowers-zh@brainstorming -g -y
npx skills add jnMetaCode/superpowers-zh@writing-plans -g -y
npx skills add jnMetaCode/superpowers-zh@using-git-worktrees -g -y
```

当前状态：

- `systematic-debugging`：来源已确认，已纳入管理系统，自动更新
- `test-driven-development`：来源已确认，已纳入管理系统，自动更新
- `verification-before-completion`：来源已确认，已纳入管理系统，自动更新
- `chinese-documentation`：来源已确认，已纳入管理系统，自动更新
- `chinese-commit-conventions`：来源已确认，已纳入管理系统，自动更新
- `mcp-builder`：来源已确认，已纳入管理系统，自动更新
- `receiving-code-review`：来源已确认，已纳入管理系统，自动更新
- `chinese-code-review`：来源已确认，已纳入管理系统，自动更新
- `brainstorming`：来源已确认，已纳入管理系统，自动更新
- `writing-plans`：来源已确认，已纳入管理系统，自动更新；轻量计划 skill，适合小中型任务，不替代 GSD
- `using-git-worktrees`：来源已确认，已纳入管理系统，自动更新；并行开发隔离 skill，按需触发，不默认使用

定位说明：

- `writing-plans` 只作为轻量实施计划补充。小中型、需求已明确的任务可以用它拆步骤；多阶段项目、复杂集成、里程碑规划仍优先使用 GSD 规划体系。
- `using-git-worktrees` 只在需要隔离工作区时使用，例如并行任务、临时 hotfix、PR 检查或多方案实验；日常单任务开发不默认启用。

当前状态：

- `create-crush`：来源已确认，当前已是最新
- `luo-xiang-perspective`：来源已确认，当前已是最新
- `health`：来源已确认，但当前已改为手动管理，不参加统一自动更新
- `hv-analysis`：来源已确认，已纳入管理系统
- `khazix-writer`：来源已确认，已纳入管理系统
- `karpathy-guidelines`：来源已确认，已纳入管理系统

#### `karpathy-guidelines`

用途：约束编码行为，减少乱猜需求、过度设计、顺手大改、缺少验收标准这类常见问题。

更适合在 `OpenCode` 里这样触发：

```text
这次任务请遵循 karpathy-guidelines：
1. 不要擅自假设，不清楚先问
2. 先用最小正确改动解决问题
3. 只改和需求直接相关的代码
4. 给出可验证的完成标准，必要时先写复现或验证步骤
```

适合的场景：

- `修 bug，但不要顺手重构一大片`
- `做一个小功能，但别过度设计`
- `帮我 review 这个改动，先说风险和问题`
- `先确认需求歧义，再开始改代码`

如果你想在 `OpenCode` 里更明确地触发，也可以直接这样说：

- `这次按 karpathy-guidelines 的方式处理`
- `先按 karpathy-guidelines 澄清假设，再动手`
- `用 karpathy-guidelines 约束这次改动，保持最小 diff`

### 适合公众号写作的 Khazix Skills

这两个 skill 很适合你现在的使用场景。

#### `khazix-writer`

用途：公众号长文写作、扩写、续写、把素材整理成完整文章。

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
npx skills add coreyhaines31/marketingskills@seo-audit -g -y
npx skills add coreyhaines31/marketingskills@schema-markup -g -y
npx skills add coreyhaines31/marketingskills@ai-seo -g -y
```

当前状态：

- `seo-audit`：来源已确认，已更新到最新
- `schema-markup`：来源已确认，当前已是最新
- `ai-seo`：来源已确认，已更新到最新

### Anthropic Skills 精选

这些 skill 来自 `anthropics/skills`，本次只安装了指定的单个 skill，没有把同仓库其他 skill 一起装下来。

```powershell
npx skills add anthropics/skills@webapp-testing -g -y
npx skills add anthropics/skills@pdf -g -y
npx skills add anthropics/skills@xlsx -g -y
npx skills add anthropics/skills@skill-creator -g -y
npx skills add anthropics/skills@docx -g -y
npx skills add anthropics/skills@pptx -g -y
npx skills add anthropics/skills@canvas-design -g -y
npx skills add anthropics/skills@web-artifacts-builder -g -y
```

当前状态：

- `webapp-testing`：来源已确认，已纳入管理系统，自动更新
- `pdf`：来源已确认，已纳入管理系统，自动更新
- `xlsx`：来源已确认，已纳入管理系统，自动更新
- `skill-creator`：来源已确认，已纳入管理系统，自动更新
- `docx`：来源已确认，已纳入管理系统，自动更新
- `pptx`：来源已确认，已纳入管理系统，自动更新
- `canvas-design`：来源已确认，已纳入管理系统，自动更新
- `web-artifacts-builder`：来源已确认，已纳入管理系统，自动更新

定位说明：

- `webapp-testing`：本地 Web 应用验证和 Playwright 流程检查
- `pdf`：PDF 读取、提取、拆分、合并、表单与 OCR
- `xlsx`：表格清洗、编辑、公式、图表和格式修复
- `skill-creator`：创建、优化、评估和 benchmark 现有 skill
- `docx`：Word 文档创建和编辑
- `pptx`：演示文稿创建和编辑
- `canvas-design`：静态视觉稿、海报、PNG/PDF 设计产物
- `web-artifacts-builder`：复杂 HTML artifact 和多组件前端演示

### 其他已确认来源的 Presentation Skills

这批 skill 不都适合同一种管理方式，需要分开看。

```powershell
npx skills add lewislulu/html-ppt-skill@html-ppt -g -y
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
- 不适合作为普通产品官网或常规应用页面的默认 skill；那类优先仍看 `frontend-design`

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

- `frontend-design`：正常网页 / landing page / 产品界面
- `html-ppt`：演示型、PPT 风格、editorial 风格的静态 HTML 页面或 deck
- `web-artifacts-builder`：复杂 React artifact
- `canvas-design`：静态视觉稿、海报、封面
- `extract-design`：提取现有网站设计语言

## 当前不建议盲更

以下这类 skill 暂时不要直接用 `npx skills add ...` 覆盖更新：

- 设计系大部分 skill，例如 `frontend-design`、`polish`、`audit`、`teach-impeccable`

原因：

- 这批 skill 很像本地混合定制版本，不是单一上游的干净安装。
- 如果直接覆盖，可能把你现在这套可用的依赖关系弄乱。

## 安全 / 风险分类

### 可以安全单独更新

- `web-access`
- `deploy-to-vercel`
- `vercel-cli-with-tokens`
- `vercel-composition-patterns`
- `vercel-react-best-practices`
- `mindos-zh`
- `create-crush`
- `luo-xiang-perspective`
- `hv-analysis`
- `khazix-writer`
- `karpathy-guidelines`
- `systematic-debugging`
- `test-driven-development`
- `verification-before-completion`
- `chinese-documentation`
- `chinese-commit-conventions`
- `mcp-builder`
- `receiving-code-review`
- `chinese-code-review`
- `brainstorming`
- `writing-plans`
- `using-git-worktrees`
- `seo-audit`
- `schema-markup`
- `ai-seo`
- `extract-design`
- `webapp-testing`
- `pdf`
- `xlsx`
- `skill-creator`
- `docx`
- `pptx`
- `canvas-design`
- `web-artifacts-builder`
- `html-ppt`

### 来源已大致确认，但不要盲更

- `frontend-design`
- `teach-impeccable`
- `polish`
- `audit`
- 以及大概率同一设计体系里的：`adapt`、`animate`、`clarify`、`critique`、`delight`、`distill`、`harden`、`optimize`、`typeset`

原因：这套设计 skill 很像基于 Anthropic 和 `impeccable` 生态做过本地定制，不适合自动覆盖更新。

当前保留的 Impeccable 拆分增强项：

- `animate`：来源为 `pbakaus/impeccable` 的 `reference/animate.md`，已改成本地独立 skill，手动纳管，不自动更新。
- `delight`：来源为 `pbakaus/impeccable` 的 `reference/delight.md`，已改成本地独立 skill，手动纳管，不自动更新。

### 这个文件里当前没有未确认来源项

- `none currently tracked in this file`

### 单独说明：`health`

- 本地目录：`C:\Users\Computer\.agents\skills\health`
- 当前状态：已改为手动管理，不参加统一 `skills-cli` 自动更新
- 原因：当前 `tw93/Waza` 的 `skills` CLI 识别结果与本地 `health` 条目不一致，继续走统一自动更新会报错
- 当前策略：保留本地已安装版本，先停止自动更新，等确认安全更新路径后再恢复自动化

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

## 怎么判断该用哪种更新方式

### 如果 skill 目录里有自己的 `.git`

用：

```powershell
git -C "C:\Users\Computer\.agents\skills\<skill-name>" pull --ff-only origin main
```

### 如果这个 skill 是通过 Skills CLI 安装的

用仓库 + skill 名的写法：

```powershell
npx skills add owner/repo@skill-name -g -y
```

## 示例

```powershell
npx skills add vercel-labs/agent-skills@vercel-react-best-practices -g -y
git -C "C:\Users\Computer\.agents\skills\web-access" pull --ff-only origin main
```

## 不建议这样做

```powershell
npx skills update
npx skills add vercel-labs/agent-skills -g -y
```

原因：

- 前者太宽泛，不适合你现在这套环境。
- 后者可能会把整仓库里不需要的 skill 一起拉下来。
