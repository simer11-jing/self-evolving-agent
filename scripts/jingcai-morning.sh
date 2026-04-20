#!/bin/bash
# 竞彩早盘预测脚本 - 每天 10:00
# 使用 Playwright 从 okooo.com 获取实时赔率数据
# 保存比赛数量供18点判断

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
JINGCAI_DIR="$SELF_IMPROVING_DIR/jingcai"
OKOOO_SCRIPT="$HOME/.openclaw/workspace/okooo_jingcai.js"
FEISHU_PUSH="$HOME/.openclaw/agents/main/send_feishu.js"
LOGFILE="$JINGCAI_DIR/logs/morning-$(date +%Y%m%d).log"

mkdir -p "$JINGCAI_DIR/logs"

echo "=== 竞彩早盘预测 - $(date) ===" | tee -a "$LOGFILE"

TODAY=$(date +%Y-%m-%d")

# 获取比赛数量并保存
MATCH_COUNT=$(node -e "
const {chromium}=require('playwright');
(async()=>{
  const b=await chromium.launch({headless:true,args:['--no-sandbox']});
  const p=await b.newPage();
  await p.goto('https://www.okooo.com/jingcai/',{timeout:30000,waitUntil:'domcontentloaded'});
  await p.waitForTimeout(5000);
  const n=await p.evaluate(()=>document.querySelectorAll('[data-mid]').length);
  console.log(n);
  await b.close();
})().catch(e=>console.log(0));
" 2>/dev/null)

echo "今日比赛数: $MATCH_COUNT" | tee -a "$LOGFILE"
echo "$MATCH_COUNT" > "$JINGCAI_DIR/match-count-$TODAY.txt"

# 早盘报告
REPORT=$(node "$OKOOO_SCRIPT" "$TODAY" 2>> "$LOGFILE")
if [ -n "$REPORT" ]; then
    echo "$REPORT" | tee -a "$LOGFILE"
    node "$FEISHU_PUSH" "$REPORT" 2>/dev/null && echo "飞书推送成功" | tee -a "$LOGFILE" || echo "飞书推送失败" | tee -a "$LOGFILE"
fi

echo "=== 早盘预测完成 ===" | tee -a "$LOGFILE"
