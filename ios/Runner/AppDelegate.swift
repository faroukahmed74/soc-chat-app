import UIKit
import Flutter
import Photos
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Do NOT call FirebaseApp.configure() here.
    // FlutterFire initializes Firebase from Dart via Firebase.initializeApp().
    // Calling configure() natively as well can crash at launch on newer Firebase SDKs.

    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Register after Flutter engine / window are ready
    if let controller = window?.rootViewController as? FlutterViewController {
      let photosChannel = FlutterMethodChannel(
        name: "soc_chat_app/photos_library",
        binaryMessenger: controller.binaryMessenger
      )

      photosChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        guard let self = self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate deallocated", details: nil))
          return
        }

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

    return ok
  }

  // Save image or video to Photos library
  private func saveToPhotosLibrary(filePath: String, isVideo: Bool, albumName: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: filePath)

    guard FileManager.default.fileExists(atPath: filePath) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "File does not exist at path: \(filePath)", details: nil))
      return
    }

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "PERMISSION_DENIED",
            message: "Photo library permission denied. Please enable it in Settings > Privacy & Security > Photos.",
            details: nil
          ))
        }
        return
      }

      PHPhotoLibrary.shared().performChanges({
        if isVideo {
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        } else {
          PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
        }
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            if !albumName.isEmpty {
              self.addToAlbum(albumName: albumName, isVideo: isVideo, result: result)
            } else {
              result(true)
            }
          } else {
            result(FlutterError(
              code: "SAVE_FAILED",
              message: error?.localizedDescription ?? "Failed to save to Photos library",
              details: nil
            ))
          }
        }
      })
    }
  }

  private func addToAlbum(albumName: String, isVideo: Bool, result: @escaping FlutterResult) {
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
      result(true)
      return
    }

    var album: PHAssetCollection?
    let fetchAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
    fetchAlbums.enumerateObjects { collection, _, stop in
      if collection.localizedTitle == albumName {
        album = collection
        stop.pointee = true
      }
    }

    if album == nil {
      PHPhotoLibrary.shared().performChanges({
        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
      }, completionHandler: { success, _ in
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
          result(true)
        }
      })
    } else {
      addAssetToAlbum(asset: asset, album: album, result: result)
    }
  }

  private func addAssetToAlbum(asset: PHAsset, album: PHAssetCollection?, result: @escaping FlutterResult) {
    guard let album = album else {
      result(true)
      return
    }

    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCollectionChangeRequest(for: album)
      request?.addAssets([asset] as NSArray)
    }, completionHandler: { success, _ in
      DispatchQueue.main.async {
        result(success)
      }
    })
  }

  // Foreground presentation - show notification while app is open
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
