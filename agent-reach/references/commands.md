# 四平台命令

在 PowerShell 中先设入口（只影响当前命令变量，无需激活环境）：

```powershell
$reader = 'C:\Users\Computer\.agents\external\agent-reach-runtime\bin\platform-read.ps1'
```

## B站

```powershell
& $reader bili search '机器学习' --type video --max 3 --json
& $reader bili video 'BV1owrpYKEtP' --json
& $reader bili hot --max 3 --json
& $reader bili user-videos 946974 --max 3 --json
```

`bili search` 默认搜用户，搜视频必须加 `--type video`。匿名入口不使用任何已保存登录信息；字幕应走浏览器后端：

```powershell
& $reader bilibili subtitle 'BV1owrpYKEtP' -f json
& $reader bilibili comments 'BV1owrpYKEtP' --limit 3 -f json
```

字幕取决于视频、分 P 和浏览器会话；先查看 `bilibili subtitle --help`。不要因为已安装就声称所有字幕可读。

## 小红书

```powershell
& $reader xhs search '咖啡' --limit 3 -f json
& $reader xhs note $noteUrl -f json
& $reader xhs comments $noteUrl --limit 3 -f json
& $reader xhs user $userId --limit 3 -f json
```

`$noteUrl` 必须来自实际搜索或 feed 的完整链接，保留 `xsec_token`、`xsec_source` 等参数；不要将它换成裸 note ID。命令输出错误时，不把空数组当作读取成功。

## Twitter/X

```powershell
& $reader twitter search 'from:OpenAI' --limit 3 -f json
& $reader twitter tweets OpenAI --limit 3 -f json
& $reader twitter thread $tweetUrl --limit 3 -f json
& $reader twitter profile OpenAI -f json
```

OpenCLI 2.0.2 的用户推文命令为 `tweets`；旧交接里的 `user-posts` 不适用于此版本。直接使用 Edge 会话，无需配置 `TWITTER_AUTH_TOKEN`、`TWITTER_CT0` 或安装独立 twitter-cli。搜索和用户推文读取分别验证，不能互相代表。

## Reddit

```powershell
& $reader reddit search 'local llm' --limit 3 -f json
& $reader reddit subreddit LocalLLaMA --limit 3 -f json
& $reader reddit read $postId --limit 3 --depth 1 --replies 2 -f json
```

帖子入口接受结果 ID、`t3_` fullname 或完整 Reddit 帖子 URL。访问受网络安全策略限制时，用户应先在 Edge 正常访问和登录 Reddit；不要自动更换代理、反复请求或绕过验证。

## 本机诊断

```powershell
& $reader doctor
& $reader xhs search --help
& $reader twitter tweets --help
```

`doctor` 只报告固定工具版本与现有 Proxy 状态，不发起四平台联网探测。底层帮助可能显示 `opencli` 前缀和 `--trace/--verbose/--window` 等通用选项；实际使用 `$reader`，这些选项在本地入口被禁用。
