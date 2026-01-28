## SOC Chat App — Disaster Recovery (Rebuild) Requirements

**Goal**: if this PC/server is damaged or down, this document lists everything you need (services + software + versions) to bring SOC Chat App back up on a new machine.

**Last updated**: 2026-01-28

---

## What you need to run (production/server)

### Required services (must be running)

- **MongoDB** (database)
  - **Minimum**: **4.4+** (per repo docs)
  - **Recommended**: 6.x/7.x
  - **Default port**: **27017**
- **SOC Local API Server** (Node/Express)
  - **File**: `servers/local_api_server/server.js`
  - **Port**: **3003**
- **Ollama** (local AI server) — *only if you use AI chat*
  - **Tested version (this server)**: **0.15.2**
  - **Default port**: **11434**
  - **Models installed on this server** (example):
    - **Text**: `llama3.2:3b` (current), `llama3.2:1b` (optional smaller)
    - **Vision**: `llava:latest`

### Optional services (only if you use these features)

- **Web Proxy / Offline web server** (serves `build/web` and proxies `/api`)
  - **File**: `servers/server.js` (and/or `servers/offline_web_server.js`)
  - **Port**: **8082**
- **FCM Server (push notifications)** (Node/Express)
  - **File**: `servers/fcm_server_production.js`
  - **Port**: **3000**
  - **Node deps live in**: `servers/package.json`
- **ngrok** (public tunnel for mobile testing / external access)
  - **Tested version (this server)**: **3.22.1**
  - **Ports**: tunnel to **3003**, ngrok admin UI **4040**
- **FFmpeg** (video transcoding for web playback)
  - Install on the server that runs `local_api_server`.
  - Verify with `ffmpeg -version`.

---

## Software required (with versions)

### Source control

- **Git**
  - **Tested version (this server)**: **2.45.1.windows.1**

### Backend runtime

- **Node.js**
  - **Tested version (this server)**: **v22.20.0**
  - **Minimum (servers)**: `>=18.0.0` (from `servers/package.json`)
  - **Cloud Functions engine**: **Node 18** (from `functions/package.json`)
- **npm**
  - **Tested version (this server)**: **10.9.3**
  - **Minimum**: `>=9.0.0` (from `servers/package.json`)

### AI runtime (optional)

- **Ollama**
  - **Tested version (this server)**: **0.15.2**
  - Verify with: `ollama --version`

### Mobile/Web build tools (only if you rebuild the app)

- **Flutter SDK**
  - **Installed version (this server)**: **Flutter 3.35.3 (stable)**, **DevTools 2.48.0**
  - Verify with: `flutter --version`
- **Dart SDK**
  - **Installed version (this server)**: **Dart 3.9.2 (stable)**
  - **Project requirement**: Dart `^3.9.0` (from `pubspec.yaml`)
  - Verify with: `dart --version`
- **Android build**
  - **Gradle wrapper**: **8.12** (from `android/gradle/wrapper/gradle-wrapper.properties`)
  - **Google services Gradle plugin**: **4.4.1** (from `android/build.gradle.kts`)
  - **NDK**: **27.0.12077973** (from `android/app/build.gradle.kts`)
  - Note: modern Gradle versions typically require **JDK 17+** for building Android apps.
- **iOS build** (macOS only)
  - **CocoaPods dependencies** are pinned in `ios/Podfile.lock`
  - Verify with: `pod --version`, `xcodebuild -version`

---

## Ports used (firewall / router)

| Component | Default port | Notes |
|---|---:|---|
| Local API server | 3003 | main backend |
| MongoDB | 27017 | database |
| Ollama | 11434 | AI (optional) |
| Web proxy | 8082 | web access (optional) |
| FCM server | 3000 | push notifications (optional) |
| ngrok admin UI | 4040 | optional |
| Local network URLs service | 3004 | optional (see scripts) |

---

## Dependencies pinned in this repo (do not “guess versions”)

- **Node server dependencies**: `servers/package.json` + **exact versions** in `servers/package-lock.json`
- **Firebase functions dependencies**: `functions/package.json` (engine Node 18) + `functions/package-lock.json` (if present)
- **Flutter/Dart dependencies**: **exact versions** in `pubspec.lock`
- **Android build tooling**: `android/gradle/wrapper/gradle-wrapper.properties`, `android/build.gradle.kts`, `android/app/build.gradle.kts`
- **iOS pods**: **exact versions** in `ios/Podfile.lock`

---

## “Must backup” items (to rebuild on a new server)

### Data (most important)

- **MongoDB database**
  - Back up using `mongodump`/`mongorestore` (or your Mongo hosting provider backup).
- **Uploaded media directory**
  - Default: `servers/local_api_server/uploads` (controlled by `UPLOADS_DIR` in `.env`)

### Secrets & credentials (never commit to git)

- `servers/local_api_server/.env` (JWT secret, DB credentials, Twilio, AI tuning, etc.)
- `servers/.env.production` (FCM server secrets, Firebase private key, etc.)
- Firebase Admin service account JSON / credentials (wherever you store it)
- **Android release signing**:
  - `android/key.properties` + the `.jks` keystore it references
- **iOS signing / APNs** (not stored in repo):
  - Apple developer certificates + APNs auth key / provisioning profiles
- ngrok authtoken / reserved domain settings (if used)

---

## Quick verification commands (new server)

### Backend

```powershell
node -v
npm -v
git --version
```

### Ollama (optional)

```powershell
ollama --version
ollama list
```

### API health

```powershell
curl.exe http://127.0.0.1:3003/api/health
```

### Flutter (only if rebuilding apps)

```powershell
flutter --version
dart --version
```

---

## Startup helpers already in this repo

- Service manager instructions exist in `All Services.txt` and `scripts/STARTUP_SERVICES_README.md`
- Common startup order: MongoDB → API server (3003) → web proxy (8082) → ngrok (optional) → FCM server (optional)

