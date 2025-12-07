# 📞 Call System - Quick Reference

## ✅ Current Status

Based on service check:
- ✅ **MongoDB**: Running
- ✅ **API Server (Port 3003)**: Running
- ✅ **Web Server (Port 8082)**: Running  
- ✅ **ngrok (Port 4040)**: Running

**All services are ready for calls!**

## 🎯 Expected Behavior Summary

### When User A Calls User B:

1. **User A taps call button** → Call screen shows "Calling..."
2. **System sends invitation** → API server sends Socket.IO event to User B
3. **User B receives invitation** → Call screen appears with "Incoming Call"
4. **User B answers** → Both users join Jitsi Meet room
5. **Call active** → Video/audio streams work
6. **Call ends** → Both return to chat

## 🚀 Start Services (If Needed)

```powershell
# Quick start all services
cd C:\Users\Administrator\Documents\GitHub\soc-chat-app

# Terminal 1: API Server
cd servers/local_api_server
$env:PORT=3003; $env:HOST="0.0.0.0"; node server.js

# Terminal 2: Web Server  
cd servers
$env:PORT=8082; $env:API_TARGET="http://localhost:3003"; node server.js

# Terminal 3: ngrok (for mobile)
ngrok http 3003
```

## 🔍 Check Services Status

```powershell
# Run the check script
.\scripts\check_services.ps1

# OR manually check:
netstat -an | findstr ":3003"  # API Server
netstat -an | findstr ":8082"  # Web Server
netstat -an | findstr ":4040"  # ngrok
```

## 📱 Testing Calls

### Test on Two Devices:

1. **Device 1 (User A)**:
   - Open chat with User B
   - Tap Voice/Video call button
   - Should see "Calling..." screen

2. **Device 2 (User B)**:
   - Should receive call invitation
   - Call screen appears with "Incoming Call"
   - Tap "Answer" button
   - Both should join Jitsi room

### What to Look For:

✅ **Success Indicators:**
- Call screen appears on both devices
- Jitsi Meet interface opens
- Audio/video streams work
- No errors in console

❌ **Failure Indicators:**
- "Calling..." but no invitation received
- Socket.IO connection errors
- Jitsi Meet doesn't open
- "Failed to start call" error

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| No call received | Check API server is running (port 3003) |
| Socket.IO errors | Check ngrok is running (for mobile) |
| Jitsi doesn't open | Check internet connection & permissions |
| No audio/video | Grant camera/microphone permissions |

## 📋 Service Ports Reference

| Service | Port | Purpose |
|---------|------|---------|
| MongoDB | 27017 | Database |
| API Server | 3003 | Backend API & Socket.IO |
| Web Server | 8082 | Web app proxy |
| ngrok | 4040 | Mobile tunnel (web UI) |
| FCM Server | 3000 | Push notifications (optional) |

## 🔗 Key Files

- **Call Service**: `lib/services/jitsi_call_service.dart`
- **Call Screen**: `lib/screens/call_screen.dart`
- **API Endpoint**: `servers/local_api_server/server.js` (line ~3197)
- **Full Guide**: `docs/CALL_SYSTEM_GUIDE.md`

