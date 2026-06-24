# Install And Bootstrap

## 安装面

当前官方支持的安装方式只有 npm。

内部 npm：

```bash
npm install -g @ali/work-agent-cli --registry=https://registry.anpm.alibaba-inc.com
workctl --help
```

公共 npm：

```bash
npm install -g work-agent-cli
workctl --help
```

安装内容：

- 下发 `workctl` CLI 本体。
- 下发 skills bundle 到支持的本地 agent home。
- 安装或升级后会清理 `~/.workctl/cache/`，让 discovery metadata 重新刷新。
- 不再附带本地 `auto_cli` provider。

## 首次就绪检查

按顺序执行：

```bash
workctl version --format json
workctl auth status --format json
workctl schema --format json
```

如果 schema 为空、缓存过期或 registry 状态异常：

```bash
workctl cache status
workctl cache refresh
workctl schema --format json
```

## 升级

使用同一安装源重新安装即可：

```bash
npm install -g @ali/work-agent-cli --registry=https://registry.anpm.alibaba-inc.com
```

或：

```bash
npm install -g work-agent-cli
```

升级后重新检查：

```bash
workctl version --format json
workctl auth status --format json
workctl schema --format json
```

## Skills-only 安装脚本

仓库提供 `scripts/install-skills.sh` 用于只安装 skills bundle。常用变量：

```bash
WORKCTL_RELEASE_BASE_URL=https://github.com/example/work-agent-cli/releases/download/v1.2.3 \
WORKCTL_SKILLS_DEST=$HOME/.agents/skills/workctl \
./scripts/install-skills.sh
```

这些变量属于 skills utility script 输入，不是常规 CLI runtime 配置。

## 配置目录

默认配置目录是：

```text
~/.workctl/
```

可用 `WORKCTL_CONFIG_DIR` 覆盖。覆盖时只影响当前进程环境里的 workctl 行为。
