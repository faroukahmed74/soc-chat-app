# =============================================================================
# SOC Chat App - Build APK and Install on Connected Devices
# =============================================================================
# This script builds Android APK for release and installs on all connected devices
# Usage: .\build_apk_and_install.ps1

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

Write-Header "SOC Chat App - Build APK and Install on Devices"

# Configuration
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

# Check ADB and connected devices
Write-Info "Checking connected Android devices..."
$hasAdb = $false
$connectedDevices = @()

try {
    $adbPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbPath) {
        $hasAdb = $true
        $devicesOutput = adb devices
        $devicesList = $devicesOutput | Where-Object { $_ -match "device$" }
        
        foreach ($device in $devicesList) {
            if ($device -match "^([^\s]+)\s+device$") {
                $deviceId = $matches[1]
                $connectedDevices += $deviceId
                Write-Info "Found device: $deviceId"
            }
        }
        
        if ($connectedDevices.Count -eq 0) {
            Write-Warning "No Android devices detected. APK will be built but not installed."
        } else {
            Write-Info "Found $($connectedDevices.Count) connected device(s)"
        }
    }
} catch {
    Write-Warning "ADB not found in PATH. APK will be built but not installed automatically."
    Write-Warning "Make sure Android SDK platform-tools is in your PATH"
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
        $apkPath = (Resolve-Path $path).Path
        break
    }
}

if (-not $apkPath) {
    Write-Error "APK not found in expected locations"
    exit 1
}

$apkSize = [Math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-Info "APK location: $apkPath ($apkSize MB)"

# Step 3: Install on connected devices
if ($hasAdb -and $connectedDevices.Count -gt 0) {
    Write-Header "Step 3: Installing APK on Connected Devices"
    
    foreach ($deviceId in $connectedDevices) {
        Write-Info "Installing on device: $deviceId"
        adb -s $deviceId install -r $apkPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Successfully installed on device: $deviceId"
        } else {
            Write-Warning "Installation failed on device: $deviceId"
            Write-Warning "Try manually: adb -s $deviceId install -r $apkPath"
        }
        Write-Host ""
    }
} else {
    Write-Header "Step 3: Manual Installation Required"
    Write-Warning "No devices detected or ADB not available"
    Write-Host ""
    Write-Host "To install manually:" -ForegroundColor Yellow
    Write-Host "  1. Copy APK to device:" -ForegroundColor Cyan
    Write-Host "     $apkPath" -ForegroundColor White
    Write-Host "  2. Install via file manager on device" -ForegroundColor Cyan
    Write-Host "  OR" -ForegroundColor Yellow
    Write-Host "  3. Use ADB:" -ForegroundColor Cyan
    Write-Host "     adb install -r $apkPath" -ForegroundColor White
    Write-Host ""
}

# Summary
Write-Header "Build Summary"
Write-Info "APK Location: $apkPath"
Write-Info "APK Size: $apkSize MB"
Write-Info "Devices Found: $($connectedDevices.Count)"
if ($connectedDevices.Count -gt 0) {
    Write-Info "Installation Status: Completed"
} else {
    Write-Warning "Installation Status: Manual installation required"
}
Write-Host ""
Write-Info "Build completed successfully! 🎉"
Write-Host ""

