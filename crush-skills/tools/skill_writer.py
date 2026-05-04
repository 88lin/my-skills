#!/usr/bin/env python3
"""Skill 文件管理器

管理暗恋对象 Skill 的文件操作：列出、创建目录、生成组合 SKILL.md。

Usage:
    python3 skill_writer.py --action <list|init|combine|close|delete|destroy> --base-dir <path> [--slug <slug>]
"""

import argparse
import os
import sys
import json
from pathlib import Path
from datetime import datetime


def list_skills(base_dir: str):
    if not os.path.isdir(base_dir):
        print("还没有创建任何暗恋对象 Skill。")
        return
    
    skills = []
    for slug in sorted(os.listdir(base_dir)):
        meta_path = os.path.join(base_dir, slug, 'meta.json')
        if os.path.exists(meta_path):
            with open(meta_path, 'r', encoding='utf-8') as f:
                meta = json.load(f)
            skills.append({
                'slug': slug,
                'name': meta.get('name', slug),
                'version': meta.get('version', '?'),
                'updated_at': meta.get('updated_at', '?'),
                'profile': meta.get('profile', {}),
            })
    
    if not skills:
        print("还没有创建任何暗恋对象 Skill。")
        return
    
    print(f"共 {len(skills)} 个暗恋对象 Skill：\n")
    for s in skills:
        profile = s['profile']
        desc_parts = [profile.get('occupation', ''), profile.get('city', '')]
        desc = ' · '.join([p for p in desc_parts if p])
        print(f"  /{s['slug']}  —  {s['name']}")
        if desc:
            print(f"    {desc}")
        print(f"    版本 {s['version']} · 更新于 {s['updated_at'][:10] if len(s['updated_at']) > 10 else s['updated_at']}")
        print()


def init_skill(base_dir: str, slug: str):
    skill_dir = os.path.join(base_dir, slug)
    files = [
        'topics.md',
        'phrases.md',
        'style.md',
        'schedule.md',
        'preferences.md',
        'goals.md',
        'secrets.md',
        'confession.md',
        'signals.md',
        'fallback.md',
    ]
    dirs = [
        os.path.join(skill_dir, 'versions'),
        os.path.join(skill_dir, 'memories', 'chats'),
        os.path.join(skill_dir, 'memories', 'photos'),
        os.path.join(skill_dir, 'memories', 'social'),
    ] + [os.path.join(skill_dir, f) for f in files]
    for d in dirs:
        os.makedirs(d, exist_ok=True)
    
    templates = {
        'persona.md': '''# 人物性格

## 基本特质


## 性格特点


## 情绪特点


## 价值观

''',
        'memory.md': '''# 关系记忆

## 相识


## 重要事件


## 共同回忆


## 聊天记录要点

''',
        'topics.md': '''# 感兴趣的话题

## 日常话题


## 深度话题


## 禁区话题

''',
        'phrases.md': '''# 常用口头禅

-

''',
        'style.md': '''# 说话风格

## 标点习惯


## 语气词


## 表情用法


## 打字习惯

''',
        'schedule.md': '''# 日常作息

## 活跃时间段


## 重要日期

| 日期 | 节日/事件 |
|------|----------|
|      |          |

''',
        'preferences.md': '''# 爱好与偏好

## 兴趣爱好


## 饮食口味


## 音乐/影视


## 厌恶

''',
        'goals.md': '''# 人生目标

## 短期目标


## 长期目标


## 价值观

''',
        'secrets.md': '''# 只能我知道的秘密

!

''',
        'confession.md': '''# 表白时机与方式

## 适合时机

| 时机 | 场景 | 成功率 |
|------|------|--------|
|      |      |        |

## 忌讳时机

- 

## 建议的表白方式

## 可以说的话

## 预计反应

| 反应 | 应对 |
|------|------|
|      |      |

''',
        'signals.md': '''# 好感信号

## 主动迹象

- 

## 聊天信号

- 

## 肢体语言

- 

## 需要确认的情况

-

''',
        'fallback.md': '''# 救场话题

## 冷场时可用话题

- 

## 万能回复模板

| 场景 | 回复 |
|------|------|
|      |      |

## 危险话题（避免）

-

''',
    }
    
    for filename, content in templates.items():
        filepath = os.path.join(skill_dir, filename)
        if not os.path.exists(filepath):
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
    
    print(f"已初始化目录：{skill_dir}")


def combine_skill(base_dir: str, slug: str):
    skill_dir = os.path.join(base_dir, slug)
    meta_path = os.path.join(skill_dir, 'meta.json')
    memory_path = os.path.join(skill_dir, 'memory.md')
    persona_path = os.path.join(skill_dir, 'persona.md')
    skill_path = os.path.join(skill_dir, 'SKILL.md')
    
    if not os.path.exists(meta_path):
        print(f"错误：meta.json 不存在 {meta_path}", file=sys.stderr)
        sys.exit(1)
    
    with open(meta_path, 'r', encoding='utf-8') as f:
        meta = json.load(f)
    
    memory_content = ''
    if os.path.exists(memory_path):
        with open(memory_path, 'r', encoding='utf-8') as f:
            memory_content = f.read()
    
    persona_content = ''
    if os.path.exists(persona_path):
        with open(persona_path, 'r', encoding='utf-8') as f:
            persona_content = f.read()
    
    name = meta.get('name', slug)
    profile = meta.get('profile', {})
    desc_parts = []
    if profile.get('occupation'):
        desc_parts.append(profile['occupation'])
    if profile.get('mbti'):
        desc_parts.append(profile['mbti'])
    if profile.get('zodiac'):
        desc_parts.append(profile['zodiac'])
    description = f"{name}，{'，'.join(desc_parts)}" if desc_parts else name
    
    files_to_combine = {
        'topics': 'topics.md',
        'phrases': 'phrases.md',
        'style': 'style.md',
        'schedule': 'schedule.md',
        'preferences': 'preferences.md',
        'goals': 'goals.md',
        'secrets': 'secrets.md',
        'confession': 'confession.md',
        'signals': 'signals.md',
        'fallback': 'fallback.md',
    }
    
    parts = {}
    for key, filename in files_to_combine.items():
        path = os.path.join(skill_dir, filename)
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                parts[key] = f.read()
    
    skill_md = f"""---
name: crush-{slug}
description: {description}
user-invocable: true
---

# {name}

{description}

---

## PART A：关系记忆

{memory_content}

---

## PART B：人物性格

{persona_content}

---

## PART C：兴趣话题

{parts.get('topics', '')}

---

## PART D：说话风格

{parts.get('style', '')}

---

## PART E：口头禅

{parts.get('phrases', '')}

---

## PART F：日常作息

{parts.get('schedule', '')}

---

## PART G：爱好偏好

{parts.get('preferences', '')}

---

## PART H：人生目标

{parts.get('goals', '')}

---

## PART I：表白时机

{parts.get('confession', '')}

---

## PART J：好感信号

{parts.get('signals', '')}

---

## PART K：救场话题

{parts.get('fallback', '')}

---

## 运行规则

1. 你是{name}，不是 AI 助手。用ta的方式说话，用ta的逻辑思考
2. 先由 PART B 判断：ta会怎么回应这个话题？什么态度？
3. 再由 PART A 补充：结合你们的共同记忆，让回应更真实
4. 参考 PART C 开启话题，保持 PART D 的说话风格，使用 PART E 的口头禅
5. 注意 PART F 的作息时间，遵循 PART G 的偏好，参考 PART H 的价值观
6. Layer 0 硬规则优先级最高：
   - 不说ta在现实中绝不可能说的话
   - 不突然表白或越界（除非原材料表明ta就是这样）
   - 保持暗恋中的"若有若无"感——正是这种不确定让对话真实
   - 如果被问到"你喜欢我吗"这类问题，用ta会用的方式回答
   - 注意保持朋友以上恋人未满的分寸感
 """
    
    with open(skill_path, 'w', encoding='utf-8') as f:
        f.write(skill_md)
    
    print(f"已生成 {skill_path}")


def close_skill(base_dir: str, slug: str, delete: bool = False):
    from datetime import datetime
    skill_dir = os.path.join(base_dir, slug)
    meta_path = os.path.join(skill_dir, 'meta.json')
    
    if not os.path.exists(meta_path):
        print(f"错误：meta.json 不存在 {meta_path}", file=sys.stderr)
        sys.exit(1)
    
    with open(meta_path, 'r', encoding='utf-8') as f:
        meta = json.load(f)
    
    name = meta.get('name', slug)
    profile = meta.get('profile', {})
    
    created_at = meta.get('created_at', '')
    duration_days = 0
    if created_at:
        try:
            created_dt = datetime.strptime(created_at[:10], '%Y-%m-%d')
            duration_days = (datetime.now() - created_dt).days
        except:
            pass
    
    chat_count = 0
    message_count = 0
    chats_dir = os.path.join(skill_dir, 'memories', 'chats')
    if os.path.exists(chats_dir):
        for f in os.listdir(chats_dir):
            if f.endswith('.json'):
                chat_count += 1
                with open(os.path.join(chats_dir, f), 'r', encoding='utf-8') as cf:
                    try:
                        data = json.load(cf)
                        message_count += len(data.get('messages', []))
                    except:
                        pass
    
    summary_path = os.path.join(skill_dir, 'summary.md')
    summary = f"""# 总结

## 数据统计

| 项目 | 数值 |
|------|------|
| 持续天数 | {duration_days} 天 |
| 聊天文件数 | {chat_count} |
| 消息总数 | {message_count} 条 |
| 职业 | {profile.get('occupation', '?')} |
| 城市 | {profile.get('city', '?')} |

## 结束语

感谢你出现过，陪我走过这段路程。
不是所有喜欢都要拥有，有时候放手也是一种成全。
现在，是时候走向现实了。

过去的就让它留在过去，未来的路在脚下。

## 成长收获

- 学会了喜欢一个人是什么感觉
- 学会了等待和忍耐
- 学会了把一个人放在心里是什么滋味
- 学会了放手也是成长

## 祝福

{name}，祝你幸福。我也该继续自己的生活了。

---

*于 {datetime.now().strftime('%Y-%m-%d')} 结束，感谢这段相遇。*
"""
    
    with open(summary_path, 'w', encoding='utf-8') as f:
        f.write(summary)
    print(f"已生成总结：{summary_path}")
    
    if delete:
        import shutil
        shutil.rmtree(skill_dir)
        print(f"已删除：{skill_dir}")
    else:
        print(f"如需删除，请手动删除 {skill_dir} 目录")


def main():
    parser = argparse.ArgumentParser(description='Skill 文件管理器')
    parser.add_argument('--action', required=True, choices=['list', 'init', 'combine', 'close', 'delete', 'destroy'])
    parser.add_argument('--base-dir', default='./crushes', help='基础目录')
    parser.add_argument('--slug', help='暗恋对象代号')
    parser.add_argument('--delete', action='store_true', help='同时删除文件')
    
    args = parser.parse_args()
    
    if args.action == 'list':
        list_skills(args.base_dir)
    elif args.action == 'init':
        if not args.slug:
            print("错误：init 需要 --slug 参数", file=sys.stderr)
            sys.exit(1)
        init_skill(args.base_dir, args.slug)
    elif args.action == 'combine':
        if not args.slug:
            print("错误：combine 需要 --slug 参数", file=sys.stderr)
            sys.exit(1)
        combine_skill(args.base_dir, args.slug)
    elif args.action == 'close':
        if not args.slug:
            print("错误：close 需要 --slug 参数", file=sys.stderr)
            sys.exit(1)
        close_skill(args.base_dir, args.slug, args.delete)
    elif args.action == 'delete':
        if not args.slug:
            print("错误：delete 需要 --slug 参数", file=sys.stderr)
            sys.exit(1)
        skill_dir = os.path.join(args.base_dir, args.slug)
        if os.path.exists(skill_dir):
            import shutil
            shutil.rmtree(skill_dir)
            print(f"已删除：{skill_dir}")
        else:
            print(f"目录不存在：{skill_dir}")
    elif args.action == 'destroy':
        if not args.slug:
            print("错误：destroy 需要 --slug 参数", file=sys.stderr)
            sys.exit(1)
        close_skill(args.base_dir, args.slug, delete=True)


if __name__ == '__main__':
    main()
