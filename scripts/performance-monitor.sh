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

# 2. 收集 OpenClaw 性能指标（简化，避免卡住）
SESSION_COUNT=0
GATEWAY_STATUS="unknown"

# 只做基本的状态检查，不调用 openclaw 命令
if curl -s -m 3 http://127.0.0.1:18789/ &> /dev/null; then
    GATEWAY_STATUS="running"
else
    GATEWAY_STATUS="stopped"
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

# 5. 简化日志记录（避免 jq 卡住）
if [ ! -f "$METRICS_FILE" ]; then
    echo "[" > "$METRICS_FILE"
else
    # 只保留最后100行
    tail -100 "$METRICS_FILE" > "${METRICS_FILE}.tmp" 2>/dev/null || echo "[" > "${METRICS_FILE}.tmp"
    mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
fi

echo "$(date -Iseconds): CPU=${CPU_USAGE}%, MEM=${MEMORY_USAGE}%, DISK=${DISK_USAGE}%, SCORE=$PERFORMANCE_SCORE" >> "$METRICS_FILE"
echo "1]" >> "$METRICS_FILE" 2>/dev/null || true

# 6. Capability Evolver 快速健康检查（第一层）
CAPABILITY_EVOLVER_SCRIPT="$SKILL_DIR/scripts/capability-evolver-integration.sh"
HEALTH_SCORE=""
EVOLVER_TRIGGERED=0

if [ -x "$CAPABILITY_EVOLVER_SCRIPT" ] && [ -n "$CLAW0X_API_KEY" ]; then
    echo "调用 Capability Evolver 进行快速健康检查..." | tee -a "$LOGFILE"
    EVOLVER_OUTPUT=$($CAPABILITY_EVOLVER_SCRIPT 2>&1) || true
    HEALTH_SCORE=$(echo "$EVOLVER_OUTPUT" | grep "HEALTH_SCORE=" | cut -d= -f2 || echo "")
    
    if [ -n "$HEALTH_SCORE" ]; then
        echo "Capability Evolver 健康评分: $HEALTH_SCORE/100" | tee -a "$LOGFILE"
        
        # 如果健康评分低于阈值，标记需要深度分析
        if [ "$(awk "BEGIN {print ($HEALTH_SCORE < 70) ? 1 : 0}")" -eq 1 ]; then
            echo "警告：健康评分低于阈值，需要深度分析" | tee -a "$LOGFILE"
            EVOLVER_TRIGGERED=1
            NEED_OPTIMIZATION=1
        fi
    fi
fi

# 7. 检查系统资源阈值（第二层）
CPU_THRESHOLD=60  # 60% 以上触发优化
MEM_THRESHOLD=70  # 70% 以上触发优化
DISK_THRESHOLD=75  # 75% 以上触发优化（90%太迟）

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

# 8. 触发优化引擎（如需要）
if [ $NEED_OPTIMIZATION -eq 1 ]; then
    echo "触发优化引擎..." | tee -a "$LOGFILE"
    mkdir -p "$SELF_IMPROVING_DIR/optimizations"
    
    # 根据触发源记录不同原因
    if [ $EVOLVER_TRIGGERED -eq 1 ]; then
        echo "capability_evolver_low_health:$HEALTH_SCORE" > "$SELF_IMPROVING_DIR/optimizations/trigger.txt"
        echo "触发源: Capability Evolver 健康评分低" | tee -a "$LOGFILE"
    else
        echo "high_resource_usage" > "$SELF_IMPROVING_DIR/optimizations/trigger.txt"
        echo "触发源: 系统资源使用率高" | tee -a "$LOGFILE"
    fi
    
    # 记录详细指标
    echo "CPU=$CPU_USAGE,MEM=$MEMORY_USAGE,DISK=$DISK_USAGE" >> "$SELF_IMPROVING_DIR/optimizations/trigger.txt"
fi

# 9. 清理旧日志（保留30天）
find "$SELF_IMPROVING_DIR/monitoring" -name "performance-*.log" -mtime +30 -delete 2>/dev/null || true
find "$SELF_IMPROVING_DIR/monitoring" -name "metrics.json" -mtime +30 -delete 2>/dev/null || true

echo "=== 性能监控完成 - $(date) ===" | tee -a "$LOGFILE"