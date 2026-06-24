# Business Tool Composition

本文件是业务编排总览，用于把 Alibaba seller-assistant skills 中沉淀的执行顺序、工具组合、校验方式迁移到 `workctl`。只迁移流程和组合策略；不要照搬旧 `accio-mcp-cli`、Python CLI 或 MCP 工具名。实际执行前一律重新查询：

```bash
workctl schema --format json
workctl schema <product.group.action> --format json
workctl <product> <group> <action> --help
```

## 通用编排模式

### 1. 发现优先

先用 `workctl schema --format json` 找可用 product，再用递归 schema 收窄候选：

```bash
workctl schema product --recursive --limit 100 --format json
workctl schema ads --recursive --limit 100 --format json
```

命中候选后再看单命令 schema，确认 `params`、`required`、`mutating`、`requires_yes`、`paginated`、`agent_hints`、`automation_hints`、`outputSchema`、`recommended_jq`。

### 2. 预检再执行

从 seller-assistant skills 里反复出现的稳定流程：

1. 意图路由：识别是查询、诊断、生成、发布、发送、删除，还是售后/风险。
2. 前置参数：时间、账号、商品 ID、订单 ID、国家、类目、图片 URL、素材文件等必须先齐。
3. schema 预检：参数名、类型、枚举、必填、分页、异步、写操作标记以 workctl 为准。
4. 数据获取：只读工具可直接执行；跨域只读数据尽量并行获取。
5. ID 接力：后续命令只能使用上游工具返回或用户原始输入的 ID，不要凭记忆补 ID。
6. 写操作确认：展示命令路径、对象、影响范围、关键参数、是否可恢复；用户明确同意后再执行。
7. 结果校验：同时看 CLI `success` 和业务 payload 中的 `errorDTO/isSuccess/businessSuccess/ok/processResult/status`。
8. 输出：只展示业务结论和必要证据，不暴露旧内部工具名；大结果按 `data.truncated/data.next_action/data.jq` 精确抽取。

### 3. 时间预检

涉及报表、IM、广告、店铺经营时，不要手算时间戳。优先使用业务命令的 `--time <preset>`；需要显式字段或排障时再用 `workctl time resolve`：

```bash
workctl data data-advisor-server data-advisor-shop-summary --time last-7d --format json
workctl time resolve --profile data-advisor --preset last-7d --format json
```

再对照 schema 的字段格式：

- 广告 report 常见 `yyyy-MM-dd HH:mm:ss`。
- IM 会话/消息可能需要毫秒时间戳，且存在最近窗口限制。
- 店铺经营类常见 `day/7d/30d`、`statisticsType`、分页字段。

如果时间窗口超出工具限制，先收缩、降级或追问；不要用同一错误时间反复重试。

### 4. 分页和大结果

schema 标记 `paginated=true` 或返回列表较大时，优先用 `workctl collect` 自动翻页、去重并落 artifact：

```bash
workctl collect <product.group.action> \
  --params '{"pageSize":50}' \
  --max-pages 10 \
  --max-items 500 \
  --format json
```

大结果被收口时，根据返回的 `data.next_action` 或 `data.jq` 读取需要字段。

### 5. 异步和轮询

生成图片、视频、发品、建站等常见两阶段或长任务：

1. 启动命令返回 `requestKey` / `taskId` / `batch_id`。
2. 优先用 `--wait --poll-interval <duration> --wait-timeout <duration>`，或 `--async` 提交后用 `workctl task wait` 恢复。
3. 工具只返回业务 `taskId/requestKey` 但没有 async metadata 时，用 `workctl task attach` 挂到本地任务管理；`status-path` 必须以真实查询结果为准。
4. 如果进程中断，先用 `workctl task list/status/wait` 查看本地 batch；业务自有 `taskId` 只能来自当前上游返回。
5. 轮询超时要返回当前任务标识和下一步恢复命令。

### 6. 多只读工具 fan-out

经营简报、广告诊断、商品分析这类场景通常要同时读多个只读工具。优先用 `workctl batch call`，不要在 skill 里手写多个临时文件和并行分支：

```bash
workctl batch call --file store-brief-batch.json --format json
```

推荐做法：

1. 先执行有依赖的前置步骤，例如获取 token、receipt、类目 key、任务 id。
2. 把后续互不依赖的只读命令写入 batch spec。
3. `batch call` 返回 artifact 后，只用 `artifact get --jq` 读取所需字段。

batch spec 只支持固定参数，不支持引用前一步输出：

```json
{
  "steps": [
    {
      "name": "weekly_report",
      "path": "crm.xianfumcp.list",
      "params": {
        "reportAllDataQry": {"receipt": "<receipt>"},
        "token": "<token>"
      }
    },
    {
      "name": "shop_summary_7d",
      "path": "data.data-advisor-server.data-advisor-shop-summary",
      "params": {"statisticsType": "7d"}
    }
  ]
}
```

读取结果：

```bash
workctl artifact get <artifact_id> --jq '.results[] | {name, success}' --format json
workctl artifact get <artifact_id> --jq '.results[] | select(.name=="weekly_report") | .output.values.reportAllData.STORE_DATA_OVERVIEW' --format json
```

如果用户追问多个周报模块，先用 `store-diagnose-brief` 拿 `encryptedReportId`，再把多个 `reportPageCode` 拆成多个只读步骤并行查；不要一次拉全量周报再把完整数据读入上下文。

### 7. 顺序 workflow

`workflow run` 适合固定参数的顺序步骤，失败即停并统一落 artifact。它当前不支持 `${steps.xxx}` 变量引用，因此不能替代“先拿 receipt 再传给周报查询”的完整 DAG。

适用：必须按顺序执行、但参数已经准备好的多个步骤。

不适用：需要把上一步输出自动注入下一步参数的复杂链路。遇到这种链路，先在 workflow 外拿 ID，再用 batch 并行后续只读步骤。

### 8. 错误恢复

本地参数错误先修输入；认证/缓存问题先走：

```bash
workctl doctor --format json
workctl auth status --format json
workctl cache refresh
```

上游业务错误保留 `traceId/code/category/retryable`。失败后不要用同一入参盲重试；先判断是缺参数、窗口限制、无数据、权限、业务校验，还是上游临时故障。

## 业务 reference 索引

按用户意图选择一份业务 reference，不要一次性加载全部：

- 店铺经营、数据分析、员工/商品/访客下钻：[business-data-analysis.md](business-data-analysis.md)
- 广告诊断、广告报表、品牌广告关键词、加品删品：[business-ads-marketing.md](business-ads-marketing.md)
- 商品发布、商品查询、商品信息优化、批量编辑：[business-product-publish.md](business-product-publish.md)
- 图片/视频生成、店铺装修、网站创建/编辑/发布：[business-creative-storefront.md](business-creative-storefront.md)
- 热品洞察、蓝海机会、1688/供应商/分销找品：[business-market-sourcing.md](business-market-sourcing.md)
- 物流运费、关税、交易、拒付、店铺/商品风险：[business-logistics-trade-risk.md](business-logistics-trade-risk.md)
- IM 会话、客服诊断、买家回复、知识问答、深度研究：[business-communication-knowledge.md](business-communication-knowledge.md)
- CLI 后续可沉淀的通用能力：[business-cli-roadmap.md](business-cli-roadmap.md)
