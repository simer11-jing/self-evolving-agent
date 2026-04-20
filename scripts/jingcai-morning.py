#!/usr/bin/env python3
"""竞彩早盘预测 - 含比分+让球预测"""
import json, sys

tmpfile = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sporttery-morning.json'
today = sys.argv[2] if len(sys.argv) > 2 else ''

with open(tmpfile) as f:
    d = json.load(f)

try:
    match_info = d.get('value', {}).get('matchInfoList', [{}])
    sub_matches = match_info[0].get('subMatchList', []) if match_info else []
except:
    sub_matches = []

leagues = ['英超', '德甲', '意甲', '西甲', '法甲', '欧冠', '欧联', '葡超', '荷甲', '瑞超', '挪超', '韩职', '澳超', '日职']
major = [m for m in sub_matches if any(l in m.get('leagueAbbName', '') for l in leagues)]

lines = []
lines.append('📊 【竞彩早盘预测】{}'.format(today))
lines.append('')
lines.append('今日共 {} 场，焦点 {} 场'.format(len(sub_matches), len(major)))
lines.append('')

for m in major[:8]:
    league = m.get('leagueAbbName', '?')
    home = m.get('homeTeamAllName', '?')
    away = m.get('awayTeamAllName', '?')
    had = m.get('had', {})
    h = had.get('h', '-')
    d_odds = had.get('d', '-')
    a = had.get('a', '-')
    mt = m.get('matchTime', today)
    tm = mt[11:16] if len(str(mt)) > 10 else mt
    
    # 让球（如果有）
    rq = m.get('rq', {})
    rqHandicap = rq.get('h', '') if rq else ''
    
    # 简单比分推断（基于赔率）
    h_float = float(h) if h != '-' else 2.0
    a_float = float(a) if a != '-' else 2.5
    
    # 赔率越低越可能赢
    if h_float < 1.5:
        home_goals = 2
        away_goals = 0
    elif h_float < 2.0:
        home_goals = 2
        away_goals = 1
    elif a_float < 1.8:
        home_goals = 0
        away_goals = 2
    else:
        home_goals = 1
        away_goals = 1
    
    score = '{}-{}'.format(home_goals, away_goals)
    
    lines.append('【{}】{} vs {}'.format(tm, home, away))
    lines.append('胜平负：主{} / 平{} / 客{}'.format(h, d_odds, a))
    if rqHandicap:
        lines.append('让球：{}'.format(rqHandicap))
    lines.append('推荐：主胜 | 比分预测：{}'.format(score))
    lines.append('')

lines.append('详细分析见 21:00 晚盘修正')
print('\n'.join(lines))
