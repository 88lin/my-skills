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
      "usageRule": "## Usage Rule\n..."
    }
  ]
}
```

每个 override 主要有 4 个字段：

- `skill`
  - skill 名称
- `localFolder`
  - 本地目录名
- `description`
  - 要覆盖进 frontmatter 的 description
- `usageRule`
  - 要写回 `SKILL.md` 的 `## Usage Rule` 段落

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
