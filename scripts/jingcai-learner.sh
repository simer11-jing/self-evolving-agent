#!/bin/bash
# 竞彩投注结果学习器
# 从历史投注记录中学习，更新 Kairos 用户画像

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
KAIROS="$HOME/.openclaw/skills/kairos/kairos-learner.py"
MEMORY_SKILL="$HOME/.openclaw/skills/hindsight-memory/lib/multi-agent"

TODAY=$(date +%Y-%m-%d)
LOGFILE="$SELF_IMPROVING_DIR/jingcai/jingcai-learner-$(date +%Y%m%d).log"
mkdir -p "$SELF_IMPROVING_DIR/jingcai"

echo "=== 竞彩学习器 - $(date) ===" | tee -a "$LOGFILE"

# ==================== 1. 读取投注结果 ====================
echo "📊 读取投注结果..." | tee -a "$LOGFILE"

RESULTS_FILE="$SELF_IMPROVING_DIR/jingcai/betting-results.md"

if [ -f "$RESULTS_FILE" ]; then
    # 统计投注结果
    STATS=$(python3 -c "
import re
try:
    with open('$RESULTS_FILE', 'r') as f:
        content = f.read()
    wins = len(re.findall(r'胜|红|赢', content))
    losses = len(re.findall(r'负|黑|输', content))
    draws = len(re.findall(r'平', content))
    total = wins + losses + draws
    if total > 0:
        wr = wins / total * 100
        print(f'总:{total} 胜:{wins} 负:{losses} 平:{draws} 胜率:{wr:.0f}%')
    else:
        print('暂无有效投注')
except Exception as e:
    print('统计失败')
" 2>/dev/null || echo "统计完成")
else
    STATS="暂无投注记录"
fi

echo "  $STATS" | tee -a "$LOGFILE"

# ==================== 2. 查询共享记忆中的竞彩分析 ====================
echo "📖 读取竞彩分析历史..." | tee -a "$LOGFILE"

HISTORY=$(node -e "
const {AgentContext} = require('$MEMORY_SKILL/index.js');
const ctx = new AgentContext('jingcai-learner');
ctx.queryTeam('竞彩', ['observations', 'mentalModels']).then(results => {
    results.slice(0, 5).forEach(r => console.log(r.content.substring(0, 200)));
}).catch(() => {});
" 2>/dev/null | tr '\n' ' ' | cut -c1-500)

echo "  历史记录: ${#HISTORY} 字符" | tee -a "$LOGFILE"

# ==================== 3. 更新 Kairos 画像 ====================
echo "🎯 更新 Kairos 用户画像..." | tee -a "$LOGFILE"

# 写临时文件传递内容
INFER_INPUT="/tmp/jingcai-infer-input-$$.txt"
cat > "$INFER_INPUT" << 'INPUTEOF'
INPUTEOF

cat >> "$INFER_INPUT" << EOF
竞彩投注学习 $TODAY
投注统计: $STATS
竞彩历史摘要: $HISTORY

请分析以上信息，提取用户竞彩投注特征（只输出特征列表，每行一个）。
EOF

KAIROS_RESULT=$(python3 "$KAIROS" \
    --user jinghao \
    --infer "$(cat $INFER_INPUT)" \
    2>&1 | tail -20 || echo "Kairos 调用完成")

echo "$KAIROS_RESULT" >> "$LOGFILE"
rm -f "$INFER_INPUT"

# ==================== 4. 写入共享记忆 ====================
echo "💾 写入共享记忆..." | tee -a "$LOGFILE"

node -e "
const {AgentContext} = require('$MEMORY_SKILL/index.js');
const ctx = new AgentContext('jingcai-learner');
const content = '竞彩投注学习 $TODAY: $STATS';
ctx.writeShared('experiences', content, {source: 'jingcai-learner', type: 'betting-learning', date: new Date().toISOString()}).then(() => {
    console.log('write ok');
}).catch(e => console.error(e.message));
" 2>&1 | tee -a "$LOGFILE" || true

echo "=== 竞彩学习器完成 - $(date) ===" | tee -a "$LOGFILE"
