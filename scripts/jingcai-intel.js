#!/usr/bin/env node
/**
 * 竞彩情报收集器
 * 赛前搜索球队新闻情报（伤病/轮换/状态）
 * 用 Tavily API 搜索，返回关键情报摘要
 */

const https = require('https');

// Tavily API配置
const TAVILY_API_KEY = process.env.TAVILY_API_KEY || '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';
const TAVILY_URL = 'https://api.tavily.com/search';

// 情报关键词（用于判断是否有重要信息）
const ALERT_KEYWORDS = [
  '伤', '停赛', '缺阵', '轮换', '主力缺席',
  '主帅', '下课', '矛盾', '更衣室',
  '红牌', '黄牌', '累积', '停赛',
  '欧战', '留力', '分心'
];

// 排除词（噪音）
const NOISE_KEYWORDS = [
  '转会', '续约', '采访', '商业', '广告',
  '纪录片', '获奖', '典礼', '投票'
];

function searchTavily(query) {
  return new Promise((resolve) => {
    const body = JSON.stringify({
      api_key: TAVILY_API_KEY,
      query,
      search_depth: 'basic',
      max_results: 3,
      include_answer: true,
      include_domains: ['sohu.com', 'sina.com.cn', 'qq.com', '163.com', 'toutiao.com', 'dongqiudi.com']
    });

    const options = {
      hostname: 'api.tavily.com',
      path: '/search',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch(e) {
          resolve(null);
        }
      });
    });
    req.on('error', () => resolve(null));
    req.write(body);
    req.end();
  });
}

function extractIntel(news) {
  if (!news || !news.results) return null;
  
  const alerts = [];
  for (const result of news.results.slice(0, 3)) {
    const title = result.title || '';
    const snippet = result.content || '';
    const text = title + ' ' + snippet;
    
    // 检查警报词
    const hasAlert = ALERT_KEYWORDS.some(k => text.includes(k));
    const hasNoise = NOISE_KEYWORDS.some(k => text.includes(k));
    
    if (hasAlert && !hasNoise) {
      alerts.push({
        title: title.substring(0, 50),
        snippet: snippet.substring(0, 100),
        url: result.url
      });
    }
  }
  
  return alerts.length > 0 ? alerts : null;
}

// 简化队名（用于搜索）
function simplifyName(name) {
  return name
    .replace(/\[?\d*\]?/g, '')
    .replace(/(足球)?俱乐部|FC|SC|AS|体育|竞技|城$/g, '')
    .trim()
    .split(/\s+/)[0];
}

async function gatherIntel(teams, league) {
  const intel = {};
  
  for (const team of teams) {
    const searchName = simplifyName(team);
    if (!searchName || searchName.length < 2) continue;
    
    // 组合搜索词
    const queries = [
      searchName + ' 伤病 停赛',
      searchName + ' 轮换 首发',
      searchName + ' ' + league + ' 近期'
    ];
    
    for (const query of queries.slice(0, 1)) { // 只搜最关键的
      try {
        const result = await searchTavily(query);
        const alerts = extractIntel(result);
        if (alerts && alerts.length > 0) {
          intel[team] = alerts;
        }
        break; // 搜到一个就够
      } catch(e) {
        continue;
      }
    }
  }
  
  return intel;
}

function formatIntel(intel) {
  const lines = [];
  for (const [team, alerts] of Object.entries(intel)) {
    lines.push('  ' + team + ':');
    for (const alert of alerts.slice(0, 2)) {
      lines.push('    • ' + alert.title);
      if (alert.snippet) lines.push('      ' + alert.snippet.substring(0, 60) + '...');
    }
  }
  return lines.join('\n');
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('用法: node jingcai-intel.js "队名1,队名2" "联赛"');
    console.log('示例: node jingcai-intel.js "曼城,阿森纳" "英超"');
    return;
  }
  
  const teams = args[0].split(',').map(t => t.trim());
  const league = args[1] || '';
  
  console.log('🔍 搜索情报:', teams.join(' / '), league);
  
  const intel = await gatherIntel(teams, league);
  
  if (Object.keys(intel).length === 0) {
    console.log('✅ 未发现重要情报');
    return;
  }
  
  console.log('\n📰 情报摘要:');
  console.log(formatIntel(intel));
}

module.exports = { gatherIntel, formatIntel, simplifyName };

// 直接运行
if (require.main === module) {
  main().catch(e => { console.error('Error:', e.message); process.exit(1); });
}
