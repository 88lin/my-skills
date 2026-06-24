---
name: workctl
description: 管理 Work Agent 平台能力。通过 `workctl schema` 发现动态产品和命令，再用结构化输出执行操作。
cli_version: ">=0.1.28"
---

# Work Agent CLI Skill

通过 `workctl` 命令管理 Work Agent 平台能力。

## 首次使用 — 安装与就绪检查 (BOOTSTRAP)

每次会话首次使用 workctl 前，必须按以下顺序检查就绪状态：

### Step 1: 检查 workctl 是否可用

```bash
workctl version --format json
```

如果返回 `command not found` 或类似错误，执行安装：

```bash
npm install -g @accio-ai/cli@latest
```

安装完成后重新执行 `workctl version --format json` 验证。

### Step 2: 检查认证状态

```bash
workctl auth status --format json
```

如果返回 `authenticated: false` 或 `auth_not_found`：

```bash
workctl auth login --provider alibaba --format json
```

### Step 3: 检查命令发现缓存

```bash
workctl cache status
```

如果缓存状态为 `stale` 或命令数为 0：

```bash
workctl cache refresh
```

**只有三步都通过后，才可以执行业务命令。**

## CLI 版本与升级

当 `workctl version --format json` 返回的版本低于本 Skill 要求的 `cli_version` 时，执行升级：

```bash
npm install -g @accio-ai/cli@latest
```

升级后缓存会自动清除（postinstall 行为），无需手动清理。

## 严格禁止 (NEVER DO)

- 不要使用 workctl 命令以外的方式操作（禁止 curl、HTTP API、浏览器）
- 不要编造 UUID、ID 等标识符，必须从命令返回中提取
- 不要猜测字段名/参数值，操作前必须先查询确认
- 不要跳过 BOOTSTRAP 步骤直接执行业务命令

## 严格要求 (MUST DO)

- 所有命令必须加 `--format json` 以获取可解析输出
- 危险操作必须先向用户确认，用户同意后才加 `--yes` 执行
- 单次批量操作不超过 30 条记录
- 所有命令参数和参数值之间至少用一个空格隔开

## 发现可用命令

```bash
# 查看所有产品
workctl schema

# 查看某个命令的完整参数
workctl schema <product>.<group>.<command> --format json

# 示例
workctl schema messaging.thread.list --format json
workctl schema directory.user.search --format json
```

## 命令使用流程

### 1. 查看产品列表
```bash
workctl schema
```

### 2. 查看工具参数
```bash
workctl schema <product>.<group>.<command> --format json
```

### 3. 预览命令（不执行）
```bash
workctl <product> <group> <command> --dry-run --format json
```

### 4. 执行命令
```bash
workctl <product> <group> <command> --format json
```

## 危险操作确认

以下操作为不可逆或高影响操作，执行前**必须先向用户展示操作摘要并获得明确同意**。

判断依据：
- `schema` / `--format json` 返回 `requires_yes=true`
- 或者命令返回的 `meta.mutating=true` 且存在明显不可逆行为

### 确认流程
```
Step 1 → 展示操作摘要（操作类型 + 目标对象 + 影响范围）
Step 2 → 用户明确回复确认（如 "确认" / "好的"）
Step 3 → 加 --yes 执行命令
```

## 错误处理

```bash
# command not found → 执行 BOOTSTRAP Step 1 安装
# auth_not_found / 401 → 执行 BOOTSTRAP Step 2 认证
# registry 不可用 → workctl cache refresh

# 如果命令报错，先查看 --help
workctl <product> <group> <command> --help

# 如果参数不确定，先查 schema
workctl schema <product>.<group>.<command> --format json

# 如果 registry 不可用，检查配置
workctl cache status
workctl auth status
```

## 输出格式

所有命令默认输出 table 格式。agent 应始终使用 `--format json`：

```bash
# JSON 输出（推荐 agent 使用）
workctl <product> <group> <command> --format json

# jq 过滤
workctl <product> <group> <command> --format json --jq '.items[].name'

# 字段选择
workctl <product> <group> <command> --format json --fields name,id

# 输出到文件
workctl <product> <group> <command> --format json -o result.json
```

如果 JSON 返回被自动收口，输出会包含 `meta.agent_friendly.large_result=true`、`field_index`、`suggested_selectors` 和 `data.artifact_id`。这时不要读取整段大 JSON，先按建议 selector 取局部数据：

```bash
workctl artifact get <artifact_id> --format json --jq '.data.items[0]'
```
