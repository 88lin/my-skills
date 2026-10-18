#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""chat_attribution.py —— 聊天记录「说话人归因」共用模块

解决的问题：原解析器用 `target_name in sender` 做子串匹配，导致
  1. 昵称里含目标名（如"小雨的迷弟"）的我方消息被判成对方的
  2. 对方消息里的「引用块」被当成对方的话写进语料
  3. 格式不符时静默解析出 0 条

设计原则：**宁可标"未知"，绝不猜身份**。判不准的一律不进 ta 的语料，
并在报告里显式警告，让用户用 --alias 补齐。

只依赖标准库，兼容 Python 3.9。
"""

import re

TIMESTAMP_RE = re.compile(
    r"^\s*\[?(\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}(?::\d{2})?)\]?\s*(.*)$"
)

EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u200D\u2764\u2665\u2661]"
)
PAREN_RE = re.compile(r"[（(\[【][^）)\]】]{0,16}[）)\]】]")
DECOR_RE = re.compile(r"[\s·•、,，.。\-—_~～^]+")
NAME_PUNCT_RE = re.compile(r"[，。！？；、,.;!?：:…~～]")

QUOTE_BRACKET_RE = re.compile(r"^[「『](.+?)[」』]\s*(.*)$")
QUOTE_MARK_RE = re.compile(r'^[“"](.+?)[”"]\s*(.*)$')
MD_QUOTE_RE = re.compile(r"^>\s?(.*)$")

STATUS_LABEL = {
    "target": "ta",
    "me": "我",
    "other": "他人",
    "unknown": "未知",
}


def normalize_name(name):
    """去装饰后用于比较：去 emoji、括号备注、符号与空白，转小写。"""
    text = (name or "").strip()
    text = EMOJI_RE.sub("", text)
    text = PAREN_RE.sub("", text)
    text = DECOR_RE.sub("", text)
    return text.lower()


def looks_like_name(text):
    """判断一行像不像「昵称」——不确定时返回 False（宁可当内容）。"""
    value = (text or "").strip()
    if not value:
        return False
    if len(value) > 16:
        return False
    if NAME_PUNCT_RE.search(value):
        return False
    if len(re.findall(r"\d", value)) > 6:
        return False
    return True


class SpeakerResolver:
    """身份判定：精确 > 去装饰 > 存疑（不猜）。"""

    def __init__(self, target_aliases=None, me_aliases=None):
        self.target_aliases = [a for a in (target_aliases or []) if a and a.strip()]
        self.me_aliases = [a for a in (me_aliases or []) if a and a.strip()]
        self._target = {normalize_name(a): a for a in self.target_aliases}
        self._me = {normalize_name(a): a for a in self.me_aliases}
        self.stats = {"exact": 0, "decorated": 0, "fuzzy_suspect": 0, "unknown": 0}
        self.fuzzy_suspects = {}   # 发言人 -> 疑似命中的别名
        self.unknown_senders = {}  # 发言人 -> 条数

    def _candidates(self, norm):
        values = {norm}
        if "@" in norm:
            values.add(norm.split("@")[0])
        return {v for v in values if v}

    def resolve(self, sender, record=True):
        """返回 (label, confidence, matched_alias)；label ∈ target/me/other/unknown。

        record=False 用于预扫描，不污染统计。
        """
        raw = (sender or "").strip()
        if not raw:
            if record:
                self.stats["unknown"] += 1
            return ("unknown", "empty", "")
        norm = normalize_name(raw)
        for candidate in self._candidates(norm):
            if candidate in self._target:
                if record:
                    self.stats["exact"] += 1
                return ("target", "exact", self._target[candidate])
            if candidate in self._me:
                if record:
                    self.stats["exact"] += 1
                return ("me", "exact", self._me[candidate])
        if norm in self._target:
            if record:
                self.stats["decorated"] += 1
            return ("target", "decorated", self._target[norm])

        # 子串命中：极可能是我方的昵称里带了目标名，**不猜**，标为待确认
        for alias_norm, alias in list(self._target.items()) + list(self._me.items()):
            if alias_norm and len(alias_norm) >= 2 and alias_norm in norm and norm != alias_norm:
                if record:
                    self.stats["fuzzy_suspect"] += 1
                    self.fuzzy_suspects[raw] = alias
                return ("other", "fuzzy_suspect", alias)

        if record:
            self.stats["unknown"] += 1
            self.unknown_senders[raw] = self.unknown_senders.get(raw, 0) + 1
        return ("other", "unknown", "")

    def add_me_alias(self, alias, note=""):
        label = alias if not note else "%s（%s）" % (alias, note)
        if alias and alias not in self.me_aliases:
            self._me[normalize_name(alias)] = alias
            self.me_aliases.append(label)

    @property
    def needs_confirmation(self):
        return bool(self.fuzzy_suspects or self.unknown_senders)


def distinct_senders(messages):
    seen = []
    for msg in messages:
        sender = (msg.get("sender") or "").strip()
        if sender and sender not in seen:
            seen.append(sender)
    return seen


def strip_quotes(content):
    """拆出本人文本与引用块。引用块里的内容不是发言者的话。"""
    own_lines = []
    quoted = []
    for line in (content or "").split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        md = MD_QUOTE_RE.match(stripped)
        if md:
            quoted.append(md.group(1).strip())
            continue
        match = QUOTE_BRACKET_RE.match(stripped) or QUOTE_MARK_RE.match(stripped)
        if match:
            quoted.append(match.group(1).strip())
            rest = match.group(2).strip()
            if rest:
                own_lines.append(rest)
            continue
        own_lines.append(line)
    return "\n".join(own_lines).strip(), quoted


def split_sender_content(rest):
    """把 '昵称' / '昵称: 内容' / '内容' 拆开。不确定时按内容处理。"""
    text = (rest or "").strip()
    if not text:
        return ("", "")
    for sep in ("：", ":"):
        if sep in text:
            head, _, tail = text.partition(sep)
            if looks_like_name(head):
                return (head.strip(), tail.strip())
    if looks_like_name(text):
        return (text, "")
    return ("", text)


def detect_layout(lines):
    """探测排版：昵称在时间前 / 时间后 / 文件里根本没有昵称。

    返回 (position, hint)：position ∈ before/after/mixed；hint ∈ ''/no_name
    """
    name_after = 0
    name_before = 0
    sentence_like = 0
    previous = None
    for raw in lines:
        stripped = (raw or "").strip()
        if not stripped:
            continue
        match = TIMESTAMP_RE.match(stripped)
        if match:
            rest = match.group(2).strip()
            if rest:
                if looks_like_name(rest):
                    name_after += 1
                else:
                    sentence_like += 1
            elif previous and looks_like_name(previous):
                name_before += 1
            previous = None
            continue
        previous = stripped

    if name_before >= 2 and name_before > name_after:
        return "before", ""
    if name_after >= 2 and name_after >= name_before:
        return "after", ""
    total = name_after + name_before + sentence_like
    if total >= 2 and sentence_like == total and name_before == 0:
        return "mixed", "no_name"
    return "mixed", ""


def next_nonempty(lines, start):
    for index in range(start, len(lines)):
        if lines[index].strip():
            return lines[index].strip()
    return None


def parse_messages_from_lines(lines, resolver):
    """按行解析，容忍多种排版（昵称可写在时间前或时间后）。"""
    messages = []
    current = None
    orphan = 0
    ts_with_name = 0
    ts_without_name = 0
    position, hint = detect_layout(lines)
    pending_name = None

    def flush():
        nonlocal current
        if current:
            current.pop("_pending_name", None)
            messages.append(current)
            current = None

    for index, raw_line in enumerate(lines):
        line = raw_line.rstrip("\n")
        if not line.strip():
            continue
        if line.strip().startswith("==="):
            continue
        match = TIMESTAMP_RE.match(line)
        if not match:
            following = next_nonempty(lines, index + 1)
            is_name_marker = bool(following and TIMESTAMP_RE.match(following))
            if is_name_marker and looks_like_name(line):
                # 「昵称行紧跟着时间行」= 这条消息的发言人（与本行内容无关）
                if position == "before" or resolver.resolve(line, record=False)[0] != "other":
                    flush()
                    pending_name = line.strip()
                    continue
            if current is None:
                orphan += 1
                continue
            if current.pop("_pending_name", False) and not current["sender"]:
                if looks_like_name(line):
                    current["sender"] = line.strip()
                    ts_with_name += 1
                    continue
                current["content"] = line
                ts_without_name += 1
                continue
            current["content"] = (current["content"] + "\n" + line) if current["content"] else line
            continue

        timestamp, rest = match.group(1), match.group(2).strip()
        flush()
        if not rest:
            if pending_name:
                current = {"timestamp": timestamp, "sender": pending_name, "content": ""}
                pending_name = None
                ts_with_name += 1
            else:
                current = {"timestamp": timestamp, "sender": "", "content": "",
                           "_pending_name": True}
                ts_without_name += 1
            continue
        sender, content = split_sender_content(rest)
        if not sender and pending_name:
            sender = pending_name
        pending_name = None
        if sender:
            ts_with_name += 1
        else:
            ts_without_name += 1
        current = {"timestamp": timestamp, "sender": sender, "content": content}
    flush()

    if hint == "no_name":
        layout = "时间+内容（文件里没有发言者信息）"
    elif position == "before":
        layout = "昵称+时间"
    elif ts_with_name and ts_with_name >= ts_without_name:
        layout = "时间+昵称"
    elif ts_with_name == 0 and ts_without_name:
        layout = "时间+内容（无昵称）"
    else:
        layout = "混合排版"
    return messages, layout, orphan


def is_no_name_layout(layout):
    return "没有发言者信息" in (layout or "")


def side_stats(messages):
    """单侧语言特征统计（已排除引用块）。"""
    texts = [m.get("own_text", "") for m in messages if m.get("own_text")]
    joined = " ".join(texts)
    particles = re.findall(r"[哈嗯哦噢嘿唉呜啊呀吧嘛呢吗么]+", joined)
    freq = {}
    for item in particles:
        freq[item] = freq.get(item, 0) + 1
    emoji_freq = {}
    for item in EMOJI_RE.findall(joined):
        emoji_freq[item] = emoji_freq.get(item, 0) + 1
    lengths = [len(t) for t in texts]
    endings = {}
    for text in texts:
        tail = re.sub(r"[\s，。！？、…—～~!?,.;:'\"]+$", "", text.strip())
        if not tail:
            continue
        key = "反问" if re.search(r"[?？]|[吗么呢]$", tail) else "陈述"
        endings[key] = endings.get(key, 0) + 1
    return {
        "count": len(messages),
        "avg_length": round(sum(lengths) / len(lengths), 1) if lengths else 0,
        "top_particles": sorted(freq.items(), key=lambda x: -x[1])[:8],
        "top_emojis": sorted(emoji_freq.items(), key=lambda x: -x[1])[:8],
        "endings": endings,
        "quote_blocks": sum(len(m.get("quoted") or []) for m in messages),
    }


def build_rhythm(messages):
    """互动节奏：谁先开口 / 平均回复间隔 / 谁更常收尾。"""
    ordered = [m for m in messages if m.get("_order") is not None]
    ordered.sort(key=lambda m: m["_order"])
    if not ordered:
        return {}
    sessions = 0
    target_first = 0
    reply_gaps = []
    last_ts = None
    starter = None
    for msg in ordered:
        ts = msg.get("_ts")
        if last_ts is None or (ts is not None and ts - last_ts > 1800):
            sessions += 1
            starter = msg.get("label")
            if starter == "target":
                target_first += 1
        elif ts is not None and last_ts is not None:
            gap = ts - last_ts
            if 0 < gap <= 1800:
                reply_gaps.append(gap)
        if ts is not None:
            last_ts = ts
    tail_label = ordered[-1].get("label")
    return {
        "sessions": sessions,
        "target_starts": target_first,
        "avg_reply_gap_sec": round(sum(reply_gaps) / len(reply_gaps), 1) if reply_gaps else None,
        "last_speaker": STATUS_LABEL.get(tail_label, tail_label),
    }


def to_timestamp(value):
    """把 '2024-03-02 21:14:32' 转成秒级时间戳，失败返回 None。"""
    try:
        import time
        pattern = "%Y-%m-%d %H:%M:%S" if value.count(":") == 2 else "%Y-%m-%d %H:%M"
        normalized = value.replace("/", "-")
        parts = normalized.split(" ")
        head = parts[0].split("-")
        normalized = "%04d-%02d-%02d %s" % (int(head[0]), int(head[1]), int(head[2]), parts[1])
        return time.mktime(time.strptime(normalized, pattern))
    except Exception:
        return None


def annotate(messages, resolver):
    """给每条消息打上身份标签与引用拆分结果。"""
    result = []
    for index, msg in enumerate(messages):
        label, confidence, alias = resolver.resolve(msg.get("sender", ""))
        own, quoted = strip_quotes(msg.get("content", ""))
        record = dict(msg)
        record.update({
            "label": label,
            "label_text": STATUS_LABEL[label],
            "confidence": confidence,
            "matched_alias": alias,
            "own_text": own,
            "quoted": quoted,
            "_order": index,
            "_ts": to_timestamp(msg.get("timestamp", "")),
        })
        result.append(record)
    return result


def build_report(target_name, source_file, fmt, layout, resolver, records, orphan):
    target_msgs = [m for m in records if m["label"] == "target"]
    me_msgs = [m for m in records if m["label"] == "me"]
    other_msgs = [m for m in records if m["label"] in ("other", "unknown")]
    target_stats = side_stats(target_msgs)
    me_stats = side_stats(me_msgs)
    rhythm = build_rhythm(records)

    lines = []
    lines.append("# 聊天记录分析 — %s" % target_name)
    lines.append("")
    lines.append("- 来源文件：%s" % source_file)
    lines.append("- 检测格式：%s（排版：%s）" % (fmt, layout))
    lines.append("- 身份判定：ta = %s｜我 = %s" % (
        "、".join(resolver.target_aliases) or "（未提供）",
        "、".join(resolver.me_aliases) or "（未提供，靠排除法）"))
    lines.append("- 消息总数 %d ｜ [ta] %d ｜ [我] %d ｜ [他人/未知] %d ｜ 引用块 %d"
                 % (len(records), len(target_msgs), len(me_msgs), len(other_msgs),
                    target_stats["quote_blocks"] + me_stats["quote_blocks"]))
    if orphan:
        lines.append("- 未归属行（缺时间戳）：%d 行，已跳过" % orphan)
    lines.append("")

    # ---- 归因警告 ----
    warnings = []
    me_norms = {normalize_name(a) for a in resolver.me_aliases}
    unresolved = {sender: alias for sender, alias in resolver.fuzzy_suspects.items()
                  if normalize_name(sender) not in me_norms}
    if unresolved:
        pairs = ["%s（疑似含 ta 的别名「%s」）" % (sender, alias)
                 for sender, alias in unresolved.items()]
        warnings.append("以下发言人被判为「他人」——昵称里含 ta 的名字，**未并入 ta**：%s。"
                        "如果其中确实有 ta（小号/备注名），请追加 --alias 重跑。" % "、".join(pairs))
    if resolver.unknown_senders:
        top = sorted(resolver.unknown_senders.items(), key=lambda x: -x[1])[:6]
        warnings.append("未能确认身份的发言人：%s。若其中包含 ta 或你本人，请用 --target / --me 指定别名。"
                        % "、".join("%s(%d条)" % (k, v) for k, v in top))
    if not target_msgs:
        warnings.append("**ta 的消息数为 0**：解析可能失败或身份判定全未命中。"
                        "请检查导出格式，或改用 --format plaintext 配合手动标注。")
    if me_msgs and not resolver.me_aliases:
        warnings.append("你本人未指定别名，「我」这一侧由排除法推定——"
                        "群友与系统消息也会落进来，引用统计时请注意。")
    if warnings:
        lines.append("## ⚠️ 归因警告（务必先看）")
        lines.append("")
        for item in warnings:
            lines.append("- %s" % item)
        lines.append("")

    # ---- 归因抽检 ----
    lines.append("## 归因抽检（请核对：以下原话是否确实出自 ta）")
    lines.append("")
    sample = [m for m in target_msgs if m["own_text"]][:5]
    if sample:
        for index, msg in enumerate(sample, 1):
            text = msg["own_text"].replace("\n", " / ")[:60]
            lines.append("%d. [%s] %s  %s" % (
                index, msg["label_text"], msg.get("timestamp", ""), text))
    else:
        lines.append("（无 ta 的可用消息，无法抽检）")
    lines.append("")

    # ---- ta 的语言特征 ----
    lines.append("## ta 的语言特征（仅统计 [ta]，已排除引用块）")
    lines.append("")
    lines.append("- 消息数：%d ｜ 平均长度：%s 字" % (target_stats["count"], target_stats["avg_length"]))
    if target_stats["top_particles"]:
        lines.append("- 高频语气词：%s" % "、".join(
            "%s×%d" % (w, c) for w, c in target_stats["top_particles"]))
    if target_stats["top_emojis"]:
        lines.append("- 高频 emoji：%s" % "、".join(
            "%s×%d" % (w, c) for w, c in target_stats["top_emojis"]))
    if target_stats["endings"]:
        lines.append("- 收尾方式：%s" % "、".join(
            "%s×%d" % (k, v) for k, v in target_stats["endings"].items()))
    lines.append("- 风格：%s" % ("短句连发型" if target_stats["avg_length"] < 20 else "长段落型"))
    lines.append("")

    # ---- 双人对照 ----
    lines.append("## 双人对照（照镜子模式可直接用）")
    lines.append("")
    lines.append("| 指标 | ta | 我 |")
    lines.append("|------|----|----|")
    lines.append("| 消息条数 | %d | %d |" % (target_stats["count"], me_stats["count"]))
    lines.append("| 平均长度 | %s 字 | %s 字 |" % (target_stats["avg_length"], me_stats["avg_length"]))
    lines.append("| 高频语气词 | %s | %s |" % (
        "、".join(w for w, _ in target_stats["top_particles"][:4]) or "—",
        "、".join(w for w, _ in me_stats["top_particles"][:4]) or "—"))
    lines.append("| 高频 emoji | %s | %s |" % (
        "、".join(w for w, _ in target_stats["top_emojis"][:4]) or "—",
        "、".join(w for w, _ in me_stats["top_emojis"][:4]) or "—"))
    lines.append("")
    if rhythm:
        lines.append("## 互动节奏")
        lines.append("")
        lines.append("- 对话段数（间隔 30 分钟切开）：%s ｜ ta 先开口：%s 次"
                     % (rhythm.get("sessions"), rhythm.get("target_starts")))
        gap = rhythm.get("avg_reply_gap_sec")
        lines.append("- 平均回复间隔：%s" % ("%.0f 秒" % gap if gap else "—"))
        lines.append("- 最后一条来自：%s" % rhythm.get("last_speaker"))
        lines.append("")

    # ---- 回合样本 ----
    lines.append("## 回合样本（前 20 组，含双方）")
    lines.append("")
    rounds = []
    pending_me = []
    for msg in records:
        text = msg["own_text"] or ("（引用）" if msg["quoted"] else "")
        if not text:
            continue
        if msg["label"] == "me":
            pending_me.append(text)
        elif msg["label"] == "target":
            pair = (" / ".join(pending_me), text) if pending_me else ("（不含你的话）", text)
            rounds.append(pair)
            pending_me = []
        if len(rounds) >= 20:
            break
    if rounds:
        for index, (mine, hers) in enumerate(rounds, 1):
            lines.append("%d. [我] %s" % (index, mine.replace("\n", " ")[:70]))
            lines.append("   [ta] %s" % hers.replace("\n", " ")[:70])
    else:
        lines.append("（未能配对出回合，可能缺少「我」侧消息或身份判定未命中）")
    lines.append("")

    # ---- 使用纪律 ----
    lines.append("## 原材料使用纪律（生成 persona / memory 时必须遵守）")
    lines.append("")
    lines.append("1. 只有标注为 `[ta]` 的内容可以计入 ta 的口头禅、兴趣与语言风格")
    lines.append("2. 标注为 `[我]` 的内容只能用于「共同经历」「互动模式」，**不得**变成 ta 的特征")
    lines.append("3. 引用块内容不计入任何一方的语言特征")
    lines.append("4. 若上方统计与你的记忆不符，说明归因可能有误：追加 `--alias` 或手动标注后重跑")
    lines.append("")
    return "\n".join(lines)


def build_plaintext_fallback(target_name, source_file, content, limit=20000):
    """无发言者信息时的兜底：原样导出并附手动标注说明。"""
    return "\n".join([
        "# 聊天记录分析 — %s（未识别发言者信息）" % target_name,
        "",
        "- 来源文件：%s" % source_file,
        "- 解析结果：**未能从文件里识别出「谁说的」**，因此不做任何归因统计。",
        "- 原因：文件缺少昵称字段，或排版不被支持。",
        "",
        "## 请手动标注后再用（任选一种）",
        "",
        "1. 在原文每行前加上 `[ta]` 或 `[我]`，例如：",
        "   ```",
        "   [我] 在干嘛",
        "   [ta] 加班呢",
        "   ```",
        "2. 或改用带昵称的导出格式（WeChatMsg 导出 txt/html/csv），并用 `--alias` 指定 ta 的昵称",
        "",
        "> 未标注的原文仅作参考，**不要**直接当作 ta 的语言素材。",
        "",
        "## 原文（截取前 %d 字）" % limit,
        "",
        content[:limit],
        "",
    ])
