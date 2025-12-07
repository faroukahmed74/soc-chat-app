# Testing Call Fix - Quick Guide
**Date:** 2025-12-03  
**Status:** ✅ **APK Installed on Both Devices**

---

## ✅ Installation Complete

### Device 1: SM T585
- **Status:** ✅ Updated with fixed APK
- **Installation Time:** 68.1 seconds

### Device 2: DUB LX1
- **Status:** ✅ Updated with fixed APK
- **Installation Time:** 23.1 seconds

---

## 🔄 Important: Restart Server

**The server needs to be restarted** to get the enhanced logging and fixes:

```bash
# Stop current server processes
Get-Process -Name "node" | Where-Object { 
  (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine -like "*server.js*" 
} | Stop-Process -Force

# Start server with enhanced logging
cd servers\local_api_server
node server.js
```

**Or use the services manager:**
```bash
.\stop_all_services.bat
.\start_all_services.bat
```

---

## 🧪 Testing Steps

### 1. Verify Server is Running
- [ ] Server is running on port 3003
- [ ] MongoDB connection established
- [ ] Socket.IO active

### 2. Login on Both Devices
- [ ] **Device 1:** Login with User Account 1
- [ ] **Device 2:** Login with User Account 2
- [ ] Verify both are logged in

### 3. Create Chat
- [ ] **Device 1:** Create chat with User Account 2
- [ ] **Device 2:** Verify chat appears
- [ ] Both devices can see the chat

### 4. Test Voice Call
- [ ] **Device 1:** Tap voice call button
- [ ] **Check Server Logs:** Should see:
  ```
  📞 Call invitation endpoint hit
  📞 Call invitation from [caller] to X participants
  ✅ Sent call invitation to [participantId]
  ```
- [ ] **Device 2:** Should receive notification
- [ ] **Device 2:** Tap notification to answer
- [ ] **Both Devices:** Jitsi Meet should open
- [ ] **Both Devices:** Audio should work

### 5. Test Video Call
- [ ] **Device 1:** Tap video call button
- [ ] **Check Server Logs:** Should see call invitation logs
- [ ] **Device 2:** Should receive notification
- [ ] **Device 2:** Tap notification to answer
- [ ] **Both Devices:** Grant camera/microphone permissions
- [ ] **Both Devices:** Video and audio should work

---

## 🔍 What to Look For

### ✅ Success Indicators:
1. **Server Logs Show:**
   - `📞 Call invitation endpoint hit`
   - `📞 Call invitation from [caller] to X participants`
   - `✅ Sent call invitation to [participantId]`
   - `📱 Sent FCM call notification to [participantId]` (if offline)

2. **Device 1 Logs (Flutter):**
   - `Starting call - Participant IDs: [ids]`
   - `Sending call invitation to X participants`
   - `Call invitation sent successfully`

3. **Device 2:**
   - Receives notification (real-time or push)
   - Can tap to answer
   - Jitsi Meet opens

### ❌ If Still Not Working:

#### Check Flutter Logs:
```bash
# Device 1
flutter logs --device-id=52001c52494e6747 | Select-String "JITSI_CALL_SERVICE|CHAT_SCREEN|call"

# Device 2
flutter logs --device-id=BVK6R19807005234 | Select-String "call_invitation|REALTIME"
```

#### Common Issues:
1. **"No participants found"** → Check participant IDs in logs
2. **"No auth token"** → User needs to login again
3. **Network error** → Check server URL and connectivity
4. **Empty participant IDs** → Check chat member IDs

---

## 📊 Expected Server Logs

When call is initiated, you should see:
```
📞 Call invitation endpoint hit
   Request body: {
     "chatId": "...",
     "callerId": "...",
     "participantIds": ["..."],
     ...
   }
📞 Call invitation from User1 (user_id) to 1 participants
   Room: chat_id_voice_timestamp, Type: voice, Chat: chat_id
   Participants: user_id_2
   ✅ Sent call invitation to user_id_2
   📱 Sent FCM call notification to user_id_2
```

---

## 🎯 Quick Test Checklist

- [ ] Server restarted with enhanced logging
- [ ] Both devices have updated APK
- [ ] Both users logged in
- [ ] Chat created between users
- [ ] Voice call works
- [ ] Video call works
- [ ] Server logs show call invitations
- [ ] Notifications work

---

## 📝 Report Issues

If issues persist, check:
1. **Server logs** - Look for error messages
2. **Flutter logs** - Check both devices
3. **Participant IDs** - Verify they're not empty
4. **Network** - Ensure both devices can reach server
5. **Socket.IO** - Verify connection is active

---

**Status:** ✅ **Ready for Testing**  
**Next:** Restart server and test calls!

