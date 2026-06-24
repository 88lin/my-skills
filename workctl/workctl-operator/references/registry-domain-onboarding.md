# Registry Domain Onboarding

用于为新业务域接入 `workctl`，或排查 discovery/detail/tools/call 协议问题。

## 当前协议

`workctl` 当前只支持远端服务接入，不再支持本地 `auto_cli` provider 作为官方运行时。

固定三段式：

```http
GET /discovery/cli/schema?clientName=workctl
GET /registry/detail?domainName=...
POST /tools/call
```

对于 `callType=mcp`，执行入口可以是远端 MCP endpoint，但 discovery 和 detail 仍然必须按上述 HTTP 协议暴露。

## Discovery 要点

响应顶层：

```json
{
  "success": true,
  "result": {
    "version": "2026-04-10",
    "servers": []
  }
}
```

每个 server 至少包含：

```json
{
  "server": {
    "domainName": "communication",
    "callType": "api",
    "callUrl": "https://open.example.com/tools/call",
    "detailUrl": "https://open.example.com/registry/detail?domainName=communication"
  },
  "cli": {
    "command": "communication",
    "description": "Communication domain capabilities",
    "groups": {
      "contact": { "description": "Contact operations" }
    },
    "tools": {
      "GET_CONTACT_LIST": {
        "cliName": "get-contact-list",
        "group": "contact",
        "supportsDryRun": true,
        "paginated": true,
        "paginationType": "page",
        "pageParam": "pageNo",
        "limitParam": "pageSize",
        "idempotent": true,
        "protocolHints": ["read_only", "bounded_output"]
      }
    }
  }
}
```

命名规则：

- `domainName`：后端执行域主键，稳定、全局唯一、大小写敏感。
- `cli.command`：一级命令，面向用户和 agent，短、明确，建议 kebab-case。
- `group`：二级资源分组，如 `contact`、`project`、`query`。
- `cliName`：三级动作，kebab-case，如 `list`、`get`、`search`、`create`、`send`、`update`、`delete`。
- `toolName`：后端 canonical identity，执行时使用，必须稳定。

最终路径 `command.group.action` 归一化后必须唯一。

## Detail 要点

detail 入口：

```http
GET /registry/detail?domainName=communication
```

响应重点：

```json
{
  "success": true,
  "result": {
    "domainName": "communication",
    "name": "Communication",
    "description": "Communication domain capabilities",
    "tools": [
      {
        "toolName": "GET_CONTACT_LIST",
        "toolTitle": "Get contact list",
        "toolDesc": "List contacts from the current account",
        "isSensitive": false,
        "supportsDryRun": true,
        "actionVersion": "2026-04-10",
        "toolRequest": "{\"type\":\"object\",\"properties\":{\"aliId\":{\"type\":\"integer\"}},\"required\":[\"aliId\"]}",
        "toolResponse": "{\"type\":\"object\",\"properties\":{\"items\":{\"type\":\"array\",\"description\":\"Contact rows\"}}}"
      }
    ]
  }
}
```

`toolRequest` 和 `toolResponse` 必须是 JSON Schema 字符串。

## toolRequest 约定

参数名使用 camelCase，例如：

```json
{
  "properties": {
    "selfAliId": {
      "type": "Long",
      "description": "查询对象的 aliId"
    },
    "count": {
      "type": "Int",
      "description": "单次查询数量",
      "default": "100"
    }
  },
  "required": ["selfAliId"]
}
```

CLI 会把 camelCase 参数直接注册为 flag，例如 `--selfAliId`，并为 camelCase 自动注册 kebab-case alias。

List/Array/Object 类型的参数用 JSON 字符串传入：

```bash
workctl im message send --receiverAliID '[123,456]' --format json
workctl product query search --filter '{"status":"active"}' --format json
```

## toolResponse 约定

`toolResponse` 只描述 `result.data` 层的业务字段，不要包含协议层字段 `success`、`errorCode`、`errorMsg`。

推荐结构：

```json
{
  "properties": {
    "items": {
      "type": "array",
      "description": "结果列表。每项包含 id、name、status"
    },
    "hasMore": {
      "type": "boolean",
      "description": "是否有下一页"
    },
    "nextCursor": {
      "type": "string",
      "description": "下一页游标"
    }
  }
}
```

字段名必须和执行响应里的业务字段对齐。默认 Agent 输出会把对象型业务结果平铺到顶层，因此列表字段通常读 `.items[]`；完整 envelope 或数组型结果才从 `.data.*` 读取。面向脚本可给出兼容路径，例如 `(.items // .data.items)[]`。

当前 `ir.Property` 不支持嵌套 fields；列表项关键子字段应写进 description。

## Execution 要点

`callType=api` 的请求：

```json
{
  "method": "tools/call",
  "params": {
    "domainName": "communication",
    "name": "GET_CONTACT_LIST",
    "arguments": {
      "aliId": 1,
      "pageNo": 1,
      "pageSize": 20
    },
    "requestId": "req-123"
  }
}
```

响应：

```json
{
  "success": true,
  "result": {
    "items": [],
    "nextCursor": ""
  },
  "message": "",
  "code": 0,
  "category": "",
  "retryable": false,
  "traceId": "trace-123"
}
```

`success=false` 时也使用同一响应外壳，并提供可读 `message`、`code`、`category`、`retryable`、`traceId`。

## 联调检查

源码或原始二进制调试时：

```bash
export WORKCTL_MCP_URL=https://open.example.com/discovery/cli/schema?clientName=workctl
workctl schema --format json
workctl schema communication.contact.get-contact-list --format json
```

npm 包会忽略外部 `WORKCTL_MCP_URL`，不能用它做 registry override。

优先排查：

- discovery 是否顶层包裹 `success/result`。
- `domainName` 是否与 detail 对齐。
- detail 是否仍在使用旧 `mcpId`。
- `toolRequest` / `toolResponse` 是否为合法 JSON Schema 字符串。
- `callUrl` 是否可达，且与 `callType` 匹配。
- 归一化叶子路径是否冲突。
