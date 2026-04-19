#!/bin/bash
# 竞彩足球分析引擎
# 每天分析赔率变化，生成投注建议，写入共享记忆
#
# 功能：
# - 读取当日比赛数据（从共享记忆）
# - 分析赔率变化、战意、盘路
# - 生成投注建议（胜平负/让球/大小球）
# - 写入共享记忆供 Kairos 推理使用

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"
MEMORY_SKILL="$HOME/.openclaw/skills/hindsight-memory/lib/multi-agent"
KAIROS="$HOME/.openclaw/skills/kairos/kairos-learner.py"

TODAY=$(date +%Y-%m-%d)
LOGFILE="$SELF_IMPROVING_DIR/jingcai/jingcai-analyzer-$(date +%Y%m%d).log"
mkdir -p "$SELF_IMPROVING_DIR/jingcai"

echo "=== 竞彩分析 - $(date) ===" | tee -a "$LOGFILE"

# ==================== 1. 用 Kairos 推理生成分析 ====================
echo "🤖 使用 Kairos 推理生成投注分析..." | tee -a "$LOGFILE"

# Kairos infer 基于竞彩经验库推理
INFER_RESULT=$(python3 "$KAIROS" \
    --user jinghao \
    --infer "今天是 $TODAY。请基于以下背景生成今日竞彩投注分析：
1. 优先分析英超/德甲/意甲焦点比赛
2. 重点关注：保级队主场（战意 > 实力）、欧战资格队分心情况
3. 识别赔率异常变化 > 15% 的比赛
4. 给出投注方向建议（优先让球盘/大小球，慎投胜平负高赔）

请输出格式：
## 今日重点比赛
[比赛列表]
## 投注建议
[具体建议]
## 风险提示
[需要避开的比赛]" \
    2>&1 | tail -30 || echo "推理失败")

echo "$INFER_RESULT" >> "$LOGFILE"

# ==================== 2. 分析赔率数据 ====================
echo "📊 分析赔率数据..." | tee -a "$LOGFILE"

# 抓取今日比赛赔率
TODAY_SHORT=$(date +%Y%m%d)
MATCH_API="https://webapi.sporttery.cn/gateway/uniform/football/getMatchCalculatorV1.qry"

ODDS_DATA=$(curl -s --max-time 15 \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
    "$MATCH_API?matchDate=$TODAY_SHORT" 2>/dev/null || echo "{}")

# 分析赔率变化
ODDS_REPORT=$(echo "$ODDS_DATA" | python3 -c "
import sys, json, re

try:
    data = json.load(sys.stdin)
    matches = data.get('value', {}).get('matchList', [])
    print(f'今日比赛: {len(matches)} 场')
    
    anomalies = []
    for m in matches[:10]:  # 只分析前10场
        mid = m.get('matchId', '')
        home = m.get('homeTeamName', m.get('homeName', '?'))
        away = m.get('awayTeamName', m.get('awayName', '?'))
        
        # 赔率分析（简化）
        had = m.get('hadOddsList', [{}])[0] if m.get('hadOddsList') else {}
        if had:
            odds = had.get('odds', 0)
            print(f'  [{mid}] {home} vs {away} | 主胜赔率: {odds}')
            
            if float(odds or 0) > 4.0:
                anomalies.append(f'{home} vs {away} 高赔主胜({odds})')
    
    if anomalies:
        print(f'⚠️ 高赔异常: {len(anomalies)} 场')
        for a in anomalies[:3]:
            print(f'  - {a}')
except Exception as e:
    print(f'解析错误: {e}')
" 2>/dev/null || echo "赔率数据获取失败")

echo "$ODDS_REPORT" | tee -a "$LOGFILE"

# ==================== 3. 写入共享记忆 ====================
echo "💾 写入共享记忆层..." | tee -a "$LOGFILE"

node -e "
const {AgentContext} = require('$MEMORY_SKILL/index.js');
const ctx = new AgentContext('jingcai-analyzer');

const report = \`## $TODAY 竞彩分析报告

### Kairos 推理分析

${INFER_RESULT}

### 赔率数据

${ODDS_REPORT}

### 生成时间
${TODAY}
\`;

ctx.writeShared('mentalModels', report, {
    source: 'jingcai-analyzer',
    type: 'betting-analysis',
    date: '$TODAY',
    tags: ['竞彩', '足球', '分析']
}).then(r => {
    console.log('✅ 分析已写入共享记忆');
}).catch(e => {
    console.error('写入失败:', e.message);
});
" 2>&1 | tee -a "$LOGFILE" || true

# ==================== 4. 生成分析报告 ====================
REPORT="$SELF_IMPROVING_DIR/jingcai/analysis-$(date +%Y%m%d).md"

cat > "$REPORT" <<EOF
# 竞彩分析报告
**时间：** $(date)
**分析时间：** $TODAY

## Kairos 推理结果

${INFER_RESULT}

## 赔率数据

${ODDS_REPORT}

---

*由 Self-Evolving Agent 竞彩分析引擎生成*
EOF

echo "✅ 报告已生成: $REPORT" | tee -a "$LOGFILE"

# ==================== 5. 飞书推送（可选）====================
FEISHU_PUSH="$HOME/.openclaw/agents/main/send_feishu.js"
if [ -f "$FEISHU_PUSH" ] && [ -n "$FEISHU_WEBHOOK_URL" ]; then
    echo "📤 推送分析结果到飞书..." | tee -a "$LOGFILE"
    
    # 推送分析结果摘要
    MATCH_COUNT=$(echo "$ODDS_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('value',{}).get('matchList',[])))" 2>/dev/null || echo "0")
    SUMMARY="📊 竞彩分析报告 $(date +%m/%d)\n\n"
    SUMMARY+="• Kairos 推理: 已完成\n"
    SUMMARY+="• 赔率分析: $MATCH_COUNT 场比赛\n"
    SUMMARY+="• 报告: $REPORT"
    
    node "$FEISHU_PUSH" "$SUMMARY" 2>/dev/null || true
    
    # 赔率异常告警
    ANOMALY_ALERTS=$(echo "$ODDS_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    matches = data.get('value', {}).get('matchList', [])
    anomalies = []
    for m in matches:
        home = m.get('homeTeamName', m.get('homeName', '?'))
        away = m.get('awayTeamName', m.get('awayName', '?'))
        had = m.get('hadOddsList', [{}])[0] if m.get('hadOddsList') else {}
        odds = float(had.get('odds', 0) or 0)
        if odds > 4.0:
            anomalies.append(f'{home} vs {away} 高赔主胜({odds})')
    if anomalies:
        print('\n'.join(anomalies[:5]))
except: pass
" 2>/dev/null)
    
    if [ -n "$ANOMALY_ALERTS" ]; then
        ALERT_MSG="🚨 赔率异常警告\n\n$ANOMALY_ALERTS"
        node "$FEISHU_PUSH" "$ALERT_MSG" 2>/dev/null || true
    fi
fi

echo "=== 竞彩分析完成 - $(date) ===" | tee -a "$LOGFILE"
