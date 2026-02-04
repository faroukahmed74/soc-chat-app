// =============================================================================
// SOC Chat App - Redis Cache Service
// =============================================================================
// This service provides Redis-based caching for improved performance
// Supports session caching, query result caching, and real-time data caching

const redis = require('redis');
const { promisify } = require('util');

// =============================================================================
// REDIS CONFIGURATION
// =============================================================================

class CacheService {
  constructor() {
    this.client = null;
    this.isConnected = false;
    this.connectionAttempts = 0;
    this.maxRetries = 5;
    this.retryDelay = 5000;
  }

  /**
   * Initialize Redis connection
   */
  async initialize() {
    try {
      const redisConfig = {
        host: process.env.REDIS_HOST || 'localhost',
        port: process.env.REDIS_PORT || 6379,
        password: process.env.REDIS_PASSWORD || undefined,
        db: process.env.REDIS_DB || 0,
        retryDelayOnFailover: 100,
        maxRetriesPerRequest: 3,
        lazyConnect: true
      };

      this.client = redis.createClient(redisConfig);
      
      // Set up event listeners
      this.setupEventListeners();
      
      // Connect to Redis
      await this.client.connect();
      this.isConnected = true;
      this.connectionAttempts = 0;
      
      console.log('✅ Redis cache service initialized successfully');
      return true;
      
    } catch (error) {
      console.error('❌ Failed to initialize Redis cache service:', error.message);
      this.isConnected = false;
      return false;
    }
  }

  /**
   * Set up Redis event listeners
   */
  setupEventListeners() {
    this.client.on('connect', () => {
      console.log('🔗 Redis client connected');
      this.isConnected = true;
    });

    this.client.on('ready', () => {
      console.log('✅ Redis client ready');
    });

    this.client.on('error', (error) => {
      console.error('❌ Redis client error:', error.message);
      this.isConnected = false;
    });

    this.client.on('end', () => {
      console.log('🔌 Redis client disconnected');
      this.isConnected = false;
    });

    this.client.on('reconnecting', () => {
      console.log('🔄 Redis client reconnecting...');
    });
  }

  /**
   * Check if Redis is available
   */
  isAvailable() {
    return this.isConnected && this.client && this.client.isReady;
  }

  // =============================================================================
  // BASIC CACHE OPERATIONS
  // =============================================================================

  /**
   * Set a key-value pair with optional expiration
   */
  async set(key, value, ttl = null) {
    if (!this.isAvailable()) {
      console.warn('⚠️ Redis not available, skipping cache set');
      return false;
    }

    try {
      const serializedValue = JSON.stringify(value);
      
      if (ttl) {
        await this.client.setEx(key, ttl, serializedValue);
      } else {
        await this.client.set(key, serializedValue);
      }
      
      return true;
    } catch (error) {
      console.error('❌ Redis set error:', error.message);
      return false;
    }
  }

  /**
   * Get a value by key
   */
  async get(key) {
    if (!this.isAvailable()) {
      console.warn('⚠️ Redis not available, skipping cache get');
      return null;
    }

    try {
      const value = await this.client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      console.error('❌ Redis get error:', error.message);
      return null;
    }
  }

  /**
   * Delete a key
   */
  async del(key) {
    if (!this.isAvailable()) {
      console.warn('⚠️ Redis not available, skipping cache delete');
      return false;
    }

    try {
      await this.client.del(key);
      return true;
    } catch (error) {
      console.error('❌ Redis delete error:', error.message);
      return false;
    }
  }

  /**
   * Check if a key exists
   */
  async exists(key) {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.client.exists(key);
      return result === 1;
    } catch (error) {
      console.error('❌ Redis exists error:', error.message);
      return false;
    }
  }

  /**
   * Set expiration time for a key
   */
  async expire(key, ttl) {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      await this.client.expire(key, ttl);
      return true;
    } catch (error) {
      console.error('❌ Redis expire error:', error.message);
      return false;
    }
  }

  // =============================================================================
  // SESSION CACHING
  // =============================================================================

  /**
   * Cache user session
   */
  async cacheUserSession(userId, sessionData, ttl = 3600) {
    const key = `session:${userId}`;
    return await this.set(key, sessionData, ttl);
  }

  /**
   * Get user session
   */
  async getUserSession(userId) {
    const key = `session:${userId}`;
    return await this.get(key);
  }

  /**
   * Delete user session
   */
  async deleteUserSession(userId) {
    const key = `session:${userId}`;
    return await this.del(key);
  }

  /**
   * Extend session TTL
   */
  async extendSession(userId, ttl = 3600) {
    const key = `session:${userId}`;
    return await this.expire(key, ttl);
  }

  // =============================================================================
  // QUERY RESULT CACHING
  // =============================================================================

  /**
   * Cache database query result
   */
  async cacheQuery(queryKey, result, ttl = 300) {
    const key = `query:${queryKey}`;
    return await this.set(key, result, ttl);
  }

  /**
   * Get cached query result
   */
  async getCachedQuery(queryKey) {
    const key = `query:${queryKey}`;
    return await this.get(key);
  }

  /**
   * Generate query cache key
   */
  generateQueryKey(collection, query, options = {}) {
    const queryString = JSON.stringify({ collection, query, options });
    return require('crypto').createHash('md5').update(queryString).digest('hex');
  }

  // =============================================================================
  // CHAT-SPECIFIC CACHING
  // =============================================================================

  /**
   * Cache chat list for user
   */
  async cacheUserChats(userId, chats, ttl = 300) {
    const key = `user_chats:${userId}`;
    return await this.set(key, chats, ttl);
  }

  /**
   * Get cached user chats
   */
  async getCachedUserChats(userId) {
    const key = `user_chats:${userId}`;
    return await this.get(key);
  }

  /**
   * Cache chat messages
   */
  async cacheChatMessages(chatId, messages, ttl = 600) {
    const key = `chat_messages:${chatId}`;
    return await this.set(key, messages, ttl);
  }

  /**
   * Get cached chat messages
   */
  async getCachedChatMessages(chatId) {
    const key = `chat_messages:${chatId}`;
    return await this.get(key);
  }

  /**
   * Cache user online status
   */
  async cacheUserStatus(userId, status, ttl = 300) {
    const key = `user_status:${userId}`;
    return await this.set(key, status, ttl);
  }

  /**
   * Get cached user status
   */
  async getCachedUserStatus(userId) {
    const key = `user_status:${userId}`;
    return await this.get(key);
  }

  // =============================================================================
  // REAL-TIME DATA CACHING
  // =============================================================================

  /**
   * Cache active connections
   */
  async cacheActiveConnection(userId, connectionData, ttl = 60) {
    const key = `connection:${userId}`;
    return await this.set(key, connectionData, ttl);
  }

  /**
   * Get cached active connection
   */
  async getCachedActiveConnection(userId) {
    const key = `connection:${userId}`;
    return await this.get(key);
  }

  /**
   * Cache notification data
   */
  async cacheNotification(userId, notificationData, ttl = 3600) {
    const key = `notification:${userId}`;
    return await this.set(key, notificationData, ttl);
  }

  /**
   * Get cached notification
   */
  async getCachedNotification(userId) {
    const key = `notification:${userId}`;
    return await this.get(key);
  }

  // =============================================================================
  // BULK OPERATIONS
  // =============================================================================

  /**
   * Set multiple keys at once
   */
  async mset(keyValuePairs, ttl = null) {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const pipeline = this.client.multi();
      
      for (const [key, value] of Object.entries(keyValuePairs)) {
        const serializedValue = JSON.stringify(value);
        if (ttl) {
          pipeline.setEx(key, ttl, serializedValue);
        } else {
          pipeline.set(key, serializedValue);
        }
      }
      
      await pipeline.exec();
      return true;
    } catch (error) {
      console.error('❌ Redis mset error:', error.message);
      return false;
    }
  }

  /**
   * Get multiple keys at once
   */
  async mget(keys) {
    if (!this.isAvailable()) {
      return {};
    }

    try {
      const values = await this.client.mGet(keys);
      const result = {};
      
      for (let i = 0; i < keys.length; i++) {
        if (values[i]) {
          result[keys[i]] = JSON.parse(values[i]);
        }
      }
      
      return result;
    } catch (error) {
      console.error('❌ Redis mget error:', error.message);
      return {};
    }
  }

  /**
   * Delete multiple keys
   */
  async mdel(keys) {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      await this.client.del(keys);
      return true;
    } catch (error) {
      console.error('❌ Redis mdel error:', error.message);
      return false;
    }
  }

  // =============================================================================
  // PATTERN-BASED OPERATIONS
  // =============================================================================

  /**
   * Get keys matching a pattern
   */
  async getKeys(pattern) {
    if (!this.isAvailable()) {
      return [];
    }

    try {
      const keys = await this.client.keys(pattern);
      return keys;
    } catch (error) {
      console.error('❌ Redis keys error:', error.message);
      return [];
    }
  }

  /**
   * Delete keys matching a pattern
   */
  async deletePattern(pattern) {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const keys = await this.getKeys(pattern);
      if (keys.length > 0) {
        await this.client.del(keys);
      }
      return true;
    } catch (error) {
      console.error('❌ Redis delete pattern error:', error.message);
      return false;
    }
  }

  // =============================================================================
  // CACHE STATISTICS
  // =============================================================================

  /**
   * Get cache statistics
   */
  async getStats() {
    if (!this.isAvailable()) {
      return null;
    }

    try {
      const info = await this.client.info('memory');
      const keyspace = await this.client.info('keyspace');
      
      return {
        connected: this.isConnected,
        memory: info,
        keyspace: keyspace,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('❌ Redis stats error:', error.message);
      return null;
    }
  }

  /**
   * Clear all cache data
   */
  async flushAll() {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      await this.client.flushAll();
      console.log('🗑️ All cache data cleared');
      return true;
    } catch (error) {
      console.error('❌ Redis flush error:', error.message);
      return false;
    }
  }

  // =============================================================================
  // CLEANUP
  // =============================================================================

  /**
   * Close Redis connection
   */
  async close() {
    if (this.client) {
      try {
        await this.client.quit();
        console.log('🔌 Redis connection closed');
      } catch (error) {
        console.error('❌ Error closing Redis connection:', error.message);
      }
    }
  }
}

// =============================================================================
// SINGLETON INSTANCE
// =============================================================================

const cacheService = new CacheService();

// =============================================================================
// MIDDLEWARE FUNCTIONS
// =============================================================================

/**
 * Cache middleware for Express routes
 */
function cacheMiddleware(ttl = 300) {
  return async (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }

    const cacheKey = `route:${req.originalUrl}`;
    const cachedResult = await cacheService.get(cacheKey);

    if (cachedResult) {
      console.log(`📦 Cache hit for: ${req.originalUrl}`);
      return res.json(cachedResult);
    }

    // Override res.json to cache the response
    const originalJson = res.json;
    res.json = function(data) {
      cacheService.set(cacheKey, data, ttl);
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Session middleware using Redis
 */
function sessionMiddleware() {
  return async (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (token) {
      const sessionData = await cacheService.getUserSession(token);
      if (sessionData) {
        req.user = sessionData;
        // Extend session TTL
        await cacheService.extendSession(token);
      }
    }
    
    next();
  };
}

// =============================================================================
// EXPORTS
// =============================================================================

module.exports = {
  cacheService,
  cacheMiddleware,
  sessionMiddleware
};

// =============================================================================
// USAGE EXAMPLES
// =============================================================================

/*
// Initialize cache service
await cacheService.initialize();

// Cache user session
await cacheService.cacheUserSession('user123', { userId: 'user123', role: 'admin' }, 3600);

// Get cached session
const session = await cacheService.getUserSession('user123');

// Cache query result
const queryKey = cacheService.generateQueryKey('users', { status: 'active' });
await cacheService.cacheQuery(queryKey, users, 300);

// Use cache middleware
app.get('/api/users', cacheMiddleware(300), async (req, res) => {
  // Route handler
});

// Use session middleware
app.use(sessionMiddleware());
*/
