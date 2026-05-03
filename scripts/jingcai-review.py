#!/usr/bin/env python3
"""竞彩午间复盘 - 统计昨日胜率"""
import re, sys

results_file = sys.argv[1] if len(sys.argv) > 1 else ''
yesterday = sys.argv[2] if len(sys.argv) > 2 else ''

if not results_file or not yesterday:
    print('[REVIEW] 参数不足')
    sys.exit(1)

with open(results_file) as f:
    content = f.read()

# 找昨天日期的section
pattern = r'##\s*' + re.escape(yesterday) + r'[^#]*'
match = re.search(pattern, content)
if not match:
    print('[REVIEW] 昨日({})无赛果记录'.format(yesterday))
    sys.exit(0)

section = match.group()

# 分割各行
lines = section.split('\n')
rows_data = []
for line in lines:
    if not line.strip().startswith('|'):
        continue
    # 解析: 日期|联赛|主队|客队|投注|赔率|半场/全场|盈亏|matchId
    cols = [c.strip() for c in line.split('|')[1:-1]]  # 去掉首尾空
    if len(cols) < 8:
        continue
    # 跳过表头和分隔符
    if cols[0] in ('日期', '联赛', '主队') or cols[0].startswith('-'):
        continue
    # 跳过非日期行
    if not re.match(r'\d{4}-\d{2}-\d{2}', cols[0]):
        continue
    rows_data.append(cols)

total = len(rows_data)
if total == 0:
    print('[REVIEW] 昨日({})无有效赛果'.format(yesterday))
    sys.exit(0)

correct = 0
wrong = 0
pending = 0

for cols in rows_data:
    bet = cols[4].strip()  # 投注: 胜/平/负
    score_str = cols[6].strip() if len(cols) > 6 else ''  # 比分: "半场/全场"
    profit = cols[7].strip() if len(cols) > 7 else ''  # 盈亏: ✅/❌/待定

    # 跳过待定
    if profit in ('待定', '', '待结算'):
        pending += 1
        continue

    # 解析比分: "半场/全场" -> 取全场
    # 格式: "1:0/2:1" 或 "0:0/1:4"
    away_goals = home_goals = None
    try:
        parts = score_str.split('/')
        if len(parts) >= 2:
            home_full = parts[-1].split(':')
            away_full = parts[-1].split(':')
            if len(home_full) == 2:
                home_goals = int(home_full[0])
                away_goals = int(away_full[1]) if len(away_full) == 2 else int(away_full[0])
        elif '/' in score_str:
            # 格式如 "1-0" or "1:0"
            clean = score_str.replace('-', ':')
            gh = clean.split(':')
            if len(gh) == 2:
                home_goals, away_goals = int(gh[0]), int(gh[1])
    except:
        pass

    # 判断胜平负
    actual_result = None
    if home_goals is not None and away_goals is not None:
        if home_goals > away_goals:
            actual_result = '胜'
        elif home_goals < away_goals:
            actual_result = '负'
        else:
            actual_result = '平'

    # 判断对错（优先用✅❌标记）
    if profit in ('✅', '正确', '胜'):
        correct += 1
    elif profit in ('❌', '错误', '负'):
        wrong += 1
    elif actual_result and bet == actual_result:
        correct += 1
    else:
        wrong += 1

confirmed = correct + wrong
win_rate = correct / confirmed * 100 if confirmed > 0 else 0

lines_out = []
lines_out.append('[REVIEW] 竞彩午间复盘 {}'.format(yesterday))
lines_out.append('')
lines_out.append('共 {} 场比赛'.format(total))
lines_out.append('已确认 {} 场，待定 {} 场'.format(confirmed, pending))
if confirmed > 0:
    lines_out.append('正确 {} 场，错误 {} 场'.format(correct, wrong))
    lines_out.append('胜率 {:.1f}%'.format(win_rate))
else:
    lines_out.append('暂无已确认赛果')
lines_out.append('')
if win_rate >= 60:
    lines_out.append('GREEN 表现优秀')
elif win_rate >= 40:
    lines_out.append('YELLOW 表现正常')
else:
    lines_out.append('RED 表现不佳，需调整策略')
lines_out.append('')
lines_out.append('详细记录: {}'.format(results_file))
print('\n'.join(lines_out))
