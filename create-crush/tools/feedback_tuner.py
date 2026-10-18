#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""feedback_tuner.py —— 阈值自适应校准（B2）

思路：用户的纠正是唯一可信的反馈信号（reward），用它调三类参数。
  1. 重复度阈值（jaccard_warn / jaccard_veto）
  2. 逃生句触发门槛（escape_ban_at）
  3. 配额窗口缩放（quota_scale）

纠正类型：
  still_repeats   "她不会老说这句" / "又来了" / "怎么又是听歌" → 漏检 → 收紧
  too_bland       "她不会这么敷衍" / "太没意思了"             → 敷衍没抓住 → 收紧
  false_positive  "这句她真的会说" / "这就是她的口头禅"        → 误报 → 放宽 + 加白名单
  reset           恢复默认

防抖设计：
  * 用 tanh 饱和函数，单条纠正只推动一小步（±0.03 上限）
  * 逃生句门槛只在「多条收紧信号」时才降到 1（避免一次抱怨就变严苛）
  * 新记录权重高（指数衰减）
  * 参数上下限夹紧，并保证 warn 与 veto 保持最小间隔
  * calibrate 永远从「纠正记录」重算，而不是在当前值上叠加 —— 幂等，不会漂移

用法：
  python3 tools/feedback_tuner.py --slug xiaomei --action add \
      --type still_repeats --target "爱听歌" --turn 12 --note "她不会老说这句"
  python3 tools/feedback_tuner.py --slug xiaomei --action show
  python3 tools/feedback_tuner.py --slug xiaomei --action reset
  python3 tools/feedback_tuner.py --selftest
"""

import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from session_state import (  # noqa: E402
    BASELINE_ADAPTIVE,
    emit,
    load_adaptive,
    now_iso,
    resolve_adaptive_path,
    save_adaptive,
)

TIGHTEN_TYPES = ("still_repeats", "too_bland")
LOOSEN_TYPES = ("false_positive",)
VALID_TYPES = TIGHTEN_TYPES + LOOSEN_TYPES
MAX_HISTORY = 40
DECAY = 10.0
STEP = 0.03
WARN_FLOOR, WARN_CEIL = 0.35, 0.72
VETO_FLOOR, VETO_CEIL = 0.48, 0.85
MIN_GAP = 0.08
QUOTA_FLOOR, QUOTA_CEIL = 0.75, 1.5
TYPE_LABEL = {
    "still_repeats": "还在重复（漏检）",
    "too_bland": "太敷衍（漏检）",
    "false_positive": "误报（其实像 ta）",
}


def clamp(value, low, high):
    return max(low, min(high, value))


def calibrate(corrections):
    """从纠正记录重算自适应参数（幂等）。"""
    window = corrections[-MAX_HISTORY:]
    tighten = 0.0
    loosen = 0.0
    whitelist = []
    for index, record in enumerate(window):
        weight = math.exp(-(len(window) - 1 - index) / DECAY)
        kind = record.get("type")
        if kind in TIGHTEN_TYPES:
            tighten += weight
        elif kind in LOOSEN_TYPES:
            loosen += weight
            target = record.get("target")
            if target and target not in whitelist:
                whitelist.append(target)
    net = tighten - loosen
    step = STEP * math.tanh(net / 2.0)

    warn = clamp(BASELINE_ADAPTIVE["jaccard_warn"] - step, WARN_FLOOR, WARN_CEIL)
    veto = clamp(BASELINE_ADAPTIVE["jaccard_veto"] - step, VETO_FLOOR, VETO_CEIL)
    if veto - warn < MIN_GAP:
        veto = min(round(warn + MIN_GAP, 3), VETO_CEIL)
        warn = min(warn, round(veto - MIN_GAP, 3))
    escape_ban_at = 1 if net >= 2.5 else 2
    quota_scale = clamp(1 + 0.12 * math.tanh(net / 2.0), QUOTA_FLOOR, QUOTA_CEIL)

    return {
        "jaccard_warn": round(warn, 3),
        "jaccard_veto": round(veto, 3),
        "escape_ban_at": escape_ban_at,
        "escape_max_len": BASELINE_ADAPTIVE["escape_max_len"],
        "quota_scale": round(quota_scale, 3),
        "whitelist": whitelist,
        "confidence": round(min(1.0, len(window) / 10.0), 2),
        "net_signal": round(net, 3),
        "corrections_count": len(corrections),
    }


def describe(adaptive):
    """给用户看的人话总结。"""
    delta_warn = round(adaptive["jaccard_warn"] - BASELINE_ADAPTIVE["jaccard_warn"], 3)
    if abs(delta_warn) < 0.005 and adaptive["escape_ban_at"] == 2:
        direction = "维持默认"
    elif delta_warn < 0:
        direction = "比默认更严（更容易判定重复）"
    else:
        direction = "比默认更松（更少拦截）"
    return {
        "方向": direction,
        "重复度门槛": "警告 %.2f / 否决 %.2f（默认 0.50 / 0.65）" % (
            adaptive["jaccard_warn"], adaptive["jaccard_veto"]),
        "逃生句门槛": "%d 轮内出现 %d 次即否决（默认 2 次）" % (5, adaptive["escape_ban_at"]),
        "配额窗口缩放": "×%.2f（>1 更严格）" % adaptive["quota_scale"],
        "白名单": adaptive["whitelist"] or "（空）",
        "置信度": adaptive["confidence"],
    }


def build_parser():
    parser = argparse.ArgumentParser(description="反单调对话引擎 · 阈值自适应校准")
    parser.add_argument("--slug", help="暗恋对象 slug")
    parser.add_argument("--state", help="会话状态文件（用于反推 adaptive.json 位置）")
    parser.add_argument("--base-dir", default="crushes")
    parser.add_argument("--action", default="show",
                        choices=["add", "calibrate", "show", "reset"])
    parser.add_argument("--type", dest="kind", choices=VALID_TYPES, help="纠正类型")
    parser.add_argument("--target", help="被纠正的特征/锚点/短语")
    parser.add_argument("--turn", type=int, help="发生纠正的轮次")
    parser.add_argument("--note", help="用户原话")
    parser.add_argument("--selftest", action="store_true")
    return parser


def run_selftest():
    cases = [
        ([], "维持默认"),
        ([{"type": "still_repeats", "target": "爱听歌"}], "收紧"),
        ([{"type": "still_repeats", "target": "爱听歌"}] * 8, "强收紧"),
        ([{"type": "false_positive", "target": "笑死"}], "放宽"),
    ]
    ok = True
    for corrections, note in cases:
        result = calibrate(corrections)
        base_warn = BASELINE_ADAPTIVE["jaccard_warn"]
        if note == "维持默认":
            passed = abs(result["jaccard_warn"] - base_warn) < 0.005
        elif note == "收紧":
            passed = result["jaccard_warn"] < base_warn
        elif note == "强收紧":
            passed = result["jaccard_warn"] < base_warn and result["escape_ban_at"] == 1
        else:
            passed = result["jaccard_warn"] > base_warn and "笑死" in result["whitelist"]
        ok = ok and passed
        print("[%s] %-8s warn=%.3f veto=%.3f escape_ban_at=%d quota=%.2f whitelist=%s" % (
            "PASS" if passed else "FAIL", note, result["jaccard_warn"],
            result["jaccard_veto"], result["escape_ban_at"], result["quota_scale"],
            result["whitelist"]))
    # 幂等性：同样的输入算两次结果必须一致
    sample = [{"type": "still_repeats", "target": "x"}] * 5 + [{"type": "false_positive", "target": "y"}]
    idempotent = calibrate(sample) == calibrate(sample)
    print("[%s] 幂等性（重算不漂移）" % ("PASS" if idempotent else "FAIL"))
    ok = ok and idempotent
    print("selftest:", "all passed" if ok else "has failures")
    return 0 if ok else 1


def main():
    args = build_parser().parse_args()
    if args.selftest:
        return run_selftest()

    path = resolve_adaptive_path(args.state, args.slug, args.base_dir)
    adaptive = load_adaptive(path)
    corrections = adaptive.get("corrections", []) or []

    if args.action == "reset":
        adaptive = load_adaptive("")
        corrections = []
    elif args.action in ("add", "calibrate"):
        if args.action == "add":
            if not args.kind:
                raise SystemExit("add 需要 --type")
            corrections = corrections + [{
                "type": args.kind,
                "target": args.target,
                "turn": args.turn,
                "note": args.note,
                "at": now_iso(),
            }]
        computed = calibrate(corrections)
        adaptive.update(computed)
        adaptive["corrections"] = corrections
        adaptive.setdefault("adjustments", []).append({
            "at": now_iso(),
            "action": args.action,
            "type": args.kind,
            "target": args.target,
            "turn": args.turn,
            "result": {k: computed[k] for k in (
                "jaccard_warn", "jaccard_veto", "escape_ban_at", "quota_scale")},
        })
    else:
        adaptive = calibrate(corrections) if corrections else adaptive

    save_adaptive(path, adaptive)
    emit({
        "action": args.action,
        "adaptive_file": path,
        "corrections_count": len(corrections),
        "params": {k: adaptive.get(k) for k in (
            "jaccard_warn", "jaccard_veto", "escape_ban_at",
            "escape_max_len", "quota_scale", "confidence", "whitelist")},
        "summary": describe(adaptive),
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
