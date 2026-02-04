# SOC Chat App — Required Services and Software Versions

**Purpose**: After reinstalling Windows Server (or moving to a new PC), use this list to install and verify everything needed to run the app.  
**DB path on this server**: `D:\soc-chat-data` (MongoDB data: `D:\soc-chat-data\MongoDB\data\db`).

**Last updated**: 2026-02-01

---

## Required services (must be running)

| Service | Port | Notes |
|--------|------|--------|
| **MongoDB** | 27017 | DB path: `D:\soc-chat-data\MongoDB\data\db`; log: `D:\soc-chat-data\MongoDB\log` |
| **SOC Local API Server** | 3003 | `servers/local_api_server/server.js` |

## Optional services (only if you use these features)

| Service | Port | Notes |
|--------|------|--------|
| Web proxy / offline web | 8082 | `servers/server.js` or `servers/offline_web_server.js` |
| FCM (push notifications) | 3000 | `servers/fcm_server_production.js` |
| ngrok | 4040 (admin UI) | Tunnel to 3003; e.g. 3.22.1 |
| Ollama (AI chat) | 11434 | Tested: 0.15.2; models e.g. `llama3.2:3b`, `llava:latest` |
| Local network URLs | 3004 | `servers/local_api_server/local_network_config.js` |
| FFmpeg | — | For video transcoding on the API server host |

---

## Software required (with versions)

### Core (required to run the app)

| Software | Minimum / tested | Verify with |
|----------|-------------------|------------|
| **Git** | 2.45+ | `git --version` |
| **Node.js** | ≥18 (tested 22.20.0) | `node -v` |
| **npm** | ≥9 (tested 10.9.3) | `npm -v` |
| **MongoDB** | 4.4+ (6.x/7.x recommended) | Service listening on 27017; dbpath `D:\soc-chat-data\MongoDB\data\db` |

### Optional (only if you use these features)

| Software | Tested | Verify with |
|----------|--------|------------|
| **Ollama** | 0.15.2 | `ollama --version`, `ollama list` |
| **Docker** | 29.x | `docker --version` (e.g. for coturn) |
| **Flutter** | 3.35+ | `flutter --version` (to rebuild app) |
| **Dart** | ^3.9.0 | `dart --version` |
| **FFmpeg** | — | `ffmpeg -version` |
| **ngrok** | 3.22.1 | `ngrok version` |

---

## Data paths (this server)

| What | Path |
|------|------|
| MongoDB data | `D:\soc-chat-data\MongoDB\data\db` |
| MongoDB logs | `D:\soc-chat-data\MongoDB\log` |
| Uploads / media | `D:\soc-chat-data\uploads` |

Ensure these directories exist. If you restore from backup, copy MongoDB dbPath (while MongoDB is stopped) and uploads into these locations.

---

## Quick verification commands

```powershell
# Core
node -v
npm -v
git --version

# MongoDB listening and API health
curl.exe http://127.0.0.1:3003/health
# Or run: .\check_services.bat

# Optional
ollama --version
ollama list
ffmpeg -version
```

---

## Startup order

1. MongoDB (service or `scripts\run\start_mongodb.bat` with dbpath `D:\soc-chat-data\MongoDB\data\db`)
2. API server (port 3003)
3. Web proxy (8082) if used
4. ngrok / FCM / others if used

Use `scripts\verify_all_required.ps1` to check that all required and optional components are installed and (where applicable) running.
