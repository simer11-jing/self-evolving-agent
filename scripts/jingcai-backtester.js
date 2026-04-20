#!/usr/bin/env node
/**
 * 竞彩回测引擎
 * 读取 betting-results.md 历史数据，模拟预测并计算准确率
 * 验证模型在不同联赛/赔率区间/时间段的稳定性
 */

const fs = require('fs');
const path = require('path');

const BETTING_FILE = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai/betting-results.md';
const JINGCAI_DIR = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai';

// 联赛置信度（当前模型）
const LEAGUE_CONF = {
  '英超': { base: 1.0, safeOdds: 1.35 },
  '意甲': { base: 1.0, safeOdds: 1.35 },
  '德甲': { base: 1.0, safeOdds: 1.35 },
  '西甲': { base: 1.0, safeOdds: 1.35 },
  '法甲': { base: 0.85, safeOdds: 1.25 },
  '葡超': { base: 0.85, safeOdds: 1.50 },
  '美职': { base: 0.80, safeOdds: 1.30 },
  '澳超': { base: 0.90, safeOdds: 1.40 },
  'J联赛': { base: 0.85, safeOdds: 1.45 },
  'K联赛': { base: 0.85, safeOdds: 1.45 },
  '瑞典超': { base: 0.90, safeOdds: 1.40 },
  '挪超': { base: 0.90, safeOdds: 1.40 },
  '英冠': { base: 0.85, safeOdds: 1.50 },
  '亚冠': { base: 0.80, safeOdds: 1.40 },
  '欧冠': { base: 1.0, safeOdds: 1.35 },
  '欧联': { base: 0.95, safeOdds: 1.40 },
};

function kelly(odds, prob, conf) {
  const b = odds - 1;
  const p = prob * conf;
  if (b <= 0) return 0;
  const f = (p * (b + 1) - 1) / b;
  return Math.max(0, Math.min(f * 0.5, 0.10));
}

// 模拟预测（基于赔率和联赛置信度）
function simulatePredict(match) {
  const { league, odds, betType } = match;
  const conf = LEAGUE_CONF[league] || { base: 0.90, safeOdds: 1.45 };
  
  const h = parseFloat(odds.h), d = parseFloat(odds.d), a = parseFloat(odds.a);
  if (isNaN(h) || isNaN(d) || isNaN(a)) return null;
  
  const inv = 1/h + 1/d + 1/a;
  const ph = (1/h)/inv, pd = (1/d)/inv, pa = (1/a)/inv;
  
  // Kelly计算
  const kH = kelly(h, ph, conf.base);
  const kD = kelly(d, pd, conf.base);
  const kA = kelly(a, pa, conf.base);
  
  // 推荐（Kelly最高项）
  let rec = '';
  let bestKelly = 0;
  if (kH > bestKelly) { bestKelly = kH; rec = '胜'; }
  if (kD > bestKelly) { bestKelly = kD; rec = '平'; }
  if (kA > bestKelly) { bestKelly = kA; rec = '负'; }
  
  if (bestKelly < 0.01) rec = '观望';
  
  // 风险
  const minOdds = Math.min(h, d, a);
  let risk = 'normal';
  if (minOdds < 1.3 && conf.base < 0.9) risk = 'risky';
  
  return { rec, kelly: bestKelly, risk, ph, pd, pa };
}

// 判断是否正确
function isCorrect(rec, actualResult) {
  if (actualResult === '✅') return rec !== '观望';
  if (actualResult === '❌') return false;
  return null; // 待定
}

// 从betting-results.md解析数据
function loadHistory() {
  if (!fs.existsSync(BETTING_FILE)) {
    console.log('找不到:', BETTING_FILE);
    return [];
  }
  
  const content = fs.readFileSync(BETTING_FILE, 'utf8');
  const lines = content.split('\n');
  const matches = [];
  let inSection = '';
  
  for (const line of lines) {
    // 检测section标题
    if (line.startsWith('## 2026-04-19 赛果') || line.startsWith('## 2026-04-20 赛果')) {
      inSection = line.match(/\d{4}-\d{2}-\d{2}/)?.[0] || '';
      continue;
    }
    
    if (!line.startsWith('| ') || !line.includes('2026-')) continue;
    if (line.includes('---') || line.includes('日期 ')) continue;
    
    const cols = line.split('|').slice(1, -1).map(c => c.trim());
    if (cols.length < 7) continue;
    
    const [date, league, home, away, betType, oddsStr, score, ...rest] = cols;
    
    if (!date.match(/^\d{4}-\d{2}-\d{2}$/)) continue;
    
    // 解析赔率
    let odds = { h: '', d: '', a: '' };
    if (oddsStr.includes('/')) {
      // 格式: 胜1.52/平3.74/负4.90
      const m = oddsStr.match(/胜([\d.]+)\/平([\d.]+)\/负([\d.]+)/);
      if (m) { odds = { h: m[1], d: m[2], a: m[3] }; }
    } else {
      // 格式: 单独数字 (已结算的表格里赔率是单一数值)
      // 这种格式需要从已结算记录中获取，这里只处理第一种格式
      continue;
    }
    
    // 判断盈亏
    let result = '';
    const lastCol = rest[rest.length - 1] || '';
    if (lastCol.includes('✅') || lastCol.includes('❌')) {
      result = lastCol.includes('✅') ? '✅' : '❌';
    } else if (score.includes('待定')) {
      result = 'pending';
    } else {
      result = score;
    }
    
    matches.push({
      date, league, home, away,
      betType: betType.trim(),
      odds,
      score: score.trim(),
      result
    });
  }
  
  return matches;
}

// 主函数
async function main() {
  const args = process.argv.slice(2);
  const verbose = args.includes('-v');
  
  const history = loadHistory();
  console.log('📊 【竞彩回测报告】');
  console.log('数据来源: betting-results.md');
  console.log('总样本:', history.length, '场\n');
  
  if (history.length === 0) {
    console.log('无历史数据，无法回测');
    return;
  }
  
  // 模拟预测并评估
  let totalCorrect = 0;
  let totalBets = 0;
  const leagueStats = {};
  const oddsRangeStats = {};
  const dayStats = {};
  
  history.forEach(m => {
    const pred = simulatePredict(m);
    if (!pred) return;
    
    // 跳过观望
    if (pred.rec === '观望') return;
    
    totalBets++;
    const correct = m.result === '✅';
    if (correct) totalCorrect++;
    
    // 按联赛统计
    if (!leagueStats[m.league]) {
      leagueStats[m.league] = { total: 0, correct: 0, league: m.league };
    }
    leagueStats[m.league].total++;
    if (correct) leagueStats[m.league].correct++;
    
    // 按赔率区间统计
    const minOdds = Math.min(parseFloat(m.odds.h), parseFloat(m.odds.d), parseFloat(m.odds.a));
    let range = '';
    if (minOdds < 1.35) range = '1.00-1.35';
    else if (minOdds < 1.65) range = '1.35-1.65';
    else if (minOdds < 2.00) range = '1.65-2.00';
    else if (minOdds < 2.50) range = '2.00-2.50';
    else range = '2.50+';
    
    if (!oddsRangeStats[range]) {
      oddsRangeStats[range] = { total: 0, correct: 0 };
    }
    oddsRangeStats[range].total++;
    if (correct) oddsRangeStats[range].correct++;
    
    // 按天统计
    if (!dayStats[m.date]) {
      dayStats[m.date] = { total: 0, correct: 0 };
    }
    dayStats[m.date].total++;
    if (correct) dayStats[m.date].correct++;
    
    if (verbose) {
      const predResult = correct ? '✅' : '❌';
      console.log(`${m.date} ${m.league} ${m.home} vs ${m.away} | 预测:${pred.rec} 实际:${m.result} ${predResult} | 赔率:${m.odds.h}/${m.odds.d}/${m.odds.a}`);
    }
  });
  
  // 输出结果
  const overallRate = totalBets > 0 ? (totalCorrect / totalBets * 100).toFixed(1) : '0';
  
  console.log('='.repeat(50));
  console.log('📈 总体准确率:', totalCorrect, '/', totalBets, '=', overallRate + '%');
  console.log('='.repeat(50));
  
  console.log('\n📌 按联赛:');
  const sortedLeagues = Object.values(leagueStats).sort((a, b) => 
    (b.correct / b.total) - (a.correct / a.total)
  );
  sortedLeagues.forEach(s => {
    const rate = s.total > 0 ? (s.correct / s.total * 100).toFixed(0) : 0;
    const bar = '█'.repeat(Math.round(rate / 5));
    console.log('  ' + s.league.padEnd(6) + ' ' + s.correct + '/' + s.total + ' (' + rate + '%) ' + bar);
  });
  
  console.log('\n📌 按赔率区间:');
  const rangeOrder = ['1.00-1.35', '1.35-1.65', '1.65-2.00', '2.00-2.50', '2.50+'];
  rangeOrder.forEach(r => {
    const s = oddsRangeStats[r];
    if (!s) return;
    const rate = s.total > 0 ? (s.correct / s.total * 100).toFixed(0) : 0;
    const bar = '█'.repeat(Math.round(rate / 5));
    console.log('  ' + r.padEnd(10) + ' ' + s.correct + '/' + s.total + ' (' + rate + '%) ' + bar);
  });
  
  console.log('\n📌 按日期:');
  Object.keys(dayStats).sort().forEach(d => {
    const s = dayStats[d];
    const rate = s.total > 0 ? (s.correct / s.total * 100).toFixed(0) : 0;
    console.log('  ' + d + ' ' + s.correct + '/' + s.total + ' (' + rate + '%)');
  });
  
  // 联赛权重建议（基于回测结果）
  console.log('\n💡 联赛权重调整建议:');
  sortedLeagues.filter(s => s.total >= 2).forEach(s => {
    const rate = s.correct / s.total;
    const current = LEAGUE_CONF[s.league]?.base || 0.90;
    if (rate > 0.65 && current < 1.0) {
      console.log(`  ${s.league}: ${(rate*100).toFixed(0)}%胜率 → 建议提高置信度`);
    } else if (rate < 0.45 && current > 0.75) {
      console.log(`  ${s.league}: ${(rate*100).toFixed(0)}%胜率 → 建议降低置信度`);
    }
  });
  
  // 样本量警告
  if (totalBets < 10) {
    console.log('\n⚠️ 样本量不足(' + totalBets + '场)，结论置信度低，需积累更多数据');
  }
}

main().catch(e => { console.error('Error:', e.message); process.exit(1); });
