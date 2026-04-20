#!/usr/bin/env node
/**
 * 竞彩投注风控引擎
 * 功能：
 * 1. Kelly公式计算最优投注比例
 * 2. ROI追踪（每单盈亏、本金、回撤）
 * 3. 单日投注限额（最多N单）
 * 4. 联赛专属Kelly阈值
 */

const fs = require('fs');
const path = require('path');

const BETTING_FILE = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai/betting-results.md';
const STATS_FILE = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai/betting-stats.json';
const JINGCAI_DIR = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai';

// Kelly公式: f* = (p*b - q) / b
// p = 胜率（隐含概率的调整值）
// b = 赔率 - 1
// q = 1 - p
function kellyFraction(odds, probability, confidence = 1.0) {
  const b = odds - 1;  // 净赔率
  const p = probability * confidence;  // 调整后的胜率
  const q = 1 - p;
  
  if (b <= 0) return 0;
  
  // Kelly比 = (p*(b+1) - 1) / b
  const kelly = (p * (b + 1) - 1) / b;
  
  // 实际投注不超过Kelly的一半（保守）
  return Math.max(0, Math.min(kelly * 0.5, 0.1));  // 最多10%本金
}

// 联赛专属置信度调整
const LEAGUE_CONFIDENCE = {
  '英超': { base: 1.0, safeOdds: 1.35 },
  '意甲': { base: 1.0, safeOdds: 1.35 },
  '德甲': { base: 1.0, safeOdds: 1.35 },
  '西甲': { base: 1.0, safeOdds: 1.35 },
  '法甲': { base: 0.85, safeOdds: 1.25, note: '客队强势' },
  '葡超': { base: 0.85, safeOdds: 1.50, note: '客队强势' },
  '美职': { base: 0.80, safeOdds: 1.30, note: '客场强队多' },
  '澳超': { base: 0.90, safeOdds: 1.40 },
  'J联赛': { base: 0.85, safeOdds: 1.45 },
  'K联赛': { base: 0.85, safeOdds: 1.45 },
  '瑞典超': { base: 0.90, safeOdds: 1.40, note: '主场优势大' },
  '挪超': { base: 0.90, safeOdds: 1.40 },
  '瑞士超': { base: 0.90, safeOdds: 1.40 },
  '英冠': { base: 0.85, safeOdds: 1.50, note: '实力接近' },
  '亚冠': { base: 0.80, safeOdds: 1.40 },
  '欧冠': { base: 1.0, safeOdds: 1.35 },
  '欧联': { base: 0.95, safeOdds: 1.40 },
  '欧协': { base: 0.85, safeOdds: 1.45 },
};

// 最大投注参数
const MAX_DAILY_BETS = 3;       // 单日最多投注数
const MAX_BANKROLL_PCT = 0.1;   // 单次最多投注本金10%
const BASE_BANKROLL = 1000;     // 假设本金1000元

// 从betting-results.md读取历史数据
function loadBettingHistory() {
  if (!fs.existsSync(BETTING_FILE)) return [];
  
  const content = fs.readFileSync(BETTING_FILE, 'utf8');
  const rows = [];
  const lines = content.split('\n');
  
  for (const line of lines) {
    // 解析 | 2026-04-19 | 英超 | ... | 胜 | 1.37 | 4-1 | ✅ |
    const match = line.match(/\| (\d{4}-\d{2}-\d{2}) \| ([^\|]+) \| ([^\|]+) \| ([^\|]+) \| ([^\|]+) \| ([^\|]+) \| ([^\|]+) \|/);
    if (match) {
      const [, date, league, home, away, betType, odds, score, result] = match;
      rows.push({
        date,
        league: league.trim(),
        home: home.trim(),
        away: away.trim(),
        betType: betType.trim(),
        odds: parseFloat(odds),
        score: score.trim(),
        result: result.trim()
      });
    }
  }
  
  return rows;
}

// 加载统计文件
function loadStats() {
  if (fs.existsSync(STATS_FILE)) {
    return JSON.parse(fs.readFileSync(STATS_FILE, 'utf8'));
  }
  return {
    totalBankroll: BASE_BANKROLL,
    currentBankroll: BASE_BANKROLL,
    totalBets: 0,
    wonBets: 0,
    totalROI: 0,
    maxDrawdown: 0,
    dailyBets: {},  // { "2026-04-19": count }
    streakW: 0,
    streakL: 0,
    maxStreakW: 0,
    maxStreakL: 0,
  };
}

// 保存统计
function saveStats(stats) {
  fs.writeFileSync(STATS_FILE, JSON.stringify(stats, null, 2));
}

// 更新统计（每单结算后调用）
function updateStats(bet, won) {
  const stats = loadStats();
  const stake = Math.round(stats.currentBankroll * bet.kellyPct * 100) / 100;
  const profit = won ? stake * (bet.odds - 1) : -stake;
  
  stats.currentBankroll = Math.round((stats.currentBankroll + profit) * 100) / 100;
  stats.totalBets++;
  if (won) stats.wonBets++;
  
  // 连胜/连负
  if (won) {
    stats.streakW++;
    stats.streakL = 0;
    stats.maxStreakW = Math.max(stats.maxStreakW, stats.streakW);
  } else {
    stats.streakL++;
    stats.streakW = 0;
    stats.maxStreakL = Math.max(stats.maxStreakL, stats.streakL);
  }
  
  // ROI
  stats.totalROI = Math.round(((stats.currentBankroll - BASE_BANKROLL) / BASE_BANKROLL) * 10000) / 100;
  
  // 回撤
  const drawdown = Math.round(((BASE_BANKROLL - stats.currentBankroll) / BASE_BANKROLL) * 10000) / 100;
  stats.maxDrawdown = Math.max(stats.maxDrawdown, drawdown);
  
  // 当日投注数
  const today = bet.date;
  stats.dailyBets[today] = (stats.dailyBets[today] || 0) + 1;
  
  saveStats(stats);
  return { stake, profit, stats };
}

// 分析一场比赛，给出投注建议
function analyzeMatch(match) {
  const { league, home, away, time, odds, betType } = match;
  const { h: homeOdds, d: drawOdds, a: awayOdds } = odds;
  
  // 计算隐含概率
  const invH = 1/homeOdds + 1/drawOdds + 1/awayOdds;
  const probH = (1/homeOdds) / invH;
  const probD = (1/drawOdds) / invH;
  const probA = (1/awayOdds) / invH;
  
  // 获取联赛置信度
  const leagueConf = LEAGUE_CONFIDENCE[league] || { base: 0.90, safeOdds: 1.45 };
  
  // Kelly计算
  const kellyH = kellyFraction(homeOdds, probH, leagueConf.base);
  const kellyD = kellyFraction(drawOdds, probD, leagueConf.base);
  const kellyA = kellyFraction(awayOdds, probA, leagueConf.base);
  
  // 推荐
  let recommendation = '';
  let bestKelly = 0;
  let bestBet = '';
  
  if (kellyH > bestKelly && kellyH > 0.01) { bestKelly = kellyH; bestBet = '主胜'; recommendation = '胜'; }
  if (kellyD > bestKelly && kellyD > 0.01) { bestKelly = kellyD; bestBet = '平局'; recommendation = '平'; }
  if (kellyA > bestKelly && kellyA > 0.01) { bestKelly = kellyA; bestBet = '客胜'; recommendation = '负'; }
  
  // 投注比例
  const stakePct = Math.round(kellyFraction(homeOdds, probH, leagueConf.base) * 10000) / 100; // 百分比
  
  // 风险等级
  let riskLevel = '✅正常';
  let riskReason = '';
  
  // 低赔风险（豪门深盘）
  const lowestOdds = Math.min(homeOdds, drawOdds, awayOdds);
  if (lowestOdds < 1.3) {
    if (leagueConf.note) {
      riskLevel = '⚠️谨慎';
      riskReason = leagueConf.note;
    }
  }
  
  // 检查今日投注数
  const today = new Date().toISOString().split('T')[0];
  const stats = loadStats();
  const todayBets = stats.dailyBets[today] || 0;
  const canBet = todayBets < MAX_DAILY_BETS;
  
  // 生成分析报告
  return {
    league,
    home,
    away,
    time,
    odds: { homeOdds, drawOdds, awayOdds },
    probability: { h: (probH*100).toFixed(0), d: (probD*100).toFixed(0), a: (probA*100).toFixed(0) },
    recommendation,
    bestBet,
    kellyPct: (bestKelly * 100).toFixed(1),
    stakePct: (kellyFraction(homeOdds, probH, leagueConf.base) * 100).toFixed(1),
    riskLevel,
    riskReason,
    canBet,
    todayBets,
    leagueConf
  };
}

// 打印分析报告
function printAnalysis(analysis) {
  const lines = [];
  
  lines.push(`⚽ ${analysis.home} vs ${analysis.away}`);
  lines.push(`   联赛: ${analysis.league} | 时间: ${analysis.time}`);
  lines.push('');
  lines.push('   📊 胜平负概率分析:');
  lines.push(`      主胜 ${analysis.odds.homeOdds} (${analysis.probability.h}%)`);
  lines.push(`      平局 ${analysis.odds.drawOdds} (${analysis.probability.d}%)`);
  lines.push(`      客胜 ${analysis.odds.awayOdds} (${analysis.probability.a}%)`);
  lines.push('');
  
  if (analysis.canBet) {
    lines.push(`   🎯 推荐: ${analysis.bestBet}`);
    lines.push(`   📈 Kelly投注比: ${analysis.kellyPct}% (建议投注本金${analysis.stakePct}%)`);
    lines.push(`   🛡️ 风险: ${analysis.riskLevel} ${analysis.riskReason}`);
  } else {
    lines.push(`   🚫 今日已投注${analysis.todayBets}单，暂停`);
  }
  
  return lines.join('\n');
}

// 主函数
async function main() {
  const args = process.argv.slice(2);
  
  if (args[0] === '--stats') {
    // 显示统计
    const stats = loadStats();
    const winRate = stats.totalBets > 0 ? ((stats.wonBets / stats.totalBets) * 100).toFixed(1) : '0';
    
    console.log('📊 【投注统计面板】');
    console.log(`   本金: ${stats.totalBankroll} 元`);
    console.log(`   当前: ${stats.currentBankroll} 元`);
    console.log(`   收益率: ${stats.totalROI > 0 ? '+' : ''}${stats.totalROI}%`);
    console.log(`   最大回撤: ${stats.maxDrawdown}%`);
    console.log(`   总投注: ${stats.totalBets} 单 | 胜: ${stats.wonBets} | 胜率: ${winRate}%`);
    console.log(`   最长连胜: ${stats.maxStreakW} | 最长连负: ${stats.maxStreakL}`);
    console.log(`   当前状态: ${stats.streakW > 0 ? '🔥'+stats.streakW+'连胜' : stats.streakL > 0 ? '❄️'+stats.streakL+'连负' : '➖'}`);
    
    // 最近30天投注趋势
    const dates = Object.keys(stats.dailyBets).sort().slice(-7);
    if (dates.length > 0) {
      console.log('');
      console.log('   📅 最近投注日:');
      dates.forEach(d => {
        console.log(`      ${d}: ${stats.dailyBets[d]} 单`);
      });
    }
    
    return;
  }
  
  if (args[0] === '--history') {
    const history = loadBettingHistory();
    console.log(`📜 历史投注记录: ${history.length} 场`);
    history.slice(-10).reverse().forEach(bet => {
      const won = bet.result === '✅';
      console.log(`   ${bet.date} ${bet.league} ${bet.home} vs ${bet.away} | ${bet.betType}@${bet.odds} | ${bet.score} | ${won ? '✅胜' : '❌负'}`);
    });
    return;
  }
  
  // 分析一场比赛（用于测试）
  if (args[0] === '--analyze') {
    // 模拟今天的一场比赛
    const testMatch = {
      league: '英超',
      home: '水晶宫',
      away: '西汉姆联',
      time: '03:00',
      odds: { homeOdds: 2.35, drawOdds: 3.14, awayOdds: 2.60 },
      betType: '胜平负'
    };
    
    const analysis = analyzeMatch(testMatch);
    console.log(printAnalysis(analysis));
    return;
  }
  
  // 默认：显示帮助
  console.log('竞彩风控引擎用法:');
  console.log('  node jingcai-risk-engine.js --stats      查看统计面板');
  console.log('  node jingcai-risk-engine.js --history    查看历史记录');
  console.log('  node jingcai-risk-engine.js --analyze    测试分析一场比赛');
  console.log('');
  console.log(' Kelly公式: f* = (p·b - q) / b  (保守使用一半)');
  console.log(' 单日最大投注: ' + MAX_DAILY_BETS + ' 单');
  console.log(' 单次最大投注: 本金 ' + (MAX_BANKROLL_PCT * 100) + '%');
}

// 执行
main().catch(e => { console.error('Error:', e.message); process.exit(1); });
