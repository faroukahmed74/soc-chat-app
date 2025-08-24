# SOC Chat App - Local Network Runner (PowerShell)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Local Network Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Getting local IP address..." -ForegroundColor Yellow
$LocalIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*"} | Select-Object -First 1).IPAddress

if (-not $LocalIP) {
    $LocalIP = "localhost"
}

Write-Host "Local IP: $LocalIP" -ForegroundColor Green
Write-Host ""

Write-Host "Starting Flutter app on local network..." -ForegroundColor Yellow
Write-Host "App will be available at: http://$LocalIP`:8080" -ForegroundColor Green
Write-Host ""

Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Red
Write-Host ""

# Run Flutter app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

Read-Host "Press Enter to exit"
