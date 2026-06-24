# Recovery And Troubleshooting

## Cache

查看缓存：

```bash
workctl cache status
```

刷新 discovery/detail metadata：

```bash
workctl cache refresh
```

清理缓存：

```bash
workctl cache clean
```

`cache clean` 只清 registry/schema 缓存，不清认证状态。

## Recovery

先跑环境诊断：

```bash
workctl doctor --format json
```

`workctl` 会持久化失败快照，并提供恢复流程：

```bash
workctl recovery last --format json
workctl recovery history --limit 20 --format json
workctl recovery get <event-id> --format json
workctl recovery plan --last --format json
workctl recovery execute --last --format json
workctl recovery finalize --event-id <id> --outcome recovered --format json
```

`plan` 用于分类失败并生成恢复计划；`execute` 生成 replay/recovery 分析包；`finalize` 关闭生命周期。

## 常见问题处理

`command not found`：

```bash
npm install -g @ali/work-agent-cli --registry=https://registry.anpm.alibaba-inc.com
workctl version --format json
```

认证缺失或 401：

```bash
workctl auth status --format json
workctl auth login
workctl auth refresh
```

schema 缺失、缓存过期、动态命令不存在：

```bash
workctl cache status
workctl cache refresh
workctl schema --format json
workctl schema <command.group.action> --format json
```

参数或字段不确定：

```bash
workctl schema <command.group.action> --format json
workctl <command> <group> <action> --help
```

长任务中断：

```bash
workctl task list --format json
workctl task status <batch_id> --format json
workctl task wait <batch_id> --format json
```

如果业务返回的是 `requestKey` / `taskId` 而不是 CLI batch，回到对应命令 schema 查结果查询命令；不要复用历史会话里的任务 ID。

需要恢复刚才的大结果：

```bash
workctl artifact list --limit 20 --format json
workctl artifact stat <artifact_id> --format json
workctl artifact get <artifact_id> --jq '<expr>' --format json
```

不要默认读取完整 artifact；先用 `stat/list` 找到目标，再按字段精确读取。

`--output` 写文件失败：

- `create output file ... no such file or directory`：父目录不存在，先 `mkdir -p <dir>`。
- `--output` 会保存完整 envelope；若只要某个业务字段，使用 `--jq '<expr>' --output result.json`。
- 若想保存默认极简 JSON，用 stdout 重定向：`workctl ... --format json > result.json`。

字段取不到：

- 默认 JSON 可能已经把对象型业务结果平铺到顶层，例如读 `.model`、`.items`、`.result`。
- `--output` 保存的完整文件可能仍是 envelope，例如同一字段在 `.data.model`。
- 写自动化脚本时优先用兼容 jq：`(.model // .data.model)`、`(.taskId // .data.taskId)`、`(.checkResult // .data.checkResult)`。

registry 路径冲突：

- 错误通常包含 `catalog_surface_conflict`。
- 检查所有 domain 归一化后的 `command.group.action` 是否重复。
- 调整 `cli.command`、`group` 或 `cliName`，不要改成依赖后端 `domainName` 解决展示层冲突。

## Exit Code 分类

常见分类：

- `0`：成功。
- `10-13`：API / transport / JSON-RPC / business error。
- `20-25`：auth failure、missing auth config、invalid auth state、auth not found。
- `30-43`：validation failure、unknown flag/command、missing required parameter、schema path 问题、recovery selector 问题。
- `50-51`：discovery / catalog load failure。
- `70`：unexpected internal error。

处理策略：

- Auth 类先看 `auth status`、登录环境变量和 token。
- Validation 类先看 `schema <path> --format json` 和 `--help`。
- Discovery 类先 `cache refresh`，再检查 registry 协议和命令路径冲突。
- API 类保留 `traceId`、`code`、`category`、`retryable`，再判断是否重试或升级给服务端。
