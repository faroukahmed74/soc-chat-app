#!/bin/bash
# Build and Install SOC Chat App with Notification Fixes

echo "🔨 Building Flutter app with notification fixes..."
echo ""

# Build APK
flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ APK built successfully!"
    echo ""
    echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "📱 To install on your devices:"
    echo "   adb install -r build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "Or manually copy APK to devices and install"
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi

