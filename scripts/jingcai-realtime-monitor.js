#!/usr/bin/env node
/**
 * 竞彩临场赔率监控
 * 每5分钟抓取500.com，检查赔率变化
 * 发现暴升/暴降时飞书通知
 */

const { chromium } = require('/home/jinghao/.openclaw/workspace/node_modules/playwright');
const fs = require('fs');
const https = require('https');

const JINGCAI_DIR = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai';
const ODDS_HISTORY_DIR = JINGCAI_DIR + '/odds-history';
const FEISHU_PUSH = process.env.HOME + '/.openclaw/agents/main/send_feishu.js';

const ALERT_THRESHOLD_UP = 0.15;   // 赔率上涨15% = 警告
const ALERT_THRESHOLD_DOWN = -0.10; // 赔率下跌10% = 主队强势
const CRITICAL_THRESHOLD = 0.30;    // 赔率上涨30% = 避开

// 联赛专属阈值
const LEAGUE_ALERT_THRESHOLD = {
  '英超': 0.18,
  '意甲': 0.18,
  '德甲': 0.18,
  '西甲': 0.18,
  '法甲': 0.12,  // 法甲不稳，阈值更低
  '葡超': 0.12,
  '美职': 0.10,
  '澳超': 0.15,
  'J联赛': 0.12,
  'K联赛': 0.12,
  '瑞典超': 0.15,
  '挪超': 0.15,
  '英冠': 0.12,
  '亚冠': 0.10,
  '欧冠': 0.18,
  '欧联': 0.15,
};

// 确保目录存在
fs.mkdirSync(ODDS_HISTORY_DIR, { recursive: true });

// 获取今天日期字符串
function getTodayStr() {
  return new Date().toISOString().split('T')[0];
}

// 获取比赛开赛时间（分钟）
function getMatchMinutesUntilStart(matchTimeStr) {
  // 格式: "04-21 02:45" 或 "02:45"
  const now = new Date();
  let matchTime = matchTimeStr.trim();
  
  if (matchTime.includes('-')) {
    // 格式: "04-21 02:45"
    const [datePart, timePart] = matchTime.split(' ');
    const [month, day] = datePart.split('-').map(Number);
    const [hour, min] = timePart.split(':').map(Number);
    matchTime = `${hour}:${min}`;
    now.setMonth(month - 1, day);
    now.setHours(hour, min, 0, 0);
  } else {
    // 格式: "02:45"
    const [hour, min] = matchTime.split(':').map(Number);
    now.setHours(hour, min, 0, 0);
  }
  
  const diffMs = now.getTime() - Date.now();
  return Math.round(diffMs / 60000);  // 距离开赛分钟数
}

// 从500.com抓取赔率
async function fetchOdds() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-blink-features=AutomationControlled']
  });
  const ctx = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    viewport: { width: 1920, height: 1080 }
  });
  const page = await ctx.newPage();
  await page.setExtraHTTPHeaders({ 'Accept-Language': 'zh-CN,zh;q=0.9' });
  
  await page.goto('https://trade.500.com/jczq/', { timeout: 30000, waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);
  
  const matches = await page.evaluate(() => {
    const results = [];
    const rows = document.querySelectorAll('.bet-tb-tr');
    
    rows.forEach(row => {
      const oddsRows = row.querySelectorAll('.betbtn-row');
      if (oddsRows.length < 1) return;
      
      const text = row.innerText.trim();
      const hadOdds = Array.from(oddsRows[0].querySelectorAll('.betbtn')).map(b => b.innerText.trim());
      if (hadOdds.length < 3) return;
      
      const leagueMatch = text.match(/([\u4e00-\u9fa5]+(?:超|甲|乙|冠|联))\s+(\d{2}-\d{2}\s+\d{2}:\d{2}|\d{2}:\d{2})/);
      const teamMatch = text.match(/\[?\d*\]?([\u4e00-\u9fa5a-zA-Z ]+) VS \[?\d*\]?([\u4e00-\u9fa5a-zA-Z ]+)/);
      const numMatch = text.match(/(周一\d{3}|周二\d{3}|周三\d{3}|周四\d{3}|周五\d{3}|周六\d{3}|周日\d{3})/);
      const rqMatch = text.match(/([+-]\d)/);
      const timeMatch = text.match(/(\d{2}-\d{2}\s+\d{2}:\d{2}|\d{2}:\d{2})/);
      
      const league = leagueMatch ? leagueMatch[1] : '';
      const time = leagueMatch ? leagueMatch[2].trim() : (timeMatch ? timeMatch[1] : '');
      const home = teamMatch ? teamMatch[1].trim() : '';
      const away = teamMatch ? teamMatch[2].trim() : '';
      const num = numMatch ? numMatch[1] : '';
      const rq = rqMatch ? rqMatch[1] : '';
      
      if (home && away) {
        results.push({ num, league, time, home, away, rq, odds: hadOdds });
      }
    });
    
    return results;
  });
  
  await browser.close();
  return matches;
}

// 加载历史赔率
function loadOddsHistory(matchKey) {
  const historyFile = ODDS_HISTORY_DIR + '/' + matchKey + '.json';
  if (fs.existsSync(historyFile)) {
    return JSON.parse(fs.readFileSync(historyFile, 'utf8'));
  }
  return [];
}

// 保存赔率历史
function saveOddsHistory(matchKey, history) {
  const historyFile = ODDS_HISTORY_DIR + '/' + matchKey + '.json';
  fs.writeFileSync(historyFile, JSON.stringify(history, null, 2));
}

// 分析赔率变化
function analyzeOddsChange(currentOdds, history) {
  if (history.length < 1) return null;
  
  const lastOdds = history[history.length - 1];
  const prevOdds = history.length > 1 ? history[history.length - 2] : lastOdds;
  
  const changes = {
    h: (currentOdds[0] - lastOdds.odds[0]) / lastOdds.odds[0],
    d: (currentOdds[1] - lastOdds.odds[1]) / lastOdds.odds[1],
    a: (currentOdds[2] - lastOdds.odds[2]) / lastOdds.odds[2],
  };
  
  const maxChange = Math.max(Math.abs(changes.h), Math.abs(changes.d), Math.abs(changes.a));
  const direction = changes.h > 0.05 ? '主胜涨' : changes.a > 0.05 ? '客胜涨' : '稳定';
  
  return { changes, maxChange, direction, prevOdds, lastOdds };
}

// 发送告警
function sendAlert(match, alertType, change, recommendation) {
  const msg = [
    `🚨 【临场赔率警报】`,
    `${match.league} ${match.home} vs ${match.away}`,
    `时间: ${match.time}`,
    ``,
    `变化: 胜${(change.changes.h*100).toFixed(1)}% | 平${(change.changes.d*100).toFixed(1)}% | 负${(change.changes.a*100).toFixed(1)}%`,
    ``,
    `建议: ${recommendation}`,
    ``,
    `理性投注，量力而行 ⚠️`
  ].join('\n');
  
  try {
    const { execSync } = require('child_process');
    execSync('node ' + FEISHU_PUSH + ' ' + JSON.stringify(msg), { stdio: 'inherit' });
    console.log('✅ 飞书告警已发送');
  } catch(e) {
    console.log('告警发送失败:', e.message);
  }
}

// 主函数
async function main() {
  const today = getTodayStr();
  const nowMinutes = Math.round((Date.now() - new Date().setHours(0,0,0,0)) / 60000);
  console.log('=== 临场赔率监控 - ' + new Date().toISOString() + ' ===');
  
  // 时间窗口：21:00-21:30（投注截止前30分钟）
  if (nowMinutes < 1260 || nowMinutes > 1290) {
    console.log('不在21:00-21:30窗口，跳过 (当前' + Math.floor(nowMinutes/60) + ':' + String(nowMinutes%60).padStart(2,'0') + ')');
    return 0;
  }
  
  // 获取当前赔率
  console.log('抓取500.com...');
  const matches = await fetchOdds();
  console.log('当前比赛数:', matches.length);
  
  const alerts = [];
  
  for (const match of matches) {
    const matchKey = today + '_' + match.num;
    const history = loadOddsHistory(matchKey);
    
    // 获取距离开赛分钟数
    const minutesToStart = getMatchMinutesUntilStart(match.time);
    
    // 记录当前赔率
    history.push({
      time: new Date().toISOString(),
      odds: match.odds,
      minutesToStart
    });
    
    // 只保留最近10条历史
    if (history.length > 10) history.shift();
    saveOddsHistory(matchKey, history);
    
    // 只分析30分钟~3小时内的比赛（临场关键期）
    if (minutesToStart > 180 || minutesToStart < 30) {
      if (minutesToStart >= 0 && minutesToStart <= 30) {
        console.log(`[${match.num}] ${match.home} vs ${match.away} ${match.time} ⏰投注即将截止`);
      }
      continue;
    }
    
    console.log(`[${match.num}] ${match.home} vs ${match.away} ${match.time} (${minutesToStart}分钟后) ⏰临场关键期`);
    
    // 分析赔率变化
    const analysis = analyzeOddsChange(match.odds, history);
    if (!analysis || history.length < 2) continue;
    
    const threshold = LEAGUE_ALERT_THRESHOLD[match.league] || ALERT_THRESHOLD_UP;
    const maxChange = analysis.maxChange;
    
    if (maxChange > CRITICAL_THRESHOLD) {
      // 暴升 > 30% = 避开
      const recommendation = '🚨 果断避开！赔率异常波动';
      sendAlert(match, 'critical', analysis, recommendation);
      alerts.push({ match, type: '🚨避开', analysis });
    } else if (maxChange > threshold) {
      // 警告 > 15%
      const rec = analysis.changes.h > 0 ? '客胜/平局为主' : '主胜为主';
      const recommendation = `⚠️ 谨慎观望 | ${rec}`;
      sendAlert(match, 'warning', analysis, recommendation);
      alerts.push({ match, type: '⚠️谨慎', analysis });
    } else if (maxChange < ALERT_THRESHOLD_DOWN) {
      // 下跌 > 10% = 主队强势
      const recommendation = '📈 主队赔率下跌，关注主胜';
      alerts.push({ match, type: '📈主队强势', analysis });
    } else {
      console.log(`   ✅ 赔率稳定 (最大变化${(maxChange*100).toFixed(1)}%)`);
    }
    
    console.log(`   赔率: ${match.odds.join(' / ')} | 变化: ${analysis.direction}`);
  }
  
  console.log('\n=== 监控完成 ===');
  console.log('告警数:', alerts.length);
  
  if (alerts.length > 0) {
    console.log('\n告警汇总:');
    alerts.forEach(a => {
      console.log(` ${a.type} ${a.match.num} ${a.match.home} vs ${a.match.away}`);
    });
  }
  
  return alerts.length;
}

// 直接运行
main().catch(e => { console.error('Error:', e.message); process.exit(1); });
