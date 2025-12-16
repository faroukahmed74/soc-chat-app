package com.faroukahmed74.socchatapp

import android.content.Intent
import android.net.Uri
import android.media.MediaScannerConnection
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "soc_chat_app/media_scanner"
    private val INSTALL_CHANNEL = "soc_chat_app/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Media scanner channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
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
}
