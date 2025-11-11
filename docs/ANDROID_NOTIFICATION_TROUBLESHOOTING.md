# Android Notification Troubleshooting Guide

## Overview
This guide helps you troubleshoot notification issues on Android devices. Notifications require proper permissions and system settings to work reliably.

## Quick Checklist

1. ✅ **Notification Permission** - Must be granted (Android 13+)
2. ✅ **Battery Optimization** - App should be exempted
3. ✅ **Foreground Service** - Should be running (check notification bar)
4. ✅ **Auto-start** - Enable in device settings (varies by manufacturer)
5. ✅ **Background Data** - Should be enabled

## Step-by-Step Fix

### Step 1: Grant Notification Permission

**For Android 13+ (API 33+):**
1. Open the app
2. When prompted, tap **"Allow"** for notifications
3. If denied, go to: **Settings > Apps > SOC Chat App > Notifications > Allow**

**For Android 12 and below:**
- Notifications are enabled by default, but you can verify in:
  - **Settings > Apps > SOC Chat App > Notifications**

### Step 2: Disable Battery Optimization

Battery optimization can kill background services. You must exempt the app:

1. Go to **Settings > Apps > SOC Chat App**
2. Tap **"Battery"** or **"Battery usage"**
3. Select **"Don't optimize"** or **"Unrestricted"**
4. Alternatively, go to **Settings > Battery > Battery optimization**
5. Find **"SOC Chat App"** and set to **"Don't optimize"**

**Note:** Some manufacturers (Xiaomi, Huawei, Oppo, Vivo) have additional battery saver settings.

### Step 3: Enable Auto-start (Manufacturer-Specific)

Some Android manufacturers require apps to be added to an "Auto-start" whitelist:

**Xiaomi (MIUI):**
- Settings > Apps > Manage apps > SOC Chat App > Autostart > Enable

**Huawei (EMUI):**
- Settings > Apps > Apps > SOC Chat App > Launch > Manage manually > Enable all

**Oppo/OnePlus (ColorOS):**
- Settings > Apps > App management > SOC Chat App > Auto-launch > Enable

**Vivo (Funtouch OS):**
- Settings > Battery > Background app management > SOC Chat App > Allow background activity

**Samsung:**
- Settings > Apps > SOC Chat App > Battery > Unrestricted

### Step 4: Verify Foreground Service is Running

1. Open the app and log in
2. Check the notification bar - you should see a persistent notification: **"SOC Chat - Connected and receiving messages"**
3. If you don't see this notification:
   - The foreground service may not have started
   - Check app logs for errors
   - Try restarting the app

### Step 5: Test Notifications

1. Open the app
2. Go to **Settings**
3. Tap **"Test Notifications"** or **"Test Real Notification"**
4. You should receive a test notification immediately
5. If no notification appears:
   - Check notification permission (Step 1)
   - Check battery optimization (Step 2)
   - Check if notifications are enabled in app settings

## Common Issues

### Issue: "No notifications received"

**Possible Causes:**
- Notification permission not granted
- Battery optimization killing the service
- Foreground service not running
- Socket connection failed

**Solutions:**
1. Re-check Steps 1-4 above
2. Restart the app
3. Check device logs: `adb logcat | grep -i "notification\|foreground"`
4. Verify server is reachable

### Issue: "Notifications work sometimes but not always"

**Possible Causes:**
- Battery optimization partially enabled
- Device in power-saving mode
- Network connectivity issues

**Solutions:**
1. Disable battery optimization completely (Step 2)
2. Disable power-saving mode
3. Ensure stable internet connection
4. Check if Wi-Fi/Mobile data restrictions exist

### Issue: "Foreground service notification disappears"

**Possible Causes:**
- Service was killed by system
- App was force-stopped
- Battery optimization re-enabled

**Solutions:**
1. Re-check battery optimization settings
2. Restart the app
3. Add app to auto-start list (Step 3)

### Issue: "Test notification works but real messages don't"

**Possible Causes:**
- Socket connection not established
- Server not sending notifications
- User not joined to notification room

**Solutions:**
1. Check if foreground service is running
2. Verify socket connection in logs
3. Check server logs for notification events
4. Restart the app to re-establish connection

## Verification Commands

### Check Notification Permission (via ADB)
```bash
adb shell dumpsys package com.your.package.name | grep notification
```

### Check Battery Optimization Status
```bash
adb shell dumpsys deviceidle whitelist | grep -i "soc\|chat"
```

### Check Running Services
```bash
adb shell dumpsys activity services | grep -i "foreground\|soc"
```

## Manufacturer-Specific Notes

### Xiaomi (MIUI)
- Requires "Autostart" permission
- May need "Display pop-up windows" permission
- Check "Battery saver" settings

### Huawei (EMUI)
- Requires "Launch" permission
- May need "Floating window" permission
- Check "App launch" settings

### Oppo/OnePlus (ColorOS)
- Requires "Auto-launch" permission
- May need "Floating window" permission
- Check "Background freeze" settings

### Vivo (Funtouch OS)
- Requires "Background app management" permission
- May need "Floating window" permission
- Check "High background power consumption" settings

### Samsung
- Generally works well with standard settings
- Check "App power management" settings
- May need "Allow background activity"

## Testing Checklist

After following all steps, verify:

- [ ] Notification permission granted
- [ ] Battery optimization disabled
- [ ] Auto-start enabled (if applicable)
- [ ] Foreground service notification visible
- [ ] Test notification works
- [ ] Real message notifications work
- [ ] Notifications work when app is in background
- [ ] Notifications work after device restart

## Still Not Working?

If notifications still don't work after following all steps:

1. **Check App Logs:**
   ```bash
   adb logcat | grep -i "notification\|foreground\|socket"
   ```

2. **Check Server Logs:**
   - Verify server is running
   - Check if socket events are being sent
   - Verify user authentication

3. **Reinstall the App:**
   - Uninstall completely
   - Reinstall from APK
   - Follow all steps again

4. **Contact Support:**
   - Provide device model and Android version
   - Share relevant logcat output
   - Describe exact steps taken

## Technical Details

### Foreground Service
The app uses a foreground service to maintain a persistent socket connection. This service:
- Shows a persistent notification
- Keeps the app alive in background
- Maintains socket connection for real-time notifications
- Automatically reconnects if connection drops

### Notification Channels
The app uses three notification channels:
- `chat_notifications` - For direct messages
- `group_notifications` - For group messages
- `broadcast_notifications` - For broadcast messages
- `foreground_chat_service` - For foreground service indicator

### Socket Connection
The foreground service maintains a WebSocket connection to the server:
- Connects on service start
- Joins user-specific notification room
- Listens for `chat_notification`, `new_message`, and `notification` events
- Automatically reconnects on disconnect

## Version Information

- **App Version:** Check in Settings > About
- **Android Version:** Settings > About phone > Android version
- **Device Model:** Settings > About phone > Model

---

**Last Updated:** 2024
**App:** SOC Chat App

