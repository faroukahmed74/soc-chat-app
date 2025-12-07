# 📞 Call Debugging Update - Enhanced Logging & Manual Start

## 🔧 **Latest Changes**

### **1. Enhanced Logging in Call Screen**
- Added detailed `print` statements throughout the call initiation flow
- Added logging for participant ID fetching from chat details
- Added error logging with stack traces

### **2. Manual Start Button**
- Added a fallback "Tap to start call" button in the outgoing call UI
- This appears if the call doesn't auto-start (when user info or participant IDs are missing)
- Green call button appears above the red end call button

### **3. Participant ID Fallback**
- Enhanced the fallback mechanism to fetch participant IDs from chat details
- Added detailed logging at each step of the participant ID resolution
- Logs show:
  - When participant IDs are empty
  - Chat details fetch attempt
  - Member IDs found
  - Filtered participant IDs (excluding current user)

## 📱 **APK Installation Status**

### **Device 1: BVK6R19807005234 (DUB LX1)**
- ✅ APK installed successfully
- ✅ App launching via `flutter run`

### **Device 2: 52001c52494e6747**
- ❌ Device not currently connected
- ⚠️ Please connect the second device and run:
  ```powershell
  flutter install --device-id=52001c52494e6747 build\app\outputs\flutter-apk\app-release.apk
  flutter run --device-id=52001c52494e6747 --release
  ```

## 🔍 **What to Check During Testing**

### **On the Caller's Device:**
1. **Open a chat** (individual or group)
2. **Tap the call button** (voice or video)
3. **Watch the console/logs** for:
   - `🔵 CALL_SCREEN: Auto-starting call in outgoing state`
   - `🔵 CALL_SCREEN: Starting call - ChatId: ..., CallType: ...`
   - `🔵 CALL_SCREEN: Current User: ...`
   - `🔵 CALL_SCREEN: Final participant IDs: ...`
   - `🔵 JITSI_CALL_SERVICE: Sending call invitation to X participants`
   - `🔵 JITSI_CALL_SERVICE: URL: ...`
   - `🔵 JITSI_CALL_SERVICE: Response status: ...`

4. **If you see "Tap to start call" button:**
   - This means auto-start failed
   - Tap the green call button to manually start
   - Check logs to see why auto-start failed

### **On the Receiver's Device:**
1. **Check for incoming call notification**
2. **Check Socket.IO connection** (should receive `call_invitation` event)
3. **Check FCM notification** (if app is in background)
4. **Watch logs for:**
   - Socket.IO events
   - FCM notification received
   - Call screen opening

### **On the Server:**
1. **Check server console** for:
   - `📞 Call invitation endpoint hit`
   - `📞 Request body: ...`
   - `📞 Call invitation from ... to X participants`
   - `📞 Participants: ...`
   - Socket.IO emission logs
   - FCM notification sending logs

## 🐛 **Debugging Steps**

### **If Call Doesn't Start:**
1. **Check participant IDs:**
   - Look for: `🔵 CALL_SCREEN: Final participant IDs: ...`
   - If empty, check: `🔵 CALL_SCREEN: Fetched participant IDs from chat: ...`
   - If still empty, there's an issue with chat member fetching

2. **Check HTTP request:**
   - Look for: `🔵 JITSI_CALL_SERVICE: Sending call invitation...`
   - Check response status code
   - If timeout: `🔴 JITSI_CALL_SERVICE: Request timeout after 10 seconds`
   - If error: `🔴 JITSI_CALL_SERVICE: HTTP request error: ...`

3. **Check server endpoint:**
   - Verify server is running
   - Check if endpoint is hit: `📞 Call invitation endpoint hit`
   - Check request body for all required fields

### **If Receiver Doesn't Get Call:**
1. **Check Socket.IO:**
   - Verify receiver is connected to Socket.IO
   - Check if `call_invitation` event is emitted
   - Check participant IDs match receiver's user ID

2. **Check FCM:**
   - Verify FCM token is registered
   - Check if notification is sent
   - Check device notification permissions

3. **Check ngrok:**
   - Verify ngrok is running
   - Check if URL is accessible from mobile devices
   - Verify `mobileServerUrl` in app matches ngrok URL

## 📋 **Log Locations**

### **Flutter App Logs:**
- Run: `flutter logs` (for connected device)
- Or check device logcat: `adb logcat | grep -i "call\|jitsi"`

### **Server Logs:**
- Check console output where `server.js` is running
- Look for `📞` emoji markers for call-related logs

### **Socket.IO Logs:**
- Check server console for Socket.IO connection/disconnection
- Check for `call_invitation` event emissions

## 🚀 **Next Steps**

1. **Connect second device** if not already connected
2. **Install APK on second device**
3. **Launch app on both devices**
4. **Test call initiation:**
   - Individual call
   - Group call
   - Voice call
   - Video call
5. **Monitor logs** on both devices and server
6. **Report any issues** with specific log outputs

## 📝 **Package Information**
- **Package Name**: `com.faroukahmed74.socchatapp`
- **APK Location**: `build\app\outputs\flutter-apk\app-release.apk`
- **APK Size**: 87.3MB

