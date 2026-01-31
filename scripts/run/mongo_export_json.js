/**
 * MongoDB JSON backup exporter (fallback when mongodump isn't installed)
 *
 * Writes one file per collection as JSON Lines (EJSON) so types like ObjectId/Date are preserved.
 *
 * Usage:
 *   node mongo_export_json.js --uri "mongodb://127.0.0.1:27017/soc_chat_app" --out "D:\backups\export"
 */
const fs = require('fs');
const path = require('path');
const { MongoClient } = require('mongodb');
const { EJSON } = require('bson');

function getArg(name) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function sanitizeFilename(name) {
  return name.replace(/[<>:"/\\|?*\x00-\x1F]/g, '_');
}

function dbNameFromUri(uri) {
  try {
    const u = new URL(uri);
    const pathname = (u.pathname || '').replace(/^\//, '');
    if (pathname) return pathname;
  } catch {
    // ignore
  }
  // mongodb://... may not parse with URL() in older node when it includes options;
  // fallback: grab the last path segment before ?.
  const noQuery = uri.split('?')[0];
  const parts = noQuery.split('/');
  const last = parts[parts.length - 1];
  return last || 'soc_chat_app';
}

async function main() {
  const uri = getArg('uri') || process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/soc_chat_app';
  const outDir = getArg('out');
  if (!outDir) {
    console.error('Missing --out <directory>');
    process.exit(2);
  }

  const dbName = dbNameFromUri(uri);
  ensureDir(outDir);

  const meta = {
    uri: uri.replace(/\/\/([^@]+)@/, '//***@'), // redact user:pass if present
    dbName,
    startedAt: new Date().toISOString(),
    collections: [],
  };

  const client = new MongoClient(uri, { maxPoolSize: 2 });
  await client.connect();
  try {
    const db = client.db(dbName);
    const cols = await db.listCollections({}, { nameOnly: true }).toArray();

    for (const c of cols) {
      const colName = c.name;
      const safe = sanitizeFilename(colName);
      const filePath = path.join(outDir, `${safe}.jsonl`);

      let count = 0;
      const ws = fs.createWriteStream(filePath, { encoding: 'utf8' });
      try {
        const cursor = db.collection(colName).find({}, { batchSize: 1000 });
        for await (const doc of cursor) {
          ws.write(EJSON.stringify(doc));
          ws.write('\n');
          count += 1;
        }
      } finally {
        await new Promise(resolve => ws.end(resolve));
      }

      meta.collections.push({
        name: colName,
        file: path.basename(filePath),
        documents: count,
      });
      console.log(`Exported ${colName}: ${count} docs -> ${filePath}`);
    }

    meta.finishedAt = new Date().toISOString();
    fs.writeFileSync(path.join(outDir, 'metadata.json'), JSON.stringify(meta, null, 2), 'utf8');
  } finally {
    await client.close();
  }
}

main().catch(err => {
  console.error('Export failed:', err && err.stack ? err.stack : String(err));
  process.exit(1);
});

