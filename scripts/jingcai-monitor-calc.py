#!/usr/bin/env python3
"""赔率监控分析 - 由 shell 脚本调用"""
import sys
import json
import os

def analyze_shift(initial_had, current_win, initial_draw, current_draw,
                 initial_lose, current_lose, danger_thr, warning_thr, opportunity_thr):
    initial = float(initial_had)
    current = float(current_win)
    idraw = float(initial_draw) if initial_draw else 0.0
    cdraw = float(current_draw) if current_draw and current_draw != 'null' else 0.0
    ilose = float(initial_lose) if initial_lose else 0.0
    close = float(current_lose) if current_lose and current_lose != 'null' else 0.0

    shift = (current - initial) / initial if initial != 0 else 0

    if shift > danger_thr:
        level, status = "danger", "DANGER"
    elif shift > warning_thr:
        level, status = "warning", "WARNING"
    elif shift < opportunity_thr:
        level, status = "opportunity", "OPP"
    else:
        level, status = "normal", "OK"

    return {
        "shift": round(shift, 4),
        "level": level,
        "status": status,
        "initial_had": initial,
        "current_win": current,
    }

def main():
    if len(sys.argv) < 9:
        # mode: output shell-parseable key=value pairs
        print("ERROR=insufficient_args", file=sys.stderr)
        sys.exit(1)

    result = analyze_shift(
        sys.argv[1], sys.argv[2],  # initial_had, current_win
        sys.argv[3], sys.argv[4],    # initial_draw, current_draw
        sys.argv[5], sys.argv[6],    # initial_lose, current_lose
        float(sys.argv[7]),
        float(sys.argv[8]),
        float(sys.argv[9])
    )

    # Output as shell-parseable format
    for k, v in result.items():
        print(f"{k.upper()}={v}")

if __name__ == "__main__":
    main()
