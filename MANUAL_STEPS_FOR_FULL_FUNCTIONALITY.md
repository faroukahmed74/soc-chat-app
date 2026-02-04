# Manual Steps for Full Functionality

These steps require **you** to do them (credentials, installs, or one-time config). Everything else has been set up in the repo.

---

## 1. Web build (required for web app at :8082)

**Status:** Flutter is at **E:\flutter**. It was added to system PATH via `scripts\add_flutter_to_path.ps1`.

**If web build fails** (e.g. `flutter_webrtc` error with Dart 3.9 beta):

- Your Flutter is **3.35 beta**; the project may need **Flutter stable** for a clean web build.
- Try: `E:\flutter\bin\flutter.bat channel stable` then `E:\flutter\bin\flutter.bat upgrade`, then run the build again.
- Or install Flutter stable alongside (e.g. different folder) and use that for `flutter build web --release`.

**Do this:**

1. **Ensure Flutter is on PATH** (already done if you ran `.\scripts\add_flutter_to_path.ps1`).
   - Flutter path: **E:\flutter** (bin: `E:\flutter\bin`).
2. **Open a new terminal** and run:
   ```powershell
   cd E:\GitHub\soc-chat-app
   .\scripts\run_build_web.ps1
   ```
   Or: `E:\flutter\bin\flutter.bat build web --release`
3. After it succeeds, **build/web** will exist and the web server (port 8082) will serve the app.

---

## 2. ngrok authtoken (optional; for stable public URL)

**Status:** Authtoken added to **`scripts/ngrok.yml`** and via `ngrok config add-authtoken`. ngrok is ready to use.

---

## 3. FCM / Firebase (optional; push notifications)

**Status:** FIREBASE_* placeholders were added to `.env` and `servers/.env.production`. `servers/local_api_server/assets/service-account/` was created with a README.

**Do this (choose one):**

**Option A – API server FCM via .env**

- Edit **`servers/local_api_server/.env`** and fill in the FIREBASE_* variables (uncomment and replace with real values from Firebase Console → Project Settings → Service accounts).

**Option B – API server FCM via JSON file**

- Download the Firebase Admin SDK JSON key from Firebase Console.
- Put it in **`servers/local_api_server/assets/service-account/`** (e.g. `soc-chat-app-ca57e-firebase-adminsdk-xxxxx.json`).

**FCM server (port 3000)**

- Edit **`servers/.env.production`** and replace all placeholders (`your_private_key_id_here`, `Your private key here`, etc.) with your real Firebase credentials.

---

## 4. FFmpeg (optional; video transcoding and thumbnails)

**Status:** FFmpeg was not found. A check script was added: `scripts\check_ffmpeg.ps1`.

**Do this:**

- Install FFmpeg:
  - **Chocolatey:** `choco install ffmpeg`
  - **Manual:** https://ffmpeg.org/download.html (Windows builds), then add the `bin` folder to PATH.
- Verify: run `.\scripts\check_ffmpeg.ps1` or `ffmpeg -version`.

---

## 5. JWT_SECRET (only if restoring existing users)

**Status:** `.env` has a placeholder JWT_SECRET and a comment.

**Do this (only if you had users before reinstall):**

- Set **JWT_SECRET** in **`servers/local_api_server/.env`** to the **exact same value** you used before. Otherwise existing tokens will be invalid and users must log in again.

---

## 6. MongoDB – ECONNREFUSED 127.0.0.1:27017

**If the app shows** `connect ECONNREFUSED 127.0.0.1:27017`, MongoDB is not running or not reachable.

**On this server:** MongoDB **8.2** is installed as a Windows service but currently **crashes on start** (exception `0xC000001D` – illegal instruction). This is a known CPU/compatibility issue with some MongoDB 8.2 Windows builds.

**Do one of the following:**

1. **Start MongoDB with Docker (recommended workaround)**  
   - From project root: `.\scripts\run\start_mongodb_docker.ps1`  
   - Uses image `mongo:6.0` and your data path `D:\soc-chat-data\MongoDB\data\db`.  
   - Ensures something is listening on **localhost:27017** so the app can connect.

2. **Install MongoDB 6.0 LTS**  
   - Download: https://www.mongodb.com/try/download/community (choose 6.0, Windows).  
   - Install, then configure the service or run manually with:  
     `.\scripts\run\start_mongodb.bat`  
   - That script uses `D:\soc-chat-data\MongoDB\data\db` as dbpath.

3. **Fix the MongoDB 8.2 service**  
   - If the 8.2 service used to start, check Windows Event Viewer (Application) for the MongoDB service failure reason.  
   - Ensure the service config (`C:\Program Files\MongoDB\Server\8.2\bin\mongod.cfg`) uses a valid `dbPath` and that the account running the service has access.

After MongoDB is listening on 27017, restart the Local API Server; the app should connect.

---

## 7. MongoDB auth vs no auth

**Status:** **`.env`** is set for **no auth**: `MONGO_URI=mongodb://localhost:27017/soc_chat_app` and `MONGODB_URI=mongodb://localhost:27017/soc_chat_app`. If you later enable MongoDB auth, switch back to the auth URI in `.env`.

---

## 8. Docker + coturn (optional; self-hosted TURN)

**Status:** Docker is installed. Twilio TURN in `.env` is enough for most calls. For self-hosted TURN:

1. Edit **`scripts/coturn-docker-compose.yml`** and set **EXTERNAL_IP** (and `--external-ip` in `command`) to your server’s public IP.
2. Run: `.\scripts\start_coturn.ps1` or `docker-compose -f scripts\coturn-docker-compose.yml up -d`

---

## Firebase (google-services.json)

**Status:** **`android/app/google-services.json`** has project **soc-chat-app-ca57e** (project number 889400273440).

- **Firebase Console:** https://console.firebase.google.com/project/soc-chat-app-ca57e  
- **Check from cmd:** Run `.\scripts\check_firebase.ps1` from project root to print project info and optionally open the console. With Firebase CLI: `firebase login` then `firebase projects:list`.

---

## Quick reference

| Step | Required? | Status / Action |
|------|-----------|------------------|
| 1. Web build | Yes for web UI | Add Flutter to PATH, run `.\scripts\run_build_web.ps1` |
| 2. ngrok token | Optional | Done (in scripts/ngrok.yml and ngrok config) |
| 3. FCM | Optional | Add Firebase credentials to .env or service-account JSON |
| 4. FFmpeg | Optional | Done (Chocolatey) |
| 5. JWT_SECRET | Only if restoring | Set same value as before in .env |
| 6. MONGO_URI | Only if no auth | Done (no-auth URI in .env) |
| 7. MongoDB :27017 | Required | If ECONNREFUSED: run `.\scripts\run\start_mongodb_docker.ps1` or install MongoDB 6.0 and `.\scripts\run\start_mongodb.bat` |
| 8. Docker/coturn | Optional | Docker installed; set EXTERNAL_IP in coturn compose, run `.\scripts\start_coturn.ps1` |

After step 1 (web build), start all services (e.g. option 1 in `services_manager_interactive.bat`) and the app will have full functionality for chat, calls, and web; add the rest as needed.
