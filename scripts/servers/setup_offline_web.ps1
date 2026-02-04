# =============================================================================
# SETUP OFFLINE WEB - Complete Setup Script
# =============================================================================
# This script sets up everything needed for offline web operation:
# 1. Builds Flutter web app
# 2. Downloads all offline assets (CanvasKit, etc.)
# 3. Verifies all assets are present
# 4. Starts the offline web server

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Offline Web Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Configuration
$WEB_BUILD_DIR = "build\web"
$CANVASKIT_DIR = "$WEB_BUILD_DIR\canvaskit"

# Step 1: Check prerequisites
Write-Host "1. Checking prerequisites..." -ForegroundColor Green
$nodeVersion = node --version 2>$null
$flutterVersion = flutter --version 2>$null

if (-not $nodeVersion) {
    Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}
if (-not $flutterVersion) {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Node.js: $nodeVersion" -ForegroundColor Gray
Write-Host "   ✅ Flutter: Found" -ForegroundColor Gray
Write-Host ""

# Step 2: Install Node dependencies
Write-Host "2. Installing Node.js dependencies..." -ForegroundColor Green
Push-Location servers
if (Test-Path "package.json") {
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} else {
    Write-Host "   ⚠️  No package.json found in servers directory" -ForegroundColor Yellow
}
Pop-Location
Write-Host "   ✅ Dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 3: Build Flutter web app
Write-Host "3. Building Flutter web app..." -ForegroundColor Green
flutter clean
flutter pub get
flutter build web --base-href "/" --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$WEB_BUILD_DIR\index.html")) {
    Write-Host "❌ Web build not found at: $WEB_BUILD_DIR" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Web build completed" -ForegroundColor Green
Write-Host ""

# Step 4: Download offline assets
Write-Host "4. Downloading offline assets (CanvasKit, etc.)..." -ForegroundColor Green
node servers\download_all_assets.js

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ⚠️  Some assets may have failed to download" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ All assets downloaded" -ForegroundColor Green
}
Write-Host ""

# Step 5: Verify assets
Write-Host "5. Verifying offline assets..." -ForegroundColor Green
$checks = @{
    "index.html" = Test-Path "$WEB_BUILD_DIR\index.html"
    "main.dart.js" = Test-Path "$WEB_BUILD_DIR\main.dart.js"
    "flutter.js" = Test-Path "$WEB_BUILD_DIR\flutter.js"
    "canvaskit.js" = Test-Path "$CANVASKIT_DIR\canvaskit.js"
    "canvaskit.wasm" = Test-Path "$CANVASKIT_DIR\canvaskit.wasm"
}

$allOk = $true
foreach ($check in $checks.GetEnumerator()) {
    if ($check.Value) {
        Write-Host "   ✅ $($check.Key)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ $($check.Key) - MISSING" -ForegroundColor Red
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host ""
    Write-Host "   ⚠️  Some assets are missing. The app may not work offline." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "   ✅ All required assets are present" -ForegroundColor Green
}
Write-Host ""

# Step 6: Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start the offline web server:" -ForegroundColor Yellow
Write-Host "   node servers\offline_web_server.js" -ForegroundColor White
Write-Host ""
Write-Host "Or use the start script:" -ForegroundColor Yellow
Write-Host "   .\servers\start_offline_web.ps1" -ForegroundColor White
Write-Host ""
Write-Host "The app will be available at:" -ForegroundColor Yellow
Write-Host "   http://localhost:8082" -ForegroundColor Cyan
Write-Host "   http://[YOUR_IPV4]:8082" -ForegroundColor Cyan
Write-Host ""

