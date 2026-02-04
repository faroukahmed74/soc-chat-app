// =============================================================================
// RATE LIMITING MIDDLEWARE
// =============================================================================
// Middleware to enforce rate limits on API requests

/**
 * In-memory rate limit store (for production, use Redis)
 */
const rateLimitStore = new Map();

/**
 * Clear old entries periodically
 */
setInterval(() => {
  const now = Date.now();
  for (const [key, data] of rateLimitStore.entries()) {
    if (now - data.windowStart > data.window * 1000) {
      rateLimitStore.delete(key);
    }
  }
}, 60000); // Clean up every minute

/**
 * Rate limiting middleware
 * @param {Object} options - Rate limit options
 * @param {number} options.requests - Number of requests allowed
 * @param {number} options.window - Time window in seconds
 * @param {Function} options.keyGenerator - Function to generate rate limit key
 */
function rateLimiter(options = {}) {
  const {
    requests = 100,
    window = 60,
    keyGenerator = (req) => {
      // Default: use API key ID or IP address
      return req.apiKey?.id || req.ip || 'anonymous';
    },
  } = options;
  
  return async (req, res, next) => {
    try {
      const key = keyGenerator(req);
      const now = Date.now();
      
      // Get or create rate limit entry
      let rateLimitData = rateLimitStore.get(key);
      
      if (!rateLimitData || now - rateLimitData.windowStart > window * 1000) {
        // New window
        rateLimitData = {
          count: 1,
          windowStart: now,
          window: window,
        };
        rateLimitStore.set(key, rateLimitData);
        return next();
      }
      
      // Check if limit exceeded
      if (rateLimitData.count >= requests) {
        const resetTime = new Date(rateLimitData.windowStart + window * 1000);
        return res.status(429).json({
          error: {
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'Rate limit exceeded',
            retryAfter: Math.ceil((resetTime.getTime() - now) / 1000),
            limit: requests,
            window: window,
          },
        });
      }
      
      // Increment count
      rateLimitData.count++;
      rateLimitStore.set(key, rateLimitData);
      
      // Add rate limit headers
      res.setHeader('X-RateLimit-Limit', requests);
      res.setHeader('X-RateLimit-Remaining', Math.max(0, requests - rateLimitData.count));
      res.setHeader('X-RateLimit-Reset', new Date(rateLimitData.windowStart + window * 1000).toISOString());
      
      next();
    } catch (error) {
      console.error('Rate limiting error:', error);
      // On error, allow request to proceed
      next();
    }
  };
}

/**
 * API key-based rate limiter (uses rate limit from API key)
 */
function apiKeyRateLimiter() {
  return rateLimiter({
    keyGenerator: (req) => {
      if (req.apiKey) {
        return `api_key:${req.apiKey.id}`;
      }
      return req.ip || 'anonymous';
    },
    requests: (req) => {
      if (req.apiKey) {
        return req.apiKey.rateLimit?.requests || 100;
      }
      return 100;
    },
    window: (req) => {
      if (req.apiKey) {
        return req.apiKey.rateLimit?.window || 60;
      }
      return 60;
    },
  });
}

/**
 * Dynamic rate limiter that uses API key settings
 */
function dynamicRateLimiter() {
  return async (req, res, next) => {
    try {
      if (!req.apiKey) {
        // No API key, use default rate limit
        return rateLimiter({ requests: 100, window: 60 })(req, res, next);
      }
      
      const requests = req.apiKey.rateLimit?.requests || 100;
      const window = req.apiKey.rateLimit?.window || 60;
      const key = `api_key:${req.apiKey.id}`;
      
      const now = Date.now();
      let rateLimitData = rateLimitStore.get(key);
      
      if (!rateLimitData || now - rateLimitData.windowStart > window * 1000) {
        rateLimitData = {
          count: 1,
          windowStart: now,
          window: window,
        };
        rateLimitStore.set(key, rateLimitData);
        return next();
      }
      
      if (rateLimitData.count >= requests) {
        const resetTime = new Date(rateLimitData.windowStart + window * 1000);
        return res.status(429).json({
          error: {
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'Rate limit exceeded',
            retryAfter: Math.ceil((resetTime.getTime() - now) / 1000),
            limit: requests,
            window: window,
          },
        });
      }
      
      rateLimitData.count++;
      rateLimitStore.set(key, rateLimitData);
      
      res.setHeader('X-RateLimit-Limit', requests);
      res.setHeader('X-RateLimit-Remaining', Math.max(0, requests - rateLimitData.count));
      res.setHeader('X-RateLimit-Reset', new Date(rateLimitData.windowStart + window * 1000).toISOString());
      
      next();
    } catch (error) {
      console.error('Dynamic rate limiting error:', error);
      next();
    }
  };
}

module.exports = {
  rateLimiter,
  apiKeyRateLimiter,
  dynamicRateLimiter,
};

