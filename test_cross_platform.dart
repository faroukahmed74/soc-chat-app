import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

/// Cross-Platform FCM and Sound Notification Test
/// This script tests FCM service and sound notifications across all platforms
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Starting Cross-Platform FCM Test...');
  print('Platform: ${Platform.operatingSystem}');
  print('Platform Version: ${Platform.operatingSystemVersion}');
  
  try {
    // Initialize Firebase
    print('📱 Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
    
    // Test Firebase Auth
    print('🔐 Testing Firebase Auth...');
    final auth = FirebaseAuth.instance;
    print('✅ Firebase Auth available');
    
    // Test Firebase Messaging
    print('📡 Testing Firebase Messaging...');
    final messaging = FirebaseMessaging.instance;
    
    // Get FCM Token
    print('🎫 Getting FCM Token...');
    final fcmToken = await messaging.getToken();
    if (fcmToken != null) {
      print('✅ FCM Token obtained: ${fcmToken.substring(0, 20)}...');
    } else {
      print('❌ FCM Token is null');
    }
    
    // Test APNS Token (iOS only)
    if (Platform.isIOS) {
      print('🍎 Testing APNS Token (iOS)...');
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null) {
        print('✅ APNS Token obtained: ${apnsToken.substring(0, 20)}...');
      } else {
        print('❌ APNS Token is null');
      }
    }
    
    // Test Notification Permissions
    print('🔔 Testing Notification Permissions...');
    final settings = await messaging.getNotificationSettings();
    print('📊 Notification Settings:');
    print('   Authorization: ${settings.authorizationStatus}');
    print('   Alert: ${settings.alert}');
    print('   Sound: ${settings.sound}');
    print('   Badge: ${settings.badge}');
    
    // Test Local Notifications
    print('🔊 Testing Local Notifications...');
    final localNotifications = FlutterLocalNotificationsPlugin();
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await localNotifications.initialize(initSettings);
    print('✅ Local Notifications initialized');
    
    // Test notification channels (Android)
    if (Platform.isAndroid) {
      print('🤖 Testing Android Notification Channels...');
      
      const chatChannel = AndroidNotificationChannel(
        'chat_notifications',
        'Chat Notifications',
        description: 'Notifications for private chat messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('chat_notification'),
      );
      
      const groupChannel = AndroidNotificationChannel(
        'group_notifications',
        'Group Notifications',
        description: 'Notifications for group chat messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('group_notification'),
      );
      
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
      
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(groupChannel);
      
      print('✅ Android notification channels created');
    }
    
    // Test sending a notification
    print('📤 Testing notification sending...');
    await localNotifications.show(
      1,
      '🔊 Cross-Platform Test',
      'FCM and sound notifications are working!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_notifications',
          'Chat Notifications',
          channelDescription: 'Test notification',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Colors.blue,
          sound: RawResourceAndroidNotificationSound('chat_notification'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
    );
    print('✅ Test notification sent');
    
    // Test FCM Server Health
    print('☁️ Testing FCM Server Health...');
    try {
      final response = await HttpClient().getUrl(
        Uri.parse('https://us-central1-soc-chat-app-ca57e.cloudfunctions.net/healthCheck')
      );
      final request = await response.close();
      if (request.statusCode == 200) {
        print('✅ FCM Server is healthy');
      } else {
        print('❌ FCM Server returned status: ${request.statusCode}');
      }
    } catch (e) {
      print('❌ FCM Server health check failed: $e');
    }
    
    print('\n🎉 Cross-Platform FCM Test Completed!');
    print('📊 Summary:');
    print('   Platform: ${Platform.operatingSystem}');
    print('   FCM Token: ${fcmToken != null ? "✅ Available" : "❌ Missing"}');
    if (Platform.isIOS) {
      print('   APNS Token: ${await messaging.getAPNSToken() != null ? "✅ Available" : "❌ Missing"}');
    }
    print('   Notifications: ${settings.authorizationStatus}');
    print('   Local Notifications: ✅ Initialized');
    print('   Test Notification: ✅ Sent');
    
  } catch (e) {
    print('❌ Cross-Platform FCM Test Failed: $e');
  }
}
