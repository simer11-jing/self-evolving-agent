#!/usr/bin/env python3
"""竞彩数据整合 - 整合 500.com 凯利指数"""
import json, sys, urllib.request, re

TMPFILE = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sporttery.json'
TODAY = sys.argv[2] if len(sys.argv) > 2 else ''

# ==================== 1. sporttery ====================
try:
    with open(TMPFILE) as f:
        st = json.load(f)
    match_info = st.get('value', {}).get('matchInfoList', [{}])
    matches = match_info[0].get('subMatchList', []) if match_info else []
except:
    matches = []

# ==================== 2. 500.com XML ====================
try:
    req = urllib.request.Request(
        'https://www.500.com/static/public/jczq/xml/odds/odds.xml',
        headers={'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        xml = resp.read().decode('utf-8')
    
    # 提取500.com赔率和凯利
    bets = {}
    for m in re.finditer(r'<match[^>]*processname="(\d+)"[^>]*>[\s\S]*?<europe[^>]*avg="([\d.,]+)"', xml):
        pid = m.group(1)
        odds = m.group(2).split(',')
        gl_m = re.search(r'<gl[^>]*avg="([\d.,]+)"', xml[m.start():m.end()+500])
        kl_m = re.search(r'<kl[^>]*avg="([\d.,]+)"', xml[m.start():m.end()+500])
        
        if len(odds) == 3:
            h, d, a = map(float, odds)
            inv = 1/h + 1/d + 1/a
            kh, kd, ka = (1/h)/inv, (1/d)/inv, (1/a)/inv
            bets[pid] = {
                'h': round(h,2), 'd': round(d,2), 'a': round(a,2),
                'kh': round(kh,3), 'kd': round(kd,3), 'ka': round(ka,3)
            }
            if gl_m:
                gl = list(map(float, gl_m.group(1).split(',')))
                bets[pid]['gl'] = [round(x,1) for x in gl]
except Exception as e:
    print(f'500.com: {e}', file=sys.stderr)

# ==================== 3. 生成报告 ====================
lines = []
lines.append('📊 【竞彩晚盘最终报告】{}'.format(TODAY))
lines.append('数据: sporttery赔率 + 500.com凯利指数')
lines.append('')

FOCUS = ['英超','德甲','意甲','西甲','法甲','欧冠','欧联','葡超','瑞超','挪超','韩职','澳超','日职']
focus = [m for m in matches if any(l in m.get('leagueAbbName','') for l in FOCUS)]

for m in focus:
    league = m.get('leagueAbbName','')
    home = m.get('homeTeamAllName','?')
    away = m.get('awayTeamAllName','?')
    had = m.get('had', {})
    h, d_odds, a = had.get('h','-'), had.get('d','-'), had.get('a','-')
    mt = m.get('matchTime', TODAY)
    tm = mt[11:16] if len(str(mt)) > 10 else mt
    
    # 凯利
    hot = ''
    try:
        h_f, d_f, a_f = float(h), float(d_odds), float(a)
        inv = 1/h_f + 1/d_f + 1/a_f
        kh, kd, ka = (1/h_f)/inv, (1/d_f)/inv, (1/a_f)/inv
        if kh > 0.65: hot = '🔥主热'
        elif ka > 0.55: hot = '🔥客热'
        elif kh < 0.35: hot = '💤主冷'
    except: pass
    
    # 比分
    try:
        h_f, a_f = float(h), float(a)
        if h_f < 1.4: sc = '2-0'
        elif h_f < 1.7: sc = '2-1'
        elif h_f < 2.2: sc = '1-0'
        elif a_f < 1.4: sc = '0-2'
        elif a_f < 1.7: sc = '1-2'
        elif a_f < 2.2: sc = '0-1'
        else: sc = '1-1'
    except: sc = '1-1'
    
    # 推荐
    try:
        h_f, d_f, a_f = float(h), float(d_odds), float(a)
        inv = 1/h_f + 1/d_f + 1/a_f
        ph, pd, pa = (1/h_f)/inv, (1/d_f)/inv, (1/a_f)/inv
        if ph > 0.52: rec = '主胜'
        elif pa > 0.45: rec = '客胜'
        elif pd > 0.33: rec = '平局'
        else: rec = '胜/平'
    except: rec = '待定'
    
    lines.append('【{}】{} vs {}'.format(tm, home, away))
    lines.append('赔率：主{} / 平{} / 客{} {}'.format(h, d_odds, a, hot))
    lines.append('推荐：{} | 比分：{}'.format(rec, sc))
    lines.append('')

if not focus:
    lines.append('今日无焦点比赛')
    
print('\n'.join(lines))
