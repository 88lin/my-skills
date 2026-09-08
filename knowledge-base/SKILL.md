---
name: knowledge-base
description: >
  个人知识库技能：从书籍、PDF、文章、笔记中学习并存储结构化笔记，支持按需检索回忆。
  当用户说"帮我学这本书"、"加入知识库"、"查知识库"、"我学过什么"、
  "知识库里有没有关于X的"、"学习这个PDF"、"把这篇文章存下来"、"我的知识库"、
  "knowledge base"、"recall"、"查一下我学过的书"时触发。
version: 1.0.0
---

# Knowledge Base Skill

个人知识库。学习书籍和文章，存储结构化笔记，用户需要时回忆检索。

## 上游更新检查（仅提醒，不自动更新）

任何模式执行前，先用 Read 工具读取 `~/.qoderworkcn/skills/knowledge-base/.update-meta.json`：

- `last_check` 距今不超过 14 天 → 跳过检查，直接进入正常流程
- 超过 14 天或文件不存在 → 用 Bash 计算上游哈希并与 `upstream_hash` 比对：
  - Bash：`curl.exe -sL https://raw.githubusercontent.com/esthersjw/learn-from-books/main/SKILL.md | sha256sum | cut -d" " -f1`
  - PowerShell：先 `Invoke-WebRequest -Uri <url> -OutFile "$env:TEMP\kb.md"`，再 `(Get-FileHash "$env:TEMP\kb.md" -Algorithm SHA256).Hash.ToLower()`（注意 PowerShell 中 `curl` 是别名，要用 `curl.exe`）
  - 哈希相同 → 写入 .update-meta.json 刷新 `last_check` 为今天，继续正常流程
  - 哈希不同 → 在本次回复末尾提醒："knowledge-base 上游有更新，仓库：https://github.com/esthersjw/learn-from-books ，请自行决定是否更新。" 然后把新哈希和今天日期写入 .update-meta.json，继续正常流程
- 下载失败 → 静默跳过，不写 .update-meta.json，不打断用户请求
- 用户明确说"检查上游"/"检查更新" → 忽略 14 天限制，立即检查

## Storage Location

知识库路径存储在配置文件中：

```
~/.qoderworkcn/skills/knowledge-base/config.json
```

Config format:
```json
{
  "knowledge_base_path": "C:/Users/Computer/Desktop/knowledge-base"
}
```

### First-Time Setup

首次使用时（config.json 不存在或 knowledge_base_path 为空）：

1. 问用户："你想把知识库放在哪个目录？默认放桌面 (`~/Desktop/knowledge-base/`)，你也可以指定其他路径。"
2. 如果用户说"默认"/"桌面"/"好"或未指定，使用 `~/Desktop/knowledge-base/`
3. 创建目录结构（Bash/Git Bash 用 `mkdir -p`；PowerShell 用 `New-Item -ItemType Directory -Force`）
4. 用 Write 工具写入 config.json

### Directory Structure

```
<knowledge_base_path>/
├── _index.md        # 书单索引（标签+关键词）
└── books/           # 每本书/来源一个文件
    ├── never-split-the-difference.md
    ├── 思考快与慢.md
    └── ...
```

### Reading the Path

任何操作（learn/recall/manage）前，先用 Read 工具读取 `~/.qoderworkcn/skills/knowledge-base/config.json` 获取知识库路径。文件不存在则触发 First-Time Setup。

## Mode: Learn

Trigger: 用户给你内容（PDF、文本、URL、粘贴内容）并要求学习/摄入。

### Steps

1. **Read config** 获取知识库路径。无配置则先执行 First-Time Setup。

2. **Read the content.**
   - PDF 文件：调用 pdf skill 提取文本
   - URL：使用 WebFetch 工具抓取内容
   - 粘贴文本：直接使用

3. **Extract knowledge.** 生成结构化笔记：
   - YAML frontmatter: title, author, tags (array), date_ingested (YYYY-MM-DD)
   - 一句话总结（blockquote）
   - 核心框架 / 模型（附简要解释）
   - 关键原则（bullet points）
   - 可行动要点（具体怎么做）
   - 金句（可选，仅收录真正精彩的）

4. **Write the book file.** 用 Write 工具保存到 `<knowledge_base_path>/books/<filename>.md`
   - 英文书：kebab-case slug，如 `never-split-the-difference.md`
   - 中文书：去标点书名，如 `思考快与慢.md`
   - 文章/其他：`source-short-title.md`

5. **Update the index.** 用 Edit 或 Write 工具更新 `<knowledge_base_path>/_index.md`，追加一行：
   ```
   | Book Title | Author | Tags | Keywords | File |
   ```
   Tags 用 `#tag` 格式。Keywords 用逗号分隔，覆盖同义词和相关词。

6. **Confirm to user.** 告知：学到了什么，提取了多少框架/原则/要点。

### Book File Template

```markdown
---
title: "书名"
author: "作者"
tags: [主题1, 主题2]
date_ingested: 2026-07-24
---

# 书名

> 一句话总结全书核心观点。

## 核心框架

### 框架名称
这个框架是什么、怎么用的简要解释。

## 关键原则

- 原则一
- 原则二

## 可行动要点

- 具体可以做的事
- 另一个行动步骤

## 金句

- "原文金句" — 上下文说明
```

所有笔记内容必须用中文。英文书需将框架、原则、要点翻译为中文。金句可保留原文但必须附中文说明。

### Large File Handling

PDF 过大时：
- 分章处理（Read 工具使用 offset/limit 参数）
- 跨分块累积提取的知识
- 全部处理完后写入最终合并笔记
- 过程中告知用户进度（"正在处理第 3/12 章..."）

### Re-ingestion

同名文件已存在时直接覆盖。用户可能有更完整的版本。

## Mode: Recall

Trigger: 用户明确要求搜索/查询知识库。如"查知识库"、"我学过的书里有没有..."、"recall"、"知识库里关于X的"。

不要自动触发 recall，仅在用户主动询问时。

### Steps

1. **Read config** 获取知识库路径。

2. **Read the index.** 用 Read 工具加载 `<knowledge_base_path>/_index.md`。

3. **Match by keywords and tags.** 将用户查询与每行的标签和关键词比对，选最相关的书（最多 5 本）。

4. **If index matching fails, grep.** 用 Grep 工具在 `books/` 目录下搜索查询词。

5. **Read matched book files.** 用 Read 工具加载相关笔记。

6. **Synthesize and respond.** 将知识织入回答：
   - 注明每条洞察来自哪本书
   - 自然表达，不要直接倾倒笔记
   - 多本书相关时做综合
   - 无匹配时直说："知识库里目前没有相关内容"

## Mode: Manage

Trigger: 用户询问知识库状态、要求列出/删除/搜索。

### Commands

- **list** — 读取 `_index.md`，以易读格式展示书单
- **show <book>** — 读取并展示某本书的完整笔记
- **delete <book>** — 将书文件移入系统回收站（Windows 用 PowerShell SendToRecycleBin），并从 `_index.md` 删除对应行
- **search <query>** — 用 Grep 工具搜索所有书文件，报告匹配及上下文
- **stats** — 统计：总书数、标签分布、最近摄入
- **path** — 显示当前知识库路径
- **move <new_path>** — 移动整个知识库到新位置并更新 config.json

## Index File Format

首次创建 `_index.md`：

```markdown
# Knowledge Base Index

| 书名 | 作者 | 标签 | 关键词 | 文件 |
|------|------|------|--------|------|
```

摄入后每行示例：
```
| Never Split the Difference | Chris Voss | #谈判 #沟通 | 谈判, BATNA, 镜像, 标注, 锚定, negotiation | books/never-split-the-difference.md |
```

## Obsidian Compatibility

知识库格式兼容 Obsidian：
- 标准 YAML frontmatter（Obsidian 原生解析）
- frontmatter 中的 tags 数组（显示在 Obsidian 标签面板）
- 纯 Markdown 结构（完美渲染）
- `_index.md` 作为内容地图
- 跨笔记引用时使用 `[[Book Title]]` wikilink 语法

用户可将 Obsidian vault 指向知识库目录来浏览、搜索和可视化知识图谱。

## Important Notes

- 任何操作前先读 config.json 确定知识库路径
- config.json 缺失或路径不存在时触发 First-Time Setup
- 笔记简洁但有实质——提取框架和原则，不写冗长摘要
- 所有笔记用中文，无论源语言是什么
- 标签短且可复用（不是完整句子）
- 索引中的关键词覆盖同义词和相关词，提升召回率
- 删除操作永远移入回收站，不永久删除

## Pitfalls

- Windows 路径用正斜杠或双反斜杠，避免转义问题
- PowerShell 中 `curl` 是 Invoke-WebRequest 的别名，参数不兼容；命令行一律用 `curl.exe` 或 Invoke-WebRequest
- 中文文件名在某些终端下可能乱码，用 Bash 操作时注意编码
- PDF 提取质量取决于 PDF 本身，扫描件可能无法提取文字
- 大 PDF 分块处理时注意章节边界，避免截断语义
- config.json 和 .update-meta.json 存在技能目录内，重装或迁移技能目录时记得一起带走

## Verification

- 摄入后：确认 books/ 下生成了 .md 文件，_index.md 有对应新行
- 检索后：确认引用的内容确实存在于对应笔记文件中
- 管理操作后：确认文件系统状态与索引一致
