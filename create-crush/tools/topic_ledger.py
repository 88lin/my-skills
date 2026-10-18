#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""topic_ledger.py —— 反单调对话引擎的账本层（B 档）

职责（只做账本与算术，不生成）：
  1. 从 persona.md 的「口头禅与细节引用表」初始化配额配置
  2. 校验候选回复的话题 / 锚点 / 口头禅是否超配额
  3. 给候选打分（供模型在 3 条候选里择优）
  4. 提交记账 + 输出退化报告（重复度曲线、话题熵）

用法：
  python3 tools/topic_ledger.py --slug xiaomei --action init \
      --from-persona crushes/xiaomei/persona.md
  python3 tools/topic_ledger.py --slug xiaomei --action check --turn 12 \
      --candidate "topic=听歌|anchor=听歌|catch=笑死"
  python3 tools/topic_ledger.py --slug xiaomei --action commit --turn 12 \
      --topics "加班,游戏" --anchors "加班" --catch ""
  python3 tools/topic_ledger.py --slug xiaomei --action report
  python3 tools/topic_ledger.py --selftest
"""

import argparse
import math
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

ANCHOR_COOLDOWN_TURNS = 3
TOPIC_REPEAT_LOOKBACK = 2
DEFAULT_LIMITS = {"强": {"window": 8, "limit": 1}, "中": {"window": 5, "limit": 1}}
WEAK_EVIDENCE_THRESHOLD = 3
TEMP_RANK = {"冷": 0, "温": 1, "热": 2}
TEMP_ALIAS = {
    "热": "热", "热情": "热", "热恋": "热",
    "温": "温", "温柔": "温", "软": "温", "平常": "温",
    "冷": "冷", "冷淡": "冷", "高冷": "冷",
}
DEFAULT_BASE_TEMP = "温"
ADVICE = {
    "weak_anchor": "这个细节在素材里只出现过 %d 次，不能当回复锚点；换成用户刚说过的事",
    "anchor_cooldown": "这个锚点近 %d 轮刚用过，冷却中，换一个",
    "quota_exceeded": "「%s」在 %d 轮内已用 %d 次，超配额；这轮别提它",
    "topic_repeat": "话题和上一轮重复了，至少推进一步或换角度",
    "temp_mismatch": "温度和 ta 的基线（%s）差太远且没有事由，出戏了；用 ta 平时的温度说话",
}


def normalize_temp(raw):
    if not raw:
        return None
    return TEMP_ALIAS.get(raw.strip())


def temperature_fit(candidate_temp, base_temp):
    """温度契合度：同档 1.0，相邻 0.5，对立 0.0，未标注 0.8（不奖不罚）。"""
    cand = normalize_temp(candidate_temp)
    base = base_temp if base_temp in TEMP_RANK else DEFAULT_BASE_TEMP
    if cand is None:
        return 0.8, None
    diff = abs(TEMP_RANK[cand] - TEMP_RANK[base])
    if diff == 0:
        return 1.0, None
    if diff == 1:
        return 0.5, None
    return 0.0, "温度「%s」与 ta 基线「%s」对立且无事由" % (cand, base)


def split_values(raw):
    if not raw:
        return []
    parts = re.split(r"[,，;；/\s]+", raw.strip())
    return [p for p in parts if p]


def parse_candidate(raw):
    """解析 'topic=听歌|anchor=听歌|catch=笑死|temp=温'。"""
    result = {"topics": [], "anchors": [], "catch": [], "temp": None}
    if not raw:
        return result
    for chunk in re.split(r"[|｜]", raw):
        if not chunk.strip():
            continue
        if "=" in chunk:
            key, _, value = chunk.partition("=")
        else:
            key, value = "topic", chunk
        key = key.strip().lower()
        values = split_values(value)
        if key in ("topic", "topics", "话题"):
            result["topics"].extend(values)
        elif key in ("anchor", "anchors", "锚点"):
            result["anchors"].extend(values)
        elif key in ("catch", "catchphrase", "口头禅"):
            result["catch"].extend(values)
        elif key in ("temp", "temperature", "温度"):
            result["temp"] = value.strip()
    return result


def to_int(text):
    digits = re.findall(r"\d+", text or "")
    return int(digits[0]) if digits else None


def clean_feature(name):
    """去掉表格单元里的引号、星号、括号备注等装饰。"""
    if not name:
        return ""
    cleaned = name.strip()
    cleaned = re.sub(r"^[`*_\"'\u201c\u201d\u2018\u2019\s]+", "", cleaned)
    cleaned = re.sub(r"[`*_\"'\u201c\u201d\u2018\u2019\s]+$", "", cleaned)
    cleaned = re.sub(r"[（(].*?[）)]", "", cleaned)
    return cleaned.strip()


def find_rule(config, name):
    """同名或互相包含都算命中（锚点标签不要求与表里完全一致）。"""
    if not name or not config:
        return None
    target = clean_feature(name)
    if target in config:
        return config[target]
    best_key = None
    for key in config:
        if len(target) >= 2 and (target in key or key in target):
            if best_key is None or len(key) > len(best_key):
                best_key = key
    return config[best_key] if best_key else None


def parse_persona_table(path):
    """解析 persona.md 里的「口头禅与细节引用表」。"""
    config = {}
    if not path or not os.path.exists(path):
        return config
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    for line in lines:
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            continue
        feature, evidence_cell, strength_cell, quota_cell = cells[0], cells[1], cells[2], cells[3]
        feature_name = clean_feature(feature)
        if not feature_name or set(feature) <= set("-: ") or "特征" in feature or "证据" in evidence_cell:
            continue
        evidence = to_int(evidence_cell)
        if evidence is None:
            continue
        quota = quota_cell or ""
        banned = ("禁止" in quota) or ("不得" in quota) or ("弱" in strength_cell) \
            or evidence < WEAK_EVIDENCE_THRESHOLD
        window = to_int(quota)
        limit = None
        if "/" in quota or "次" in quota:
            numbers = re.findall(r"\d+", quota)
            if len(numbers) >= 2:
                limit, window = int(numbers[0]), int(numbers[1])
        if limit is None:
            fallback = DEFAULT_LIMITS.get(strength_cell.strip(), DEFAULT_LIMITS["中"])
            limit, window = fallback["limit"], fallback["window"]
        if window is None or window < limit:
            window = DEFAULT_LIMITS["中"]["window"]
        config[feature_name] = {
            "evidence": evidence,
            "strength": strength_cell,
            "banned_as_anchor": banned,
            "window": window if not banned else 0,
            "limit": limit,
            "raw_quota": quota,
        }
    return config


def usage_in_window(turns, field, value, window, before_turn=None):
    """统计最近 window 轮里某字段出现 value 的次数。"""
    if window <= 0:
        return 0
    count = 0
    for record in turns:
        for item in record.get(field) or []:
            if item == value:
                count += 1
    return count


def check_candidate(state, parsed, turn_no, adaptive=None):
    adaptive = adaptive or {}
    quota_scale = adaptive.get("quota_scale", BASELINE_ADAPTIVE["quota_scale"])
    whitelist = adaptive.get("whitelist") or []
    cooldown = max(2, int(round(ANCHOR_COOLDOWN_TURNS * quota_scale)))

    config = state.get("quota_config") or {}
    history = [t for t in state.get("turns", []) if t.get("turn") is not None
               and (turn_no is None or t["turn"] < turn_no)]
    history.sort(key=lambda r: r["turn"])

    violations = []
    advice = []

    anchors = parsed["anchors"]
    topics = parsed["topics"]
    catch = parsed["catch"]

    for anchor in anchors:
        if anchor in whitelist:
            continue
        rule = find_rule(config, anchor)
        if rule and rule.get("banned_as_anchor"):
            violations.append({
                "type": "weak_anchor",
                "level": "veto",
                "detail": "锚点「%s」证据仅 %d 条（强度%s）" % (
                    anchor, rule.get("evidence", 0), rule.get("strength", "?")),
            })
            advice.append(ADVICE["weak_anchor"] % rule.get("evidence", 0))
            continue
        recent = history[-cooldown:]
        if usage_in_window(recent, "anchors", anchor, cooldown) > 0:
            violations.append({
                "type": "anchor_cooldown",
                "level": "veto",
                "detail": "锚点「%s」近 %d 轮内已用过" % (anchor, cooldown),
            })
            advice.append(ADVICE["anchor_cooldown"] % cooldown)
            continue
        if rule:
            window = int(round((rule.get("window") or 0) * quota_scale))
            used = usage_in_window(history[-window:] if window else [], "anchors", anchor, window)
            if window and used >= rule.get("limit", 1):
                violations.append({
                    "type": "quota_exceeded",
                    "level": "veto",
                    "detail": "锚点「%s」%d 轮内已用 %d 次（上限 %d）" % (
                        anchor, window, used, rule.get("limit", 1)),
                })
                advice.append(ADVICE["quota_exceeded"] % (anchor, window, used))

    for phrase in catch:
        if phrase in whitelist:
            continue
        rule = find_rule(config, phrase)
        window = rule.get("window") if rule else DEFAULT_LIMITS["强"]["window"]
        limit = rule.get("limit") if rule else DEFAULT_LIMITS["强"]["limit"]
        window = int(round((window or DEFAULT_LIMITS["强"]["window"]) * quota_scale))
        used = usage_in_window(history[-window:], "catch", phrase, window)
        if used >= limit:
            violations.append({
                "type": "quota_exceeded",
                "level": "veto",
                "detail": "口头禅「%s」%d 轮内已用 %d 次（上限 %d）" % (phrase, window, used, limit),
            })
            advice.append(ADVICE["quota_exceeded"] % (phrase, window, used))

    for topic in topics:
        recent = history[-TOPIC_REPEAT_LOOKBACK:]
        if usage_in_window(recent, "topics", topic, TOPIC_REPEAT_LOOKBACK) > 0:
            violations.append({
                "type": "topic_repeat",
                "level": "warn",
                "detail": "话题「%s」近 %d 轮内出现过" % (topic, TOPIC_REPEAT_LOOKBACK),
            })
            advice.append(ADVICE["topic_repeat"])

    levels = [v["level"] for v in violations]
    verdict = "veto" if "veto" in levels else ("warn" if "warn" in levels else "ok")

    consistency = 0.9 if (anchors and all(find_rule(config, a) for a in anchors)) else (
        0.8 if not anchors else 0.7)
    progression = 0.2 if any(v["type"] == "topic_repeat" for v in violations) else 1.0
    novelty = 1.0
    for anchor in anchors:
        if usage_in_window(history, "anchors", anchor, len(history) or 1) > 0:
            novelty = 0.2
    repetition = 0.0
    total_history = len(history)
    for anchor in anchors:
        uses = usage_in_window(history, "anchors", anchor, total_history or 1)
        repetition = max(repetition, min(1.0, 0.34 * uses))

    base_temp = state.get("base_temp") or DEFAULT_BASE_TEMP
    temp_fit, temp_note = temperature_fit(parsed.get("temp"), base_temp)
    if temp_note:
        violations.append({
            "type": "temp_mismatch",
            "level": "warn",
            "detail": temp_note + "（若本轮确有事由可忽略此条）",
        })
        advice.append(ADVICE["temp_mismatch"] % base_temp)

    levels = [v["level"] for v in violations]
    verdict = "veto" if "veto" in levels else ("warn" if "warn" in levels else "ok")

    score = round(
        0.4 * consistency + 0.25 * temp_fit + 0.2 * progression + 0.15 * novelty
        - 0.4 * repetition, 3)

    return {
        "turn": turn_no,
        "verdict": verdict,
        "score": score,
        "breakdown": {
            "consistency": consistency,
            "temperature_fit": temp_fit,
            "progression": progression,
            "novelty": novelty,
            "repetition": round(repetition, 3),
        },
        "base_temp": base_temp,
        "violations": violations,
        "advice": advice,
        "parsed": parsed,
        "adaptive": {
            "quota_scale": quota_scale,
            "cooldown_turns": cooldown,
            "whitelist": whitelist,
        },
    }


def build_report(state):
    turns = sorted([t for t in state.get("turns", []) if t.get("turn") is not None],
                   key=lambda r: r["turn"])
    topic_counter = {}
    for record in turns:
        for topic in record.get("topics") or []:
            topic_counter[topic] = topic_counter.get(topic, 0) + 1
    total_topics = sum(topic_counter.values())
    entropy = 0.0
    for count in topic_counter.values():
        p = count / total_topics
        entropy -= p * math.log(p, 2)
    jaccards = [t.get("jaccard_max") for t in turns if t.get("jaccard_max") is not None]
    escapes = sum(len(t.get("escape_hits") or []) for t in turns)
    violation_counter = {}
    for entry in state.get("violations", []):
        for item in entry.get("items", []):
            key = item.get("type")
            violation_counter[key] = violation_counter.get(key, 0) + 1
    return {
        "turns": len(turns),
        "topic_distribution": topic_counter,
        "topic_entropy_bits": round(entropy, 2),
        "avg_jaccard": round(sum(jaccards) / len(jaccards), 3) if jaccards else None,
        "max_jaccard": max(jaccards) if jaccards else None,
        "escape_phrase_total": escapes,
        "violation_summary": violation_counter,
        "quota_config_size": len(state.get("quota_config") or {}),
    }


def build_parser():
    parser = argparse.ArgumentParser(description="反单调对话引擎 · 话题账本与配额裁判")
    parser.add_argument("--state", help="状态文件路径")
    parser.add_argument("--slug", help="暗恋对象 slug")
    parser.add_argument("--base-dir", default="crushes")
    parser.add_argument("--action", required=False,
                        choices=["init", "check", "commit", "report"], default="report")
    parser.add_argument("--from-persona", dest="from_persona", help="persona.md 路径")
    parser.add_argument("--turn", type=int, help="轮次号")
    parser.add_argument("--candidate", help="候选标签：topic=x|anchor=y|catch=z")
    parser.add_argument("--topics", help="本轮实际使用的话题，逗号分隔")
    parser.add_argument("--anchors", help="本轮实际使用的锚点，逗号分隔")
    parser.add_argument("--catch", help="本轮实际使用的口头禅，逗号分隔")
    parser.add_argument("--adaptive", help="自适应配置文件路径（默认 crushes/{slug}/adaptive.json）")
    parser.add_argument("--base-temp", dest="base_temp", choices=["冷", "温", "热"],
                        help="ta 的基线情绪温度（init 时写入，默认「温」，应与 persona 情感模式一致）")
    parser.add_argument("--selftest", action="store_true")
    return parser


def run_selftest():
    config = {
        "笑死": {"evidence": 12, "strength": "强", "banned_as_anchor": False,
               "window": 8, "limit": 1, "raw_quota": "≤1 次 / 8 轮"},
        "爱听歌": {"evidence": 1, "strength": "弱", "banned_as_anchor": True,
                "window": 0, "limit": None, "raw_quota": "禁止作为回复锚点"},
    }
    state = {"quota_config": config, "turns": [
        {"turn": 1, "topics": ["游戏"], "anchors": ["游戏"], "catch": ["笑死"]},
        {"turn": 2, "topics": ["听歌"], "anchors": ["听歌"], "catch": []},
    ], "violations": []}
    cases = [
        ("topic=加班|anchor=加班|catch=", "ok"),
        ("topic=听歌|anchor=听歌|catch=", "veto"),
        ("topic=游戏|anchor=游戏|catch=笑死", "veto"),
    ]
    ok = True
    for raw, expected in cases:
        result = check_candidate(state, parse_candidate(raw), turn_no=4)
        passed = result["verdict"] == expected
        ok = ok and passed
        print("[%s] expect=%s got=%s score=%.3f  candidate=%s" % (
            "PASS" if passed else "FAIL", expected, result["verdict"], result["score"], raw))
        for item in result["violations"]:
            print("        - %s: %s" % (item["type"], item["detail"]))
    print("selftest:", "all passed" if ok else "has failures")
    return 0 if ok else 1


def main():
    args = build_parser().parse_args()
    if args.selftest:
        return run_selftest()

    path = resolve_state_path(args.state, args.slug, args.base_dir)
    state = load_state(path, slug=args.slug)
    adaptive_path = args.adaptive or resolve_adaptive_path(args.state, args.slug, args.base_dir)
    adaptive = load_adaptive(adaptive_path)

    if args.action == "init":
        config = parse_persona_table(args.from_persona)
        if not config:
            print("警告：未能从 persona 解析出引用表，配额配置为空（将退化为宽松校验）")
        state["quota_config"] = config
        if args.base_temp:
            state["base_temp"] = args.base_temp
        save_state(path, state)
        emit({"action": "init", "state_file": path, "base_temp": state.get("base_temp"),
              "quota_config": config})
        return 0

    if args.action == "check":
        if not args.candidate:
            raise SystemExit("check 需要 --candidate")
        result = check_candidate(state, parse_candidate(args.candidate), args.turn, adaptive)
        result["action"] = "check"
        result["state_file"] = path
        result["adaptive_file"] = adaptive_path
        emit(result)
        return 0

    if args.action == "commit":
        record = upsert_turn(state, args.turn, {
            "topics": split_values(args.topics),
            "anchors": split_values(args.anchors),
            "catch": split_values(args.catch),
        })
        save_state(path, state)
        emit({"action": "commit", "state_file": path, "turn": record})
        return 0

    report = build_report(state)
    report["action"] = "report"
    report["state_file"] = path
    emit(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
