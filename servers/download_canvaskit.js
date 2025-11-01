// Node script to download CanvasKit files for offline Flutter web rendering
// Saves files into build/web/canvaskit so the proxy can serve them locally

const https = require('https');
const fs = require('fs');
const path = require('path');

// Match the version used in servers/download_canvaskit.sh
const BASE = 'https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium';
const FILES = [
  { name: 'canvaskit.js', url: `${BASE}/canvaskit.js` },
  { name: 'canvaskit.wasm', url: `${BASE}/canvaskit.wasm` },
  // Some builds may reference chromium/canvaskit.js path; include it too
  { name: path.join('chromium', 'canvaskit.js'), url: `${BASE}/canvaskit.js` },
];

const DEST_DIR = path.join(__dirname, '..', 'build', 'web', 'canvaskit');

function ensureDir(p) {
  try { fs.mkdirSync(p, { recursive: true }); } catch (_) {}
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    console.log(`Downloading ${url} -> ${dest}`);
    const file = fs.createWriteStream(dest);
    https.get(url, (res) => {
      if (res.statusCode !== 200) {
        file.close();
        fs.unlink(dest, () => {});
        return reject(new Error(`Failed (${res.statusCode}) ${url}`));
      }
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', (err) => {
      file.close();
      fs.unlink(dest, () => {});
      reject(err);
    });
  });
}

async function main() {
  ensureDir(DEST_DIR);
  ensureDir(path.join(DEST_DIR, 'chromium'));

  let failures = 0;
  for (const f of FILES) {
    const dest = path.join(DEST_DIR, f.name);
    try {
      await download(f.url, dest);
    } catch (e) {
      failures++;
      console.error(`Error downloading ${f.url}: ${e.message}`);
    }
  }

  console.log('=========================================');
  if (failures === 0) {
    console.log('✅ CanvasKit files downloaded successfully');
    console.log(`   Location: ${DEST_DIR}`);
  } else {
    console.log('⚠️ Completed with some errors. Check logs above.');
    console.log(`   Files may be missing under: ${DEST_DIR}`);
  }
  console.log('=========================================');
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});