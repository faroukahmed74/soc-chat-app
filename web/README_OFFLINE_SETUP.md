# Offline Web App Setup Guide

This guide ensures all resources are loaded from the local server without requiring internet connection.

## ✅ Resources Already Configured for Offline

1. **CanvasKit** - Bundled locally in `/canvaskit/` directory
2. **Fonts** - All fonts bundled in `/assets/assets/fonts/`
3. **Firebase SDK** - Downloaded and placed in `/web/firebase/` directory
4. **Icons** - All icons in `/web/icons/` directory
5. **Assets** - All assets bundled in `/assets/` directory

## 📦 Firebase SDK Files

Firebase SDK files are stored in `web/firebase/`:
- `firebase-app-compat.js`
- `firebase-messaging-compat.js`

These files are automatically copied to `build/web/firebase/` during `flutter build web`.

## 🔧 Build Process

When building the web app, Flutter automatically:
1. Copies all files from `web/` to `build/web/`
2. Bundles all assets from `pubspec.yaml`
3. Includes CanvasKit locally
4. Includes all fonts locally

## ✅ Verification Checklist

After building, verify in `build/web/`:
- [ ] `firebase/firebase-app-compat.js` exists
- [ ] `firebase/firebase-messaging-compat.js` exists
- [ ] `canvaskit/` directory with all files
- [ ] `assets/` directory with all fonts and resources
- [ ] No external CDN URLs in `index.html`

## 🚫 Blocked External Resources

The following external resources are blocked:
- Google Fonts CDN
- Firebase CDN (gstatic.com, googleapis.com)
- CanvasKit CDN (gstatic.com/flutter-canvaskit)
- All other CDN services

## 📝 Notes

- All resources load from the local server
- No internet connection required
- Works completely offline on internal network
- Firebase files are loaded from `./firebase/` (local)
