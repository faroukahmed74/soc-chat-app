# Android APK Release Build - Testing Guide
**Date:** 2025-12-03  
**APK Location:** `build\app\outputs\flutter-apk\app-release.apk`  
**APK Size:** 87.2 MB

---

## ✅ Build Status

- **Status:** ✅ **Successfully Built**
- **Build Type:** Release APK
- **File Path:** `build\app\outputs\flutter-apk\app-release.apk`
- **File Size:** 87.2 MB
- **Signing:** Debug keystore (for testing)

---

## 📱 Installation Instructions

### Method 1: ADB (Android Debug Bridge)
```bash
# Connect Android device via USB
# Enable USB debugging on device
adb devices  # Verify device is connected

# Install APK
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Method 2: Direct Transfer
1. Copy `build\app\outputs\flutter-apk\app-release.apk` to Android device
2. On device, open File Manager
3. Navigate to the APK file
4. Tap to install
5. Allow installation from unknown sources if prompted

### Method 3: Email/Cloud Transfer
1. Upload APK to Google Drive/Dropbox
2. Share link with test devices
3. Download and install on devices

---

## 🧪 Testing Checklist

### Pre-Testing Setup
- [ ] Ensure server is running (`servers/local_api_server/server.js`)
- [ ] Verify MongoDB is running
- [ ] Check ngrok tunnel is active (if using ngrok)
- [ ] Ensure both test devices are on same network or have internet access

### Audio/Video Call Testing

#### 1. Basic Call Functionality
- [ ] **Install APK on Device 1**
- [ ] **Install APK on Device 2**
- [ ] **Login on both devices** with different user accounts
- [ ] **Create a chat** between the two users
- [ ] **Test Voice Call:**
  - [ ] Tap voice call button in chat screen
  - [ ] Verify call invitation is sent
  - [ ] Verify recipient receives notification
  - [ ] Verify Jitsi Meet opens on caller's device
  - [ ] Verify recipient can answer call
  - [ ] Verify audio works on both devices
  - [ ] Verify call can be ended
- [ ] **Test Video Call:**
  - [ ] Tap video call button in chat screen
  - [ ] Verify call invitation is sent
  - [ ] Verify recipient receives notification
  - [ ] Verify Jitsi Meet opens on caller's device
  - [ ] Verify recipient can answer call
  - [ ] Verify video works on both devices
  - [ ] Verify audio works on both devices
  - [ ] Verify call can be ended

#### 2. Call Notifications
- [ ] **Test Real-time Notification (Socket.IO):**
  - [ ] Start call when recipient is online
  - [ ] Verify instant notification appears
  - [ ] Verify notification shows caller name
  - [ ] Verify notification shows call type (voice/video)
- [ ] **Test Push Notification (FCM):**
  - [ ] Start call when recipient is offline
  - [ ] Verify FCM push notification is received
  - [ ] Verify tapping notification opens call screen
  - [ ] Verify call can be answered from notification

#### 3. Group Call Testing
- [ ] **Create group chat** with 3+ participants
- [ ] **Start group video call**
- [ ] Verify all participants receive invitation
- [ ] Verify multiple participants can join
- [ ] Verify all participants can see/hear each other
- [ ] Verify screen sharing works (if available)

#### 4. Call Error Handling
- [ ] **Test with no internet connection:**
  - [ ] Verify error message appears
  - [ ] Verify app doesn't crash
- [ ] **Test with server offline:**
  - [ ] Verify error message appears
  - [ ] Verify graceful failure
- [ ] **Test call rejection:**
  - [ ] Verify call can be rejected
  - [ ] Verify caller receives rejection notification

#### 5. Permissions Testing
- [ ] **Camera Permission:**
  - [ ] Verify camera permission is requested for video calls
  - [ ] Verify video works after granting permission
- [ ] **Microphone Permission:**
  - [ ] Verify microphone permission is requested
  - [ ] Verify audio works after granting permission
- [ ] **Storage Permission:**
  - [ ] Verify storage permission is requested (if needed)
  - [ ] Verify media sharing works

---

## 🔍 Server Verification

### Check Server Endpoint
```bash
# Test call invitation endpoint
curl -X POST http://localhost:3003/api/calls/invite \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "chatId": "test_chat_id",
    "chatName": "Test Chat",
    "callerId": "user1_id",
    "callerName": "User 1",
    "roomName": "test_room_123",
    "callType": "video",
    "participantIds": ["user2_id"],
    "isGroupChat": false
  }'
```

### Check Server Logs
Monitor server console for:
- `📞 Call invitation from [caller] to [participants]`
- `✅ Sent call invitation to [participantId]`
- `📱 Sent FCM call notification to [participantId]`

---

## 📊 Expected Behavior

### Call Flow:
1. **User A taps call button** → Call screen appears
2. **Server receives invitation** → `/api/calls/invite` endpoint called
3. **Socket.IO sends event** → Real-time notification to User B
4. **FCM sends push** → Push notification (if User B is offline)
5. **Jitsi Meet opens** → Browser/webview opens `https://meet.jit.si/[roomName]`
6. **User B receives invitation** → Notification appears
7. **User B answers** → Jitsi Meet opens for User B
8. **Both users in same room** → Call is active

---

## 🐛 Troubleshooting

### Issue: Call invitation not received
- **Check:** Server is running
- **Check:** Socket.IO connection is active
- **Check:** User is logged in on both devices
- **Check:** Network connectivity

### Issue: Jitsi Meet doesn't open
- **Check:** Internet connection
- **Check:** `url_launcher` package is installed
- **Check:** Browser is available on device
- **Check:** Jitsi server is accessible (`https://meet.jit.si`)

### Issue: No audio/video
- **Check:** Permissions granted (camera, microphone)
- **Check:** Device hardware is working
- **Check:** Browser permissions (if using webview)

### Issue: Call drops immediately
- **Check:** Network stability
- **Check:** Server logs for errors
- **Check:** Jitsi server status

---

## 📝 Test Results Template

```
Device 1: [Device Name/Model]
Device 2: [Device Name/Model]
Date: [Date]
Tester: [Name]

Voice Call:
- [ ] Works
- [ ] Issues: [Describe]

Video Call:
- [ ] Works
- [ ] Issues: [Describe]

Notifications:
- [ ] Real-time: [ ] Works / [ ] Issues
- [ ] Push (FCM): [ ] Works / [ ] Issues

Group Calls:
- [ ] Works
- [ ] Issues: [Describe]

Overall Status: [ ] Pass / [ ] Fail
Notes: [Any additional notes]
```

---

## ✅ Success Criteria

The APK is ready for testing if:
- ✅ APK builds successfully
- ✅ APK installs on test devices
- ✅ App launches without crashes
- ✅ Login works
- ✅ Chat creation works
- ✅ Call buttons are visible
- ✅ Server endpoint is accessible

---

**APK Location:** `build\app\outputs\flutter-apk\app-release.apk`  
**Server Review:** See `scripts/SERVER_CALL_SERVICES_REVIEW.md`  
**Call Configuration:** See `scripts/CALL_CONFIGURATION_REPORT.md`

---

**Ready for Testing!** 🚀

