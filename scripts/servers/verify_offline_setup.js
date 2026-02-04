// =============================================================================
// VERIFY OFFLINE SETUP
// =============================================================================
// Verifies that all offline assets are present and API/MongoDB connections work

const fs = require('fs');
const path = require('path');
const http = require('http');

const BUILD_WEB_DIR = path.join(__dirname, '..', 'build', 'web');
const CANVASKIT_DIR = path.join(BUILD_WEB_DIR, 'canvaskit');
const API_TARGET = process.env.API_TARGET || 'http://127.0.0.1:3003';
const WEB_PORT = process.env.PORT || 8082;

console.log('========================================');
console.log('  Verifying Offline Web Setup');
console.log('========================================');
console.log('');

// Check file existence
function checkFile(filePath, name) {
  const exists = fs.existsSync(filePath);
  console.log(`${exists ? '✅' : '❌'} ${name}`);
  if (!exists) {
    console.log(`   Missing: ${filePath}`);
  }
  return exists;
}

// Verify assets
console.log('📦 Checking Offline Assets...');
console.log('');

const assetChecks = {
  'Web Build Directory': checkFile(BUILD_WEB_DIR, 'build/web directory'),
  'index.html': checkFile(path.join(BUILD_WEB_DIR, 'index.html'), 'index.html'),
  'main.dart.js': checkFile(path.join(BUILD_WEB_DIR, 'main.dart.js'), 'main.dart.js'),
  'flutter.js': checkFile(path.join(BUILD_WEB_DIR, 'flutter.js'), 'flutter.js'),
  'Service Worker': checkFile(path.join(BUILD_WEB_DIR, 'firebase-messaging-sw.js'), 'firebase-messaging-sw.js'),
  'CanvasKit Directory': checkFile(CANVASKIT_DIR, 'canvaskit directory'),
  'canvaskit.js': checkFile(path.join(CANVASKIT_DIR, 'canvaskit.js'), 'canvaskit.js'),
  'canvaskit.wasm': checkFile(path.join(CANVASKIT_DIR, 'canvaskit.wasm'), 'canvaskit.wasm'),
};

const allAssetsOk = Object.values(assetChecks).every(v => v);

console.log('');
console.log('🔌 Checking API/MongoDB Connection...');
console.log('');

// Test API connection
function testApiConnection() {
  return new Promise((resolve) => {
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
        const ok = response.statusCode === 200;
        console.log(`${ok ? '✅' : '❌'} API Server Connection`);
        console.log(`   Status: ${response.statusCode}`);
        console.log(`   Target: ${API_TARGET}`);
        if (ok) {
          try {
            const json = JSON.parse(data);
            console.log(`   Response: ${JSON.stringify(json)}`);
          } catch (e) {
            console.log(`   Response: ${data.substring(0, 100)}`);
          }
        }
        resolve(ok);
      });
    });
    
    request.on('error', (err) => {
      console.log('❌ API Server Connection');
      console.log(`   Error: ${err.message}`);
      console.log(`   Target: ${API_TARGET}`);
      console.log('   Make sure the API server is running!');
      resolve(false);
    });
    
    request.on('timeout', () => {
      request.destroy();
      console.log('❌ API Server Connection');
      console.log('   Error: Connection timeout');
      console.log(`   Target: ${API_TARGET}`);
      resolve(false);
    });
    
    request.end();
  });
}

// Test web server
function testWebServer() {
  return new Promise((resolve) => {
    const request = http.request({
      hostname: 'localhost',
      port: WEB_PORT,
      path: '/offline-status',
      method: 'GET',
      timeout: 3000,
    }, (response) => {
      let data = '';
      response.on('data', (chunk) => { data += chunk; });
      response.on('end', () => {
        const ok = response.statusCode === 200;
        console.log(`${ok ? '✅' : '❌'} Web Server`);
        console.log(`   Status: ${response.statusCode}`);
        console.log(`   Port: ${WEB_PORT}`);
        if (ok) {
          try {
            const json = JSON.parse(data);
            console.log(`   Offline Ready: ${json.offline ? 'Yes' : 'No'}`);
          } catch (e) {}
        }
        resolve(ok);
      });
    });
    
    request.on('error', () => {
      console.log('❌ Web Server');
      console.log(`   Error: Server not running on port ${WEB_PORT}`);
      console.log('   Start it with: node servers/offline_web_server.js');
      resolve(false);
    });
    
    request.on('timeout', () => {
      request.destroy();
      console.log('❌ Web Server');
      console.log('   Error: Connection timeout');
      resolve(false);
    });
    
    request.end();
  });
}

// Run all checks
(async () => {
  const apiOk = await testApiConnection();
  console.log('');
  const webOk = await testWebServer();
  
  console.log('');
  console.log('========================================');
  console.log('  Verification Summary');
  console.log('========================================');
  console.log(`   Assets: ${allAssetsOk ? '✅ All present' : '❌ Some missing'}`);
  console.log(`   API/MongoDB: ${apiOk ? '✅ Connected' : '❌ Not connected'}`);
  console.log(`   Web Server: ${webOk ? '✅ Running' : '❌ Not running'}`);
  console.log('========================================');
  console.log('');
  
  if (allAssetsOk && apiOk && webOk) {
    console.log('✅ Everything is ready for offline operation!');
    console.log('');
    console.log('Access the app at:');
    console.log(`   http://localhost:${WEB_PORT}`);
    console.log(`   http://[YOUR_IPV4]:${WEB_PORT}`);
  } else {
    console.log('⚠️  Some issues found. Please fix them before using offline mode.');
    console.log('');
    if (!allAssetsOk) {
      console.log('To download missing assets:');
      console.log('   node servers/download_all_assets.js');
    }
    if (!apiOk) {
      console.log('To start API server:');
      console.log('   node servers/local_api_server/server.js');
    }
    if (!webOk) {
      console.log('To start web server:');
      console.log('   node servers/offline_web_server.js');
    }
  }
  console.log('');
})();

