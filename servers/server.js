const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');
const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 8082;

// Proxy API requests to local API server to keep same-origin for the web app
// Use 127.0.0.1 for localhost, but for remote access we need to use the actual host IP
const API_TARGET = process.env.API_TARGET || 'http://127.0.0.1:3003';
console.log('API Proxy configured to target:', API_TARGET);
console.log('NOTE: For remote access, ensure API server is running and accessible on the network');

// CRITICAL: Route order matters! Proxy routes MUST come before static file serving

// Proxy Socket.IO for real-time messaging (comes first to avoid conflicts)
app.use(
  '/socket.io',
  createProxyMiddleware({
    target: API_TARGET,
    ws: true,
    changeOrigin: true,
    logLevel: 'warn',
    onProxyReq: (proxyReq, req, res) => {
      try {
        proxyReq.setHeader('origin', '');
      } catch (e) {}
    },
  })
);

// Proxy API requests to local API server
app.use(
  '/api',
  createProxyMiddleware({
    target: API_TARGET,
    changeOrigin: true,
    logLevel: 'debug',
    // The /api prefix is automatically stripped by app.use('/api'), so we need to add it back
    pathRewrite: function (path, req) {
      // path will be like '/chats' after stripping, add '/api' back
      console.log('Proxying API:', req.url, 'path:', path, '-> /api' + path);
      return '/api' + path;
    },
    onProxyReq: (proxyReq, req, res) => {
      console.log('Proxying API request:', req.method, req.url, '->', API_TARGET + '/api' + req.url.replace(/^\/api/, ''));
      // Remove Origin header so API treats request as non-browser (allowed by CORS)
      try {
        proxyReq.setHeader('origin', '');
      } catch (e) {}
    },
    onProxyRes: (proxyRes, req, res) => {
      console.log('API Proxy response:', proxyRes.statusCode, req.url);
    },
    onError: (err, req, res) => {
      console.error('API Proxy error:', err.message);
      res.status(500).json({ error: 'Proxy error', message: err.message });
    },
  })
);

// Serve static files from the Flutter web build (project root build/web)
app.use(express.static(path.join(__dirname, '..', 'build', 'web')));

// Quick readiness endpoint to verify offline assets are present
app.get('/offline-status', (req, res) => {
  try {
    const root = path.join(__dirname, '..', 'build', 'web');
    const ckDir = path.join(root, 'canvaskit');
    const hasIndex = fsExists(path.join(root, 'index.html'));
    const hasMain = fsExists(path.join(root, 'main.dart.js'));
    const hasSW = fsExists(path.join(root, 'flutter_service_worker.js'));
    const hasCK = fsExists(path.join(ckDir, 'canvaskit.wasm')) && fsExists(path.join(ckDir, 'canvaskit.js'));
    res.json({
      ok: hasIndex && hasMain,
      buildRoot: root,
      indexHtml: hasIndex,
      mainDartJs: hasMain,
      serviceWorker: hasSW,
      canvasKitLocal: hasCK,
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

function fsExists(p) {
  try { return require('fs').existsSync(p); } catch (_) { return false; }
}

// Handle all routes by serving index.html (for SPA) - MUST come last
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '..', 'build', 'web', 'index.html'));
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
    console.log('========================================');
    console.log('  SOC Chat App - Portable Server');
    console.log('========================================');
    console.log('');
    console.log(`🚀 App is running at:`);
    console.log(`   Local: http://localhost:${PORT}`);
    console.log(`   Network: http://0.0.0.0:${PORT}`);
    console.log('');
    console.log('Offline assets readiness check:');
    console.log(`   GET http://localhost:${PORT}/offline-status`);
    console.log('');
    console.log('Press Ctrl+C to stop the server');
    console.log('');
    
    // Auto-open browser
    const { exec } = require('child_process');
    exec(`start http://localhost:${PORT}`, (error) => {
        if (error) {
            console.log('Please open your browser and navigate to:');
            console.log(`http://localhost:${PORT}`);
        }
    });
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down SOC Chat App...');
    process.exit(0);
});
