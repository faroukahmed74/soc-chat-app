# Monitor both devices for RELAY candidates simultaneously

$env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Monitoring Both Devices for RELAY Candidates" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device 1: 52001c52494e6747" -ForegroundColor Yellow
Write-Host "Device 2: BVK6R19807005234" -ForegroundColor Yellow
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. Make a call between the two devices" -ForegroundColor White
Write-Host "2. One device should be on mobile data (different network)" -ForegroundColor White
Write-Host "3. Watch for RELAY candidates below" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Clear logs on both devices
Write-Host "Clearing logs on both devices..." -ForegroundColor Gray
adb -s 52001c52494e6747 logcat -c | Out-Null
adb -s BVK6R19807005234 logcat -c | Out-Null

Write-Host "✅ Logs cleared" -ForegroundColor Green
Write-Host ""
Write-Host "Monitoring... (Make a call now!)" -ForegroundColor Green
Write-Host ""

# Start monitoring both devices
$job1 = Start-Job -ScriptBlock {
    $env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
    adb -s 52001c52494e6747 logcat -s flutter:* | Select-String -Pattern "RELAY|ICE_CANDIDATE|ICE_CONNECTION" | ForEach-Object {
        Write-Output "[DEVICE 1] $_"
    }
}

$job2 = Start-Job -ScriptBlock {
    $env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
    adb -s BVK6R19807005234 logcat -s flutter:* | Select-String -Pattern "RELAY|ICE_CANDIDATE|ICE_CONNECTION" | ForEach-Object {
        Write-Output "[DEVICE 2] $_"
    }
}

# Monitor job outputs
try {
    while ($true) {
        $output1 = Receive-Job -Job $job1 -ErrorAction SilentlyContinue
        $output2 = Receive-Job -Job $job2 -ErrorAction SilentlyContinue
        
        if ($output1) {
            foreach ($line in $output1) {
                if ($line -match "RELAY") {
                    Write-Host $line -ForegroundColor Green
                } elseif ($line -match "ICE_CANDIDATE") {
                    Write-Host $line -ForegroundColor Cyan
                } else {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
        
        if ($output2) {
            foreach ($line in $output2) {
                if ($line -match "RELAY") {
                    Write-Host $line -ForegroundColor Green
                } elseif ($line -match "ICE_CANDIDATE") {
                    Write-Host $line -ForegroundColor Cyan
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

