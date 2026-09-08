# Skills 更新说明

这份文档说明全局 skill 的检查、更新、纳管和恢复方式。活动状态以磁盘和配置文件为准，不维护容易过期的静态数量清单。

## 关键路径

- 活动目录：`C:\Users\Computer\.agents\skills`
- 备份仓库：`C:\Users\Computer\Documents\GitHub\my-skills`（GitHub `88lin/my-skills`）
- 来源登记：`skills-sources.json`
- 本地持久规则：`local-routing-overrides.json`
- Claude Code 白名单：`C:\Users\Computer\.claude\skills`
- QoderWork skill 入口：当前不存在（`C:\Users\Computer\.qoderwork` 下无 `skills` 目录）
- WorkBuddy skill 入口：`C:\Users\Computer\.workbuddy\skills`
- 备份、缓存和外部仓库：`C:\Users\Computer\.agents\external`

## 日常命令

### 检查全部

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check
```

`check` 是只读操作：检查来源版本、目录完整性、override 是否同步以及 `bodyPatches` 是否仍能匹配。

### 应用本地规则

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides
```

修改 `local-routing-overrides.json` 后运行。它不会获取上游，只把已经登记的本地规则写回对应 `SKILL.md`。

### 更新允许自动更新的 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update
```

更新会获取上游、重放 override，再检查结果。日常更推荐先检查，再按需更新指定 skill。

### 只处理指定 skill

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only ai-seo,seo-audit
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only ai-seo
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides -Only systematic-debugging
```

桌面上的 `更新 Skills.bat` 是日常图形入口，最终仍调用同一套管理脚本。

## 推荐更新流程

1. 运行 `check`，确认需要更新的目标。
2. 对重要或有本地规则的 skill，使用 `-Only` 单独更新。
3. 再运行一次目标 `check`。
4. 检查 `C:\Users\Computer\.claude\skills` 是否出现意外入口。
5. 遇到 `patch-stale` 时先审查上游变化，不要直接删除补丁或覆盖本地文件。

通过 symlink 映射到 WorkBuddy 的 skill 不需要单独复制或更新；更新 `C:\Users\Computer\.agents\skills` 后，客户端会读取同一份内容。客户端入口只需检查链接是否仍指向活动目录。

QoderWork 当前没有 skill 入口目录（`C:\Users\Computer\.qoderwork` 下不存在 `skills`），所以不需要为它做任何同步。如果以后重建了入口，按 WorkBuddy 的方式建 symlink 指向活动目录，不要复制实体目录。

`C:\Users\Computer\.workbuddy\skills` 下除 symlink 外还有几个实体目录（`checklist-design`、`frontend-dev`、`knowledge-base`、`wechat-cover`），它们不在本仓库纳管范围内。其中 `knowledge-base` 与活动目录里的同名 skill 是两份独立内容，改动其中一份不会同步到另一份。

不要使用宽泛的 `npx skills update`，也不要把整个多 skill 仓库一次性安装进全局目录。

## 来源类型

### `git`

- 用于本身就是独立 Git 仓库的 skill。
- 管理器按 `skills-sources.json` 登记的 remote 和 branch 检查、更新。
- 当前 `web-access` 恢复为 `git`、`autoUpdate: true`，不再维护本地路由 override。
- 如果 `SKILL.md` 依赖仓库内的脚本、参考资料或数据目录，必须保留完整工作树，不能只下载根目录的 `SKILL.md`。
- `img2threejs` 属于完整仓库型 skill，更新后必须确认 `forge/`、`grimoire/`、`scripts/` 和 `docs/` 仍存在。
- `xhs-visual-director` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\xhs-visual-director-source`；登记的 `syncSkillDirectory: skill` 会在 Git 更新后把上游 `skill` 子目录同步到活动 skill 根目录。
- `ian-xiaohei-illustrations` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\ian-xiaohei-illustrations-source`；活动目录只保留同步后的 skill 内容，避免 Codex 递归扫描出重复 skill。
- `modlens` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\modlens-source`；登记的 `syncSkillDirectory: skills\\modlens` 会同步入口、Windows/Unix 启动脚本和 references 到活动 skill 根目录。
- `archify` 的完整 Git 源仓库保存在 `C:\Users\Computer\.agents\external\archify-source`；登记的 `syncSkillDirectory: archify` 会同步独立 HTML 技术图所需的 CLI、schemas、renderers、references 和资源，不把外层网站、研究文档、测试项目暴露为活动 skill。
- Git 源仓库需要与活动目录分离时，使用 `repositoryFolder` 指向外部仓库，再用 `syncSkillDirectory` 把仓库内的 skill 子目录同步到活动目录；如果入口依赖仓库根部资料，再用 `syncSkillDirectories` 按目录名同步这些资源。不要手工把完整仓库复制回活动 skill 根目录。

### `skills-cli`

- 从 `skills-sources.json` 登记的仓库和单 skill 名获取更新。
- 更新后自动重放 `local-routing-overrides.json`。
- 可能在 `C:\Users\Computer\.claude\skills` 创建额外软链接或目录入口。

需要手动执行单项安装时，使用明确的仓库和 skill：

```powershell
npx -y skills add owner/repo@skill-name -g -y
```

不要省略 `@skill-name`，否则可能安装同仓库中不需要的其他 skill。

### `manual`

`manual` 表示不能由通用管理器盲目覆盖。`check` 仍会核对目录和本地规则，但不会自动拉取上游。

当前主要人工审核项：

- `impeccable`：使用专用 preview/apply 更新器。
- `officecli`：低层跨格式 Office 工具，按人工审核维护。

不要仅因为某项是 `manual` 就把它改成自动更新；先确认它是否能在不丢本地内容的情况下稳定重放。

## 检查状态

| 状态 | 含义 | 处理 |
|---|---|---|
| `up-to-date` | 来源、本地规则和结构正常 | 无需操作 |
| `outdated` | 上游或本地生成结果有差异 | 审查后更新或重放 override |
| `patch-stale` | `bodyPatches.find` 已无法匹配当前上游 | 对照上游修改补丁，再单项更新 |
| `error` | 来源不可达、目录缺失或命令失败 | 先处理具体错误，不要批量覆盖 |
| `skipped` | 人工管理或明确跳过 | 按对应专用流程处理 |

`manual` 型的 `up-to-date` **不代表上游已经检查过**，它只表示"本地 override 与本地 `SKILL.md` 一致"（有 override 的 manual 项走这条判定，没有 override 的显示 `skipped`）。`impeccable` 的真实上游状态只能用 `update-impeccable.ps1 -Mode preview` 得到，`check` 表格看不出它有没有待应用的上游更新。

`git` 型出现 `outdated` 且 detail 提到 `local skill directory out of sync` 时，说明源仓库已经拉到最新、但 `syncSkillDirectory` 还没同步进活动目录，跑一次 `update -Only <skill>` 即可。这个同步是**只覆盖不删除**的，活动目录里多出来的文件不会被清掉。

`git` 型报 `缺少 Git 源仓库目录` 时，是 `.agents\external\<name>-source` 丢了而不是 skill 坏了。按 `skills-sources.json` 里登记的 remote 重新 clone 回去即可，活动目录内容不用动：

```powershell
git clone <remote> "C:\Users\Computer\.agents\external\<name>-source"
```

管理器检查通过只能证明配置和生成结果一致，不能替代对触发优先级是否符合使用习惯的人工判断。

## 本地 Override

`local-routing-overrides.json` 是本地触发规则的权威来源。不要只编辑生成后的 `SKILL.md`，否则下一次更新会覆盖。

允许持久化的内容主要包括：

- 真实误触发或多个 skill 的职责冲突
- 需要长期保留的客户端兼容边界
- 已删除依赖、真实断链、无效命令或确认的兼容故障

正文默认保持上游原样。字段选择和 `patch-stale` 处理见 `LOCAL-ROUTING-OVERRIDES-USAGE.md`。

## Impeccable 专用更新

预览：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\update-impeccable.ps1" -Mode preview
```

确认预览后应用：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\update-impeccable.ps1" -Mode apply
```

专用更新器会检查上游 bundle、重放 `impeccable-local-patches.json` 和路由规则，再替换活动目录。不要直接覆盖 `impeccable/SKILL.md`。

## Claude Code 白名单

`C:\Users\Computer\.claude\skills` 是面向 Claude Code 的入口视图，不是第二份独立 skill 仓库。

`skills-cli` 安装或更新可能自动创建 Claude 入口，因此每次 update/install 后直接检查现场：

```powershell
Get-ChildItem -LiteralPath "C:\Users\Computer\.claude\skills" -Force
```

不需要暴露给 Claude 的入口应从白名单移除，但不要因此删除 `C:\Users\Computer\.agents\skills` 中仍供其他客户端使用的本体。不要依赖文档里的旧数量或旧名单判断当前状态。

## 安装并纳管新 Skill

交互入口：`C:\Users\Computer\Desktop\纳管新 Skill.bat`

底层脚本：`install-and-register-skill.ps1`

### 先预览

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" `
  -SourceType skills-cli `
  -Repo owner/repo `
  -Skill skill-name `
  -RawSkillUrl "https://raw.githubusercontent.com/owner/repo/main/path/SKILL.md" `
  -Preview
```

### 确认后安装并登记

去掉 `-Preview`。脚本会安装单个 skill、定位本地目录、核对上游并写入 `skills-sources.json`。

### 登记人工管理项

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" `
  -SourceType manual `
  -Skill skill-name `
  -LocalFolder skill-folder `
  -SkipInstall `
  -Reason "为什么不能自动覆盖"
```

只有来源明确、单 skill 路径稳定且能验证本地内容的项目才适合 `skills-cli` 自动更新。

### 完整 Git 仓库型 Skill

以下 Git 仓库型 skill 使用 Git 纳管，来源均为各自 GitHub 仓库的 `main` 分支：

- `xhs-visual-director`：源仓库为 `C:\Users\Computer\.agents\external\xhs-visual-director-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\xhs-visual-director`；活动目录保留入口、`agents` 以及运行所需的 `assets`、`docs`、`examples`、`templates`，不包含完整 Git 仓库。
- `oil-cover`：`C:\Users\Computer\.agents\skills\oil-cover`；上游入口为根目录 `SKILL.md`。
- `ian-xiaohei-illustrations`：源仓库为 `C:\Users\Computer\.agents\external\ian-xiaohei-illustrations-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\ian-xiaohei-illustrations`；活动目录只保留内层 skill 内容。
- `modlens`：源仓库为 `C:\Users\Computer\.agents\external\modlens-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\modlens`；活动目录同步 `skills\\modlens`，保留 `SKILL.md`、`scripts` 和 `references`，不包含完整项目源码。
- `archify`：源仓库为 `C:\Users\Computer\.agents\external\archify-source`，活动 skill 为 `C:\Users\Computer\.agents\skills\archify`；活动目录同步仓库内的 `archify` 子目录，保留渲染、校验、导出和视觉检查所需的完整运行包。
- `img2threejs`：`C:\Users\Computer\.agents\skills\img2threejs`；需要完整保留 `forge/`、`grimoire/`、`scripts/` 和 `docs/`。

日常检查和更新：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only img2threejs
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only img2threejs
```

不要把这些仓库改成只含 `SKILL.md` 的单文件安装；它们的 `references/`、`templates/`、`assets/`、脚本或数据目录都是运行和参考流程的一部分。

## 备份仓库

`C:\Users\Computer\Documents\GitHub\my-skills` 是活动目录的备份镜像，不是第二份活动 skill。唯一的权威内容在 `C:\Users\Computer\.agents\skills`。

同步方向固定为**活动目录 → 备份仓库**。反向复制会把旧内容盖回在用的 skill，`web-access` 曾因此在备份里停留在 v2.5.3、而活动目录已经是 v2.5.4。

需要修改配置、脚本或本地 override 时，先在备份仓库里改并验证，再同步到活动目录。管理脚本以自身所在目录为根（`$ScriptRoot`），所以直接跑备份仓库里的 `manage-skills.ps1` 只会作用于备份自己，可以安全试：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\Documents\GitHub\my-skills\manage-skills.ps1" -Mode check -Only <skill>
```

注意备份仓库里跑 `git` 型 skill 会失败，因为 `repositoryFolder` 相对备份根解析不到 `.agents\external`。`git` 型只能在活动目录侧更新。

每次 update/apply-overrides 之后都要把结果同步回备份并提交，否则备份会静默落后。用下面这条**只列差异、不改文件**的命令核对（无输出即完全一致）：

```powershell
robocopy "C:\Users\Computer\.agents\skills" "C:\Users\Computer\Documents\GitHub\my-skills" /MIR /XD .git /XF .gitattributes /L /NDL /NJH /NJS /NP
```

去掉 `/L` 才会真正复制。此时务必先确认备份里没有尚未同步到活动目录的改动：`/MIR` 是单向镜像，会把备份独有的文件删掉、把备份里更新的内容盖回旧版。所以顺序永远是"先把备份里的修改同步进活动目录并验证，再用 `/MIR` 反向刷回备份"。`/XF .gitattributes` 是必需的，否则 `/MIR` 会因为活动目录没有这个文件而把它删掉。

`.agents\external` 下的源仓库和备份**不在**这个仓库里，丢了要按 `skills-sources.json` 的 remote 重新 clone。

仓库里的 `.gitattributes` 用 `* -text` 关掉了 Git 的行尾转换，这样任何机器克隆都能逐字节还原活动目录。不要删掉它，否则 `core.autocrlf` 会重新在还原时改写行尾。

## 删除和恢复

删除一个 skill 时同步处理：

1. `C:\Users\Computer\.agents\skills` 活动目录。
2. `skills-sources.json` 来源登记。
3. `local-routing-overrides.json` 对应规则。
4. `C:\Users\Computer\.claude\skills` 入口。
5. 其他活动 skill 对它的依赖或 Related Skills 引用。

删除前把可恢复副本放到 `C:\Users\Computer\.agents\external`。恢复时不要只复制目录，还要恢复来源登记和需要的客户端入口，然后运行 `check`。

## 当前已移除

- 流程入口：`brainstorming`、`test-driven-development`、`verification-before-completion`、`using-git-worktrees`、`writing-plans`
- 通用或重复：`karpathy-guidelines`、本地 `skill-creator`
- 平台和低频：`health`、`workctl`、`workctl-operator`
- Vercel 组：`deploy-to-vercel`、`vercel-cli-with-tokens`、`vercel-composition-patterns`、`vercel-react-best-practices`
- 失效重流程：`extract-design`
- 已折叠进 `impeccable` 的旧设计辅助 skill

历史原因和具体变更保留在 `SKILL-ROUTING-CHANGELOG.md`，这里不重复展开。
