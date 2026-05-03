#!/usr/bin/env python3
"""
OpenClaw/Hindsight local memory inference helper.
Replaces Kairos hard dependency for self-evolving-agent.

CLI compatibility:
  --infer TEXT
  --feedback
  --record-feedback SESSION:status[:note]
  --learn-from-betting [PATH]
"""
import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
BASE = HOME / ".openclaw"
STATE_DIR = BASE / "workspace/self-improving/memory-core"
STATE_FILE = STATE_DIR / "state.json"
MEMORY_FILE = BASE / "agents/main/MEMORY.md"
DAILY_DIR = BASE / "agents/main/memory"


def load_state():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"feedback": [], "betting": [], "inferences": []}


def save_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def strip_tags(line):
    return re.sub(r"\s*\{tags:[^}]+\}\s*$", "", line).strip()


def collect_memory(prompt="", limit=60):
    terms = [t for t in re.split(r"\W+", prompt) if len(t) >= 2]
    default_terms = ["赔率", "联赛", "战意", "cron", "Gateway", "OpenClaw", "配置", "错误", "优化", "记忆", "系统"]
    terms = list(dict.fromkeys(terms + default_terms))
    lines = []

    files = []
    if MEMORY_FILE.exists():
        files.append(MEMORY_FILE)
    for p in sorted(DAILY_DIR.glob("20*.md"), reverse=True)[:3]:
        files.append(p)

    for path in files:
        try:
            for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
                line = strip_tags(raw)
                if not line or len(line) < 4:
                    continue
                if any(t in line for t in terms):
                    lines.append((str(path), line))
        except Exception:
            continue
    # de-dupe preserving order
    seen, out = set(), []
    for src, line in lines:
        key = line[:160]
        if key not in seen:
            seen.add(key)
            out.append((src, line))
        if len(out) >= limit:
            break
    return out


def infer(user, prompt):
    state = load_state()
    session_id = f"ocmem-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    state.setdefault("inferences", []).append({
        "session_id": session_id,
        "user": user,
        "prompt": prompt[:1500],
        "createdAt": datetime.now().isoformat(),
        "engine": "openclaw-memory",
    })
    save_state(state)

    mem = collect_memory(prompt)
    print(f"OpenClaw Memory Inference [{session_id}]")
    print("\n## 相关长期记忆/近期记录")
    if mem:
        for _, line in mem[:14]:
            print(f"- {line}")
    else:
        print("- 未找到强相关记忆，采用保守默认策略。")

    print("\n## 推理建议")
    if any(k in prompt for k in ["投注", "赔率", "比赛", "联赛"]):
        print("- 优先使用已验证联赛：英超/德甲/瑞超/挪超。")
        print("- 赔率 1.35-1.50 优先；1.50-2.00 和 >3.00 降低置信度。")
        print("- 临场暴升 >0.3、杯赛深盘、法甲/葡超/美职/J联赛默认避险。")
    elif any(k in prompt for k in ["优化", "系统", "资源", "配置", "cron", "Gateway"]):
        print("- 先备份，再做最小改动；修改后跑健康检查/脚本 smoke test。")
        print("- cron 推送优先确认 channel/to/accountId，避免错发。")
        print("- 高资源问题优先清理日志和缓存，避免破坏业务数据。")
    else:
        print("- 优先查 MEMORY.md 与近 3 天 daily memory，复用已验证经验。")
        print("- 不确定时保持 Kairos 兼容 fallback，但新逻辑应写入 OpenClaw memory-core。")


def feedback_report(user):
    state = load_state()
    items = state.get("feedback", [])
    print(f"OpenClaw memory feedback report for {user}")
    print(f"Total feedback: {len(items)}")
    counts = {}
    for it in items:
        counts[it.get("status", "unknown")] = counts.get(it.get("status", "unknown"), 0) + 1
    if counts:
        print("Status counts:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    for it in items[-20:]:
        note = f" | {it.get('note')}" if it.get("note") else ""
        print(f"- {it.get('createdAt')} {it.get('session_id')} {it.get('status')}{note}")


def record_feedback(value):
    state = load_state()
    parts = value.split(":", 2)
    item = {
        "session_id": parts[0] if parts else "unknown",
        "status": parts[1] if len(parts) > 1 else "unknown",
        "note": parts[2] if len(parts) > 2 else "",
        "createdAt": datetime.now().isoformat(),
        "engine": "openclaw-memory",
    }
    state.setdefault("feedback", []).append(item)
    save_state(state)
    print(f"OpenClaw memory feedback recorded: {item['session_id']} -> {item['status']}")


def learn_from_betting(path=None):
    p = Path(path).expanduser() if path else BETTING_FILE
    state = load_state()
    summary = {"path": str(p), "exists": p.exists(), "updatedAt": datetime.now().isoformat(), "records": 0, "engine": "openclaw-memory"}
    if p.exists():
        lines = [l for l in p.read_text(encoding="utf-8", errors="ignore").splitlines() if l.strip() and not l.lstrip().startswith("#")]
        summary["records"] = len(lines)
        wins = sum(1 for l in lines if any(x in l for x in ["命中", "赢", "✅", "win", "true"]))
        losses = sum(1 for l in lines if any(x in l for x in ["未中", "输", "❌", "loss", "false"]))
        summary["wins"] = wins
        summary["losses"] = losses
        summary["hitRate"] = round(wins / (wins + losses), 3) if wins + losses else None
    state.setdefault("betting", []).append(summary)
    save_state(state)
    print("OpenClaw memory betting learning updated")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", default="jinghao")
    ap.add_argument("--infer")
    ap.add_argument("--feedback", action="store_true")
    ap.add_argument("--record-feedback")
    ap.add_argument("--learn-from-betting", nargs="?", const=str(BETTING_FILE))
    args = ap.parse_args()
    if args.record_feedback:
        record_feedback(args.record_feedback); return 0
    if args.learn_from_betting:
        learn_from_betting(args.learn_from_betting); return 0
    if args.feedback:
        feedback_report(args.user); return 0
    if args.infer:
        infer(args.user, args.infer); return 0
    ap.print_help(); return 0

if __name__ == "__main__":
    sys.exit(main())
