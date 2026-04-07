#!/bin/bash
# 性能监控脚本
# 监控系统的性能指标
#
# 功能：
# - 收集系统性能指标（CPU/内存/磁盘）
# - 收集 OpenClaw 性能指标
# - 记录性能数据到日志
# - 检查是否需要优化

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/monitoring/performance-$(date +%Y%m%d).log"
METRICS_FILE="$SELF_IMPROVING_DIR/monitoring/metrics.json"

echo "=== 开始性能监控 - $(date) ===" | tee -a "$LOGFILE"

# 1. 收集系统性能指标
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
MEMORY_USAGE=$(free -m | awk 'NR==2 {printf "%.2f", $3*100/$2}' 2>/dev/null || echo "0")
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")

echo "系统CPU使用率: ${CPU_USAGE}%" | tee -a "$LOGFILE"
echo "系统内存使用率: ${MEMORY_USAGE}%" | tee -a "$LOGFILE"
echo "磁盘使用率: ${DISK_USAGE}%" | tee -a "$LOGFILE"

# 2. 收集 OpenClaw 性能指标
SESSION_COUNT=0
GATEWAY_STATUS="unknown"

if command -v openclaw &> /dev/null; then
    # 检查活跃会话
    if openclaw sessions &> /dev/null; then
        SESSION_COUNT=$(openclaw sessions 2>/dev/null | grep -c "direct" || echo "0")
    fi
    
    # 检查网关状态
    if curl -s -m 5 http://127.0.0.1:18789/ &> /dev/null; then
        GATEWAY_STATUS="running"
    else
        GATEWAY_STATUS="stopped"
    fi
fi

echo "OpenClaw活跃会话: $SESSION_COUNT" | tee -a "$LOGFILE"
echo "网关状态: $GATEWAY_STATUS" | tee -a "$LOGFILE"

# 3. 计算性能评分（0-100，越高越好）
# 扣分项：CPU、内存、磁盘使用率
PERFORMANCE_SCORE=$(awk "BEGIN {printf \"%.2f\", 100 - ($CPU_USAGE * 0.3 + $MEMORY_USAGE * 0.3 + $DISK_USAGE * 0.2)}")
echo "性能评分: $PERFORMANCE_SCORE/100" | tee -a "$LOGFILE"

# 4. 记录性能数据
PERFORMANCE_DATA=$(cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "system": {
    "cpu_usage": "${CPU_USAGE}%",
    "memory_usage": "${MEMORY_USAGE}%",
    "disk_usage": "${DISK_USAGE}%"
  },
  "openclaw": {
    "active_sessions": "$SESSION_COUNT",
    "gateway_status": "$GATEWAY_STATUS"
  },
  "performance_score": "$PERFORMANCE_SCORE"
}
EOF
)

# 5. 保存到指标文件
if [ -f "$METRICS_FILE" ]; then
    # 追加数据
    EXISTING_DATA=$(cat "$METRICS_FILE" | jq -c '.' 2>/dev/null || echo "[]")
    NEW_DATA=$(echo "$PERFORMANCE_DATA" | jq -c '.')
    echo "[$EXISTING_DATA,$NEW_DATA]" | jq '.' > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
else
    echo "[$PERFORMANCE_DATA]" | jq '.' > "$METRICS_FILE"
fi

# 6. 检查是否需要优化
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=90

NEED_OPTIMIZATION=0

if [ "$(awk "BEGIN {print ($CPU_USAGE > $CPU_THRESHOLD) ? 1 : 0}")" -eq 1 ]; then
    echo "警告：CPU使用率过高 (${CPU_USAGE}%)" | tee -a "$LOGFILE"
    NEED_OPTIMIZATION=1
fi

if [ "$(awk "BEGIN {print ($MEMORY_USAGE > $MEM_THRESHOLD) ? 1 : 0}")" -eq 1 ]; then
    echo "警告：内存使用率过高 (${MEMORY_USAGE}%)" | tee -a "$LOGFILE"
    NEED_OPTIMIZATION=1
fi

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "警告：磁盘使用率过高 (${DISK_USAGE}%)" | tee -a "$LOGFILE"
    NEED_OPTIMIZATION=1
fi

# 7. 触发优化引擎（如需要）
if [ $NEED_OPTIMIZATION -eq 1 ]; then
    echo "触发优化引擎..." | tee -a "$LOGFILE"
    mkdir -p "$SELF_IMPROVING_DIR/optimizations"
    echo "high_resource_usage" > "$SELF_IMPROVING_DIR/optimizations/trigger.txt"
fi

# 8. 清理旧日志（保留30天）
find "$SELF_IMPROVING_DIR/monitoring" -name "performance-*.log" -mtime +30 -delete 2>/dev/null || true
find "$SELF_IMPROVING_DIR/monitoring" -name "metrics.json" -mtime +30 -delete 2>/dev/null || true

echo "=== 性能监控完成 - $(date) ===" | tee -a "$LOGFILE"