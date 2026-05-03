/**
 * Message Dedup - 消息去重模块
 * 
 * 功能：
 * - 消息 ID 去重，避免重复处理
 * - 支持持久化存储
 * - 自动清理过期记录
 */

const fs = require('fs');
const path = require('path');

class MessageDedup {
  constructor(dataDir) {
    this.dataDir = dataDir || path.join(process.env.HOME, '.openclaw/data/dedup');
    this.dedupFile = path.join(this.dataDir, 'processed-messages.json');
    this.maxAgeMs = 7 * 24 * 60 * 60 * 1000; // 保留 7 天
    this.maxMessages = 10000; // 最多保留 10000 条记录
    
    this.processed = new Map(); // messageId -> timestamp
    
    this._load();
  }

  _load() {
    try {
      if (!fs.existsSync(this.dataDir)) {
        fs.mkdirSync(this.dataDir, { recursive: true });
      }
      
      if (fs.existsSync(this.dedupFile)) {
        const data = JSON.parse(fs.readFileSync(this.dedupFile, 'utf8'));
        const now = Date.now();
        
        // 只加载未过期的记录
        Object.entries(data).forEach(([id, timestamp]) => {
          if (now - timestamp < this.maxAgeMs) {
            this.processed.set(id, timestamp);
          }
        });
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  _save() {
    try {
      const data = Object.fromEntries(this.processed);
      fs.writeFileSync(this.dedupFile, JSON.stringify(data, null, 2));
    } catch (e) {
      // 忽略保存错误
    }
  }

  /**
   * 检查消息是否已处理
   */
  has(messageId) {
    return this.processed.has(messageId);
  }

  /**
   * 标记消息为已处理
   */
  mark(messageId) {
    // 如果记录满了，删除最旧的
    if (this.processed.size >= this.maxMessages) {
      const oldestKey = this.processed.keys().next().value;
      this.processed.delete(oldestKey);
    }
    
    this.processed.set(messageId, Date.now());
    this._save();
  }

  /**
   * 检查并标记（原子操作）
   */
  checkAndMark(messageId) {
    if (this.has(messageId)) {
      return {
        isDuplicate: true,
        processed: true
      };
    }
    
    this.mark(messageId);
    return {
      isDuplicate: false,
      processed: false
    };
  }

  /**
   * 批量检查
   */
  checkBatch(messageIds) {
    const duplicates = [];
    const newMessages = [];
    
    messageIds.forEach(id => {
      if (this.has(id)) {
        duplicates.push(id);
      } else {
        newMessages.push(id);
        this.mark(id);
      }
    });
    
    this._save();
    
    return {
      duplicates,
      newMessages,
      totalChecked: messageIds.length,
      duplicateRate: messageIds.length > 0 
        ? (duplicates.length / messageIds.length * 100).toFixed(2) + '%'
        : '0%'
    };
  }

  /**
   * 获取统计信息
   */
  getStats() {
    const now = Date.now();
    let recent = 0;
    let expired = 0;
    
    this.processed.forEach(timestamp => {
      if (now - timestamp < 24 * 60 * 60 * 1000) {
        recent++;
      } else {
        expired++;
      }
    });
    
    return {
      totalMessages: this.processed.size,
      maxMessages: this.maxMessages,
      recent24h: recent,
      expired: expired,
      oldestTimestamp: this.processed.size > 0 
        ? Math.min(...this.processed.values())
        : null
    };
  }

  /**
   * 清理过期记录
   */
  cleanup() {
    const now = Date.now();
    let cleaned = 0;
    
    for (const [id, timestamp] of this.processed.entries()) {
      if (now - timestamp >= this.maxAgeMs) {
        this.processed.delete(id);
        cleaned++;
      }
    }
    
    if (cleaned > 0) {
      this._save();
    }
    
    return cleaned;
  }

  /**
   * 清空所有记录
   */
  clear() {
    this.processed.clear();
    this._save();
  }
}

module.exports = MessageDedup;
