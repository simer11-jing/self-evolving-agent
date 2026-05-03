/**
 * Token Cache - LLM Token 缓存模块
 * 
 * 功能：
 * - 缓存 LLM 请求的 token 使用情况
 * - 避免重复计算相同 prompt 的 token 数
 * - 支持缓存命中率统计
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

class TokenCache {
  constructor(cacheDir) {
    this.cacheDir = cacheDir || path.join(process.env.HOME, '.openclaw/cache/tokens');
    this.cacheFile = path.join(this.cacheDir, 'token-cache.json');
    this.maxCacheSize = 1000; // 最多缓存 1000 条
    this.maxAgeMs = 24 * 60 * 60 * 1000; // 缓存 24 小时
    
    this.cache = new Map();
    this.stats = {
      hits: 0,
      misses: 0,
      totalSaved: 0
    };
    
    this._loadCache();
  }

  _loadCache() {
    try {
      if (!fs.existsSync(this.cacheDir)) {
        fs.mkdirSync(this.cacheDir, { recursive: true });
      }
      
      if (fs.existsSync(this.cacheFile)) {
        const data = JSON.parse(fs.readFileSync(this.cacheFile, 'utf8'));
        const now = Date.now();
        
        // 只加载未过期的缓存
        Object.entries(data.cache || {}).forEach(([key, value]) => {
          if (now - value.timestamp < this.maxAgeMs) {
            this.cache.set(key, value);
          }
        });
        
        this.stats = data.stats || this.stats;
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  _saveCache() {
    try {
      const data = {
        cache: Object.fromEntries(this.cache),
        stats: this.stats,
        savedAt: new Date().toISOString()
      };
      
      fs.writeFileSync(this.cacheFile, JSON.stringify(data, null, 2));
    } catch (e) {
      // 忽略保存错误
    }
  }

  _hashPrompt(prompt, model) {
    // 使用 MD5 生成 prompt 的唯一标识
    const content = `${model}:${prompt}`;
    return crypto.createHash('md5').update(content).digest('hex');
  }

  /**
   * 获取缓存的 token 信息
   */
  get(prompt, model) {
    const key = this._hashPrompt(prompt, model);
    const cached = this.cache.get(key);
    
    if (cached && Date.now() - cached.timestamp < this.maxAgeMs) {
      this.stats.hits++;
      this.stats.totalSaved += cached.tokenCount;
      return {
        hit: true,
        tokenCount: cached.tokenCount,
        cached: true
      };
    }
    
    this.stats.misses++;
    return {
      hit: false,
      tokenCount: null,
      cached: false
    };
  }

  /**
   * 设置 token 缓存
   */
  set(prompt, model, tokenCount) {
    const key = this._hashPrompt(prompt, model);
    
    // 如果缓存满了，删除最旧的条目
    if (this.cache.size >= this.maxCacheSize) {
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
    }
    
    this.cache.set(key, {
      tokenCount,
      timestamp: Date.now(),
      model
    });
    
    this._saveCache();
  }

  /**
   * 获取缓存统计信息
   */
  getStats() {
    const total = this.stats.hits + this.stats.misses;
    const hitRate = total > 0 ? (this.stats.hits / total * 100).toFixed(2) : 0;
    
    return {
      ...this.stats,
      total,
      hitRate: `${hitRate}%`,
      cacheSize: this.cache.size,
      maxCacheSize: this.maxCacheSize
    };
  }

  /**
   * 清理过期缓存
   */
  cleanup() {
    const now = Date.now();
    let cleaned = 0;
    
    for (const [key, value] of this.cache.entries()) {
      if (now - value.timestamp >= this.maxAgeMs) {
        this.cache.delete(key);
        cleaned++;
      }
    }
    
    if (cleaned > 0) {
      this._saveCache();
    }
    
    return cleaned;
  }

  /**
   * 清空所有缓存
   */
  clear() {
    this.cache.clear();
    this.stats = { hits: 0, misses: 0, totalSaved: 0 };
    this._saveCache();
  }
}

module.exports = TokenCache;
