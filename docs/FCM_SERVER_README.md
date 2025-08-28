# FCM Notification Server

This is a Node.js server that uses Firebase Admin SDK to send push notifications to your Flutter app.

## 🚀 Quick Start

### 1. Start the server:
```bash
node fcm_server.js
```

The server will start on port 3000 (or the port specified in the PORT environment variable).

### 2. Test the server:
```bash
node test_fcm.js
```

## 📱 How to Get FCM Tokens from Your Flutter App

### 1. In your Flutter app, get the FCM token:
```dart
// In your notification service
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token'); // Copy this token
```

### 2. Replace the placeholder tokens in `test_fcm.js`:
```javascript
const testNotification = {
  token: 'YOUR_ACTUAL_FCM_TOKEN_HERE', // Replace this
  title: 'Test',
  body: 'Test message'
};
```

## 🔧 API Endpoints

### Health Check
- **GET** `/health` - Check if server is running

### Send Notifications
- **POST** `/send-notification` - Send to specific FCM token
- **POST** `/send-topic-notification` - Send to topic subscribers
- **POST** `/send-multicast` - Send to multiple tokens

### Topic Management
- **POST** `/subscribe-topic` - Subscribe tokens to a topic
- **POST** `/unsubscribe-topic` - Unsubscribe tokens from a topic

## 📨 Example Usage

### Send to specific user:
```bash
curl -X POST http://localhost:3000/send-notification \
  -H "Content-Type: application/json" \
  -d '{
    "token": "USER_FCM_TOKEN",
    "title": "New Message",
    "body": "You have a new message!",
    "data": {
      "chatId": "chat123",
      "type": "message"
    }
  }'
```

### Send broadcast to all users:
```bash
curl -X POST http://localhost:3000/send-topic-notification \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "all_users",
    "title": "System Update",
    "body": "App will be updated soon!",
    "data": {
      "type": "system",
      "version": "2.0.0"
    }
  }'
```

### Send to multiple users:
```bash
curl -X POST http://localhost:3000/send-multicast \
  -H "Content-Type: application/json" \
  -d '{
    "tokens": ["TOKEN1", "TOKEN2", "TOKEN3"],
    "title": "Group Chat",
    "body": "New message in group!",
    "data": {
      "chatId": "group123",
      "type": "group_message"
    }
  }'
```

## 🔐 Security Notes

- **Never commit** the service account JSON file to version control
- The file is already added to `.gitignore`
- Use environment variables for production deployments
- Consider implementing authentication for the API endpoints

## 🏗️ Architecture

```
Flutter App (Client) ←→ FCM Server ←→ Firebase Cloud Messaging ←→ User Devices
```

1. **Flutter App** gets FCM token and sends it to your backend
2. **FCM Server** uses service account to authenticate with Firebase
3. **Firebase** delivers notifications to user devices
4. **User Devices** receive and display notifications

## 🧪 Testing

1. Start the server: `node fcm_server.js`
2. Run tests: `node test_fcm.js`
3. Check server logs for success/failure messages
4. Verify notifications appear on your Flutter app

## 📋 Requirements

- Node.js 14+
- Firebase project with Cloud Messaging enabled
- Service account JSON file
- Flutter app with Firebase Messaging configured

## 🚨 Troubleshooting

### Common Issues:

1. **"Service account not found"**
   - Ensure the JSON file is in `assets/service-account/`
   - Check file permissions

2. **"Invalid project ID"**
   - Verify the project ID in the service account JSON
   - Update the projectId in `fcm_server.js`

3. **"Permission denied"**
   - Check if the service account has the right roles
   - Ensure Cloud Messaging API is enabled

4. **"Invalid FCM token"**
   - Verify the token is current and valid
   - Check if the user has uninstalled the app

## 🔄 Next Steps

1. **Integrate with your backend** - Call these endpoints from your chat server
2. **Add authentication** - Protect the API endpoints
3. **Implement retry logic** - Handle failed notifications
4. **Add analytics** - Track notification delivery rates
5. **Deploy to production** - Use environment variables and secure hosting

## 📚 Resources

- [Firebase Admin SDK Documentation](https://firebase.google.com/docs/admin/setup)
- [FCM HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/http-server-ref)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview/)
