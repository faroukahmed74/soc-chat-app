# Call Testing - Live Session
**Date:** 2025-12-03  
**Status:** ✅ APK Installed on Both Devices

---

## ✅ Installation Complete

### Device 1: SM T585
- **Status:** ✅ Updated
- **Installation Time:** 42.2 seconds

### Device 2: DUB LX1
- **Status:** ✅ Updated
- **Installation Time:** 25.2 seconds

---

## 🔄 Step 1: Restart Server (IMPORTANT!)

**The server MUST be restarted** to get the enhanced logging:

```powershell
# Stop current server
Get-Process -Name "node" | Where-Object { 
  (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine -like "*server.js*" 
} | Stop-Process -Force

# Start server
cd servers\local_api_server
node server.js
```

**Watch for:** Server should start and show "Server running on port 3003"

---

## 🧪 Step 2: Testing Procedure

### A. Setup Phase
1. **Device 1:** Open app and login with User Account 1
2. **Device 2:** Open app and login with User Account 2
3. **Device 1:** Create a chat with User Account 2
4. **Device 2:** Verify chat appears

### B. Test Voice Call
1. **Device 1:** Tap the **voice call button** (phone icon) in chat screen
2. **Watch Device 1:**
   - Call screen should open
   - Should show "Calling..."
   - Should automatically start call (within 1 second)
3. **Watch Server Logs:**
   - Should see: `📞 Call invitation endpoint hit`
   - Should see: `📞 Call invitation from [caller] to X participants`
   - Should see: `✅ Sent call invitation to [participantId]`
4. **Watch Device 2:**
   - Should receive notification (real-time or push)
   - Notification should show caller name and "Incoming voice call"
5. **Device 2:** Tap notification to answer
6. **Both Devices:** Jitsi Meet should open
7. **Both Devices:** Audio should work

### C. Test Video Call
1. **Device 1:** Tap the **video call button** (camera icon) in chat screen
2. **Watch Device 1:**
   - Call screen should open
   - Should automatically start call
3. **Watch Server Logs:**
   - Should see call invitation logs
4. **Watch Device 2:**
   - Should receive notification
5. **Device 2:** Tap notification to answer
6. **Both Devices:** Grant camera/microphone permissions if prompted
7. **Both Devices:** Video and audio should work

---

## 🔍 Step 3: Monitor Logs

### Device 1 Logs (Caller):
```powershell
flutter logs --device-id=52001c52494e6747 | Select-String "CALL_SCREEN|JITSI_CALL_SERVICE|Starting call|participant|Auto-starting"
```

**Look for:**
- `🔵 CALL_SCREEN: Auto-starting call`
- `Starting call - ChatId: ...`
- `Final participant IDs: ...`
- `Sending call invitation to X participants`
- `Call invitation sent successfully`

### Device 2 Logs (Receiver):
```powershell
flutter logs --device-id=BVK6R19807005234 | Select-String "call_invitation|REALTIME|incoming"
```

**Look for:**
- `Received call invitation`
- `call_invitation` event

### Server Logs:
**Look for:**
- `📞 Call invitation endpoint hit`
- `📞 Call invitation from [caller] to X participants`
- `✅ Sent call invitation to [participantId]`
- `📱 Sent FCM call notification to [participantId]` (if offline)

---

## 🐛 Troubleshooting

### Issue: No server logs
**Possible causes:**
- Server not restarted
- HTTP request failing before reaching server
- Network connectivity issue

**Check:**
- Server is running
- Flutter logs show "Sending call invitation"
- Network connection

### Issue: "No participants found"
**Check Flutter logs for:**
- `Starting call - Participant IDs:`
- If empty, check `Fetched participant IDs from chat:`

**Solution:**
- Verify chat has members
- Check `_memberIds` in chat screen

### Issue: Auto-start not triggering
**Check Flutter logs for:**
- `🔵 CALL_SCREEN: Auto-starting call`
- `🔵 CALL_SCREEN: Delayed call start triggered`

**If missing:**
- User info might not be loaded
- State might not be `outgoing`

### Issue: Call invitation not received
**Check:**
- Server logs show invitation sent
- Socket.IO connection active on Device 2
- FCM token registered (for push notifications)

---

## 📊 Expected Log Sequence

### Successful Call Flow:

**Device 1 (Caller):**
```
🔵 CALL_SCREEN: Auto-starting call - User: [userId], ChatId: [chatId]
🔵 CALL_SCREEN: Delayed call start triggered
Starting call - ChatId: [chatId], Initial Participants: [ids]
Final participant IDs: [ids]
Starting voice call... (or video call...)
Sending call invitation to X participants
URL: [serverUrl]/api/calls/invite
Call invitation sent successfully
```

**Server:**
```
📞 Call invitation endpoint hit
   Request body: {...}
📞 Call invitation from [caller] to X participants
   Room: [roomName], Type: [voice/video], Chat: [chatId]
   Participants: [ids]
✅ Sent call invitation to [participantId]
📱 Sent FCM call notification to [participantId]
```

**Device 2 (Receiver):**
```
Received call invitation globally: {...}
Navigating to call screen: chatId=[chatId], roomName=[roomName]
```

---

## ✅ Success Criteria

- [ ] Call screen opens automatically
- [ ] Auto-start triggers (check logs)
- [ ] Participant IDs are found (check logs)
- [ ] Server receives call invitation request
- [ ] Server logs show invitation sent
- [ ] Device 2 receives notification
- [ ] Device 2 can answer call
- [ ] Jitsi Meet opens on both devices
- [ ] Audio/video works

---

## 🚀 Ready to Test!

**Next Steps:**
1. Restart server
2. Login on both devices
3. Create chat
4. Start call
5. Monitor logs
6. Report results

---

**Status:** ✅ **Ready for Testing**

