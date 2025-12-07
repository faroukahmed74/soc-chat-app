# Monitor call logs from both devices
# This script captures logs related to calls from both connected Android devices

param(
    [switch]$Device1Only = $false,
    [switch]$Device2Only = $false
)

$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adbPath)) {
    Write-Host "❌ ADB not found at: $adbPath" -ForegroundColor Red
    exit 1
}

# Get connected devices
$devices = & $adbPath devices | Select-String -Pattern "device$" | ForEach-Object { $_.Line.Split("`t")[0] }

if ($devices.Count -eq 0) {
    Write-Host "❌ No devices connected" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Monitoring Call Logs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Connected devices: $($devices.Count)" -ForegroundColor Yellow
Write-Host ""

# Filter for call-related logs
$filter = "WEBRTC|Call|CALL|call_invitation|webrtc|CallScreen|CHAT_SCREEN_MONGODB|MAIN_APP|REALTIME"

if ($Device1Only -and $devices.Count -ge 1) {
    Write-Host "Monitoring Device 1: $($devices[0])" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow
    & $adbPath -s $devices[0] logcat -c  # Clear log buffer
    & $adbPath -s $devices[0] logcat | Select-String -Pattern $filter
} elseif ($Device2Only -and $devices.Count -ge 2) {
    Write-Host "Monitoring Device 2: $($devices[1])" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow
    & $adbPath -s $devices[1] logcat -c  # Clear log buffer
    & $adbPath -s $devices[1] logcat | Select-String -Pattern $filter
} else {
    # Monitor both devices in separate windows
    Write-Host "Opening separate windows for each device..." -ForegroundColor Yellow
    Write-Host "Device 1: $($devices[0])" -ForegroundColor Green
    Write-Host "Device 2: $($devices[1])" -ForegroundColor Green
    Write-Host ""
    
    # Start monitoring for Device 1
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "& '$adbPath' -s $($devices[0]) logcat -c; & '$adbPath' -s $($devices[0]) logcat | Select-String -Pattern '$filter'" -WindowStyle Normal
    
    if ($devices.Count -ge 2) {
        # Start monitoring for Device 2
        Start-Sleep -Seconds 1
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "& '$adbPath' -s $($devices[1]) logcat -c; & '$adbPath' -s $($devices[1]) logcat | Select-String -Pattern '$filter'" -WindowStyle Normal
    }
    
    Write-Host "✅ Log monitoring windows opened for both devices" -ForegroundColor Green
    Write-Host "Make a call and watch the logs in the opened windows" -ForegroundColor Yellow
}

