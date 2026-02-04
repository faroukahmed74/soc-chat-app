# SOC Chat App – Verification Report

**Generated:** 2026-02-02  
**Project:** E:\GitHub\soc-chat-app  
**DB Path:** D:\soc-chat-data  

---

## 1. Software Versions

| Software | Status | Version/Path |
|----------|--------|--------------|
| **Node.js** | ✅ Installed | v24.13.0 |
| **npm** | ✅ Installed | 11.6.2 |
| **Git** | ✅ Installed | 2.52.0.windows.1 |
| **Docker** | ✅ Installed | 29.1.5 |
| **Flutter** | ✅ Installed | 3.35.0-0.3.pre (beta), Dart 3.9.0 |
| **ngrok** | ✅ Installed | 3.35.0 at E:\Programs\ngrok.exe |
| **Ollama** | ✅ Running | Port 11434 listening |
| **FFmpeg** | ⚠️ Not in PATH | Run `choco install ffmpeg` if needed |

---

## 2. Services – Current State

| Service | Port | Status | Notes |
|---------|------|--------|-------|
| **MongoDB** | 27017 | ✅ LISTENING | DB path: D:\soc-chat-data |
| **Ollama** | 11434 | ✅ LISTENING | AI chat models |
| **API Server** | 3003 | ❌ Not running | Start: `node server.js` in local_api_server |
| **Web Server** | 8082 | ❌ Not running | Start: `node server.js` in servers |
| **ngrok** | 4040 | ❌ Not running | Start via services manager or ngrok start |
| **FCM** | 3000 | ❌ Not running | Optional – push notifications |
| **Local Network** | 3004 | ❌ Not running | Optional |

---

## 3. Project Files & Paths

| Item | Status |
|------|--------|
| **build/web/** (Flutter web build) | ✅ Exists |
| **servers/node_modules** | ✅ Exists |
| **servers/local_api_server/node_modules** | ✅ Exists |
| **servers/local_api_server/.env** | ✅ Exists |
| **D:\soc-chat-data\MongoDB\data\db** | ✅ Exists |
| **scripts/ngrok.yml** | ✅ Exists |
| **scripts/coturn-docker-compose.yml** | ✅ Exists |

---

## 4. Configuration (.env)

- **MONGO_URI / MONGODB_URI:** mongodb://localhost:27017/soc_chat_app
- **OLLAMA_MODEL:** llama3.2:3b
- **OLLAMA_VISION_MODEL:** llava
- **Firebase:** Service account loaded (FCM initialized)

---

## 5. ngrok PATH

- **Location:** E:\Programs\ngrok.exe
- **Add to PATH:** Ensure `E:\Programs` is in system PATH so services_manager can find ngrok.
- **Config:** scripts/ngrok.yml exists (authtoken configured).

---

## 6. Summary

| Category | Result |
|----------|--------|
| Core software (Node, npm, Git, Flutter, Docker) | ✅ All installed |
| MongoDB | ✅ Running on 27017 |
| Ollama | ✅ Running on 11434 |
| Web build | ✅ build/web exists |
| Node dependencies | ✅ Installed in both servers |
| API & Web servers | ❌ Not running (start manually or via services_manager) |

---

## 7. To Run the App

1. **Start MongoDB** (if not running): `.\scripts\run\start_mongodb.bat` or MongoDB service
2. **Start API Server:** `cd servers\local_api_server && node server.js`
3. **Start Web Server:** `cd servers && node server.js`
4. **Or use Services Manager:** Run `services_manager_interactive.bat` and choose option 1

---

## 8. Optional Improvements

- Add **E:\Programs** to system PATH for ngrok
- Install **FFmpeg** (`choco install ffmpeg`) for video transcoding
- Pull Ollama models: `ollama pull llama3.2:3b` and `ollama pull llava` (per .env)
- Start **Docker Desktop** if using coturn or MongoDB via Docker
