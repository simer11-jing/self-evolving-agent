#!/usr/bin/env node
/**
 * 竞彩联赛权重校准器
 * 分析 betting-results.md 历史数据，按联赛统计胜率
 * 自动调整 LEAGUE_CONF 置信度
 */

const fs = require('fs');

const BETTING_FILE = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai/betting-results.md';
const CONF_FILE = process.env.HOME + '/.openclaw/workspace/self-improving/jingcai/league-confidence.json';

// 当前置信度配置
const DEFAULT_CONF = {
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
  '瑞超': { base: 0.90, safeOdds: 1.40 },
  '韩职': { base: 0.85, safeOdds: 1.45 },
  '德乙': { base: 0.90, safeOdds: 1.50 },
  '英冠': { base: 0.85, safeOdds: 1.50 },
};

// 赔率区间阈值
const ODDS_THRESHOLDS = {
  // 法甲 <1.25 防冷
  '法甲': { cold: 1.25 },
  // 葡超 <1.50 防冷
  '葡超': { cold: 1.50 },
  // 美职 <1.30 防冷
  '美职': { cold: 1.30 },
};

function main() {
  if (!fs.existsSync(BETTING_FILE)) {
    console.log('无历史数据');
    return;
  }

  const content = fs.readFileSync(BETTING_FILE, 'utf8');
  const lines = content.split('\n');
  
  // 按联赛统计
  const leagueStats = {};
  
  // 赔率区间统计（用于动态阈值）
  const oddsRangeStats = {};
  
  for (const line of lines) {
    if (!line.startsWith('| ') || !line.includes('2026-')) continue;
    if (line.includes('---') || line.includes('日期 ')) continue;
    
    const cols = line.split('|').slice(1, -1).map(c => c.trim());
    if (cols.length < 6) continue;
    
    const [date, league, home, away, betType, oddsStr, score, ...rest] = cols;
    if (!date.match(/^\d{4}-\d{2}-\d{2}$/)) continue;
    
    // 解析赔率
    let odds = { h: '', d: '', a: '' };
    if (oddsStr.includes('/')) {
      const m = oddsStr.match(/胜([\d.]+)\/平([\d.]+)\/负([\d.]+)/);
      if (m) { odds = { h: m[1], d: m[2], a: m[3] }; }
    } else {
      // 单值赔率（手动录入的），无法分解，跳过联赛统计
    }
    
    // 判断盈亏
    let won = null;
    const lastCol = rest[rest.length - 1] || '';
    if (lastCol.includes('✅')) won = true;
    else if (lastCol.includes('❌')) won = false;
    else if (score.includes('待定')) continue; // 跳过待定
    
    if (won === null) continue;
    
    if (!leagueStats[league]) {
      leagueStats[league] = { total: 0, won: 0, league };
    }
    leagueStats[league].total++;
    if (won) leagueStats[league].won++;
    
    // 赔率区间
    const minOdds = Math.min(parseFloat(odds.h), parseFloat(odds.d), parseFloat(odds.a));
    if (!isNaN(minOdds)) {
      let range = '';
      if (minOdds < 1.35) range = '<1.35';
      else if (minOdds < 1.65) range = '1.35-1.65';
      else if (minOdds < 2.00) range = '1.65-2.00';
      else if (minOdds < 2.50) range = '2.00-2.50';
      else range = '>=2.50';
      
      if (!oddsRangeStats[range]) oddsRangeStats[range] = { total: 0, won: 0 };
      oddsRangeStats[range].total++;
      if (won) oddsRangeStats[range].won++;
    }
  }
  
  console.log('📊 【联赛权重校准报告】');
  console.log('');
  
  // 显示联赛统计
  const leagues = Object.values(leagueStats).filter(s => s.total >= 1);
  console.log('📌 联赛胜率统计:');
  leagues.sort((a, b) => (b.won/b.total) - (a.won/a.total)).forEach(s => {
    const rate = (s.won / s.total * 100).toFixed(0);
    const bar = '█'.repeat(Math.round(rate / 5));
    const current = DEFAULT_CONF[s.league]?.base || 0.90;
    const diff = (rate / 100 - current).toFixed(2);
    const sign = diff >= 0 ? '+' : '';
    console.log('  ' + s.league.padEnd(6) + ' ' + s.won + '/' + s.total + ' (' + rate + '%) ' + bar + '  (当前:' + current + ' ' + sign + diff + ')');
  });
  
  // 显示赔率区间统计
  console.log('\n📌 低赔区间胜率:');
  const rangeOrder = ['<1.35', '1.35-1.65', '1.65-2.00', '2.00-2.50', '>=2.50'];
  rangeOrder.forEach(r => {
    const s = oddsRangeStats[r];
    if (!s || s.total === 0) return;
    const rate = (s.won / s.total * 100).toFixed(0);
    const bar = '█'.repeat(Math.round(rate / 5));
    console.log('  ' + r.padEnd(12) + ' ' + s.won + '/' + s.total + ' (' + rate + '%) ' + bar);
  });
  
  // 生成调整建议
  console.log('\n💡 权重调整建议:');
  let hasChanges = false;
  leagues.filter(s => s.total >= 2).forEach(s => {
    const rate = s.won / s.total;
    const current = DEFAULT_CONF[s.league]?.base || 0.90;
    
    // 如果实际胜率和当前置信度偏差超过15%，建议调整
    if (Math.abs(rate - current) > 0.15) {
      hasChanges = true;
      const suggested = Math.round(rate * 100) / 100;
      const direction = rate > current ? '⬆️提高' : '⬇️降低';
      console.log('  ' + s.league + ': ' + direction + ' ' + current + ' → ' + suggested);
    }
  });
  
  if (!hasChanges) {
    console.log('  当前权重无需调整（偏差<15%）');
  }
  
  // 输出调整后的配置
  console.log('\n📋 建议配置 (league-confidence.json):');
  const newConf = { ...DEFAULT_CONF };
  leagues.filter(s => s.total >= 3 && Math.abs(s.won/s.total - (DEFAULT_CONF[s.league]?.base || 0.90)) > 0.15)
    .forEach(s => {
      if (!newConf[s.league]) newConf[s.league] = { base: 0.90, safeOdds: 1.45 };
      newConf[s.league].base = Math.round(s.won / s.total * 100) / 100;
    });
  
  console.log(JSON.stringify(newConf, null, 2).substring(0, 500) + '...');
  
  // 保存
  if (hasChanges) {
    fs.writeFileSync(CONF_FILE, JSON.stringify(newConf, null, 2));
    console.log('\n✅ 已保存到 ' + CONF_FILE);
  }
}

main();
