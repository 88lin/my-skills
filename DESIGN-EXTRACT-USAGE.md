# design-extract / extract-design 使用说明

### 第一步：先找一个公开网站

先不要上来就分析登录页面、公司后台、需要权限的网站。

第一次建议先拿一个公开网站测试，比如：

- `https://stripe.com`
- `https://vercel.com`
- `https://www.apple.com`

### 第二步：运行最简单的一条命令

```bash
designlang https://stripe.com
```

这条命令的意思是：

- 用 `designlang` 分析 `https://stripe.com`
- 把提取结果写到输出目录

### 第三步：打开输出目录

命令执行完后，通常会在你**当前所在文件夹**下面生成：

```text
./design-extract-output/
```

例如：

如果你是在：

```text
C:\Users\Computer\Desktop\test
```

里运行命令，那么结果通常在：

```text
C:\Users\Computer\Desktop\test\design-extract-output
```

### 第四步：先看这个文件

优先打开：

```text
*-design-language.md
```

这是最适合直接阅读、也最适合继续发给 AI 做参考的文件。

## 常用使用教程

### 1. 基础提取

```bash
designlang https://stripe.com
```

适合：

- 先快速看一个网站用了什么颜色、字体、间距、组件风格

### 2. 带截图提取

```bash
designlang https://stripe.com --screenshots
```

比基础模式多做一件事：

- 顺便截图页面和部分组件

适合：

- 既想看设计语言总结，也想保留视觉证据

### 3. 多抓几页，不只看首页

```bash
designlang https://stripe.com --depth 3 --screenshots
```

这里的 `--depth 3` 可以理解成：

- 不只分析首页
- 还会沿着站内链接继续抓一部分页面

适合：

- 想分析“整个网站”的设计系统，而不是只看首页

### 4. 提取暗色模式

```bash
designlang https://stripe.com --dark --screenshots
```

适合：

- 目标网站本身有暗色模式
- 你想看看亮暗模式差异

### 5. 全量模式

```bash
designlang --full https://stripe.com
```

`--full` 会启用：

- 截图
- 响应式分析
- 交互状态捕获
- 自动交互

适合：

- 你已经知道基础怎么用
- 想一次拿到尽可能完整的信息

第一次不建议直接跑 `--full`，因为它更慢、输出更多。

## 进阶教程

### 1. 生成设计评分报告

```bash
designlang grade https://stripe.com
```

可以理解成：

- 给这个网站生成一份“设计成绩单”
- 更适合快速看它设计质量高不高、有哪些问题

### 2. 生成设计质量分数

```bash
designlang score https://stripe.com
```

这是比 `grade` 更偏“打分/维度”的输出。

### 3. 对比两个网站

```bash
designlang diff https://site-a.com https://site-b.com
```

这里你要把 `site-a.com` 和 `site-b.com` 换成两个真实网址。

适合比较：

- 两个竞品差异
- 改版前后差异
- 你的网站和参考网站差异

### 4. 多品牌矩阵

```bash
designlang brands https://stripe.com https://vercel.com https://linear.app
```

适合：

- 一次分析多个品牌
- 做横向视觉对比

### 5. 检查 token drift

```bash
designlang drift https://yourapp.com --tokens ./src/tokens.json
```

意思是：

- 用线上网站 `https://yourapp.com`
- 去对比你本地 `./src/tokens.json`
- 看看本地 token 和线上设计有没有漂移

如果你现在没有自己的 token 文件，这条先不用。

### 6. 视觉 diff

```bash
designlang visual-diff https://staging.example.com https://example.com
```

适合：

- 比较测试环境和正式环境
- 比较改版前后两个网址的差别

### 7. 直接把设计应用到你的项目

```bash
designlang apply https://stripe.com
```

适合：

- 你不只是想分析
- 还想把提取出来的设计 tokens 直接写进当前项目

注意：

- 这比普通提取更激进
- 第一次不建议直接用在正式项目上
- 建议先对着一个测试项目或临时目录试

### 8. 直接生成一个可运行的 Next.js 风格起步项目

```bash
designlang clone https://stripe.com
```

适合：

- 你想快速得到一个“参考网站风格的起步项目”
- 想把一个网站的设计语言快速变成可改的前端起点

注意：

- 这是“生成起步项目”，不是 1:1 完整克隆线上站点

### 9. 监控一个网站设计有没有变化

```bash
designlang watch https://stripe.com
```

适合：

- 长期观察某个竞品有没有改版
- 跟踪设计系统变化

### 10. 查看某个网站历史上的设计变化

```bash
designlang history https://stripe.com
```

适合：

- 你想知道一个网站过去有没有做过明显改版
- 想看设计演进轨迹

### 11. 把它当 MCP server 用

```bash
designlang mcp
```

适合：

- 你以后想把 designlang 作为 MCP 工具接给支持 MCP 的 agent

如果你现在只是想“提取网页设计系统”，这条可以先不用。

### 12. 检查本地 token 文件本身有没有问题

```bash
designlang lint ./src/tokens/design-tokens.json
```

适合：

- 你已经有本地 token 文件
- 想做 CI/质量检查

## 输出文件怎么看

重点看这些：

| 文件 | 用途 |
|---|---|
| `*-design-language.md` | 最适合给 AI 当设计上下文 |
| `*-design-tokens.json` | W3C DTCG design tokens |
| `*-variables.css` | CSS 自定义属性 |
| `*-tailwind.config.js` | Tailwind 主题配置 |
| `*-shadcn-theme.css` | shadcn/ui 主题变量 |
| `*-figma-variables.json` | Figma Variables 导入 |
| `*-preview.html` | 可视化预览报告 |
| `*-grade.html` | 设计评分报告 |

你还可能看到这些：

| 文件 / 目录 | 用途 |
|---|---|
| `*-anatomy.tsx` | 检测到的组件结构和变体草稿 |
| `*-motion-tokens.json` | 动效相关 token |
| `*-voice.json` | 品牌语气、CTA 用词等 |
| `*-prompts/` | 给 v0 / Cursor / Claude Artifacts 等工具的提示词 |
| `*-mcp.json` | MCP 相关输出 |
| `ios/` `android/` `flutter/` | 多平台输出（如果启用了对应参数） |

### 第一次优先看哪个

如果你第一次用，建议按这个顺序看：

1. `*-design-language.md`
2. `*-preview.html`
3. `*-grade.html`
4. `*-design-tokens.json`
5. `*-tailwind.config.js` / `*-variables.css`

### 这些文件怎么理解

#### `*-design-language.md`

最重要。

适合：

- 你自己读
- 发给 AI 做参考
- 做竞品设计总结

#### `*-preview.html`

这是可视化报告。

适合：

- 直接双击在浏览器打开
- 看颜色、字体、间距、阴影等可视化展示

#### `*-grade.html`

这是评分报告。

适合：

- 快速判断设计质量
- 看哪些地方做得好，哪些地方有问题

#### `*-design-tokens.json`

这是结构化 tokens 文件。

适合：

- 开发接设计系统
- 喂给其他工具
- 后续做 token diff / drift

#### `*-tailwind.config.js`
#### `*-variables.css`
#### `*-shadcn-theme.css`

这些更偏“直接接项目”的文件。

如果你只是做分析，先不用急着看。

## 推荐给 AI 的用法

### 分析参考网站

```text
用 extract-design 分析 https://example.com 的设计系统。
请重点总结：颜色、字体、间距、圆角、阴影、组件模式、动效风格、WCAG 问题。
最后告诉我哪些部分适合借鉴到当前项目，哪些不要照搬。
```

这里的 `https://example.com` 只是示例网址，你要换成真实网址。

### 为项目生成设计参考

```text
用 extract-design 提取 https://example.com 的 design-language.md。
然后把它整理成适合我当前项目使用的设计参考，不要直接照搬品牌，只提炼可迁移的视觉原则。
```

### 做竞品设计对比

```text
用 designlang 分析这几个网站：
1. https://site-a.com
2. https://site-b.com
3. https://site-c.com

请比较它们的色彩策略、排版、组件密度、交互动效、品牌气质，并给我一个可执行的设计方向建议。
```

### 配合 frontend-design 使用

```text
先用 extract-design 提取这个参考网站的设计语言：<URL>。
再用 frontend-design 的标准，把提取结果转成我当前项目可用的设计方向。
注意：不要复制对方品牌，只借鉴结构、节奏、层次和交互模式。
```

### 配合 critique 使用

```text
先用 extract-design 提取目标页面的客观设计数据。
再用 critique 做人工设计评审。
请区分：哪些是工具提取到的事实，哪些是你的设计判断。
```

## 处理登录页面或内网页面

默认的 `designlang <url>` 不使用你的日常 Chrome 登录态。

如果目标页面需要登录，它可能抓不到真实页面。

可选方式：

```bash
designlang https://example.com --cookie "session=xxx"
```

或者：

```bash
designlang https://example.com --cookie-file ./cookies.json
```

如果页面必须依赖你的浏览器登录状态，优先考虑 `web-access`，不要强行用 `designlang`。

简单理解：

- 公开网站：优先可以直接用 `designlang`
- 登录后页面：优先考虑 `web-access`
- 如果 `designlang` 能带 cookie 跑通，再考虑继续用它

### 还能用的认证相关参数

除了 `--cookie` 和 `--cookie-file`，原项目还支持：

```bash
designlang https://example.com --header "Authorization: Bearer xxxxx"
```

适合：

- 站点靠 header 鉴权
- API 网关或受保护页面场景

如果是本地开发站点、自签名证书，也可以用：

```bash
designlang https://example.local --insecure
```

## 当前安装状态

### Skill 放在哪里

```text
C:\Users\Computer\.agents\skills\extract-design
```

### CLI 放在哪里

```text
C:\Program Files\nodejs\node_global
```

### 当前版本

```text
designlang 12.1.0
```

## 更新与维护

常用维护命令：

- 检查 skill：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode check -Only extract-design
```

- 更新 skill：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update -Only extract-design
```

- 更新 CLI：

```bash
npm update -g designlang
```

- 查看 CLI 版本：

```bash
designlang --version
```

- 如果以后需要重装 skill：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\install-and-register-skill.ps1" -SourceType skills-cli -Repo Manavarya09/design-extract -Skill extract-design -RawSkillUrl "https://raw.githubusercontent.com/Manavarya09/design-extract/main/skills/extract-design/SKILL.md"
```

### 其他常用参数（没写在前面但也很有用）

- 指定输出目录：

```bash
designlang https://stripe.com --out ./my-output
```

- 指定输出名前缀：

```bash
designlang https://stripe.com --name stripe-home
```

- 等页面多加载一会儿（适合 SPA）：

```bash
designlang https://example.com --wait 3000
```

- 只提取某个区域：

```bash
designlang https://example.com --selector ".pricing-card"
```

- 只生成特定框架主题：

```bash
designlang https://example.com --framework shadcn
```

- 打印 JSON 到终端：

```bash
designlang https://example.com --json
```

- 输出多平台主题：

```bash
designlang https://example.com --platforms web,ios,android,flutter
```

## 风险和注意事项

- 它会访问外部 URL，属于联网操作。
- 第一次运行可能下载 Playwright Chromium。
- 输出文件可能很多，会写到 `design-extract-output/`。
- 对动态站、反爬站、登录站不一定稳定。
- 它提取的是“视觉事实”，不是完整设计判断。
- 不要把竞品 tokens 原样搬进商业项目，注意品牌和版权边界。

## 使用原则

- **按需触发**，不是默认触发。
- 只有当任务明确涉及“提取网站设计系统 / 分析竞品视觉 / 导出 tokens / 对比品牌风格”时再用。
- 日常普通 UI 修改不要默认调用它。

## Usage Rule

Use this skill **on demand**, not by default.

Trigger it only when the task clearly involves one of these goals:

- Extracting a website's design system or design language
- Understanding colors, fonts, spacing, shadows, radii, component patterns, or motion style from a live site
- Generating design tokens, CSS variables, Tailwind config, shadcn theme, or Figma variables from an existing website
- Comparing multiple websites or brands from a design-system perspective

Do **not** use this as the default skill for everyday UI design work, polish, critique, or typography improvements. For normal UI creation or iteration, prefer the existing design workflow and only use this skill when a real extraction task is needed.

## 我的推荐工作流

### 参考网站转项目设计方向

1. 用 `extract-design` / `designlang` 提取参考网站。
2. 读取 `*-design-language.md`。
3. 用 `frontend-design` 把参考转成当前项目的独立设计方向。
4. 用 `critique` 检查是否有照搬感或 AI slop。
5. 用 `polish` 做最后一致性和细节打磨。

### 竞品视觉研究

1. 用 `designlang brands` 或分别提取多个 URL。
2. 对比颜色、字体、密度、布局、动效、组件模式。
3. 总结共性和差异。
4. 明确哪些不该学，避免同质化。
