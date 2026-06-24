# Business Creative Storefront

用于图片生成、视频生成、店铺装修、网站创建、编辑和发布。候选域：`product.icbu-ai-image-agent`、`icbu.icbu-ai-video-agent`、`storefront`。

## 图片生成顺序

1. 判断能力类型：场景图、换色、Logo、模特图、翻译、去背景/水印等。
2. 校验图片 URL、prompt、能力 code、目标语言、色卡等必填字段。
3. 发起生成命令，保存 `requestKey` 或任务标识。
4. 优先用 `--wait --poll-interval ... --wait-timeout ...`；若只返回业务 `requestKey`，用结果查询命令或 `task attach` 恢复。
5. 展示结果 URL、失败原因或下一步恢复命令。

## 视频生成顺序

1. 校验商品图片和视频描述 prompt。
2. 查 schema，确认使用 v1/v2 或风格生成能力。
3. 发起视频任务。
4. 优先 `--wait`；需要后台继续时用 `--async` 后 `task wait/status`，超时返回任务标识和恢复命令。
5. 输出视频 URL 和生成状态。

## 店铺装修顺序

1. 区分创建、编辑、发布、恢复版本、查询模板/页面。
2. 创建前先获取公司信息、模板、页面上下文或用户素材；互不依赖的只读上下文用 batch 并行读取。
3. 编辑前先获取页面/版本，明确云端/本地路径。
4. 创建预览或完整页面后优先用 `--wait` 或 `task wait` 查询任务状态。
5. 发布前展示页面、版本、范围、是否可回滚；用户确认后执行。

## 注意事项

- 生成类工具通常是长任务：优先 `--wait` 或业务结果查询命令。
- 多张图、多段视频、多页面只读上下文能并行时用 `batch call`，不要逐个串行查。
- `requestKey`、页面 ID、版本 ID、token 必须来自当前工具返回或用户明确输入。
- 不要用通用图片生成替代有账号态/商品态的业务能力。
- 发布类命令即使 summary 没写 mutating，只要 `requires_yes=true` 也必须确认。
