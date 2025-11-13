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

    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Foreground presentation
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound, .badge])
      } else {
        completionHandler([.alert, .sound, .badge])
      }
  }

  // Handle notification tap (when app is in background or terminated)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    // Let Flutter handle the notification tap
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    completionHandler()
  }

  // APNs token to FCM
  override func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("📱 APNs device token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNs token forwarded to FCM")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle APNs registration failure
  override func application(_ application: UIApplication,
                   didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    print("⚠️ Make sure:")
    print("   1. Push Notifications capability is enabled in Xcode")
    print("   2. APNs Authentication Key is uploaded to Firebase Console")
    print("   3. Bundle ID matches Firebase configuration")
    print("   4. App is running on a physical device (simulator doesn't support push)")
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // You may POST token to backend here if you prefer native side; we do it in Dart too.
    if let token = fcmToken {
      print("✅ FCM registration token received: \(token.prefix(20))...")
    } else {
      print("⚠️ FCM registration token is nil")
    }
  }

  // Handle background FCM messages
  override func application(_ application: UIApplication,
                           didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                           fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Handle background notification
    if let aps = userInfo["aps"] as? [String: Any] {
      print("Background FCM notification received: \(aps)")
    }
    completionHandler(.newData)
  }
}
