# Monitor both devices for TURN fix verification
# This script monitors for public IP TURN server detection and RELAY candidates

$env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Monitoring TURN Fix Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Looking for:" -ForegroundColor Yellow
Write-Host "  ✅ 'Detected public IP TURN server: 41.33.106.54'" -ForegroundColor Green
Write-Host "  ✅ 'Cloud servers to add: 2' (or more)" -ForegroundColor Green
Write-Host "  ✅ 'RELAY candidate' with 41.33.106.54" -ForegroundColor Green
Write-Host "  ✅ 'TURN Server: 41.33.106.54:XXXX'" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

# Clear logs on both devices
Write-Host "Clearing logs on both devices..." -ForegroundColor Gray
adb -s 52001c52494e6747 logcat -c | Out-Null
adb -s BVK6R19807005234 logcat -c | Out-Null
Write-Host "✅ Logs cleared" -ForegroundColor Green
Write-Host ""

# Start monitoring Device 1
Write-Host "=== Monitoring Device 1 (52001c52494e6747) ===" -ForegroundColor Cyan
$job1 = Start-Job -ScriptBlock {
    $env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
    adb -s 52001c52494e6747 logcat -s flutter:* | Select-String -Pattern "TURN_CONFIG.*public IP|Detected public IP|RELAY|41\.33\.106\.54|Cloud servers to add|Total TURN servers" -Context 0,1 | ForEach-Object {
        if ($_ -match "Detected public IP|Cloud servers to add: [1-9]|RELAY|41\.33\.106\.54") {
            Write-Output "[DEVICE 1] ✅ $_"
        } else {
            Write-Output "[DEVICE 1] $_"
        }
    }
}

# Start monitoring Device 2
Write-Host "=== Monitoring Device 2 (BVK6R19807005234) ===" -ForegroundColor Cyan
$job2 = Start-Job -ScriptBlock {
    $env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
    adb -s BVK6R19807005234 logcat -s flutter:* | Select-String -Pattern "TURN_CONFIG.*public IP|Detected public IP|RELAY|41\.33\.106\.54|Cloud servers to add|Total TURN servers" -Context 0,1 | ForEach-Object {
        if ($_ -match "Detected public IP|Cloud servers to add: [1-9]|RELAY|41\.33\.106\.54") {
            Write-Output "[DEVICE 2] ✅ $_"
        } else {
            Write-Output "[DEVICE 2] $_"
        }
    }
}

Write-Host ""
Write-Host "✅ Monitoring started for both devices!" -ForegroundColor Green
Write-Host ""
Write-Host "📱 Instructions:" -ForegroundColor Yellow
Write-Host "  1. Restart the app on both devices (force close and reopen)" -ForegroundColor White
Write-Host "  2. Make a call between devices (one on mobile data, one on WiFi)" -ForegroundColor White
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
                if ($line -match "Detected public IP|Cloud servers to add: [1-9]|RELAY|41\.33\.106\.54") {
                    Write-Host $line -ForegroundColor Green
                } else {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
        
        if ($output2) {
            foreach ($line in $output2) {
                if ($line -match "Detected public IP|Cloud servers to add: [1-9]|RELAY|41\.33\.106\.54") {
                    Write-Host $line -ForegroundColor Green
                } else {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
} finally {
    Stop-Job -Job $job1, $job2 -ErrorAction SilentlyContinue
    Remove-Job -Job $job1, $job2 -ErrorAction SilentlyContinue
}

