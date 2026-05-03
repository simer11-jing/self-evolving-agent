#!/bin/bash
# 集成测试脚本 - Token缓存/消息去重/连接池

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 集成测试开始 ==="
echo ""

# 1. Token 缓存测试
echo "1️⃣ 测试 Token 缓存..."
node -e "
const TokenCache = require('${SCRIPT_DIR}/token-cache.js');
const cache = new TokenCache();

console.log('✅ Token 缓存初始化成功');

// 测试 set/get
cache.set('test prompt', 'gpt-4', 150);
const result = cache.get('test prompt', 'gpt-4');

if (result.hit) {
  console.log('✅ Token 缓存命中:', result.tokenCount);
} else {
  console.log('❌ Token 缓存未命中');
}

// 统计
const stats = cache.getStats();
console.log('📊 缓存统计:', JSON.stringify(stats));
"

echo ""

# 2. 消息去重测试
echo "2️⃣ 测试消息去重..."
node -e "
const MessageDedup = require('${SCRIPT_DIR}/message-dedup.js');
const dedup = new MessageDedup();

console.log('✅ 消息去重初始化成功');

// 测试去重
const msgId = 'test-msg-' + Date.now();
const result1 = dedup.checkAndMark(msgId);
console.log('首次检查:', result1.isDuplicate ? '❌ 重复' : '✅ 新消息');

const result2 = dedup.checkAndMark(msgId);
console.log('二次检查:', result2.isDuplicate ? '✅ 已去重' : '❌ 未去重');

// 统计
const stats = dedup.getStats();
console.log('📊 去重统计:', JSON.stringify(stats));
"

echo ""

# 3. 连接池测试
echo "3️⃣ 测试连接池..."
node -e "
const ConnectionPool = require('${SCRIPT_DIR}/connection-pool.js');

const pool = new ConnectionPool({
  maxConnections: 5,
  minConnections: 1
});

// 模拟连接创建函数
const createConnection = async () => {
  return {
    id: Math.random().toString(36).substring(7),
    close: async () => console.log('连接已关闭')
  };
};

pool.on('initialized', (info) => {
  console.log('✅ 连接池初始化成功:', info);
});

pool.on('error', (err) => {
  console.error('❌ 连接池错误:', err.message);
});

(async () => {
  await pool.initialize(createConnection);
  
  // 测试获取/释放
  const conn = await pool.acquire();
  console.log('✅ 获取连接:', conn._id);
  
  pool.release(conn);
  console.log('✅ 释放连接');
  
  // 统计
  const stats = pool.getStats();
  console.log('📊 连接池统计:', JSON.stringify(stats));
  
  await pool.close();
  console.log('✅ 连接池已关闭');
})();
"

echo ""
echo "=== 集成测试完成 ==="
