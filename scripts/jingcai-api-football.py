#!/usr/bin/env python3
"""竞彩复盘脚本 - 使用 api-football 查询历史赛果"""
import json, sys, urllib.request, time
from datetime import datetime, timedelta

API_KEY = "af4c15da6766ceb1a1206dd5c6b89b69"
BASE_URL = "https://v3.football.api-sports.io"

# 联赛ID映射
LEAGUE_IDS = {
    39: "英超",    # Premier League
    135: "意甲",   # Serie A
    78: "德甲",    # Bundesliga
    61: "法甲",    # Ligue 1
    140: "西甲",   # La Liga
}

# api-football 每天100次配额，这里指定要查询的联赛
# 一个联赛=1次API调用，查多个联赛消耗更多
QUERY_LEAGUES = [39, 135, 78, 61, 140]  # 查询5个联赛

def api_get(endpoint, params):
    """调用api-football API"""
    url = BASE_URL + endpoint + "?" + "&".join(f"{k}={v}" for k, v in params.items())
    req = urllib.request.Request(url, headers={
        "x-apisports-key": API_KEY,
        "User-Agent": "Mozilla/5.0"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except Exception as e:
        print(f"API错误: {e}", file=sys.stderr)
        return None

def get_match_results(date_str, league_id):
    """获取指定日期和联赛的比赛结果"""
    result = api_get("/fixtures", {
        "date": date_str,
        "league": league_id,
        "season": 2024,  # 免费版只支持2022-2024
        "timezone": "Asia/Shanghai"
    })
    if not result or result.get("results", 0) == 0:
        return []
    
    matches = []
    for r in result.get("response", []):
        try:
            home = r["teams"]["home"]["name"]
            away = r["teams"]["away"]["name"]
            score_h = r["score"]["fulltime"]["home"]
            score_a = r["score"]["fulltime"]["away"]
            league_name = r["league"]["name"]
            
            if score_h is not None and score_a is not None:
                matches.append({
                    "league": LEAGUE_IDS.get(league_id, league_name),
                    "home": home,
                    "away": away,
                    "score": f"{score_h}-{score_a}",
                    "date": date_str
                })
        except (KeyError, TypeError):
            continue
    return matches

def main():
    # 要查询的日期，默认昨天
    if len(sys.argv) > 1:
        query_date = sys.argv[1]
    else:
        query_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    
    print(f"=== 复盘查询: {query_date} ===")
    print(f"API配额: 每天100次 | 查询联赛: {len(QUERY_LEAGUES)}个")
    print()
    
    all_matches = []
    for league_id in QUERY_LEAGUES:
        league_name = LEAGUE_IDS[league_id]
        print(f"查询 {league_name}({league_id})...", end=" ", flush=True)
        matches = get_match_results(query_date, league_id)
        print(f"{len(matches)}场")
        all_matches.extend(matches)
        time.sleep(0.3)  # 避免请求过快
    
    print(f"\n共找到 {len(all_matches)} 场比赛:")
    for m in all_matches:
        print(f"  [{m['league']}] {m['home']} vs {m['away']} | {m['score']}")
    
    if not all_matches:
        print("⚠️ 免费版仅支持2022-2024年数据，请确认日期在范围内")
    
    return all_matches

if __name__ == "__main__":
    main()
