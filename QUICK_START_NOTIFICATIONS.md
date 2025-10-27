# Quick Start - Test Notifications on Both Devices

## Status
✅ **Notification fixes committed and pushed**
✅ **Build in progress**

## Steps to Deploy

### On Your Main PC (Windows Server):

1. **Pull the latest changes:**
   ```bash
   cd C:\path\to\soc-chat-app
   git pull
   ```

2. **Restart the server:**
   - Open `services_manager_interactive.bat`
   - Choose option 2 (Stop All Services)
   - Choose option 1 (Start All Services)

3. **Wait for server to start** and note the API URL (should be `https://soc-chat-app.ngrok-free.app`)

### On This Mac (Building APK):

4. **Build the APK** (already started in background):
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
   ```

5. **After build completes**, the APK will be at:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

### Install on Both Devices:

6. **For Device 1 (SM-T585):**
   ```bash
   adb devices  # Check device is connected
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

7. **For Device 2 (DUB LX1):**
   - If connected via ADB:
     ```bash
     adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
     ```
   - Or copy APK to device and install manually

### Test Notifications:

8. **On both devices:**
   - Open the app
   - Login to different accounts
   - Go to a chat between the two accounts
   - Device A sends a message to Device B

9. **Expected behavior:**
   - ✅ Device B should receive notification
   - ✅ Notification should play SOUND (default system sound)
   - ✅ Device should VIBRATE
   - ✅ LED should flash (if supported)

10. **Check logs:**
    - Server console should show:
      ```
      📨 Sending notifications to 1 members
      📤 Emitting chat_notification to room: "..."
      ✅ User ... joined personal notification room
      ```
    - Device logs should show:
      ```
      ✅ Socket connected to notification server
      🔔 Received chat notification via socket
      🎵 DISPLAYED local notification with SOUND
      ```

## What Changed

### Notification Sound Fix:
- ❌ Removed corrupted custom sound files (1KB files)
- ✅ Using default Android notification sound
- ✅ Enabled vibration and LED

### Debug Logging:
- Server logs when emitting notifications
- Client logs when receiving notifications
- Helps identify any remaining issues

## Troubleshooting

If notifications still don't work:
1. Check server logs for emission confirmation
2. Check device logs for reception confirmation
3. Verify notification permissions are granted
4. Make sure Socket.IO connection is established (check for "✅ Socket connected")

