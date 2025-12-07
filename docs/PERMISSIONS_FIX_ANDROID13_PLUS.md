# Permissions Fix for Android 13+ and All Platforms

## Issue
On Android 13+ (API 33+), the system requires explicit runtime permission requests for microphone and camera before `getUserMedia()` can be called. The app was not requesting these permissions, causing permission dialogs to not appear and calls to fail.

## Solution
Created a unified `CallPermissionService` that:
1. **Requests permissions explicitly** before accessing media
2. **Handles Android 13+** granular permissions correctly
3. **Supports all platforms** (Android, iOS, Web)
4. **Shows appropriate dialogs** when permissions are permanently denied

## Changes Made

### 1. New Service: `CallPermissionService`
**File**: `lib/services/call_permission_service.dart`

- **`requestMicrophonePermission()`**: Requests microphone permission (required for all calls)
- **`requestCameraPermission()`**: Requests camera permission (required for video calls)
- **`requestCallPermissions()`**: Requests both permissions based on call type
- **Platform-specific handling**: 
  - Android: Uses `Permission.microphone` and `Permission.camera`
  - iOS: Uses same permissions with iOS-specific dialogs
  - Web: Returns `true` (browser handles permissions automatically)

### 2. Updated WebRTC Call Service
**File**: `lib/services/webrtc_call_service.dart`

- **Updated `_getLocalStream()`**: Now requests permissions before calling `getUserMedia()`
- **Uses navigator key**: Gets context from global navigator key when available
- **Error handling**: Throws exception if permissions are denied
- **All call paths updated**: `startCall()`, `acceptCall()`, and offer handler all request permissions

### 3. iOS Permission Descriptions
**File**: `ios/Runner/Info.plist`

- Updated `NSCameraUsageDescription` to mention video calls
- Updated `NSMicrophoneUsageDescription` to mention voice and video calls

### 4. Android Manifest
**File**: `android/app/src/main/AndroidManifest.xml`

- Already has required permissions declared:
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`
- No changes needed

## How It Works

### Android 13+ (API 33+)
1. User initiates or accepts a call
2. `CallPermissionService.requestCallPermissions()` is called
3. Service checks current permission status
4. If not granted, shows system permission dialog
5. If permanently denied, shows settings dialog
6. Only proceeds with `getUserMedia()` if permissions are granted

### Android < 13 (API < 33)
- Same flow, but permissions are typically granted at install time
- Runtime requests still work for consistency

### iOS
1. User initiates or accepts a call
2. `CallPermissionService.requestCallPermissions()` is called
3. Service checks current permission status
4. If not granted, shows iOS system permission dialog
5. If permanently denied, shows settings dialog
6. Only proceeds with `getUserMedia()` if permissions are granted

### Web
- Browser handles permissions automatically via `getUserMedia()`
- Service returns `true` immediately
- Browser shows its own permission dialog when needed

## Permission Request Flow

```
User Action (Start/Accept Call)
    ↓
CallPermissionService.requestCallPermissions()
    ↓
Check Permission Status
    ↓
┌─────────────────┬─────────────────┬─────────────────┐
│   Already        │   Not Granted   │   Permanently   │
│   Granted        │                  │   Denied        │
└────────┬────────┴────────┬────────┴────────┬────────┘
         │                  │                 │
    Return true      Request Permission   Show Settings
         │                  │                 │
         │            ┌──────┴──────┐         │
         │            │             │         │
         │        Granted      Denied        │
         │            │             │         │
         └────────────┴─────────────┴────────┘
                      │
                 Return true/false
                      │
                 getUserMedia()
```

## Testing

### Test Android 13+ Permissions
1. Install app on Android 13+ device
2. Start a voice call
3. **Expected**: System permission dialog appears for microphone
4. Grant permission
5. **Expected**: Call proceeds normally
6. Start a video call
7. **Expected**: System permission dialogs appear for microphone and camera
8. Grant permissions
9. **Expected**: Video call proceeds normally

### Test Android < 13 Permissions
1. Install app on Android < 13 device
2. Start a call
3. **Expected**: Permissions may already be granted, or dialog appears
4. **Expected**: Call proceeds normally

### Test iOS Permissions
1. Install app on iOS device
2. Start a voice call
3. **Expected**: iOS permission dialog appears for microphone
4. Grant permission
5. **Expected**: Call proceeds normally
6. Start a video call
7. **Expected**: iOS permission dialogs appear for microphone and camera
8. Grant permissions
9. **Expected**: Video call proceeds normally

### Test Web Permissions
1. Open app in browser
2. Start a call
3. **Expected**: Browser permission dialog appears
4. Grant permission
5. **Expected**: Call proceeds normally

## Troubleshooting

### Permissions not requested on Android 13+
- **Check**: Ensure `CallPermissionService` is being called before `getUserMedia()`
- **Check**: Verify `permission_handler` package is up to date
- **Check**: Ensure Android manifest has permissions declared

### Permission dialog appears but call still fails
- **Check**: Verify permissions are actually granted (check app settings)
- **Check**: Ensure `getUserMedia()` is called after permissions are granted
- **Check**: Look for errors in logs

### iOS permission dialog doesn't appear
- **Check**: Verify `Info.plist` has permission descriptions
- **Check**: Ensure permissions haven't been permanently denied
- **Check**: Try resetting permissions in iOS Settings

### Web permissions not working
- **Check**: Ensure HTTPS is used (required for getUserMedia)
- **Check**: Browser console for permission errors
- **Check**: Browser settings for site permissions

## Summary

✅ **Android 13+**: Permissions are now explicitly requested before accessing media
✅ **Android < 13**: Permissions are requested for consistency
✅ **iOS**: Permissions are requested with proper descriptions
✅ **Web**: Browser handles permissions automatically
✅ **All Platforms**: Unified permission service ensures consistent behavior

The app now properly requests permissions on all platforms, ensuring calls work correctly on Android 13+ devices.

