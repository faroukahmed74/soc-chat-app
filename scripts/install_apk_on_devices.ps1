# Install APK on connected Android devices
# Usage: .\scripts\install_apk_on_devices.ps1

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"

if (-not (Test-Path $apkPath)) {
    Write-Host "Error: APK not found at $apkPath" -ForegroundColor Red
    Write-Host "Please build the APK first using: flutter build apk --release" -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing APK on Android Devices" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Try to find ADB
$adbPath = $null
$possiblePaths = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
    "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $adbPath = $path
        Write-Host "[OK] Found ADB at: $path" -ForegroundColor Green
        break
    }
}

if (-not $adbPath) {
    Write-Host "[ERROR] ADB not found. Please install Android SDK Platform Tools." -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Install APK manually:" -ForegroundColor Yellow
    Write-Host "1. Copy APK to devices: $apkPath" -ForegroundColor Yellow
    Write-Host "2. On each device, enable 'Install from unknown sources'" -ForegroundColor Yellow
    Write-Host "3. Open the APK file on device and install" -ForegroundColor Yellow
    exit 1
}

# Check connected devices
Write-Host "Checking connected devices..." -ForegroundColor Cyan
$devicesOutput = & $adbPath devices
$devices = $devicesOutput | Where-Object { $_ -match "device$" } | ForEach-Object { ($_ -split "\s+")[0] }

if ($devices.Count -eq 0) {
    Write-Host "[ERROR] No devices connected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Connect Android devices via USB" -ForegroundColor Yellow
    Write-Host "2. Enable USB Debugging on each device" -ForegroundColor Yellow
    Write-Host "3. Accept the USB debugging prompt on devices" -ForegroundColor Yellow
    Write-Host "4. Run this script again" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Found $($devices.Count) device(s):" -ForegroundColor Green
foreach ($device in $devices) {
    Write-Host "  - $device" -ForegroundColor Cyan
}
Write-Host ""

# Install on each device
$successCount = 0
foreach ($device in $devices) {
    Write-Host "Installing on device: $device..." -ForegroundColor Cyan
    $installOutput = & $adbPath -s $device install -r $apkPath 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Successfully installed on $device" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "[ERROR] Failed to install on $device" -ForegroundColor Red
        Write-Host $installOutput -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total devices: $($devices.Count)" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $($devices.Count - $successCount)" -ForegroundColor $(if ($successCount -eq $devices.Count) { "Green" } else { "Red" })
Write-Host ""
Write-Host "APK Location: $apkPath" -ForegroundColor Cyan
Write-Host "APK Size: $((Get-Item $apkPath).Length / 1MB) MB" -ForegroundColor Cyan

