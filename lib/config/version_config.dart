class VersionConfig {
  // Dropbox URLs for Android updates (use direct download endpoints)
  // Ensure links use dl.dropboxusercontent.com and dl=1 for raw access
  
  // JSON file containing version information (Dropbox direct link)
  static const String dropboxJsonUrl = 'https://dl.dropboxusercontent.com/scl/fi/gw7fksg131be66f9254hu/version_info.json?rlkey=sqlwp6ah3ycsat3bo854cdow4&st=jjtf2vte&dl=1';
  
  // APK file for download (Dropbox direct link)
  static const String dropboxApkUrl = 'https://dl.dropboxusercontent.com/scl/fi/bsr34voj7mtlyys8egff0/app-release.apk?rlkey=qvx4vuus73b9z4lhzu2g7vltr&st=33b8ivxm&dl=1';
  
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
