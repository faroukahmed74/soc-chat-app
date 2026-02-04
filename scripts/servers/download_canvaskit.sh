#!/bin/bash
# Download CanvasKit files from Google CDN to serve locally
# This allows PCs without internet access to download CanvasKit from the server

CUR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$CUR_DIR/../build/web/canvaskit"

# Create directory if it doesn't exist
mkdir -p "$WEB_DIR"

echo "========================================="
echo "Downloading CanvasKit from Google CDN"
echo "========================================="
echo ""

# Download CanvasKit files
echo "Downloading canvaskit.js..."
curl -L "https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.js" \
     -o "$WEB_DIR/canvaskit.js" || echo "Failed to download canvaskit.js"

echo "Downloading canvaskit.wasm..."
curl -L "https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.wasm" \
     -o "$WEB_DIR/canvaskit.wasm" || echo "Failed to download canvaskit.wasm"

echo "Downloading chromium/canvaskit.js..."
mkdir -p "$WEB_DIR/chromium"
curl -L "https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.js" \
     -o "$WEB_DIR/chromium/canvaskit.js" || echo "Failed to download chromium/canvaskit.js"

echo ""
echo "========================================="
echo "✅ CanvasKit files downloaded successfully!"
echo "Files location: $WEB_DIR"
echo "========================================="
echo ""
echo "Now you can serve these files from your local server."
echo "The Flutter app will download CanvasKit from your server instead of Google's CDN."

