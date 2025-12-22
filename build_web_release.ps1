# =============================================================================
# SOC Chat App - Web Release Build Script
# =============================================================================
# This script builds the Flutter web app for production release
# Usage: .\build_web_release.ps1

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n=============================================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "=============================================================================`n" -ForegroundColor Cyan
}

Write-Header "SOC Chat App - Web Release Build"

# Configuration
$WebApiUrl = "http://localhost:3003"
$MobileApiUrl = "https://soc-chat-app.ngrok-free.app"

# Check Flutter
Write-Info "Checking Flutter installation..."
try {
    $flutterVersion = flutter --version | Select-Object -First 1
    Write-Info "Flutter: $flutterVersion"
} catch {
    Write-Error "Flutter is not installed or not in PATH"
    exit 1
}

# Step 1: Clean and get dependencies
Write-Header "Step 1: Preparing Build Environment"
Write-Info "Cleaning previous build..."
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter clean failed"
    exit 1
}

Write-Info "Getting dependencies..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get dependencies"
    exit 1
}
Write-Info "Dependencies updated"

# Step 2: Build Web Release
Write-Header "Step 2: Building Web Release"
Write-Info "Web API URL: $WebApiUrl"
Write-Info "Mobile API URL: $MobileApiUrl"
Write-Host ""

Write-Info "Building web app (this may take a few minutes)..."
# Note: --web-renderer flag is deprecated in Flutter 3.35+, using default renderer
$webBuildCommand = "flutter build web --release --dart-define=API_BASE_URL_WEB=$WebApiUrl --dart-define=API_BASE_URL_MOBILE=$MobileApiUrl --dart-define=USE_PHYSICAL_SERVER=true"
Write-Host "Command: $webBuildCommand" -ForegroundColor Gray
Write-Host ""

Invoke-Expression $webBuildCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "Web build failed"
    exit 1
}

Write-Info "Web build completed"

# Check web build output
$buildDir = "build\web"
if (Test-Path $buildDir) {
    Write-Header "Build Output Summary"
    
    $indexHtml = Join-Path $buildDir "index.html"
    if (Test-Path $indexHtml) {
        $indexSize = [Math]::Round((Get-Item $indexHtml).Length / 1KB, 2)
        Write-Info "index.html ($indexSize KB)"
    }
    
    $mainJs = Join-Path $buildDir "main.dart.js"
    if (Test-Path $mainJs) {
        $jsSize = [Math]::Round((Get-Item $mainJs).Length / 1MB, 2)
        Write-Info "main.dart.js ($jsSize MB)"
    }
    
    $assetsDir = Join-Path $buildDir "assets"
    if (Test-Path $assetsDir) {
        $assetCount = (Get-ChildItem $assetsDir -Recurse -File).Count
        Write-Info "Assets directory ($assetCount files)"
    }
    
    $canvaskitDir = Join-Path $buildDir "canvaskit"
    if (Test-Path $canvaskitDir) {
        Write-Info "CanvasKit resources found"
    }
    
    # Calculate total size
    $totalSize = (Get-ChildItem $buildDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)
    Write-Info "Total build size: $totalSizeMB MB"
    
    Write-Host ""
    Write-Info "Web build location: $buildDir"
} else {
    Write-Error "Web build directory not found"
    exit 1
}

# Summary
Write-Header "Build Summary"
Write-Info "Web Build: $buildDir"
Write-Info "Build Size: $totalSizeMB MB"
Write-Host ""
Write-Info "Web build completed successfully! 🎉"

Write-Header "Next Steps"
Write-Host "To serve the web app locally:" -ForegroundColor Yellow
Write-Host "  cd $buildDir" -ForegroundColor Cyan
Write-Host "  python -m http.server 8080" -ForegroundColor Cyan
Write-Host ""
Write-Host "Or deploy to a web server:" -ForegroundColor Yellow
Write-Host "  Copy the contents of $buildDir to your web server" -ForegroundColor Cyan
Write-Host ""

