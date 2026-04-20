#!/bin/bash
# 竞彩晚盘脚本 - 每天 21:00
# 比赛>10场时 18点加一场当天进度（早盘数据），少时跳过

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
JINGCAI_DIR="$SELF_IMPROVING_DIR/jingcai"
OKOOO_SCRIPT="$HOME/.openclaw/workspace/okooo_jingcai.js"
FEISHU_PUSH="$HOME/.openclaw/agents/main/send_feishu.js"
LOGFILE="$JINGCAI_DIR/logs/evening-$(date +%Y%m%d).log"

mkdir -p "$JINGCAI_DIR/logs"

echo "=== 竞彩晚盘报告 - $(date) ===" | tee -a "$LOGFILE"

TODAY=$(date +%Y-%m-%d)

# 获取比赛数量（基于早盘缓存数据）
MATCH_COUNT=$(cat "$JINGCAI_DIR/match-count-$TODAY.txt" 2>/dev/null || echo "0")

echo "今日比赛数(早盘): $MATCH_COUNT" | tee -a "$LOGFILE"

# 晚盘最终报告
REPORT=$(node "$OKOOO_SCRIPT" "$TODAY" 2>> "$LOGFILE")
if [ -n "$REPORT" ]; then
    echo "$REPORT" | tee -a "$LOGFILE"
    node "$FEISHU_PUSH" "$REPORT" 2>/dev/null && echo "飞书推送成功" | tee -a "$LOGFILE" || echo "飞书推送失败" | tee -a "$LOGFILE"
fi

echo "=== 晚盘完成 ===" | tee -a "$LOGFILE"