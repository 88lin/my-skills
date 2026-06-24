# Schema And Dynamic Commands

## 命令面

静态命令：

```text
workctl auth login|logout|status|refresh|reset
workctl cache status|refresh|clean
workctl artifact get|list|stat|clean
workctl time resolve
workctl collect
workctl batch call
workctl task list|status|wait|attach
workctl workflow run
workctl memory outcome
workctl file inspect
workctl recovery last|get|history|plan|execute|finalize
workctl schema
workctl doctor
```

隐藏维护命令包括 `completion`、`auth`、`version`。`artifact` 虽然偏维护，但 Agent 需要在大结果收口时使用。

动态命令来自远端 registry，路径固定理解为：

```text
workctl <cli.command> <group> <cliName> [flags...]
```

schema path 支持点号，也支持按命令路径拆成空格参数。日常推荐点号写 schema，执行命令推荐空格路径：

```text
<command>.<group>.<action>
```

示例：

```bash
workctl schema communication.icbu-im-server.list-contact --format json
workctl schema communication icbu-im-server list-contact --format json
workctl communication icbu-im-server list-contact --format json
```

## 发现和查看参数

查看全部命令：

```bash
workctl schema --format json
```

查看一级或递归子树：

```bash
workctl schema communication --format json
workctl schema communication --recursive --limit 20 --format json
workctl schema --search '发品' --limit 10 --format json
workctl schema --related product.icbu-product-agent.infer-category --format json
```

查看单个命令 schema。默认是 Agent 执行所需的 compact 结构；需要完整契约时显式加 `--detail full`：

```bash
workctl schema communication.icbu-im-server.list-contact --format json
workctl schema communication.icbu-im-server.list-contact --detail full --format json
```

执行前从 schema 中确认：

- 命令说明和业务含义。
- 必填参数、类型、默认值。
- 是否 `supports_dry_run` / `supportsDryRun`。
- 是否敏感、`mutating` 或 `requires_yes`。
- 是否 `paginated`，以及 `page_param` / `limit_param` / cursor 等分页提示。
- 是否有异步/任务提示、`agent_hints.workflow_state`、`automation_hints`。
- compact schema 中的 `params`、`jq`、`returns`、`workflow`、`recommended_jq`；需要低频字段时再看 full schema。

## 输出格式和过滤

Agent 默认使用 JSON，并优先消费极简结果：

```bash
workctl schema --format json
workctl auth status --format json
workctl <command> <group> <action> --format json
```

默认读取原则：

- 成功：先读 `success` 和顶层业务字段。对象型业务结果会直接平铺到顶层；数组、字符串、数字等非对象结果才放在 `data`。
- 动态命令字段形态由业务决定，常见主字段可能是 `model`、`items`、`result`、`records` 等；不要强行假设 `.data` 一定存在。
- 如果同一命令在默认极简输出和完整 envelope 下字段位置不同，读取已保存结果时使用兼容 jq，例如 `(.model // .data.model)`、`(.taskId // .data.taskId)`。
- 失败：先读 `error.reason` 和 `error.next_action`。
- 同时检查业务 payload 中的失败信号，例如 `errorDTO`、`isSuccess=false`、`businessSuccess=false`、`ok=false`、`processResult=false`、`status<0`。
- 需要诊断时再加 `--debug` 或看 recovery。

命令行 `--jq/--fields` 在输出极简化之前执行，作用对象是完整 structured envelope，因此在线过滤通常从 `.data.*` 读取：

```bash
workctl schema --format json --jq '.data.products[]'
workctl schema --format json --fields path,summary
```

### `--output` 与保存文件

`--output` / `-o` 表示“把完整结果写入文件”，显式保存时不会自动删 `meta`，也不会触发默认大结果压缩。路径必须解析后仍在当前工作目录内，并且父目录必须已存在。

保存默认极简 stdout：

```bash
workctl <command> <group> <action> --format json <flags...> > result.json
```

只保存某个业务字段：

```bash
workctl <command> <group> <action> --format json --jq '(.model // .data.model)' --output result.json <flags...>
```

保存完整 envelope 供排障：

```bash
workctl <command> <group> <action> --format json --output result.json <flags...>
```

如果看到 `create output file ... no such file or directory`，先创建父目录再重试。

### 大结果和 artifact

未显式 `--output` 时，Agent 默认输出会自动收口大结果。若返回 `data.truncated=true`，按返回中的 `data.next_action` 执行，或从 `data.jq` 选择真实 selector 精确读取；不要把完整 artifact 读进上下文。大结果收口本身仍使用 `data` 容器，因为返回的是 artifact 摘要而不是业务对象。

常用命令：

```bash
workctl artifact get <artifact_id> --jq '<expr>' --format json
workctl artifact list --limit 20 --format json
workctl artifact stat <artifact_id> --format json
workctl artifact clean --expired --format json
```

### 时间、分页、批量

时间类命令优先用动态命令隐藏 `--time`：

```bash
workctl data data-advisor-server data-advisor-shop-summary --time last-7d --format json
```

需要显式字段时再解析：

```bash
workctl time resolve --profile data-advisor --preset last-7d --format json
```

分页采集：

```bash
workctl collect <product.group.action> --params '{"pageSize":50}' --max-pages 10 --max-items 500 --format json
```

多只读命令 fan-out：

```bash
workctl batch call --file batch.json --format json
```

batch spec：

```json
{
  "steps": [
    {"name": "step_a", "path": "product.group.command-a", "params": {}},
    {"name": "step_b", "path": "product.group.command-b", "params": {}}
  ]
}
```

`batch call` 并行执行所有只读步骤，返回 `artifact_id/summary/failed/next_action`。它不会自动把某一步输出传给另一步；有依赖的 ID 先单独取出，再生成 batch spec。

## 执行业务命令

推荐流程：

```bash
workctl schema <command.group.action> --format json
workctl <command> <group> <action> --format json <flags...>
```

如果 schema 显示支持 dry-run：

```bash
workctl <command> <group> <action> --dry-run --format json <flags...>
```

写入、发送、删除、授权变更等高影响命令，先向用户展示：

- 将执行的命令路径。
- 目标对象和关键参数。
- 影响范围。
- 是否支持 dry-run 以及 dry-run 结果。

取得明确确认后再执行真实命令。

### 长任务和恢复

全局异步 flags：

```bash
workctl <command> <group> <action> --async --format json <flags...>
workctl <command> <group> <action> --wait --poll-interval 5s --wait-timeout 30m --format json <flags...>
```

提交后如果返回本地 batch：

```bash
workctl task list --format json
workctl task status <batch_id> --format json
workctl task wait <batch_id> --format json
```

业务工具只返回 `taskId/requestKey`、但未声明 async metadata 时，可以挂载：

```bash
workctl task attach \
  --task-id <task_id> \
  --poll-command <product.group.poll-action> \
  --poll-id-param taskId \
  --status-path '$.data[0].status' \
  --format json
```

有些业务工具返回自己的 `requestKey` / `taskId`，需要继续调用同域查询命令；只使用当前流程上游返回的 ID，不要从历史会话或用户口述补任务 ID。

### Agent Hints

`--detail full` 可能包含面向 Agent 的提示：

- `agent_hints.preflight_checks`：本地执行前必须满足的参数、枚举、流程约束。
- `agent_hints.normalized_output.recommended_jq`：优先使用的结果抽取方式。
- `agent_hints.workflow_state.produces`：本命令会产出的下游 ID 或阶段状态。
- `automation_hints.confirmation_required`：是否需要确认。

这些 hint 优先级高于旧 skill 文档中的硬编码示例；但如果 hint 与 `--help`/schema 参数冲突，以当前 schema/help 为准。

## 动态加载模型

动态命令加载顺序：

1. `GET /discovery/cli/schema?clientName=workctl`
2. `GET /registry/detail?domainName=...`
3. `POST /tools/call`

概念边界：

- `cli.command` 是 CLI 导航根，不是后端路由域。
- `domainName` 是 backend routing domain。
- 多个 domain 可以共享一个 top-level CLI root。
- 唯一性只要求最终归一化叶子路径 `command.group.action` 唯一。

如果 discovery 报 `reason=catalog_surface_conflict`，说明合并后的 CLI 命令树存在路径冲突。
