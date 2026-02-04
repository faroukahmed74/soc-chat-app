# services_manager_interactive.bat – Route Verification

Verified that all 8 services use the correct paths and run the right executables.

## Configuration

| Variable | Path | Resolves To |
|----------|------|-------------|
| PROJECT_ROOT | `%~dp0` or `E:\GitHub\soc-chat-app\` | Project root |
| API_SERVER_DIR | `%PROJECT_ROOT%servers\local_api_server` | API server directory |
| WEB_SERVER_DIR | `%PROJECT_ROOT%servers` | Web server directory |
| FCM_DIR | `%PROJECT_ROOT%servers` | FCM server directory |

---

## Service 1: MongoDB (Port 27017)

| Item | Value |
|------|-------|
| **Route** | `%PROJECT_ROOT%scripts\run\start_mongodb.bat` |
| **File** | `scripts\run\start_mongodb.bat` |
| **Status** | Exists |
| **Fallback** | `net start MongoDB` (Windows service) |
| **Data path** | `D:\soc-chat-data\MongoDB\data\db` (from start_mongodb.bat) |

---

## Service 2: Ollama AI (Port 11434)

| Item | Value |
|------|-------|
| **Route** | `ollama serve` (from PATH) |
| **Requires** | Ollama in PATH (e.g. `E:\Programs` or default install) |
| **Status** | External binary |

---

## Service 3: API Server (Port 3003)

| Item | Value |
|------|-------|
| **Route** | `%API_SERVER_DIR%\server.js` → `servers\local_api_server\server.js` |
| **Start command** | `node server.js` with `PORT=3003` `HOST=0.0.0.0` |
| **Working dir** | `servers\local_api_server` |
| **Status** | Exists |

---

## Service 4: TURN Server (coturn Docker, Port 3478)

| Item | Value |
|------|-------|
| **Route** | `%PROJECT_ROOT%scripts\coturn-docker-compose.yml` |
| **File** | `scripts\coturn-docker-compose.yml` |
| **Start command** | `docker-compose -f "…\scripts\coturn-docker-compose.yml" up -d` |
| **Container** | `soc-chat-coturn` |
| **Status** | Exists |

---

## Service 5: ngrok Tunnel (Port 4040 web UI)

| Item | Value |
|------|-------|
| **Config** | `%PROJECT_ROOT%scripts\ngrok.yml` |
| **Working dir** | `%PROJECT_ROOT%scripts` |
| **Start command** | `ngrok start --all --config=ngrok.yml` (or HTTP-only fallback) |
| **File** | `scripts\ngrok.yml` |
| **Status** | Exists |

---

## Service 6: Web Server (Port 8082)

| Item | Value |
|------|-------|
| **Route** | `%WEB_SERVER_DIR%\server.js` → `servers\server.js` |
| **Start command** | `node server.js` with `PORT=8082` `API_TARGET=http://localhost:3003` |
| **Working dir** | `servers` |
| **Status** | Exists |

---

## Service 7: Network URLs Service (Port 3004)

| Item | Value |
|------|-------|
| **Route** | `%API_SERVER_DIR%\local_network_config.js` → `servers\local_api_server\local_network_config.js` |
| **Start command** | `node local_network_config.js` |
| **Working dir** | `servers\local_api_server` |
| **Status** | Exists |

---

## Service 8: FCM Server (Port 3000)

| Item | Value |
|------|-------|
| **Route (primary)** | `%FCM_DIR%\fcm_server_production.js` → `servers\fcm_server_production.js` |
| **Route (fallback)** | `%FCM_DIR%\fcm_server.js` → `servers\fcm_server.js` |
| **Start command** | `node fcm_server_production.js` or `node fcm_server.js` with `PORT=3000` |
| **Working dir** | `servers` |
| **Status** | Both exist |

---

## STOP_ALL – Window Titles

| Service | Taskkill filter |
|---------|-----------------|
| ngrok | `taskkill /f /im ngrok.exe` |
| TURN | `docker-compose … down` |
| API Server | `WINDOWTITLE eq SOC Chat App - API Server` |
| Web Server | `WINDOWTITLE eq SOC Chat App - Web Server` |
| Network URLs | `WINDOWTITLE eq Network URLs Service` |
| FCM Server | `WINDOWTITLE eq SOC Chat App - FCM Server` |
| MongoDB | `net stop MongoDB` |

---

## Fix Applied

- **MongoDB status check**: Switched from `net start | findstr mongo` to `netstat :27017 LISTENING` so MongoDB started via `start_mongodb.bat` is detected correctly.

---

## Summary

All 8 services use the correct paths and commands. File existence has been verified.
