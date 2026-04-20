#!/bin/bash
# 竞彩午后修正脚本 - 每天 15:00
# 使用 Playwright 从 okooo.com 获取实时赔率数据

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
JINGCAI_DIR="$SELF_IMPROVING_DIR/jingcai"
SCRIPT_DIR="$HOME/.openclaw/workspace/okooo_jingcai.js"
FEISHU_PUSH="$HOME/.openclaw/agents/main/send_feishu.js"
LOGFILE="$JINGCAI_DIR/logs/afternoon-$(date +%Y%m%d).log"

mkdir -p "$JINGCAI_DIR/logs"

echo "=== 竞彩午后修正 - $(date) ===" | tee -a "$LOGFILE"

TODAY=$(date +%Y-%m-%d)

REPORT=$(node "$SCRIPT_DIR" "$TODAY" 2>> "$LOGFILE")
NODE_RET=$?

if [ $NODE_RET -eq 0 ] && [ -n "$REPORT" ]; then
    echo "$REPORT" | tee -a "$LOGFILE"
    node "$FEISHU_PUSH" "$REPORT" 2>/dev/null && echo "飞书推送成功" | tee -a "$LOGFILE" || echo "飞书推送失败" | tee -a "$LOGFILE"
else
    echo "分析失败" | tee -a "$LOGFILE"
fi

echo "=== 午后修正完成 ===" | tee -a "$LOGFILE"
