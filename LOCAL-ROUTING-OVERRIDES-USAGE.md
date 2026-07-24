# Local Routing Overrides

`local-routing-overrides.json` 是本地触发规则的权威来源。上游负责提供和更新 skill，本地 override 负责在更新后重放经过确认的触发边界和兼容补丁。

不要只修改生成后的 `SKILL.md`。下一次 `update` 或 `apply-overrides` 会按 override 重新生成相关内容。

## 什么时候添加 Override

只在以下情况添加：

- 上游 description 在本地会造成真实误触发或漏触发
- 两个或多个 skill 的最终产物、职责或默认入口存在明显冲突
- 需要长期保留轻量化、安全或客户端兼容边界
- 上游正文引用已删除或本地未安装的 skill、文件或工具
- 上游正文包含已确认的无效命令、依赖或兼容故障

不要为了格式统一给每个 skill 添加 Usage Rule，也不要仅凭一次假设性的冲突修改路由。

## 字段

```json
{
  "overrides": [
    {
      "skill": "skill-name",
      "localFolder": "skill-folder",
      "description": "运行时触发描述",
      "usageRule": "写入正文顶部的本地边界",
      "bodyPatches": [
        {
          "reason": "为什么必须长期修正",
          "find": "上游原文的精确文本",
          "replace": "本地替换文本"
        }
      ]
    }
  ]
}
```

### `skill` 与 `localFolder`

- `skill`：与 `skills-sources.json` 对应的逻辑名称。
- `localFolder`：活动目录下的实际文件夹名称。

新增或重命名时，两处登记必须一致。

### `description`

真正参与 skill 选择的主要触发信号。应同时说明：

- skill 做什么
- 什么情况下使用
- 容易冲突时什么情况下不要使用

把重要触发条件写在 description 中，不要只写在 Usage Rule，因为正文只有触发之后才会加载。

### `usageRule`

写入 `SKILL.md` 顶部的受管区块：

```text
<!-- LOCAL ROUTING OVERRIDE START -->
...
<!-- LOCAL ROUTING OVERRIDE END -->
```

它用于 skill 已触发后的执行边界、快速路径和相邻 skill 分工，不能代替清晰的 description。

### `bodyPatches`

用于对上游正文做精确字符串替换。默认保持上游正文不变，仅对可客观验证的问题使用最小补丁：

- 已删除或未安装依赖
- 真实文件断链
- 无效命令或环境绑定
- 已确认的客户端兼容故障

不要用 `bodyPatches` 润色措辞、统一格式、重排工作流或加入个人偏好。补丁越大，上游更新时越容易漂移。

`find` 是区分大小写的普通字符串，不是正则表达式；空格和换行必须与上游一致。`reason` 只供维护者阅读，不写入生成后的 `SKILL.md`。

## 字段选择

| 需要修改的位置 | 使用字段 |
|---|---|
| frontmatter 触发描述 | `description` |
| 正文顶部本地边界 | `usageRule` |
| 上游正文中的客观错误 | `bodyPatches` |

如果只是路由冲突，优先修改 description；需要触发后的执行边界时再加 Usage Rule；只有正文确实存在问题时才用 body patch。

## 应用与检查

应用全部 override：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides
```

只应用指定 skill：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides -Only impeccable,webapp-testing
```

应用后检查：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only impeccable,webapp-testing
```

推荐顺序：

1. 修改 `local-routing-overrides.json`。
2. 对受影响的 skill 运行 `apply-overrides -Only ...`。
3. 运行对应的 `check -Only ...`。
4. 检查生成后的 description、受管区块和正文补丁是否符合预期。

`apply-overrides` 不统一改写其他上游 metadata。上游 frontmatter 即使与辅助校验器的偏好不同，只要没有真实加载故障就保持原样。

## `patch-stale` 怎么处理

上游修改了被补丁匹配的原文后，`check` 或 `update` 会报告 `patch-stale`，防止旧补丁静默失效。

处理顺序：

1. 查看 `check -Only <skill>` 给出的 missing 预览。
2. 对照当前上游 `rawSkillUrl`，确认原文为何变化。
3. 判断补丁是否仍然必要；不再需要就删除该 patch。
4. 仍然需要时，更新 `find`，必要时同步调整 `replace`。
5. 单独运行 `update -Only <skill>`，再运行 `check`。

不要为了消除 `patch-stale` 直接覆盖本地规则，也不要在未读上游变化的情况下扩大模糊匹配。

## 更新边界

- `skills-cli`：可以获取上游，更新后自动重放 override。
- `manual`：不由通用管理器覆盖，但可以用 `apply-overrides` 写入本地规则。
- 独立 Git 工作树中的本地修改要么转成可重放规则，要么明确改为人工审核更新；不要把脏工作树伪装成可自动更新状态。

更新或安装后检查 `C:\Users\Computer\.claude\skills`，因为 skills CLI 可能额外创建 Claude Code 入口。

## 和其他文件的关系

- `skills-sources.json`：决定 skill 从哪里来、活动目录是什么、是否自动更新。
- `manage-skills.ps1`：读取来源和 override，执行检查、更新与重放。
- `SKILL-ROUTING-RULES.md`：解释优先级和冲突边界，不是生成源。
- 各 skill 的 `SKILL.md`：最终运行文件，其中本地受管内容可能由 override 生成。

维护本地规则时，优先修改 override，然后重放并检查；不要把生成后的 `SKILL.md` 当作唯一来源。
