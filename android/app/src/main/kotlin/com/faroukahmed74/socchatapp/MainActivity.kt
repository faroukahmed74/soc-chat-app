package com.faroukahmed74.socchatapp

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.media.MediaScannerConnection
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "soc_chat_app/media_scanner"
    private val GALLERY_CHANNEL = "soc_chat_app/gallery"
    private val INSTALL_CHANNEL = "soc_chat_app/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Media scanner channel (for legacy support)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_SCANNER_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "Path is null or empty", null)
                } else {
                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(path),
                        null,
                        null
                    )
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Gallery save channel (using MediaStore API)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GALLERY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToGallery" -> {
                    val path = call.argument<String>("path")
                    val isVideo = call.argument<Boolean>("isVideo") ?: false
                    val albumName = call.argument<String>("albumName") ?: "SOC Chat"
                    
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            android.util.Log.e("MainActivity", "File not found: $path")
                            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                            return@setMethodCallHandler
                        }
                        
                        if (!file.canRead()) {
                            android.util.Log.e("MainActivity", "File not readable: $path")
                            result.error("FILE_NOT_READABLE", "File is not readable: $path", null)
                            return@setMethodCallHandler
                        }
                        
                        android.util.Log.d("MainActivity", "Attempting to save file: $path, isVideo=$isVideo, albumName=$albumName")
                        val uri = saveToGallery(file, isVideo, albumName)
                        if (uri != null) {
                            android.util.Log.i("MainActivity", "Successfully saved to gallery: $uri")
                            result.success(uri.toString())
                        } else {
                            android.util.Log.e("MainActivity", "saveToGallery returned null for file: $path")
                            result.error("SAVE_FAILED", "Failed to save to gallery. MediaStore insert returned null. This might be a permission issue. Check logcat for details.", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Exception saving to gallery: ${e.message}", e)
                        result.error("SAVE_ERROR", "Error saving to gallery: ${e.message}", e.stackTraceToString())
                    }
                }
                "saveToDownloads" -> {
                    val path = call.argument<String>("path")
                    val fileName = call.argument<String>("fileName") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                            return@setMethodCallHandler
                        }
                        
                        val uri = saveToDownloads(file, fileName, mimeType)
                        if (uri != null) {
                            result.success(uri.toString())
                        } else {
                            result.error("SAVE_FAILED", "Failed to save to downloads", null)
                        }
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", "Error saving to downloads: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // APK installer channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALL_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val apkPath = call.argument<String>("apkPath")
                val useFileProvider = call.argument<Boolean>("useFileProvider") ?: true
                
                if (apkPath.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "APK path is null or empty", null)
                    return@setMethodCallHandler
                }
                
                try {
                    val file = File(apkPath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file not found: $apkPath", null)
                        return@setMethodCallHandler
                    }
                    
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        
                        val apkUri = if (useFileProvider && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                            // Use FileProvider for Android 7+ (API 24+), including Android 13+ (API 33+)
                            // FileProvider is required for secure file sharing on Android 7+
                            FileProvider.getUriForFile(
                                applicationContext,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                        } else {
                            // Use file URI for older Android versions (Android 6.0 and below)
                            Uri.fromFile(file)
                        }
                        
                        setDataAndType(apkUri, "application/vnd.android.package-archive")
                    }
                    
                    // Start the installation activity
                    // This will open the system installation dialog on all Android versions including 13+
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_FAILED", "Failed to install APK: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Save image or video to gallery using MediaStore API
     * Works for both Android 13+ (API 33+) and below
     */
    private fun saveToGallery(file: File, isVideo: Boolean, albumName: String): Uri? {
        return try {
            // Verify file exists and is readable
            if (!file.exists()) {
                android.util.Log.e("MainActivity", "File does not exist: ${file.absolutePath}")
                return null
            }
            
            if (!file.canRead()) {
                android.util.Log.e("MainActivity", "File is not readable: ${file.absolutePath}")
                return null
            }
            
            val contentResolver = applicationContext.contentResolver
            // Sanitize filename - remove emojis and special characters that might cause issues
            var fileName = file.name
            // Remove emojis and keep only alphanumeric, dots, hyphens, underscores
            fileName = fileName.replace(Regex("[^\\w\\s.-]"), "").trim()
            // Ensure filename has extension
            if (!fileName.contains(".")) {
                val originalExt = file.absolutePath.substringAfterLast(".", "")
                fileName = if (originalExt.isNotEmpty()) "image_${System.currentTimeMillis()}.$originalExt" else "image_${System.currentTimeMillis()}.jpg"
            }
            // Limit filename length
            if (fileName.length > 100) {
                val ext = fileName.substringAfterLast(".", "")
                val nameWithoutExt = fileName.substringBeforeLast(".", fileName)
                fileName = nameWithoutExt.take(90) + "." + ext
            }
            
            android.util.Log.d("MainActivity", "Original filename: ${file.name}, Sanitized: $fileName")
            
            val mimeType = if (isVideo) {
                when (fileName.substringAfterLast(".", "").lowercase()) {
                    "mp4" -> "video/mp4"
                    "mov" -> "video/quicktime"
                    "avi" -> "video/x-msvideo"
                    "mkv" -> "video/x-matroska"
                    "webm" -> "video/webm"
                    else -> "video/mp4"
                }
            } else {
                when (fileName.substringAfterLast(".", "").lowercase()) {
                    "jpg", "jpeg" -> "image/jpeg"
                    "png" -> "image/png"
                    "gif" -> "image/gif"
                    "webp" -> "image/webp"
                    "bmp" -> "image/bmp"
                    else -> "image/jpeg"
                }
            }
            
            android.util.Log.d("MainActivity", "Saving to gallery: fileName=$fileName, mimeType=$mimeType, isVideo=$isVideo, albumName=$albumName, SDK=${Build.VERSION.SDK_INT}")
            
            // For Android <10 (API <29), use legacy file-based approach with MediaScannerConnection
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                android.util.Log.d("MainActivity", "Using legacy file-based approach for Android <10")
                return saveToGalleryLegacy(file, fileName, isVideo, albumName, mimeType)
            }
            
            // For Android 10+ (API 29+), use MediaStore with RELATIVE_PATH
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                
                // Try with album name first, fallback to root directory if that fails
                val relativePath = if (isVideo) {
                    Environment.DIRECTORY_MOVIES + "/$albumName"
                } else {
                    Environment.DIRECTORY_PICTURES + "/$albumName"
                }
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            
            android.util.Log.d("MainActivity", "Attempting to insert into collection: $collection")
            var uri = contentResolver.insert(collection, contentValues)
            
            if (uri == null) {
                android.util.Log.w("MainActivity", "Failed to insert with album name, trying root directory...")
                
                // Try again without album name (save to root Pictures/Movies directory)
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                contentValues.put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                contentValues.put(MediaStore.MediaColumns.RELATIVE_PATH, if (isVideo) {
                    Environment.DIRECTORY_MOVIES
                } else {
                    Environment.DIRECTORY_PICTURES
                })
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 1)
                
                uri = contentResolver.insert(collection, contentValues)
                if (uri == null) {
                    android.util.Log.e("MainActivity", "Failed to insert media even without album name. Falling back to legacy method.")
                    // Fallback to legacy method
                    return saveToGalleryLegacy(file, fileName, isVideo, albumName, mimeType)
                }
                android.util.Log.i("MainActivity", "Successfully inserted without album name, using fallback URI: $uri")
            }
            
            // Use helper method to save file to URI
            return saveFileToUri(uri, file, contentResolver, contentValues, mimeType)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in saveToGallery: ${e.message}", e)
            e.printStackTrace()
            return             null
        }
    }
    
    /**
     * Legacy method for Android <10: Save to file system and use MediaScannerConnection
     */
    private fun saveToGalleryLegacy(file: File, fileName: String, isVideo: Boolean, albumName: String, mimeType: String): Uri? {
        return try {
            val directory = if (isVideo) {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            } else {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            }
            
            // Create album directory if it doesn't exist
            val albumDir = File(directory, albumName)
            if (!albumDir.exists()) {
                val created = albumDir.mkdirs()
                android.util.Log.d("MainActivity", "Created album directory: $albumDir, success: $created")
            }
            
            // Copy file to album directory
            val targetFile = File(albumDir, fileName)
            // Handle file name conflicts
            var finalFile = targetFile
            var counter = 1
            while (finalFile.exists()) {
                val nameWithoutExt = fileName.substringBeforeLast(".", fileName)
                val ext = fileName.substringAfterLast(".", "")
                finalFile = File(albumDir, "${nameWithoutExt}_$counter.$ext")
                counter++
            }
            
            file.copyTo(finalFile, overwrite = true)
            android.util.Log.d("MainActivity", "File copied to: ${finalFile.absolutePath}")
            
            // Trigger media scan to make it appear in gallery
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(finalFile.absolutePath),
                arrayOf(mimeType),
                null
            )
            
            android.util.Log.i("MainActivity", "Successfully saved to gallery using legacy method: ${finalFile.absolutePath}")
            Uri.fromFile(finalFile)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in saveToGalleryLegacy: ${e.message}", e)
            e.printStackTrace()
            null
        }
    }
    
    /**
     * Helper method to save file content to MediaStore URI
     */
    private fun saveFileToUri(uri: Uri, file: File, contentResolver: android.content.ContentResolver, contentValues: ContentValues, mimeType: String): Uri? {
        return try {
            // Copy file content to MediaStore
            contentResolver.openOutputStream(uri, "w")?.use { outputStream ->
                FileInputStream(file).use { inputStream ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    var totalBytes = 0L
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                        totalBytes += bytesRead
                    }
                    outputStream.flush()
                    android.util.Log.d("MainActivity", "Copied $totalBytes bytes to MediaStore")
                }
            } ?: run {
                android.util.Log.e("MainActivity", "Failed to open output stream for URI: $uri")
                // Delete the inserted entry if we can't write to it
                try {
                    contentResolver.delete(uri, null, null)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to delete failed entry: ${e.message}")
                }
                return null
            }
            
            // Mark as not pending (Android 10+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    val updateResult = contentResolver.update(uri, contentValues, null, null)
                    if (updateResult == 0) {
                        android.util.Log.w("MainActivity", "Failed to update IS_PENDING flag, but file was saved")
                    } else {
                        android.util.Log.d("MainActivity", "Successfully updated IS_PENDING flag")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error updating IS_PENDING flag: ${e.message}")
                    // File was saved, so we can still return success
                }
            }
            
            // Media scan is handled in legacy method for Android <10
            // For Android 10+, MediaStore automatically makes files visible
            
            android.util.Log.i("MainActivity", "Successfully saved media to gallery: $uri")
            return uri
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error saving file to URI: ${e.message}", e)
            // Delete the inserted entry if write failed
            try {
                contentResolver.delete(uri, null, null)
            } catch (deleteException: Exception) {
                android.util.Log.e("MainActivity", "Failed to delete failed entry: ${deleteException.message}")
            }
            return null
        }
    }
    
    /**
     * Save document/audio file to Downloads using MediaStore API
     * Works for both Android 10+ (API 29+) and below
     */
    private fun saveToDownloads(file: File, fileName: String, mimeType: String): Uri? {
        return try {
            val contentResolver = applicationContext.contentResolver
            val displayName = if (fileName.isNotEmpty()) fileName else file.name
            
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/SOC Chat")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
            }
            
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                // For Android 9 and below, use MediaStore but with different approach
                // We'll save to Downloads folder and trigger media scan
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val socChatDir = File(downloadsDir, "SOC Chat")
                if (!socChatDir.exists()) {
                    socChatDir.mkdirs()
                }
                val targetFile = File(socChatDir, displayName)
                file.copyTo(targetFile, overwrite = true)
                
                // Trigger media scan for older Android versions
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(targetFile.absolutePath),
                    arrayOf(mimeType),
                    null
                )
                
                return Uri.fromFile(targetFile)
            }
            
            val uri = contentResolver.insert(collection, contentValues)
            
            if (uri != null) {
                // Copy file content to MediaStore
                contentResolver.openOutputStream(uri)?.use { outputStream ->
                    FileInputStream(file).use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
                
                // Mark as not pending (Android 10+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    contentValues.clear()
                    contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                    contentResolver.update(uri, contentValues, null, null)
                }
                
                uri
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
