# Android Update System Setup Guide

## Overview
This guide explains how to set up the Android-only update system for SOC Chat App. The system checks for updates from a JSON file in Dropbox and allows users to download and install APK updates.

## Features
- ✅ **Android Only**: Update functionality only appears on Android devices
- ✅ **Settings Integration**: "Check for Updates" option in Settings screen
- ✅ **Home Screen Display**: Current version shown on main screen with update button
- ✅ **Dropbox Integration**: Version checking from JSON file in Dropbox
- ✅ **Auto-Install**: Downloads APK and attempts automatic installation
- ✅ **Force Updates**: Option to require updates for app functionality

## Setup Steps

### 1. Upload Files to Dropbox

#### A. Version Info JSON
1. Upload `version_info.json` to your Dropbox
2. Get the sharing link
3. Replace `YOUR_JSON_FILE_ID` in `lib/services/version_check_service.dart`

#### B. APK File
1. Build your APK: `flutter build apk --release`
2. Upload the APK to Dropbox
3. Get the sharing link
4. Replace `YOUR_APK_FILE_ID` in `lib/services/version_check_service.dart`

### 2. Configure Version Service

Edit `lib/services/version_check_service.dart`:

```dart
static const String _dropboxJsonUrl = 'https://dl.dropboxusercontent.com/s/YOUR_ACTUAL_JSON_ID/version_info.json';
static const String _dropboxApkUrl = 'https://dl.dropboxusercontent.com/s/YOUR_ACTUAL_APK_ID/app-release.apk';
```

### 3. Update JSON File

Modify `version_info.json` with your actual version information:

```json
{
  "version": "1.0.2",
  "build_number": "3",
  "download_url": "https://dl.dropboxusercontent.com/s/YOUR_ACTUAL_APK_ID/app-release.apk",
  "release_notes": "Your actual release notes here",
  "force_update": false
}
```

## How It Works

### 1. Version Checking
- App compares current version with version in Dropbox JSON
- Supports semantic versioning (1.2.3) and build numbers
- Only shows updates when newer version is available

### 2. Update Process
- User taps "Check for Updates" in Settings or home screen
- App fetches version info from Dropbox
- If update available, shows update dialog
- Downloads APK to device's Downloads folder
- Attempts automatic installation

### 3. Platform Detection
- **Android**: Full update functionality
- **iOS**: No update UI (handled by TestFlight)
- **Web**: No update functionality
- **Other**: No update functionality

## User Experience

### Settings Screen
- Version information displayed dynamically
- "Check for Updates" button (Android only)
- Real-time version checking

### Home Screen
- Current app version displayed at bottom
- "Check Update" button for quick access
- Clean, unobtrusive design

### Update Dialog
- Shows version comparison
- Release notes display
- Download and install options
- Force update warnings (if applicable)

## Security Features

- **HTTPS Only**: All downloads use secure connections
- **Permission Handling**: Requests storage permission for downloads
- **File Validation**: Downloads to secure Downloads directory
- **User Control**: User must confirm download and installation

## Troubleshooting

### Common Issues

1. **JSON Not Found**
   - Check Dropbox sharing link
   - Ensure file is publicly accessible
   - Verify JSON format is valid

2. **APK Download Fails**
   - Check APK sharing link
   - Verify file size and format
   - Check network connectivity

3. **Installation Fails**
   - Enable "Install from Unknown Sources"
   - Check device storage space
   - Verify APK compatibility

### Debug Information

Check console logs for:
- `[VersionCheck]` prefixed messages
- HTTP response status codes
- File download progress
- Installation attempts

## Maintenance

### Regular Tasks
1. **Update JSON**: When releasing new versions
2. **Upload APK**: After successful builds
3. **Test Updates**: Verify on test devices
4. **Monitor Logs**: Check for errors

### Version Management
- Increment version numbers consistently
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Update build numbers for each release
- Maintain release notes

## Example Workflow

1. **Build New Version**
   ```bash
   flutter build apk --release --build-number=4
   ```

2. **Update JSON**
   ```json
   {
     "version": "1.0.3",
     "build_number": "4",
     "download_url": "https://dl.dropboxusercontent.com/s/NEW_APK_ID/app-release.apk"
   }
   ```

3. **Upload Files**
   - Upload new APK to Dropbox
   - Update JSON file in Dropbox
   - Update service URLs if needed

4. **Test Update**
   - Install old version on test device
   - Check for updates
   - Verify download and installation

## Support

For issues or questions:
- Check console logs for error messages
- Verify Dropbox file accessibility
- Test on different Android versions
- Ensure proper file permissions
