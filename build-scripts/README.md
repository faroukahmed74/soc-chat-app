# 🔧 Build Scripts

This directory contains all the build and execution scripts for the SOC Chat App across different platforms.

## 📁 Script Categories

### 🪟 Windows Scripts (`.bat` and `.ps1`)

#### Build Scripts
- **`build_exe.bat`** - Creates a simple executable for Windows
- **`create_simple_exe.bat`** - Creates a basic Windows executable
- **`create_portable_exe.bat`** - Creates a portable Windows executable
- **`build_windows.bat`** - Windows build script (PowerShell alternative)
- **`build_windows.ps1`** - PowerShell build script for Windows

#### Execution Scripts
- **`run_built_app.bat`** - Runs the built Windows application
- **`SOC_Chat_App.bat`** - Main application launcher for Windows

### 🐧 Cross-Platform Scripts (`.sh`)

#### Network Scripts
- **`run_local_network.sh`** - Runs the app on local network (Linux/macOS)
- **`run_local_network.bat`** - Windows version of local network script
- **`run_local_network.ps1`** - PowerShell version of local network script

## 🚀 Usage Instructions

### Windows Development

#### Using Batch Files (.bat)
```cmd
# Build the app
build_windows.bat

# Create executable
create_simple_exe.bat

# Run the app
run_built_app.bat
```

#### Using PowerShell (.ps1)
```powershell
# Build the app
.\build_windows.ps1

# Run on local network
.\run_local_network.ps1
```

### Cross-Platform Development

#### Linux/macOS
```bash
# Make scripts executable
chmod +x *.sh

# Run on local network
./run_local_network.sh

# Build for specific platform
flutter build apk --release    # Android
flutter build ios --release    # iOS
flutter build web              # Web
```

## 🔨 Build Process

### 1. Flutter Build
All scripts follow this general build process:
1. **Clean Build**: Remove previous build artifacts
2. **Dependencies**: Get and update Flutter packages
3. **Build**: Compile for target platform
4. **Optimize**: Apply platform-specific optimizations
5. **Package**: Create distributable package

### 2. Platform-Specific Builds

#### Android
- Builds APK with release optimizations
- Includes signing configuration
- Optimizes for different device architectures

#### iOS
- Builds for iOS devices
- Includes proper provisioning profiles
- Optimizes for App Store submission

#### Web
- Creates optimized web build
- Applies tree-shaking optimizations
- Generates PWA-ready files

#### Windows
- Creates Windows executable
- Includes all dependencies
- Optimizes for Windows performance

## ⚙️ Configuration

### Environment Variables
Some scripts may require environment variables:
```bash
# Flutter SDK path
export FLUTTER_ROOT=/path/to/flutter

# Build configuration
export BUILD_TYPE=release
export BUILD_NUMBER=1
```

### Build Configuration
Scripts automatically detect:
- Flutter SDK location
- Target platform
- Build type (debug/release)
- Output directory

## 🐛 Troubleshooting

### Common Issues

#### Script Permission Denied
```bash
# Make executable (Linux/macOS)
chmod +x script_name.sh

# Windows: Run as Administrator
```

#### Flutter Not Found
```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"

# Or use full path in scripts
/path/to/flutter/bin/flutter build
```

#### Build Failures
1. Check Flutter version: `flutter --version`
2. Clean project: `flutter clean`
3. Get dependencies: `flutter pub get`
4. Check platform support: `flutter doctor`

### Debug Mode
Most scripts support debug mode:
```bash
# Enable debug output
set DEBUG=1  # Windows
export DEBUG=1  # Linux/macOS

# Run script with debug
./script_name.sh
```

## 📋 Script Maintenance

### Adding New Scripts
1. Follow naming convention: `action_platform.extension`
2. Include proper error handling
3. Add usage comments
4. Test on target platform
5. Update this README

### Updating Existing Scripts
1. Test changes thoroughly
2. Update documentation
3. Maintain backward compatibility
4. Add version comments

## 🔗 Related Documentation

- **[Build Guide](../docs/EXECUTABLE_BUILD_GUIDE.md)** - Detailed build instructions
- **[Windows Build Guide](../docs/WINDOWS_BUILD_GUIDE.md)** - Windows-specific build guide
- **[Build Status](../docs/FINAL_BUILD_STATUS.md)** - Current build status
- **[Production Readiness](../docs/PRODUCTION_READINESS.md)** - Production deployment

## 📞 Support

For build script issues:
1. Check the troubleshooting section above
2. Review the main [README](../README.md)
3. Check [Build Status](../docs/FINAL_BUILD_STATUS.md)
4. Create an issue in the repository

---

**Note**: Always test build scripts in a clean environment before using in production.
