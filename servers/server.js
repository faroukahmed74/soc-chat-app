const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');
const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 8082;

// Proxy API requests to local API server to keep same-origin for the web app
const API_TARGET = process.env.API_TARGET || 'http://localhost:3003';
app.use(
  '/api',
  createProxyMiddleware({
    target: API_TARGET,
    changeOrigin: true,
    logLevel: 'warn',
    onProxyReq: (proxyReq, req, res) => {
      // Remove Origin header so API treats request as non-browser (allowed by CORS)
      try {
        proxyReq.setHeader('origin', '');
      } catch (e) {}
    },
  })
);

// Proxy Socket.IO for real-time messaging
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

// Serve static files from the Flutter web build (project root build/web)
app.use(express.static(path.join(__dirname, '..', 'build', 'web')));

// Handle all routes by serving index.html (for SPA)
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
