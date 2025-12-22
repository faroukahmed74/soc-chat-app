// =============================================================================
// API KEY AUTHENTICATION MIDDLEWARE
// =============================================================================
// Middleware to authenticate requests using API keys

const { ObjectId } = require('mongodb');

/**
 * Middleware to authenticate API requests using API keys
 * Expects API key in header: X-API-Key: sk_xxxxx
 */
async function apiKeyAuthMiddleware(req, res, next) {
  try {
    const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '');
    
    if (!apiKey) {
      return res.status(401).json({
        error: {
          code: 'API_KEY_MISSING',
          message: 'API key is required',
        },
      });
    }
    
    const db = req.app.locals.db;
    const key = await db.collection('api_keys').findOne({ key: apiKey });
    
    if (!key) {
      return res.status(401).json({
        error: {
          code: 'API_KEY_INVALID',
          message: 'Invalid API key',
        },
      });
    }
    
    if (key.isActive === false) {
      return res.status(403).json({
        error: {
          code: 'API_KEY_INACTIVE',
          message: 'API key is inactive',
        },
      });
    }
    
    // Attach key info to request
    req.apiKey = {
      id: key._id.toString(),
      name: key.name,
      permissions: key.permissions || [],
      rateLimit: key.rateLimit || { requests: 100, window: 60 },
    };
    
    // Update usage stats
    await db.collection('api_keys').updateOne(
      { _id: key._id },
      {
        $set: { lastUsed: new Date() },
        $inc: { usageCount: 1 },
      }
    );
    
    // Log API usage
    await db.collection('api_usage_logs').insertOne({
      keyId: key._id,
      endpoint: req.path,
      method: req.method,
      timestamp: new Date(),
      ip: req.ip,
      userAgent: req.headers['user-agent'],
    });
    
    next();
  } catch (error) {
    console.error('API key authentication error:', error);
    res.status(500).json({
      error: {
        code: 'AUTH_ERROR',
        message: 'Authentication error',
      },
    });
  }
}

/**
 * Middleware to check API key permissions
 * @param {string[]} requiredPermissions - Array of required permissions
 */
function requireApiPermission(requiredPermissions) {
  return (req, res, next) => {
    if (!req.apiKey) {
      return res.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'API key authentication required',
        },
      });
    }
    
    const hasPermission = requiredPermissions.some(permission =>
      req.apiKey.permissions.includes(permission) || req.apiKey.permissions.includes('*')
    );
    
    if (!hasPermission) {
      return res.status(403).json({
        error: {
          code: 'INSUFFICIENT_PERMISSIONS',
          message: 'Insufficient permissions',
        },
      });
    }
    
    next();
  };
}

module.exports = {
  apiKeyAuthMiddleware,
  requireApiPermission,
};

