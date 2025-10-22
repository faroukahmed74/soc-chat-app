# SOC Chat App - Notification System Documentation

## Overview

The SOC Chat App implements a comprehensive notification system that works across all platforms (Android, iOS, Web) using a combination of local notifications and real-time server communication via Socket.IO. The system is designed to work with the remote Windows server running the notification server on port 3001.

## Architecture

### Components

1. **Enhanced Notification Service** (`lib/services/enhanced_notification_service.dart`)
   - Main notification service that handles both local and server notifications
   - Integrates with Socket.IO for real-time communication
   - Manages notification channels and permissions
   - Provides unified API for all platforms

2. **Notification Server** (`servers/local_api_server/notification_server.js`)
   - Node.js server running on port 3001
   - Handles Socket.IO connections with authentication
   - Provides REST API endpoints for notification management
   - Stores notifications in MongoDB

3. **Notification Test Screen** (`lib/screens/notification_test_screen.dart`)
   - Debug and testing interface for notification functionality
   - Displays notification status and recent notifications
   - Provides test buttons for local and server notifications

## Features

### Local Notifications
- **Android**: Uses `flutter_local_notifications` with custom notification channels
- **iOS**: Uses system notification handling
- **Web**: Uses browser notification API

### Server Notifications
- **Real-time**: Socket.IO connection for instant notifications
- **REST API**: HTTP endpoints for notification management
- **Authentication**: JWT token-based authentication
- **Persistence**: Notifications stored in MongoDB

### Notification Channels
- `chat_notifications`: For 1:1 chat messages
- `group_notifications`: For group chat messages  
- `broadcast_notifications`: For broadcast messages

## API Endpoints

### Server Endpoints (Port 3001)

#### Health Check
```
GET /health
```
Returns server status.

#### Send Notification to User
```
POST /api/notifications/send
Authorization: Bearer <token>
Content-Type: application/json

{
  "userId": "user_id",
  "title": "Notification Title",
  "body": "Notification Body",
  "data": {}
}
```

#### Send Notification to Chat Room
```
POST /api/notifications/chat
Authorization: Bearer <token>
Content-Type: application/json

{
  "chatId": "chat_id",
  "title": "Chat Notification",
  "body": "New message in chat",
  "data": {}
}
```

#### Get User Notifications
```
GET /api/notifications
Authorization: Bearer <token>
```

#### Mark Notification as Read
```
PUT /api/notifications/:id/read
Authorization: Bearer <token>
```

## Socket.IO Events

### Client → Server
- **Authentication**: Token sent in connection auth
- **Join Chat**: `join_chat` event with chat ID
- **Leave Chat**: `leave_chat` event with chat ID

### Server → Client
- **Notification**: `notification` event for direct notifications
- **Chat Notification**: `chat_notification` event for chat messages

## Platform-Specific Implementation

### Android
- Uses `flutter_local_notifications` plugin
- Requires runtime notification permission
- Custom notification channels with sounds
- Handles notification taps for navigation

### iOS
- Uses system notification handling
- Automatic permission management
- Supports badge, alert, and sound
- Handles notification taps

### Web
- Uses browser notification API
- Permission handled by browser
- Limited to browser capabilities
- Socket.IO for real-time updates

## Usage

### Initialization
```dart
final notificationService = EnhancedNotificationService();
await notificationService.initialize();
```

### Send Local Notification
```dart
await notificationService.sendLocalNotification(
  title: 'Test Notification',
  body: 'This is a test',
  payload: json.encode({'type': 'test'}),
  channelId: 'chat_notifications',
);
```

### Send Server Notification
```dart
final success = await notificationService.sendServerNotification(
  userId: 'user_id',
  title: 'Server Notification',
  body: 'Sent via server',
  data: {'type': 'server'},
);
```

### Get Notifications
```dart
final notifications = await notificationService.getUserNotifications();
```

## Testing

### Notification Test Screen
Access the notification test screen via:
- **Native Apps**: Settings → Test Notifications
- **Web**: Navigate to `/notification-test`

### Test Features
- **Status Display**: Shows notification system status
- **Local Test**: Sends local notification
- **Server Test**: Sends notification via server
- **Permission Request**: Requests notification permission
- **Notification History**: Displays recent notifications

## Configuration

### Server Configuration
The notification server runs on the Windows PC with:
- **Port**: 3001
- **MongoDB**: Connected to local MongoDB instance
- **JWT Secret**: Configured in environment variables
- **CORS**: Enabled for cross-origin requests

### Client Configuration
The client connects to the server using:
- **Base URL**: `https://soc-chat-app.ngrok-free.app`
- **Socket.IO**: WebSocket connection for real-time updates
- **Authentication**: JWT token from SharedPreferences

## Troubleshooting

### Common Issues

1. **Socket Connection Failed**
   - Check if server is running on port 3001
   - Verify ngrok URL is accessible
   - Check authentication token

2. **Local Notifications Not Working**
   - Verify notification permissions
   - Check notification channels are created
   - Test with notification test screen

3. **Server Notifications Not Received**
   - Check Socket.IO connection status
   - Verify user authentication
   - Check server logs for errors

### Debug Information
The notification test screen provides comprehensive debug information:
- Platform detection
- Permission status
- Socket connection status
- Authentication status
- Recent notifications

## Security

### Authentication
- JWT tokens for API authentication
- Socket.IO authentication middleware
- User-specific notification filtering

### Data Protection
- Notifications encrypted in transit
- User data isolation
- Secure token storage

## Performance

### Optimization
- Notification caching
- Batch notification processing
- Efficient Socket.IO reconnection
- Minimal memory footprint

### Monitoring
- Connection status tracking
- Error logging
- Performance metrics
- User engagement tracking

## Future Enhancements

### Planned Features
- Push notification support
- Notification scheduling
- Rich notification content
- Notification analytics
- Multi-language support

### Technical Improvements
- WebSocket fallback
- Offline notification queuing
- Notification deduplication
- Enhanced error handling

## Build Information

### Current Builds
- **Android APK**: `build/app/outputs/flutter-apk/app-release.apk` (78.6MB)
- **iOS Archive**: `build/ios/archive/Runner.xcarchive` (510.3MB)
- **Web Build**: `build/web/` directory

### Build Commands
```bash
# Android
flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app

# iOS
flutter build ipa --no-codesign --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app

# Web
flutter build web --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
```

## Conclusion

The SOC Chat App notification system provides a robust, cross-platform solution for real-time communication. It successfully integrates local notifications with server-side real-time updates, ensuring users receive timely notifications across all platforms while maintaining security and performance standards.

The system is fully tested and ready for production use, with comprehensive debugging tools and monitoring capabilities built-in.
