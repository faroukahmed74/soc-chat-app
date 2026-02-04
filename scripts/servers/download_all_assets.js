// =============================================================================
// DOWNLOAD ALL OFFLINE ASSETS FOR WEB
// =============================================================================
// Downloads all Flutter web assets (CanvasKit, fonts, etc.) for complete offline support
// All assets are stored locally and served by the proxy server

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

// CanvasKit version (matches Flutter's default)
const CANVASKIT_VERSION = '1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f';
const CANVASKIT_BASE = `https://www.gstatic.com/flutter-canvaskit/${CANVASKIT_VERSION}/chromium`;

// Assets to download
const ASSETS = {
  canvaskit: [
    { name: 'canvaskit.js', url: `${CANVASKIT_BASE}/canvaskit.js` },
    { name: 'canvaskit.wasm', url: `${CANVASKIT_BASE}/canvaskit.wasm` },
    { name: 'skwasm.js', url: `${CANVASKIT_BASE}/skwasm.js` },
    { name: 'skwasm.wasm', url: `${CANVASKIT_BASE}/skwasm.wasm` },
    { name: 'skwasm_heavy.js', url: `${CANVASKIT_BASE}/skwasm_heavy.js` },
    { name: 'skwasm_heavy.wasm', url: `${CANVASKIT_BASE}/skwasm_heavy.wasm` },
  ],
};

const BUILD_WEB_DIR = path.join(__dirname, '..', 'build', 'web');
const CANVASKIT_DIR = path.join(BUILD_WEB_DIR, 'canvaskit');

// Utility functions
function ensureDir(p) {
  try {
    fs.mkdirSync(p, { recursive: true });
  } catch (e) {
    if (e.code !== 'EEXIST') throw e;
  }
}

function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    console.log(`📥 Downloading: ${path.basename(dest)}`);
    const file = fs.createWriteStream(dest);
    const protocol = url.startsWith('https') ? https : http;
    
    protocol.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        // Handle redirects
        file.close();
        fs.unlink(dest, () => {});
        return downloadFile(res.headers.location, dest).then(resolve).catch(reject);
      }
      
      if (res.statusCode !== 200) {
        file.close();
        fs.unlink(dest, () => {});
        return reject(new Error(`HTTP ${res.statusCode}: ${url}`));
      }
      
      const totalSize = parseInt(res.headers['content-length'], 10);
      let downloadedSize = 0;
      
      res.on('data', (chunk) => {
        downloadedSize += chunk.length;
        if (totalSize) {
          const percent = ((downloadedSize / totalSize) * 100).toFixed(1);
          process.stdout.write(`\r   Progress: ${percent}%`);
        }
      });
      
      res.pipe(file);
      
      file.on('finish', () => {
        file.close();
        console.log(` ✅ ${path.basename(dest)}`);
        resolve();
      });
    }).on('error', (err) => {
      file.close();
      fs.unlink(dest, () => {});
      reject(err);
    });
  });
}

async function downloadAssets() {
  console.log('========================================');
  console.log('  Downloading Offline Web Assets');
  console.log('========================================');
  console.log('');
  
  // Ensure directories exist
  ensureDir(BUILD_WEB_DIR);
  ensureDir(CANVASKIT_DIR);
  
  let totalFiles = 0;
  let successFiles = 0;
  let failedFiles = 0;
  
  // Download CanvasKit files
  console.log('📦 Downloading CanvasKit files...');
  for (const asset of ASSETS.canvaskit) {
    totalFiles++;
    const dest = path.join(CANVASKIT_DIR, asset.name);
    
    // Check if file already exists
    if (fs.existsSync(dest)) {
      console.log(` ⏭️  Skipping (already exists): ${asset.name}`);
      successFiles++;
      continue;
    }
    
    try {
      await downloadFile(asset.url, dest);
      successFiles++;
    } catch (error) {
      failedFiles++;
      console.error(` ❌ Failed to download ${asset.name}: ${error.message}`);
    }
  }
  
  console.log('');
  console.log('========================================');
  console.log('  Download Summary');
  console.log('========================================');
  console.log(`   Total files: ${totalFiles}`);
  console.log(`   ✅ Success: ${successFiles}`);
  console.log(`   ❌ Failed: ${failedFiles}`);
  console.log(`   Location: ${CANVASKIT_DIR}`);
  console.log('========================================');
  console.log('');
  
  if (failedFiles === 0) {
    console.log('✅ All assets downloaded successfully!');
    console.log('   The web app can now run completely offline.');
  } else {
    console.log('⚠️  Some assets failed to download.');
    console.log('   The app may still work, but some features might be limited.');
  }
  console.log('');
}

// Run the download
downloadAssets().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

