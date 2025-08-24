class VersionConfig {
  // Dropbox URLs for Android updates
  // Replace these with your actual Dropbox sharing links
  
  // JSON file containing version information
  static const String dropboxJsonUrl = 'https://dl.dropboxusercontent.com/scl/fi/bsr34voj7mtlyys8egff0/version_info.json?rlkey=qvx4vuus73b9z4lhzu2g7vltr&st=rko7ld9s&dl=1';
  
  // APK file for download
  static const String dropboxApkUrl = 'https://dl.dropboxusercontent.com/scl/fi/bsr34voj7mtlyys8egff0/app-release.apk?rlkey=qvx4vuus73b9z4lhzu2g7vltr&st=rko7ld9s&dl=1';
  
  // Update check interval (in hours)
  static const int updateCheckIntervalHours = 24;
  
  // Force update threshold (if current version is older than this, force update)
  static const int forceUpdateThresholdDays = 30;
  
  // Minimum supported version (versions below this will be forced to update)
  static const String minimumSupportedVersion = '1.0.0';
  
  // Update notification settings
  static const bool showUpdateNotifications = true;
  static const bool showBetaUpdates = false;
  
  // Download settings
  static const int downloadTimeoutSeconds = 300; // 5 minutes
  static const bool allowCellularDownload = false;
}
