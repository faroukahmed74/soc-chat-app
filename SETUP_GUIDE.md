# 🚀 **SOC CHAT APP - COMPLETE SETUP GUIDE**

## 📋 **PREREQUISITES**
- Firebase project with Firestore, Storage, and Messaging enabled
- Dropbox account (for Android updates)
- iOS Developer Account (for TestFlight)

---

## 🔥 **FIREBASE SETUP**

### 1. **FCM Server Key Configuration**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `soc-chat-app-ca57e`
3. Go to **Project Settings** → **Cloud Messaging**
4. Copy the **Server Key**
5. Open `lib/config/fcm_config.dart`
6. Replace `YOUR_FCM_SERVER_KEY_HERE` with your actual server key

```dart
static const String serverKey = 'AIzaSyC...'; // Your actual key here
```

### 2. **Firestore Indexes Creation**
The app requires several Firestore indexes to avoid "failed-precondition" errors:

1. Go to [Firestore Indexes](https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes)
2. Click **Create Index** for each of the following:

#### **Chats Collection:**
- **Collection ID:** `chats`
- **Fields:** `members` (Array), `lastMessageTime` (Descending)
- **Fields:** `type`, `timestamp` (Descending)

#### **Messages Collection:**
- **Collection ID:** `messages`
- **Fields:** `chatId`, `timestamp` (Descending)
- **Collection Group:** `messages`, `timestamp` (Ascending)

#### **Scheduled Messages Collection:**
- **Collection ID:** `scheduled_messages`
- **Fields:** `userId`, `scheduledTime` (Ascending)
- **Fields:** `status`, `scheduledTime` (Ascending)

#### **Users Collection:**
- **Collection ID:** `users`
- **Fields:** `role`, `status`
- **Fields:** `lastSeen`, `status`

#### **Admin Actions Collection:**
- **Collection ID:** `admin_actions`
- **Fields:** `actionType`, `timestamp` (Descending)
- **Fields:** `adminId`, `timestamp` (Descending)

3. Wait for indexes to build (1-5 minutes)
4. Restart your app

---

## 📱 **ANDROID UPDATE SYSTEM SETUP**

### 1. **Prepare APK File**
1. Build your Android APK: `flutter build apk --release`
2. The APK will be in: `build/app/outputs/flutter-apk/app-release.apk`

### 2. **Upload to Dropbox**
1. Upload `app-release.apk` to Dropbox
2. Create a sharing link (right-click → Share → Copy link)
3. Replace the `dl.dropboxusercontent.com/s/` part with `dl.dropboxusercontent.com/s/`
4. Copy the file ID from the URL

### 3. **Create Version Info JSON**
1. Create a file called `version_info.json` with this content:

```json
{
  "version": "1.0.0",
  "build_number": "1",
  "download_url": "https://dl.dropboxusercontent.com/s/YOUR_APK_FILE_ID/app-release.apk",
  "release_notes": "Initial release with secure messaging and admin features",
  "force_update": false,
  "minimum_version": "1.0.0"
}
```

2. Upload this JSON file to Dropbox
3. Create a sharing link and copy the file ID

### 4. **Update Configuration**
1. Open `lib/config/version_config.dart`
2. Replace the placeholder URLs:

```dart
static const String dropboxJsonUrl = 'https://dl.dropboxusercontent.com/s/YOUR_JSON_FILE_ID/version_info.json';
static const String dropboxApkUrl = 'https://dl.dropboxusercontent.com/s/YOUR_APK_FILE_ID/app-release.apk';
```

---

## 🍎 **iOS TESTFLIGHT SETUP**

### 1. **Build iOS App**
1. Run: `flutter build ios --release`
2. Open Xcode project: `ios/Runner.xcworkspace`
3. Select your team in signing settings
4. Archive the app (Product → Archive)

### 2. **Upload to TestFlight**
1. In Xcode, click **Distribute App**
2. Select **App Store Connect**
3. Choose **Upload**
4. Follow the upload process
5. Wait for processing (usually 10-30 minutes)

### 3. **TestFlight Configuration**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to **TestFlight** tab
4. Add internal testers
5. Submit for Beta App Review if needed

---

## 🔧 **VERIFICATION STEPS**

### 1. **Test FCM Notifications**
1. Send a test message from admin panel
2. Check if push notification appears
3. Verify notification opens the app correctly

### 2. **Test Android Updates**
1. Change version in `version_info.json`
2. Check for updates in app settings
3. Verify download and installation works

### 3. **Test Firestore Queries**
1. Check console for "failed-precondition" errors
2. Verify all indexes are built
3. Test chat loading and message sending

---

## 🚨 **TROUBLESHOOTING**

### **FCM Notifications Not Working**
- Verify server key is correct
- Check Firebase project settings
- Ensure app has notification permissions

### **Android Updates Failing**
- Verify Dropbox URLs are accessible
- Check file permissions and sharing settings
- Ensure APK file is valid

### **Firestore Errors Persist**
- Wait for indexes to finish building
- Check index status in Firebase Console
- Verify collection and field names match

### **iOS Build Issues**
- Check signing certificate validity
- Verify bundle identifier matches
- Ensure minimum iOS version is set correctly

---

## 📞 **SUPPORT**

If you encounter issues:
1. Check the console logs for error messages
2. Verify all configuration files are updated
3. Ensure external services (Firebase, Dropbox) are accessible
4. Check network connectivity and permissions

---

## ✅ **COMPLETION CHECKLIST**

- [ ] FCM Server Key configured
- [ ] All Firestore indexes created and built
- [ ] Dropbox URLs updated for Android updates
- [ ] Version info JSON created and uploaded
- [ ] iOS app uploaded to TestFlight
- [ ] FCM notifications tested
- [ ] Android update system tested
- [ ] All Firestore queries working without errors

**🎉 Your SOC Chat App is now ready for production!**
