#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QQ 聊天记录解析器（v2：带说话人归因）

支持格式：
- QQ 消息管理器导出的 txt 格式
- QQ 消息管理器导出的 mht 格式

与微信解析器共用 `chat_attribution` 模块的归因逻辑：
精确/去装饰匹配、判不准不猜、引用块单独标出、双侧标注 + 归因抽检。

Usage:
    python3 qq_parser.py --file <path> --target "<昵称>" --output <out.md>
        [--alias "<别名>"]... [--me "<我的昵称>"]... [--format auto]
"""

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from chat_attribution import (  # noqa: E402
    SpeakerResolver,
    annotate,
    build_plaintext_fallback,
    build_report,
    distinct_senders,
    is_no_name_layout,
    parse_messages_from_lines,
)

QQ_NAME_WITH_NUMBER_RE = re.compile(r"^(.+?)\s*[（(](\d+)[）)]\s*$")


def preprocess_qq_lines(file_path):
    """QQ 导出常见 `昵称(12345) 时间` 或 `时间 昵称(12345)`，统一成统一排版。"""
    with open(file_path, "r", encoding="utf-8", errors="ignore") as handle:
        lines = handle.readlines()
    normalized = []
    for raw in lines:
        line = raw.rstrip("\n")
        if line.strip().startswith("==="):
            continue
        match = QQ_NAME_WITH_NUMBER_RE.match(line.strip())
        if match:
            # 「昵称(QQ号)」独占一行 → 转成时间行前可直接用作昵称
            normalized.append(match.group(1).strip())
            continue
        normalized.append(line)
    return normalized


def detect_format(file_path):
    ext = Path(file_path).suffix.lower()
    if ext in (".mht", ".mhtml"):
        return "qq_mht"
    return "qq_txt"


def parse_qq_mht(file_path, target_name):
    with open(file_path, "r", encoding="utf-8", errors="ignore") as handle:
        content = handle.read()
    clean = re.sub(r"<[^>]+>", "\n", content)
    clean = re.sub(r"\n{3,}", "\n\n", clean)
    return clean


def auto_assign_me(resolver, messages):
    if resolver.me_aliases:
        return None
    candidates = []
    for sender in distinct_senders(messages):
        label, _, _ = resolver.resolve(sender, record=False)
        if label != "target":
            candidates.append(sender)
    if len(candidates) == 1:
        resolver.add_me_alias(candidates[0], note="自动识别")
        return candidates[0]
    return None


def main():
    parser = argparse.ArgumentParser(description="QQ 聊天记录解析器（带说话人归因）")
    parser.add_argument("--file", required=True, help="输入文件路径")
    parser.add_argument("--target", required=True, help="暗恋对象的名字/昵称（主别名）")
    parser.add_argument("--alias", action="append", default=[], help="ta 的其他别名，可重复传入")
    parser.add_argument("--me", action="append", default=[], help="你本人的昵称，可重复传入")
    parser.add_argument("--output", required=True, help="输出文件路径")
    parser.add_argument("--format", default="auto", help="文件格式 (auto/qq_txt/qq_mht)")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print("错误：文件不存在 %s" % args.file, file=sys.stderr)
        sys.exit(1)

    fmt = args.format
    if fmt == "auto":
        fmt = detect_format(args.file)
        print("自动检测格式：%s" % fmt)

    resolver = SpeakerResolver([args.target] + args.alias, args.me)
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)

    if fmt == "qq_mht":
        content = parse_qq_mht(args.file, args.target)
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(build_plaintext_fallback(args.target, args.file, content))
        print("MHT 格式已提取纯文本，但未识别发言者信息，请按提示手动标注")
        print("结果已写入 %s" % args.output)
        return 0

    lines = preprocess_qq_lines(args.file)
    messages, layout, orphan = parse_messages_from_lines(lines, resolver)

    if not messages or is_no_name_layout(layout):
        content = "".join(lines)
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(build_plaintext_fallback(args.target, args.file, content))
        print("⚠️ %s，已回退为带标注说明的原文导出"
              % ("未解析出任何消息" if not messages else "文件中没有发言者信息"))
        print("结果已写入 %s" % args.output)
        return 0

    auto_me = auto_assign_me(resolver, messages)
    records = annotate(messages, resolver)

    target_count = sum(1 for r in records if r["label"] == "target")
    me_count = sum(1 for r in records if r["label"] == "me")
    if not target_count:
        content = "".join(lines)
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(build_plaintext_fallback(args.target, args.file, content))
        print("⚠️ 没有识别出任何 ta 的消息（请检查 --target/--alias 或导出格式），已回退为原文导出")
        print("结果已写入 %s" % args.output)
        return 0

    report = build_report(args.target, args.file, fmt, layout, resolver, records, orphan)
    if auto_me:
        report = report.replace(
            "- 消息总数",
            "- 自动识别：「%s」被判为你本人（库内只有这一个非 ta 的发言人）\n- 消息总数" % auto_me,
            1)

    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(report)

    print("解析完成：共 %d 条 ｜ ta %d ｜ 我 %d ｜ 其他 %d"
          % (len(records), target_count, me_count, len(records) - target_count - me_count))
    if resolver.unknown_senders:
        print("⚠️ 未能确认身份的发言人：%s" % "、".join(resolver.unknown_senders))
    if not target_count:
        print("⚠️ ta 的消息数为 0，请检查 --target/--alias 或导出格式")
    print("结果已写入 %s" % args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
