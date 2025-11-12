# =============================================================================
# SOC Chat App - Web Release Build Script
# =============================================================================
# This script builds the Flutter web app for production release
# Usage: .\scripts\build_web_release.ps1

param(
    [string]$WebApiUrl = "http://localhost:3003",
    [string]$MobileApiUrl = "https://soc-chat-app.ngrok-free.app",
    [string]$WebRenderer = "canvaskit",
    [switch]$SkipClean = $false
)

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

# Check Flutter
Write-Info "Checking Flutter installation..."
try {
    $flutterVersion = flutter --version | Select-Object -First 1
    Write-Info "Flutter: $flutterVersion"
} catch {
    Write-Error "Flutter is not installed or not in PATH"
    exit 1
}

# Clean previous build
if (-not $SkipClean) {
    Write-Info "Cleaning previous build..."
    flutter clean
    Write-Info "✓ Clean completed"
}

# Get dependencies
Write-Info "Getting dependencies..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get dependencies"
    exit 1
}
Write-Info "✓ Dependencies updated"

# Build web app
Write-Header "Building Web App"
Write-Info "Web API URL: $WebApiUrl"
Write-Info "Mobile API URL: $MobileApiUrl"
Write-Info "Web Renderer: $WebRenderer"
Write-Host ""

Write-Info "Building web app (this may take a few minutes)..."
$buildCommand = "flutter build web --release --web-renderer $WebRenderer --dart-define=API_BASE_URL_WEB=$WebApiUrl --dart-define=API_BASE_URL_MOBILE=$MobileApiUrl --dart-define=USE_PHYSICAL_SERVER=true"

Write-Host "Command: $buildCommand" -ForegroundColor Gray
Write-Host ""

Invoke-Expression $buildCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "Web build failed"
    exit 1
}

Write-Info "✓ Web build completed"

# Check build output
$buildDir = "build\web"
if (Test-Path $buildDir) {
    Write-Header "Build Summary"
    
    $indexHtml = Join-Path $buildDir "index.html"
    if (Test-Path $indexHtml) {
        $indexSize = (Get-Item $indexHtml).Length / 1KB
        $indexSizeRounded = [math]::Round($indexSize, 2)
        Write-Info "✓ index.html ($indexSizeRounded KB)"
    }
    
    $mainJs = Join-Path $buildDir "main.dart.js"
    if (Test-Path $mainJs) {
        $jsSize = (Get-Item $mainJs).Length / 1MB
        $jsSizeRounded = [math]::Round($jsSize, 2)
        Write-Info "✓ main.dart.js ($jsSizeRounded MB)"
    }
    
    $assetsDir = Join-Path $buildDir "assets"
    if (Test-Path $assetsDir) {
        $assetCount = (Get-ChildItem $assetsDir -Recurse -File).Count
        Write-Info "✓ Assets directory ($assetCount files)"
    }
    
    $canvaskitDir = Join-Path $buildDir "canvaskit"
    if (Test-Path $canvaskitDir) {
        Write-Info "✓ CanvasKit resources"
    }
    
    Write-Host ""
    Write-Info "Build location: $buildDir"
    Write-Info "Build completed successfully! 🎉"
    
    Write-Header "Next Steps"
    Write-Host "To serve the web app locally:" -ForegroundColor Yellow
    Write-Host "  cd $buildDir" -ForegroundColor Cyan
    Write-Host "  python -m http.server 8080" -ForegroundColor Cyan
    Write-Host "  # or" -ForegroundColor Gray
    Write-Host "  npx serve -s . -l 8080" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To deploy:" -ForegroundColor Yellow
    Write-Host "  1. Upload the contents of '$buildDir' to your web server" -ForegroundColor White
    Write-Host "  2. Ensure your server supports SPA routing (redirect all routes to index.html)" -ForegroundColor White
    Write-Host "  3. Configure CORS if needed for API access" -ForegroundColor White
    Write-Host ""
} else {
    Write-Error "Build directory not found: $buildDir"
    exit 1
}

Write-Header "Build Complete"

