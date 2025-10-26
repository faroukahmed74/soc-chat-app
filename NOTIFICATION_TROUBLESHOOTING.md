# Notification Troubleshooting Guide

## Problem
No sound notifications when sending messages between devices.

## Fix Applied
Added debugging to track notification flow:
1. ✅ Server logging when emitting notifications
2. ✅ Client logging when receiving notifications
3. ✅ Enhanced logging for notification display

## How to Test

### Step 1: Restart the Server
Stop and restart your services using option 1 in services_manager_interactive.bat

### Step 2: Check Server Logs
Look for these logs in the server console when you send a message:
```
📨 Sending notifications to X members
📤 Emitting chat_notification to room: "USER_ID"
```

### Step 3: Check Client Logs
On the receiving device, check for these logs:
```
✅ Socket connected to notification server
🔔 Received chat notification via socket: {...}
📱 Processing notification - will show local notification
🎵 DISPLAYED local notification with SOUND: Title - Body
```

### Step 4: Verify Sound Files
The sound files should exist at:
```
android/app/src/main/res/raw/chat_notification.mp3
android/app/src/main/res/raw/group_notification.mp3
android/app/src/main/res/raw/notification_sound.mp3
```
✅ All files are present and in correct location

### Step 5: Common Issues

#### Issue 1: Socket Not Connected
**Symptom**: No "✅ Socket connected" log
**Solution**: Check network connection and API URL in app

#### Issue 2: Server Not Emitting
**Symptom**: No "📨 Sending notifications" log in server
**Solution**: Check if users are in the same chat and members array is correct

#### Issue 3: Room Mismatch
**Symptom**: Server shows emitting but client doesn't receive
**Solution**: Check if user ID format matches between server and client

#### Issue 4: No Sound
**Symptom**: Notification appears but no sound
**Solution**: 
- Check notification permissions are granted
- Verify sound file exists and is not corrupted
- Check device volume settings

## Debug Commands

### Check if server is running:
```bash
netstat -an | findstr ":3003"
```

### View server logs:
Check the API Server window opened by services_manager_interactive.bat

### Test notification manually:
```bash
curl -X POST http://localhost:3003/api/notifications/send \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"userId":"USER_ID","title":"Test","body":"Test notification"}'
```

## Next Steps
1. Restart your server using option 1 in services_manager_interactive.bat
2. Send a test message between devices
3. Check the logs in:
   - Server console (API Server window)
   - Client logs (use Flutter DevTools or adb logcat)
4. Report what you see in the logs

