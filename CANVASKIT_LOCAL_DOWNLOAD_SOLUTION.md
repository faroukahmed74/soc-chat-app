# CanvasKit Local Server Download Solution

## Problem
The local network PC (`160.2.1.18`) cannot access Google's CDN to download CanvasKit, causing persistent loading screen.

## Solution
Download CanvasKit files from Google's CDN and serve them from your local server.

## Steps on Your Main PC Server:

### 1. Pull Latest Code
```bash
git pull origin main
```

### 2. Build Web App First (if not already done)
```bash
flutter build web --release
```

### 3. Run the Download Script
```bash
bash servers/download_canvaskit.sh
```

This will download CanvasKit files to `build/web/canvaskit/` directory.

### 4. Restart Services
```bash
services_manager_interactive.bat
# Choose option 3 (Restart All Services)
```

## What This Does
- Downloads CanvasKit from Google's CDN (while server has internet)
- Stores files in `build/web/canvaskit/`
- Web server serves these files to local PCs
- PCs on `160.2.1.18` network can download from server (no internet needed)
- App loads successfully on both network IPs

## Files Downloaded
- `build/web/canvaskit/canvaskit.js`
- `build/web/canvaskit/canvaskit.wasm`
- `build/web/canvaskit/chromium/canvaskit.js`

## Testing
1. Start services with `services_manager_interactive.bat`
2. Access from local network PC: `http://160.2.1.18:8082`
3. Check browser console (F12) - should NOT see ERR_NAME_NOT_RESOLVED
4. App should load successfully

## Alternative: Manual Download
If the script doesn't work, manually download:

```bash
# Windows (using PowerShell or Git Bash)
cd build/web/canvaskit
curl -L "https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.js" -o canvaskit.js
curl -L "https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.wasm" -o canvaskit.wasm
```

Then restart services.

