// =============================================================================
// PERFORMANCE MONITORING MIDDLEWARE
// =============================================================================
// This middleware tracks API response times, error rates, and other performance metrics

const { ObjectId } = require('mongodb');

// In-memory metrics cache (for real-time monitoring)
const metricsCache = {
  responseTimes: [],
  errorRates: {},
  activeConnections: 0,
  lastUpdate: new Date(),
};

// Performance monitoring middleware
function performanceMonitorMiddleware(req, res, next) {
  const startTime = Date.now();
  const endpoint = `${req.method} ${req.path}`;
  
  // Track active connections
  metricsCache.activeConnections++;
  
  // Override res.end to capture response time
  const originalEnd = res.end;
  res.end = function(...args) {
    const responseTime = Date.now() - startTime;
    
    // Record response time
    metricsCache.responseTimes.push({
      endpoint: endpoint,
      method: req.method,
      path: req.path,
      responseTime: responseTime,
      statusCode: res.statusCode,
      timestamp: new Date(),
    });
    
    // Keep only last 1000 entries
    if (metricsCache.responseTimes.length > 1000) {
      metricsCache.responseTimes.shift();
    }
    
    // Track error rates
    if (res.statusCode >= 400) {
      if (!metricsCache.errorRates[endpoint]) {
        metricsCache.errorRates[endpoint] = { count: 0, total: 0 };
      }
      metricsCache.errorRates[endpoint].count++;
    }
    
    if (!metricsCache.errorRates[endpoint]) {
      metricsCache.errorRates[endpoint] = { count: 0, total: 0 };
    }
    metricsCache.errorRates[endpoint].total++;
    
    // Decrease active connections
    metricsCache.activeConnections--;
    metricsCache.lastUpdate = new Date();
    
    // Call original end
    originalEnd.apply(res, args);
  };
  
  next();
}

// Store metrics to database periodically
async function storeMetricsToDatabase(db) {
  try {
    if (!db) return;
    
    const now = new Date();
    const oneMinuteAgo = new Date(now.getTime() - 60 * 1000);
    
    // Calculate average response times by endpoint
    const responseTimesByEndpoint = {};
    metricsCache.responseTimes
      .filter(m => m.timestamp >= oneMinuteAgo)
      .forEach(metric => {
        if (!responseTimesByEndpoint[metric.endpoint]) {
          responseTimesByEndpoint[metric.endpoint] = [];
        }
        responseTimesByEndpoint[metric.endpoint].push(metric.responseTime);
      });
    
    const avgResponseTimes = {};
    Object.keys(responseTimesByEndpoint).forEach(endpoint => {
      const times = responseTimesByEndpoint[endpoint];
      avgResponseTimes[endpoint] = {
        avg: times.reduce((a, b) => a + b, 0) / times.length,
        min: Math.min(...times),
        max: Math.max(...times),
        count: times.length,
      };
    });
    
    // Calculate error rates
    const errorRates = {};
    Object.keys(metricsCache.errorRates).forEach(endpoint => {
      const stats = metricsCache.errorRates[endpoint];
      if (stats.total > 0) {
        errorRates[endpoint] = (stats.count / stats.total) * 100;
      }
    });
    
    // Get system resources (if available)
    const os = require('os');
    const cpuUsage = process.cpuUsage();
    const memoryUsage = process.memoryUsage();
    
    // Store metrics
    await db.collection('performance_metrics').insertOne({
      timestamp: now,
      responseTimes: avgResponseTimes,
      errorRates: errorRates,
      activeConnections: metricsCache.activeConnections,
      systemResources: {
        cpu: {
          user: cpuUsage.user,
          system: cpuUsage.system,
        },
        memory: {
          rss: memoryUsage.rss,
          heapTotal: memoryUsage.heapTotal,
          heapUsed: memoryUsage.heapUsed,
          external: memoryUsage.external,
        },
        loadAverage: os.loadavg(),
        uptime: process.uptime(),
      },
      messageDeliveryRate: await calculateMessageDeliveryRate(db, oneMinuteAgo),
    });
    
    // Clean up old metrics (keep last 7 days)
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    await db.collection('performance_metrics').deleteMany({
      timestamp: { $lt: sevenDaysAgo },
    });
    
  } catch (error) {
    console.error('Error storing performance metrics:', error);
  }
}

// Calculate message delivery rate
async function calculateMessageDeliveryRate(db, since) {
  try {
    const totalMessages = await db.collection('messages').countDocuments({
      createdAt: { $gte: since },
    });
    
    const deliveredMessages = await db.collection('messages').countDocuments({
      createdAt: { $gte: since },
      status: 'delivered',
    });
    
    return totalMessages > 0 ? (deliveredMessages / totalMessages) * 100 : 100;
  } catch (error) {
    console.error('Error calculating message delivery rate:', error);
    return 100;
  }
}

// Get database query performance
async function getDatabaseQueryPerformance(db) {
  try {
    const stats = await db.stats();
    
    return {
      collections: stats.collections || 0,
      dataSize: stats.dataSize || 0,
      storageSize: stats.storageSize || 0,
      indexes: stats.indexes || 0,
      indexSize: stats.indexSize || 0,
      objects: stats.objects || 0,
    };
  } catch (error) {
    console.error('Error getting database query performance:', error);
    return null;
  }
}

// Get database connection pool status
async function getDatabaseConnectionPoolStatus(db) {
  try {
    const admin = db.admin();
    const serverStatus = await admin.serverStatus();
    
    return {
      connections: {
        current: serverStatus.connections?.current || 0,
        available: serverStatus.connections?.available || 0,
        active: serverStatus.connections?.active || 0,
      },
      network: {
        bytesIn: serverStatus.network?.bytesIn || 0,
        bytesOut: serverStatus.network?.bytesOut || 0,
        numRequests: serverStatus.network?.numRequests || 0,
      },
      opcounters: serverStatus.opcounters || {},
    };
  } catch (error) {
    console.error('Error getting database connection pool status:', error);
    return null;
  }
}

// Get current metrics from cache
function getCurrentMetrics() {
  return {
    ...metricsCache,
    responseTimes: metricsCache.responseTimes.slice(-100), // Last 100 only
  };
}

// Start periodic metric storage
function startMetricStorage(db, intervalMs = 60000) {
  setInterval(() => {
    storeMetricsToDatabase(db);
  }, intervalMs);
  
  // Store immediately
  storeMetricsToDatabase(db);
}

module.exports = {
  performanceMonitorMiddleware,
  getCurrentMetrics,
  storeMetricsToDatabase,
  getDatabaseQueryPerformance,
  getDatabaseConnectionPoolStatus,
  startMetricStorage,
};

