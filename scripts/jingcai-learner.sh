#!/bin/bash
# 竞彩投注结果学习器
# 从历史投注记录中学习，更新 Kairos 用户画像 + 调优赔率阈值

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
KAIROS="$HOME/.openclaw/skills/kairos/kairos-learner.py"
MEMORY_SKILL="$HOME/.openclaw/skills/hindsight-memory/lib/multi-agent"

TODAY=$(date +%Y-%m-%d)
LOGFILE="$SELF_IMPROVING_DIR/jingcai/jingcai-learner-$(date +%Y%m%d).log"
mkdir -p "$SELF_IMPROVING_DIR/jingcai"

echo "=== 竞彩学习器 - $(date) ===" | tee -a "$LOGFILE"

RESULTS_FILE="$SELF_IMPROVING_DIR/jingcai/betting-results.md"
THRESHOLDS_FILE="$SELF_IMPROVING_DIR/jingcai/odds-thresholds.json"

# ==================== 1. 统计投注表现 ====================
echo "📊 分析投注表现..." | tee -a "$LOGFILE"

python3 << 'PYEOF'
import re
import json
from pathlib import Path

results_file = Path.home() / '.openclaw/workspace/self-improving/jingcai/betting-results.md'
thresholds_file = Path.home() / '.openclaw/workspace/self-improving/jingcai/odds-thresholds.json'

# 统计
wins = losses = draws = 0
if results_file.exists():
    with open(results_file) as f:
        content = f.read()
    wins = len(re.findall(r'胜|红|赢', content))
    losses = len(re.findall(r'负|黑|输', content))
    draws = len(re.findall(r'平', content))

total = wins + losses + draws
win_rate = wins / total * 100 if total > 0 else 0

print(f"总:{total}场 胜:{wins} 负:{losses} 平:{draws} 胜率:{win_rate:.0f}%")

# 读取当前阈值
try:
    with open(thresholds_file) as f:
        th = json.load(f)
except:
    th = {'danger_threshold': 0.30, 'warning_threshold': 0.15, 'opportunity_threshold': -0.15}

danger = th.get('danger_threshold', 0.30)
warning = th.get('warning_threshold', 0.15)

# 阈值自适应调优逻辑
# 规则：基于胜率调整阈值
# - 胜率高(>55%) → 可适当提高danger阈值（减少假信号）
# - 胜率低(<40%) → 降低danger阈值（增加捕捉机会）
# - 胜率中等(40-55%) → 保持现状
adjusted = False
if total >= 10:
    if win_rate > 55:
        # 用户胜率高，减少假信号警告
        new_danger = round(min(danger + 0.05, 0.45), 2)
        new_warning = round(min(warning + 0.03, 0.25), 2)
        if new_danger != danger:
            th['danger_threshold'] = new_danger
            th['warning_threshold'] = new_warning
            adjusted = True
            print(f"✅ 阈值调优(用户胜率高>{55}%): danger {danger}→{new_danger}")
    elif win_rate < 40:
        # 用户胜率低，收紧阈值多捕捉机会
        new_danger = round(max(danger - 0.05, 0.20), 2)
        new_warning = round(max(warning - 0.03, 0.10), 2)
        if new_danger != danger:
            th['danger_threshold'] = new_danger
            th['warning_threshold'] = new_warning
            adjusted = True
            print(f"⚠️ 阈值调优(用户胜率低<{40}%): danger {danger}→{new_danger}")
    else:
        print(f"阈值保持: danger={danger*100:.0f}% (胜率{win_rate:.0f}%在正常区间)")
else:
    print(f"投注不足10场({total}场)，跳过阈值调优")

with open(thresholds_file, 'w') as f:
    json.dump(th, f, indent=2, ensure_ascii=False)
print(f"阈值已保存: danger>{th['danger_threshold']*100:.0f}% warning>{th['warning_threshold']*100:.0f}%")
PYEOF

# ==================== 2. 查询共享记忆 ====================
echo "📖 读取竞彩分析历史..." | tee -a "$LOGFILE"

HISTORY=$(node -e "
const {AgentContext} = require('$MEMORY_SKILL/index.js');
const ctx = new AgentContext('jingcai-learner');
ctx.queryTeam('竞彩', ['observations', 'mentalModels']).then(results => {
    results.slice(0, 5).forEach(r => console.log(r.content.substring(0, 200)));
}).catch(() => {});
" 2>/dev/null | tr '\n' ' ' | cut -c1-500)

echo "  历史: ${#HISTORY} 字符" | tee -a "$LOGFILE"

# ==================== 3. 调用 Kairos 画像更新 ====================
echo "🎯 更新 Kairos 画像..." | tee -a "$LOGFILE"

INFER_INPUT="/tmp/jingcai-infer-input-$$.txt"
cat > "$INFER_INPUT" << INPUTEOF
INPUTEOF

cat >> "$INFER_INPUT" << EOF
竞彩投注学习 $TODAY
投注统计: 见上方分析
竞彩历史摘要: $HISTORY

请分析以上信息，提取用户竞彩投注特征（只输出特征列表，每行一个）。
EOF

python3 "$KAIROS" \
    --user jinghao \
    --infer "$(cat $INFER_INPUT)" \
    2>&1 | tail -10 >> "$LOGFILE" || echo "  Kairos 完成" | tee -a "$LOGFILE"
rm -f "$INFER_INPUT"

# ==================== 4. 写入共享记忆 ====================
echo "💾 写入共享记忆..." | tee -a "$LOGFILE"

node -e "
const {AgentContext} = require('$MEMORY_SKILL/index.js');
const ctx = new AgentContext('jingcai-learner');
ctx.writeShared('experiences', '竞彩学习 $TODAY: 阈值已调优', {source: 'jingcai-learner', type: 'betting-learning', date: new Date().toISOString()}).then(() => {
    console.log('ok');
}).catch(e => console.error(e.message));
" 2>&1 | tee -a "$LOGFILE" || true

echo "=== 竞彩学习器完成 - $(date) ===" | tee -a "$LOGFILE"
