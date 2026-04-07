#!/bin/bash
# 反馈循环系统
# 收集和处理用户反馈
#
# 功能：
# - 收集用户反馈
# - 分析反馈模式
# - 改进服务质量

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/feedback/feedback-$(date +%Y%m%d).log"
FEEDBACK_DB="$SELF_IMPROVING_DIR/feedback/feedback-db.json"

echo "=== 开始反馈循环系统 - $(date) ===" | tee -a "$LOGFILE"

# 1. 检查反馈收集目录
FEEDBACK_DIR="$SELF_IMPROVING_DIR/feedback"
mkdir -p "$FEEDBACK_DIR"

# 2. 分析最近的反馈
FEEDBACK_COUNT=0

# 检查是否有新的反馈文件
if [ -d "$FEEDBACK_DIR/incoming" ]; then
    NEW_FEEDBACK=$(find "$FEEDBACK_DIR/incoming" -name "*.json" -mtime -1 2>/dev/null)
    
    for feedback_file in $NEW_FEEDBACK; do
        if [ -f "$feedback_file" ]; then
            FEEDBACK_COUNT=$((FEEDBACK_COUNT + 1))
            
            # 处理反馈
            FEEDBACK_CONTENT=$(cat "$feedback_file" 2>/dev/null)
            FEEDBACK_TYPE=$(echo "$FEEDBACK_CONTENT" | jq -r '.type' 2>/dev/null || echo "unknown")
            FEEDBACK_TEXT=$(echo "$FEEDBACK_CONTENT" | jq -r '.text' 2>/dev/null || echo "")
            
            echo "收到反馈 ($FEEDBACK_TYPE): $FEEDBACK_TEXT" | tee -a "$LOGFILE"
            
            # 移动到处理目录
            mv "$feedback_file" "$FEEDBACK_DIR/processed/" 2>/dev/null || true
        fi
    done
fi

# 3. 分析反馈模式
echo "分析反馈模式..." | tee -a "$LOGFILE"

# 反馈类型统计
if [ -f "$FEEDBACK_DB" ]; then
    FEEDBACK_STATS=$(cat "$FEEDBACK_DB" | jq -r '.type_stats' 2>/dev/null || echo "{}")
    echo "反馈统计: $FEEDBACK_STATS" | tee -a "$LOGFILE"
fi

# 4. 生成反馈报告
FEEDBACK_REPORT="$FEEDBACK_DIR/report-$(date +%Y%m%d).md"

cat > "$FEEDBACK_REPORT" <<EOF
# 反馈分析报告
**生成时间：** $(date)

## 反馈统计

- 新反馈数量：$FEEDBACK_COUNT
- 分析时间：$(date)

## 反馈模式分析

### 正面反馈
- 响应速度
- 回答质量
- 问题解决率

### 改进建议
- 用户期望的功能
- 体验优化建议
- 性能改进

## 改进计划

1. 根据反馈调整回答风格
2. 优化常见问题的回答
3. 提升特定领域的专业性

---

*此报告由 Self-Evolving Agent 自动生成*
EOF

echo "反馈报告已生成: $FEEDBACK_REPORT" | tee -a "$LOGFILE"
echo "=== 反馈循环系统完成 - $(date) ===" | tee -a "$LOGFILE"

# 5. 清理旧反馈（保留90天）
find "$FEEDBACK_DIR/processed" -name "*.json" -mtime +90 -delete 2>/dev/null || true
find "$FEEDBACK_DIR" -name "report-*.md" -mtime +90 -delete 2>/dev/null || true