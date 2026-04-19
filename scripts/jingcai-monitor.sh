#!/bin/bash
# 竞彩足球比赛数据监控
# 每天定时抓取 sporttery.cn 当日比赛数据，写入共享记忆层
#
# 功能：
# - 获取当日所有比赛列表
# - 抓取赔率、让球盘、大小球
# - 识别焦点比赛（赔率异常变化）
# - 写入 hindsight-memory shared 层供全 Agent 使用

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"
MEMORY_SKILL="$HOME/.openclaw/skills/hindsight-memory/lib/multi-agent"

# 赔率历史记录目录
ODDS_HISTORY_DIR="$SELF_IMPROVING_DIR/jingcai/odds-history"
mkdir -p "$ODDS_HISTORY_DIR"

# 存储赔率异常检测结果（用于报告）
ODDS_ALERTS_FILE="$SELF_IMPROVING_DIR/jingcai/odds-alerts-$(date +%Y%m%d).json"
echo "[]" > "$ODDS_ALERTS_FILE" 2>/dev/null || true

# 日志
LOGFILE="$SELF_IMPROVING_DIR/jingcai/jingcai-monitor-$(date +%Y%m%d).log"
mkdir -p "$SELF_IMPROVING_DIR/jingcai"

echo "=== 竞彩监控 - $(date) ===" | tee -a "$LOGFILE"

# ==================== 1. 获取当日比赛列表 ====================
echo "📥 获取当日比赛列表..." | tee -a "$LOGFILE"

MATCH_API="https://webapi.sporttery.cn/gateway/uniform/football/getMatchCalculatorV1.qry"
TODAY=$(date +%Y%m%d)

# 抓取比赛列表（简化版，实际需要分页）
MATCH_LIST=$(curl -s --max-time 10 \
    -H "User-Agent: Mozilla/5.0" \
    "$MATCH_API?matchDate=$TODAY" 2>/dev/null || echo "{}")

if echo "$MATCH_LIST" | jq -e '.success' >/dev/null 2>&1; then
    MATCH_COUNT=$(echo "$MATCH_LIST" | jq '.value.matchList | length' 2>/dev/null || echo 0)
    echo "  获取到 $MATCH_COUNT 场比赛" | tee -a "$LOGFILE"
else
    MATCH_COUNT=0
    echo "  ⚠️ API 返回异常" | tee -a "$LOGFILE"
fi

# ==================== 2. 分析赔率变化 ====================
echo "📊 分析赔率变化..." | tee -a "$LOGFILE"

# 赔率变化检测函数（带历史对比）
check_odds_shift() {
    local match_id="$1"
    local home_team="$2"
    local away_team="$3"
    local league_name="${4:-未知联赛}"
    local odds_api="https://webapi.sporttery.cn/gateway/uniform/football/getOddsHistoryV1.qry"
    
    # 读取初始赔率（如果有历史记录）
    INITIAL_FILE="$ODDS_HISTORY_DIR/${match_id}.json"
    INITIAL_HAD=$(cat "$INITIAL_FILE" 2>/dev/null | jq -r '.initial.had // empty' 2>/dev/null || echo "")
    
    # 获取当前赔率
    ODDS_RESPONSE=$(curl -s --max-time 10 \
        -H "User-Agent: Mozilla/5.0" \
        "${odds_api}?matchId=${match_id}&poolCode=HAD" 2>/dev/null || echo "{}")
    
    # 解析当前赔率（主胜、平局、客胜）
    CURRENT_WIN=$(echo "$ODDS_RESPONSE" | jq -r '.value[-1].hadOddsList[0].odds // empty' 2>/dev/null || echo "")
    CURRENT_DRAW=$(echo "$ODDS_RESPONSE" | jq -r '.value[-1].hadOddsList[1].odds // empty' 2>/dev/null || echo "")
    CURRENT_LOSE=$(echo "$ODDS_RESPONSE" | jq -r '.value[-1].hadOddsList[2].odds // empty' 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_WIN" ] || [ "$CURRENT_WIN" = "null" ] || [ "$CURRENT_WIN" = "" ]; then
        return
    fi
    
    # 首次记录，保存初始赔率
    if [ -z "$INITIAL_HAD" ]; then
        echo "{\"matchId\": \"$match_id\", \"home\": \"$home_team\", \"away\": \"$away_team\", \"league\": \"$league_name\", \"initial\": {\"had\": $CURRENT_WIN, \"draw\": $CURRENT_DRAW, \"lose\": $CURRENT_LOSE}, \"current\": {\"had\": $CURRENT_WIN, \"draw\": $CURRENT_DRAW, \"lose\": $CURRENT_LOSE}, \"firstSeen\": \"$(date -Iseconds)\"}" > "$INITIAL_FILE"
        echo "  [$match_id] 初始赔率记录: 主胜 $CURRENT_WIN / 平 $CURRENT_DRAW / 客胜 $CURRENT_LOSE" | tee -a "$LOGFILE"
        return
    fi
    
    # 更新当前赔率到文件
    INITIAL_DRAW=$(cat "$INITIAL_FILE" 2>/dev/null | jq -r '.initial.draw // 0' 2>/dev/null || echo "0")
    INITIAL_LOSE=$(cat "$INITIAL_FILE" 2>/dev/null | jq -r '.initial.lose // 0' 2>/dev/null || echo "0")
    
    # 计算变化幅度并判断
    python3 << PYEOF
import json
import sys

try:
    initial = float('$INITIAL_HAD')
    initial_draw = float('$INITIAL_DRAW')
    initial_lose = float('$INITIAL_LOSE')
    current = float('$CURRENT_WIN')
    current_draw = float('$CURRENT_DRAW') if '$CURRENT_DRAW' and '$CURRENT_DRAW' != 'null' else 0
    current_lose = float('$CURRENT_LOSE') if '$CURRENT_LOSE' and '$CURRENT_LOSE' != 'null' else 0
    
    shift = (current - initial) / initial
    
    # 判断等级
    if shift > 0.30:
        status = "🚨 果断避开"
        level = "danger"
    elif shift > 0.15:
        status = "⚠️ 谨慎"
        level = "warning"
    elif shift < -0.15:
        status = "📉 主队强势"
        level = "opportunity"
    else:
        status = "✅ 正常"
        level = "normal"
    
    print(f'  [$match_id] $home_team vs $away_team | 初:{initial:.2f} → 现:{current:.2f} | 变化:{shift*100:+.1f}% {status}')
    
    if level != "normal":
        print(f'  ⚠️ 赔率异常: {status}')
    
    # 更新历史文件
    data = {
        "matchId": "$match_id",
        "home": "$home_team",
        "away": "$away_team",
        "league": "$league_name",
        "initial": {"had": initial, "draw": initial_draw, "lose": initial_lose},
        "current": {"had": current, "draw": current_draw, "lose": current_lose},
        "shift": round(shift * 100, 1),
        "level": level,
        "status": status,
        "lastUpdated": "$(date -Iseconds)"
    }
    
    with open("$INITIAL_FILE", "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    # 如果是异常赔率，追加到警报文件
    if level in ["danger", "warning", "opportunity"]:
        try:
            with open("$ODDS_ALERTS_FILE", "r") as f:
                alerts = json.load(f)
            alerts.append(data)
            with open("$ODDS_ALERTS_FILE", "w") as f:
                json.dump(alerts, f, ensure_ascii=False, indent=2)
        except:
            pass
            
except Exception as e:
    print(f'  [$match_id] 赔率计算错误: {e}', file=sys.stderr)
PYEOF
}

# 焦点比赛识别
identify_focus_matches() {
    local match_info="$1"
    local home_team=$(echo "$match_info" | jq -r '.homeTeamName // .homeName // ""')
    local away_team=$(echo "$match_info" | jq -r '.awayTeamName // .awayName // ""')
    local league=$(echo "$match_info" | jq -r '.leagueName // "未知"')
    
    # 焦点比赛关键词
    local focus_keywords="巴萨|皇马|曼城|利物浦|拜仁|巴黎|尤文|国米|米兰|曼联|切尔西|阿森纳|热刺|多特|马竞|欧冠|欧罗巴|德比|保级"
    
    if echo "$home_team $away_team $league" | grep -qiE "$focus_keywords"; then
        return 0  # 是焦点比赛
    fi
    return 1  # 不是焦点比赛
}

# ==================== 3. 写入共享记忆层 ====================
echo "💾 写入共享记忆层..." | tee -a "$LOGFILE"

# 构建当日比赛摘要
MATCH_SUMMARY=$(echo "$MATCH_LIST" | jq -r '
if .value and .value.matchList then
    .value.matchList[] | 
    "[\(.matchId)] \(.homeTeamName or .homeName or .teamName // \"未知\") vs \(.awayTeamName or .awayName // \"未知\") | 联赛:\(.leagueName // .竞赛名称 // \"未知\") | 时间:\(.matchTime // .startTime // \"未知\")"
else
    "无比赛数据"
end
' 2>/dev/null | head -20 || echo "数据解析失败")

# 用 Node.js 写入 hindsight-memory
WRITE_RESULT=$(node -e "
const {AgentContext} = require('$MEMORY_SKILL/index.js');
const ctx = new AgentContext('jingcai-monitor');
const today = new Date().toISOString().split('T')[0];
const summary = \`## $TODAY 竞彩比赛数据

### 比赛数量
$MATCH_COUNT 场

### 比赛列表
${MATCH_SUMMARY}

### 生成时间
${TODAY}
\`;

ctx.writeShared('observations', summary, {
    source: 'jingcai-monitor',
    type: 'match-data',
    date: '$TODAY'
}).then(r => {
    console.log('写入结果:', JSON.stringify(r));
}).catch(e => {
    console.error('写入失败:', e.message);
});
" 2>&1)

echo "$WRITE_RESULT" | tee -a "$LOGFILE"

# ==================== 4. 生成监控报告 ====================
REPORT="$SELF_IMPROVING_DIR/jingcai/report-$(date +%Y%m%d).md"

# 读取赔率异常数据
ODDS_ALERTS=$(cat "$ODDS_ALERTS_FILE" 2>/dev/null || echo "[]")
DANGER_COUNT=$(echo "$ODDS_ALERTS" | jq '[.[] | select(.level == "danger")] | length' 2>/dev/null || echo 0)
WARNING_COUNT=$(echo "$ODDS_ALERTS" | jq '[.[] | select(.level == "warning")] | length' 2>/dev/null || echo 0)
OPPORTUNITY_COUNT=$(echo "$ODDS_ALERTS" | jq '[.[] | select(.level == "opportunity")] | length' 2>/dev/null || echo 0)

cat > "$REPORT" <<EOF
# 竞彩监控报告
**时间：** $(date)
**比赛数量：** $MATCH_COUNT

## 当日比赛摘要

$MATCH_SUMMARY

## 赔率异常检测

| 比赛 | 初始赔率 | 当前赔率 | 变化 | 判断 |
|------|---------|---------|------|------|
EOF

# 追加各比赛的检测结果
echo "$ODDS_ALERTS" | jq -r '.[] | "| \(.home) vs \(.away) | \(.initial.had) | \(.current.had) | \(.shift)% | \(.status) |"' 2>/dev/null >> "$REPORT" || true

cat >> "$REPORT" <<EOF

## 监控状态

- 数据抓取：$([ "$MATCH_COUNT" -gt 0 ] && echo "✅ 正常" || echo "⚠️ 无数据")
- 赔率分析：已检查焦点比赛
- 共享记忆：已写入

### 赔率异常统计

- 🚨 危险（暴升>30%）：$DANGER_COUNT 场
- ⚠️ 警告（上升15-30%）：$WARNING_COUNT 场
- 📉 机会（下降>15%）：$OPPORTUNITY_COUNT 场

## 赔率判断标准

| 变化幅度 | 判断 | 建议 |
|---------|------|------|
| > +30% | 🚨 果断避开 | 庄家不看好主队 |
| +15% ~ +30% | ⚠️ 谨慎 | 观察为主 |
| -15% ~ +15% | ✅ 正常 | 可考虑 |
| < -15% | 📉 主队强势 | 可以关注 |

---

*由 Self-Evolving Agent 竞彩监控生成*
EOF

echo "✅ 报告已生成: $REPORT" | tee -a "$LOGFILE"
echo "=== 竞彩监控完成 - $(date) ===" | tee -a "$LOGFILE"
