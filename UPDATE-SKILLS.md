# Skills 更新说明

这份文档说明全局 skill 的检查、更新、纳管和恢复方式。活动状态以磁盘和配置文件为准，不维护容易过期的静态数量清单。

## 关键路径

- 活动目录：`C:\Users\Computer\.agents\skills`
- 来源登记：`skills-sources.json`
- 本地持久规则：`local-routing-overrides.json`
- Claude Code 白名单：`C:\Users\Computer\.claude\skills`
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

不要使用宽泛的 `npx skills update`，也不要把整个多 skill 仓库一次性安装进全局目录。

## 来源类型

### `git`

- 用于本身就是独立 Git 仓库的 skill。
- 管理器按 `skills-sources.json` 登记的 remote 和 branch 检查、更新。
- 当前 `web-access` 恢复为 `git`、`autoUpdate: true`，不再维护本地路由 override。

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
