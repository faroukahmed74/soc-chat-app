# Update UI Flow Report - What Happens When New Update is Available

## Overview
This document describes the complete UI flow when a new update is detected, covering both automatic and manual update checks.

---

## 🔄 Two Update Check Scenarios

### **Scenario 1: Automatic Update Check (Background)**
- **Trigger:** App startup (ChatListScreen `initState`)
- **Frequency:** Every 24 hours (configurable)
- **Location:** `lib/screens/chat_list_screen_mongodb.dart` line 244

### **Scenario 2: Manual Update Check (User-Initiated)**
- **Trigger:** User taps "Check for Updates" in Settings
- **Frequency:** On-demand
- **Location:** `lib/screens/settings_screen.dart` line 314

---

## 📱 Scenario 1: Automatic Update Check UI Flow

### **Step 1: Background Check (No UI)**
- App starts → `_maybeAutoCheckUpdate()` runs silently
- Checks if 24 hours have passed since last check
- If yes, fetches version from Dropbox
- **No UI shown during check**

### **Step 2: Update Found - Simple AlertDialog**
**Location:** `chat_list_screen_mongodb.dart` lines 1748-1798

**UI Elements:**
```
┌─────────────────────────────────────┐
│  New version available (1.0.28)     │  ← Title
├─────────────────────────────────────┤
│                                     │
│  [Scrollable Release Notes]         │  ← Content
│  SOC Chat App v1.0.28 - ...        │
│  - Feature 1                        │
│  - Feature 2                        │
│  ...                                │
│                                     │
├─────────────────────────────────────┤
│  [Later]  [Download]                │  ← Actions
└─────────────────────────────────────┘
```

**Dialog Details:**
- **Title:** "New version available (1.0.28)" - Shows latest version number
- **Content:** Scrollable text with full release notes
- **Actions:**
  - **"Later" Button:** Dismisses dialog, user can continue using app
  - **"Download" Button:** Opens download URL in external browser

**User Actions:**
1. **Tap "Later":**
   - Dialog closes
   - User continues using app
   - Update check will run again in 24 hours

2. **Tap "Download":**
   - Dialog closes
   - Opens download URL in external browser (Chrome, etc.)
   - User downloads APK manually from browser
   - **No in-app download progress shown**

---

## 📱 Scenario 2: Manual Update Check UI Flow

### **Step 1: User Initiates Check**
- User opens Settings screen
- Taps "Check for Updates" button
- **Loading indicator appears** (if `_isLoading` state is shown)

### **Step 2A: Update Found - Full UpdateDialog**
**Location:** `lib/widgets/update_dialog.dart`

**UI Elements:**
```
┌─────────────────────────────────────┐
│  🔄 Update Available                │  ← Title with icon
├─────────────────────────────────────┤
│                                     │
│  A new version of SOC Chat App      │
│  is available!                      │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Current Version: 1.0.27 (27)  │ │  ← Version info box
│  │ Latest Version:  1.0.28 (28)  │ │  ← (green text)
│  └───────────────────────────────┘ │
│                                     │
│  What's New:                        │
│  SOC Chat App v1.0.28 - ...         │  ← Release notes
│  - Feature 1                        │
│  - Feature 2                        │
│  ...                                │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ ⚠️ This update is required    │ │  ← Force update warning
│  │    to continue using app.     │ │  ← (if force_update: true)
│  └───────────────────────────────┘ │
│                                     │
├─────────────────────────────────────┤
│  [Later]  [Download Update]         │  ← Actions
└─────────────────────────────────────┘
```

**Dialog Features:**
- **Title:** "Update Available" with system update icon (🔄)
- **Version Comparison Box:**
  - Gray background container
  - Shows current version (e.g., 1.0.27 (27))
  - Shows latest version in **green** (e.g., 1.0.28 (28))
- **Release Notes Section:**
  - "What's New:" heading (bold)
  - Full release notes text
- **Force Update Warning (if applicable):**
  - Orange banner with warning icon
  - Text: "This update is required to continue using the app."
  - Only shown if `force_update: true` in version_info.json
- **Actions:**
  - **"Later" Button:** Only shown if `force_update != true`
  - **"Download Update" Button:** Primary action (blue/primary color)

**User Actions:**
1. **Tap "Later" (if available):**
   - Dialog closes
   - User continues using app

2. **Tap "Download Update":**
   - UpdateDialog closes
   - **DownloadProgressDialog appears** (see Step 3)

### **Step 2B: No Update Available**
**UI:** Green SnackBar at bottom of screen
```
┌─────────────────────────────────────┐
│  ✓ No updates available             │  ← Green background
└─────────────────────────────────────┘
```
- **Duration:** Default (4 seconds)
- **Color:** Green background
- **Message:** "No updates available"

### **Step 2C: Error During Check**
**UI:** Red SnackBar at bottom of screen
```
┌─────────────────────────────────────┐
│  ✗ Error checking for updates: ...  │  ← Red background
└─────────────────────────────────────┘
```
- **Duration:** Default (4 seconds)
- **Color:** Red background
- **Message:** Shows error details

---

## 📥 Step 3: Download Progress Dialog

**Location:** `lib/widgets/download_progress_dialog.dart`

**Triggered when:** User taps "Download Update" in UpdateDialog

### **Phase 1: Downloading**
```
┌─────────────────────────────────────┐
│  ⏳ Downloading Update               │  ← Title with spinner
├─────────────────────────────────────┤
│                                     │
│  ████████████░░░░░░░░░░  60.5%     │  ← Progress bar
│                                     │
│           60.5%                     │  ← Percentage (large, bold)
│                                     │
│  Downloading... 45.2 MB / 74.8 MB  │  ← Status message
│                                     │
├─────────────────────────────────────┤
│  [Cancel]                            │  ← Action (if downloading)
└─────────────────────────────────────┘
```

**UI Elements:**
- **Title:** "Downloading Update" with circular progress indicator
- **Progress Bar:** Linear progress indicator (0% to 100%)
- **Percentage:** Large, bold text showing exact percentage
- **Status Message:** Shows MB downloaded / MB total
- **Cancel Button:** Allows user to cancel download
- **Barrier Dismissible:** `false` (cannot dismiss by tapping outside)

**Progress Updates:**
- Real-time progress: 0.0% → 100.0%
- Status messages:
  - "Connecting to server..."
  - "Starting download..."
  - "Downloading... X.X MB / Y.Y MB"
  - "Download complete. Verifying..."
  - "Installing update..."

### **Phase 2: Download Complete**
```
┌─────────────────────────────────────┐
│  ✓ Download Complete                │  ← Title with checkmark
├─────────────────────────────────────┤
│                                     │
│            ✓                         │  ← Large green checkmark icon
│                                     │
│  Update downloaded successfully!    │
│  Preparing installation...          │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│                                     │  ← No actions (auto-closes)
└─────────────────────────────────────┘
```

**UI Elements:**
- **Title:** "Download Complete" with green checkmark icon
- **Icon:** Large green checkmark (✓)
- **Message:** "Update downloaded successfully!\nPreparing installation..."
- **Auto-Close:** Dialog closes automatically after 2 seconds
- **Next Step:** Android package installer opens automatically

### **Phase 3: Download Failed**
```
┌─────────────────────────────────────┐
│  ✗ Download Failed                  │  ← Title with error icon
├─────────────────────────────────────┤
│                                     │
│            ⚠️                        │  ← Large red error icon
│                                     │
│  Download failed. Please try again. │  ← Error message
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  [Retry]                            │  ← Action button
└─────────────────────────────────────┘
```

**UI Elements:**
- **Title:** "Download Failed" with red error icon
- **Icon:** Large red error outline icon
- **Error Message:** Specific error description
- **Retry Button:** Blue elevated button with refresh icon
- **User Can Dismiss:** Yes (can tap outside or back button)

**Error Messages:**
- "Connection timeout. Please check your internet connection."
- "Network error. Please check your internet connection."
- "Permission denied. Please grant storage permission in Settings."
- "Download failed after 3 attempts. [error details]"
- Generic: "Download failed. Please try again."

---

## 🔄 Complete User Journey

### **Automatic Check Flow:**
```
App Starts
    ↓
Background Check (24h interval)
    ↓
Update Found?
    ├─ No → Continue silently
    └─ Yes → Show Simple AlertDialog
              ├─ User taps "Later" → Dialog closes, continue app
              └─ User taps "Download" → Opens browser, manual download
```

### **Manual Check Flow:**
```
User opens Settings
    ↓
Taps "Check for Updates"
    ↓
Loading indicator (brief)
    ↓
Update Found?
    ├─ No → Green SnackBar "No updates available"
    ├─ Error → Red SnackBar with error message
    └─ Yes → Show Full UpdateDialog
              ├─ User taps "Later" → Dialog closes (if not forced)
              └─ User taps "Download Update" → DownloadProgressDialog
                    ├─ Downloading → Progress bar, percentage, MB
                    ├─ Complete → Success message, auto-close, install
                    └─ Failed → Error message, Retry button
```

---

## 🎨 UI Components Summary

| Component | Location | When Shown | Dismissible |
|-----------|----------|------------|-------------|
| **Simple AlertDialog** | ChatListScreen | Auto-check finds update | Yes (Later button) |
| **Full UpdateDialog** | Settings screen | Manual check finds update | Yes (if not forced) |
| **DownloadProgressDialog** | After Download tap | Download in progress | No (during download) |
| **Green SnackBar** | Settings screen | No update available | Auto-dismiss |
| **Red SnackBar** | Settings screen | Error during check | Auto-dismiss |

---

## 🔒 Force Update Behavior

### **When `force_update: true` in version_info.json:**

**UpdateDialog Changes:**
- ✅ Orange warning banner appears
- ✅ "Later" button is **HIDDEN**
- ✅ User **MUST** tap "Download Update"
- ✅ Dialog cannot be dismissed by back button
- ✅ User cannot continue using app without updating

**Visual:**
```
┌─────────────────────────────────────┐
│  🔄 Update Available                │
├─────────────────────────────────────┤
│  ...                                │
│  ┌───────────────────────────────┐ │
│  │ ⚠️ This update is required    │ │  ← Orange warning
│  │    to continue using app.     │ │
│  └───────────────────────────────┘ │
│  ...                                │
├─────────────────────────────────────┤
│           [Download Update]         │  ← Only button available
└─────────────────────────────────────┘
```

---

## 📊 Visual States

### **UpdateDialog States:**
1. **Normal Update:** Shows "Later" + "Download Update" buttons
2. **Force Update:** Only shows "Download Update" button
3. **With Release Notes:** Shows "What's New" section
4. **Without Release Notes:** Skips "What's New" section

### **DownloadProgressDialog States:**
1. **Downloading:** Progress bar, percentage, status message, Cancel button
2. **Complete:** Green checkmark, success message, auto-closes
3. **Error:** Red error icon, error message, Retry button

---

## 🎯 Key UI Features

### **✅ What Works Well:**
- Clear version comparison (current vs latest)
- Real-time download progress
- Visual feedback (icons, colors, progress bar)
- Force update enforcement (no "Later" button)
- Error handling with retry option
- User-friendly messages

### **📝 Notes:**
- Automatic check shows simpler dialog (opens browser)
- Manual check shows full dialog (in-app download)
- Download progress is only shown in manual check flow
- Force updates cannot be dismissed
- All dialogs are Android-only (not shown on iOS/Web)

---

## 📅 Last Updated
**Date:** December 15, 2025  
**Version:** 1.0.27  
**Author:** System Review

