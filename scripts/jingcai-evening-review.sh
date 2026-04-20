#!/bin/bash
# 竞彩晚盘进度脚本 - 每天 18:00
# 早盘比赛>10场时发送当天进度（已结束+待踢），少时跳过

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
JINGCAI_DIR="$SELF_IMPROVING_DIR/jingcai"
OKOOO_SCRIPT="$HOME/.openclaw/workspace/okooo_jingcai.js"
FEISHU_PUSH="$HOME/.openclaw/agents/main/send_feishu.js"
LOGFILE="$JINGCAI_DIR/logs/evening-review-$(date +%Y%m%d).log"

mkdir -p "$JINGCAI_DIR/logs"

echo "=== 竞彩晚盘进度 - $(date) ===" | tee -a "$LOGFILE"

TODAY=$(date +%Y-%m-%d)

# 从早盘缓存读取比赛数量
if [ -f "$JINGCAI_DIR/match-count-$TODAY.txt" ]; then
    MATCH_COUNT=$(cat "$JINGCAI_DIR/match-count-$TODAY.txt")
else
    echo "无早盘数据，跳过" | tee -a "$LOGFILE"
    exit 0
fi

echo "今日比赛数(早盘): $MATCH_COUNT" | tee -a "$LOGFILE"

# 少于10场就跳过
if [ "$MATCH_COUNT" -lt 10 ] 2>/dev/null; then
    echo "比赛少于10场，跳过18点进度" | tee -a "$LOGFILE"
    exit 0
fi

# 生成晚盘进度报告
REPORT=$(node "$OKOOO_SCRIPT" "$TODAY" 2>> "$LOGFILE")
if [ -n "$REPORT" ]; then
    # 加上进度标题
    PREVIEW=$(echo "$REPORT" | sed "1s/📊 【竞彩晚盘最终报告】/📋 【午后进度报告】$TODAY ($MATCH_COUNT场)\n---\n早盘已发，最新数据：/")
    echo "$PREVIEW" | tee -a "$LOGFILE"
    node "$FEISHU_PUSH" "$PREVIEW" 2>/dev/null && echo "飞书推送成功" | tee -a "$LOGFILE" || echo "飞书推送失败" | tee -a "$LOGFILE"
fi

echo "=== 晚盘进度完成 ===" | tee -a "$LOGFILE"
