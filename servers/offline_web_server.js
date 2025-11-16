// =============================================================================
// OFFLINE WEB SERVER - Complete Offline Support
// =============================================================================
// Serves Flutter web app and proxies all API/MongoDB requests
// All assets are served locally - no internet required after initial setup

const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 8082;
const API_TARGET = process.env.API_TARGET || 'http://127.0.0.1:3003';

console.log('========================================');
console.log('  SOC Chat App - Offline Web Server');
console.log('========================================');
console.log('');
console.log('Configuration:');
console.log(`   Port: ${PORT}`);
console.log(`   API Target: ${API_TARGET}`);
console.log(`   Web Build: ${path.join(__dirname, '..', 'build', 'web')}`);
console.log('');

// =============================================================================
// MIDDLEWARE
// =============================================================================

// CORS for local network access
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, ngrok-skip-browser-warning');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// =============================================================================
// PROXY ROUTES (Must come before static file serving)
// =============================================================================

// Proxy Socket.IO for real-time messaging
app.use(
  '/socket.io',
  createProxyMiddleware({
    target: API_TARGET,
    ws: true,
    changeOrigin: true,
    logLevel: 'warn',
    onProxyReq: (proxyReq, req) => {
      try {
        proxyReq.setHeader('origin', '');
        const clientBase = `${req.protocol}://${req.headers.host}`;
        proxyReq.setHeader('x-client-base', clientBase);
        proxyReq.setHeader('x-client-platform', 'web');
      } catch (e) {}
    },
    onError: (err, req, res) => {
      console.error('Socket.IO proxy error:', err.message);
      if (!res.headersSent) {
        res.status(502).json({ error: 'Socket.IO proxy error', message: err.message });
      }
    },
  })
);

// Proxy API requests to MongoDB server
app.use(
  '/api',
  createProxyMiddleware({
    target: API_TARGET,
    changeOrigin: true,
    logLevel: 'info',
    pathRewrite: (path, req) => {
      // Keep /api prefix for API server
      return path.startsWith('/api') ? path : '/api' + path;
    },
    onProxyReq: (proxyReq, req) => {
      try {
        proxyReq.setHeader('origin', '');
        const clientBase = `${req.protocol}://${req.headers.host}`;
        proxyReq.setHeader('x-client-base', clientBase);
        proxyReq.setHeader('x-client-platform', 'web');
      } catch (e) {}
    },
    onProxyRes: (proxyRes, req) => {
      // Log API responses for debugging
      if (req.url.includes('/health') || req.url.includes('/auth')) {
        console.log(`API ${proxyRes.statusCode}: ${req.method} ${req.url}`);
      }
    },
    onError: (err, req, res) => {
      console.error('API proxy error:', err.message);
      if (!res.headersSent) {
        res.status(502).json({ error: 'API proxy error', message: err.message });
      }
    },
  })
);

// Proxy uploaded media files
app.use(
  '/uploads',
  createProxyMiddleware({
    target: API_TARGET,
    changeOrigin: true,
    logLevel: 'warn',
    onError: (err, req, res) => {
      console.error('Uploads proxy error:', err.message);
      if (!res.headersSent) {
        res.status(502).end('Proxy error');
      }
    },
  })
);

// Proxy legacy chat media paths
app.use(
  '/chat_media',
  createProxyMiddleware({
    target: API_TARGET,
    changeOrigin: true,
    logLevel: 'warn',
    onError: (err, req, res) => {
      console.error('ChatMedia proxy error:', err.message);
      if (!res.headersSent) {
        res.status(502).end('Proxy error');
      }
    },
  })
);

// =============================================================================
// STATIC FILE SERVING
// =============================================================================

const webBuildDir = path.join(__dirname, '..', 'build', 'web');

// Serve static files from Flutter web build
app.use(express.static(webBuildDir, {
  maxAge: '1y', // Cache for 1 year
  etag: true,
  lastModified: true,
}));

// =============================================================================
// HEALTH & STATUS ENDPOINTS
// =============================================================================

// Offline assets status check
app.get('/offline-status', (req, res) => {
  try {
    const checks = {
      buildDir: fs.existsSync(webBuildDir),
      indexHtml: fs.existsSync(path.join(webBuildDir, 'index.html')),
      mainDartJs: fs.existsSync(path.join(webBuildDir, 'main.dart.js')),
      flutterJs: fs.existsSync(path.join(webBuildDir, 'flutter.js')),
      serviceWorker: fs.existsSync(path.join(webBuildDir, 'firebase-messaging-sw.js')),
      canvaskitDir: fs.existsSync(path.join(webBuildDir, 'canvaskit')),
      canvaskitJs: fs.existsSync(path.join(webBuildDir, 'canvaskit', 'canvaskit.js')),
      canvaskitWasm: fs.existsSync(path.join(webBuildDir, 'canvaskit', 'canvaskit.wasm')),
    };
    
    const allOk = Object.values(checks).every(v => v === true);
    
    res.json({
      ok: allOk,
      offline: allOk,
      buildDir: webBuildDir,
      checks: checks,
      message: allOk 
        ? 'All offline assets are available' 
        : 'Some offline assets are missing',
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// API connection test
app.get('/api-connection-test', async (req, res) => {
  try {
    const http = require('http');
    const url = require('url');
    const apiUrl = new URL('/api/health', API_TARGET);
    
    const request = http.request({
      hostname: apiUrl.hostname,
      port: apiUrl.port,
      path: apiUrl.pathname,
      method: 'GET',
      timeout: 5000,
    }, (response) => {
      let data = '';
      response.on('data', (chunk) => { data += chunk; });
      response.on('end', () => {
        res.json({
          ok: response.statusCode === 200,
          statusCode: response.statusCode,
          apiTarget: API_TARGET,
          response: data,
        });
      });
    });
    
    request.on('error', (err) => {
      res.json({
        ok: false,
        apiTarget: API_TARGET,
        error: err.message,
      });
    });
    
    request.on('timeout', () => {
      request.destroy();
      res.json({
        ok: false,
        apiTarget: API_TARGET,
        error: 'Connection timeout',
      });
    });
    
    request.end();
  } catch (e) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// =============================================================================
// SPA ROUTE HANDLING
// =============================================================================

// Handle all routes by serving index.html (for SPA) - MUST come last
app.get('*', (req, res) => {
  const indexPath = path.join(webBuildDir, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.status(404).send(`
      <html>
        <head><title>Build Not Found</title></head>
        <body>
          <h1>Web Build Not Found</h1>
          <p>Please run: <code>flutter build web --base-href "/" --release</code></p>
          <p>Expected location: ${webBuildDir}</p>
        </body>
      </html>
    `);
  }
});

// =============================================================================
// START SERVER
// =============================================================================

app.listen(PORT, '0.0.0.0', () => {
  console.log('✅ Server started successfully!');
  console.log('');
  console.log('🌐 Access the app at:');
  console.log(`   Local:    http://localhost:${PORT}`);
  console.log(`   Network:  http://0.0.0.0:${PORT}`);
  console.log('');
  console.log('📊 Status endpoints:');
  console.log(`   Assets:   http://localhost:${PORT}/offline-status`);
  console.log(`   API:      http://localhost:${PORT}/api-connection-test`);
  console.log('');
  console.log('Press Ctrl+C to stop the server');
  console.log('');
  
  // Auto-open browser (Windows)
  if (process.platform === 'win32') {
    const { exec } = require('child_process');
    exec(`start http://localhost:${PORT}`, (error) => {
      if (error) {
        console.log('Please open your browser manually');
      }
    });
  }
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down server...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Shutting down server...');
  process.exit(0);
});

