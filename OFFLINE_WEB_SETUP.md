# 🌐 Complete Offline Web Setup Guide

## Overview

This guide sets up a **complete offline web version** of the SOC Chat App that:
- ✅ Serves all Flutter web assets locally (no internet required)
- ✅ Proxies all API requests to local MongoDB server
- ✅ Downloads and caches all external dependencies (CanvasKit, etc.)
- ✅ Works completely offline on local network (IPv4:8082)
- ✅ All frontend and backend assets fetched from PC server

---

## 🚀 Quick Start

### 1. Run Setup Script (One-time)

```powershell
.\servers\setup_offline_web.ps1
```

This will:
- Build the Flutter web app
- Download all offline assets (CanvasKit, etc.)
- Verify all assets are present

### 2. Start API Server (MongoDB)

```powershell
# In a separate terminal
$env:PORT = '3003'
$env:MONGO_URI = 'mongodb://localhost:27017/soc_chat_app'
$env:JWT_SECRET = 'your_jwt_secret'
node servers\local_api_server\server.js
```

### 3. Start Offline Web Server

```powershell
.\servers\start_offline_web.ps1
```

Or manually:
```powershell
node servers\offline_web_server.js
```

### 4. Access the App

- **Local:** `http://localhost:8082`
- **Network:** `http://[YOUR_IPV4]:8082`

---

## 📋 Detailed Setup

### Prerequisites

- ✅ Node.js 18+ installed
- ✅ Flutter SDK installed
- ✅ MongoDB running locally
- ✅ API server running on port 3003

### Step-by-Step Setup

#### Step 1: Install Dependencies

```powershell
cd servers
npm install
cd ..
```

#### Step 2: Build Flutter Web App

```powershell
flutter clean
flutter pub get
flutter build web --base-href "/" --release
```

#### Step 3: Download Offline Assets

```powershell
node servers\download_all_assets.js
```

This downloads:
- CanvasKit JavaScript files
- CanvasKit WebAssembly files
- All Flutter engine assets

#### Step 4: Verify Setup

```powershell
node servers\verify_offline_setup.js
```

This checks:
- ✅ All assets are present
- ✅ API/MongoDB connection works
- ✅ Web server is ready

---

## 🏗️ Architecture

### Server Structure

```
servers/
├── offline_web_server.js      # Main proxy server (port 8082)
├── download_all_assets.js     # Downloads offline assets
├── verify_offline_setup.js    # Verification script
├── setup_offline_web.ps1      # Complete setup script
└── start_offline_web.ps1      # Start server script

build/web/                     # Flutter web build
├── index.html
├── main.dart.js
├── flutter.js
├── canvaskit/                 # Offline CanvasKit files
│   ├── canvaskit.js
│   ├── canvaskit.wasm
│   └── ...
└── assets/                    # App assets
    ├── fonts/
    ├── logo/
    └── notification_sounds/
```

### Request Flow

```
Browser (http://[IP]:8082)
    ↓
Offline Web Server (port 8082)
    ├── / → Serves Flutter web app (build/web/)
    ├── /api/* → Proxies to API Server (port 3003)
    ├── /socket.io → Proxies WebSocket to API Server
    ├── /uploads/* → Proxies media files
    └── /canvaskit/* → Serves local CanvasKit files
        ↓
API Server (port 3003)
    └── MongoDB (localhost:27017)
```

---

## ✅ Verification

### Check Offline Assets

Visit: `http://localhost:8082/offline-status`

Response:
```json
{
  "ok": true,
  "offline": true,
  "checks": {
    "buildDir": true,
    "indexHtml": true,
    "mainDartJs": true,
    "canvaskitJs": true,
    "canvaskitWasm": true
  }
}
```

### Check API Connection

Visit: `http://localhost:8082/api-connection-test`

Response:
```json
{
  "ok": true,
  "statusCode": 200,
  "apiTarget": "http://127.0.0.1:3003"
}
```

### Run Full Verification

```powershell
node servers\verify_offline_setup.js
```

---

## 🔧 Configuration

### Environment Variables

**Offline Web Server:**
- `PORT` - Web server port (default: 8082)
- `API_TARGET` - API server URL (default: http://127.0.0.1:3003)

**API Server:**
- `PORT` - API server port (default: 3003)
- `MONGO_URI` - MongoDB connection string
- `JWT_SECRET` - JWT secret for authentication

### Example Configuration

```powershell
# Start API server
$env:PORT = '3003'
$env:MONGO_URI = 'mongodb://admin:password@localhost:27017/soc_chat_app?authSource=admin'
$env:JWT_SECRET = 'your_secret_key'
node servers\local_api_server\server.js

# Start web server
$env:PORT = '8082'
$env:API_TARGET = 'http://127.0.0.1:3003'
node servers\offline_web_server.js
```

---

## 🌐 Network Access

### Local Network Access

The server binds to `0.0.0.0`, making it accessible from:
- **Localhost:** `http://localhost:8082`
- **Local Network:** `http://[YOUR_IPV4]:8082`

### Find Your IP Address

**Windows:**
```powershell
ipconfig | findstr IPv4
```

**Example output:**
```
IPv4 Address. . . . . . . . . . . : 192.168.1.100
```

Access from other devices: `http://192.168.1.100:8082`

---

## 📦 Offline Assets

### What's Downloaded

All assets are stored in `build/web/`:

- **Flutter Engine:**
  - `main.dart.js` - Compiled Dart code
  - `flutter.js` - Flutter loader
  - `flutter_service_worker.js` - Service worker

- **CanvasKit (Offline):**
  - `canvaskit/canvaskit.js`
  - `canvaskit/canvaskit.wasm`
  - `canvaskit/skwasm.js`
  - `canvaskit/skwasm.wasm`
  - `canvaskit/skwasm_heavy.js`
  - `canvaskit/skwasm_heavy.wasm`

- **App Assets:**
  - Fonts (Roboto, NotoSansArabic, etc.)
  - Images (logo, icons)
  - Audio (notification sounds)

### Re-download Assets

If assets are missing or corrupted:

```powershell
node servers\download_all_assets.js
```

---

## 🔍 Troubleshooting

### Issue: "Web build not found"

**Solution:**
```powershell
flutter build web --base-href "/" --release
```

### Issue: "API server not responding"

**Solution:**
1. Check API server is running: `http://localhost:3003/api/health`
2. Verify MongoDB is running
3. Check API_TARGET environment variable

### Issue: "CanvasKit files missing"

**Solution:**
```powershell
node servers\download_all_assets.js
```

### Issue: "Cannot access from network"

**Solution:**
1. Check Windows Firewall allows port 8082
2. Verify server binds to `0.0.0.0` (not just `127.0.0.1`)
3. Check network IP address is correct

### Issue: "MongoDB connection failed"

**Solution:**
1. Verify MongoDB is running: `mongosh` or `mongo`
2. Check MONGO_URI is correct
3. Verify MongoDB is accessible from API server

---

## ✅ Verification Checklist

Before using offline mode, verify:

- [ ] Flutter web build exists (`build/web/index.html`)
- [ ] All CanvasKit files downloaded (`build/web/canvaskit/`)
- [ ] API server is running (`http://localhost:3003/api/health`)
- [ ] MongoDB is running and accessible
- [ ] Web server is running (`http://localhost:8082/offline-status`)
- [ ] Assets status shows all OK
- [ ] API connection test passes
- [ ] Can access from network devices

---

## 🎯 Summary

**Complete Offline Setup Includes:**

1. ✅ **Flutter Web Build** - All app code bundled locally
2. ✅ **CanvasKit Assets** - All Flutter engine files downloaded
3. ✅ **Proxy Server** - Serves web app and proxies API requests
4. ✅ **API Server** - Connects to MongoDB locally
5. ✅ **Service Worker** - Caches all assets for offline use
6. ✅ **Network Access** - Accessible from local network devices

**Result:** The web app works **completely offline** - no internet required after initial setup!

---

## 📞 Support

If you encounter issues:

1. Run verification: `node servers\verify_offline_setup.js`
2. Check server logs for errors
3. Verify all prerequisites are met
4. Check firewall/network settings

