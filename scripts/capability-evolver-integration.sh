#!/bin/bash
# Capability Evolver 集成脚本
# 功能：调用 ClawHub Capability Evolver API 获取健康评分和改进建议
# 集成到 Self-Evolving Agent 的性能监控流程中

set -e

# 配置
CLAW0X_API_KEY="${CLAW0X_API_KEY:-}"
CLAW0X_ENDPOINT="https://api.claw0x.com/v1/call"
SKILL_NAME="capability-evolver"

# 日志
LOG_DIR="${LOG_DIR:-$HOME/.openclaw/workspace/self-improving/capability-evolver}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/evolver-$(date +%Y%m%d).log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 检查 API Key
if [ -z "$CLAW0X_API_KEY" ]; then
    log "警告: 未配置 CLAW0X_API_KEY，跳过 Capability Evolver 分析"
    log "提示: export CLAW0X_API_KEY=your_key 或在 .env 中配置"
    exit 0
fi

# 收集最近 N 小时的日志
HOURS_BACK="${HOURS_BACK:-1}"
log "收集最近 ${HOURS_BACK} 小时的运行日志..."

# 从多个来源收集日志
LOGS_ARRAY=()

# 1. OpenClaw 网关日志
if [ -d "$HOME/.openclaw/logs" ]; then
    GATEWAY_LOGS=$(find "$HOME/.openclaw/logs" -name "*.log" -mmin -$((HOURS_BACK * 60)) -exec cat {} \; 2>/dev/null | head -100)
    if [ -n "$GATEWAY_LOGS" ]; then
        while IFS= read -r line; do
            LOGS_ARRAY+=("{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"message\":\"$line\",\"context\":\"gateway\"}")
        done <<< "$GATEWAY_LOGS"
    fi
fi

# 2. Self-Evolving Agent 监控日志
MONITORING_DIR="$HOME/.openclaw/workspace/self-improving/monitoring"
if [ -d "$MONITORING_DIR" ]; then
    MONITOR_LOGS=$(find "$MONITORING_DIR" -name "*.log" -mmin -$((HOURS_BACK * 60)) -exec cat {} \; 2>/dev/null | head -50)
    if [ -n "$MONITOR_LOGS" ]; then
        while IFS= read -r line; do
            LOGS_ARRAY+=("{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"message\":\"$line\",\"context\":\"monitoring\"}")
        done <<< "$MONITOR_LOGS"
    fi
fi

# 3. Cron 任务失败记录
CRON_LOG="/var/log/syslog"
if [ -f "$CRON_LOG" ]; then
    CRON_ERRORS=$(grep -i "cron.*error\|cron.*fail" "$CRON_LOG" 2>/dev/null | tail -20)
    if [ -n "$CRON_ERRORS" ]; then
        while IFS= read -r line; do
            LOGS_ARRAY+=("{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"error\",\"message\":\"$line\",\"context\":\"cron\"}")
        done <<< "$CRON_ERRORS"
    fi
fi

# 4. 系统指标作为日志
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
MEMORY_USAGE=$(free -m | awk 'NR==2 {printf "%.2f", $3*100/$2}' 2>/dev/null || echo "0")
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")

LOGS_ARRAY+=("{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"message\":\"CPU usage: ${CPU_USAGE}%\",\"context\":\"system\"}")
LOGS_ARRAY+=("{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"message\":\"Memory usage: ${MEMORY_USAGE}%\",\"context\":\"system\"}")
LOGS_ARRAY+=("{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"message\":\"Disk usage: ${DISK_USAGE}%\",\"context\":\"system\"}")

# 检查是否有日志
if [ ${#LOGS_ARRAY[@]} -eq 0 ]; then
    log "未收集到日志数据，使用系统基础指标"
    LOGS_JSON="[{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"info\",\"message\":\"System health check\",\"context\":\"system\"}]"
else
    # 构建 JSON 数组
    LOGS_JSON="[$(IFS=,; echo "${LOGS_ARRAY[*]}")]"
fi

log "收集到 ${#LOGS_ARRAY[@]} 条日志记录"

# 调用 Capability Evolver API
log "调用 Capability Evolver API..."

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CLAW0X_ENDPOINT" \
    -H "Authorization: Bearer $CLAW0X_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"skill\": \"$SKILL_NAME\",
        \"input\": {
            \"action\": \"analyze\",
            \"logs\": $LOGS_JSON
        }
    }" 2>&1)

HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    log "错误: API 调用失败 (HTTP $HTTP_CODE)"
    log "响应: $RESPONSE_BODY"
    exit 1
fi

# 解析响应
HEALTH_SCORE=$(echo "$RESPONSE_BODY" | jq -r '.health_score // 0' 2>/dev/null || echo "0")
PATTERNS_COUNT=$(echo "$RESPONSE_BODY" | jq -r '.patterns | length' 2>/dev/null || echo "0")
RECOMMENDATIONS_COUNT=$(echo "$RESPONSE_BODY" | jq -r '.recommendations | length' 2>/dev/null || echo "0")

log "健康评分: $HEALTH_SCORE/100"
log "检测到模式: $PATTERNS_COUNT 个"
log "改进建议: $RECOMMENDATIONS_COUNT 条"

# 保存完整响应
RESPONSE_FILE="$LOG_DIR/response-$(date +%Y%m%d-%H%M%S).json"
echo "$RESPONSE_BODY" | jq '.' > "$RESPONSE_FILE" 2>/dev/null || echo "$RESPONSE_BODY" > "$RESPONSE_FILE"
log "完整响应已保存到: $RESPONSE_FILE"

# 输出关键信息供其他脚本使用
echo "HEALTH_SCORE=$HEALTH_SCORE"
echo "PATTERNS_COUNT=$PATTERNS_COUNT"
echo "RECOMMENDATIONS_COUNT=$RECOMMENDATIONS_COUNT"
echo "RESPONSE_FILE=$RESPONSE_FILE"

# 如果健康评分低于阈值，生成告警
HEALTH_THRESHOLD="${HEALTH_THRESHOLD:-70}"
if [ "$(awk "BEGIN {print ($HEALTH_SCORE < $HEALTH_THRESHOLD) ? 1 : 0}")" -eq 1 ]; then
    log "警告: 健康评分低于阈值 ($HEALTH_SCORE < $HEALTH_THRESHOLD)"
    
    # 创建触发文件，通知 Self-Evolving Agent 进行深度分析
    TRIGGER_FILE="$HOME/.openclaw/workspace/self-improving/optimizations/trigger.txt"
    mkdir -p "$(dirname "$TRIGGER_FILE")"
    echo "low_health_score:$HEALTH_SCORE" > "$TRIGGER_FILE"
    echo "capability_evolver_alert" >> "$TRIGGER_FILE"
    
    log "已触发深度分析流程"
    
    # 提取高优先级建议
    HIGH_PRIORITY=$(echo "$RESPONSE_BODY" | jq -r '.recommendations[] | select(.priority == "high" or .priority == "critical") | .description' 2>/dev/null | head -5)
    if [ -n "$HIGH_PRIORITY" ]; then
        log "高优先级建议:"
        echo "$HIGH_PRIORITY" | while read -r rec; do
            log "  - $rec"
        done
    fi
fi

# 清理旧日志（保留7天）
find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
find "$LOG_DIR" -name "*.json" -mtime +7 -delete 2>/dev/null || true

log "Capability Evolver 分析完成"
