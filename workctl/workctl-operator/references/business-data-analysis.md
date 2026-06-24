# Business Data Analysis

用于店铺经营分析、日报/周报、流量/访客/商品/员工下钻。候选域：`data`，必要时联动 `communication`、`ads`、`default`。核心目标是少查 schema、少串行等待：只要同一时间窗下互不依赖，就用 `workctl batch call` 并行；分页列表用 `workctl collect`；只有需要上一步返回 ID、receipt、临时表名时才串行。

## 快速结论

- 店铺大盘、地域分布、员工汇总、商品榜单、访客列表、IM 店铺/账号诊断、广告账户诊断都可以共享同一时间窗并行查询。
- 商品列表、访客列表是分页命令，优先用 `workctl collect`，不要手写一页一页查询。
- 广告 SQL 是两段式：先 load datasource，再 execute sql；这组内部串行，但可和店铺大盘、商品、访客、员工等并行。
- 员工/商品/访客详情下钻通常是“先拿列表 ID，再按 ID 并行查详情”。不要在没拿到 ID 前猜参数。
- 输出只读 `success/data` 和 artifact 摘要；大结果用返回的 `next_action` 或 `workctl artifact get <artifact_id> --jq ...` 精确抽取。

## 意图路由

- 店铺大盘、日报、周报、GMV、UV、询盘、订单：先取经营汇总，同时并行补商品、地域、员工、沟通或广告。
- 流量地域、国家分布、市场机会：经营汇总、地域分布、多维访客筛选、商品效果可并行。
- 商品效果、商品诊断、链接质量：商品列表/Top/低质品用 `collect` 或 batch 多排序并行；商品详情、风险、广告加品建议依赖商品 ID 后再并行。
- 访客、买家、询盘质量：访客列表用 `collect`；国家、询盘访客、TM 访客等筛选可并行；会话消息依赖 conversationId 后再查。
- 员工/子账号表现：员工汇总、IM 账号诊断可并行；按员工下钻商品/访客时，先从员工数据拿 accountId/aliId，再并行查询。

## 推荐执行模型

1. 建立统一时间窗：优先在业务命令上用 `--time yesterday|last-7d|last-30d`；接口没有 `--time` 时再用显式 `startDate/endDate/queryDate`。
2. 一次性发现候选：`workctl schema data --recursive --limit 100 --format json`；跨域时再查 `communication`、`ads`。不要对每个猜测命令反复查 schema。
3. 只对将要执行的目标命令查 schema，确认必填、分页和时间字段。
4. 拆分依赖：
   - 无依赖只读：进入 batch 并行。
   - 分页列表：用 collect。
   - 有 ID/receipt/table 依赖：先跑前置命令，拿到值后再 batch 后续。
5. 生成报告前只抽取必要字段：Top 指标、异常项、同比/环比/同行对比、可行动建议。

## 可并行查询清单

| 场景 | 可并行命令 | 何时串行 |
|---|---|---|
| 店铺经营大盘 | `data-advisor-shop-summary`、`data-advisor-shop-region`、`data-advisor-account-summary`、`data-advisor-shop-product`、`data-advisor-visitor-detail`、IM 店铺诊断、广告账户诊断 | 若用户只问单一指标，可少查；广告 SQL 内部需要先 load 再 execute |
| 流量下降归因 | 汇总、地域分布、访客明细、商品曝光/点击榜、IM 店铺诊断、广告诊断 | 需要按某个国家/商品/员工继续下钻时，先拿对应 ID |
| 商品下钻 | 商品榜单、低质品、P4P 商品、点击率低商品、询盘高商品可以并行 | 商品详情/风险/买家行为必须等商品 ID |
| 员工下钻 | 员工汇总、IM 账号诊断可以并行 | 员工负责商品、员工访客筛选需要 accountId/aliId |
| 访客下钻 | 访客列表、有询盘访客、TM 访客、国家筛选访客可以并行 | 会话消息、卡片详情依赖 conversationId/card 信息 |
| 广告分析 | 广告账户诊断可和经营数据并行 | `icbu-ads-report-execute-sql` 依赖 `icbu-ads-report-load-datasource` |

## 店铺经营并行模板

适合“帮我分析店铺经营情况 / 近 7 天经营诊断 / 为什么流量下降”。先确认当前 schema 中命令存在，然后生成 batch spec。`batch call` 里不能写命令行 `--time`，需要把时间窗展开成显式字段：

```json
{
  "steps": [
    {
      "name": "shop_summary_7d",
      "path": "data.data-advisor-server.data-advisor-shop-summary",
      "params": {"statisticsType": "7d"}
    },
    {
      "name": "region_business_7d",
      "path": "data.data-advisor-server.data-advisor-shop-region",
      "params": {"statisticsType": "day", "startDate": "<startDate>", "endDate": "<endDate>", "dimensionType": "total_bus_cnt", "terminalType": "TOTAL"}
    },
    {
      "name": "account_summary_7d",
      "path": "data.data-advisor-server.data-advisor-account-summary",
      "params": {"statisticsType": "day", "startDate": "<startDate>", "endDate": "<endDate>"}
    },
    {
      "name": "top_products_by_views",
      "path": "data.data-advisor-server.data-advisor-shop-product",
      "params": {"statisticsType": "day", "statDate": "<endDate>", "orderBy": "views", "orderModel": "DESC", "pageNo": 1, "pageSize": 10}
    },
    {
      "name": "top_products_by_inquiries",
      "path": "data.data-advisor-server.data-advisor-shop-product",
      "params": {"statisticsType": "day", "statDate": "<endDate>", "orderBy": "inquiries", "orderModel": "DESC", "pageNo": 1, "pageSize": 10}
    },
    {
      "name": "visitor_inquiry_7d",
      "path": "data.data-advisor-server.data-advisor-visitor-detail",
      "params": {"startDate": "<startDate>", "endDate": "<endDate>", "isMcFb": true, "orderBy": "visitPv", "orderModel": "desc", "pageNO": 1, "pageSize": 20}
    }
  ]
}
```

执行：

```bash
workctl batch call --file store-analysis-batch.json --format json
```

读取摘要：

```bash
workctl artifact get <artifact_id> --jq '.results[] | {name, success}' --format json
workctl artifact get <artifact_id> --jq '.results[] | select(.name=="shop_summary_7d") | .output.data' --format json
```

如果某一步因必填时间失败，再补 `startDate/endDate/statDate/queryDate`，不要用同一错误入参盲重试。

## 商品下钻

先拿商品列表，再决定是否继续查详情。列表型查询优先：

```bash
workctl collect data.data-advisor-server.data-advisor-shop-product \
  --params '{"statisticsType":"day","orderBy":"views","orderModel":"DESC","pageSize":50}' \
  --max-pages 3 \
  --max-items 100 \
  --dedupe-by id \
  --format json
```

常用并行切片：

- `orderBy=views`：曝光 Top。
- `orderBy=clicksRates` + `orderModel=ASC`：低点击率商品。
- `orderBy=inquiries`：询盘 Top。
- `prodLevel=低质品`：低质品清单。
- `p4pProd=Y`：投放商品效果。

这些切片互不依赖，可以放进同一个 batch。拿到 Top 商品 ID 后，若需要商品详情、质量分、风险词、广告推荐，再按 ID 组织第二个 batch。

## 访客下钻

访客列表是分页结果，用 collect：

```bash
workctl collect data.data-advisor-server.data-advisor-visitor-detail \
  --params '{"startDate":"<startDate>","endDate":"<endDate>","orderBy":"visitPv","orderModel":"desc","pageSize":50}' \
  --max-pages 5 \
  --max-items 200 \
  --dedupe-by visitorId \
  --format json
```

可并行筛选：

- `isMcFb=true`：有询盘访客。
- `isAtmFb=true`：有 TM 咨询访客。
- `buyerCountry=<country>`：指定国家。
- `buyerRegion=<region>`：指定大洲。
- `searchKeyword=<keyword>`：按偏好关键词。

会话消息、卡片信息、买家联系人等属于 ID 接力：先从访客或会话列表拿 `conversationId/toLoginId/cardTypeValue`，再并行查消息和卡片。

## 员工/子账号下钻

员工总览可直接查：

```bash
workctl data data-advisor-server data-advisor-account-summary --time last-7d --format json
```

可并行补充：

- `communication.icbu-im-server.list-seller-acct-dim-diag-data`：账号维度沟通诊断。
- `data-advisor-shop-product` 带 `aliId`：某员工负责商品表现。
- `data-advisor-visitor-detail` 带 `subMemberSeq`：某员工相关访客。

注意：`aliId/subMemberSeq` 必须来自员工汇总、用户指定或上游返回，不能猜。若用户问“哪个员工表现差”，先取员工汇总和 IM 账号诊断；若用户追问“这个员工负责哪些商品/访客”，再做第二轮并行下钻。

## 广告与沟通联动

广告账户诊断可和经营大盘并行：

```bash
workctl ads icbu-ads-ai-support icbu-ads-account-diagnosis --time last-7d --format json
```

广告明细 SQL 必须串行：

1. `icbu-ads-report-load-datasource` 加载临时表。
2. `icbu-ads-report-execute-sql` 对临时表跑多条 SQL。`sqlQueries` 本身支持多条聚合 SQL，优先用数组一次提交。

沟通诊断可和经营大盘并行，但 `queryDate/dateType/buyerType` 必填。用户问服务/回复率/询盘跟进时，至少并行查店铺维度和账号维度诊断。

## 输出规则

- 先说数据窗口和口径：如“近 7 天 / 数据参谋 T-2 / 店铺维度”。
- 先给结论，再给 3 到 5 条证据，不堆完整 JSON。
- 对每个异常给出可执行动作：商品优化、流量国家、员工跟进、广告诊断、沟通质量。
- 无数据时说明查询窗口和筛选条件，不编造指标。
- 指标变化必须有对比基准：同行均值、同行优秀、环比、同比或同周期。
