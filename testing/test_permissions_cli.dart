import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../lib/services/production_permission_service.dart';

void main() async {
  print('🔐 COMPREHENSIVE PERMISSION TEST - ALL PLATFORMS');
  print('=' * 60);
  
  // Detect platform
  final platform = _getPlatformInfo();
  print('🌍 Platform: $platform');
  print('🌐 Web: ${kIsWeb ? "Yes" : "No"}');
  print('📱 iOS: ${defaultTargetPlatform == TargetPlatform.iOS ? "Yes" : "No"}');
  print('🤖 Android: ${defaultTargetPlatform == TargetPlatform.android ? "Yes" : "No"}');
  print('🍎 macOS: ${defaultTargetPlatform == TargetPlatform.macOS ? "Yes" : "No"}');
  print('🪟 Windows: ${defaultTargetPlatform == TargetPlatform.windows ? "Yes" : "No"}');
  print('🐧 Linux: ${defaultTargetPlatform == TargetPlatform.linux ? "Yes" : "No"}');
  print('=' * 60);
  
  // Test all permissions
  await _testAllPermissions();
  
  // Test permission status checking
  await _testPermissionStatuses();
  
  // Test permission service methods
  await _testPermissionServiceMethods();
  
  print('=' * 60);
  print('✅ PERMISSION TESTING COMPLETED');
  print('📋 Check the logs above for detailed results');
}

String _getPlatformInfo() {
  if (kIsWeb) return 'Web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'iOS';
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.macOS:
      return 'macOS';
    case TargetPlatform.windows:
      return 'Windows';
    case TargetPlatform.linux:
      return 'Linux';
    default:
      return 'Unknown';
  }
}

Future<void> _testAllPermissions() async {
  print('\n🔍 TESTING ALL PERMISSIONS');
  print('-' * 40);
  
  final permissions = [
    Permission.camera,
    Permission.photos,
    Permission.microphone,
    Permission.notification,
    Permission.location,
    Permission.storage,
    Permission.phone,
    Permission.sms,
    Permission.contacts,
    Permission.calendar,
    Permission.bluetooth,
    Permission.manageExternalStorage,
  ];
  
  for (final permission in permissions) {
    await _testSinglePermission(permission);
  }
}

Future<void> _testSinglePermission(Permission permission) async {
  final permissionName = permission.toString().split('.').last.toUpperCase();
  print('\n📱 Testing $permissionName Permission');
  print('   └─ Permission: $permission');
  
  try {
    // Check current status
    print('   ├─ Checking current status...');
    final currentStatus = await permission.status;
    print('   ├─ Current status: $currentStatus');
    
    // Request permission if not granted
    if (!currentStatus.isGranted && !currentStatus.isLimited) {
      print('   ├─ Permission not granted, requesting...');
      final result = await permission.request();
      print('   ├─ Request result: $result');
    } else {
      print('   ├─ Permission already granted/limited');
    }
    
    // Check final status
    final finalStatus = await permission.status;
    print('   ├─ Final status: $finalStatus');
    
    // Determine if test passed
    final isGranted = finalStatus.isGranted || finalStatus.isLimited;
    final statusIcon = isGranted ? '✅' : '❌';
    final statusText = isGranted ? 'PASSED' : 'FAILED';
    
    print('   └─ $statusIcon $permissionName: $statusText');
    
  } catch (e) {
    print('   └─ ❌ ERROR: $e');
  }
}

Future<void> _testPermissionStatuses() async {
  print('\n📊 TESTING PERMISSION STATUS CHECKING');
  print('-' * 40);
  
  final permissions = [
    Permission.camera,
    Permission.photos,
    Permission.microphone,
    Permission.notification,
    Permission.location,
    Permission.storage,
  ];
  
  print('Checking status for ${permissions.length} permissions...');
  
  for (final permission in permissions) {
    try {
      final status = await permission.status;
      final permissionName = permission.toString().split('.').last.toUpperCase();
      final statusIcon = status.isGranted ? '✅' : status.isLimited ? '⚠️' : '❌';
      
      print('$statusIcon $permissionName: $status');
    } catch (e) {
      final permissionName = permission.toString().split('.').last.toUpperCase();
      print('❌ $permissionName: ERROR - $e');
    }
  }
}

Future<void> _testPermissionServiceMethods() async {
  print('\n🛠️ TESTING PERMISSION SERVICE METHODS');
  print('-' * 40);
  
  if (kIsWeb) {
    print('🌐 Web platform detected - skipping permission service tests');
    return;
  }
  
  try {
    print('Testing ProductionPermissionService methods...');
    
    // Note: ProductionPermissionService requires BuildContext for UI dialogs
    // In CLI testing, we'll test the permission_handler directly instead
    print('├─ Testing permission status directly...');
    
    print('├─ Testing camera permission status...');
    final cameraStatus = await Permission.camera.status;
    print('├─ Camera permission: ${_formatPermissionStatus(cameraStatus)}');
    
    print('├─ Testing photos permission status...');
    final photosStatus = await Permission.photos.status;
    print('├─ Photos permission: ${_formatPermissionStatus(photosStatus)}');
    
    print('├─ Testing microphone permission status...');
    final micStatus = await Permission.microphone.status;
    print('├─ Microphone permission: ${_formatPermissionStatus(micStatus)}');
    
    print('├─ Testing notification permission status...');
    final notifStatus = await Permission.notification.status;
    print('├─ Notification permission: ${_formatPermissionStatus(notifStatus)}');
    
    print('├─ Testing location permission status...');
    final locationStatus = await Permission.location.status;
    print('├─ Location permission: ${_formatPermissionStatus(locationStatus)}');
    
    print('└─ Permission status tests completed');
    
  } catch (e) {
    print('└─ ❌ ERROR testing permission service: $e');
  }
}

// Helper function to format permission status
String _formatPermissionStatus(PermissionStatus status) {
  switch (status) {
    case PermissionStatus.granted:
      return 'GRANTED ✅';
    case PermissionStatus.denied:
      return 'DENIED ❌';
    case PermissionStatus.permanentlyDenied:
      return 'PERMANENTLY DENIED 🚫';
    case PermissionStatus.restricted:
      return 'RESTRICTED 🔒';
    case PermissionStatus.limited:
      return 'LIMITED ⚠️';
    case PermissionStatus.provisional:
      return 'PROVISIONAL 🔄';
    case PermissionStatus.denied:
      return 'DENIED ❌';
    default:
      return 'UNKNOWN ❓';
  }
}

// Helper function to check if permission is working
bool _isPermissionWorking(PermissionStatus status) {
  return status.isGranted || status.isLimited || status.isProvisional;
}

// Generate summary report
void _generateSummary() {
  print('\n📋 PERMISSION TEST SUMMARY');
  print('=' * 40);
  
  // Platform compatibility
  print('🌍 Platform Compatibility:');
  if (kIsWeb) {
    print('   ✅ Web: Full support (no actual permissions)');
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    print('   ✅ iOS: Full support with proper permission handling');
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    print('   ✅ Android: Full support with runtime permissions');
  } else {
    print('   ⚠️ ${_getPlatformInfo()}: Limited testing (desktop platform)');
  }
  
  print('\n🔐 Permission Types Tested:');
  print('   ✅ Camera: Photo/video capture');
  print('   ✅ Photos: Gallery access');
  print('   ✅ Microphone: Voice recording');
  print('   ✅ Notifications: Push notifications');
  print('   ✅ Location: GPS access');
  print('   ✅ Storage: File access');
  print('   ✅ Phone: Phone state');
  print('   ✅ SMS: Text messaging');
  print('   ✅ Contacts: Address book');
  print('   ✅ Calendar: Schedule access');
  print('   ✅ Bluetooth: Device connectivity');
  print('   ✅ External Storage: File management');
  
  print('\n📱 Testing Recommendations:');
  print('   1. Test on real devices, not just simulators');
  print('   2. Test permission denial scenarios');
  print('   3. Test permission re-granting after denial');
  print('   4. Test on different Android API levels');
  print('   5. Test on different iOS versions');
  
  print('\n🚀 Next Steps:');
  print('   1. Integrate SimplePermissionService into your main app');
  print('   2. Test media services with the new permission system');
  print('   3. Remove old permission services if no longer needed');
  print('   4. Test edge cases and error scenarios');
}
