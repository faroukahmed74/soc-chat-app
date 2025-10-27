# Notification System - Testing Guide

## ✅ All Changes Committed and Pushed!

**Latest Commit**: `9b7f92b` - Notification debugging documentation added
**Previous Commits**:
- `23b42fd` - Debug logging added to server
- `c4574d3` - Fixed notification sound issue
- `ab111b6` - Initial notification fixes

---

## 🖥️ On Your Main PC Server:

### Step 1: Pull Latest Changes
```bash
cd C:\path\to\soc-chat-app
git pull
```

### Step 2: Restart Services
1. Open: `services_manager_interactive.bat`
2. Choose: **Option 2** (Stop All Services)
3. Wait for all services to stop
4. Choose: **Option 1** (Start All Services)
5. Wait for all services to start

### Step 3: Verify Server is Running
Check the API Server console window - you should see:
```
Server running on http://0.0.0.0:3003
Allowed origins: ...
MongoDB connected
```

---

## 📱 On Both Devices (SM-T585 & DUB LX1):

### Current Status:
- ✅ APK installed with latest notification fixes
- ✅ Using default Android notification sound
- ✅ Debug logging enabled

### Step 4: Test Notifications

1. **Device A (SM-T585)**:
   - Open the app
   - Login as User A

2. **Device B (DUB LX1)**:
   - Open the app
   - Login as User B (different account)

3. **Create or Open a Chat**:
   - Make sure User A and User B are in the same chat

4. **Send Test Message**:
   - From Device A, send a message to Device B
   - **Watch the server console immediately!**

---

## 📊 What to Look For in Server Console:

### When Users Connect:
```
🔌 User connected: USER_ID
   Socket ID: abc123
   User ID type: string
   User ID value: "USER_ID"
✅ User USER_ID joined personal notification room: "USER_ID"
   User is in rooms: ["USER_ID", "socket_id"]
```

### When Message is Sent:
```
📨 Sending notifications to 1 members
   Member IDs: ["RECIPIENT_USER_ID"]
   Total Socket.IO rooms: X
📤 Emitting chat_notification to room: "RECIPIENT_USER_ID" (sender: SENDER_USER_ID)
   Available rooms include memberId: true/false ← THIS IS KEY!
```

---

## 🔍 What This Tells Us:

### ✅ If "Available rooms include memberId: true":
- Socket.IO room exists
- ID formats match
- **Notifications SHOULD work!**
- If you still don't hear sound, check device volume/permissions

### ❌ If "Available rooms include memberId: false":
- Socket.IO room doesn't exist
- ID format mismatch or user not connected
- **This is the root cause!**

**If false, share these logs with me:**
- What `socket.userId` shows (when users connect)
- What `memberId` shows (when emitting)
- The full server console output

---

## 🎯 Expected Results:

### Device B (Receiving Device) Should:
- ✅ Get notification popup
- 🔊 Play default Android notification sound
- 📳 Vibrate
- 🔴 LED flash (if supported)

### Device Logs Should Show:
```
✅ Socket connected to notification server
🔔 Received chat notification via socket: {...}
📱 Processing notification - will show local notification
🎵 DISPLAYED local notification with SOUND: Title - Body
```

---

## 🚨 Troubleshooting:

### No Notification at All:
1. Check server console - did it show "Available rooms include memberId: false"?
2. If false, the issue is ID format mismatch - share logs with me
3. If true, check device notification permissions

### Notification Appears but No Sound:
1. Check device volume is up
2. Check device is not in Do Not Disturb mode
3. Verify notification permissions are granted
4. Check server logs for any errors

### Can't See Server Logs:
- Make sure the "API Server" window is open and visible
- Check if services_manager_interactive.bat is running
- Try restarting services again

---

## 📝 After Testing:

**Please share**:
1. Server console logs (especially the "Available rooms include memberId" line)
2. Whether notification appeared or not
3. Whether sound played or not
4. Any error messages

This will help me identify and fix any remaining issues!

---

## 📄 Reference Documents:

- `NOTIFICATION_FIXES_SUMMARY.md` - Complete list of all edits
- `NOTIFICATION_DEBUG_COMPLETE.md` - Debugging guide
- `NOTIFICATION_INSTALL_STATUS.md` - Installation status

