# Android Update Behavior Report

## Overview
This document describes the complete update flow for the SOC Chat App on Android, covering UI, client-side, and server-side behavior.

---

## 🔄 Update Flow Architecture

### **Server Side (Dropbox)**
The update mechanism uses Dropbox as a simple CDN to host:
1. **version_info.json** - Contains version metadata
2. **app-release.apk** - The actual APK file

**Configuration:**
- JSON URL: `https://dl.dropboxusercontent.com/scl/fi/gw7fksg131be66f9254hu/version_info.json?rlkey=...&dl=1`
- APK URL: `https://dl.dropboxusercontent.com/scl/fi/bsr34voj7mtlyys8egff0/app-release.apk?rlkey=...&dl=1`

**version_info.json Structure:**
```json
{
  "version": "1.0.27",
  "build_number": "27",
  "download_url": "https://dl.dropboxusercontent.com/.../app-release.apk?rlkey=...",
  "release_notes": "SOC Chat App v1.0.27 - Contact Permissions & Stability Update:\n- Fixed contact picker...",
  "force_update": false,
  "minimum_version": "1.0.5",
  "update_available": true,
  "last_updated": "2025-12-15T17:30:00Z"
}
```

**Server Responsibilities:**
- ✅ Host version_info.json file
- ✅ Host APK file
- ✅ Provide direct download links (dl=1 parameter)
- ❌ No server-side logic or API endpoints
- ❌ No user tracking or analytics
- ❌ No authentication required

---

## 📱 Client Side (Android App)

### **1. Update Check Triggers**

#### **A. Automatic Check (Background)**
- **When:** App starts (in `initState` of `ChatListScreen`)
- **Frequency:** Every 24 hours (configurable in `VersionConfig.updateCheckIntervalHours`)
- **Method:** `_maybeAutoCheckUpdate()` in `chat_list_screen_mongodb.dart`
- **Storage:** Uses `SharedPreferences` to track last check time (`last_update_check_ms`)

**Code Flow:**
```dart
// Line 244: chat_list_screen_mongodb.dart
_maybeAutoCheckUpdate();

// Line 1726-1799: Auto-check logic
1. Check if 24 hours have passed since last check
2. If yes, call VersionCheckService.checkForUpdates()
3. If update found, show AlertDialog
4. Save current timestamp to SharedPreferences
```

#### **B. Manual Check (User-Initiated)**
- **When:** User taps "Check for Updates" in Settings screen
- **Method:** `_checkForUpdates()` in `settings_screen.dart`
- **UI:** Shows loading indicator, then UpdateDialog or "No updates" message

### **2. Version Comparison Logic**

**Service:** `FixedVersionCheckService.checkForUpdates()`

**Process:**
1. **Read Local Version:**
   - Loads `version_info.json` from app assets (bundled at build time)
   - Extracts: `version` (e.g., "1.0.26") and `build_number` (e.g., "26")

2. **Fetch Remote Version:**
   - HTTP GET request to Dropbox JSON URL
   - Timeout: 30 seconds
   - Headers: `User-Agent: SOC-Chat-App/1.0.0`

3. **Version Comparison:**
   ```dart
   // Compares version strings (e.g., "1.2.3")
   // Splits by '.' and compares each part numerically
   // If versions equal, compares build numbers
   // Returns true if latest > current
   ```

**Comparison Algorithm:**
- Compares major.minor.patch (e.g., 1.0.27 vs 1.0.26)
- If versions equal, compares build numbers (27 vs 26)
- Returns `hasUpdate: true` if remote is newer

### **3. Update Detection Response**

**Return Value:**
```dart
{
  'hasUpdate': bool,           // true if update available
  'currentVersion': '1.0.26',   // Current app version
  'currentBuildNumber': '26',   // Current build number
  'latestVersion': '1.0.27',   // Latest available version
  'latestBuildNumber': '27',   // Latest build number
  'downloadUrl': 'https://...', // APK download URL
  'releaseNotes': '...',        // Release notes string
  'forceUpdate': false,         // Whether update is mandatory
  'platform': 'android'        // Platform identifier
}
```

---

## 🎨 UI Side (User Experience)

### **1. Automatic Update Dialog**

**When Update is Found:**
- **Location:** `chat_list_screen_mongodb.dart` (lines 1748-1798)
- **Type:** Simple `AlertDialog` (not the full `UpdateDialog` widget)
- **Content:**
  - Title: "New version available (1.0.27)"
  - Body: Scrollable release notes
  - Actions:
    - "Later" button - Dismisses dialog
    - "Download" button - Opens download URL in browser

**Dialog Code:**
```dart
AlertDialog(
  title: Text('New version available ($latest)'),
  content: SingleChildScrollView(child: Text(notes)),
  actions: [
    TextButton('Later') -> Navigator.pop(),
    TextButton('Download') -> launchUrl(downloadUrl)
  ]
)
```

**User Actions:**
1. **Tap "Later":**
   - Dialog closes
   - User can continue using app
   - Update check will run again in 24 hours

2. **Tap "Download":**
   - Opens download URL in external browser
   - Uses `LaunchMode.platformDefault` (Android 13+ compatible)
   - Falls back to `LaunchMode.externalApplication` if needed
   - User downloads APK manually from browser

### **2. Manual Update Dialog (Settings)**

**When User Taps "Check for Updates":**
- **Location:** `settings_screen.dart` (lines 314-359)
- **Type:** Full `UpdateDialog` widget (more detailed)
- **Shows:**
  - Loading indicator while checking
  - If update found: `UpdateDialog` with full details
  - If no update: Green SnackBar "No updates available"
  - If error: Red SnackBar with error message

**UpdateDialog Features:**
- **Title:** "Update Available" with system update icon
- **Version Info Box:**
  - Current Version: 1.0.26 (26)
  - Latest Version: 1.0.27 (27) [in green]
- **Release Notes:** Full "What's New" section
- **Force Update Warning:** Orange banner if `force_update: true`
- **Actions:**
  - "Later" button (only if not forced)
  - "Download Update" button (primary action)

**User Actions:**
1. **Tap "Later" (if available):**
   - Dialog closes
   - User continues using app

2. **Tap "Download Update":**
   - Dialog closes
   - Calls `FixedVersionCheckService.downloadAndInstallUpdate()`
   - Shows "Downloading update..." SnackBar
   - Downloads APK to Downloads folder
   - Attempts auto-install
   - Shows success/error message

### **3. Download & Install Flow**

**Process:**
1. **Permission Check:**
   - Android 13+: Requests `manageExternalStorage`
   - Android <13: Requests `storage` permission
   - Shows error if permission denied

2. **Download:**
   - HTTP GET request to APK URL
   - Timeout: 5 minutes
   - Saves to: `Downloads/soc_chat_app_update.apk`
   - Shows "Downloading update..." SnackBar

3. **Install Attempt:**
   - Tries to auto-install using Android Package Installer
   - Command: `am start -a android.intent.action.VIEW -d file://... -t application/vnd.android.package-archive`
   - If successful: Shows "Update downloaded successfully! Please install manually."
   - If fails: Opens file manager to Downloads folder

4. **User Experience:**
   - APK opens in system package installer
   - User sees Android's standard install prompt
   - User must tap "Install" to proceed
   - After install, user can open updated app

---

## 📊 Update Behavior Summary

### **Automatic Check (Background)**
| Aspect | Details |
|--------|---------|
| **Trigger** | App startup (ChatListScreen initState) |
| **Frequency** | Every 24 hours |
| **UI** | Simple AlertDialog |
| **User Action** | "Later" or "Download" (opens browser) |
| **Silent** | Yes, only shows if update found |

### **Manual Check (Settings)**
| Aspect | Details |
|--------|---------|
| **Trigger** | User taps "Check for Updates" |
| **Frequency** | On-demand |
| **UI** | Full UpdateDialog with details |
| **User Action** | "Later" or "Download Update" (in-app download) |
| **Loading** | Shows loading indicator |

### **Download Methods**
| Method | Used By | Behavior |
|--------|---------|----------|
| **Browser Download** | Auto-check dialog | Opens URL in external browser |
| **In-App Download** | Manual check dialog | Downloads APK directly, attempts install |

---

## 🔍 Key Observations

### **✅ What Works Well:**
1. **Simple Architecture:** No complex server infrastructure needed
2. **Flexible:** Supports both browser and in-app downloads
3. **User-Friendly:** Clear dialogs with release notes
4. **Efficient:** 24-hour check interval prevents excessive requests
5. **Platform-Aware:** Handles Android 13+ permission differences

### **⚠️ Potential Issues:**

1. **No Download Progress:**
   - Download happens silently
   - No progress bar or percentage shown
   - User doesn't know download status

2. **No Background Download:**
   - Download requires app to stay open
   - If app closes, download may fail

3. **Manual Install Required:**
   - Even with auto-install attempt, user must confirm
   - No silent/automatic installation

4. **No Update Verification:**
   - Doesn't verify APK signature
   - Doesn't check file integrity
   - Relies on HTTPS only

5. **Error Handling:**
   - Network errors show generic messages
   - No retry mechanism
   - No offline detection

6. **Force Update Not Enforced:**
   - `force_update: true` only shows warning
   - User can still dismiss and continue
   - No app blocking mechanism

### **🔧 Recommendations:**

1. **Add Download Progress:**
   - Show progress bar during download
   - Display download speed and ETA

2. **Implement Force Update Blocking:**
   - If `force_update: true`, disable "Later" button
   - Show blocking overlay until update installed

3. **Add Retry Logic:**
   - Retry failed downloads automatically
   - Show retry button on errors

4. **Improve Error Messages:**
   - More specific error messages
   - Network error vs. permission error vs. file error

5. **Add Update Verification:**
   - Verify APK signature before install
   - Check file size matches expected

---

## 📝 Code Locations

### **Update Check Services:**
- `lib/services/version_check_service.dart` - Basic version check
- `lib/services/fixed_version_check_service.dart` - Enhanced version check with platform handling

### **UI Components:**
- `lib/widgets/update_dialog.dart` - Full update dialog widget
- `lib/screens/chat_list_screen_mongodb.dart` - Auto-check logic (line 1726)
- `lib/screens/settings_screen.dart` - Manual check (line 314)

### **Configuration:**
- `lib/config/version_config.dart` - Update check interval, URLs
- `version_info.json` - Local version info (bundled in app)

---

## 🧪 Testing Scenarios

### **Test Case 1: Automatic Update Check**
1. Install app with version 1.0.26
2. Update version_info.json on Dropbox to 1.0.27
3. Launch app
4. **Expected:** AlertDialog appears after 24 hours (or immediately if first launch)

### **Test Case 2: Manual Update Check**
1. Open Settings
2. Tap "Check for Updates"
3. **Expected:** Loading indicator → UpdateDialog or "No updates" message

### **Test Case 3: Download & Install**
1. Trigger update dialog
2. Tap "Download Update"
3. **Expected:** 
   - Permission prompt (if needed)
   - Download SnackBar
   - APK saved to Downloads
   - Install prompt appears

### **Test Case 4: Force Update**
1. Set `force_update: true` in version_info.json
2. Check for updates
3. **Expected:** Orange warning banner, but "Later" button still available (not enforced)

---

## 📈 Update Statistics (Not Tracked)

**Current Implementation:**
- ❌ No analytics on update checks
- ❌ No tracking of update acceptance rate
- ❌ No monitoring of download success/failure
- ❌ No user version distribution data

**Recommendation:** Add optional analytics to track:
- Update check frequency
- Update acceptance rate
- Download success rate
- Version distribution

---

## 🔐 Security Considerations

### **Current Security:**
- ✅ HTTPS for all downloads
- ✅ Direct download links (no redirects)
- ⚠️ No APK signature verification
- ⚠️ No file integrity checks

### **Recommendations:**
1. Verify APK signature before installation
2. Check file hash/size matches expected
3. Implement certificate pinning for Dropbox URLs
4. Add checksum verification

---

## 📅 Last Updated
**Date:** December 15, 2025  
**Version:** 1.0.27  
**Author:** System Review

