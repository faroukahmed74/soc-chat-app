# 🧪 iOS FCM Notifications - Testing Guide

## ✅ **Configuration Status**

### **Firebase Console** ✅
- ✅ Development APNs key uploaded
- ✅ Production APNs key uploaded
- ✅ Bundle ID: `com.faroukahmed74.socchatapp`
- ✅ Key ID: `L43735XNV9`
- ✅ Team ID: `25NVHMQAY8`

### **Server Configuration** ✅
- ✅ Always sends FCM for iOS devices (even when "online")
- ✅ APNs payload structure correct
- ✅ Platform detection working

### **App Configuration** ✅
- ✅ Info.plist configured
- ✅ AppDelegate.swift handles notifications
- ✅ FCM service initialized

---

## 🧪 **TESTING PROCEDURE**

### **Step 1: Rebuild and Deploy**

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter build ios --release
   ```

2. **Open in Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

3. **Verify Xcode settings:**
   - Select **Runner** → **Signing & Capabilities**
   - ✅ Push Notifications capability enabled
   - ✅ Team: `25NVHMQAY8`
   - ✅ Bundle ID: `com.faroukahmed74.socchatapp`
   - ✅ Provisioning Profile includes push notifications

4. **Archive and upload:**
   - Product → Archive
   - Distribute App → App Store Connect
   - Upload to TestFlight

### **Step 2: Install and Setup**

1. **Install from TestFlight:**
   - Install on physical iOS device
   - **Do NOT use simulator** (simulator doesn't support push)

2. **First launch:**
   - Grant notification permissions when prompted
   - Log in to the app

3. **Verify FCM token registration:**
   - Go to Settings → Push Notification Diagnostics
   - Check:
     - ✅ FCM Token: Should show token (not "Not available")
     - ✅ User ID: Should show your user ID
     - ✅ Last Send Status: Should show "Success"
     - ✅ Platform: Should show "ios"

### **Step 3: Test Notifications**

#### **Test 1: Foreground Notifications**
1. Keep app open and in foreground
2. Have another user (Android or iOS) send you a message
3. **Expected:** Notification banner should appear at top of screen
4. **Check server logs:** Should see:
   ```
   📱 User [userId] is iOS device (always send FCM for background/terminated support), sending FCM notification
   ```

#### **Test 2: Background Notifications**
1. Put app in background (press home button)
2. Have another user send you a message
3. **Expected:** Notification should appear in notification center
4. **Check:** Notification should show title and body

#### **Test 3: Terminated App Notifications**
1. Force close the app (swipe up from app switcher)
2. Have another user send you a message
3. **Expected:** Notification should appear in notification center
4. Tap notification → App should open to the chat

#### **Test 4: Broadcast Notifications**
1. Have an admin send a broadcast message
2. **Expected:** All iOS users should receive notification
3. **Check server logs:** Should see FCM being sent to all iOS users

---

## 🔍 **DEBUGGING**

### **Check Server Logs**

Look for these log messages:

**✅ Success indicators:**
```
📱 User [userId] is iOS device (always send FCM for background/terminated support), sending FCM notification
✅ FCM notification sent to user [userId] (platform: ios): [messageId]
```

**❌ Error indicators:**
```
❌ Error sending FCM notification to user [userId]: [error message]
📱 No FCM token found for user [userId], skipping notification
```

### **Common Errors and Fixes**

#### **Error: "Invalid APNs credentials"**
- **Cause:** APNs key not properly uploaded or expired
- **Fix:** Re-upload APNs key in Firebase Console

#### **Error: "Invalid registration token"**
- **Cause:** FCM token is invalid or expired
- **Fix:** User needs to re-login to get new token

#### **Error: "No FCM token found"**
- **Cause:** User hasn't logged in or token not registered
- **Fix:** User needs to log in and grant notification permissions

### **Check App Logs (Xcode Console)**

When app is running, look for:

**✅ Success indicators:**
```
✅ Firebase configured
✅ Notification delegates set
📱 APNs device token received: [token]
✅ APNs token forwarded to FCM
✅ FCM registration token received: [token]
📬 Foreground notification received: [data]
```

**❌ Error indicators:**
```
❌ Failed to register for remote notifications: [error]
⚠️ FCM registration token is nil
```

---

## 📊 **VERIFICATION CHECKLIST**

### **Before Testing:**
- [ ] Production APNs key uploaded to Firebase ✅
- [ ] Server code updated (always send FCM for iOS) ✅
- [ ] App rebuilt in Release mode
- [ ] Uploaded to TestFlight
- [ ] Installed on physical iOS device

### **During Testing:**
- [ ] FCM token registered (check Settings screen)
- [ ] Notification permissions granted
- [ ] Foreground notifications work
- [ ] Background notifications work
- [ ] Terminated app notifications work
- [ ] Broadcast notifications work

### **Server Verification:**
- [ ] Server logs show FCM being sent for iOS
- [ ] No "Invalid APNs credentials" errors
- [ ] No "Invalid registration token" errors

---

## 🐛 **TROUBLESHOOTING**

### **Issue: Notifications Still Not Working**

1. **Verify FCM Token:**
   - Settings → Push Notification Diagnostics
   - FCM Token should be present
   - If "Not available", re-login

2. **Check iOS Notification Settings:**
   - iOS Settings → Notifications → SOC Chat App
   - Ensure "Allow Notifications" is ON
   - Enable Lock Screen, Notification Center, Banners

3. **Verify Server is Running Updated Code:**
   - Check server logs for: `iOS device (always send FCM for background/terminated support)`
   - If not seeing this, server needs to be restarted with updated code

4. **Check Firebase Console:**
   - Verify both Development AND Production keys are uploaded
   - Key ID and Team ID should match

5. **Test with Test Notification:**
   - Use the test notification feature in app
   - If test works but real messages don't, check server logic

### **Issue: Notifications Work in Debug But Not Release**

- **Cause:** Production APNs key not uploaded (but you've fixed this ✅)
- **Verify:** Both keys are uploaded in Firebase Console

### **Issue: FCM Token Shows "Not available"**

1. **Re-login to app**
2. **Grant notification permissions** when prompted
3. **Check Xcode console** for APNs token registration
4. **Verify Push Notifications capability** is enabled in Xcode

---

## 📝 **EXPECTED BEHAVIOR**

### **Foreground (App Open):**
- Notification banner appears at top
- Sound plays (if enabled)
- Badge updates

### **Background (App Minimized):**
- Notification appears in notification center
- Sound plays (if enabled)
- Badge updates
- Tapping opens app to chat

### **Terminated (App Closed):**
- Notification appears in notification center
- Sound plays (if enabled)
- Badge updates
- Tapping opens app to chat

---

## ✅ **SUCCESS CRITERIA**

Notifications are working correctly when:
1. ✅ FCM token is registered
2. ✅ Server sends FCM for iOS users
3. ✅ Notifications appear in all states (foreground, background, terminated)
4. ✅ Tapping notification opens app to correct chat
5. ✅ No errors in server logs
6. ✅ No errors in app logs

---

**Status:** ✅ All configurations complete | Ready for testing

**Next:** Follow testing procedure above

