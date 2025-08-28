# SOC Chat App

A secure, cross-platform chat application built with Flutter, featuring real-time messaging, media sharing, and comprehensive notification systems.

## 🏗️ Project Organization

This project has been organized for enhanced readability and maintainability:

### 📁 Directory Structure

```
soc_chat_app/
├── 📱 android/                 # Android platform-specific code
├── 🍎 ios/                     # iOS platform-specific code
├── 🐧 linux/                   # Linux platform-specific code
├── 🪟 windows/                 # Windows platform-specific code
├── 🖥️ macos/                   # macOS platform-specific code
├── 🌐 web/                     # Web platform-specific code
├── 📦 lib/                     # Main Flutter application code
├── 🧪 test/                    # Flutter widget tests
├── 📚 docs/                    # Project documentation
├── 🔧 build-scripts/           # Build and execution scripts
├── 🧪 testing/                 # Custom test files
├── ⚙️ config/                  # Configuration files
├── 🖥️ servers/                 # Server-side code and dependencies
├── 🎨 assets/                  # App assets (images, fonts, etc.)
├── 🚀 functions/               # Firebase Cloud Functions
└── 📋 Project files           # Root-level project files
```

### 📚 Documentation (`docs/`)

All project documentation is organized in the `docs/` directory:

- **Build & Testing**: Build status, testing reports, and testing guides
- **Platform Guides**: Platform-specific setup and permission guides
- **Legal & Compliance**: Privacy policy, terms of service, and compliance documents
- **Feature Documentation**: Comprehensive guides for app features
- **Setup & Deployment**: Setup guides and deployment instructions

### 🔧 Build Scripts (`build-scripts/`)

Platform-specific build and execution scripts:

- **Windows**: `.bat` and `.ps1` scripts for Windows builds
- **Cross-platform**: Shell scripts for various build operations
- **App Execution**: Scripts to run the built application

### 🧪 Testing (`testing/`)

Custom test files for various app functionalities:

- **Permission Tests**: Platform-specific permission testing
- **Notification Tests**: Notification system verification
- **Performance Tests**: App performance and functionality testing

### ⚙️ Configuration (`config/`)

Project configuration files:

- **Firebase**: Firebase configuration and rules
- **Analysis**: Dart analysis options
- **Build**: Platform-specific build configurations

### 🖥️ Servers (`servers/`)

Server-side components:

- **FCM Server**: Firebase Cloud Messaging server
- **Node.js Dependencies**: Server package management
- **Server Scripts**: Server-side utilities and tests

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (3.8.0+)
- Dart SDK (3.8.0+)
- Android Studio / Xcode (for mobile development)
- Node.js (for server components)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/faroukahmed74/soc-chat_app.git
   cd soc_chat_app
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Install server dependencies**
   ```bash
   cd servers
   npm install
   cd ..
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Platform Support

- ✅ **Android**: Full support with optimized APK builds
- ✅ **iOS**: App Store ready with proper permissions
- ✅ **Web**: Optimized web build with tree-shaking
- ✅ **Windows**: Desktop application support
- ✅ **macOS**: Native macOS application
- ✅ **Linux**: Linux desktop support

## 🔐 Key Features

- **Secure Messaging**: End-to-end encryption
- **Real-time Communication**: Firebase-powered real-time updates
- **Media Sharing**: Photos, videos, and file sharing
- **Cross-platform**: Consistent experience across all platforms
- **Push Notifications**: Comprehensive notification system
- **Admin Panel**: Advanced user management and monitoring
- **Responsive Design**: Optimized for all screen sizes

## 🧪 Testing

### Run Flutter Tests
```bash
flutter test
```

### Run Custom Tests
```bash
cd testing
flutter run test_permissions_cli.dart
```

### Test Notifications
```bash
cd testing
flutter run test_notification_system.dart
```

## 🏗️ Building

### Android
```bash
cd build-scripts
./build_android.bat  # Windows
./build_android.sh   # Linux/macOS
```

### iOS
```bash
cd build-scripts
./build_ios.sh
```

### Web
```bash
flutter build web
```

## 📚 Documentation Index

### Essential Guides
- [Setup Guide](docs/SETUP_GUIDE.md) - Complete project setup
- [Project Documentation](docs/PROJECT_DOCUMENTATION.md) - Comprehensive project overview
- [Production Readiness](docs/PRODUCTION_READINESS.md) - Production deployment guide

### Platform-Specific
- [Android Setup](docs/ANDROID_UPDATE_SETUP.md) - Android development setup
- [iOS Permissions](docs/IOS_PERMISSION_FIXES_SUMMARY.md) - iOS permission handling
- [Windows Build](docs/WINDOWS_BUILD_GUIDE.md) - Windows application building

### Testing & Quality
- [Testing Guide](docs/PERMISSION_TESTING_GUIDE.md) - Comprehensive testing guide
- [UAT Plan](docs/UAT_TEST_PLAN.md) - User acceptance testing
- [Testing Status](docs/CURRENT_TESTING_STATUS.md) - Current testing status

### Legal & Compliance
- [Privacy Policy](docs/PRIVACY_POLICY.md) - App privacy policy
- [Terms of Service](docs/TERMS_OF_SERVICE.md) - App terms and conditions
- [Legal Compliance](docs/LEGAL_COMPLIANCE_CHECKLIST.md) - Compliance checklist

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Check the [documentation](docs/) for guides
- Review the [testing status](docs/CURRENT_TESTING_STATUS.md) for known issues

## 🔄 Project Status

- **Version**: 1.0.1 (Build 5)
- **Status**: Production Ready ✅
- **Last Updated**: 2025-01-27
- **All Platforms**: Successfully Built ✅

For detailed build information, see [version_info.json](version_info.json).
