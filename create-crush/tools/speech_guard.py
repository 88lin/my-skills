#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""speech_guard.py —— 反单调对话引擎的文本层裁判（B 档）

职责（只做算术，不生成）：
  1. 重复度：与最近 N 轮回复做「字符 2-gram Jaccard」，判断是否退化成同一句话
  2. 结尾方式：反问 / 省略号 / 表情 / 感叹 / 陈述，检测"每轮同一个收尾"
  3. 逃生句：算了吧 / 还是去…吧 这类万能句，5 轮窗口内计数，超标即否决
  4. 句式指纹：(长度分桶, 前2字, 结尾类) 连续相同即判定隐性重复

用法：
  python3 tools/speech_guard.py --slug xiaomei --turn 12 --text "算了吧，还是去听歌吧"
  python3 tools/speech_guard.py --state crushes/xiaomei/sessions/2026-10-01.json \
      --turn 12 --text "..." --commit
  python3 tools/speech_guard.py --selftest

输出：JSON 裁决，verdict = ok / warn / veto
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from session_state import (  # noqa: E402
    BASELINE_ADAPTIVE,
    emit,
    load_adaptive,
    load_state,
    log_violation,
    recent_turns,
    resolve_adaptive_path,
    resolve_state_path,
    save_state,
    upsert_turn,
)

STOP_CHARS = set(
    "的了呢吧啊呀嘛哦嗯是在有和就也都还很不要会着过们我你他她它这那什么怎么一个把被给对能"
)

ESCAPE_PATTERNS = [
    (r"算了吧", "算了吧"),
    (r"^算了$", "算了"),
    (r"^懒得", "懒得"),
    (r"随便吧", "随便吧"),
    (r"^无所谓", "无所谓"),
    (r"^就这样吧$", "就这样吧"),
    (r"^再说吧$", "再说吧"),
    (r"^看情况", "看情况"),
    (r"^嗯嗯$", "嗯嗯"),
    (r"^哈哈$", "哈哈"),
    (r"^呵呵$", "呵呵"),
    (r"^不想说", "不想说"),
    (r"还是去.{0,6}吧$", "还是去…吧"),
]

ESCAPE_MAX_LEN = 14
ESCAPE_WINDOW = 5
ESCAPE_BAN_AT = 2
JACCARD_WARN = 0.50
JACCARD_VETO = 0.65
COMPARE_TURNS = 3

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u2764]"
)
PUNCT_RE = re.compile(
    r"[，。！？、；：\u201c\u201d\u2018\u2019（）《》…—～~!?,.;:(){}\[\]\"'`\s\-]+"
)
TRAILING_PUNCT_RE = re.compile(r"[\s，。！？、；：…—～~!?,.;:'\"）)】\]]+$")
QUESTION_RE = re.compile(r"[？?]")
EXCLAIM_RE = re.compile(r"[！!]")
ELLIPSIS_RE = re.compile(r"(\.{2,}|…)")
SOFT_END_RE = re.compile(
    r"(那你呢|你呢|早点睡|早点休息|路上小心|注意安全|吃了吗|多穿点|别熬夜"
    r"|晚安|到了说|小心点|好好吃饭|记得吃饭|慢慢来)"
)


def normalize(text):
    """去掉标点空白，只留汉字与字母数字。"""
    return PUNCT_RE.sub("", text or "")


def bigrams(text):
    """字符 2-gram 集合，先剔除高频停用字，避免「的了呢」主导相似度。"""
    chars = [c for c in normalize(text) if c not in STOP_CHARS]
    if len(chars) < 2:
        return set(chars)
    return {"".join(chars[i:i + 2]) for i in range(len(chars) - 1)}


def jaccard(set_a, set_b):
    if not set_a or not set_b:
        return 0.0
    inter = len(set_a & set_b)
    union = len(set_a | set_b)
    return round(inter / union, 3) if union else 0.0


def end_style(text):
    """结尾方式分类。关心式软收尾单独成类——它是温度，不是敷衍。"""
    stripped = TRAILING_PUNCT_RE.sub("", (text or "").strip())
    plain = normalize(stripped)
    if EMOJI_RE.search(stripped[-2:] if stripped else ""):
        return "表情"
    if SOFT_END_RE.search(stripped[-10:] if stripped else ""):
        return "关心"
    if QUESTION_RE.search(stripped[-3:] if stripped else ""):
        return "反问"
    if re.search(r"[吗么呢]$", plain):
        return "反问"
    if ELLIPSIS_RE.search(stripped[-4:] if stripped else ""):
        return "省略号"
    if EXCLAIM_RE.search(stripped[-3:] if stripped else ""):
        return "感叹"
    if len(plain) <= 3:
        return "敷衍"
    return "陈述"


def length_bucket(text):
    n = len(normalize(text))
    if n <= 4:
        return 0
    if n <= 12:
        return 1
    if n <= 30:
        return 2
    return 3


def fingerprint(text):
    """句式指纹：长度分桶 + 前 2 字 + 结尾方式。"""
    plain = normalize(text)
    return [length_bucket(text), plain[:2], end_style(text)]


def match_escapes(text, max_len=ESCAPE_MAX_LEN, whitelist=()):
    """短回复里出现的万能句。长回复中提到这些词不算（可能在讲故事）。"""
    plain = normalize(text)
    if len(plain) > max_len:
        return []
    hits = []
    for pattern, label in ESCAPE_PATTERNS:
        if label in whitelist:
            continue
        if re.search(pattern, plain) and label not in hits:
            hits.append(label)
    return hits


def count_recent_escapes(recent):
    total = 0
    for record in recent:
        total += len(record.get("escape_hits") or [])
    return total


def analyze(text, recent, turn_no=None, adaptive=None):
    adaptive = adaptive or {}
    warn_threshold = adaptive.get("jaccard_warn", BASELINE_ADAPTIVE["jaccard_warn"])
    veto_threshold = adaptive.get("jaccard_veto", BASELINE_ADAPTIVE["jaccard_veto"])
    ban_at = adaptive.get("escape_ban_at", BASELINE_ADAPTIVE["escape_ban_at"])
    max_len = adaptive.get("escape_max_len", BASELINE_ADAPTIVE["escape_max_len"])
    whitelist = adaptive.get("whitelist") or []

    text_grams = bigrams(text)
    max_jaccard = 0.0
    similar_turn = None
    for record in recent:
        score = jaccard(text_grams, bigrams(record.get("text", "")))
        if score > max_jaccard:
            max_jaccard = score
            similar_turn = record.get("turn")

    style = end_style(text)
    fp = fingerprint(text)
    escapes = match_escapes(text, max_len, whitelist)

    violations = []
    advice = []

    if max_jaccard >= veto_threshold:
        violations.append({
            "type": "degenerate_repetition",
            "level": "veto",
            "detail": "与第 %s 轮重合度 %.2f，几乎在重复同一句话" % (similar_turn, max_jaccard),
        })
        advice.append("换一个话题锚点重写：这一轮必须引入上几轮没出现过的新内容")
    elif max_jaccard >= warn_threshold:
        violations.append({
            "type": "similar_repetition",
            "level": "warn",
            "detail": "与第 %s 轮重合度 %.2f，句式偏近" % (similar_turn, max_jaccard),
        })

    if recent:
        prev = recent[-1]
        prev_style = prev.get("end_style")
        if prev_style and style == prev_style:
            prev2_style = recent[-2].get("end_style") if len(recent) >= 2 else None
            if prev2_style and prev2_style == style:
                violations.append({
                    "type": "repeat_ending",
                    "level": "veto",
                    "detail": "连续三轮都是「%s」式结尾" % style,
                })
                advice.append("这次换个收尾：反问 / 陈述 / 表情轮着来，别总用同一种")
            else:
                violations.append({
                    "type": "same_ending",
                    "level": "warn",
                    "detail": "与上一轮同一种结尾方式（%s）" % style,
                })

        prev_fp = prev.get("fingerprint")
        if prev_fp and prev_fp == fp and length_bucket(text) <= 2:
            violations.append({
                "type": "same_fingerprint",
                "level": "veto",
                "detail": "与上一轮句式指纹完全相同：%s" % "|".join(str(x) for x in fp),
            })

    recent_escape_count = count_recent_escapes(recent)
    escape_total = recent_escape_count + len(escapes)
    if escapes and escape_total >= ban_at:
        violations.append({
            "type": "escape_phrase",
            "level": "veto",
            "detail": "万能句「%s」，%d 轮内第 %d 次" % (
                "、".join(escapes), ESCAPE_WINDOW, escape_total),
        })
        advice.append("这轮不许用万能句收尾，把话说完或直接抛一个具体问题")
    elif escapes:
        violations.append({
            "type": "escape_phrase_once",
            "level": "warn",
            "detail": "出现万能句「%s」（%d 轮内第 %d 次）" % (
                "、".join(escapes), ESCAPE_WINDOW, escape_total),
        })

    levels = [v.get("level") for v in violations]
    if "veto" in levels:
        verdict = "veto"
    elif "warn" in levels:
        verdict = "warn"
    else:
        verdict = "ok"

    return {
        "turn": turn_no,
        "verdict": verdict,
        "max_jaccard": max_jaccard,
        "similar_to_turn": similar_turn,
        "end_style": style,
        "fingerprint": fp,
        "escape_hits": escapes,
        "escape_count_window": escape_total,
        "plain_length": len(normalize(text)),
        "thresholds": {
            "jaccard_warn": warn_threshold,
            "jaccard_veto": veto_threshold,
            "escape_ban_at": ban_at,
        },
        "violations": violations,
        "advice": advice,
    }


def build_parser():
    parser = argparse.ArgumentParser(description="反单调对话引擎 · 文本层裁判")
    parser.add_argument("--state", help="状态文件路径")
    parser.add_argument("--slug", help="暗恋对象 slug（自动定位今天的会话文件）")
    parser.add_argument("--base-dir", default="crushes")
    parser.add_argument("--turn", type=int, help="当前轮次号")
    parser.add_argument("--adaptive", help="自适应配置文件路径（默认 crushes/{slug}/adaptive.json）")
    parser.add_argument("--text", help="待校验的回复文本")
    parser.add_argument("--commit", action="store_true", help="校验通过后写入本轮记录")
    parser.add_argument("--selftest", action="store_true")
    return parser


def run_selftest():
    """回归样本：覆盖「爱听歌」退化场景与正常回复。"""
    degenerate_history = [
        {"turn": 1, "text": "在忙，晚点说", "end_style": "陈述",
         "fingerprint": [1, "在忙", "陈述"], "escape_hits": []},
        {"turn": 2, "text": "算了吧，还是去听歌吧", "end_style": "陈述",
         "fingerprint": [2, "算了", "陈述"], "escape_hits": ["算了吧"]},
        {"turn": 3, "text": "算了吧，还是去听歌好了", "end_style": "陈述",
         "fingerprint": [2, "算了", "陈述"], "escape_hits": ["算了吧"]},
    ]
    healthy_history = [
        {"turn": 1, "text": "在忙，晚点说", "end_style": "陈述",
         "fingerprint": [1, "在忙", "陈述"], "escape_hits": []},
        {"turn": 2, "text": "周末那个展你去吗？", "end_style": "反问",
         "fingerprint": [1, "周末", "反问"], "escape_hits": []},
        {"turn": 3, "text": "嗯嗯", "end_style": "敷衍",
         "fingerprint": [0, "嗯嗯", "敷衍"], "escape_hits": ["嗯嗯"]},
    ]
    flat_history = [
        {"turn": 1, "text": "今天开了三个会", "end_style": "陈述",
         "fingerprint": [1, "今天", "陈述"], "escape_hits": []},
        {"turn": 2, "text": "项目排期又变了", "end_style": "陈述",
         "fingerprint": [1, "项目", "陈述"], "escape_hits": []},
    ]
    cases = [
        ("算了吧，还是去听歌吧", degenerate_history, "veto", "退化：逃生句 + 句子重复"),
        ("刚忙完，你那边的项目收尾了吗", healthy_history, "ok", "正常：新内容 + 反问收尾"),
        ("今天开了三个会，脑子有点糊", healthy_history, "ok", "正常：陈述收尾"),
        ("嗯嗯", flat_history, "warn", "轻警：首次出现敷衍句"),
        ("嗯嗯，都行", flat_history, "veto", "退化：连续三轮陈述式结尾"),
    ]
    ok = True
    for text, history, expected, note in cases:
        result = analyze(text, history, turn_no=4)
        passed = result["verdict"] == expected
        ok = ok and passed
        print("[%s] expect=%-4s got=%-4s | %s" % (
            "PASS" if passed else "FAIL", expected, result["verdict"], note))
        print("       text=%s  jaccard=%.2f style=%s escapes=%s" % (
            text, result["max_jaccard"], result["end_style"], result["escape_hits"]))
        for item in result["violations"]:
            print("         - %s: %s" % (item["type"], item["detail"]))
    print("selftest:", "all passed" if ok else "has failures")
    return 0 if ok else 1


def main():
    args = build_parser().parse_args()
    if args.selftest:
        return run_selftest()
    if not args.text:
        raise SystemExit("需要 --text（或使用 --selftest）")

    path = resolve_state_path(args.state, args.slug, args.base_dir)
    state = load_state(path, slug=args.slug)
    adaptive_path = args.adaptive or resolve_adaptive_path(args.state, args.slug, args.base_dir)
    adaptive = load_adaptive(adaptive_path)
    recent = recent_turns(state, COMPARE_TURNS, before_turn=args.turn)

    result = analyze(args.text, recent, turn_no=args.turn, adaptive=adaptive)

    if args.commit:
        upsert_turn(state, args.turn, {
            "text": args.text,
            "end_style": result["end_style"],
            "fingerprint": result["fingerprint"],
            "escape_hits": result["escape_hits"],
            "jaccard_max": result["max_jaccard"],
        })
        log_violation(state, args.turn, result["violations"])
        save_state(path, state)

    result["state_file"] = path
    result["adaptive_file"] = adaptive_path
    result["committed"] = bool(args.commit)
    emit(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
