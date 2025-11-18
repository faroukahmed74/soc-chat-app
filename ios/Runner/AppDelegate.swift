import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import Photos

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
    
    // Register method channel for Photos library
    if let controller = window?.rootViewController as? FlutterViewController {
      let photosChannel = FlutterMethodChannel(name: "soc_chat_app/photos_library", binaryMessenger: controller.binaryMessenger)
      
      photosChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "saveToPhotos" {
          guard let args = call.arguments as? [String: Any],
                let path = args["path"] as? String,
                let isVideo = args["isVideo"] as? Bool,
                let albumName = args["albumName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }
          
          self.saveToPhotosLibrary(filePath: path, isVideo: isVideo, albumName: albumName, result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Save image or video to Photos library
  private func saveToPhotosLibrary(filePath: String, isVideo: Bool, albumName: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: filePath)
    
    // Check if file exists
    guard FileManager.default.fileExists(atPath: filePath) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "File does not exist at path: \(filePath)", details: nil))
      return
    }
    
    // Request photo library permission
    PHPhotoLibrary.requestAuthorization { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission denied", details: nil))
        }
        return
      }
      
      // Perform save operation on main thread
      PHPhotoLibrary.shared().performChanges({
        if isVideo {
          // Save video
          let videoRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
          videoRequest?.placeholderForCreatedAsset
        } else {
          // Save image
          let imageRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
          imageRequest?.placeholderForCreatedAsset
        }
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            // Try to add to album if album name is provided
            if !albumName.isEmpty {
              self.addToAlbum(albumName: albumName, isVideo: isVideo, result: result)
            } else {
              result(true)
            }
          } else {
            result(FlutterError(code: "SAVE_FAILED", message: error?.localizedDescription ?? "Failed to save to Photos library", details: nil))
          }
        }
      })
    }
  }
  
  // Add saved media to custom album
  private func addToAlbum(albumName: String, isVideo: Bool, result: @escaping FlutterResult) {
    // Fetch the most recently added asset
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    fetchOptions.fetchLimit = 1
    
    let fetchResult: PHFetchResult<PHAsset>
    if isVideo {
      fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
    } else {
      fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    }
    
    guard let asset = fetchResult.firstObject else {
      result(true) // Still return success even if album addition fails
      return
    }
    
    // Find or create album
    var album: PHAssetCollection?
    let fetchAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
    fetchAlbums.enumerateObjects { collection, _, stop in
      if collection.localizedTitle == albumName {
        album = collection
        stop.pointee = true
      }
    }
    
    if album == nil {
      // Create new album
      PHPhotoLibrary.shared().performChanges({
        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
      }, completionHandler: { success, error in
        if success {
          let fetchAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
          fetchAlbums.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == albumName {
              album = collection
              stop.pointee = true
            }
          }
          self.addAssetToAlbum(asset: asset, album: album, result: result)
        } else {
          result(true) // Still return success even if album creation fails
        }
      })
    } else {
      addAssetToAlbum(asset: asset, album: album, result: result)
    }
  }
  
  // Add asset to album
  private func addAssetToAlbum(asset: PHAsset, album: PHAssetCollection?, result: @escaping FlutterResult) {
    guard let album = album else {
      result(true)
      return
    }
    
    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCollectionChangeRequest(for: album)
      request?.addAssets([asset] as NSArray)
    }, completionHandler: { success, error in
      DispatchQueue.main.async {
        result(success)
      }
    })
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
