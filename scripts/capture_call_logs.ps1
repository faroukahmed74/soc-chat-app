# Script to capture device logs during a call
# Usage: .\scripts\capture_call_logs.ps1

Write-Host "`n📱 Device Log Capture for Call Diagnostics" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Try to find ADB
$adbPath = $null

# Check common Android SDK locations
$possiblePaths = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $adbPath = $path
        Write-Host "✅ Found ADB at: $path" -ForegroundColor Green
        break
    }
}

# Try Flutter's ADB
if (-not $adbPath) {
    try {
        $flutterVersion = flutter --version 2>&1
        $flutterSdkPath = $flutterVersion | Select-String "Flutter SDK" | ForEach-Object {
            if ($_ -match 'Flutter SDK at (.+?)(\s|$)') {
                $matches[1]
            }
        }
        
        if ($flutterSdkPath) {
            $flutterAdbPath = Join-Path $flutterSdkPath "bin\cache\artifacts\engine\android-arm64\adb.exe"
            if (Test-Path $flutterAdbPath) {
                $adbPath = $flutterAdbPath
                Write-Host "✅ Found ADB via Flutter at: $flutterAdbPath" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "⚠️  Could not find Flutter SDK" -ForegroundColor Yellow
    }
}

if (-not $adbPath) {
    Write-Host "`n❌ ADB not found!" -ForegroundColor Red
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Install Android SDK Platform Tools" -ForegroundColor White
    Write-Host "2. Add to PATH: %LOCALAPPDATA%\Android\Sdk\platform-tools" -ForegroundColor White
    Write-Host "3. Or set ANDROID_HOME environment variable" -ForegroundColor White
    Write-Host "`nAlternatively, run these commands manually on your device:" -ForegroundColor Cyan
    Write-Host "   adb logcat | findstr 'ICE_CONNECTION'" -ForegroundColor White
    Write-Host "   adb logcat | findstr 'ON_TRACK\|ON_ADD_STREAM'" -ForegroundColor White
    Write-Host "   adb logcat | findstr 'CALL_SCREEN.*onRemoteStream'" -ForegroundColor White
    exit 1
}

# Check for connected devices
Write-Host "`n📱 Checking connected devices..." -ForegroundColor Cyan
$devices = & $adbPath devices 2>&1
$deviceLines = $devices | Select-String "device$" | Where-Object { $_ -notmatch "List of devices" }

if ($deviceLines.Count -eq 0) {
    Write-Host "❌ No devices connected!" -ForegroundColor Red
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Connect your Android device via USB" -ForegroundColor White
    Write-Host "2. Enable USB debugging" -ForegroundColor White
    Write-Host "3. Run this script again" -ForegroundColor White
    exit 1
}

Write-Host "✅ Found $($deviceLines.Count) device(s)" -ForegroundColor Green
$deviceLines | ForEach-Object { Write-Host "   - $($_.Line.Trim())" -ForegroundColor Gray }

# Clear log buffer
Write-Host "`n🧹 Clearing log buffer..." -ForegroundColor Cyan
& $adbPath logcat -c 2>&1 | Out-Null

Write-Host "`n📋 Instructions:" -ForegroundColor Yellow
Write-Host "1. Make a call between the two devices NOW" -ForegroundColor White
Write-Host "2. Wait for the call to connect (or fail)" -ForegroundColor White
Write-Host "3. Press Ctrl+C to stop capturing logs" -ForegroundColor White
Write-Host "`n🔍 Starting log capture..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Capture logs with filters
$filters = @(
    "ICE_CONNECTION",
    "ON_TRACK",
    "ON_ADD_STREAM",
    "CALL_SCREEN",
    "TURN_CONFIG",
    "RELAY",
    "ICE_CANDIDATE"
)

$filterString = $filters -join "|"
Write-Host "`nFiltering for: $filterString" -ForegroundColor Gray
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Start logcat with filters
try {
    & $adbPath logcat | Select-String -Pattern $filterString -CaseSensitive:$false
} catch {
    Write-Host "`n❌ Error capturing logs: $_" -ForegroundColor Red
    Write-Host "`nTry running manually:" -ForegroundColor Yellow
    Write-Host "   $adbPath logcat | findstr /i '$filterString'" -ForegroundColor White
}

