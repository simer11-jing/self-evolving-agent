#!/usr/bin/env python3
"""竞彩午间复盘 - 统计昨日胜率"""
import re, sys

results_file = sys.argv[1] if len(sys.argv) > 1 else ''
yesterday = sys.argv[2] if len(sys.argv) > 2 else ''

with open(results_file) as f:
    content = f.read()

match = re.search(r'##\s*' + yesterday + r'[^#]*', content)
if not match:
    print('昨日({})无赛果记录'.format(yesterday))
    sys.exit(0)

section = match.group()
# 匹配9列表格: 日期|联赛|主队|客队|投注|赔率|比分|盈亏|备注
rows = re.findall(
    r'\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|',
    section)

total = len(rows)
if total == 0:
    print('昨日无有效赛果')
    sys.exit(0)

def parse_score(score_str):
    """解析比分字符串，返回(主进球,客进球)"""
    # 比分格式: "1:0/1:0" -> 取实际比分 "1:0"
    actual = score_str.split('/')[0].strip()
    parts = actual.split(':')
    if len(parts) == 2:
        try:
            return int(parts[0]), int(parts[1])
        except:
            return None, None
    return None, None

def get_result(home_goals, away_goals):
    """根据比分返回结果: 胜/平/负"""
    if home_goals is None or away_goals is None:
        return None
    if home_goals > away_goals:
        return '胜'
    elif home_goals < away_goals:
        return '负'
    else:
        return '平'

correct = 0
wrong = 0
pending = 0
results_detail = []

for r in rows:
    bet = r[4].strip()  # 投注选项: 胜/平/负
    score_str = r[6].strip()  # 比分
    profit = r[7].strip()  # 盈亏
    
    if profit == '待定':
        pending += 1
        continue
    
    home_goals, away_goals = parse_score(score_str)
    actual_result = get_result(home_goals, away_goals)
    
    if actual_result and actual_result == bet:
        correct += 1
    else:
        wrong += 1

win_rate = correct / (correct + wrong) * 100 if (correct + wrong) > 0 else 0

lines = []
lines.append('[REVIEW] 竞彩午间复盘 {}'.format(yesterday))
lines.append('')
lines.append('共 {} 场比赛'.format(total))
lines.append('已确认 {} 场，待定 {} 场'.format(correct + wrong, pending))
if correct + wrong > 0:
    lines.append('正确 {} 场，错误 {} 场'.format(correct, wrong))
    lines.append('胜率 {:.1f}%'.format(win_rate))
else:
    lines.append('暂无已确认赛果')
lines.append('')

if win_rate >= 60:
    lines.append('GREEN 表现优秀')
elif win_rate >= 40:
    lines.append('YELLOW 表现正常')
else:
    lines.append('RED 表现不佳，需调整策略')

lines.append('')
lines.append('详细记录: {}'.format(results_file))
print('\n'.join(lines))