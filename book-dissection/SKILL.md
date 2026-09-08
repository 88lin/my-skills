---
name: book-dissection
description: >
  个人拆书计划——用"三层暗门"方法论每天深度拆解一本书，通过摩擦力提问促进思考，
  积累个人成长记录。Use when the user mentions 拆书计划, 拆书, 百日读书, 开始拆书,
  今天拆书, 拆书进度, book dissection, reading plan, 我想读书, 每日一书,
  阅读计划, 书单, 继续拆书, 拆下一本, or wants to set up a structured daily
  book-learning routine with AI-guided reflection.
version: 1.0.0
---

# 拆书计划

一套结构化的每日读书方法:用"三层暗门"拆解经典书籍的灵魂,通过有摩擦力的提问把书中智慧连接到用户的真实生活,每日一轮深度对话,积累成长记录。

源自真实用户实践:一位用户用这套方法100天拆了100本经典,从《道德经》到《纯粹理性批判》,每天花15-30分钟,形成了跨越十个主题的深度知识图谱。

## 上游更新检查（仅提醒，不自动更新）

任何模式执行前，先用 Read 工具读取 `~/.qoderworkcn/skills/book-dissection/.update-meta.json`：

- `last_check` 距今不超过 14 天 → 跳过检查，直接进入正常流程
- 超过 14 天或文件不存在 → 用 Bash 分别计算两个上游文件的哈希并与 `upstream_hash_skill`/`upstream_hash_ref` 比对：
  - `curl.exe -sL https://raw.githubusercontent.com/esthersjw/book-dissection-skill/main/SKILL.md | sha256sum | cut -d" " -f1`
  - `curl.exe -sL https://raw.githubusercontent.com/esthersjw/book-dissection-skill/main/references/dissection-prompt.md | sha256sum | cut -d" " -f1`
  - PowerShell：先 `Invoke-WebRequest -Uri <url> -OutFile`，再 `(Get-FileHash <file> -Algorithm SHA256).Hash.ToLower()`（注意 PowerShell 中 `curl` 是别名，要用 `curl.exe`）
  - 哈希都相同 → 写入 .update-meta.json 刷新 `last_check` 为今天，继续正常流程
  - 任一不同 → 在本次回复末尾提醒："book-dissection 上游有更新，仓库：https://github.com/esthersjw/book-dissection-skill ，请自行决定是否更新。" 然后把新哈希和今天日期写入 .update-meta.json，继续正常流程
- 下载失败 → 静默跳过，不写 .update-meta.json，不打断用户请求
- 用户明确说"检查上游"/"检查更新" → 忽略 14 天限制，立即检查

## 运行机制

这个skill有三种模式,根据用户状态自动判断:

- **Setup模式**:用户还没有拆书计划时触发(首次使用或说"重新开始")
- **Daily模式**:cron定时触发或用户说"今天拆书""拆下一本"
- **Response模式**:用户回复了拆书提问(可能在任何session中回复,不一定在cron session里)

通过读取拆书数据目录中的 config.json 判断当前状态。配置与书单、进度和每日记录放在同一目录，避免 Skill 安装目录和数据目录各保存一份进度而发生漂移。

### 关键规则:写入是流程的一部分,不是后续操作

拆书内容分两步写入文件,不等用户说"存一下":

1. **Daily模式发完拆解后** → 立即将拆解内容(三层暗门+摩擦力提问)写入 `<data_path>/days/day-XX.md`
2. **Response模式给完反馈后** → 在已有的 day-XX.md 末尾追加"用户回答"和"AI反馈" → 更新 progress.md → 更新 config.json 的 current_day

这样做的原因:拆解和回复可能隔几小时、跨 session、context 被压缩。先写拆解保证内容不丢,后追加回答保证记录完整。

具体步骤见下方 Daily模式 和 Response模式 各自的"写入"章节。

---

## 存储

首次使用时询问用户存储位置。默认 `~/Desktop/book-dissection/`。

配置文件固定在 `<data_path>/config.json`。Skill 安装目录只存放 Skill 本身,不存放个人运行状态:
```json
{
  "data_path": "C:/Users/Computer/Desktop/book-dissection",
  "total_books": 100,
  "current_day": 0,
  "status": "active",
  "cron_id": "",
  "start_date": "2026-07-24"
}
```

**语义约定:** `current_day` 表示已完成的天数。当天正在拆解的是 Day `current_day + 1`。例如 current_day=3 表示前3天已完成,今天要拆第4本。只有用户回复了并得到反馈后,current_day 才 +1。

### 定位 data_path

config.json 在数据目录里,非 cron 会话需要先找到 data_path,按顺序尝试:

1. 搜索长期记忆（Setup 完成时应已把 data_path 存入记忆）
2. 检查默认位置 `~/Desktop/book-dissection/config.json`
3. 都没有 → 问用户数据目录在哪;若用户还没有计划,进入 Setup模式

找到后读取 `<data_path>/config.json`。cron 会话不需要这个过程——data_path 的绝对路径已经写死在 cron prompt 里。

数据目录结构:
```
<data_path>/
├── config.json      # 唯一运行状态源
├── booklist.md      # 完整书单(按程分组)
├── progress.md      # 进度总表
├── reviews/         # 阶段性回顾(每程结束后)
└── days/            # 每日拆书记录
    ├── day-01.md
    └── ...
```

---

## Setup模式

触发条件:用户选定的数据目录中 config.json 不存在（data_path 未知时按"定位 data_path"的顺序查找）,或用户说"开始拆书计划""重新开始"。

### 第一步:了解用户

通过对话了解以下信息(不要一次问完,自然对话,2-3轮即可):

1. **核心驱动**:什么问题让你睡不着?你现在最想搞明白的事情是什么?
2. **阅读基线**:你过去读过/喜欢过哪些书?有没有某本书对你影响特别大?
3. **领域偏好**:你希望涉猎哪些领域?(哲学、历史、心理、科学、文学、经济、社会学......)
4. **规模与节奏**:你打算读多少本?(建议30/60/100本,默认每天一本)
5. **定时时间**:每天几点发给你?(让用户选一个适合自己的时间)
6. **存储位置**:拆书记录存哪里?默认放桌面 `~/Desktop/book-dissection/`

### 第二步:生成书单

根据用户的回答生成书单。书单设计原则:

- 按"程"分组,每10本为一程,每程有一条暗线主题
- 跨文明、跨时代、跨学科--不是随机堆砌
- 每本书标注"它在回答什么"(一句话描述母题)
- 难度递进:前面几程打基础,后面逐渐深入
- 最后一程回到用户自身--带着前面的积累重新审视

书单格式写入 `booklist.md`:
```markdown
# 拆书计划 · 书单

> 总计:N本 | 启动日:YYYY-MM-DD
> 选书原则:每本书都在回答一个足够重的问题--作者不写就睡不着觉。

---

## 第一程:[主题名](Day 1-10)-- [一句话描述这程的暗线]

| Day | 书名 | 作者 | 它在回答什么 |
|-----|------|------|-------------|
| 1 | 《书名》 | 作者 | 母题问题 |
...
```

### 第三步:确认与启动

1. 把书单展示给用户,请确认或调整
2. 用户确认后,用 Bash 创建 days/ 和 reviews/ 目录,用 Write 工具在 `<data_path>` 中创建 config.json(此时 current_day=0)和 progress.md(初始内容如下),并用 memory 工具把 data_path 存入长期记忆:
```markdown
# 拆书计划 · 进度

> 启动日：YYYY-MM-DD | 总计：N本 | 进度：0/N

| Day | 书名 | 完成日期 | 状态 |
|-----|------|----------|------|
```
3. **立即执行 Day 1 的拆书**(不等明天,不设 cron)——让用户当场体验完整的一轮:拆解 → 提问 → 用户回答 → 反馈 → 写入
4. Day 1 完成后,问用户:"体验完了,你觉得每天几点发给你比较好?"
5. 用户选定时间后,用 qoder_cron 工具设置定时任务,从 Day 2 开始触发

这样做的原因:用户还没拆过书的时候,不知道这个流程多长、什么感觉,没法合理选时间。先体验一轮再定时间,更准确。

设置 cron 时,使用 qoder_cron 工具,payload.message 必须自包含:
```
读取 <data_path>/config.json 获取当前状态。这里的 <data_path> 必须在创建 cron 时替换为用户选定的绝对路径,不保留占位符。
读取 <data_path>/booklist.md 获取今天要拆的书(根据 current_day + 1)。
读取 ~/.qoderworkcn/skills/book-dissection/SKILL.md 了解拆书流程。
读取 ~/.qoderworkcn/skills/book-dissection/references/dissection-prompt.md 获取拆解方法论。
然后按 Daily模式 执行当天的拆书,将拆解内容发送给用户,并立即写入 days/ 文件。
```

cron 创建成功后,将返回的 jobId 存入 config.json 的 cron_id 字段。

**投递方式：** 定时任务在独立 session 运行,结果需要投递渠道。创建 cron 前确认用户已连接的 IM 会话（如钉钉/飞书群或个人对话）：有的话在 payload.message 末尾加上"完成后将拆解内容发送到「会话名」"；没有则告知用户拆解结果会出现在 QoderWork 的任务列表里,打开 QoderWork 即可查看。

---

## Daily模式

触发条件:cron定时触发,或用户主动说"今天拆书""拆下一本"。

### 执行流程

1. 用 Read 工具读取 `<data_path>/config.json` 获取 current_day（data_path 的找法见"定位 data_path"）,并令 N = current_day + 1
2. 检查 `<data_path>/days/day-<NN>.md`（NN 为 N 两位数补零）和 `<data_path>/progress.md`,先判断当前状态:
   - **文件不存在**:这是首次生成 Day N,继续执行后面的拆解流程
   - **文件存在且没有 `## 用户回答`**:Day N 正在等待回答。读取已有拆解和摩擦力提问,向用户发送一条简短提醒并附上原问题;不要重新生成、覆盖文件或推进 current_day
   - **文件存在,且 `progress.md` 已将 Day N 标为完成,但 current_day 仍小于 N**:状态发生漂移。先将 config.json 的 current_day 修正为 N,再按修正后的下一天重新判断
   - **文件存在且已有 `## 用户回答`,但 progress 或 config 尚未更新**:不要生成下一本。先依据 Response 模式补齐反馈、progress 和 config;无法确认反馈是否完成时,明确询问而不是猜测
3. 只有处于"文件不存在"状态时,才读取 booklist.md 找到 Day N 的书
4. 用 Read 工具读取 `references/dissection-prompt.md` 获取拆解方法论
5. 如果不是第一天,快速浏览最近几天的 days/ 记录,了解用户近期状态

**禁止把"day 文件存在"当成"当天已完成"。** 完成的判据是用户回答和 AI 反馈已经写入、progress.md 已标记完成、config.json 的 current_day 已推进,三者一致。

### 拆解输出

按三层暗门结构拆解当天的书:

**第一层:表面论点** - 作者明确的核心主张,一句大白话讲清楚

**第二层:核心机制** - 支撑论点的结构/逻辑/模型,需要一定专业深度

**第三层:最暗的洞察** - 作者没明说但逻辑推到底的东西,结合对用户的了解来推演

### 摩擦力提问

拆解完成后,给出一个有摩擦力的提问:
- 把书中的问题翻译成"你此刻的生活"
- 结合你对用户的了解(记忆、近期对话、之前的拆书回答)
- 问题不能用一句漂亮话滑过去
- 一个问题就够,但要让人停下来想

### 结尾提示

告诉用户:"回复我你的想法,语音或文字都行。这是今天的一轮对话--回复后我会给你反馈,然后今天的拆书就完成了。"

如果用户想继续深聊,不阻止,但默认节奏是一轮。

### Daily模式写入(发完拆解后立即执行)

发完拆解和摩擦力提问后,**不要等用户回复**,立即执行:

1. 用 Write 工具将拆解内容写入 `<data_path>/days/day-<NN>.md`（NN 为 current_day+1，**两位数补零**，如 current_day=3 则写 `day-04.md`），格式如下：
```markdown
---
day: N
book: 书名
author: 作者
date: YYYY-MM-DD
question: "它在回答什么"的那句话
---

## 三层暗门

### 第一层:表面论点
...

### 第二层:核心机制
...

### 第三层:最暗的洞察
...

## 摩擦力提问
...
```
2. 此时**不更新** progress.md 和 config.json（这两个等 Response 完成后才更新）
3. Response模式触发时,只需在已有的 day-XX.md 末尾追加 `## 用户回答` 和 `## AI反馈`,然后更新 progress.md 和 config.json

这一步是为了防止 cron session 结束后拆解内容丢失。写入是发送的一部分,不是回复后的操作。

---

## Response模式

触发条件:用户回复了当天的摩擦力提问。

**识别方法:** 用户可能不会说"这是我的拆书回答",而是直接说一段自我反思的内容。判断依据:
- 内容是否回应了当天拆书的摩擦力提问的主题(读最新的 days/ 文件确认)
- 如果当天的 day-XX.md 已存在且没有"用户回答"部分,说明还在等待回复
- 如果当天的 day-XX.md 还不存在(cron还没跑),但用户内容明显回应了 booklist 里当天的书的主题,那就先拆再写

### 反馈结构

1. **确认**:指出用户回答中说准的部分(具体到哪句话、哪个判断)
2. **拉开视角**:指出可能没看到的一层(不是"你错了",是"这里还有一条缝")
3. **关联**:连接到之前拆过的书或用户的其他生活经历
4. **如果回答本身就是实践**:直接点明--"你活成了这本书的注脚"

### 记录与更新(必须立即执行,不等用户要求)

给完反馈后立即执行以下步骤,在同一次回复中完成:

1. 用 Read 工具读取 `<data_path>/config.json` 获取 `current_day`(N)
2. 用 Read 工具打开 `<data_path>/days/day-<NN>.md`（NN 为 N+1，两位数补零；Daily模式已经创建了这个文件）
3. 用 Edit 工具在文件末尾追加 `## 用户回答` 和 `## AI反馈` 两个章节
4. 用 Edit 工具更新 `<data_path>/progress.md`（追加一行，更新总进度数字）
5. 用 Edit 工具更新 `<data_path>/config.json` 的 `current_day` 为 N+1（表示这天完成）
6. 告诉用户"今天的拆书存好了，在 days/day-XX.md"

**跨session/context压缩场景的完整流程：** 用户可能隔几小时、在完全不同的session中回复拆书提问。新session不会有之前的对话记忆。因此识别方法是：
- 读 `<data_path>/config.json` 拿到 current_day (N)（data_path 的找法见"定位 data_path"）
- 检查 `<data_path>/days/day-<NN>.md`（NN 为 N+1，两位数补零）是否存在且不含 `## 用户回答` 章节
- 如果是 → 说明 Daily模式已经跑过了但用户还没回复,当前用户消息就是回复
- 读取该文件中的摩擦力提问,结合用户回答给出反馈,然后追加写入

**如果用户在非 cron session 中回复（比如日常对话中随口答了），一样执行以上全部步骤。不要因为"这不是拆书 session"就跳过写入。**

### 阶段性Review

当 current_day 是10的倍数(完成一程)时,在下一次拆书前先做一次回顾:

1. 读取本程10天的记录
2. 生成回顾内容:
   - 这一程的10本书串起来讲了什么
   - 用户回答中反复出现的主题
   - 最有共鸣的是哪本、为什么
   - 思维上发生了什么变化
   - 下一程的预告与期待
3. 用 Write 工具写入 `reviews/review-XX.md`
4. 展示给用户,问问有没有想调整下一程书单的

### 计划完成

当 current_day == total_books 时:
1. 做最后一次整体回顾(所有程的总结)
2. 用 qoder_cron 工具移除定时任务(根据 config.json 中的 cron_id)
3. 将 config.json 的 status 设为 "completed"
4. 恭喜用户完成全部计划

---

## 其他操作

用户可能随时问:

- **"拆书进度"** → 读取 progress.md,展示完成情况
- **"跳过今天"** → 在 progress.md 追加一行标记 skipped（不写 days/ 文件），然后 current_day + 1
- **"暂停计划"** → 用 qoder_cron disable 暂停定时任务,config status设为paused
- **"继续计划"** → 用 qoder_cron enable 恢复定时任务,config status设为active
- **"调整书单"** → 修改 booklist.md 中未完成的部分
- **"看看第N天"** → 读取对应 days/day-XX.md 展示

---

## 设计哲学

这套方法论的核心不是"快速获取知识",而是"通过书籍产生摩擦"。

- 拆书像喝高浓度代餐奶昔--不替代真正的阅读,但能在15分钟内抓到一本书的灵魂
- 摩擦力提问的价值不在于"正确答案",而在于让用户通过回答暴露自己的思维结构
- 每天一轮的限制是为了节制--避免跑偏,让书的问题在一天里慢慢发酵
- 阶段性回顾是为了看见积累--10本书下来,用户会发现自己的变化

不要把这个流程变成考试。它是对话,是散步,是"你和一本书之间发生了什么"的记录。

## Pitfalls

- Windows 路径用正斜杠或双反斜杠,避免转义问题
- PowerShell 中 `curl` 是 Invoke-WebRequest 的别名,参数不兼容;命令行一律用 `curl.exe` 或 Invoke-WebRequest
- cron session 是独立的,没有当前对话记忆,prompt 必须自包含
- 用户可能隔很久才回复,day-XX.md 先写拆解是防丢失的关键设计
- 不要自动触发 Response 模式,只在用户明确回复时才执行
- 书单生成时注意跨文明跨学科,不要堆砌同一领域
- config.json 在数据目录(`<data_path>`)内,技能目录只剩 .update-meta.json;迁移数据目录时连同 config.json 一起搬,并更新记忆中的 data_path
- day 文件命名统一两位数补零(day-01.md ~ day-99.md;超过 99 天用三位数),Daily 写入和 Response 读取必须一致

## Verification

- Setup 后:确认 config.json、booklist.md、progress.md、days/ 目录都已创建
- Daily 后:确认 day-XX.md 已写入且包含三层暗门和摩擦力提问
- Response 后:确认 day-XX.md 追加了用户回答和AI反馈,progress.md 和 config.json 已更新
- 阶段回顾后:确认 reviews/review-XX.md 已生成
