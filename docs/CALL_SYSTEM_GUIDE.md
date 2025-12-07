# 📞 Call System - Services & Behavior Guide

## 🚀 Required Services

For the call system to work, you need the following services running:

### 1. **MongoDB** (Database)
- **Port**: 27017 (default)
- **Purpose**: Stores users, chats, messages, and call data
- **Status Check**: 
  ```powershell
  net start | findstr -i mongo
  # OR
  Get-Service | Where-Object {$_.Name -like "*mongo*"}
  ```

### 2. **API Server** (Main Backend)
- **Port**: 3003
- **File**: `servers/local_api_server/server.js`
- **Purpose**: 
  - Handles authentication
  - Manages chats and messages
  - **Sends call invitations via Socket.IO**
  - Handles FCM notifications
- **Start Command**:
  ```powershell
  cd servers/local_api_server
  node server.js
  # OR with environment variables:
  $env:PORT=3003; $env:HOST="0.0.0.0"; node server.js
  ```
- **Status Check**:
  ```powershell
  netstat -an | findstr ":3003"
  # OR visit: http://localhost:3003/health
  ```

### 3. **Web Server** (Proxy for Web Platform)
- **Port**: 8082
- **File**: `servers/server.js`
- **Purpose**: 
  - Serves web app (Flutter web build)
  - Proxies API requests to API server
  - Handles Socket.IO connections for web
- **Start Command**:
  ```powershell
  cd servers
  $env:PORT=8082; $env:API_TARGET="http://localhost:3003"; node server.js
  ```
- **Status Check**:
  ```powershell
  netstat -an | findstr ":8082"
  # OR visit: http://localhost:8082
  ```

### 4. **ngrok** (For Mobile Devices)
- **Port**: 4040 (web interface)
- **Purpose**: Creates public HTTPS tunnel to your local API server
- **Required For**: Android & iOS devices to connect
- **Start Command**:
  ```powershell
  ngrok http 3003
  # OR with custom domain:
  ngrok http 3003 --domain=your-domain.ngrok-free.app
  ```
- **Status Check**:
  ```powershell
  netstat -an | findstr ":4040"
  # OR visit: http://localhost:4040
  ```
- **Important**: Update `lib/config/database_config.dart` with your ngrok URL

### 5. **FCM Server** (Optional - for push notifications)
- **Port**: 3000
- **Purpose**: Sends Firebase Cloud Messaging notifications
- **Required For**: Call notifications when app is in background
- **Start Command**:
  ```powershell
  cd servers
  $env:PORT=3000; node fcm_server_production.js
  ```

## 📋 Quick Start - All Services

### Windows (PowerShell)
```powershell
# Option 1: Use services manager (if available)
.\services_manager.bat start-all

# Option 2: Manual start
# Terminal 1: MongoDB (if not running as service)
mongod --dbpath "C:\data\db"

# Terminal 2: API Server
cd servers/local_api_server
$env:PORT=3003; $env:HOST="0.0.0.0"; node server.js

# Terminal 3: Web Server
cd servers
$env:PORT=8082; $env:API_TARGET="http://localhost:3003"; node server.js

# Terminal 4: ngrok (for mobile)
ngrok http 3003
```

### Check All Services Status
```powershell
# Check MongoDB
Get-Service | Where-Object {$_.Name -like "*mongo*"}

# Check API Server (Port 3003)
netstat -an | findstr ":3003"

# Check Web Server (Port 8082)
netstat -an | findstr ":8082"

# Check ngrok (Port 4040)
netstat -an | findstr ":4040"

# Test API Server
curl http://localhost:3003/health
# OR
Invoke-WebRequest -Uri http://localhost:3003/health
```

## 🎯 Expected Behavior - Call Flow

### Scenario: User A calls User B

#### **Step 1: User A Initiates Call**
1. User A opens a chat with User B
2. User A taps **Voice Call** or **Video Call** button in the AppBar
3. **Expected**: 
   - `CallScreen` appears with "Calling..." state
   - Shows User B's name/avatar
   - Shows call type (Voice/Video)
   - Cancel button available

#### **Step 2: Call Invitation Sent**
1. `JitsiCallService.startVoiceCall()` or `startVideoCall()` is called
2. **What Happens**:
   - Generates unique room name (e.g., `chat123_voice_1234567890abc12345`)
   - Sends HTTP POST to `/api/calls/invite` on API server
   - API server:
     - Validates request
     - Emits `call_invitation` Socket.IO event to User B
     - Sends FCM notification to User B (if app is in background)
3. **Expected**: 
   - User A sees "Calling..." screen
   - No errors in console/logs

#### **Step 3: User B Receives Invitation**
1. **If User B's app is OPEN**:
   - Socket.IO receives `call_invitation` event
   - `RealtimeService.onCallInvitation()` handler fires
   - `ChatScreenMongoDB` navigates to `CallScreen`
   - **Expected**: 
     - `CallScreen` appears with **"Incoming Call"** state
     - Shows User A's name/avatar
     - Shows call type (Voice/Video)
     - **Answer** (green) and **Reject** (red) buttons

2. **If User B's app is in BACKGROUND**:
   - FCM notification is received
   - **Expected**: 
     - Push notification appears: "Incoming voice/video call from [User A]"
     - Tapping notification opens app and navigates to `CallScreen`

#### **Step 4: User B Answers**
1. User B taps **Answer** button
2. **What Happens**:
   - `CallScreen._answerCall()` is called
   - If `roomName` is provided (from invitation), calls `JitsiCallService.joinCall()`
   - Otherwise, calls `JitsiCallService.startVideoCall()` or `startVoiceCall()`
   - Jitsi Meet SDK opens with the room name
3. **Expected**: 
   - Jitsi Meet interface appears
   - User B joins the call room
   - User A (who is already in the room) sees User B join

#### **Step 5: Both Users in Call**
1. Both users are in the same Jitsi Meet room
2. **Expected**: 
   - Video/audio streams are active
   - Both users can see/hear each other
   - Call controls available (mute, camera toggle, screen share, etc.)
   - Call can be ended by either user

#### **Step 6: Call Ends**
1. Either user ends the call
2. **What Happens**:
   - `JitsiCallService.closeCall()` is called
   - Jitsi Meet closes
   - `CallScreen` navigates back to chat
3. **Expected**: 
   - Both users return to chat screen
   - No errors

## 🔍 Troubleshooting

### Issue: "Calling screen shows but no call received"

**Possible Causes:**
1. **API Server not running** - Check port 3003
2. **Socket.IO not connected** - Check if users are online
3. **ngrok not running** - Mobile devices can't reach server
4. **FCM not configured** - Background notifications won't work

**Debug Steps:**
```powershell
# 1. Check API server logs
# Look for: "📞 Call invitation from..." messages

# 2. Check Socket.IO connections
# In API server logs, look for: "🔌 User connected: [userId]"

# 3. Test call invitation endpoint manually
$token = "YOUR_AUTH_TOKEN"
$body = @{
    chatId = "CHAT_ID"
    chatName = "Test Chat"
    callerId = "USER_A_ID"
    callerName = "User A"
    roomName = "test_room_123"
    callType = "video"
    participantIds = @("USER_B_ID")
    isGroupChat = $false
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:3003/api/calls/invite" `
    -Method POST `
    -Headers @{"Authorization"="Bearer $token"; "Content-Type"="application/json"} `
    -Body $body
```

### Issue: "Socket.IO connection failed"

**Check:**
1. API server is running on port 3003
2. Web server is running on port 8082 (for web)
3. ngrok is running and URL is correct (for mobile)
4. Firewall allows connections
5. CORS is configured correctly

### Issue: "Jitsi Meet doesn't open"

**Check:**
1. `jitsi_meet` package is installed: `flutter pub get`
2. Internet connection (Jitsi uses `https://meet.jit.si`)
3. App permissions (camera, microphone)
4. Check Flutter logs for errors

### Issue: "Users can't hear/see each other"

**Check:**
1. Camera/microphone permissions granted
2. Browser permissions (for web)
3. Device permissions (for mobile)
4. Network connectivity
5. Jitsi server is accessible (`https://meet.jit.si`)

## 📱 Platform-Specific Notes

### Web
- Uses local network proxy (port 8082)
- Socket.IO connects via WebSocket
- Jitsi Meet runs in browser
- Requires HTTPS for camera/microphone (or localhost)

### Android/iOS
- Uses ngrok URL for API server
- Socket.IO connects via WebSocket through ngrok
- Jitsi Meet runs natively
- Requires app permissions for camera/microphone

## ✅ Testing Checklist

1. **Services Running**:
   - [ ] MongoDB running
   - [ ] API Server running (port 3003)
   - [ ] Web Server running (port 8082) - for web
   - [ ] ngrok running - for mobile
   - [ ] FCM Server running (optional)

2. **Users Connected**:
   - [ ] User A is logged in and online
   - [ ] User B is logged in and online
   - [ ] Both users can send/receive messages

3. **Call Test**:
   - [ ] User A can initiate call
   - [ ] User B receives call invitation
   - [ ] User B can answer call
   - [ ] Both users join Jitsi room
   - [ ] Audio/video works
   - [ ] Call can be ended

4. **Background Test**:
   - [ ] User B receives FCM notification when app is in background
   - [ ] Tapping notification opens call screen

## 🔗 Related Files

- **Call Service**: `lib/services/jitsi_call_service.dart`
- **Call Screen**: `lib/screens/call_screen.dart`
- **Chat Screen**: `lib/screens/chat_screen_mongodb.dart`
- **Realtime Service**: `lib/services/realtime_service.dart`
- **API Endpoint**: `servers/local_api_server/server.js` (line ~3197)
- **Call Types**: `lib/services/call_types.dart`

## 📝 Logs to Monitor

### API Server Logs
Look for these messages:
- `📞 Call invitation from [name] to [count] participants`
- `✅ Sent call invitation to [userId]`
- `📱 Sent FCM call notification to [userId]`
- `🔌 User connected: [userId]` (Socket.IO)

### Flutter App Logs
Look for these in debug console:
- `Voice call started: [roomName]` (JITSI_CALL_SERVICE)
- `Conference joined: [url]` (JITSI_CALL_SERVICE)
- `Received call invitation` (CHAT_SCREEN_MONGODB)

