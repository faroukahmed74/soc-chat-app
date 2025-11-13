# 🔧 FCM Notifications Troubleshooting Guide

## Current Status
- ✅ Firebase Admin SDK: Initialized
- ✅ Server endpoint: Working (`/api/users/fcm-token`)
- ✅ MongoDB: Connected
- ❌ FCM Tokens: **No tokens registered**

## Why Tokens Aren't Being Registered

The app needs to:
1. **Initialize FCM service** on startup
2. **Get FCM token** from Firebase
3. **Send token to server** at `/api/users/fcm-token`

## Step-by-Step Troubleshooting

### 1. Check App Logs

When users log in, you should see these logs in the app:

**Expected logs:**
```
✅ FCM service initialized
FCM token obtained: [token preview]...
Sending FCM token to server for user: [userId], platform: [android/ios/web]
✅ FCM token sent to server successfully
```

**If you see errors:**
- `Cannot send FCM token: user not logged in` → User ID not stored
- `Cannot send FCM token: no auth token` → Auth token missing
- `Failed to send FCM token: [status code]` → Server connection issue
- `FCM notification permission denied` → User denied permissions

### 2. Verify Server URL

Check what URL the app is using:

**In the app:**
- Check `DatabaseConfig.physicalServerUrl` value
- Should match your server URL (e.g., `http://localhost:3003` or your ngrok URL)

**Common issues:**
- App using wrong server URL
- Server not accessible from app's network
- CORS blocking requests

### 3. Check FCM Initialization

FCM service should initialize automatically. Verify:

**In `lib/main.dart`:**
```dart
// Should have something like:
await FCMService().initialize();
```

**In `lib/services/physical_auth_service.dart`:**
```dart
// After login, should call:
await fcmService.updateUserId(userId.toString());
```

### 4. Test Token Registration Manually

You can test if the endpoint works by manually registering a token:

**Using curl (replace with actual values):**
```bash
curl -X POST http://localhost:3003/api/users/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{
    "userId": "YOUR_USER_ID",
    "fcmToken": "TEST_TOKEN",
    "platform": "android",
    "timestamp": "2025-11-13T10:00:00Z"
  }'
```

### 5. Check Server Logs

When app tries to register token, server should log:
```
FCM token updated for user [userId] (platform: [platform])
```

**If you don't see this:**
- App isn't reaching the server
- Authentication is failing
- Request is being blocked

### 6. Verify Firebase Configuration in App

**For Android:**
- Check `android/app/google-services.json` exists
- Verify package name matches Firebase project

**For iOS:**
- Check `ios/Runner/GoogleService-Info.plist` exists
- Verify bundle ID matches Firebase project

**For Web:**
- Check Firebase config in `web/index.html`
- Verify VAPID key is configured in Firebase Console

### 7. Check Permissions

**Android:**
- Notification permissions should be granted
- Check `AndroidManifest.xml` has notification permissions

**iOS:**
- User must grant notification permissions
- Check `Info.plist` has notification permissions

**Web:**
- Browser must allow notifications
- User must grant permission when prompted

## Quick Fixes

### Fix 1: Force FCM Re-initialization

Add this to your login screen or main app:

```dart
// After successful login
final fcmService = FCMService();
await fcmService.initialize();
final token = await fcmService.getToken();
if (token != null) {
  print('FCM Token: $token');
}
```

### Fix 2: Check Server Accessibility

Test if app can reach server:

```dart
try {
  final response = await http.get(
    Uri.parse('${DatabaseConfig.physicalServerUrl}/api/health')
  );
  print('Server reachable: ${response.statusCode}');
} catch (e) {
  print('Server NOT reachable: $e');
}
```

### Fix 3: Verify Authentication

Check if auth token is valid:

```dart
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('auth_token');
final userId = prefs.getString('user_id');
print('Auth token: ${token != null ? "exists" : "missing"}');
print('User ID: $userId');
```

## Expected Flow

1. **App starts** → FCM service initializes
2. **User logs in** → FCM service gets user ID
3. **FCM token obtained** → Automatically sent to server
4. **Server stores token** → Token saved in MongoDB
5. **Message sent** → Server checks if recipient is offline
6. **FCM notification sent** → Push notification delivered

## Verification Commands

**Check tokens in database:**
```bash
node servers/local_api_server/show_fcm_tokens.js
```

**Check server health:**
```bash
node servers/local_api_server/diagnose_fcm.js
```

**Test endpoint:**
```bash
node servers/local_api_server/check_fcm_endpoint.js
```

## Next Steps

1. **Check app logs** when users log in
2. **Verify server URL** matches in app config
3. **Test manual token registration** using curl
4. **Check Firebase config files** exist in app
5. **Verify permissions** are granted

Once tokens are registered, notifications will work automatically!

