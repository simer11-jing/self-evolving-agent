#!/bin/bash
# 竞彩赛果自动抓取脚本
# 从 sporttery.cn 官方 API 抓取昨日赛果，自动填入 betting-results.md

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
RESULTS_FILE="$SELF_IMPROVING_DIR/jingcai/betting-results.md"
mkdir -p "$SELF_IMPROVING_DIR/jingcai"

YESTERDAY=$(date -d 'yesterday' +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)
TMPFILE="/tmp/sporttery-results-$$.json"
trap "rm -f $TMPFILE" EXIT

echo "=== 赛果抓取 - $YESTERDAY ==="

# 调用 sporttery.cn 赛果 API
API_URL="https://webapi.sporttery.cn/gateway/uniform/football/getUniformMatchResultV1.qry?matchBeginDate=${YESTERDAY}&matchEndDate=${YESTERDAY}&pageSize=50&pageNo=1&pcOrWap=1&isFix=0&matchPage=1"

curl -s --max-time 15 "$API_URL" -o "$TMPFILE"

if [ ! -s "$TMPFILE" ]; then
    echo "❌ API 调用失败"
    exit 1
fi

python3 -c "import json; json.load(open('$TMPFILE'))" 2>/dev/null || {
    echo "❌ JSON 解析失败"
    exit 1
}

echo "✅ API 调用成功"

python3 << PYEOF
import json, re, os

TMPFILE = "$TMPFILE"
RESULTS_FILE = "$RESULTS_FILE"
YESTERDAY = "$YESTERDAY"

with open(TMPFILE) as f:
    d = json.load(f)

matches = d.get('value', {}).get('matchResult', [])

if not matches:
    print(f"昨日（{YESTERDAY}）无已结算比赛")
    exit(0)

# 只取已结算的（full score 存在）
settled = [m for m in matches if m.get('sectionsNo999')]
print(f"昨日共 {len(matches)} 场，{len(settled)} 场已结算")

if not settled:
    exit(0)

# 读取已有的 matchId
existing_ids = set()
if os.path.exists(RESULTS_FILE):
    existing_ids = set(re.findall(r'matchId[=:\s]*(\d+)', open(RESULTS_FILE).read()))

result_map = {'H': '胜', 'A': '负', 'D': '平'}
new_lines = []

for m in settled:
    mid = str(m.get('matchId', ''))
    if mid in existing_ids:
        continue

    league = m.get('leagueNameAbbr', m.get('leagueName', ''))
    home = m.get('homeTeam', m.get('allHomeTeam', '?'))
    away = m.get('awayTeam', m.get('allAwayTeam', '?'))
    wf = m.get('winFlag', '')
    result_text = result_map.get(wf, wf or '-')

    h = m.get('h', '')
    d_odds = m.get('d', '')
    a = m.get('a', '')
    odds_str = '/'.join([f"{k}{v}" for k, v in [('胜', h), ('平', d_odds), ('负', a)] if v])

    half = m.get('sectionsNo1', '-')
    full = m.get('sectionsNo999', '-')
    match_date = m.get('matchDate', YESTERDAY)

    new_lines.append(f"| {match_date} | {league} | {home} | {away} | {result_text} | {odds_str} | {half}/{full} | 待定 | matchId={mid}")

if new_lines:
    with open(RESULTS_FILE, 'a', encoding='utf-8') as f:
        f.write(f"\n## {YESTERDAY} 赛果（自动抓取）\n")
        f.write("| 日期 | 联赛 | 主队 | 客队 | 投注 | 赔率 | 比分 | 盈亏 | 备注 |\n")
        f.write("|------|------|------|------|------|------|------|------|------|\n")
        f.write('\n'.join(new_lines) + '\n')
    print(f"✅ 新增 {len(new_lines)} 条赛果 → {RESULTS_FILE}")
else:
    print("没有新增记录（昨日比赛已在文件中）")

print(f"\n昨日赛果（前5场）:")
for m in settled[:5]:
    print(f"  {m.get('leagueNameAbbr','?')} {m.get('homeTeam','?')} vs {m.get('awayTeam','?')}  {m.get('sectionsNo1','?')}/{m.get('sectionsNo999','?')}  结果:{result_map.get(m.get('winFlag',''),'?')}")
PYEOF

echo "=== 赛果抓取完成 ==="
