# =============================================================================
# SOC Chat App - Complete Release Build Script
# =============================================================================
# This script builds both Android APK and Web release versions
# Usage: .\build_release_all.ps1

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

Write-Header "SOC Chat App - Complete Release Build"

# Configuration
$WebApiUrl = "http://localhost:3003"
$MobileApiUrl = "https://soc-chat-app.ngrok-free.app"
$WebRenderer = "canvaskit"

# Check Flutter
Write-Info "Checking Flutter installation..."
try {
    $flutterVersion = flutter --version | Select-Object -First 1
    Write-Info "Flutter: $flutterVersion"
} catch {
    Write-Error "Flutter is not installed or not in PATH"
    exit 1
}

# Check if connected devices
Write-Info "Checking connected devices..."
try {
    $devices = adb devices 2>$null
    if ($devices -match "device$") {
        Write-Info "Android device(s) detected"
        $hasAdb = $true
    } else {
        Write-Warning "No Android devices detected. APK will be built but not installed automatically."
        $hasAdb = $true
    }
} catch {
    Write-Warning "ADB not found in PATH. APK will be built but not installed automatically."
    $hasAdb = $false
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

# Step 2: Build Android APK
Write-Header "Step 2: Building Android APK (Release)"
Write-Info "Building release APK..."
Write-Info "Mobile API URL: $MobileApiUrl"
Write-Host ""

$apkBuildCommand = "flutter build apk --release --dart-define=API_BASE_URL_MOBILE=$MobileApiUrl --dart-define=USE_PHYSICAL_SERVER=true"
Write-Host "Command: $apkBuildCommand" -ForegroundColor Gray
Write-Host ""

Invoke-Expression $apkBuildCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "APK build failed"
    exit 1
}

Write-Info "APK build completed"

# Find APK location
$apkCandidates = @(
    "build\app\outputs\flutter-apk\app-release.apk",
    "build\app\outputs\apk\release\app-release.apk",
    "android\app\build\outputs\apk\release\app-release.apk"
)

$apkPath = $null
foreach ($path in $apkCandidates) {
    if (Test-Path $path) {
        $apkPath = $path
        break
    }
}

if ($apkPath) {
    $apkSize = [Math]::Round((Get-Item $apkPath).Length / 1MB, 2)
    Write-Info "APK location: $apkPath ($apkSize MB)"
    
    # Install on connected device
    if ($hasAdb) {
        try {
            $devices = adb devices 2>$null
            if ($devices -match "device$") {
                Write-Info "Installing APK on connected device..."
                adb install -r $apkPath
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "APK installed successfully on device"
                } else {
                    Write-Warning "APK installation failed. You can install manually: adb install -r $apkPath"
                }
            }
        } catch {
            Write-Warning "Could not install APK automatically. Install manually: adb install -r $apkPath"
        }
    }
} else {
    Write-Error "APK not found in expected locations"
}

# Summary
Write-Header "Build Summary"
Write-Info "Android APK: $apkPath"
Write-Host ""
Write-Info "APK build completed successfully! 🎉"

Write-Header "Installation Instructions"
Write-Host "Android APK:" -ForegroundColor Yellow
Write-Host "  Location: $apkPath" -ForegroundColor Cyan
Write-Host "  Install manually: adb install -r $apkPath" -ForegroundColor Cyan
Write-Host "  Or copy APK to device and install via file manager" -ForegroundColor Cyan
Write-Host ""

