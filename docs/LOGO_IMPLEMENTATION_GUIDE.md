# SOC Logo Implementation Guide

This guide explains how the SOCLogo.png is used throughout the app and how to generate app icons for different platforms.

## Current Implementation

### 1. App Logo Widget (`lib/widgets/app_logo.dart`)
- **AppLogo**: Main logo widget that displays SOCLogo.png with customizable size, background, and text
- **AppLogoIcon**: Simplified icon version without background
- Both widgets use `assets/logo/SOCLogo.png` as the source image
- Includes error handling with fallback to chat bubble icon

### 2. Usage in Screens
The logo is now used in:
- `lib/screens/login_screen.dart` - Login screen
- `lib/screens/modern_login_screen.dart` - Modern login screen
- `lib/screens/register_screen.dart` - Registration screen
- `lib/screens/modern_register_screen.dart` - Modern registration screen
- `lib/screens/register_screen_mongodb.dart` - MongoDB registration screen

### 3. Web Implementation
- `web/index.html` - Loading screen uses SOCLogo.png
- Web manifest references icons in `web/icons/` directory

### 4. App Icons Configuration
- `pubspec.yaml` - `flutter_icons` configuration uses SOCLogo.png for Android and iOS app icons

## Generating App Icons

### Recommended Sizes

#### Android
- **mdpi**: 48x48
- **hdpi**: 72x72
- **xhdpi**: 96x96
- **xxhdpi**: 144x144
- **xxxhdpi**: 192x192
- **Adaptive Icon Foreground**: 1024x1024 (recommended)
- **Adaptive Icon Background**: Solid color or gradient

#### iOS
- **App Icon**: 1024x1024 (required for App Store)
- **Icon sizes**: Generated automatically by Xcode from 1024x1024

#### Web
- **favicon.png**: 32x32
- **Icon-192.png**: 192x192
- **Icon-512.png**: 512x512
- **Icon-maskable-192.png**: 192x192 (maskable)
- **Icon-maskable-512.png**: 512x512 (maskable)

### Tools for Generating Icons

#### Option 1: Online Tools
1. **AppIcon.co** (https://www.appicon.co/)
   - Upload SOCLogo.png
   - Select platforms (Android, iOS, Web)
   - Download generated icons

2. **Icon Kitchen** (https://icon.kitchen/)
   - Upload SOCLogo.png
   - Generate Android adaptive icons
   - Download all sizes

3. **Favicon Generator** (https://realfavicongenerator.net/)
   - Upload SOCLogo.png
   - Generate web icons and favicons
   - Download all sizes

#### Option 2: ImageMagick (Command Line)
```bash
# Install ImageMagick first
# Then resize SOCLogo.png to different sizes

# Android icons
magick assets/logo/SOCLogo.png -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
magick assets/logo/SOCLogo.png -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
magick assets/logo/SOCLogo.png -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
magick assets/logo/SOCLogo.png -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
magick assets/logo/SOCLogo.png -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# Web icons
magick assets/logo/SOCLogo.png -resize 32x32 web/icons/favicon.png
magick assets/logo/SOCLogo.png -resize 192x192 web/icons/Icon-192.png
magick assets/logo/SOCLogo.png -resize 512x512 web/icons/Icon-512.png
```

#### Option 3: Flutter Icon Package
The `flutter_launcher_icons` package (already configured in pubspec.yaml) can automatically generate icons:

```bash
# Install the package
flutter pub global activate flutter_launcher_icons

# Generate icons (uses SOCLogo.png from pubspec.yaml)
flutter pub run flutter_launcher_icons
```

This will automatically:
- Generate all Android icon sizes
- Generate iOS app icons
- Update adaptive icon configurations

### Manual Steps for Web Icons

1. Copy SOCLogo.png to `web/icons/` directory
2. Resize to required sizes:
   - `favicon.png`: 32x32
   - `Icon-192.png`: 192x192
   - `Icon-512.png`: 512x512
   - `Icon-maskable-192.png`: 192x192 (with safe zone)
   - `Icon-maskable-512.png`: 512x512 (with safe zone)

3. Update `web/manifest.json` if needed (already configured)

## Best Practices

1. **Logo Quality**: Ensure SOCLogo.png is at least 1024x1024 pixels for best results
2. **Transparency**: If logo has transparency, ensure it works well on both light and dark backgrounds
3. **Safe Zone**: For adaptive icons, keep important content in the center 66% of the image
4. **Testing**: Test icons on actual devices to ensure they look good at all sizes
5. **Consistency**: Use the same logo across all platforms for brand consistency

## Current Configuration

### pubspec.yaml
```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/logo/SOCLogo.png"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/logo/SOCLogo.png"
```

### Assets Declaration
```yaml
assets:
  - assets/logo/
  - assets/logo/logo.png
  - assets/logo/SOCLogo.png
```

## Next Steps

1. Ensure SOCLogo.png is high quality (1024x1024 or larger)
2. Run `flutter pub run flutter_launcher_icons` to generate app icons
3. Manually create web icons if needed
4. Test on all platforms to ensure logos display correctly
5. Update any remaining hardcoded logo references

## Troubleshooting

### Logo not appearing
- Check that `assets/logo/SOCLogo.png` exists
- Verify asset path in `pubspec.yaml`
- Run `flutter pub get` to refresh assets
- Check console for asset loading errors

### App icons not updating
- Clean build: `flutter clean`
- Regenerate icons: `flutter pub run flutter_launcher_icons`
- Rebuild app: `flutter build apk` or `flutter build ios`

### Web icons not showing
- Verify files exist in `web/icons/` directory
- Check `web/manifest.json` references
- Clear browser cache
- Check browser console for 404 errors
