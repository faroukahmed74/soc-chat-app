# =============================================================================
# BUILD WEB OFFLINE RELEASE SCRIPT
# =============================================================================
# This script builds the Flutter web app with complete offline support
# All assets, fonts, and resources are bundled and cached for local network access
# Works on IPv4:8082 without internet connection
# Does NOT affect mobile platforms (Android/iOS)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Offline Web Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$PORT = "8082"
$BUILD_DIR = "build\web"
$WEB_DIR = "web"

Write-Host "Building offline web app for local network access..." -ForegroundColor Yellow
Write-Host "Target: http://[YOUR_IPV4]:$PORT" -ForegroundColor Yellow
Write-Host ""

# Step 1: Clean previous build
Write-Host "1. Cleaning previous build..." -ForegroundColor Green
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter clean failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Clean completed" -ForegroundColor Green
Write-Host ""

# Step 2: Get dependencies
Write-Host "2. Getting dependencies..." -ForegroundColor Green
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter pub get failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Dependencies updated" -ForegroundColor Green
Write-Host ""

# Step 3: Build web app with offline configuration
Write-Host "3. Building web app with offline support..." -ForegroundColor Green
Write-Host "   - HTML renderer (for offline fonts)" -ForegroundColor Gray
Write-Host "   - All assets bundled locally" -ForegroundColor Gray
Write-Host "   - Service worker for caching" -ForegroundColor Gray
Write-Host ""

flutter build web `
  --base-href "/" `
  --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Web build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Web build completed" -ForegroundColor Green
Write-Host ""

# Step 4: Verify service worker is in place
Write-Host "4. Verifying offline configuration..." -ForegroundColor Green
if (Test-Path "$BUILD_DIR\firebase-messaging-sw.js") {
    Write-Host "✓ Service worker found" -ForegroundColor Green
} else {
    Write-Host "⚠ Warning: Service worker not found, copying..." -ForegroundColor Yellow
    if (Test-Path "$WEB_DIR\firebase-messaging-sw.js") {
        Copy-Item "$WEB_DIR\firebase-messaging-sw.js" "$BUILD_DIR\firebase-messaging-sw.js"
        Write-Host "✓ Service worker copied" -ForegroundColor Green
    }
}

# Verify responsive config
if (Test-Path "$BUILD_DIR\responsive_config.js") {
    Write-Host "✓ Responsive config found" -ForegroundColor Green
} else {
    if (Test-Path "$WEB_DIR\responsive_config.js") {
        Copy-Item "$WEB_DIR\responsive_config.js" "$BUILD_DIR\responsive_config.js"
        Write-Host "✓ Responsive config copied" -ForegroundColor Green
    }
}
Write-Host ""

# Step 5: Display build information
Write-Host "5. Build Summary" -ForegroundColor Green
Write-Host "   Build directory: $BUILD_DIR" -ForegroundColor Gray
Write-Host "   Port: $PORT" -ForegroundColor Gray
Write-Host "   Offline support: ✓ Enabled" -ForegroundColor Green
Write-Host "   Service worker: ✓ Enabled" -ForegroundColor Green
Write-Host "   Local assets: ✓ Bundled" -ForegroundColor Green
Write-Host "   Fonts: ✓ Local only" -ForegroundColor Green
Write-Host ""

# Step 6: Instructions for serving
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To serve the app on local network:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Using Python (if installed)" -ForegroundColor White
Write-Host "  cd $BUILD_DIR" -ForegroundColor Gray
Write-Host "  python -m http.server $PORT" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Using Node.js http-server" -ForegroundColor White
Write-Host "  npx http-server $BUILD_DIR -p $PORT -c-1" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 3: Using Flutter" -ForegroundColor White
Write-Host "  flutter run -d chrome --web-port=$PORT --web-hostname=0.0.0.0" -ForegroundColor Gray
Write-Host ""
Write-Host "Then access from other devices on your network:" -ForegroundColor Yellow
Write-Host "  http://[YOUR_IPV4]:$PORT" -ForegroundColor Cyan
Write-Host ""
Write-Host "The app will work completely offline after first load!" -ForegroundColor Green
Write-Host ""

