# iOS Background Notifications - Available Solutions

## Overview
iOS has strict limitations on background execution. Unlike Android, iOS suspends network connections when apps go to background. Here are the available solutions:

---

## Solution 1: Push Notifications (APNs via FCM) ✅ **RECOMMENDED**

### Status: **ALREADY AVAILABLE** ✅
Your app already has Firebase Cloud Messaging (FCM) configured!

### What's Already Set Up:
- ✅ `firebase_messaging: ^15.2.10` in `pubspec.yaml`
- ✅ Firebase configured in `ios/Runner/AppDelegate.swift`
- ✅ APNs token registration working
- ✅ FCM server files exist (`servers/fcm_server.js`)

### What Needs to Be Done:

#### Step 1: Integrate FCM with Your MongoDB Backend

**Current Situation:**
- FCM is configured but may not be integrated with your MongoDB server
- Server needs to send FCM notifications when messages arrive

**Implementation Steps:**

1. **Get FCM Token in Flutter App:**
```dart
// Add to lib/services/enhanced_notification_service.dart or create new service
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // Get FCM token
  static Future<String?> getToken() async {
    try {
      final token = await _fcm.getToken();
      Log.i('FCM Token: $token', 'FCM_SERVICE');
      return token;
    } catch (e) {
      Log.e('Error getting FCM token', 'FCM_SERVICE', e);
      return null;
    }
  }
  
  // Send token to your MongoDB server
  static Future<void> sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      
      final response = await http.post(
        Uri.parse('${DatabaseConfig.physicalServerUrl}/api/users/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'fcmToken': token}),
      );
      
      if (response.statusCode == 200) {
        Log.i('FCM token sent to server', 'FCM_SERVICE');
      }
    } catch (e) {
      Log.e('Error sending FCM token to server', 'FCM_SERVICE', e);
    }
  }
  
  // Listen for foreground messages
  static void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Log.i('Received FCM message in foreground: ${message.notification?.title}', 'FCM_SERVICE');
      
      // Show local notification
      final notificationService = EnhancedNotificationService();
      notificationService.sendLocalNotification(
        title: message.notification?.title ?? 'New Message',
        body: message.notification?.body ?? '',
        payload: message.data['chatId'] ?? '',
        channelId: 'chat_notifications',
      );
    });
  }
  
  // Handle background messages
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    Log.i('Received FCM message in background: ${message.notification?.title}', 'FCM_SERVICE');
    
    final notificationService = EnhancedNotificationService();
    await notificationService.initialize();
    await notificationService.sendLocalNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? '',
      payload: message.data['chatId'] ?? '',
      channelId: 'chat_notifications',
    );
  }
}
```

2. **Update MongoDB Server to Send FCM Notifications:**

When a new message is created, your server should:
- Get recipient's FCM token from database
- Send FCM notification via Firebase Admin SDK
- This works even when app is in background!

**Example Server Code (Node.js):**
```javascript
const admin = require('firebase-admin');

// Initialize Firebase Admin (use your service account key)
admin.initializeApp({
  credential: admin.credential.cert(require('./path/to/serviceAccountKey.json'))
});

// When new message arrives
async function sendMessageNotification(recipientId, messageData) {
  // Get recipient's FCM token from MongoDB
  const user = await User.findById(recipientId);
  if (!user || !user.fcmToken) return;
  
  const message = {
    token: user.fcmToken,
    notification: {
      title: messageData.senderName,
      body: messageData.content,
    },
    data: {
      chatId: messageData.chatId,
      type: 'chat_message',
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };
  
  try {
    await admin.messaging().send(message);
    console.log('FCM notification sent successfully');
  } catch (error) {
    console.error('Error sending FCM notification:', error);
  }
}
```

#### Step 2: Request Notification Permissions

Already done! Your code already requests iOS notification permissions.

#### Step 3: Test

1. Get FCM token from device
2. Send token to your MongoDB server
3. Server sends FCM notification when message arrives
4. Notification appears even when app is in background! ✅

### Advantages:
- ✅ Works when app is completely closed
- ✅ Works when app is in background
- ✅ Low battery usage
- ✅ Reliable delivery
- ✅ Already configured in your app

### Requirements:
- Firebase project with APNs certificate configured
- Server-side Firebase Admin SDK
- Store FCM tokens in MongoDB

---

## Solution 2: Background Fetch ⚠️ **LIMITED**

### Status: **DISABLED** (CocoaPods Issue)

### Current Status:
- ❌ `background_fetch: ^1.5.0` is commented out in `pubspec.yaml`
- ❌ Code exists but is disabled in `lib/services/ios_background_service.dart`

### What Background Fetch Does:
- iOS periodically wakes your app (every 15+ minutes minimum)
- App can sync messages from server
- Show notifications for new messages
- **BUT:** Not real-time, system-controlled timing

### How to Enable:

#### Option A: Fix CocoaPods Issue

1. **Uncomment in pubspec.yaml:**
```yaml
background_fetch: ^1.5.0
```

2. **Try to install:**
```bash
cd ios
pod install
```

3. **If CocoaPods error occurs:**
   - Check the specific error
   - May need to update CocoaPods: `sudo gem install cocoapods`
   - May need to clean: `pod deintegrate && pod install`

#### Option B: Use Alternative Package

Try `workmanager` (works on both iOS and Android):
```yaml
workmanager: ^0.5.2
```

**Note:** You mentioned `workmanager` is also disabled due to compatibility issues.

### Implementation (if enabled):

```dart
import 'package:background_fetch/background_fetch.dart';

class IOSBackgroundService {
  static Future<void> initialize() async {
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15, // minutes (minimum is 15)
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
      ),
      _onBackgroundFetch,
      _onBackgroundFetchTimeout,
    );
    
    await BackgroundFetch.start();
  }
  
  static void _onBackgroundFetch(String taskId) async {
    // Sync messages from server
    await syncMessages();
    BackgroundFetch.finish(taskId);
  }
  
  static void _onBackgroundFetchTimeout(String taskId) {
    BackgroundFetch.finish(taskId);
  }
}
```

### Advantages:
- ✅ Can sync messages periodically
- ✅ Works when app is in background
- ✅ No server-side changes needed

### Disadvantages:
- ⚠️ Not real-time (15+ minute intervals)
- ⚠️ System-controlled (iOS decides when to run)
- ⚠️ May not run if battery is low
- ⚠️ Currently disabled due to CocoaPods issues

---

## Recommendation: Use FCM Push Notifications

**Why FCM is Better:**
1. ✅ **Real-time** - Notifications arrive immediately
2. ✅ **Reliable** - Works even when app is closed
3. ✅ **Low battery** - Server sends, device just receives
4. ✅ **Already configured** - Just needs integration
5. ✅ **Industry standard** - Used by WhatsApp, Telegram, etc.

**Background Fetch is:**
- ⚠️ Backup solution
- ⚠️ Not real-time
- ⚠️ Currently broken (CocoaPods issue)

---

## Implementation Priority

### Phase 1: FCM Integration (High Priority) ✅
1. Get FCM token in app
2. Send token to MongoDB server
3. Server sends FCM when messages arrive
4. **Result:** Background notifications work! ✅

### Phase 2: Background Fetch (Low Priority) ⚠️
1. Fix CocoaPods issue
2. Enable background_fetch
3. Implement periodic sync
4. **Result:** Backup sync mechanism

---

## Quick Start: FCM Integration

1. **Add FCM service to your app:**
   - Create `lib/services/fcm_notification_service.dart`
   - Use code from Solution 1 above

2. **Initialize in main.dart:**
```dart
// In _initializeNotifications()
if (Platform.isIOS) {
  final fcmToken = await FCMNotificationService.getToken();
  if (fcmToken != null) {
    await FCMNotificationService.sendTokenToServer(fcmToken);
  }
  FCMNotificationService.setupForegroundHandler();
}
```

3. **Update MongoDB server:**
   - Add endpoint to store FCM tokens
   - Send FCM notifications when messages arrive

4. **Test:**
   - Send message from another device
   - Notification should appear even when app is in background! ✅

---

## Summary

| Solution | Status | Real-time | Reliability | Battery | Implementation |
|----------|--------|-----------|-------------|---------|----------------|
| **FCM Push** | ✅ Available | ✅ Yes | ✅ High | ✅ Low | Medium |
| **Background Fetch** | ❌ Disabled | ❌ No | ⚠️ Medium | ✅ Low | Easy (if fixed) |

**Recommendation:** Implement FCM push notifications first. It's the best solution for iOS background notifications.

