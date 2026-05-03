#!/bin/bash
# 缓存清理脚本

SCRIPT_DIR="$HOME/.openclaw/skills/self-evolving-agent/scripts"

node -e "
const TokenCache = require('${SCRIPT_DIR}/token-cache.js');
const MessageDedup = require('${SCRIPT_DIR}/message-dedup.js');

const tokenCache = new TokenCache();
const messageDedup = new MessageDedup();

console.log('=== 缓存清理开始 ===');

// 清理 token 缓存
const tokenCleaned = tokenCache.cleanup();
console.log('Token 缓存清理:', tokenCleaned, '条');

// 清理消息去重记录
const msgCleaned = messageDedup.cleanup();
console.log('消息去重清理:', msgCleaned, '条');

// 统计
const tokenStats = tokenCache.getStats();
const msgStats = messageDedup.getStats();

console.log('');
console.log('📊 Token 缓存统计:', JSON.stringify(tokenStats));
console.log('📊 消息去重统计:', JSON.stringify(msgStats));

console.log('');
console.log('✅ 缓存清理完成');
"
