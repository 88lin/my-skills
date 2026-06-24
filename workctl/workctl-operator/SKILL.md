---
name: workctl-operator
description: |
  安装、升级、认证、发现并使用 Work Agent CLI (`workctl`)。适用于通过 `workctl schema` 发现并调用阿里巴巴国际站商家经营工具，处理店铺经营数据、广告、发品、商品优化、AI 图片/视频、旺铺、选品、物流、交易、IM、知识问答、深度研究等场景。

  也适用于配置 workctl、登录认证、排查 token/cache/schema/runtime/async task/recovery 问题，编排多个 workctl 工具，或为新业务域接入 registry/discovery/detail/tools/call 协议。执行业务命令时必须以当前 `workctl schema` 和 `workctl <command> --help` 为准，不照搬旧 MCP/CLI 命令。
metadata:
  short-description: Use workctl for Alibaba.com seller operations
---

# Workctl Operator

使用 `workctl` 管理 Work Agent 平台能力。默认相信 CLI 已做 Agent-Friendly 收口：成功输出尽量极简，失败输出只给可执行修复动作，大结果自动落 artifact。不要在 skill 里重复写 CLI 内部策略。

## 快速流程

1. 确认 CLI 和测试登录态：
   ```bash
   workctl version --format json
   workctl auth login --provider alibaba --format json
   workctl auth status --format json
   ```
2. 发现命令，先搜再看 schema：
   ```bash
   workctl schema --search '<关键词>' --limit 10 --format json
   workctl schema <product.group.action> --format json
   ```
3. 执行业务命令：
   ```bash
   workctl <product> <group> <action> --format json <flags...>
   ```
4. 多个互不依赖的只读查询不要逐条串行跑，生成 batch spec 后用：
   ```bash
   workctl batch call --file batch.json --format json
   ```
5. 写操作、发送消息、投广告、发布/编辑商品前，先展示对象、影响范围和关键参数，得到明确确认后再执行。

## 并行和异步策略

- 先画依赖：只有 token、receipt、categoryKey、taskId 这类上游 ID 必须串行；拿到 ID 后，后续只读查询尽量 `batch call` 并行。
- 报表、诊断、商品/流量/转化/IM/物流等只读 fan-out，优先生成一个临时 batch JSON；结果统一落 artifact，再用 `artifact get --jq` 精确读取。
- 生成、发品、图片、视频、建站等长任务，优先 `--wait --poll-interval ... --wait-timeout ...`；需要后台提交时用 `--async`，再 `task status/wait` 恢复。
- CLI 当前 `batch call` 不做步骤间变量引用；有依赖的前置步骤先在 batch 外执行，或用 `workflow run` 顺序执行固定参数步骤。
- 避免 Agent 自己开多个 shell 后台进程、手写 sleep/while 或把多个大 JSON 读进上下文。

## Agent 读取规则

- 成功：优先读顶层业务字段和 `success`；对象型业务结果通常已平铺，数组/字符串才放在 `data`。
- 失败：优先读 `error.reason` 和 `error.next_action`；不要盲目重试同一入参。
- 动态命令返回形态可能是 `model/items/result/records/data`，不要假设一定有 `.data`。
- `--jq/--fields` 作用于完整 structured envelope；在线过滤常从 `.data.*` 读，读默认 stdout 时先看顶层字段。
- `--output` 保存完整结果，可能保留 `meta`；想保存极简结果用 shell 重定向，想保存字段用 `--jq ... --output`。
- 大结果若返回 `truncated=true`，只按 `next_action` 用 `workctl artifact get <artifact_id> --jq '<expr>' --format json` 精确取字段，不要读取完整 artifact 进上下文。
- 时间类命令优先用业务命令的 `--time <preset>`；不确定字段时用 `workctl time resolve`。
- 分页读数优先用 `workctl collect`，多只读命令并行取数优先用 `workctl batch call`。
- 长任务优先用 `--async/--wait` 或 `workctl task attach/status/wait`，保留当前流程返回的 `taskId/requestKey/batch_id`。

## 何时读 reference

- 安装、升级、首次就绪检查：读 [install-and-bootstrap.md](references/install-and-bootstrap.md)。
- 登录、测试鉴权、配置目录、trace/audit 环境变量：读 [auth-and-env.md](references/auth-and-env.md)。
- 查询可用命令、查看参数、执行动态命令、解析输出：读 [schema-and-dynamic-commands.md](references/schema-and-dynamic-commands.md)。
- 业务域工具编排、跨工具组合、当前 Alibaba seller-assistant 场景迁移：先读 [business-tool-composition.md](references/business-tool-composition.md)，再按业务读取下方专门 reference。
- 新业务域接入 discovery/detail/tools/call：读 [registry-domain-onboarding.md](references/registry-domain-onboarding.md)。
- 报错、缓存、恢复流程、exit code：读 [recovery-and-troubleshooting.md](references/recovery-and-troubleshooting.md)。

## 业务 reference

- 店铺经营、数据分析、员工/商品/访客下钻：读 [business-data-analysis.md](references/business-data-analysis.md)。
- 广告诊断、广告报表、品牌广告关键词、加品删品：读 [business-ads-marketing.md](references/business-ads-marketing.md)。
- 商品发布、商品查询、商品信息优化、批量编辑：读 [business-product-publish.md](references/business-product-publish.md)。
- 图片/视频生成、店铺装修、网站创建/编辑/发布：读 [business-creative-storefront.md](references/business-creative-storefront.md)。
- 热品洞察、蓝海机会、1688/供应商/分销找品：读 [business-market-sourcing.md](references/business-market-sourcing.md)。
- 物流运费、关税、交易、拒付、店铺/商品风险：读 [business-logistics-trade-risk.md](references/business-logistics-trade-risk.md)。
- IM 会话、客服诊断、买家回复、知识问答、深度研究：读 [business-communication-knowledge.md](references/business-communication-knowledge.md)。
- 想评估哪些通用能力应沉淀进 CLI：读 [business-cli-roadmap.md](references/business-cli-roadmap.md)。

## 操作原则

- 不猜命令路径、参数名、字段名；先 schema，再执行。
- 从旧 skill/旧 MCP 文档迁移时，只迁移业务意图和 ID 接力模式；命令、flag、字段重新查。
- 写操作先确认，能 dry-run 就先 dry-run。
- 只使用当前流程上游返回或用户明确提供的 ID，不从历史会话补 ID。
- 排障时先 `doctor/auth login/auth status/schema`，再看 recovery。
- 当前官方安装面是 npm 内网包；源码/原始二进制调试变量不是常规用户配置。

## 本仓库权威文档

当前行为以 `raw/cli/README.md`、`raw/cli/docs/reference.md`、`raw/cli/docs/environment-variables.md`、`raw/cli/docs/registry/README.md` 和代码为准。历史设计稿、旧 provider 文档、旧包名或旧鉴权参数不要作为现行契约。
