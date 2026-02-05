# SOC Chat App – .env and Services Reference

This document lists **all app services/servers** and how they depend on `.env` so the whole app works correctly.

---

## 1. Which .env file is used where

| Location | Used by | Purpose |
|----------|---------|--------|
| **`servers/local_api_server/.env`** | Local API server and all scripts in this folder | Main app backend: MongoDB, JWT, Twilio, Ollama, uploads, FCM (optional) |
| **`servers/.env.production`** | FCM server (`fcm_server_production.js`) when run from `servers/` | Push notifications: Firebase credentials, PORT=3000 |
| **No .env** | Web proxy (`servers/server.js`), offline web (`servers/offline_web_server.js`) | They use **environment variables** only (PORT, API_TARGET), set by the batch/startup script |

---

## 2. Services that use `servers/local_api_server/.env`

These run from **`servers/local_api_server/`** and load **`.env`** in that folder (via `require('dotenv').config()` or by being started with that folder as cwd after the main server has loaded .env). For scripts run standalone (e.g. `node fix_media_urls.js`), ensure you `cd` to `servers/local_api_server` first so `.env` is loaded.

| Service / script | Key variables from .env |
|------------------|-------------------------|
| **server.js** (API server, port 3003) | MONGO_URI, JWT_SECRET, JWT_EXPIRES_IN, UPLOADS_DIR, ALLOWED_ORIGINS, PORT, HOST, TWILIO_*, CLOUD_TURN_*, OLLAMA_*, AI_*, MOBILE_BASE_URL, FIREBASE_* (optional), CF_ACCESS_* (optional), MAX_UPLOAD_MB, SOCKET_TOKEN_REFRESH_GRACE_DAYS |
| **local_network_config.js** (port 3004) | MONGO_URI, JWT_SECRET, LOCAL_NETWORK_PORT, LOCAL_NETWORK_HOST |
| **notification_server.js** (port 3001) | MONGO_URI, JWT_SECRET, NOTIFICATION_PORT, ALLOW_MONGO_FAILURE |
| **transcode_all_videos.js** | MONGO_URI, DB_NAME, MOBILE_BASE_URL |
| **fix_media_urls.js** | MONGODB_URI, MOBILE_BASE_URL |
| **fix_lastmessage_time.js** | MONGODB_URI |
| **show_fcm_tokens.js** | MONGODB_URI, FIREBASE_* (if FCM) |
| **query_fcm_tokens.js** | MONGODB_URI |
| **diagnose_fcm.js** | MONGODB_URI, FIREBASE_*, NODE_ENV |
| **check_users.js** | MONGODB_URI |
| **database_indexes.js** | MONGO_URI |
| **aiService.js** (used by server.js) | OLLAMA_*, AI_*, UPLOADS_DIR |
| **cache_service.js** (optional Redis) | REDIS_HOST, REDIS_PORT, REDIS_PASSWORD, REDIS_DB |
| **https_server.js** (optional HTTPS) | SSL_CERT_PATH, SSL_KEY_PATH, HTTPS_PORT, HOST |
| **TEST_TWILIO_CREDENTIALS.js** | TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN |
| **test_send_notification.js**, **test_fcm_both_platforms.js**, **test_fcm_logs.js** | MONGODB_URI, FIREBASE_*, NODE_ENV |

---

## 3. Variables in `servers/local_api_server/.env` (checklist)

Ensure these are set (or have acceptable defaults) so all dependent services work:

### Required for core app

- **MONGO_URI** – MongoDB connection (DB path on this server: `D:\soc-chat-data`)
- **MONGODB_URI** – Same value as MONGO_URI (used by several scripts)
- **JWT_SECRET** – Auth tokens; use same value as before reinstall if you need existing tokens to work
- **UPLOADS_DIR** – e.g. `D:\soc-chat-data\uploads`

### Optional but recommended

- **ALLOWED_ORIGINS** – CORS (e.g. `http://localhost:8080,http://localhost:8082`)
- **PORT**, **HOST** – 3003, 0.0.0.0 (batch often sets these when starting)
- **JWT_EXPIRES_IN**, **SOCKET_TOKEN_REFRESH_GRACE_DAYS**
- **MOBILE_BASE_URL** – Public/ngrok URL for media links
- **LOCAL_NETWORK_PORT**, **LOCAL_NETWORK_HOST** – For Local Network URLs service (3004)
- **MAX_UPLOAD_MB** – Upload size limit
- **DB_NAME** – e.g. `soc_chat_app` (for transcode script)

### Twilio / TURN (calls)

- **TWILIO_ACCOUNT_SID**, **TWILIO_AUTH_TOKEN**
- **CLOUD_TURN_ENABLED**, **CLOUD_TURN_URLS**, **CLOUD_TURN_USERNAME**, **CLOUD_TURN_PASSWORD**

### Ollama / AI

- **OLLAMA_HOST**, **OLLAMA_PORT**, **OLLAMA_MODEL**, **OLLAMA_VISION_MODEL**, **OLLAMA_TIMEOUT**
- **ALLOWED_ORIGINS** – Must include ngrok URL for mobile and proxy ports for web (e.g. `https://soc-chat-app.ngrok-free.app`, `http://localhost:8082`)

**AI reachability:**
- **Mobile (ngrok)**: App → `https://soc-chat-app.ngrok-free.app` → ngrok tunnel → API (3003) → Ollama (127.0.0.1:11434)
- **Web (proxy)**: App → `http://host:8082` (same origin) → proxy → API (3003) → Ollama (127.0.0.1:11434)
- **OLLAMA_MAX_CONTEXT_MESSAGES**, **OLLAMA_MAX_RESPONSE_LENGTH**, **OLLAMA_MAX_MESSAGE_LENGTH**, **OLLAMA_MAX_IMAGE_SIZE**, **OLLAMA_ALLOW_EXTERNAL_IMAGES**
- **AI_RATE_LIMIT_WINDOW**, **AI_RATE_LIMIT_MAX**, **AI_MAX_CONCURRENT_JOBS**, **AI_MAX_QUEUE**, **AI_DEBUG_LOGS**
- **OLLAMA_NUM_THREAD**, **OLLAMA_TEXT_CTX**, **OLLAMA_VISION_CTX**, **OLLAMA_NUM_PREDICT**, **OLLAMA_TEMPERATURE**, **OLLAMA_TOP_P**, **OLLAMA_TOP_K**, **OLLAMA_REPEAT_PENALTY**, **OLLAMA_REPEAT_LAST_N**

### FCM (optional – push notifications)

- **FIREBASE_TYPE**, **FIREBASE_PROJECT_ID**, **FIREBASE_PRIVATE_KEY_ID**, **FIREBASE_PRIVATE_KEY**, **FIREBASE_CLIENT_EMAIL**, **FIREBASE_CLIENT_ID**, **FIREBASE_AUTH_URI**, **FIREBASE_TOKEN_URI**, **FIREBASE_AUTH_PROVIDER_X509_CERT_URL**, **FIREBASE_CLIENT_X509_CERT_URL**

### Other optional

- **CF_ACCESS_*** – Cloudflare Access for admin routes
- **APNS_SOUND** – iOS notification sound
- **SERVER_URL** – For check_fcm_endpoint.js (e.g. http://localhost:3003)
- **NOTIFICATION_PORT**, **ALLOW_MONGO_FAILURE** – For notification_server.js
- **REDIS_*** – If using cache_service with Redis
- **SSL_CERT_PATH**, **SSL_KEY_PATH**, **HTTPS_PORT** – If using https_server.js

---

## 4. Services that do **not** use `local_api_server/.env`

| Service | Config source | What to set |
|---------|----------------|------------|
| **Web proxy** (`servers/server.js`, port 8082) | Environment only | `PORT=8082`, `API_TARGET=http://localhost:3003` (batch sets these) |
| **Offline web** (`servers/offline_web_server.js`) | Environment only | Same as above |
| **FCM server** (`servers/fcm_server_production.js`, port 3000) | **`servers/.env.production`** | Copy from `servers/env.example` or backup; set Firebase credentials, PORT=3000 |

So: **local_api_server/.env** drives the API server and all scripts in that folder. **Web server** uses only env vars set by the launcher. **FCM server** uses **servers/.env.production** (different file).

---

## 5. Quick check

1. **API and related scripts**  
   From project root:  
   `cd servers\local_api_server` then `node server.js`  
   All of the above variables for server.js and local_network_config.js come from `servers/local_api_server/.env`.

2. **Web proxy**  
   From project root:  
   `set PORT=8082 && set API_TARGET=http://localhost:3003 && node servers\server.js`  
   No .env needed; only PORT and API_TARGET.

3. **FCM server**  
   Ensure **`servers/.env.production`** exists and has Firebase and PORT=3000, then from `servers/`:  
   `node fcm_server_production.js`

4. **services_manager_interactive.bat (option 1)**  
   Starts API server (uses `local_api_server/.env`), Web server (env vars only), Local Network (uses `local_api_server/.env`), and optionally FCM (uses `servers/.env.production`). So both .env files must be correct for “all app services” to work.

---

**Summary:**  
- **One .env for the main app backend and scripts:** `servers/local_api_server/.env` (now includes MONGO_URI, MONGODB_URI, JWT_*, UPLOADS_DIR, Twilio, Ollama, MOBILE_BASE_URL, LOCAL_NETWORK_*, etc.).  
- **Separate .env for FCM:** `servers/.env.production`.  
- **Web proxy:** no .env; set PORT and API_TARGET when starting.
