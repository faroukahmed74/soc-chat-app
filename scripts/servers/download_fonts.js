// Download local fonts for Flutter web (offline CanvasKit/HTML rendering)
// This script fetches Roboto TTFs and places them under assets/fonts/
// Usage: node servers/download_fonts.js

const fs = require('fs');
const path = require('path');
const https = require('https');

const targetDir = path.join(__dirname, '..', 'assets', 'fonts');

const fonts = [
  {
    filename: 'Roboto-Regular.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto-Regular.ttf',
      'https://raw.githubusercontent.com/googlefonts/roboto/main/src/hinted/Roboto-Regular.ttf',
    ],
  },
  {
    filename: 'Roboto-Medium.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto-Medium.ttf',
      'https://raw.githubusercontent.com/googlefonts/roboto/main/src/hinted/Roboto-Medium.ttf',
    ],
  },
  {
    filename: 'Roboto-Bold.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto-Bold.ttf',
      'https://raw.githubusercontent.com/googlefonts/roboto/main/src/hinted/Roboto-Bold.ttf',
    ],
  },
  // Arabic fonts for proper rendering of Arabic text and filenames
  {
    filename: 'NotoNaskhArabic-Regular.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/notonaskharabic/NotoNaskhArabic-Regular.ttf',
      'https://raw.githubusercontent.com/notofonts/notofonts.github.io/noto-monthly-release-2025.05.01/fonts/NotoNaskhArabic/hinted/ttf/NotoNaskhArabic-Regular.ttf',
    ],
  },
  {
    filename: 'NotoNaskhArabic-Bold.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/notonaskharabic/NotoNaskhArabic-Bold.ttf',
      'https://raw.githubusercontent.com/notofonts/notofonts.github.io/noto-monthly-release-2025.05.01/fonts/NotoNaskhArabic/hinted/ttf/NotoNaskhArabic-Bold.ttf',
    ],
  },
  {
    filename: 'NotoSansArabic-Regular.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/NotoSansArabic-Regular.ttf',
      'https://raw.githubusercontent.com/notofonts/notofonts.github.io/noto-monthly-release-2025.05.01/fonts/NotoSansArabic/hinted/ttf/NotoSansArabic-Regular.ttf',
    ],
  },
  {
    filename: 'NotoSansArabic-Bold.ttf',
    urls: [
      'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/NotoSansArabic-Bold.ttf',
      'https://raw.githubusercontent.com/notofonts/notofonts.github.io/noto-monthly-release-2025.05.01/fonts/NotoSansArabic/hinted/ttf/NotoSansArabic-Bold.ttf',
    ],
  },
];

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https
      .get(url, (res) => {
        if (res.statusCode !== 200) {
          file.close();
          fs.unlink(dest, () => {});
          return reject(new Error(`Failed to download ${url}: ${res.statusCode}`));
        }
        res.pipe(file);
        file.on('finish', () => file.close(resolve));
      })
      .on('error', (err) => {
        file.close();
        fs.unlink(dest, () => {});
        reject(err);
      });
  });
}

async function main() {
  console.log('Preparing to download Roboto fonts to', targetDir);
  ensureDir(targetDir);
  for (const f of fonts) {
    const dest = path.join(targetDir, f.filename);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 0) {
      console.log(`✔ Font already present: ${f.filename}`);
      continue;
    }
    console.log(`↓ Downloading ${f.filename}...`);
    let success = false;
    for (const url of f.urls) {
      try {
        await download(url, dest);
        console.log(`✔ Saved ${f.filename} from ${url}`);
        success = true;
        break;
      } catch (e) {
        console.warn(`• Fallback failed for ${f.filename} from ${url}: ${e.message}`);
      }
    }
    if (!success) {
      console.error(`✖ All attempts failed for ${f.filename}`);
    }
  }
  console.log('Done. If all fonts downloaded, run:');
  console.log('  flutter pub get');
  console.log('  flutter build web --release');
}

main().catch((e) => {
  console.error('Unexpected error:', e);
  process.exit(1);
});