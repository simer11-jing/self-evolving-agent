#!/usr/bin/env python3
"""竞彩晚盘报告 - 含比分+让球预测"""
import json, sys

tmpfile = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sporttery-evening.json'
today = sys.argv[2] if len(sys.argv) > 2 else ''

with open(tmpfile) as f:
    d = json.load(f)

try:
    match_info = d.get('value', {}).get('matchInfoList', [{}])
    sub_matches = match_info[0].get('subMatchList', []) if match_info else []
except:
    sub_matches = []

leagues = ['英超', '德甲', '意甲', '西甲', '法甲', '欧冠', '欧联', '葡超', '瑞超', '挪超', '韩职', '澳超', '日职']
major = [m for m in sub_matches if any(l in m.get('leagueAbbName', '') for l in leagues)]

lines = []
lines.append('📊 【竞彩晚盘最终报告】{}'.format(today))
lines.append('')
lines.append('今日共 {} 场，焦点 {} 场'.format(len(sub_matches), len(major)))
lines.append('')

def predict_score(h, a):
    """基于赔率预测最可能比分"""
    try:
        h_f = float(h)
        a_f = float(a)
    except:
        return '1-1'
    
    if h_f < 1.4:
        return '2-0'
    elif h_f < 1.7:
        return '2-1'
    elif h_f < 2.2:
        return '1-0'
    elif a_f < 1.4:
        return '0-2'
    elif a_f < 1.7:
        return '1-2'
    elif a_f < 2.2:
        return '0-1'
    else:
        return '1-1'

def recommend(h, d_odds, a):
    """推荐投注选项"""
    try:
        h_f, d_f, a_f = float(h), float(d_odds), float(a)
    except:
        return '胜' 
    
    # 隐含概率
    total = 1/h_f + 1/d_f + 1/a_f
    ph, pd, pa = (1/h_f)/total, (1/d_f)/total, (1/a_f)/total
    
    if ph > 0.55:
        return '主胜'
    elif pa > 0.45 and a_f < 2.5:
        return '客胜'
    elif pd > 0.35:
        return '平局'
    elif ph > 0.40:
        return '胜/平'
    elif pa > 0.35:
        return '平/负'
    else:
        return '胜/平/负'

# 按联赛分组
by_league = {}
for m in major:
    league = m.get('leagueAbbName', '?')
    if league not in by_league:
        by_league[league] = []
    by_league[league].append(m)

for league, lmatches in by_league.items():
    lines.append('⚽ {} ==='.format(league))
    for m in lmatches:
        home = m.get('homeTeamAllName', '?')
        away = m.get('awayTeamAllName', '?')
        had = m.get('had', {})
        h = had.get('h', '-')
        d_odds = had.get('d', '-')
        a = had.get('a', '-')
        mt = m.get('matchTime', today)
        tm = mt[11:16] if len(str(mt)) > 10 else mt
        
        # 让球
        rq = m.get('rq', {})
        rq_handicap = rq.get('h', '') if rq else ''
        rq_odds = rq.get('homeOdds', '') if rq else ''
        
        score = predict_score(h, a)
        rec = recommend(h, d_odds, a)
        
        lines.append('【{}】{} vs {}'.format(tm, home, away))
        lines.append('胜平负：主{} / 平{} / 客{}'.format(h, d_odds, a))
        if rq_handicap:
            lines.append('让球（{}）：{}'.format(rq_handicap, rq_odds if rq_odds else '见市场'))
        lines.append('推荐：{} | 比分预测：{}'.format(rec, score))
        lines.append('')

lines.append('=== 投注建议 ===')
lines.append('重点关注赔率异常比赛，理性投注')
print('\n'.join(lines))
