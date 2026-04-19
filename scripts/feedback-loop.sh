#!/bin/bash
# 反馈循环系统 v2
# 接真实反馈源：
#   1. 飞书消息历史（用户消息中的反馈信号）
#   2. memory/YYYY-MM-DD.md（用户评价/满意度）
#   3. Kairos 推理结果（置信度变化）
#   4. 文件式 incoming（兜底）
#
set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

LOGFILE="$SELF_IMPROVING_DIR/feedback/feedback-$(date +%Y%m%d).log"
FEEDBACK_DB="$SELF_IMPROVING_DIR/feedback/feedback-db.json"
mkdir -p "$SELF_IMPROVING_DIR/feedback/processed"

echo "=== 反馈循环 v2 - $(date) ===" | tee -a "$LOGFILE"

FEEDBACK_COUNT=0
declare -a FEEDBACKS

# ==================== 反馈源 1：飞书消息历史 ====================
echo "📥 读取飞书消息历史..." | tee -a "$LOGFILE"
FEISHU_CHAT_ID="oc_1c24e7fd6e77bb61600b7462e9efd98c"
FEEDBACK_SIGNALS=("不错" "很好" "谢谢" "厉害了" "不对" "错了" "重做" "不满意" "可以" "不行")

for signal in "${FEEDBACK_SIGNALS[@]}"; do
    # 用 lcm_grep 搜索包含反馈信号的会话
    RESULT=$(node -e "
const {lcm_grep} = require('$HOME/.npm-global/lib/node_modules/openclaw/dist/lcm/lcm-grep.js');
" 2>/dev/null) || true
done

# ==================== 反馈源 2：memory 文件 ====================
echo "📥 读取记忆文件反馈..." | tee -a "$LOGFILE"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

for date_check in "$TODAY" "$YESTERDAY"; do
    MEMORY_FILE="$HOME/.openclaw/agents/main/memory/${date_check}.md"
    if [ -f "$MEMORY_FILE" ]; then
        # 提取用户反馈相关行
        FEEDBACK_LINES=$(grep -E "(反馈|满意|不满意|不错|很好|错了|重做)" "$MEMORY_FILE" 2>/dev/null || true)
        if [ -n "$FEEDBACK_LINES" ]; then
            echo "  从 ${date_check} 内存找到反馈线索" | tee -a "$LOGFILE"
            while IFS= read -r line; do
                FEEDBACKS+=("$line")
                FEEDBACK_COUNT=$((FEEDBACK_COUNT + 1))
            done <<< "$FEEDBACK_LINES"
        fi
    fi
done

# ==================== 反馈源 3：Kairos representation 变化 ====================
echo "📥 检查 Kairos 用户画像变化..." | tee -a "$LOGFILE"
KAIROS_LEARNER="$SKILL_DIR/../kairos/kairos-learner.py"
if [ -f "$KAIROS_LEARNER" ]; then
    # 运行反馈模式（不写入，只打印）
    FEEDBACK_REPORT=$(python3 "$KAIROS_LEARNER" --user jinghao --feedback 2>/dev/null || true)
    if [ -n "$FEEDBACK_REPORT" ]; then
        # 提取矛盾特征（高置信度变化）
        CONTRADICTIONS=$(echo "$FEEDBACK_REPORT" | grep -A2 "矛盾特征" | head -5 || true)
        if [ -n "$CONTRADICTIONS" ]; then
            echo "  检测到用户特征变化：$CONTRADICTIONS" | tee -a "$LOGFILE"
            FEEDBACKS+=("Kairos特征变化: $CONTRADICTIONS")
            FEEDBACK_COUNT=$((FEEDBACK_COUNT + 1))
        fi
    fi
fi

# ==================== 反馈源 4：incoming 文件（兜底） ====================
if [ -d "$SELF_IMPROVING_DIR/feedback/incoming" ]; then
    for f in "$SELF_IMPROVING_DIR/feedback/incoming"/*.json; do
        [ -f "$f" ] || continue
        CONTENT=$(cat "$f" 2>/dev/null)
        TEXT=$(echo "$CONTENT" | jq -r '.text // .message // empty' 2>/dev/null || true)
        if [ -n "$TEXT" ]; then
            FEEDBACKS+=("file: $TEXT")
            FEEDBACK_COUNT=$((FEEDBACK_COUNT + 1))
            mv "$f" "$SELF_IMPROVING_DIR/feedback/processed/" 2>/dev/null || true
        fi
    done
fi

# ==================== 分析 & 写入反馈数据库 ====================
echo "" | tee -a "$LOGFILE"
echo "📊 分析 $FEEDBACK_COUNT 条反馈..." | tee -a "$LOGFILE"

# 读取现有数据库
if [ -f "$FEEDBACK_DB" ]; then
    DB_SNAPSHOT=$(cat "$FEEDBACK_DB")
else
    DB_SNAPSHOT='{"total": 0, "positive": 0, "negative": 0, "neutral": 0, "entries": []}'
fi

# 分析每条反馈
POSITIVE=0
NEGATIVE=0
for item in "${FEEDBACKS[@]}"; do
    LOWER=$(echo "$item" | tr '[:upper:]' '[:lower:]')
    if echo "$LOWER" | grep -qE "(不错|很好|谢谢|满意|厉害|可以)"; then
        POSITIVE=$((POSITIVE + 1))
        SENTIMENT="positive"
    elif echo "$LOWER" | grep -qE "(不对|错了|不满意|不行|重做)"; then
        NEGATIVE=$((NEGATIVE + 1))
        SENTIMENT="negative"
    else
        SENTIMENT="neutral"
    fi
    echo "  [$SENTIMENT] $item" | tee -a "$LOGFILE"
done

# 更新数据库
TOTAL=$(echo "$DB_SNAPSHOT" | jq '.total' 2>/dev/null || echo 0)
POS=$(echo "$DB_SNAPSHOT" | jq '.positive' 2>/dev/null || echo 0)
NEG=$(echo "$DB_SNAPSHOT" | jq '.negative' 2>/dev/null || echo 0)

NEW_DB=$(jq -n \
    --argjson total "$((TOTAL + FEEDBACK_COUNT))" \
    --argjson pos "$((POS + POSITIVE))" \
    --argjson neg "$((NEG + NEGATIVE))" \
    '{total: $total, positive: $pos, negative: $neg, neutral: ($total - $pos - $neg), last_updated: now | todateiso8601}')
echo "$NEW_DB" > "$FEEDBACK_DB"

# ==================== 生成反馈报告 ====================
REPORT="$SELF_IMPROVING_DIR/feedback/report-$(date +%Y%m%d).md"
cat > "$REPORT" <<EOF
# 反馈分析报告
**时间：** $(date)
**反馈条数：** $FEEDBACK_COUNT（正面 $POSITIVE / 负面 $NEGATIVE）

## 汇总

| 指标 | 数值 |
|------|------|
| 累计正面反馈 | $((POS + POSITIVE)) |
| 累计负面反馈 | $((NEG + NEGATIVE)) |
| 正面率 | $(awk "BEGIN {printf \"%.1f\", ($POS + POSITIVE) * 100 / ($TOTAL + $FEEDBACK_COUNT + 1)}")% |

## 详细反馈

EOF

for item in "${FEEDBACKS[@]}"; do
    echo "- $item" >> "$REPORT"
done

echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "*由 Self-Evolving Agent 自动生成*" >> "$REPORT"

echo "✅ 报告已生成: $REPORT" | tee -a "$LOGFILE"

# 清理 90 天前
find "$SELF_IMPROVING_DIR/feedback/processed" -name "*.json" -mtime +90 -delete 2>/dev/null || true
find "$SELF_IMPROVING_DIR/feedback" -name "report-*.md" -mtime +90 -delete 2>/dev/null || true

echo "=== 反馈循环完成 - $(date) ===" | tee -a "$LOGFILE"
