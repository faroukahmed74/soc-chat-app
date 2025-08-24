
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

/// Test script to send notifications to all platforms
/// Run with: dart test_notifications.dart
void main() async {
  print('🧪 Starting notification test for all platforms...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('✅ Firebase initialized');
    
    // Get all users
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final users = usersSnapshot.docs;
    
    print('📱 Found ${users.length} users');
    
    // Send test notification to each user
    int successCount = 0;
    for (final userDoc in users) {
      try {
        final userData = userDoc.data();
        final userName = userData['displayName'] ?? userData['email'] ?? 'Unknown User';
        final platform = userData['platform'] ?? 'Unknown';
        final hasFcmToken = userData['fcmToken'] != null;
        
        print('👤 Testing user: $userName ($platform) - FCM Token: ${hasFcmToken ? "✅" : "❌"}');
        
        // Create test notification
        final testNotification = {
          'type': 'test_notification',
          'title': '🧪 Test Notification',
          'body': 'This is a test notification sent to all platforms!',
          'senderId': 'system',
          'senderName': 'System Test',
          'timestamp': FieldValue.serverTimestamp(),
          'testId': DateTime.now().millisecondsSinceEpoch.toString(),
        };
        
        // Add to user's notifications collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .add(testNotification);
        
        successCount++;
        print('  ✅ Notification sent successfully');
        
      } catch (e) {
        print('  ❌ Failed to send notification: $e');
      }
    }
    
    print('\n🎉 Test completed!');
    print('📊 Results:');
    print('  - Total users: ${users.length}');
    print('  - Successful notifications: $successCount');
    print('  - Failed notifications: ${users.length - successCount}');
    
    // Create a test broadcast message
    try {
      await FirebaseFirestore.instance.collection('broadcasts').add({
        'title': '🧪 System Test Broadcast',
        'message': 'This is a test broadcast message sent to all platforms!',
        'senderId': 'system',
        'senderName': 'System Test',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'test_broadcast',
        'recipients': users.map((doc) => doc.id).toList(),
        'readCount': 0,
      });
      
      print('📢 Test broadcast message created successfully');
    } catch (e) {
      print('❌ Failed to create broadcast message: $e');
    }
    
  } catch (e) {
    print('❌ Error during notification test: $e');
  }
  
  print('\n🏁 Test script finished');
}
