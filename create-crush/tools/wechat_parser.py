#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""微信聊天记录解析器（v2：带说话人归因）

支持主流导出工具的格式：
- WeChatMsg 导出（txt/html/csv）
- 留痕导出（json）
- PyWxDump 导出（sqlite，需先转为 txt）
- 手动复制粘贴（纯文本）

相对 v1 的关键改动（修"我的话变成 ta 说的"）：
1. 不再用 `target_name in sender` 子串匹配；改为精确/去装饰匹配，**判不准就不猜**
2. 识别消息里的「引用块」并单独标出，不计入任何一方的语言特征
3. 输出双侧标注 `[ta] / [我] / [他人]`，并附「归因抽检」供人工核对
4. 解析不到 ta 的消息时明确报警，不再静默通过

Usage:
    python3 wechat_parser.py --file <path> --target "<昵称>" --output <out.md>
        [--alias "<别名>"]... [--me "<我的昵称>"]... [--format auto]
"""

import argparse
import json
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

TIMESTAMP_HINT_RE = re.compile(r"\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}")


def detect_format(file_path):
    ext = Path(file_path).suffix.lower()
    if ext == ".json":
        return "liuhen"
    if ext == ".csv":
        return "wechatmsg_csv"
    if ext in (".html", ".htm"):
        return "wechatmsg_html"
    if ext in (".db", ".sqlite"):
        return "pywxdump"
    if ext == ".txt":
        with open(file_path, "r", encoding="utf-8", errors="ignore") as handle:
            head = handle.read(3000)
        if TIMESTAMP_HINT_RE.search(head):
            return "wechatmsg_txt"
        return "plaintext"
    return "plaintext"


def load_txt_messages(file_path, resolver):
    with open(file_path, "r", encoding="utf-8", errors="ignore") as handle:
        lines = handle.readlines()
    return parse_messages_from_lines(lines, resolver)


def load_liuhen_messages(file_path, resolver):
    with open(file_path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    raw_list = data if isinstance(data, list) else data.get("messages", data.get("data", []))
    messages = []
    for item in raw_list:
        messages.append({
            "timestamp": str(item.get("time", item.get("timestamp", ""))),
            "sender": str(item.get("sender", item.get("nickname", item.get("from", "")))),
            "content": str(item.get("content", item.get("message", item.get("text", "")))),
        })
    return messages, "JSON 结构", 0


def auto_assign_me(resolver, messages):
    """未指定 --me 时：若只有一个非 ta 的发言人，自动认定为你本人。"""
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


def emit_fallback(args, reason):
    with open(args.file, "r", encoding="utf-8", errors="ignore") as handle:
        content = handle.read()
    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(build_plaintext_fallback(args.target, args.file, content))
    print("⚠️ %s，已回退为带标注说明的原文导出" % reason)
    print("结果已写入 %s" % args.output)
    return 0


def main():
    parser = argparse.ArgumentParser(description="微信聊天记录解析器（带说话人归因）")
    parser.add_argument("--file", required=True, help="输入文件路径")
    parser.add_argument("--target", required=True, help="暗恋对象的名字/昵称（主别名）")
    parser.add_argument("--alias", action="append", default=[],
                        help="ta 的其他别名/备注名/群昵称，可重复传入")
    parser.add_argument("--me", action="append", default=[],
                        help="你本人的昵称/备注名，可重复传入（不传则自动识别）")
    parser.add_argument("--output", required=True, help="输出文件路径")
    parser.add_argument("--format", default="auto",
                        help="文件格式 (auto/wechatmsg_txt/liuhen/plaintext)")
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

    if fmt == "plaintext":
        return emit_fallback(args, "未识别到发言者信息")

    if fmt == "liuhen":
        messages, layout, orphan = load_liuhen_messages(args.file, resolver)
    else:
        messages, layout, orphan = load_txt_messages(args.file, resolver)

    if not messages:
        return emit_fallback(args, "未解析出任何消息（格式可能不受支持）")

    if is_no_name_layout(layout):
        return emit_fallback(args, "文件中没有发言者信息（时间+内容排版），无法区分双方")

    auto_me = auto_assign_me(resolver, messages)
    records = annotate(messages, resolver)

    target_count = sum(1 for r in records if r["label"] == "target")
    me_count = sum(1 for r in records if r["label"] == "me")
    if not target_count:
        return emit_fallback(
            args, "没有识别出任何 ta 的消息（请检查 --target/--alias 或导出格式）")

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
    if resolver.fuzzy_suspects:
        print("⚠️ 有发言人昵称含 ta 的名字但未被并入 ta：%s"
              % "、".join(resolver.fuzzy_suspects))
    if resolver.unknown_senders:
        print("⚠️ 未能确认身份的发言人：%s" % "、".join(resolver.unknown_senders))
    if not target_count:
        print("⚠️ ta 的消息数为 0，请检查 --target/--alias 或导出格式")
    print("结果已写入 %s" % args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
