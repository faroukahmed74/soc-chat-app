# Monitor both devices for Twilio TURN and media streams
# This script monitors both devices simultaneously for TURN configuration and media stream events

$env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Monitoring Both Devices - Twilio TURN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Looking for:" -ForegroundColor Yellow
Write-Host "  [OK] TURN_CONFIG messages" -ForegroundColor Green
Write-Host "  [OK] Cloud servers to add: 3 (Twilio)" -ForegroundColor Green
Write-Host "  [OK] twilio.com in TURN URLs" -ForegroundColor Green
Write-Host "  [OK] RELAY candidates" -ForegroundColor Green
Write-Host "  [OK] ON_TRACK events (remote media)" -ForegroundColor Green
Write-Host "  [OK] ICE_CONNECTION Connected/Completed" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

# Clear logs on both devices
Write-Host "Clearing logs on both devices..." -ForegroundColor Gray
adb -s 52001c52494e6747 logcat -c | Out-Null
adb -s BVK6R19807005234 logcat -c | Out-Null
Write-Host "[OK] Logs cleared" -ForegroundColor Green
Write-Host ""

# Start monitoring Device 1
Write-Host "=== Starting Device 1 Monitor (52001c52494e6747) ===" -ForegroundColor Cyan
$job1 = Start-Job -ScriptBlock {
    $env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
    adb -s 52001c52494e6747 logcat -s flutter:* | Select-String -Pattern "TURN_CONFIG|Cloud servers|twilio|RELAY|ON_TRACK|ICE_CONNECTION" -Context 0,1 | ForEach-Object {
        $line = $_.ToString()
        if ($line -match "Cloud servers to add: [1-9]|twilio\.com|RELAY|ON_TRACK.*REMOTE|ICE_CONNECTION.*Connected|ICE_CONNECTION.*Completed") {
            Write-Output "[DEVICE 1] [OK] $line"
        } else {
            Write-Output "[DEVICE 1] $line"
        }
    }
}

# Start monitoring Device 2
Write-Host "=== Starting Device 2 Monitor (BVK6R19807005234) ===" -ForegroundColor Cyan
$job2 = Start-Job -ScriptBlock {
    $env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
    adb -s BVK6R19807005234 logcat -s flutter:* | Select-String -Pattern "TURN_CONFIG|Cloud servers|twilio|RELAY|ON_TRACK|ICE_CONNECTION" -Context 0,1 | ForEach-Object {
        $line = $_.ToString()
        if ($line -match "Cloud servers to add: [1-9]|twilio\.com|RELAY|ON_TRACK.*REMOTE|ICE_CONNECTION.*Connected|ICE_CONNECTION.*Completed") {
            Write-Output "[DEVICE 2] [OK] $line"
        } else {
            Write-Output "[DEVICE 2] $line"
        }
    }
}

Write-Host ""
Write-Host "[OK] Monitoring started for both devices!" -ForegroundColor Green
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "  1. Restart the app on both devices (force close and reopen)" -ForegroundColor White
Write-Host "  2. Make a call between devices (cross-network if possible)" -ForegroundColor White
Write-Host "  3. Watch for the logs below..." -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Monitor job outputs
try {
    while ($true) {
        $output1 = Receive-Job -Job $job1 -ErrorAction SilentlyContinue
        $output2 = Receive-Job -Job $job2 -ErrorAction SilentlyContinue
        
        if ($output1) {
            foreach ($line in $output1) {
                if ($line -match "Cloud servers to add: [1-9]|twilio\.com|RELAY|ON_TRACK.*REMOTE|ICE_CONNECTION.*Connected|ICE_CONNECTION.*Completed") {
                    Write-Host $line -ForegroundColor Green
                } else {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
        
        if ($output2) {
            foreach ($line in $output2) {
                if ($line -match "Cloud servers to add: [1-9]|twilio\.com|RELAY|ON_TRACK.*REMOTE|ICE_CONNECTION.*Connected|ICE_CONNECTION.*Completed") {
                    Write-Host $line -ForegroundColor Green
                } else {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
} catch {
    Write-Host "`n[WARN] Monitoring stopped: $_" -ForegroundColor Yellow
} finally {
    Write-Host "`nStopping monitoring jobs..." -ForegroundColor Yellow
    Stop-Job -Job $job1, $job2 -ErrorAction SilentlyContinue
    Remove-Job -Job $job1, $job2 -ErrorAction SilentlyContinue
    Write-Host "[OK] Monitoring stopped" -ForegroundColor Green
}

