// Admin JWT generator compatible with server (HS256)
// Discovers secret via CLI arg, env var, or .env file

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function base64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signHS256(secret, data) {
  const h = crypto.createHmac('sha256', Buffer.from(secret, 'utf8'));
  h.update(data);
  return base64url(h.digest());
}

function parseArg(name, def = undefined) {
  const prefix = `--${name}=`;
  const arg = process.argv.find(a => a.startsWith(prefix));
  if (arg) return arg.slice(prefix.length);
  return def;
}

function getSecret() {
  // 1) CLI arg
  const argSecret = parseArg('secret');
  if (argSecret) return argSecret;
  // 2) Env var
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET;
  // 3) .env file (repo root)
  try {
    const envPath = path.resolve(__dirname, '..', '.env');
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, 'utf8');
      const line = content.split(/\r?\n/).find(l => l.startsWith('JWT_SECRET='));
      if (line) return line.split('=')[1].trim();
    }
  } catch (_) {}
  // 4) Fallback (will likely not verify on server)
  return 'your_jwt_secret_here';
}

const secret = getSecret();
const id = parseArg('id') || 'admin-tool';
const email = parseArg('email') || 'admin@example.com';
const displayName = parseArg('name') || 'Admin';
const expDaysRaw = parseArg('expDays');
const expDays = expDaysRaw ? parseInt(expDaysRaw, 10) : 7;

const nowSec = Math.floor(Date.now() / 1000);
const payload = {
  id,
  email,
  displayName,
  role: 'admin',
  iat: nowSec,
  exp: nowSec + expDays * 24 * 60 * 60,
};

const header = { alg: 'HS256', typ: 'JWT' };
const encodedHeader = base64url(JSON.stringify(header));
const encodedPayload = base64url(JSON.stringify(payload));
const signingInput = `${encodedHeader}.${encodedPayload}`;
const signature = signHS256(secret, signingInput);
const token = `${encodedHeader}.${encodedPayload}.${signature}`;

console.log(token);