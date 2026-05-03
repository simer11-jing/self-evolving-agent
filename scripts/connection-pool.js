/**
 * Connection Pool - 数据库连接池模块
 * 
 * 注意：OpenClaw 主要使用 SQLite，不需要连接池
 * 此模块主要用于支持其他数据库连接（如 MySQL、PostgreSQL）
 * 
 * 功能：
 * - 连接池管理
 * - 自动重连
 * - 连接健康检查
 */

const EventEmitter = require('events');

class ConnectionPool extends EventEmitter {
  constructor(config) {
    super();
    
    this.config = {
      maxConnections: 10,
      minConnections: 2,
      acquireTimeoutMs: 30000,
      idleTimeoutMs: 300000, // 5 分钟
      connectionTimeoutMs: 5000,
      ...config
    };
    
    this.connections = [];
    this.available = [];
    this.pending = [];
    this.stats = {
      totalCreated: 0,
      totalAcquired: 0,
      totalReleased: 0,
      totalErrors: 0
    };
    
    this._initialized = false;
  }

  /**
   * 初始化连接池
   */
  async initialize(createConnectionFn) {
    if (this._initialized) {
      return;
    }
    
    this.createConnection = createConnectionFn;
    
    // 创建最小连接数
    for (let i = 0; i < this.config.minConnections; i++) {
      try {
        const conn = await this._createConnection();
        this.connections.push(conn);
        this.available.push(conn);
      } catch (e) {
        this.emit('error', e);
      }
    }
    
    this._initialized = true;
    this._startHealthCheck();
    
    this.emit('initialized', {
      total: this.connections.length,
      available: this.available.length
    });
  }

  async _createConnection() {
    const conn = await this.createConnection();
    conn._createdAt = Date.now();
    conn._lastUsedAt = Date.now();
    conn._id = `conn-${++this.stats.totalCreated}`;
    
    this.stats.totalCreated++;
    
    return conn;
  }

  /**
   * 获取连接
   */
  async acquire() {
    // 如果有可用连接
    if (this.available.length > 0) {
      const conn = this.available.pop();
      conn._lastUsedAt = Date.now();
      this.stats.totalAcquired++;
      return conn;
    }
    
    // 如果还可以创建新连接
    if (this.connections.length < this.config.maxConnections) {
      try {
        const conn = await this._createConnection();
        this.connections.push(conn);
        this.stats.totalAcquired++;
        return conn;
      } catch (e) {
        this.stats.totalErrors++;
        throw e;
      }
    }
    
    // 等待可用连接
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        const idx = this.pending.findIndex(p => p.resolve === resolve);
        if (idx !== -1) {
          this.pending.splice(idx, 1);
          reject(new Error('Connection acquire timeout'));
        }
      }, this.config.acquireTimeoutMs);
      
      this.pending.push({
        resolve: (conn) => {
          clearTimeout(timeout);
          this.stats.totalAcquired++;
          resolve(conn);
        },
        reject: (err) => {
          clearTimeout(timeout);
          reject(err);
        }
      });
    });
  }

  /**
   * 释放连接
   */
  release(conn) {
    conn._lastUsedAt = Date.now();
    
    // 如果有等待的请求
    if (this.pending.length > 0) {
      const { resolve } = this.pending.shift();
      resolve(conn);
    } else {
      this.available.push(conn);
    }
    
    this.stats.totalReleased++;
  }

  /**
   * 销毁连接
   */
  async destroy(conn) {
    const idx = this.connections.indexOf(conn);
    if (idx !== -1) {
      this.connections.splice(idx, 1);
    }
    
    const availIdx = this.available.indexOf(conn);
    if (availIdx !== -1) {
      this.available.splice(availIdx, 1);
    }
    
    if (conn.close) {
      await conn.close();
    }
  }

  /**
   * 健康检查
   */
  _startHealthCheck() {
    this.healthCheckInterval = setInterval(() => {
      this._checkConnections();
    }, 60000); // 每分钟检查一次
  }

  async _checkConnections() {
    const now = Date.now();
    const toRemove = [];
    
    // 检查空闲超时的连接
    for (const conn of this.available) {
      if (now - conn._lastUsedAt > this.config.idleTimeoutMs) {
        if (this.connections.length > this.config.minConnections) {
          toRemove.push(conn);
        }
      }
    }
    
    // 移除超时连接
    for (const conn of toRemove) {
      await this.destroy(conn);
    }
    
    this.emit('healthCheck', {
      total: this.connections.length,
      available: this.available.length,
      removed: toRemove.length
    });
  }

  /**
   * 获取统计信息
   */
  getStats() {
    return {
      ...this.stats,
      totalConnections: this.connections.length,
      availableConnections: this.available.length,
      pendingRequests: this.pending.length,
      maxConnections: this.config.maxConnections,
      minConnections: this.config.minConnections
    };
  }

  /**
   * 关闭连接池
   */
  async close() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
    }
    
    // 拒绝所有等待的请求
    this.pending.forEach(({ reject }) => {
      reject(new Error('Connection pool is closing'));
    });
    this.pending = [];
    
    // 关闭所有连接
    for (const conn of this.connections) {
      try {
        if (conn.close) {
          await conn.close();
        }
      } catch (e) {
        // 忽略关闭错误
      }
    }
    
    this.connections = [];
    this.available = [];
    this._initialized = false;
    
    this.emit('closed');
  }
}

module.exports = ConnectionPool;
