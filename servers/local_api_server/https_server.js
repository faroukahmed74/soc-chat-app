// =============================================================================
// SOC Chat App - HTTPS Server Configuration
// =============================================================================
// This file provides HTTPS server setup for production deployment
// Supports both Let's Encrypt and custom SSL certificates

const https = require('https');
const fs = require('fs');
const path = require('path');
const express = require('express');

// =============================================================================
// SSL CERTIFICATE CONFIGURATION
// =============================================================================

/**
 * Load SSL certificates from file paths
 */
function loadSSLCertificates() {
  const certPath = process.env.SSL_CERT_PATH;
  const keyPath = process.env.SSL_KEY_PATH;
  const caPath = process.env.SSL_CA_PATH;
  
  if (!certPath || !keyPath) {
    throw new Error('SSL_CERT_PATH and SSL_KEY_PATH environment variables are required for HTTPS');
  }
  
  try {
    const options = {
      key: fs.readFileSync(keyPath),
      cert: fs.readFileSync(certPath)
    };
    
    // Add CA certificate if provided
    if (caPath) {
      options.ca = fs.readFileSync(caPath);
    }
    
    return options;
  } catch (error) {
    throw new Error(`Failed to load SSL certificates: ${error.message}`);
  }
}

/**
 * Create HTTPS server with SSL certificates
 */
function createHTTPSServer(app) {
  const port = process.env.HTTPS_PORT || 3443;
  const host = process.env.HOST || '0.0.0.0';
  
  try {
    const sslOptions = loadSSLCertificates();
    const server = https.createServer(sslOptions, app);
    
    server.listen(port, host, () => {
      console.log(`🔒 HTTPS Server running on https://${host}:${port}`);
      console.log(`📜 SSL Certificate loaded from: ${process.env.SSL_CERT_PATH}`);
      console.log(`🔑 SSL Private Key loaded from: ${process.env.SSL_KEY_PATH}`);
    });
    
    return server;
  } catch (error) {
    console.error('❌ Failed to create HTTPS server:', error.message);
    process.exit(1);
  }
}

/**
 * Redirect HTTP to HTTPS middleware
 */
function redirectToHTTPS() {
  return (req, res, next) => {
    if (req.secure) {
      return next();
    }
    
    const httpsPort = process.env.HTTPS_PORT || 3443;
    const host = req.get('host').split(':')[0];
    const httpsUrl = `https://${host}:${httpsPort}${req.url}`;
    
    res.redirect(301, httpsUrl);
  };
}

/**
 * Create HTTP redirect server
 */
function createHTTPRedirectServer() {
  const http = require('http');
  const redirectApp = express();
  
  redirectApp.use(redirectToHTTPS());
  
  const port = process.env.HTTP_PORT || 3003;
  const host = process.env.HOST || '0.0.0.0';
  
  const server = http.createServer(redirectApp);
  
  server.listen(port, host, () => {
    console.log(`🔄 HTTP Redirect Server running on http://${host}:${port}`);
    console.log(`   Redirecting all traffic to HTTPS`);
  });
  
  return server;
}

// =============================================================================
// LET'S ENCRYPT INTEGRATION
// =============================================================================

/**
 * Setup Let's Encrypt SSL certificates
 */
async function setupLetsEncrypt(domain, email) {
  const { exec } = require('child_process');
  const util = require('util');
  const execAsync = util.promisify(exec);
  
  try {
    console.log('🔐 Setting up Let\'s Encrypt SSL certificates...');
    
    // Install certbot if not available
    try {
      await execAsync('which certbot');
    } catch (error) {
      console.log('📦 Installing certbot...');
      await execAsync('sudo apt-get update && sudo apt-get install -y certbot');
    }
    
    // Generate certificates
    const certbotCommand = `sudo certbot certonly --standalone --non-interactive --agree-tos --email ${email} -d ${domain}`;
    await execAsync(certbotCommand);
    
    // Set environment variables
    process.env.SSL_CERT_PATH = `/etc/letsencrypt/live/${domain}/fullchain.pem`;
    process.env.SSL_KEY_PATH = `/etc/letsencrypt/live/${domain}/privkey.pem`;
    
    console.log('✅ Let\'s Encrypt certificates generated successfully');
    console.log(`📜 Certificate: ${process.env.SSL_CERT_PATH}`);
    console.log(`🔑 Private Key: ${process.env.SSL_KEY_PATH}`);
    
  } catch (error) {
    console.error('❌ Failed to setup Let\'s Encrypt:', error.message);
    throw error;
  }
}

/**
 * Auto-renew Let's Encrypt certificates
 */
function setupAutoRenewal() {
  const cron = require('node-cron');
  
  // Run renewal check daily at 2 AM
  cron.schedule('0 2 * * *', async () => {
    try {
      console.log('🔄 Checking for certificate renewal...');
      const { exec } = require('child_process');
      const util = require('util');
      const execAsync = util.promisify(exec);
      
      await execAsync('sudo certbot renew --quiet');
      console.log('✅ Certificate renewal check completed');
    } catch (error) {
      console.error('❌ Certificate renewal failed:', error.message);
    }
  });
  
  console.log('⏰ Auto-renewal scheduled for daily at 2 AM');
}

// =============================================================================
// SSL SECURITY CONFIGURATION
// =============================================================================

/**
 * Configure SSL security options
 */
function configureSSLSecurity() {
  return {
    // SSL/TLS version
    minVersion: 'TLSv1.2',
    maxVersion: 'TLSv1.3',
    
    // Cipher suites (secure ones only)
    ciphers: [
      'ECDHE-RSA-AES128-GCM-SHA256',
      'ECDHE-RSA-AES256-GCM-SHA384',
      'ECDHE-RSA-AES128-SHA256',
      'ECDHE-RSA-AES256-SHA384',
      'ECDHE-RSA-AES128-SHA',
      'ECDHE-RSA-AES256-SHA',
      'AES128-GCM-SHA256',
      'AES256-GCM-SHA384',
      'AES128-SHA256',
      'AES256-SHA256',
      'AES128-SHA',
      'AES256-SHA'
    ].join(':'),
    
    // Honor cipher order
    honorCipherOrder: true,
    
    // Secure renegotiation
    secureProtocol: 'TLSv1_2_method',
    
    // Session cache
    sessionIdContext: 'soc-chat-app',
    
    // OCSP stapling
    requestOCSP: true
  };
}

// =============================================================================
// MIDDLEWARE FOR HTTPS
// =============================================================================

/**
 * HTTPS-only middleware
 */
function requireHTTPS() {
  return (req, res, next) => {
    if (!req.secure && req.get('x-forwarded-proto') !== 'https') {
      return res.status(403).json({
        error: 'HTTPS required',
        message: 'This server requires HTTPS connections'
      });
    }
    next();
  };
}

/**
 * HSTS (HTTP Strict Transport Security) middleware
 */
function hstsMiddleware() {
  return (req, res, next) => {
    if (req.secure) {
      res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
    }
    next();
  };
}

// =============================================================================
// HEALTH CHECK FOR HTTPS
// =============================================================================

/**
 * HTTPS health check endpoint
 */
function httpsHealthCheck(app) {
  app.get('/health/ssl', (req, res) => {
    const sslInfo = {
      secure: req.secure,
      protocol: req.protocol,
      hostname: req.hostname,
      port: req.get('host').split(':')[1] || (req.secure ? '443' : '80'),
      certificate: req.secure ? 'Valid SSL certificate' : 'No SSL certificate',
      timestamp: new Date().toISOString()
    };
    
    res.json({
      status: req.secure ? 'secure' : 'insecure',
      ssl: sslInfo,
      message: req.secure ? 'HTTPS connection established' : 'HTTP connection (not secure)'
    });
  });
}

// =============================================================================
// EXPORTS
// =============================================================================

module.exports = {
  createHTTPSServer,
  createHTTPRedirectServer,
  loadSSLCertificates,
  setupLetsEncrypt,
  setupAutoRenewal,
  configureSSLSecurity,
  requireHTTPS,
  hstsMiddleware,
  httpsHealthCheck,
  redirectToHTTPS
};

// =============================================================================
// USAGE EXAMPLES
// =============================================================================

/*
// Basic HTTPS server setup
const app = express();
const httpsServer = createHTTPSServer(app);

// With Let's Encrypt
await setupLetsEncrypt('yourdomain.com', 'admin@yourdomain.com');
setupAutoRenewal();

// With custom certificates
process.env.SSL_CERT_PATH = '/path/to/certificate.pem';
process.env.SSL_KEY_PATH = '/path/to/private-key.pem';
const httpsServer = createHTTPSServer(app);

// HTTP to HTTPS redirect
const httpServer = createHTTPRedirectServer();

// Apply HTTPS middleware
app.use(requireHTTPS());
app.use(hstsMiddleware());
httpsHealthCheck(app);
*/
