# Auth And Env

## 当前测试登录模型

测试阶段先把 `workctl auth login` 当成“打开本地登录态”的动作，不要求真实业务鉴权。

```bash
workctl auth login --provider alibaba --format json
workctl auth status --format json
```

期望状态：

```json
{
  "authenticated": true,
  "provider": "alibaba",
  "success": true
}
```

如果需要重置：

```bash
workctl auth logout --provider alibaba --format json
workctl auth login --provider alibaba --format json
workctl auth status --format json
```

Agent 不需要处理真实 token，也不要引导用户配置 OAuth、device flow 或手写 token。

## 严格鉴权模式

只有在明确需要验证真实鉴权链路时，才开启严格模式：

```bash
WORKCTL_AUTH_STRICT=true workctl auth login --provider alibaba --debug --format json
```

严格模式会要求 auth proxy 返回真实 `access_token`。如果失败，优先看 `error.reason` 和 `RECOVERY_EVENT_ID`，不要把测试登录问题误判为业务命令不可用。

## Runtime 变量

常规 Agent 调用一般不需要设置环境变量。

排查集成链路时可关注：

- `WORKCTL_AUTH_STRICT=true`：关闭测试 token fallback，要求真实鉴权。
- `WORKCTL_AUTH_BACKEND_URL`：指定 auth backend。
- `GATEWAY_PORT`：指定本地 Accio gateway 端口。
- `ACCIO_GATEWAY_TOKEN`：本地 gateway Basic auth 密码。
- `WORKCTL_CONFIG_DIR`：隔离本地配置目录。

平台集成方可以注入：

- `WORKCTL_TRACE_ID`：转发为 `X-Trace-Id`。
- `WORKCTL_MESSAGE_ID`：`WORKCTL_TRACE_ID` 的 legacy fallback。
- `WORKCTL_SOURCE`：转发为 `X-Source`。
- `WORKCTL_METADATA`：JSON 字符串，转发为 `X-Metadata`。

`WORKCTL_METADATA` 必须是合法 JSON；非法值会被忽略。
