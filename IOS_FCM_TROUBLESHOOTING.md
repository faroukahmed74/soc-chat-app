# 🔧 iOS FCM Notifications - Troubleshooting Guide

## ❓ Why FCM Works on Android But Not iOS?

iOS requires **additional configuration** that Android doesn't need. Here are the most common reasons and how to fix them:

---

## 🔴 **Issue #1: APNs Authentication Key Not Configured in Firebase**

**This is the #1 reason iOS notifications fail!**

### ✅ **Solution:**

1. **Go to Firebase Console:**
   - Navigate to: https://console.firebase.google.com/project/soc-chat-app-ca57e/settings/cloudmessaging
   - Scroll to **"Apple app configuration"** section
   - Find your iOS app: `com.faroukahmed74.socchatapp`

2. **Upload APNs Authentication Key:**
   - Click **"Upload"** under "APNs Authentication Key"
   - Upload your `.p8` file (e.g., `AuthKey_L43735XNV9.p8`)
   - Enter **Key ID**: `L43735XNV9`
   - Enter **Team ID**: `25NVHMQAY8`
   - Click **"Upload"**

3. **Verify Status:**
   - Status should show "Uploaded" or "Configured"
   - If it shows "Not configured", notifications **will not work**

---

## 🔴 **Issue #2: Push Notifications Capability Not Enabled in Xcode**

### ✅ **Solution:**

1. **Open Xcode Project:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Enable Push Notifications:**
   - Select **Runner** in the project navigator (left sidebar)
   - Click on **"Signing & Capabilities"** tab
   - Click **"+ Capability"** button
   - Search for **"Push Notifications"** and add it
   - Ensure it shows a checkmark ✅

3. **Verify Signing:**
   - Select your **Team** (should match Team ID: `25NVHMQAY8`)
   - Bundle ID should be: `com.faroukahmed74.socchatapp`
   - Ensure **"Automatically manage signing"** is checked

---

## 🔴 **Issue #3: Testing on iOS Simulator**

**iOS Simulator does NOT support push notifications!**

### ✅ **Solution:**

- **Always test on a physical iOS device**
- Simulator will show errors like:
  - "Failed to register for remote notifications"
  - "APNs token is nil"

---

## 🔴 **Issue #4: Notification Permissions Not Granted**

### ✅ **Solution:**

1. **Check App Settings:**
   - iOS Settings → Notifications → SOC Chat App
   - Ensure **"Allow Notifications"** is ON
   - Enable **"Lock Screen"**, **"Notification Center"**, and **"Banners"**

2. **Check Background App Refresh:**
   - iOS Settings → General → Background App Refresh
   - Ensure it's enabled for your app

3. **Re-request Permissions:**
   - Delete and reinstall the app
   - Grant notification permissions when prompted

---

## 🔴 **Issue #5: APNs Environment Mismatch**

iOS uses different APNs environments for development vs production.

### ✅ **Solution:**

The server code has been updated to handle this automatically. However, if you're testing:

- **Debug builds** → Use development APNs
- **Release builds** → Use production APNs

Firebase automatically handles this when APNs key is properly configured.

---

## 🔴 **Issue #6: Bundle ID Mismatch**

### ✅ **Solution:**

1. **Check Xcode:**
   - Bundle ID in Xcode must match: `com.faroukahmed74.socchatapp`

2. **Check Firebase Console:**
   - Firebase Console → Project Settings → Your Apps
   - iOS app Bundle ID must match exactly

3. **Check GoogleService-Info.plist:**
   - Verify `BUNDLE_ID` matches in `ios/Runner/GoogleService-Info.plist`

---

## 🔴 **Issue #7: APNs Token Not Being Forwarded**

### ✅ **Solution:**

The `AppDelegate.swift` has been updated with better error handling. Check Xcode console logs:

- ✅ **Success:** `"APNs device token received"` and `"APNs token forwarded to FCM"`
- ❌ **Failure:** `"Failed to register for remote notifications"`

If you see failure, check:
1. Push Notifications capability enabled
2. APNs key uploaded to Firebase
3. Running on physical device (not simulator)

---

## 🔴 **Issue #8: FCM Token Not Being Generated**

### ✅ **Solution:**

1. **Check Flutter Logs:**
   - Look for: `"FCM token obtained"` or `"FCM token is null"`

2. **Check Server Logs:**
   - Verify token is being sent to server
   - Check database for `fcmToken` and `fcmPlatform: 'ios'`

3. **Verify FCM Service Initialization:**
   - Ensure `FCMService().initialize()` is called in `main.dart`
   - Check that notification permissions are granted

---

## 🔴 **Issue #9: Server Payload Issues**

### ✅ **Solution:**

The server code has been updated with:
- ✅ `contentAvailable: 1` for background notifications
- ✅ Proper `alert` structure with `title` and `body`
- ✅ `apns-push-type: 'alert'` header

If notifications still don't work, check server logs for:
- `"FCM notification sent to user"` → Success
- `"Error sending FCM notification"` → Check error message

---

## 🧪 **Step-by-Step Testing Checklist**

Follow this checklist to verify everything is working:

### **1. Firebase Console Setup**
- [ ] APNs Authentication Key uploaded
- [ ] Key ID matches: `L43735XNV9`
- [ ] Team ID matches: `25NVHMQAY8`
- [ ] Status shows "Uploaded" or "Configured"

### **2. Xcode Configuration**
- [ ] Push Notifications capability enabled
- [ ] Team selected correctly
- [ ] Bundle ID: `com.faroukahmed74.socchatapp`
- [ ] Signing configured properly

### **3. Device Setup**
- [ ] Testing on **physical iOS device** (not simulator)
- [ ] iOS version: iOS 13.0 or later
- [ ] Device connected to internet

### **4. App Installation**
- [ ] App installed on device
- [ ] Notification permissions granted
- [ ] Background App Refresh enabled

### **5. Token Registration**
- [ ] User logged in to app
- [ ] FCM token registered (check database)
- [ ] `fcmPlatform: 'ios'` in database
- [ ] Token is not empty

### **6. Notification Testing**
- [ ] Send test notification from server
- [ ] Check server logs for success/error
- [ ] Notification appears on device
- [ ] Tapping notification opens app

---

## 🔍 **Debugging Steps**

### **Step 1: Check Xcode Console Logs**

When you run the app, look for these messages:

```
✅ Good signs:
- "APNs device token received: ..."
- "APNs token forwarded to FCM"
- "FCM registration token received: ..."
- "FCM token obtained: ..."

❌ Bad signs:
- "Failed to register for remote notifications"
- "FCM token is null"
- "FCM registration token is nil"
```

### **Step 2: Check Flutter Logs**

Look for FCM service logs:
```
✅ "FCM service initialized"
✅ "FCM notification permission granted"
✅ "FCM token obtained"
```

### **Step 3: Check Server Logs**

When sending a notification:
```
✅ "FCM notification sent to user [userId] (platform: ios)"
❌ "Error sending FCM notification" → Check error message
```

### **Step 4: Check Database**

Verify token is stored:
```javascript
// In MongoDB
db.users.findOne({ fcmPlatform: 'ios' })
// Should show:
// - fcmToken: "..." (not empty)
// - fcmPlatform: "ios"
```

---

## 🆘 **Common Error Messages**

### **Error: "Invalid registration token"**
- **Cause:** Token expired or invalid
- **Fix:** User needs to re-login to refresh token

### **Error: "APNs certificate not found"**
- **Cause:** APNs key not uploaded to Firebase
- **Fix:** Upload APNs Authentication Key to Firebase Console

### **Error: "Failed to register for remote notifications"**
- **Cause:** Push Notifications capability not enabled
- **Fix:** Enable in Xcode → Signing & Capabilities

### **Error: "FCM token is null"**
- **Cause:** Notification permissions not granted
- **Fix:** Grant permissions in iOS Settings

---

## 📝 **Quick Fix Summary**

If notifications still don't work after checking everything:

1. **Delete app from device**
2. **Clean Xcode build:**
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```
3. **Rebuild and reinstall:**
   ```bash
   flutter build ios
   # Then install via Xcode or TestFlight
   ```
4. **Grant permissions again**
5. **Test notification**

---

## ✅ **What Was Fixed in This Update**

1. ✅ **Server APNs payload** - Added `contentAvailable: 1` and proper `alert` structure
2. ✅ **AppDelegate error handling** - Added logging and error messages
3. ✅ **APNs token forwarding** - Improved logging to track token registration

---

## 📞 **Still Not Working?**

If you've checked everything above and it still doesn't work:

1. **Check Firebase Console** - Verify APNs key status
2. **Check Xcode Console** - Look for error messages
3. **Check Server Logs** - Look for FCM send errors
4. **Check Device Settings** - Ensure notifications are enabled
5. **Test with a simple notification** - Use the test script:
   ```bash
   cd servers/local_api_server
   node test_send_notification.js [ios_user_id]
   ```

---

**Remember:** iOS push notifications require:
1. ✅ APNs Authentication Key uploaded to Firebase
2. ✅ Push Notifications capability enabled in Xcode
3. ✅ Physical iOS device (simulator doesn't work)
4. ✅ Notification permissions granted
5. ✅ Proper server payload format

