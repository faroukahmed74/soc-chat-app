// =============================================================================
// IP FILTERING MIDDLEWARE
// =============================================================================
// This middleware checks IP addresses against whitelist and blacklist
// Should be applied to admin routes for enhanced security

const { ObjectId } = require('mongodb');

/**
 * Get client IP address from request
 */
function getClientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
         req.headers['x-real-ip'] ||
         req.connection?.remoteAddress ||
         req.socket?.remoteAddress ||
         req.ip ||
         'unknown';
}

/**
 * Check if IP is in whitelist
 */
async function isIpWhitelisted(db, ip) {
  try {
    const settings = await db.collection('security_settings').findOne({ type: 'global' });
    if (!settings || !settings.ipWhitelist || settings.ipWhitelist.length === 0) {
      // If no whitelist configured, allow all (whitelist is optional)
      return true;
    }
    
    return settings.ipWhitelist.some(entry => entry.ip === ip);
  } catch (error) {
    console.error('Error checking IP whitelist:', error);
    // On error, allow access (fail open)
    return true;
  }
}

/**
 * Check if IP is in blacklist
 */
async function isIpBlacklisted(db, ip) {
  try {
    const settings = await db.collection('security_settings').findOne({ type: 'global' });
    if (!settings || !settings.ipBlacklist || settings.ipBlacklist.length === 0) {
      return false;
    }
    
    return settings.ipBlacklist.some(entry => entry.ip === ip);
  } catch (error) {
    console.error('Error checking IP blacklist:', error);
    // On error, allow access (fail open)
    return false;
  }
}

/**
 * IP filtering middleware
 * Checks if the client IP is whitelisted/blacklisted
 */
function ipFilterMiddleware(req, res, next) {
  const db = req.app.locals.db;
  if (!db) {
    // If DB not available, skip filtering
    return next();
  }
  
  const clientIp = getClientIp(req);
  
  // Skip filtering for localhost
  if (clientIp === '127.0.0.1' || clientIp === '::1' || clientIp === 'localhost') {
    return next();
  }
  
  // Check blacklist first
  isIpBlacklisted(db, clientIp).then(isBlacklisted => {
    if (isBlacklisted) {
      console.warn(`[IP FILTER] Blocked blacklisted IP: ${clientIp}`);
      
      // Log suspicious activity
      db.collection('suspicious_activity').insertOne({
        type: 'blocked_ip',
        ip: clientIp,
        description: `Blocked IP attempted to access: ${req.method} ${req.path}`,
        severity: 'high',
        timestamp: new Date(),
        resolved: false,
      }).catch(err => console.error('Error logging suspicious activity:', err));
      
      return res.status(403).json({
        error: {
          code: 'IP_BLACKLISTED',
          message: 'Access denied: IP address is blacklisted',
          timestamp: new Date().toISOString(),
        },
      });
    }
    
    // Check whitelist (if whitelist is enabled and has entries)
    isIpWhitelisted(db, clientIp).then(isWhitelisted => {
      if (!isWhitelisted) {
        // Check if whitelist is actually enforced (has entries)
        db.collection('security_settings').findOne({ type: 'global' }).then(settings => {
          if (settings && settings.ipWhitelist && settings.ipWhitelist.length > 0) {
            // Whitelist is enforced and IP is not whitelisted
            console.warn(`[IP FILTER] Blocked non-whitelisted IP: ${clientIp}`);
            
            // Log suspicious activity
            db.collection('suspicious_activity').insertOne({
              type: 'blocked_ip',
              ip: clientIp,
              description: `Non-whitelisted IP attempted to access: ${req.method} ${req.path}`,
              severity: 'medium',
              timestamp: new Date(),
              resolved: false,
            }).catch(err => console.error('Error logging suspicious activity:', err));
            
            return res.status(403).json({
              error: {
                code: 'IP_NOT_WHITELISTED',
                message: 'Access denied: IP address is not whitelisted',
                timestamp: new Date().toISOString(),
              },
            });
          } else {
            // Whitelist not enforced, allow access
            next();
          }
        }).catch(err => {
          console.error('Error checking whitelist enforcement:', err);
          next(); // Fail open
        });
      } else {
        // IP is whitelisted or whitelist not enforced
        next();
      }
    }).catch(err => {
      console.error('Error checking IP whitelist:', err);
      next(); // Fail open
    });
  }).catch(err => {
    console.error('Error checking IP blacklist:', err);
    next(); // Fail open
  });
}

/**
 * Track failed login attempt
 */
async function trackFailedLogin(db, ip, email, userId, reason, userAgent) {
  try {
    await db.collection('failed_login_attempts').insertOne({
      ip: ip,
      email: email,
      userId: userId ? new ObjectId(userId) : null,
      reason: reason || 'Invalid credentials',
      timestamp: new Date(),
      userAgent: userAgent || 'unknown',
    });
    
    // Check if this IP has too many failed attempts
    const recentAttempts = await db.collection('failed_login_attempts')
      .countDocuments({
        ip: ip,
        timestamp: { $gte: new Date(Date.now() - 15 * 60 * 1000) }, // Last 15 minutes
      });
    
    // Get security settings
    const settings = await db.collection('security_settings').findOne({ type: 'global' });
    const threshold = settings?.suspiciousActivityAlerts?.threshold || 10;
    
    if (recentAttempts >= threshold) {
      // Log suspicious activity
      await db.collection('suspicious_activity').insertOne({
        type: 'multiple_failed_logins',
        ip: ip,
        userId: userId ? new ObjectId(userId) : null,
        description: `Multiple failed login attempts (${recentAttempts}) from IP: ${ip}`,
        severity: 'high',
        timestamp: new Date(),
        resolved: false,
      });
    }
  } catch (error) {
    console.error('Error tracking failed login:', error);
  }
}

module.exports = {
  ipFilterMiddleware,
  getClientIp,
  isIpWhitelisted,
  isIpBlacklisted,
  trackFailedLogin,
};

