# Web Offline Setup (Local Network Only)

This guide configures the web app to run fully offline on a local network. Other PCs on the same LAN will load all resources from the main PC without using the Internet. Mobile builds and ngrok configuration remain unchanged.

## Overview

- Web clients connect to the proxy server on the main PC (default `http://[MAIN_PC_IP]:8082`).
- The proxy forwards `\api` and `\socket.io` to the local API (`http://127.0.0.1:3003`) and serves the Flutter web build from `build/web`.
- Flutter web engine resources (CanvasKit) are hosted locally under `build/web/canvaskit/`.
- Service worker caches all web resources for fast, resilient offline use.

## Prerequisites

- Windows PC acting as the main server.
- Node.js installed (to run servers).
- MongoDB accessible to all platforms (same database for web and mobile). Set `MONGO_URI` in the API server environment.

## Steps

1) Build the Flutter web app (from project root):

```powershell
# Ensure Flutter SDK is available in PATH
flutter build web --release --web-renderer canvaskit
```

This creates `build/web/` with `index.html`, `main.dart.js`, assets, and `flutter_service_worker.js`.

2) Download CanvasKit locally (only needed once):

```powershell
# Downloads canvaskit.js and canvaskit.wasm to build/web/canvaskit/
node servers/download_canvaskit.js
```

3) Start the Local API server (MongoDB + Socket.IO):

```powershell
# From project root; configure environment as needed
$env:HOST = '0.0.0.0'
$env:PORT = '3003'
$env:MONGO_URI = 'mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin'
$env:JWT_SECRET = 'please_change_this_secret'
node servers/local_api_server/server.js
```

4) Start the Web Proxy server (serves web build and proxies API/socket):

```powershell
$env:PORT = '8082'
# API_TARGET defaults to http://127.0.0.1:3003 and usually doesn't need changing
node servers/server.js
```

5) Verify offline readiness:

- Open `http://localhost:8082/offline-status` on the main PC.
- You should see `canvasKitLocal: true`, and `indexHtml`, `mainDartJs`, and `serviceWorker` as `true`.

6) Access from other PCs on the same network:

- Navigate to `http://[MAIN_PC_IP]:8082` from other PCs.
- The app will serve all resources from the main PC and use the same MongoDB via the API proxy.

## Notes

- Web-specific configuration reads the current page origin (same-origin proxy) and does not affect mobile. Mobile continues to use ngrok as before.
- CORS for the API server is permissive for local IPs; ensure `servers/local_api_server/server.js` is running and accessible from the proxy.
- For production hardening, set a strong `JWT_SECRET` and consider tightening `ALLOWED_ORIGINS`.

## Troubleshooting

- If `canvasKitLocal` is false on `/offline-status`, re-run `node servers/download_canvaskit.js`.
- If the app fails to reach the API, confirm that `servers/local_api_server/server.js` is running and that MongoDB is accessible.
- Use `docs/LOCAL_NETWORK_SETUP.md` for more network-specific instructions.