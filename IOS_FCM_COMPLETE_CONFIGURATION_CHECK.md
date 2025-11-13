# 🔍 iOS FCM Notifications - Complete Configuration Review

## ✅ **Configuration Checklist**

Use this checklist to verify ALL iOS FCM configurations are correct:

---

## 1. **Firebase Console Configuration** 🔴 **CRITICAL**

### **APNs Authentication Key**
- [ ] Go to: https://console.firebase.google.com/project/soc-chat-app-ca57e/settings/cloudmessaging
- [ ] Scroll to **"Apple app configuration"** section
- [ ] Find iOS app: `com.faroukahmed74.socchatapp`
- [ ] Under **"APNs Authentication Key"**, verify:
  - [ ] Status shows **"Uploaded"** or **"Configured"** ✅
  - [ ] Key ID: `L43735XNV9`
  - [ ] Team ID: `25NVHMQAY8`
- [ ] **If NOT uploaded:** Upload your `.p8` file now

**⚠️ WITHOUT THIS, iOS NOTIFICATIONS WILL NEVER WORK!**

---

## 2. **Xcode Project Configuration**

### **Open Xcode Project**
```bash
open ios/Runner.xcworkspace
```

### **Signing & Capabilities**
- [ ] Select **Runner** in project navigator
- [ ] Go to **"Signing & Capabilities"** tab
- [ ] **Push Notifications** capability:
  - [ ] Click **"+ Capability"** if not present
  - [ ] Add **"Push Notifications"**
  - [ ] Verify it shows a checkmark ✅
- [ ] **Signing:**
  - [ ] Team selected: Should match Team ID `25NVHMQAY8`
  - [ ] Bundle Identifier: `com.faroukahmed74.socchatapp`
  - [ ] "Automatically manage signing" is checked ✅

### **Build Settings**
- [ ] iOS Deployment Target: `13.0` or higher
- [ ] Code Signing Identity: Set correctly
- [ ] Provisioning Profile: Valid and matches Bundle ID

---

## 3. **iOS Configuration Files**

### **Info.plist** ✅ **VERIFIED**
- [x] `UIBackgroundModes` includes `remote-notification` ✅
- [x] `FirebaseAppDelegateProxyEnabled` = `true` ✅
- [x] Background modes configured correctly ✅

**Location:** `ios/Runner/Info.plist`

### **GoogleService-Info.plist** ✅ **VERIFIED**
- [x] File exists: `ios/Runner/GoogleService-Info.plist` ✅
- [x] Bundle ID: `com.faroukahmed74.socchatapp` ✅
- [x] Project ID: `soc-chat-app-ca57e` ✅
- [x] `IS_GCM_ENABLED` = `true` ✅

### **AppDelegate.swift** ✅ **VERIFIED**
- [x] `FirebaseApp.configure()` called ✅
- [x] `UNUserNotificationCenter.current().delegate = self` ✅
- [x] `Messaging.messaging().delegate = self` ✅
- [x] `application.registerForRemoteNotifications()` called ✅
- [x] APNs token forwarding: `Messaging.messaging().apnsToken = deviceToken` ✅
- [x] Error handling for APNs registration ✅
- [x] Foreground notification presentation ✅
- [x] Background notification handler ✅

**Location:** `ios/Runner/AppDelegate.swift`

### **Podfile** ✅ **VERIFIED**
- [x] Platform: `ios, '13.0'` ✅
- [x] Firebase dependencies installed via CocoaPods ✅

**Location:** `ios/Podfile`

---

## 4. **Flutter Code Configuration**

### **pubspec.yaml** ✅ **VERIFIED**
- [x] `firebase_messaging: ^15.2.10` ✅

### **FCM Service** ✅ **VERIFIED**
- [x] `FCMService` initialized in `main.dart` ✅
- [x] Platform detection: `Platform.isIOS` returns `'ios'` ✅
- [x] Permission request: `requestPermission()` called ✅
- [x] Token retrieval: `getToken()` with iOS retry logic ✅
- [x] Token sent to server with platform: `'ios'` ✅
- [x] Background message handler registered ✅
- [x] Foreground message handler registered ✅
- [x] Token refresh listener active ✅

**Location:** `lib/services/fcm_service.dart`

### **Main.dart** ✅ **VERIFIED**
- [x] `Firebase.initializeApp()` called ✅
- [x] `FCMService().initialize()` called ✅
- [x] User ID updated in FCM service after login ✅

**Location:** `lib/main.dart`

---

## 5. **Server Configuration**

### **APNs Payload Format** ✅ **VERIFIED**
- [x] `apns-push-type: 'alert'` header (required for iOS 13+) ✅
- [x] `apns-priority: '10'` (high priority) ✅
- [x] `aps.sound: 'default'` ✅
- [x] `aps.badge: 1` ✅
- [x] `aps.category` set ✅
- [x] `notification` field with `title` and `body` ✅

**Location:** `servers/local_api_server/server.js`

---

## 6. **Device Requirements**

### **Physical Device** 🔴 **REQUIRED**
- [ ] Testing on **physical iOS device** (not simulator)
- [ ] iOS version: **13.0 or higher**
- [ ] Device connected to internet
- [ ] Device time/date is correct

### **Device Settings**
- [ ] **Notifications:**
  - Settings → Notifications → SOC Chat App
  - **"Allow Notifications"** is ON ✅
  - **"Lock Screen"** enabled ✅
  - **"Notification Center"** enabled ✅
  - **"Banners"** enabled ✅
- [ ] **Background App Refresh:**
  - Settings → General → Background App Refresh
  - **"Background App Refresh"** is ON ✅
  - SOC Chat App is enabled ✅

---

## 7. **Testing & Verification**

### **Step 1: Check Xcode Console Logs**

When you run the app, you should see:

```
✅ Good signs:
- "Firebase initialized successfully"
- "FCM service initialized"
- "FCM notification permission granted"
- "📱 APNs device token received: ..."
- "✅ APNs token forwarded to FCM"
- "✅ FCM registration token received: ..."
- "FCM token obtained: ..."
- "Sending FCM token to server for user: ..., platform: ios"

❌ Bad signs:
- "❌ Failed to register for remote notifications"
- "FCM token is null"
- "FCM registration token is nil"
- "Error getting FCM token"
```

### **Step 2: Check Flutter Logs**

Look for:
```
✅ "✅ FCM service initialized"
✅ "✅ FCM notification permission granted"
✅ "FCM token obtained: ..."
✅ "Sending FCM token to server for user: ..., platform: ios"
```

### **Step 3: Verify Token in Database**

Check MongoDB:
```javascript
db.users.findOne({ fcmPlatform: 'ios' })
```

Should show:
- `fcmToken`: Not empty, valid FCM token
- `fcmPlatform`: `"ios"`
- `fcmTokenUpdatedAt`: Recent timestamp

### **Step 4: Test Notification**

```bash
cd servers/local_api_server
node test_send_notification.js [ios_user_id]
```

Check server logs:
```
✅ "FCM notification sent to user [userId] (platform: ios)"
```

---

## 🔴 **Common Issues & Solutions**

### **Issue 1: "Failed to register for remote notifications"**

**Causes:**
1. Push Notifications capability not enabled in Xcode
2. APNs key not uploaded to Firebase
3. Testing on simulator (simulator doesn't support push)

**Solutions:**
1. Enable Push Notifications in Xcode → Signing & Capabilities
2. Upload APNs Authentication Key to Firebase Console
3. Test on physical device

---

### **Issue 2: "FCM token is null"**

**Causes:**
1. APNs token not registered yet (timing issue on iOS)
2. Notification permissions not granted
3. APNs key not configured in Firebase

**Solutions:**
1. Wait a few seconds and retry (code now has retry logic)
2. Grant notification permissions in iOS Settings
3. Verify APNs key in Firebase Console

---

### **Issue 3: Token registered but notifications don't arrive**

**Causes:**
1. APNs key not uploaded to Firebase
2. Server payload format incorrect
3. Device notifications disabled

**Solutions:**
1. Upload APNs Authentication Key to Firebase Console
2. Verify server APNs payload format
3. Check iOS Settings → Notifications

---

### **Issue 4: Notifications arrive but don't show**

**Causes:**
1. Notification permissions denied
2. Background App Refresh disabled
3. App in foreground without proper handling

**Solutions:**
1. Grant notification permissions
2. Enable Background App Refresh
3. Verify AppDelegate foreground handling

---

## 🧪 **Diagnostic Commands**

### **Check FCM Token Registration**
```bash
# In MongoDB
db.users.find({ fcmPlatform: 'ios' }, { 
  email: 1, 
  fcmToken: 1, 
  fcmPlatform: 1, 
  fcmTokenUpdatedAt: 1 
}).pretty()
```

### **Test Notification**
```bash
cd servers/local_api_server
node test_send_notification.js [ios_user_id]
```

### **Check Server Logs**
```bash
# Look for:
# ✅ "FCM notification sent to user [userId] (platform: ios)"
# ❌ "Error sending FCM notification"
```

### **Check Xcode Console**
```bash
# Look for APNs token registration messages
# Check for any error messages
```

---

## 📋 **Quick Fix Checklist**

If notifications still don't work:

1. [ ] **Verify APNs key uploaded to Firebase Console** (MOST IMPORTANT!)
2. [ ] **Enable Push Notifications in Xcode** (Signing & Capabilities)
3. [ ] **Test on physical device** (not simulator)
4. [ ] **Grant notification permissions** (iOS Settings)
5. [ ] **Enable Background App Refresh** (iOS Settings)
6. [ ] **Check Xcode console** for APNs token registration
7. [ ] **Check Flutter logs** for FCM token retrieval
8. [ ] **Verify token in database** (MongoDB)
9. [ ] **Test notification** from server
10. [ ] **Check server logs** for send errors

---

## ✅ **What Was Fixed**

1. ✅ **Info.plist** - Removed duplicate key, cleaned up deprecated entries
2. ✅ **FCM Service** - Added iOS-specific retry logic for token retrieval
3. ✅ **AppDelegate** - Enhanced error handling and logging
4. ✅ **Server Payload** - Improved APNs payload structure

---

## 🆘 **Still Not Working?**

If you've checked everything above:

1. **Check Firebase Console:**
   - Verify APNs Authentication Key is uploaded
   - Check Key ID and Team ID match

2. **Check Xcode:**
   - Verify Push Notifications capability is enabled
   - Check Bundle ID matches Firebase
   - Verify Team is selected correctly

3. **Check Device:**
   - Settings → Notifications → SOC Chat App → Enabled
   - Settings → General → Background App Refresh → Enabled

4. **Check Logs:**
   - Xcode console for APNs token
   - Flutter logs for FCM token
   - Server logs for notification send

5. **Try Clean Build:**
   ```bash
   flutter clean
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter build ios
   ```

---

**Remember:** 90% of iOS FCM issues are due to:
1. APNs Authentication Key not uploaded to Firebase
2. Push Notifications capability not enabled in Xcode
3. Testing on simulator instead of device

