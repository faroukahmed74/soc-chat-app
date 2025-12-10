$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$deviceId = "BVK6R19807005234"
Write-Host "`n Capturing logs from device $deviceId..." -ForegroundColor Cyan
Write-Host "   This will capture the last 500 log entries..." -ForegroundColor Yellow
& $adb -s $deviceId logcat -d -v time | Select-Object -Last 500 | Out-File -FilePath "device_logs.txt" -Encoding UTF8
Write-Host " Logs saved to device_logs.txt" -ForegroundColor Green
Write-Host "`n Searching for relevant patterns..." -ForegroundColor Cyan
Get-Content "device_logs.txt" | Select-String -Pattern "TURN|ICE|RELAY|CLOUD|Twilio|PEER|CONNECTION|flutter" -CaseSensitive:$false | Select-Object -Last 100
