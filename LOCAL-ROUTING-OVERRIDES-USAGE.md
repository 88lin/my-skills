# local-routing-overrides 使用说明

## 这是什么

文件路径：

- `C:\Users\Computer\.agents\skills\local-routing-overrides.json`

对已经纳入 override 系统的 skill，这个文件是你本地路由增强规则的**真正来源**。

它的作用是：

- 当上游 skill 更新后
- 自动把你本地定制过的 `description` 和 `Usage Rule`
- 再写回对应的 `SKILL.md`

一句话理解：

**上游负责更新 skill，本地 override 负责保住你的触发规则。**

---

## 为什么需要它

你之前的问题是真实存在的：

- `更新 Skills.bat` 会调用 `manage-skills.ps1 -Mode update`
- `skills-cli` 类型的 skill 更新时，本质上会重新安装上游 skill
- 如果你直接改本地 `SKILL.md`，那些改动就可能被覆盖

所以现在采用的机制是：

1. 上游更新正常走
2. 更新后自动读取 `local-routing-overrides.json`
3. 把你的本地规则重新回写到对应 `SKILL.md`

对于 `manual` 类型的 skill，没有“上游更新”这一步，但仍然可以通过 `manage-skills.ps1 -Mode apply-overrides` 把 override 回写到本地文件。

这样可以同时保留：

- 自动更新能力
- 本地路由增强规则

---

## 文件结构

当前结构是：

```json
{
  "overrides": [
    {
      "skill": "html-ppt",
      "localFolder": "html-ppt",
      "description": "...",
      "usageRule": "## Usage Rule\n...",
      "bodyPatches": [
        {
          "reason": "为什么要打这个补丁",
          "find": "上游 SKILL.md 里要替换的精确文本",
          "replace": "你想要的替换文本"
        }
      ]
    }
  ]
}
```

每个 override 最多有 5 个字段：

- `skill`
  - skill 名称
- `localFolder`
  - 本地目录名
- `description`
  - 要覆盖进 frontmatter 的 description
- `usageRule`
  - 要写回 `SKILL.md` 顶部 `<!-- LOCAL ROUTING OVERRIDE START --> ... END -->` 块的 `## Usage Rule` 段落
- `bodyPatches`（可选）
  - 数组；用来对 SKILL.md **正文段落**做精确替换
  - 每项包含：
    - `reason`：人类可读的注释，说明为什么打这个补丁（仅给维护者看，不写入文件）
    - `find`：上游 SKILL.md 里要被替换的**精确文本**（区分大小写、空格、换行）
    - `replace`：替换后的文本

### bodyPatches 的能力边界

`description` 和 `usageRule` 都只能改 frontmatter 和顶部 Usage Rule 块。`bodyPatches` 用来补足正文段落级覆盖能力，典型场景：

- 上游 SKILL.md 主体里硬编码了未安装的子 skill 引用（例如 `superpowers:*`、`elements-of-style:*`）
- 上游某段流程描述与本地路由结论冲突（例如某 skill 主体里强制 invoke 另一个 skill）
- 上游模板在本地环境跑不动（例如硬编码沙箱路径）

### bodyPatches 的行为

- 应用顺序按数组顺序，每条 patch 独立替换
- 如果 `find` 文本在输入正文里**不存在**，脚本不会改写该段，但会在内部 `$script:CurrentApplyMissingPatches` 里记录一条 "missing" 事件，并按调用模式给出不同反馈：
  - `check` 模式：脚本会用上游 RemoteText（skills-cli）或本地 LocalText（manual）跑一次 patches；只要任一 `patch.find` 没匹配到，状态会标成 **`patch-stale`**，Detail 给出 missing 数量和 find 文本预览。这是判断"上游漂移导致补丁失效"的主要途径
  - `update` 模式：拉完上游 → apply → 复检；如果上游内容已变到 `patch.find` 不能匹配，最终状态会从 `up-to-date` 变成 `patch-stale`，Action 标为 `failed`，update 不会被误判为成功
  - `apply-overrides` 模式：missing 在幂等 rerun 时是**预期**行为（本地已经替换过，find 自然找不到）；脚本不会因此报错或改 Status，但会把 missing 数量附在 Detail 里。如果你是**首次 apply** 却也看到 missing，应改用 `update -Only <skill>` 重新从上游拉
- patch 用普通字符串匹配（不是 regex）；换行符要在 JSON 里写成 `\n`，引号写成 `\"`，反斜杠写成 `\\`；反引号、中文、emoji 直接写
- 当 check 或 update 标 `patch-stale` 时，建议处理顺序：
  1. 看 `manage-skills.ps1 -Mode check -Only <skill>` 输出的 find 预览
  2. `curl` 当前上游 `rawSkillUrl` 看 `patch.find` 对应段落已改成什么样
  3. 改 `local-routing-overrides.json` 里的 `patch.find`（必要时也改 `replace`）
  4. 跑 `manage-skills.ps1 -Mode update -Only <skill>` 拉上游 + 应用新 patch
  5. 再跑一次 check 确认 `up-to-date`

### bodyPatches vs usageRule：选哪个？

| 想改的位置 | 用什么 |
|---|---|
| frontmatter `description` | `description` 字段 |
| 顶部的 Usage Rule 块 | `usageRule` 字段 |
| 主体任何其他段落 | `bodyPatches` |

如果你只是想给 skill 加一条本地触发边界，**先试 usageRule**；只有当本地规则需要直接修改上游正文（比如改流程、删死引用）时才用 `bodyPatches`。

---

## 什么时候该改这个文件

只有在下面这些情况，才应该改它：

1. 你想给某个自动更新 skill 加本地触发规则
2. 你想修改某个已加规则 skill 的 `description`
3. 你想修改某个已加规则 skill 的 `Usage Rule`
4. 你又安装了一个会和现有 skill 冲突的新 skill

如果一个 skill 本来不需要本地路由增强，就不要往这里加。

---

## 什么情况下不要改它

下面这些情况不要动这个文件：

- 只是想更新 skill
- 只是想检查 skill 是否最新
- 只是想看某个 skill 的原始说明
- 一个 skill 本来就职责很独立，没有冲突

也就是说：

**不是每个 skill 都需要 override。**

只有真正会和别的 skill 抢触发的，才值得加。

---

## 如何新增一个 override

假设你未来又给某个自动更新 skill 加了本地触发规则，推荐步骤是：

### 第一步：先判断是不是必要

先问自己：

- 这个 skill 是否真的和别的 skill 有冲突？
- 这个冲突是否会影响默认触发？
- 有没有必要保住本地定制规则？

如果答案是“没有明显冲突”，不要加。

### 第二步：写好本地版本的 `description` 和 `Usage Rule`

先把你真正想要的：

- `description`
- `## Usage Rule`

想清楚。

### 第三步：把它写进 `local-routing-overrides.json`

示例：

```json
{
  "skill": "example-skill",
  "localFolder": "example-skill",
  "description": "这里写你本地定制后的 description",
  "usageRule": "## Usage Rule\n\n这里写你本地定制后的使用规则"
}
```

### 第四步：再同步本地 `SKILL.md`

最稳妥的做法是直接运行：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode apply-overrides -Only <skill>
```

说明：

- `skills-cli` 类型的 skill：更新后会自动回写 override，但你手动改了 override 以后，最好还是显式跑一次 `apply-overrides`
- `manual` 类型的 skill：不会经过上游更新，改完 override 后更应该显式跑 `apply-overrides`

---

## 修改已有 override 的建议

如果要改现有 override，建议这样做：

1. 先改 `local-routing-overrides.json`
2. 运行 `manage-skills.ps1 -Mode apply-overrides -Only <skill>`
3. 再跑一次 `manage-skills.ps1 -Mode check -Only <skill>`

不要只改 `SKILL.md` 而不改 override 文件。

因为那样下次更新时，旧 override 还是会把你的改动覆盖回去。

---

## 当前 override 主要服务哪些 skill

当前这份文件主要服务的是高冲突簇，例如：

- `extract-design`
- `html-ppt`
- `pptx`
- `pdf`
- `docx`
- `xlsx`
- `frontend-design`
- `canvas-design`
- `seo-audit`
- `schema-markup`
- `ai-seo`
- `deploy-to-vercel`
- `vercel-cli-with-tokens`
- `brainstorming`
- `writing-plans`
- `using-git-worktrees`
- `vercel-react-best-practices`
- `hv-analysis`
- `khazix-writer`

这些是因为它们之间存在真实触发冲突，才值得放进 override 系统。

---

## 和其他文件的关系

### `manage-skills.ps1`

- 负责读取这个 override 文件
- 对 `skills-cli` 类型：更新后自动回写本地规则
- 对 `manual` 类型：可通过 `-Mode apply-overrides` 手动回写
- 检查时：
  - `skills-cli` 按“磁盘上的真实本地文件” vs “上游 + override”来判断
  - `manual + override` 检查本地文件是否已经同步了 override

### `SKILL-ROUTING-RULES.md`

- 负责解释路由原则
- 不是实际回写来源

### 各个 `SKILL.md`

- 是最终落地文件
- 但不再是本地路由规则的唯一来源

换句话说：

- 真正应该优先维护的是 `local-routing-overrides.json`
- `SKILL.md` 是生成后的结果
- `check` 不等于回写；真正把规则落到磁盘上的是 `apply-overrides` 或 `update`

---

## 最后总结

以后如果你想保护某个 skill 的本地触发规则，记住这句就够了：

**不要只改 `SKILL.md`，要把规则写进 `local-routing-overrides.json`，然后跑一次 `apply-overrides`。**
