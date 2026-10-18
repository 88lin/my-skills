#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""会话状态文件读写 —— speech_guard.py 与 topic_ledger.py 共用。

状态文件路径：crushes/{slug}/sessions/YYYY-MM-DD.json
只依赖标准库，兼容 Python 3.9。
"""

import json
import os
import sys
from datetime import date, datetime


def _ensure_stdout_utf8():
    """Windows 控制台默认 GBK，输出中文 JSON 会炸，这里强制 UTF-8。"""
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def today_str():
    return date.today().isoformat()


def now_iso():
    return datetime.now().replace(microsecond=0).isoformat()


def resolve_state_path(state=None, slug=None, base_dir="crushes"):
    if state:
        return state
    if not slug:
        raise SystemExit("需要提供 --state 或 --slug 之一")
    return os.path.join(base_dir, slug, "sessions", today_str() + ".json")


def load_state(path, slug=None):
    if not os.path.exists(path):
        return {
            "slug": slug,
            "date": today_str(),
            "created_at": now_iso(),
            "quota_config": {},
            "turns": [],
            "violations": [],
        }
    with open(path, "r", encoding="utf-8") as f:
        state = json.load(f)
    state.setdefault("slug", slug)
    state.setdefault("quota_config", {})
    state.setdefault("turns", [])
    state.setdefault("violations", [])
    return state


def save_state(path, state):
    directory = os.path.dirname(os.path.abspath(path))
    if directory and not os.path.isdir(directory):
        os.makedirs(directory, exist_ok=True)
    state["updated_at"] = now_iso()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def get_turn(state, turn_no):
    for record in state.get("turns", []):
        if record.get("turn") == turn_no:
            return record
    return None


def upsert_turn(state, turn_no, fields):
    """按轮次号写入或合并字段。"""
    record = get_turn(state, turn_no)
    if record is None:
        record = {"turn": turn_no}
        state.setdefault("turns", []).append(record)
        state["turns"].sort(key=lambda r: r.get("turn", 0))
    for key, value in fields.items():
        if value is not None:
            record[key] = value
    return record


def recent_turns(state, count, before_turn=None):
    """取 before_turn 之前（不含）的最近 count 轮，按时间正序返回。"""
    turns = [t for t in state.get("turns", []) if t.get("turn") is not None]
    if before_turn is not None:
        turns = [t for t in turns if t["turn"] < before_turn]
    turns.sort(key=lambda r: r["turn"])
    return turns[-count:] if count > 0 else turns


def log_violation(state, turn_no, violations):
    if not violations:
        return
    state.setdefault("violations", []).append(
        {"turn": turn_no, "at": now_iso(), "items": violations}
    )


def emit(payload):
    """统一 JSON 输出。"""
    _ensure_stdout_utf8()
    print(json.dumps(payload, ensure_ascii=False, indent=2))


BASELINE_ADAPTIVE = {
    "jaccard_warn": 0.50,
    "jaccard_veto": 0.65,
    "escape_ban_at": 2,
    "escape_max_len": 14,
    "quota_scale": 1.0,
}

DEFAULT_ADAPTIVE = dict(BASELINE_ADAPTIVE, whitelist=[], corrections=[], adjustments=[], confidence=0.0)


def resolve_adaptive_path(state_path=None, slug=None, base_dir="crushes"):
    """自适应配置固定放在 crushes/{slug}/adaptive.json（跨会话持久）。"""
    if slug:
        return os.path.join(base_dir, slug, "adaptive.json")
    if state_path:
        sessions_dir = os.path.dirname(os.path.abspath(state_path))
        root = os.path.dirname(sessions_dir)
        return os.path.join(root, "adaptive.json")
    raise SystemExit("需要提供 --slug 或 --state 以定位 adaptive.json")


def load_adaptive(path):
    data = dict(DEFAULT_ADAPTIVE)
    if path and os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data.update(json.load(f))
        except Exception:
            pass
    for key, value in BASELINE_ADAPTIVE.items():
        data.setdefault(key, value)
    data.setdefault("whitelist", [])
    return data


def save_adaptive(path, adaptive):
    directory = os.path.dirname(os.path.abspath(path))
    if directory and not os.path.isdir(directory):
        os.makedirs(directory, exist_ok=True)
    adaptive["updated_at"] = now_iso()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(adaptive, f, ensure_ascii=False, indent=2)
