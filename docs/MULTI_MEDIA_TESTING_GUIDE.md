# 📱 Multiple Media Selection & Download Testing Guide

## 🎯 Overview

This guide explains how to test the multiple media selection and download features in the SOC Chat App.

---

## 📤 **PART 1: Sending Multiple Media Files**

### **Current Implementation Status**

The `MultiMediaUploadWidget` has been created and is fully responsive, but it needs to be integrated into the chat input UI. Currently, the chat uses `EnhancedMediaSender` which only supports single media selection.

### **How to Access Multiple Media Selection (After Integration)**

Once integrated, the UI flow will be:

1. **Open a Chat**
   - Navigate to any chat conversation
   - Tap the **attachment icon** (📎) in the chat input bar

2. **Select Multiple Media Option**
   - In the media selection panel, you'll see:
     - **"Select Single File"** (current option)
     - **"Select Multiple Files"** (new option) ← Tap this

3. **Choose Multiple Files**
   - A file picker will open
   - **Hold and select multiple files** (or use multi-select if supported by platform)
   - You can select:
     - Multiple images
     - Multiple videos
     - Multiple audio files
     - Multiple documents
     - Mixed types (images + videos + documents)

4. **Review Selected Media**
   - A grid will appear showing all selected media thumbnails
   - Each thumbnail has:
     - Preview (image/video thumbnail or icon for documents)
     - File name
     - Remove button (X) to remove individual files

5. **Add Caption (Optional)**
   - Enter a caption that will be sent with all media files
   - The caption applies to all selected media

6. **Upload All**
   - Tap **"Send All"** button
   - Progress indicators will show for each file:
     - Individual progress bars
     - Upload status (Queued, Uploading, Completed, Failed)
     - Cancel button for each upload
   - Files upload concurrently (max 3 at a time)

7. **Completion**
   - When all uploads complete, all media files are sent as separate messages
   - Each file appears in the chat with the shared caption

### **Expected UI Behavior**

- **Mobile (< 600px)**:
  - 2-column grid for media thumbnails
  - Stacked buttons (Send All, Clear All)
  - Full-width buttons
  - Compact progress list

- **Tablet (600-900px)**:
  - 3-column grid for media thumbnails
  - Side-by-side buttons
  - Medium-sized progress list

- **Desktop (> 900px)**:
  - 4-column grid for media thumbnails
  - Side-by-side buttons
  - Larger progress list with more details

---

## 📥 **PART 2: Downloading Multiple Media Files**

### **Current Implementation**

Each media item in chat messages has its own download button. Multiple downloads can happen simultaneously.

### **How to Download Multiple Media Files**

#### **Method 1: Download from Chat Messages (Individual Downloads)**

1. **Open a Chat with Media**
   - Navigate to a chat that has media messages (images, videos, audio, documents)

2. **Download Individual Media**
   - For each media message, you'll see:
     - **Download icon** (⬇️) on the media preview
     - Or **long-press** the media to open context menu → **"Download"**

3. **Download Progress**
   - When you tap download, an **inline progress indicator** appears:
     - Overlay on the media item
     - Shows progress percentage
     - Shows status message ("Downloading...", "Saving...", etc.)
     - Shows file name
     - Cancel button (X) to stop download

4. **Multiple Simultaneous Downloads**
   - You can tap download on **multiple media items at once**
   - Each download has its own progress indicator
   - Downloads happen concurrently
   - No need to wait for one to finish before starting another

5. **Download Completion**
   - When download completes:
     - Progress indicator shows "Download complete!"
     - Green success message appears
     - Media is saved to:
       - **Android**: Gallery (images/videos) or Downloads folder (documents/audio)
       - **iOS**: Photos library (images/videos) or Files app (documents/audio)

#### **Method 2: Download from Media Gallery (Bulk Download)**

1. **Open Media Gallery**
   - In chat screen, tap the **gallery icon** (🖼️) in the app bar
   - Or use the media gallery feature if available

2. **View All Media**
   - All media from the chat is displayed in a grid
   - Filter by type (Images, Videos, Documents, Audio)

3. **Download Multiple Items**
   - **Long-press** on a media item to select it
   - **Tap other items** to select multiple
   - Tap **"Download Selected"** button
   - All selected items download simultaneously

4. **Progress Tracking**
   - Each download shows its own progress indicator
   - Progress list shows all active downloads
   - Can cancel individual downloads

---

## 🧪 **Testing Scenarios**

### **Test 1: Send Multiple Images**
1. Open a chat
2. Tap attachment icon
3. Select "Select Multiple Files"
4. Choose 3-5 images
5. Add caption: "Vacation photos"
6. Tap "Send All"
7. **Expected**: All images upload and appear in chat with caption

### **Test 2: Send Mixed Media Types**
1. Open a chat
2. Tap attachment icon
3. Select "Select Multiple Files"
4. Choose: 2 images + 1 video + 1 document
5. Add caption: "Mixed media"
6. Tap "Send All"
7. **Expected**: All files upload successfully, each appears as separate message

### **Test 3: Download Multiple Images from Chat**
1. Open a chat with multiple image messages
2. Tap download icon on first image
3. Immediately tap download on second image
4. Immediately tap download on third image
5. **Expected**: All three downloads start simultaneously, each shows its own progress indicator

### **Test 4: Cancel Upload**
1. Start uploading multiple large files
2. Tap cancel (X) on one upload
3. **Expected**: That upload stops, others continue

### **Test 5: Cancel Download**
1. Start downloading multiple large files
2. Tap cancel (X) on one download
3. **Expected**: That download stops, others continue

### **Test 6: Responsive Design**
1. Test on different screen sizes:
   - Small phone (320px)
   - Large phone (414px)
   - Tablet (768px)
   - Desktop (1920px)
2. **Expected**: UI adapts correctly, buttons are touch-friendly, layouts are readable

### **Test 7: Network Interruption**
1. Start uploading/downloading multiple files
2. Turn off Wi-Fi/mobile data
3. **Expected**: Uploads/downloads pause, show error, can retry

### **Test 8: Permission Handling**
1. On first download, deny storage permission
2. Try downloading again
3. **Expected**: Permission request appears, download works after granting

---

## 📋 **UI Elements to Look For**

### **Multiple Media Upload UI:**
- ✅ "Select Multiple Files" button
- ✅ Grid of selected media thumbnails
- ✅ Remove button (X) on each thumbnail
- ✅ Caption input field
- ✅ "Send All" button
- ✅ "Clear All" button
- ✅ Upload progress list with:
  - File name
  - Progress bar
  - Status message
  - Cancel button
  - Success/error icons

### **Download Progress UI:**
- ✅ Inline progress overlay on media item
- ✅ Progress percentage
- ✅ Status message
- ✅ File name
- ✅ Cancel button
- ✅ Success message on completion

---

## 🐛 **Known Issues / Integration Needed**

### **Multiple Media Selection:**
- ⚠️ `MultiMediaUploadWidget` exists but needs integration into `EnhancedMediaSender` or `EnhancedChatInput`
- ⚠️ Need to add "Select Multiple" button to media selection UI

### **Multiple Media Download:**
- ✅ Individual downloads work
- ⚠️ Bulk download from gallery needs implementation
- ✅ Simultaneous downloads work correctly

---

## 🔧 **Next Steps for Full Implementation**

1. **Integrate MultiMediaUploadWidget into EnhancedMediaSender:**
   - Add "Select Multiple Files" button
   - Show MultiMediaUploadWidget when multiple selection is chosen
   - Handle upload completion and send messages

2. **Add Bulk Download to Media Gallery:**
   - Add multi-select mode
   - Add "Download Selected" button
   - Handle multiple simultaneous downloads

3. **Test on All Platforms:**
   - Android (all versions)
   - iOS (all versions)
   - Web (all browsers)

---

## 📝 **Notes**

- Multiple uploads are limited to 3 concurrent uploads (configurable)
- Downloads have no limit on concurrent downloads
- All UI elements are fully responsive
- Progress indicators update in real-time
- Error handling includes retry options

