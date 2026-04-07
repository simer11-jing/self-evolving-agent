#!/bin/bash
# 错误分析脚本
# 分析并记录错误模式
#
# 功能：
# - 分析最近的错误日志
# - 识别错误模式
# - 记录错误到错误日志
# - 提供修复建议

# 不要在错误时退出（某些检查可能失败）
set +e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

# 确保目录存在
mkdir -p "$SELF_IMPROVING_DIR/errors"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/errors/error-log-$(date +%Y%m%d).json"
ERROR_SUMMARY="$SELF_IMPROVING_DIR/errors/error-summary-$(date +%Y%m%d).md"

echo "=== 开始错误分析 - $(date) ===" | tee -a "$LOGFILE"

# 1. 分析 OpenClaw 错误日志
ERRORS_FOUND=0

if [ -d "$HOME/.openclaw/logs" ]; then
    # 查找最近的错误日志
    RECENT_ERRORS=$(find "$HOME/.openclaw/logs" -name "*.log" -mtime -1 -exec grep -l "ERROR\|error\|Error" {} \; 2>/dev/null | head -5)
    
    if [ -n "$RECENT_ERRORS" ]; then
        echo "发现错误日志文件: $RECENT_ERRORS" | tee -a "$LOGFILE"
        
        # 提取错误信息
        for logfile in $RECENT_ERRORS; do
            ERROR_COUNT=$(grep -c "ERROR\|error\|Error" "$logfile" 2>/dev/null || echo "0")
            ERRORS_FOUND=$((ERRORS_FOUND + ERROR_COUNT))
            
            # 提取错误类型统计
            grep -oP "Error: \K[^"]+" "$logfile" 2>/dev/null | sort | uniq -c | sort -rn | head -10 >> "$SELF_IMPROVING_DIR/errors/recent-errors.txt" 2>/dev/null || true
        done
    fi
fi

# 2. 分析 Cron 任务错误
if [ -d "$HOME/.openclaw/cron/runs" ]; then
    # 查找最近运行中的错误
    FAILED_JOBS=$(find "$HOME/.openclaw/cron/runs" -name "*.jsonl" -mtime -1 -exec grep -l '"status":"error"' {} \; 2>/dev/null | head -5)
    
    if [ -n "$FAILED_JOBS" ]; then
        echo "发现失败的 Cron 任务" | tee -a "$LOGFILE"
        
        for job in $FAILED_JOBS; do
            grep -A2 '"status":"error"' "$job" 2>/dev/null | head -20 >> "$SELF_IMPROVING_DIR/errors/failed-jobs.txt" 2>/dev/null || true
        done
    fi
fi

# 3. 创建错误报告
cat > "$ERROR_SUMMARY" <<EOF
# 错误分析报告
**生成时间：** $(date)

## 错误统计

- 总错误数：$ERRORS_FOUND
- 分析时间：$(date)

## 错误来源

### 系统错误
$(cat "$SELF_IMPROVING_DIR/errors/recent-errors.txt" 2>/dev/null | head -20 || echo "无")

### Cron 任务失败
$(cat "$SELF_IMPROVING_DIR/errors/failed-jobs.txt" 2>/dev/null | head -20 || echo "无")

## 修复建议

1. 如果是资源问题，考虑清理磁盘或增加内存
2. 如果是网络问题，检查网络连接和 API 密钥
3. 如果是权限问题，检查文件权限配置

---

*此报告由 Self-Evolving Agent 自动生成*
EOF

echo "错误报告已生成: $ERROR_SUMMARY" | tee -a "$LOGFILE"
echo "发现错误数: $ERRORS_FOUND" | tee -a "$LOGFILE"
echo "=== 错误分析完成 - $(date) ===" | tee -a "$LOGFILE"

# 4. 清理旧错误日志（保留30天）
find "$SELF_IMPROVING_DIR/errors" -name "error-*.json" -mtime +30 -delete 2>/dev/null || true
find "$SELF_IMPROVING_DIR/errors" -name "error-summary-*.md" -mtime +30 -delete 2>/dev/null || true
rm -f "$SELF_IMPROVING_DIR/errors/recent-errors.txt" 2>/dev/null || true
rm -f "$SELF_IMPROVING_DIR/errors/failed-jobs.txt" 2>/dev/null || true