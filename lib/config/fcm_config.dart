class FCMConfig {
  // FCM Server Key - Get this from Firebase Console > Project Settings > Cloud Messaging
  // Replace with your actual FCM Server Key
  static const String serverKey = 'AIzaSyDf2OUnFBkHgjugfsD1elUe4dQAHb3y0OQ';
  
  // FCM Endpoint
  static const String fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';
  
  // Notification channel IDs
  static const String chatChannelId = 'chat_channel';
  static const String broadcastChannelId = 'broadcast_channel';
  static const String adminChannelId = 'admin_channel';
  
  // Notification channel names
  static const String chatChannelName = 'Chat Messages';
  static const String broadcastChannelName = 'Broadcast Messages';
  static const String adminChannelName = 'Admin Notifications';
  
  // Notification channel descriptions
  static const String chatChannelDescription = 'Notifications for chat messages';
  static const String broadcastChannelDescription = 'Notifications for broadcast messages';
  static const String adminChannelDescription = 'Notifications for admin actions';
}
