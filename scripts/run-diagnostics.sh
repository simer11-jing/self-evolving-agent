#!/bin/bash
# 自我诊断 + 自动修复
# 建议: 每30分钟运行一次

SCRIPT_DIR="$HOME/.openclaw/skills/self-evolving-agent"
LOG_FILE="$SCRIPT_DIR/logs/diagnostics.log"

# 运行诊断
cd "$SCRIPT_DIR"
node scripts/self-diagnostics.js --silent --fix >> "$LOG_FILE" 2>&1

# 检查是否需要通知
REPORT_FILE="$SCRIPT_DIR/logs/diagnostics-report.json"
if [ -f "$REPORT_FILE" ]; then
    CRITICAL=$(jq '.summary.criticalIssues' "$REPORT_FILE" 2>/dev/null || echo "0")
    FIXED=$(jq '.summary.autoFixed' "$REPORT_FILE" 2>/dev/null || echo "0")
    
    if [ "$CRITICAL" -gt 0 ] || [ "$FIXED" -gt 0 ]; then
        # 生成简短摘要
        MSG="🔍 Self-Diagnostics: "
        if [ "$CRITICAL" -gt 0 ]; then
            MSG+="❌ $CRITICAL 个严重问题"
        else
            MSG+="✅ 已修复 $FIXED 个问题"
        fi
        
        # 发送通知
        node "$HOME/.openclaw/agents/main/send_feishu.js" "$MSG" 2>/dev/null || true
    fi
fi
