# 🧪 Testing Directory

This directory contains custom test files for various app functionalities that go beyond the standard Flutter widget tests.

## 📁 Test File Categories

### 🔐 Permission Tests
- **`test_permissions_cli.dart`** - Command-line permission testing interface
- **`test_simple_permissions.dart`** - Basic permission functionality testing
- **`test_gallery_permission.dart`** - Gallery and media permission testing
- **`test_ios_permissions.dart`** - iOS-specific permission handling tests
- **`test_permissions_notifications_media.dart`** - Comprehensive permission, notification, and media testing

### 🔔 Notification Tests
- **`test_notification_system.dart`** - Complete notification system verification
- **`test_notifications.dart`** - Basic notification functionality testing

### 🚀 Performance & Functionality Tests
- **`test_performance.dart`** - App performance and optimization testing
- **`test_real_functionality.dart`** - Real-world app functionality testing

## 🚀 How to Run Tests

### Prerequisites
- Flutter SDK installed and configured
- Device or emulator running
- App dependencies installed (`flutter pub get`)

### Running Individual Tests

#### Permission Tests
```bash
# Test basic permissions
flutter run testing/test_simple_permissions.dart

# Test gallery permissions
flutter run testing/test_gallery_permission.dart

# Test iOS-specific permissions
flutter run testing/test_ios_permissions.dart

# Test comprehensive permissions
flutter run testing/test_permissions_notifications_media.dart
```

#### Notification Tests
```bash
# Test notification system
flutter run testing/test_notification_system.dart

# Test basic notifications
flutter run testing/test_notifications.dart
```

#### Performance Tests
```bash
# Test app performance
flutter run testing/test_performance.dart

# Test real functionality
flutter run testing/test_real_functionality.dart
```

### Running All Tests
```bash
# Run all Flutter tests (including widget tests)
flutter test

# Run custom tests sequentially
cd testing
for file in test_*.dart; do
    echo "Running $file..."
    flutter run "$file"
done
```

## 🧪 Test Descriptions

### Permission Testing

#### `test_permissions_cli.dart`
- **Purpose**: Command-line interface for permission testing
- **Features**: Interactive permission testing, step-by-step verification
- **Use Case**: Development and debugging permission issues
- **Output**: Detailed permission status and error reporting

#### `test_simple_permissions.dart`
- **Purpose**: Basic permission functionality verification
- **Features**: Camera, microphone, storage permission tests
- **Use Case**: Quick permission validation
- **Output**: Permission grant/deny status

#### `test_gallery_permission.dart`
- **Purpose**: Gallery and media access permission testing
- **Features**: Photo library access, camera roll permissions
- **Use Case**: Media sharing functionality validation
- **Output**: Media access permission status

#### `test_ios_permissions.dart`
- **Purpose**: iOS-specific permission handling
- **Features**: iOS permission dialogs, settings redirect
- **Use Case**: iOS app permission compliance
- **Output**: iOS permission flow verification

#### `test_permissions_notifications_media.dart`
- **Purpose**: Comprehensive permission, notification, and media testing
- **Features**: All permission types, notification system, media handling
- **Use Case**: Complete app functionality validation
- **Output**: Comprehensive test results

### Notification Testing

#### `test_notification_system.dart`
- **Purpose**: Complete notification system verification
- **Features**: FCM, local notifications, background processing
- **Use Case**: Notification system validation
- **Output**: Notification delivery status

#### `test_notifications.dart`
- **Purpose**: Basic notification functionality testing
- **Features**: Simple notification display, user interaction
- **Use Case**: Basic notification validation
- **Output**: Notification display status

### Performance & Functionality Testing

#### `test_performance.dart`
- **Purpose**: App performance and optimization testing
- **Features**: Memory usage, CPU performance, response times
- **Use Case**: Performance optimization validation
- **Output**: Performance metrics and benchmarks

#### `test_real_functionality.dart`
- **Purpose**: Real-world app functionality testing
- **Features**: End-to-end user flows, integration testing
- **Use Case**: Production readiness validation
- **Output**: Functionality verification results

## 📊 Test Results Interpretation

### Permission Test Results
- ✅ **GRANTED**: Permission successfully granted
- ❌ **DENIED**: Permission denied by user
- ⚠️ **RESTRICTED**: Permission restricted by system
- 🔄 **PENDING**: Permission request in progress

### Notification Test Results
- ✅ **SENT**: Notification successfully sent
- ❌ **FAILED**: Notification failed to send
- ⏳ **DELAYED**: Notification delayed
- 🔕 **BLOCKED**: Notification blocked by user

### Performance Test Results
- 🟢 **EXCELLENT**: Performance within optimal range
- 🟡 **GOOD**: Performance acceptable
- 🟠 **FAIR**: Performance needs attention
- 🔴 **POOR**: Performance requires optimization

## 🐛 Troubleshooting

### Common Test Issues

#### Permission Tests Fail
1. Check device permission settings
2. Verify app permissions in system settings
3. Restart the app after permission changes
4. Check platform-specific permission requirements

#### Notification Tests Fail
1. Verify FCM configuration
2. Check notification permissions
3. Ensure device is not in Do Not Disturb mode
4. Verify Firebase project settings

#### Performance Tests Slow
1. Close other apps
2. Check device performance mode
3. Verify test device specifications
4. Run tests multiple times for average

### Debug Mode
Enable debug output for detailed testing:
```bash
# Set debug environment variable
export FLUTTER_TEST_DEBUG=1

# Run test with debug
flutter run testing/test_file.dart --debug
```

## 📋 Test Maintenance

### Adding New Tests
1. Follow naming convention: `test_feature_name.dart`
2. Include comprehensive test coverage
3. Add proper error handling
4. Include test documentation
5. Update this README

### Updating Existing Tests
1. Test changes thoroughly
2. Maintain backward compatibility
3. Update test documentation
4. Verify test reliability

## 🔗 Related Documentation

- **[Testing Guide](../docs/PERMISSION_TESTING_GUIDE.md)** - Comprehensive testing guide
- **[Testing Status](../docs/CURRENT_TESTING_STATUS.md)** - Current testing progress
- **[Testing Summary](../docs/FINAL_TESTING_SUMMARY.md)** - Testing results summary
- **[UAT Plan](../docs/UAT_TEST_PLAN.md)** - User acceptance testing plan

## 📞 Support

For testing issues:
1. Check the troubleshooting section above
2. Review [Testing Guide](../docs/PERMISSION_TESTING_GUIDE.md)
3. Check [Testing Status](../docs/CURRENT_TESTING_STATUS.md)
4. Create an issue in the repository

---

**Note**: Always run tests on target devices/emulators for accurate results.
