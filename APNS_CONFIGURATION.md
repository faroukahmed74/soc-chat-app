# ✅ APNs Authentication Key Configuration

## 📋 **Your APNs Key Information**

- **Key ID**: `L43735XNV9`
- **Team ID**: `25NVHMQAY8`
- **Status**: ✅ Created

## 🔍 **Verify Firebase Console Configuration**

### **Step 1: Check Firebase Console**

1. Go to: **https://console.firebase.google.com/project/soc-chat-app-ca57e/settings/cloudmessaging**
2. Scroll to **"Apple app configuration"** section
3. Find your iOS app: **com.faroukahmed74.socchatapp**
4. Under **"APNs Authentication Key"**, verify:
   - ✅ Status shows "Uploaded" or "Configured"
   - ✅ Key ID: `L43735XNV9`
   - ✅ Team ID: `25NVHMQAY8`

### **Step 2: If Not Uploaded Yet**

If you haven't uploaded to Firebase yet:

1. Click **"Upload"** under "APNs Authentication Key"
2. Upload your `.p8` file (AuthKey_L43735XNV9.p8)
3. Enter **Key ID**: `L43735XNV9`
4. Enter **Team ID**: `25NVHMQAY8`
5. Click **"Upload"**

## ✅ **After Upload - Next Steps**

### **1. Build iOS App**

```bash
flutter build ios --release
```

Or open in Xcode:
```bash
open ios/Runner.xcworkspace
```

### **2. Configure Xcode**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** in the project navigator
3. Go to **"Signing & Capabilities"** tab
4. Select your **Team** (should match Team ID: 25NVHMQAY8)
5. Ensure **"Push Notifications"** capability is enabled
6. Ensure Bundle ID is: `com.faroukahmed74.socchatapp`

### **3. Test on iOS Device**

1. Connect your iOS device
2. Build and run from Xcode
3. Grant notification permissions when prompted
4. Log in to the app
5. FCM token should register automatically

### **4. Verify Token Registration**

After logging in on iOS device:

```bash
cd servers/local_api_server
node show_fcm_tokens.js
```

You should see the iOS user with:
- Platform: `ios`
- FCM Token: Present

### **5. Test iOS Push Notification**

```bash
cd servers/local_api_server
node test_send_notification.js [iOS_user_id]
```

## 🧪 **Testing Checklist**

- [ ] APNs key uploaded to Firebase Console
- [ ] Xcode project configured with correct Team
- [ ] Push Notifications capability enabled
- [ ] App installed on iOS device
- [ ] Notification permissions granted
- [ ] User logged in
- [ ] FCM token registered (check with `show_fcm_tokens.js`)
- [ ] Test notification received
- [ ] Notification tap opens app

## 📝 **Important Notes**

- ✅ **APNs Authentication Key** works for both development and production
- ✅ No need to create separate keys for dev/prod
- ✅ Key never expires (unlike certificates)
- ✅ One key can be used for all apps in your developer account

## 🆘 **Troubleshooting**

### **If notifications don't work:**

1. **Check Firebase Console**:
   - Verify APNs key is uploaded
   - Check Key ID and Team ID match

2. **Check Xcode**:
   - Verify Push Notifications capability is enabled
   - Check Bundle ID matches: `com.faroukahmed74.socchatapp`
   - Verify Team is selected correctly

3. **Check Device**:
   - Settings → Notifications → SOC Chat App → Enabled
   - Settings → General → Background App Refresh → Enabled

4. **Check Server Logs**:
   - Look for FCM token registration
   - Check for any error messages when sending notifications

---

**Your APNs key is ready!** Once uploaded to Firebase, iOS push notifications will work.

