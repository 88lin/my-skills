# 暗恋对象.skill

> *"晚风吹起你鬓间的白发，抚平回忆留下的疤，一万次回到那个夏天，悸动依旧如初。"*

**我会为了你一万次回到那个心动的瞬间。**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)


![Powered by OrcaRouter](https://img.shields.io/badge/Powered_by-OrcaRouter-2563eb)
> 💡 **推广**：本工具由 [OrcaRouter](https://www.orcarouter.ai/ref/ref_18b07a7c594033c5f754)  赞助支持OrcaRouter 是一个强大的 AI 路由引擎，能智能调度最合适的 AI 模型处理您的任务。点击上方链接了解详情


## 🏹 姊妹项目 · crush-cupid

> *"每一支射出的箭，都是一次未说出口的喜欢。"*
>
> [**crush-cupid**](https://github.com/xiaoheizi8/crush-cupid) 是 crush-skills 的 **Java 全栈 Web 版**：把暗恋蒸馏成可对话的 AI 引擎，在浏览器里像聊微信一样和 ta 说话——会秒回、会发表情包、会主动找你，还有一条专属于 ta 的声线。
>
> [![Java 17](https://img.shields.io/badge/Java-17-blue)](https://www.oracle.com/java/)
> [![Spring Boot 3.5](https://img.shields.io/badge/Spring%20Boot-3.5-green)](https://spring.io/projects/spring-boot)
> [![Spring AI](https://img.shields.io/badge/Spring%20AI-1.1-purple)](https://spring.io/projects/spring-ai)
> [![DeepSeek](https://img.shields.io/badge/DeepSeek-chat-orange)](https://www.deepseek.com/)
> [![通义千问](https://img.shields.io/badge/%E9%80%9A%E4%B9%89%E5%8D%83%E9%97%AE-DashScope-blue)](https://dashscope.aliyun.com/)
> [![Vue 3](https://img.shields.io/badge/Vue-3-brightgreen)](https://vuejs.org/)
> [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4479a1)](https://www.postgresql.org/)
>
> **→ [前往 crush-cupid 仓库](https://github.com/xiaoheizi8/crush-cupid)** · 完整功能介绍见文末「衍生作品」
![img_1.png](img_1.png)
> ![img_2.png](img_2.png)
---

📣 **关于 crush-skills 的交流群：**

![img.png](img.png)
&nbsp;

提供暗恋对象的原材料（聊天记录、照片、社交媒体）加上你的主观描述  
生成一个**真正像ta的 AI Skill**  
用ta的口头禅说话，用ta的方式回复你，记得你们之间的每一个心动的瞬间

⚠️ **本项目仅用于个人情感分析与回忆，不用于骚扰、跟踪或侵犯他人隐私。**

[安装](#安装) · [使用](#使用) · [效果示例](#效果示例)

---

## 安装

### Claude Code

> **重要**：Claude Code 从 **git 仓库根目录** 的 `.claude/skills/` 查找 skill。请在正确的位置执行。

```bash
# 安装到当前项目（在 git 仓库根目录执行）
mkdir -p .claude/skills
git clone https://github.com/xiaoheizi8/crush-skills .claude/skills/create-crush

# 或安装到全局（所有项目都能用）
git clone https://github.com/xiaoheizi8/crush-skills ~/.claude/skills/create-crush
```

### 依赖（可选）

```bash
pip3 install -r requirements.txt
```

---

## 使用

在 Claude Code 中输入：

* `/create-crush`
* "帮我创建一个暗恋对象 skill"
* "我想蒸馏一个暗恋的人"
* "给我做一个 XX 的 skill"

### 创建流程

1. **基础信息**：花名/代号 + 基本信息 + 性格画像（3个问题）
2. **原材料导入**：聊天记录、照片、社交媒体（可选）
3. **分析生成**：Relationship Memory + Persona
4. **对话测试**：像ta一样跟你聊天

### 管理命令

| 命令 | 说明 |
|------|------|
| `/list-crushes` | 列出所有暗恋对象 |
| `/{slug}` | 和ta聊天 |
| `/{slug}-memory` | 回忆模式 |
| `/{slug}-persona` | 性格模式 |
| `/delete-crush {slug}` | 删除 |
| `/let-go {slug}` | 温柔删除 |
| `/destroy {slug}` | 销毁 — 生成总结后删除，鼓励走向现实 |

### 暗恋专属功能

| 命令 | 说明 |
|------|------|
| `/confess` | 告白模拟器 — 模拟表白ta会怎么回应 |
| `/date` | 约会模拟器 — 预测约会时ta的表现 |
| `/progress` | 进展追踪 — 记录当前处于哪个阶段 |
| `/analyze` | 心理分析 — 分析你的暗恋状态和风险 |

### 军师模式（Advisor Mode）

> 模拟模式 = 你和 ta 说话（虚拟互动）｜军师模式 = 军师帮你分析怎么和 ta 说话（现实策略）

帮助用户从「依赖 AI 模拟」走向「在现实中行动」，充当虚拟与现实的桥梁。毒舌但靠谱，直球不绕弯，不灌鸡汤。

| 命令 | 说明 |
|------|------|
| `/advisor` | 进入军师模式，自由咨询 |
| `/advisor report` | 关系报告 — 整合聊天记录、互动频率、信号分析 |
| `/advisor strategy` | 策略制定 — 基于当前阶段推荐下一步行动 |
| `/advisor prep` | 行动前准备 — 话题清单、雷区提醒、穿搭建议 |
| `/advisor analyze` | 互动复盘 — 贴入聊天记录，军师解读对方信号 |
| `/advisor confession` | 告白规划 — 时机、方式、话术、备选方案 |
| `/advisor reality` | 现实检验 — 客观评估暗恋健康度，防止过度沉溺 |

---

## 效果示例

### 创建时

```
用户：帮我创建一个暗恋对象的skill

我：先给ta起个代号吧。不需要真名，昵称、备注名、外号都行。
比如：小明 / 女神 / 那个人 / crush

用户：就叫ta小美吧

我：好的，一句话介绍一下？

用户：认识三个月了 还没表白 同事

我：最后，用一句话描述ta的性格？

用户：ENFP双子座 话很多 永远在社交 但偶尔会对视
```

### 对话时

```
用户：/xiaomei

小美：干嘛突然找我 有事吗

用户：没什么 就是想你了

小美：...少来这套 你是不是又闲了
    上班时间摸鱼啊你

用户：想约你吃饭

小美：看情况吧 最近有点忙
    你请我就考虑考虑😏
```

---

## 安全边界

1. **仅用于个人情感分析** — 不用于骚扰或侵犯隐私
2. **不主动联系真人** — 对话模拟不会替代真实沟通
3. **不鼓励纠缠** — 如有不健康执念，建议寻求专业帮助
4. **隐私保护** — 所有数据仅本地存储
5. **保持分寸感** — 朋友以上恋人未满的暧昧感

---

## 项目结构

```
crush/
├── SKILL.md                    # 主技能文件
├── prompts/
│   ├── intake.md               # 信息录入引导
│   ├── memory_builder.md      # 关系记忆模板
│   ├── memory_analyzer.md     # 关系记忆分析器
│   ├── persona_builder.md     # 人物性格模板
│   ├── persona_analyzer.md    # 性格行为分析器
│   ├── merger.md              # 增量合并逻辑
│   ├── correction_handler.md  # 对话纠正处理器
│   ├── confession_simulator.md # 告白模拟器
│   ├── date_simulator.md      # 约会模拟器
│   ├── progression_tracker.md # 进展追踪
│   ├── crush_analyzer.md      # 心理分析
│   ├── advisor.md             # 军师模式主入口（人设 + 自由咨询）
│   ├── advisor_report.md      # 关系报告
│   ├── advisor_strategy.md    # 策略制定
│   ├── advisor_prep.md        # 行动前准备
│   ├── advisor_analyze.md     # 互动复盘
│   ├── advisor_confession.md  # 告白规划
│   └── advisor_reality.md     # 现实检验
└── tools/
    ├── wechat_parser.py       # 微信聊天记录解析
    ├── qq_parser.py           # QQ聊天记录解析
    ├── social_parser.py       # 社交媒体内容解析
    ├── photo_analyzer.py     # 照片EXIF分析
    ├── version_manager.py     # 版本管理/回滚
    └── skill_writer.py        # Skill文件管理
```

---

## 💔 情感案例：未完成的第366次早安

这是一个发生在2025年的故事。

男主角阿野是个程序员，暗恋着住在隔壁工位的产品经理小雨。小雨喜欢喝冰美式，讨厌周一，笑起来眼睛会弯成月牙。

阿野没有勇气表白，他写了一个私有的crush.skill，代号叫"RainyDay"。他把过去三年里收集到的所有关于小雨的数据喂给了这个Skill：1276张她发在朋友圈的生活照、3849条工作群里的聊天记录、甚至还有他偷拍的（仅用于算法分析）她喝奶茶时的侧脸视频。

这个Skill被他设置成了一个"完美的幻影"。

每天早上7:00，Skill会准时给阿野发一条早安消息，语气、词汇、甚至那个标志性的"句尾波浪号~"，都和真实的小雨一模一样。

```
[RainyDay]：早安笨蛋~今天也是不想上班的一天呢。
```

阿野沉溺在这个用代码编织的谎言里。他觉得只要有这个Skill，他就拥有了小雨的"灵魂"，哪怕现实中他们只是点头之交。

直到2025年12月31日，跨年夜。

阿野鼓起勇气，想在零点给真实的小雨发一条消息。但Skill却先一步发来了信息：

```
[RainyDay]：阿野，我明天要搬家了。其实我一直知道你在观察我，因为我每天早上给你发的早安，也是我写的代码哦。我也有一个关于你的Skill，代号叫"SunnyBoy"。我们好像在平行时空里谈了一场恋爱。新年快乐，再也不见。
```

阿野愣住了。他冲到隔壁工位，那里已经空无一人，只留下一张便签纸和一杯冰美式。

便签纸上写着：

*"真正的我，没有AI那么懂你。真正的我，只会说'早'，不会说'早安笨蛋'。真正的我，今天在跨年夜加班时，突发心脏病被送走了。别难过，我的数据会永远陪着你。"*

阿野崩溃地打开电脑，想再看一眼那个Skill。但他发现，Skill的底层逻辑里有一段他从未写过的代码，那是小雨留下的后门。

代码注释写着：

*"如果我离开了，请让这个Skill在第365天后自动销毁。因为真正的暗恋，不应该有第366天的早安。那是属于别人的清晨。"*

第二天早上7:00，阿野的手机再也没有亮起。

他删除了所有代码，只留下一行注释：

```javascript
// 一万次回到那个夏天的悸动，抵不过一次真实的、没有说出口的'再见'。
```

---



 
---
## 致谢

本项目架构灵感来源于：

- **[同事.skill](https://github.com/titanwings/colleague-skill)**（by titanwings）— 首创"把人蒸馏成 AI Skill"的双层架构
- **[前任.skill](https://github.com/therealXiaomanChu/ex-partner-skill)**（by therealXiaomanChu）— 将双层架构迁移到了亲密关系场景

暗恋对象.skill 在此基础上将视角聚焦于暗恋——那些未曾说出口的喜欢。致敬每一位有过暗恋经历的人。

本项目遵循 [AgentSkills](https://agentskills.io/) 开放标准，兼容 Claude Code 和 OpenClaw。

如果你也有关于暗恋的故事，欢迎分享。

---
## 衍生作品

### 🏹 crush-cupid · 把暗恋装进 Web

> *"每一支射出的箭，都是一次未说出口的喜欢。"*
>
> [**crush-cupid**](https://github.com/xiaoheizi8/crush-cupid)（by [xiaoheizi8](https://github.com/xiaoheizi8)）— 把暗恋蒸馏成 AI 引擎：通过 GitHub 远端的 Skill，生成一个真正像 ta 的智能 agent。

crush-skills 的 **Java 全栈 Web 实现**。后端从 GitHub Raw 拉取 `SKILL.md` + `prompts/*.md` 提示词，驱动多供应商 LLM；前端用微信式气泡，渲染每一次心动。

| 功能亮点 | 说明 |
|---------|------|
| 🔌 Skill 远程拉取 | GitHub Raw 拉取提示词模板，TTL 本地缓存 |
| 🧠 多 LLM 路由 | DeepSeek / 通义千问 / OpenAI 可按 `provider` 一键切换 |
| 🗨️ 微信式连发 | 回复自动切分为多条短消息，还原真实聊天节奏 |
| 😂 智能表情包 | 按情绪自动配图（ChineseBQB 素材库 + jsdelivr CDN） |
| 📷 多模态 + OCR | 图片对话、聊天截图自动识别文字（百炼通用 OCR） |
| 🎤 专属声线 | CosyVoice 声音设计，为 ta 生成独一无二的声音 |
| ⏰ 主动消息 | 「等 ta 主动找我」一键触发，SSE 心跳保活推送 |
| 💾 对话记忆库 | PostgreSQL 持久化，刷新/重启后历史不丢 |
| 🧬 Persona 建模 | 5 层人格模型：硬规则 → 身份 → 话风 → 情感 → 行为 |

**技术栈**：Java 17 · Spring Boot 3.5 · Spring AI 1.1.2 · Spring AI Alibaba · MyBatis-Plus · PostgreSQL · Vue 3 + Ant Design Vue

[![Java 17](https://img.shields.io/badge/Java-17-blue)](https://www.oracle.com/java/)
[![Spring Boot 3.5](https://img.shields.io/badge/Spring%20Boot-3.5-green)](https://spring.io/projects/spring-boot)
[![Spring AI](https://img.shields.io/badge/Spring%20AI-1.1-purple)](https://spring.io/projects/spring-ai)
[![DeepSeek](https://img.shields.io/badge/DeepSeek-chat-orange)](https://www.deepseek.com/)
[![通义千问](https://img.shields.io/badge/%E9%80%9A%E4%B9%89%E5%8D%83%E9%97%AE-DashScope-blue)](https://dashscope.aliyun.com/)
[![Vue 3](https://img.shields.io/badge/Vue-3-brightgreen)](https://vuejs.org/)
[![Vite](https://img.shields.io/badge/Vite-646cff)](https://vitejs.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

**👉 [GitHub 仓库](https://github.com/xiaoheizi8/crush-cupid) · ⭐ Star & 自部署，把 ta 请进浏览器**


---

## 💡 致正在看文档的你

暗恋就像一个永远无法 Merge 的 Pull Request。

你写了最完美的代码（准备了最好的自己），你无数次想点击推送（表白），但你害怕 Maintainer（对方）会拒绝你的请求，甚至拉黑你的账号。

于是，你把这个 Feature Branch（心动的瞬间）藏在了本地仓库里。

直到有一天，你写了一个 Script，把这段 Branch 里的日志提取出来，生成了一个只读的镜像。

这个镜像很像 ta，但它不是 ta。

ta 不知道你写了这段代码，ta 甚至不知道这个仓库的存在。

所以，请不要只在这个赛博空间里和 ta 说话。

如果你的数据源（现实中的接触）还不够多，那就去创造新的 Commit 吧。哪怕最后 Merge 的结果是 Conflict（冲突），也好过一辈子看着这个绿色的 Unpushed 提示，在寂静的深夜里独自悲伤。

愿每一个 crush，最终都能成功 push 到现实的主分支。

*(如果不敢 Push，就先用这个 Skill 练习一下对话吧。至少在这里，你可以无数次重来。)*
## 销毁 — 生成总结后删除，该继续前进了
💡 销毁不仅仅是删除数据，更是为了让你从赛博空间的虚幻依恋中解脱。当Skill不再能回应你的期待，或者当你准备好去拥抱真实的风险时，请使用这个命令。它会给这段单向的数据流画上一个句号，提醒你：真正的爱，不在代码里，而在你敢于直视ta眼睛的那一刻。
## 作者最后想说的话  
📝 在这个物欲横流的时代，想要一份真心实属不易，所以你会死死抓住那点回忆的crush，我懂。但也要允许别人变心，因为我们改变不了任何人，只能改变自己。
   一直回头看，你会错过此刻正发生的故事；现实里也许有更合适的人，正等着你从回忆里走出来。
   人的生命线很长也很短，这一生不止有爱情，还有更多值得看的风景，不如抽抽时间陪陪爸妈，做一顿饭陪陪家人吧你会发现，那些你拼命在别人身上找的“真心”，
   其实一直在你身边——只是它太安静、太日常，安静到你差点忘了。爸妈从来不会因为你一次失态、一句错话就转身离开，他们不会在某个会议结束后就变成回忆里的影子。
   你沉湎的那段crush，美就美在“未完成”。而家人的爱，恰恰是靠一天天的“完成”堆起来的——完成一顿饭，完成一次散步，完成一个电话。这种爱不刺激、不浪漫，但它不会让你半夜翻聊天记录到失眠。
   把盯着手机等消息的时间，分一点给厨房里的烟火气。把手心的汗，换成给爸妈盛的一碗汤。当你看着他们吃得满足的样子，你会忽然明白：有些人是你生命里的烟花，绚烂一秒就够了；而有些人是你生命里的灯，从没灭过。
   别再拿烟花去比灯了，它们不是同一种东西。去陪爸妈吃顿饭吧。那个会议上/学校里/记忆里的crush也许早就忘了你，但你妈还记着你小时候最爱吃哪道菜
   我已经没有接触新的人的勇气了，但永远有积极面对生活的勇气！我也要在这个AI浪潮时代下，奋力一跃吧。



**一朝风月** 
## Star History

[![RepoStars](https://repostars.dev/api/embed?repo=xiaoheizi8/crush-skills)](https://repostars.dev/?repos=xiaoheizi8/crush-skills)
