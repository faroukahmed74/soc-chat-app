# Build Release APK and Start Servers Guide

## 🚀 Quick Start

### Step 1: Start All Required Servers

**Option A: Use the Interactive Services Manager (Recommended)**
```powershell
.\services_manager_interactive.bat
# Select option 1: "Start All Services"
```

**Option B: Start Services Manually**

Run these commands in separate terminals:

#### Terminal 1: MongoDB
```powershell
net start MongoDB
```

#### Terminal 2: API Server (Port 3003)
```powershell
cd servers\local_api_server
$env:PORT=3003; $env:HOST="0.0.0.0"; node server.js
```

#### Terminal 3: coturn TURN Server (Docker)
```powershell
cd scripts
docker-compose -f coturn-docker-compose.yml up -d
```

#### Terminal 4: ngrok Tunnel
```powershell
cd scripts
# If you have ngrok.yml config:
ngrok start --all --config=ngrok.yml

# OR if no config:
ngrok http 3003 --domain=soc-chat-app.ngrok-free.app
```

#### Terminal 5: Web Server (Port 8082) - Optional (only for web platform)
```powershell
cd servers
$env:PORT=8082; $env:API_TARGET="http://localhost:3003"; node server.js
```

### Step 2: Verify Services Are Running

```powershell
# Check MongoDB
Get-Service | Where-Object {$_.Name -like "*mongo*"}

# Check API Server (port 3003)
netstat -an | findstr ":3003"

# Check coturn (Docker)
docker ps | findstr coturn

# Check ngrok (port 4040)
netstat -an | findstr ":4040"

# Check Web Server (port 8082) - optional
netstat -an | findstr ":8082"
```

Or use the check script:
```powershell
.\scripts\check_services.ps1
```

### Step 3: Build Release APK

#### Prerequisites
1. **Flutter SDK** installed and in PATH
2. **Android SDK** configured
3. **Java JDK** installed
4. **Signing key** configured (for release builds)

#### Build Commands

**Option 1: Build Release APK (Recommended)**
```powershell
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# APK will be at: build\app\outputs\flutter-apk\app-release.apk
```

**Option 2: Build Release APK with Specific Build Number**
```powershell
flutter build apk --release --build-number=27 --build-name=1.0.27
```

**Option 3: Build Split APKs (for smaller file size)**
```powershell
flutter build apk --release --split-per-abi

# Creates separate APKs for:
# - build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
# - build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
# - build\app\outputs\flutter-apk\app-x86_64-release.apk
```

**Option 4: Build App Bundle (for Google Play Store)**
```powershell
flutter build appbundle --release

# AAB will be at: build\app\outputs\bundle\release\app-release.aab
```

### Step 4: Install APK on Devices

#### Method 1: Using ADB (Android Debug Bridge)
```powershell
# Connect device via USB and enable USB debugging
# Then install:
adb install build\app\outputs\flutter-apk\app-release.apk

# Or for split APKs (use the appropriate one for your device):
adb install build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

#### Method 2: Transfer via File Sharing
1. Copy APK to device (via email, cloud storage, etc.)
2. Enable "Install from Unknown Sources" on device
3. Open APK file and install

#### Method 3: Using ADB Wireless (if on same network)
```powershell
# On device: Enable Wireless debugging
# Connect via ADB:
adb connect <device-ip>:5555
adb install build\app\outputs\flutter-apk\app-release.apk
```

## 📋 Required Servers Summary

### Essential Servers (Must Be Running)

1. **MongoDB** (Port 27017)
   - Database for all app data
   - **Status**: Must be running

2. **API Server** (Port 3003)
   - Backend API + Socket.IO for real-time communication
   - Handles call invitations
   - **Status**: Must be running

3. **coturn TURN Server** (Port 3478)
   - Required for cross-network calls
   - Media relay for WebRTC
   - **Status**: Must be running for cross-network calls

4. **ngrok Tunnel** (Port 4040)
   - Public HTTPS tunnel for mobile devices
   - Required for Android/iOS to connect
   - **Status**: Must be running for mobile devices

### Optional Servers

5. **Web Server** (Port 8082)
   - Only needed for web platform testing
   - **Status**: Optional (not needed for mobile APK testing)

## 🔍 Verify Server Configuration

### Check ngrok URL
After starting ngrok, get the public URL:
```powershell
# Visit: http://localhost:4040/api/tunnels
# Or check ngrok web interface: http://localhost:4040
```

Update `lib/config/database_config.dart` with the ngrok URL if needed.

### Check TURN Server
Verify coturn is accessible:
```powershell
docker logs soc-chat-coturn
# Should see: "IPv4. UDP listener opened on: 0.0.0.0:3478"
```

## 🧪 Testing the Fix

After building and installing APK on both devices:

1. **Test Same-Network Call**:
   - Both devices on same WiFi
   - Make a call
   - Should see/hear each other ✅

2. **Test Cross-Network Call**:
   - Device 1 on WiFi
   - Device 2 on mobile data (different network)
   - Make a call
   - Should see/hear each other ✅ (with the fix)

3. **Check Logs**:
   - Use `adb logcat` to see device logs
   - Look for:
     - `[ICE_CONNECTION] ✅✅✅ Connection established`
     - `[ICE_CONNECTION] Getting receivers to create remote stream...`
     - `[ICE_CONNECTION] Created stream with X audio and Y video tracks`
     - `[CALL_SCREEN] onRemoteStream callback triggered`

## 🐛 Troubleshooting

### Issue: APK Build Fails

**Solution**:
```powershell
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### Issue: Services Not Starting

**Check**:
- MongoDB service: `Get-Service MongoDB`
- Node.js installed: `node --version`
- Docker running: `docker ps`
- Ports not in use: `netstat -an | findstr ":3003"`

### Issue: APK Installation Fails

**Solutions**:
- Enable "Install from Unknown Sources" on device
- Uninstall previous version first: `adb uninstall com.faroukahmed74.socchatapp`
- Check device storage space
- Use `adb install -r` to replace existing app

### Issue: Devices Can't Connect

**Check**:
- ngrok is running and accessible
- ngrok URL is correct in app config
- API server is running on port 3003
- Firewall allows connections

## 📝 Notes

- **Version**: Current version is `1.0.26+26` (from pubspec.yaml)
- **APK Size**: Release APK is typically 30-50 MB
- **Split APKs**: Use split APKs for smaller file sizes (15-25 MB each)
- **Signing**: Release APKs are signed with your keystore (configured in `android/app/build.gradle.kts`)

## ✅ Quick Checklist

Before testing:
- [ ] MongoDB running
- [ ] API Server running (port 3003)
- [ ] coturn TURN server running (Docker)
- [ ] ngrok tunnel running
- [ ] APK built successfully
- [ ] APK installed on both devices
- [ ] Devices can connect to server (test login/chat first)
- [ ] Both devices have internet connection

