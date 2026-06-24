# Business CLI Roadmap

这些能力来自 seller-assistant skills 中反复出现的模式，适合后续沉淀进 `workctl`，减少每个业务 skill 重复写流程。

## 计划与发现

- `workctl plan <intent>`：根据 schema 和自然语言列候选命令、必填参数、风险等级、建议执行顺序。
- `workctl schema --search <keyword>`：本地搜索 command、summary、params、returns。
- `workctl schema --related <path>`：根据 registry workflow hints 找上游/下游命令。

## 流程校验

- `workctl flow validate <flow.json>`：验证跨命令 ID 接力、必填参数、写操作确认、dry-run/异步策略。
- ID provenance：在输出中标注关键 ID 来自哪个命令/字段，防止后续误用历史 ID。
- 域级 workflow hints：registry detail 声明 `requires`、`produces`、`workflow_state`、推荐上游/下游命令。

## 时间和分页

- 统一业务时间解析：把“昨天/近7天/上周/近30天”转换为日期、毫秒时间戳或 `statisticsType`，并内置窗口限制。
- 统一分页拉取：按 schema pagination hints 自动翻页、限量、去重、输出 artifact。
- 大结果 selector 建议：根据 output schema 自动推荐 `--jq`。

## 异步和恢复

- 统一异步任务：把业务 `requestKey/taskId` 和 CLI `batch_id` 打通。
- `workctl task attach`：把业务任务标识挂到本地 batch 管理。
- `workctl task resume`：自动选择 CLI batch 或业务查询命令恢复。

## 安全和错误

- 统一确认预览：对 `mutating/requires_yes` 命令生成摘要，并支持 dry-run 或本地参数预检。
- 业务错误规范化：将 `errorDTO/isSuccess=false/businessSuccess=false/status<0` 规范成 `error.reason/next_action/retry_policy`。
- 自动重试策略：按 `retryable`、错误类型、参数修复建议决定是否重试。
