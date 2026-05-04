# 旧 Skills 体检

结论先说：你当前这套旧 skills 没有必须马上删除的项，整体结构是健康的。现在更适合“保持现状、明确边界”，而不是为了看起来精简就大规模删改。

## 建议保留，继续自动更新

- `systematic-debugging`：调 bug 的前置方法论，适合继续保留并自动更新。
- `test-driven-development`：做功能或修复缺陷时很有价值，适合继续保留。
- `verification-before-completion`：它是你这套流程里的质量闸门，必须保留。
- `web-access`：独立 git 仓库，联网和浏览器能力关键，建议持续更新。
- `mindos-zh`：跨会话知识沉淀能力独特，没有本地替代，建议保留。
- `karpathy-guidelines`：约束改动范围、减少乱改和过度设计，建议保留。
- `writing-plans`：轻量计划 skill，和复杂规划体系不冲突，建议保留。
- `using-git-worktrees`：隔离工作区能力明确，建议保留。
- `seo-audit` / `schema-markup` / `ai-seo`：职责清晰，适合持续自动更新。
- `find-skills` / `extract-design` / `health`：都属于专项工具型 skill，建议保留。
- `mcp-builder`：虽然上游也有同名 skill，但你当前这版更贴近中文工作流，建议保留当前来源。
- `html-ppt`：定位清晰，适合网页演示稿，已纳管自动更新，建议保留。

## 建议保留，继续 manual

- `frontend-design`：你当前这版已经基于 Anthropic 做过本地增强，不适合盲目覆盖。
- `adapt`：本地定制成分高，直接覆盖风险大。
- `animate`：本地定制成分高，直接覆盖风险大。
- `audit`：本地定制成分高，直接覆盖风险大。
- `clarify`：本地定制成分高，直接覆盖风险大。
- `critique`：本地定制成分高，直接覆盖风险大。
- `delight`：本地定制成分高，直接覆盖风险大。
- `distill`：本地定制成分高，直接覆盖风险大。
- `harden`：本地定制成分高，直接覆盖风险大。
- `optimize`：本地定制成分高，直接覆盖风险大。
- `polish`：本地定制成分高，直接覆盖风险大。
- `teach-impeccable`：本地定制成分高，直接覆盖风险大。
- `typeset`：本地定制成分高，直接覆盖风险大。

## 可以后续再观察的重叠点

- `writing-plans` 和更重型的规划体系有重叠，但你已经把定位分开了，现在先保留。
- 设计链 skill 数量很多，但这是你有意识拆出来的，不建议为了“目录更干净”而删掉。
- `deploy-to-vercel` 与 `vercel-cli-with-tokens` 不冲突，一个偏部署流程，一个偏 CLI 认证和细节操作。
- `pptx`、`html-ppt`、`ppt-master` 都碰演示文稿，但输出格式不同，不属于简单重复，建议按场景分工，不要删。

## 当前不建议做的事

- 不建议把 `frontend-design` 直接换成 Anthropic 原版。
- 不建议把 `mcp-builder` 直接换成 Anthropic 原版。
- 不建议批量删除低频 skill，除非你明确感觉触发噪音已经影响日常使用。

## 这次体检的实际结论

- 现在最合理的状态是：旧 skill 基本不动，新 skill 负责补位。
- 你这次新装的 `webapp-testing`、`pdf`、`xlsx`、`skill-creator`、`docx`、`pptx`、`canvas-design`、`web-artifacts-builder`，主要补的是旧体系里原本较弱的部分。
- 现在又补上了 `html-ppt` 和 `ppt-master` 这条演示文稿能力线。
- 所以下一步重点不是“删旧”，而是“把新 skill 用顺手”。
