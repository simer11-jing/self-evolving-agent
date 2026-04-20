#!/usr/bin/env python3
"""竞彩午后修正 - 检测赔率异常+比分预测"""
import json, sys

tmpfile = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sporttery-afternoon.json'
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

def predict_score(h, a):
    try:
        h_f, a_f = float(h), float(a)
    except:
        return '1-1'
    if h_f < 1.4: return '2-0'
    elif h_f < 1.7: return '2-1'
    elif h_f < 2.2: return '1-0'
    elif a_f < 1.4: return '0-2'
    elif a_f < 1.7: return '1-2'
    elif a_f < 2.2: return '0-1'
    else: return '1-1'

lines = []
lines.append('📊 【竞彩午后修正】{}'.format(today))
lines.append('')
lines.append('今日 {} 场焦点比赛'.format(len(major)))
lines.append('')

# 检测赔率异常
alerts = []
for m in major:
    had = m.get('had', {})
    h = had.get('h', '0')
    d_odds = had.get('d', '0')
    a = had.get('a', '0')
    try:
        h_f, d_f, a_f = float(h), float(d_odds), float(a)
        if h_f <= 0: continue
        total = 1/h_f + 1/d_f + 1/a_f
        prob_h = (1/h_f)/total
        # 赔率偏高（主队被低估）
        if h_f > 2.5 and prob_h < 0.40:
            alerts.append({
                'm': m,
                'h': h_f, 'd': d_f, 'a': a_f,
                'prob_h': prob_h
            })
    except:
        pass

if alerts:
    lines.append('⚠️ 赔率异常（主队被低估）：')
    for item in alerts[:3]:
        m = item['m']
        home = m.get('homeTeamAllName', '?')
        away = m.get('awayTeamAllName', '?')
        lines.append('【{}】{} vs {}'.format(m.get('leagueAbbName',''), home, away))
        lines.append('赔率：主{} / 平{} / 客{}'.format(item['h'], item['d'], item['a']))
        lines.append('主胜概率：{:.0f}%'.format(item['prob_h']*100))
        lines.append('')

lines.append('📋 午后修正预测：')
for m in major[:6]:
    home = m.get('homeTeamAllName', '?')
    away = m.get('awayTeamAllName', '?')
    had = m.get('had', {})
    h, d_odds, a = had.get('h','-'), had.get('d','-'), had.get('a','-')
    score = predict_score(h, a)
    try:
        h_f, d_f, a_f = float(h), float(d_odds), float(a)
        total = 1/h_f + 1/d_f + 1/a_f
        ph, pd, pa = (1/h_f)/total, (1/d_f)/total, (1/a_f)/total
        rec = '主胜' if ph > 0.50 else ('客胜' if pa > 0.40 else '平局')
    except:
        rec = '待定'
    lines.append('{} vs {} | 推荐:{} | 比分:{}'.format(home, away, rec, score))

lines.append('')
lines.append('详细分析见 21:00 最终报告')
print('\n'.join(lines))
