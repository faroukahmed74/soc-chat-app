# SOC Chat App — What’s Needed for Full Functionality

Use this checklist so the app has **full functionality** after a reinstall or new server.

**Last updated**: 2026-02-01

---

## Already in place (from earlier setup)

| Item | Status |
|------|--------|
| MongoDB (port 27017, dbpath `D:\soc-chat-data`) | ✅ Configured / running |
| Node.js, npm, Git | ✅ Installed |
| API server deps (`servers`, `local_api_server`) | ✅ `npm install` done |
| `servers/local_api_server/.env` | ✅ Present with MONGO_URI, JWT, Twilio, Ollama, UPLOADS_DIR, etc. |
| Data paths `D:\soc-chat-data` (MongoDB, uploads) | ✅ Created |
| ngrok in PATH (E:\Programs) | ✅ Added |
| services_manager_interactive.bat | ✅ Fixed (start /D, paths) |
| Ollama (optional) | ✅ Installed / running |

---

## Missing or to verify for full functionality

### 1. Web app build (required for web at :8082)

**Issue:** The web proxy (`servers/server.js`) serves the app from **`build/web`**. That folder does **not** exist until you build the Flutter web app.

**Effect without it:** Opening http://localhost:8082 returns 404 or empty page; web chat does not work.

**Fix:**

1. Add **Flutter** to PATH (e.g. extract to `E:\Programs\flutter` and add `E:\Programs\flutter\bin` to PATH).
2. Run:
   ```powershell
   cd E:\GitHub\soc-chat-app
   .\scripts\run_build_web.ps1
   ```
   Or: `flutter build web --release`
3. This creates `build/web`. Then start the web server (e.g. option 1 in `services_manager_interactive.bat`).
4. See **MANUAL_STEPS_FOR_FULL_FUNCTIONALITY.md** for detailed Flutter PATH and build steps.

---

### 2. ngrok config for stable URL (optional but recommended for mobile)

**Issue:** **`scripts/ngrok.yml`** does not exist in the project root. The batch then starts ngrok in “HTTP only” mode (no config file).

**Effect without it:** Mobile can still use the API if you run `ngrok http 3003 --domain=...` manually or the batch runs it; but you won’t have a single config file for API + TURN tunnels.

**Fix:**

- Add **`scripts/ngrok.yml`** (e.g. copy from `soc-chat-app\scripts\ngrok.yml` if you have it, or use the template from `scripts\start_ngrok_with_turn.ps1`).
- Set your **ngrok authtoken** and **reserved domain** (e.g. `soc-chat-app.ngrok-free.app`) in that file.

---

### 3. FCM / push notifications (optional)

**Issue:**

- **API server (port 3003)** can send FCM if either:
  - **FIREBASE_*** variables are set in `servers/local_api_server/.env`, or  
  - A Firebase service account JSON file exists under `servers/local_api_server/assets/service-account/` or `servers/assets/service-account/`.
- **FCM server (port 3000)** uses **`servers/.env.production`**. That file exists but has **placeholder** values (`your_private_key_id_here`, etc.).

**Effect without it:** Chat and calls work; push notifications (background/missed call, etc.) do not.

**Fix:**

- For **API server FCM**:  
  - Either add **FIREBASE_TYPE, FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL**, etc. to `servers/local_api_server/.env`, or  
  - Put your Firebase Admin SDK JSON key in e.g. `servers/local_api_server/assets/service-account/` and ensure the code path that loads it can find it.
- For **FCM server (port 3000)**:  
  - Replace placeholders in **`servers/.env.production`** with real Firebase credentials and any other production settings.

---

### 4. FFmpeg (optional – video transcoding and thumbnails)

**Issue:** Video transcoding and video thumbnails use **FFmpeg**. If FFmpeg is not installed or not in PATH, those features are disabled (uploads still work; no transcoding/thumbnails).

**Effect without it:** Video messages work; no automatic transcoding for web playback and no video thumbnails.

**Fix:**

- Install FFmpeg and add it to PATH.
- Check: `ffmpeg -version`

---

### 5. TURN server (optional – calls across strict networks)

**Issue:**  
- **Twilio (cloud) TURN** is configured in `.env` (TWILIO_*, CLOUD_TURN_*). That is enough for most calls.  
- **Self-hosted TURN** uses **Docker** and **`scripts/coturn-docker-compose.yml`**. Docker was not installed on this server earlier.

**Effect without it:** With Twilio TURN in .env, voice/video calls work for most users. Self-hosted TURN is only needed if you want a backup or no cloud dependency.

**Fix (only if you want self-hosted TURN):**

- Install Docker.
- Ensure **`scripts/coturn-docker-compose.yml`** is present (it is in the repo).
- Start coturn via the batch (option 1) or:  
  `docker-compose -f scripts\coturn-docker-compose.yml up -d`

---

### 6. JWT_SECRET (important if you had users before reinstall)

**Issue:** `JWT_SECRET` in `servers/local_api_server/.env` was set to a placeholder. If you had users and tokens **before** the reinstall, old tokens will be invalid unless you use the **same** secret as before.

**Effect without it:** New install: fine. Restore: existing users may need to log in again; old tokens invalid.

**Fix:** If you know the previous JWT secret, set that same value for **JWT_SECRET** in `servers/local_api_server/.env`. Otherwise keep a strong random secret and accept that existing tokens are invalid.

---

### 7. MongoDB auth vs no auth

**Issue:** `.env` uses **MONGO_URI** with auth:  
`mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin`

If your MongoDB is running **without** authorization (e.g. only `mongod --dbpath D:\soc-chat-data\...`), this URI will fail to connect.

**Fix:**  
- If MongoDB has **no auth**: in `.env` set  
  `MONGO_URI=mongodb://localhost:27017/soc_chat_app`  
  (and same for **MONGODB_URI** if present).  
- If MongoDB has auth: ensure the user/password in MONGO_URI match your MongoDB setup (e.g. admin user created by setup_mongodb.ps1).

---

## Summary: “Full functionality” checklist

| # | Item | Required? | Status / action |
|---|------|-----------|------------------|
| 1 | **build/web** (Flutter web build) | Yes for web app | ❌ Run `flutter build web --release` |
| 2 | **scripts/ngrok.yml** + authtoken/domain | Optional (mobile/stable URL) | ❌ Add file + configure |
| 3 | **FCM** (Firebase in .env or JSON; servers/.env.production) | Optional (push) | ⚠️ Replace placeholders / add credentials |
| 4 | **FFmpeg** in PATH | Optional (video transcode/thumbnails) | ⚠️ Verify: `ffmpeg -version` |
| 5 | **Docker + coturn** | Optional (self-hosted TURN) | ⚠️ Install Docker if needed |
| 6 | **JWT_SECRET** same as before | Only if restoring users/tokens | ⚠️ Set in .env if you have old secret |
| 7 | **MONGO_URI** matches MongoDB (auth vs no auth) | Yes for DB | ⚠️ Adjust .env if MongoDB has no auth |

---

## Minimal “everything works” set

- MongoDB running, MONGO_URI correct in `.env`.
- API server (3003) and Web server (8082) running.
- **build/web** present (so the web app loads at :8082).
- Twilio/CLOUD_TURN_* in `.env` (for calls).

Then: chat, login, calls, and web app work. Add FCM, FFmpeg, ngrok config, and/or Docker TURN as needed for push, video transcoding, mobile access, and self-hosted TURN.
