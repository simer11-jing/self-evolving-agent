#!/bin/bash
# 竞彩午间复盘脚本 - 每天 12:00
# 对照昨天预测计算胜率，直接发送到飞书群

set -e

WORKSPACE="/home/jinghao/.openclaw/workspace"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
JINGCAI_DIR="$SELF_IMPROVING_DIR/jingcai"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGFILE="$JINGCAI_DIR/logs/review-$(date +%Y%m%d).log"

mkdir -p "$JINGCAI_DIR/logs"

echo "=== 竞彩午间复盘 - $(date) ===" | tee -a "$LOGFILE"

RESULTS_FILE="$JINGCAI_DIR/betting-results.md"
YESTERDAY=$(date -d 'yesterday' +%Y-%m-%d)

if [ ! -f "$RESULTS_FILE" ]; then
    echo "无投注记录" | tee -a "$LOGFILE"
    exit 0
fi

SUMMARY=$(python3 "$SCRIPT_DIR/jingcai-review.py" "$RESULTS_FILE" "$YESTERDAY")
PY_RET=$?

if [ $PY_RET -eq 0 ] && [ -n "$SUMMARY" ]; then
    echo "$SUMMARY" | tee -a "$LOGFILE"
else
    echo "复盘失败或无内容" | tee -a "$LOGFILE"
fi

echo "=== 复盘完成 ===" | tee -a "$LOGFILE"
