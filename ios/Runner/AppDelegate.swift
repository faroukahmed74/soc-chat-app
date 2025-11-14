import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: FlutterAppDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()
    print("✅ Firebase configured")

    // Set notification center delegate - MUST be set before Flutter plugin registration
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    print("✅ Notification delegates set")

    // Register for remote notifications
    // Note: Permission request is handled by Flutter FCM plugin
    application.registerForRemoteNotifications()
    print("📱 Registered for remote notifications")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Foreground presentation - Show notification even when app is in foreground
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      print("📬 Foreground notification received: \(notification.request.content.userInfo)")
      
      // Show notification banner, sound, and badge even when app is in foreground
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound, .badge, .list])
      } else {
        completionHandler([.alert, .sound, .badge])
      }
  }

  // Handle notification tap (when app is in background or terminated)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
      print("👆 Notification tapped: \(response.notification.request.content.userInfo)")
      
      // Let Flutter handle the notification tap
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
      completionHandler()
  }

  // APNs token to FCM - CRITICAL for iOS notifications
  override func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("📱 APNs device token received: \(tokenString)")
    
    // Forward APNs token to FCM - THIS IS REQUIRED!
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNs token forwarded to FCM")
    
    // Also call super to let Flutter handle it
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle APNs registration failure
  override func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    print("⚠️ Common causes:")
    print("   1. Push Notifications capability not enabled in Xcode")
    print("   2. APNs Authentication Key not uploaded to Firebase Console")
    print("   3. Bundle ID mismatch between Xcode and Firebase")
    print("   4. Testing on iOS Simulator (simulator doesn't support push)")
    print("   5. Invalid provisioning profile")
    
    // Also call super
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // FCM token received/refreshed
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
      print("✅ FCM registration token received: \(token.prefix(30))...")
      print("📝 Full token length: \(token.count) characters")
    } else {
      print("⚠️ FCM registration token is nil - notifications will not work!")
    }
  }

  // Handle background FCM messages (data-only or silent notifications)
  override func application(_ application: UIApplication,
                           didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                           fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("📥 Background FCM notification received")
    if let aps = userInfo["aps"] as? [String: Any] {
      print("   APS payload: \(aps)")
    }
    print("   Full userInfo: \(userInfo)")
    
    // Let Flutter handle it
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
}
