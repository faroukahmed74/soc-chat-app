# Call Log Monitoring Guide
**Date:** 2025-12-03  
**Status:** ✅ APK Installed with Enhanced Debugging

---

## ✅ Infrastructure Status

### Diagnostic Results:
- ✅ **Server:** Running (Process IDs: 14888, 15120)
- ✅ **Port 3003:** Accessible
- ✅ **ngrok:** Running and accessible
- ✅ **ngrok URL:** `https://soc-chat-app.ngrok-free.app` → `http://localhost:3003`
- ✅ **Call Endpoint:** `/api/calls/invite` exists in server.js
- ✅ **Devices:** Both Android devices connected

**Conclusion:** Infrastructure is working correctly. Issue is in Flutter app code flow.

---

## 🔍 Enhanced Debugging Added

### Print Statements Added:
- `🔵 CALL_SCREEN: Auto-starting call` - When auto-start triggers
- `🔵 CALL_SCREEN: Delayed call start triggered` - When call actually starts
- `🔵 JITSI_CALL_SERVICE: Sending call invitation` - When HTTP request is made
- `🔵 JITSI_CALL_SERVICE: Base URL: [url]` - Shows which URL is being used
- `🔵 JITSI_CALL_SERVICE: Making HTTP POST request` - Before making request
- `🔵 JITSI_CALL_SERVICE: Response status: [code]` - Server response
- `🔴 JITSI_CALL_SERVICE: [error]` - Any errors

---

## 📊 How to Monitor Logs

### Option 1: Monitor Device 1 (Caller) Logs
```powershell
flutter logs --device-id=52001c52494e6747
```

**Look for these patterns:**
- `🔵 CALL_SCREEN: Auto-starting call`
- `🔵 CALL_SCREEN: Delayed call start triggered`
- `Starting call - ChatId:`
- `Final participant IDs:`
- `🔵 JITSI_CALL_SERVICE: Sending call invitation`
- `🔵 JITSI_CALL_SERVICE: Base URL:`
- `🔵 JITSI_CALL_SERVICE: Making HTTP POST request`
- `🔵 JITSI_CALL_SERVICE: Response status:`
- Any `🔴` error messages

### Option 2: Monitor Device 2 (Receiver) Logs
```powershell
flutter logs --device-id=BVK6R19807005234
```

**Look for:**
- `call_invitation` events
- `Received call invitation`
- `REALTIME` connection logs

### Option 3: Monitor Server Logs
Watch the server console for:
- `📞 Call invitation endpoint hit`
- `📞 Call invitation from [caller]`
- `✅ Sent call invitation to [participantId]`

---

## 🧪 Testing Steps

1. **Restart Server** (to get fresh logs):
   ```powershell
   # Stop server
   Get-Process -Name "node" | Where-Object { 
     (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine -like "*server.js*" 
   } | Stop-Process -Force
   
   # Start server
   cd servers\local_api_server
   node server.js
   ```

2. **Start Log Monitoring** (in separate terminals):
   ```powershell
   # Terminal 1: Device 1 logs
   flutter logs --device-id=52001c52494e6747
   
   # Terminal 2: Device 2 logs  
   flutter logs --device-id=BVK6R19807005234
   ```

3. **Test Call:**
   - Device 1: Login and create chat
   - Device 1: Tap voice/video call button
   - **Watch all three logs simultaneously**

---

## 🔍 What to Check

### If No Logs Appear:
- **Check:** Is call button actually being tapped?
- **Check:** Is call screen opening?
- **Check:** Are there any crash logs?

### If Auto-Start Logs Appear But No HTTP Request:
- **Check:** Participant IDs - are they empty?
- **Check:** User info - is it loaded?
- **Check:** Any errors in logs?

### If HTTP Request Logs Appear But No Server Logs:
- **Check:** Is the URL correct? (should be ngrok URL for mobile)
- **Check:** Network connectivity
- **Check:** ngrok tunnel status
- **Check:** Request timeout errors

### If Server Logs Appear But No Notification:
- **Check:** Socket.IO connection on Device 2
- **Check:** User ID matching
- **Check:** FCM token registered

---

## 📝 Expected Log Sequence

### Successful Call:

**Device 1:**
```
🔵 CALL_SCREEN: Auto-starting call - User: [userId], ChatId: [chatId]
🔵 CALL_SCREEN: Delayed call start triggered
Starting call - ChatId: [chatId], Initial Participants: [ids]
Final participant IDs: [ids]
Starting voice call... (or video call...)
🔵 JITSI_CALL_SERVICE: Sending call invitation
🔵 JITSI_CALL_SERVICE: Base URL: https://soc-chat-app.ngrok-free.app
🔵 JITSI_CALL_SERVICE: Full URL: https://soc-chat-app.ngrok-free.app/api/calls/invite
🔵 JITSI_CALL_SERVICE: Making HTTP POST request
🔵 JITSI_CALL_SERVICE: Response status: 200
Call invitation sent successfully
```

**Server:**
```
📞 Call invitation endpoint hit
   Request body: {...}
📞 Call invitation from [caller] to X participants
✅ Sent call invitation to [participantId]
```

**Device 2:**
```
Received call invitation globally: {...}
Navigating to call screen
```

---

## 🐛 Common Issues & Solutions

### Issue: "No participant IDs"
**Solution:** Check chat member IDs are loaded

### Issue: "No auth token"
**Solution:** User needs to login again

### Issue: "Request timeout"
**Solution:** Check network/ngrok connection

### Issue: "404 Not Found"
**Solution:** Check server URL is correct

### Issue: "401 Unauthorized"
**Solution:** Token expired, need to login

---

## ✅ Next Steps

1. **Restart server** with fresh logs
2. **Start log monitoring** on both devices
3. **Test call** and watch all logs
4. **Report findings** - what logs appear and where it stops

---

**Status:** ✅ **Ready for Detailed Log Analysis**

