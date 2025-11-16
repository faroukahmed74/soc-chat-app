# =============================================================================
# START OFFLINE WEB SERVER
# =============================================================================
# Starts the offline web server that serves the Flutter app and proxies API requests

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Offline Web Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if build exists
if (-not (Test-Path "build\web\index.html")) {
    Write-Host "❌ Web build not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run setup first:" -ForegroundColor Yellow
    Write-Host "   .\servers\setup_offline_web.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Check if API server is running (optional check)
Write-Host "Checking API server connection..." -ForegroundColor Gray
$apiTarget = $env:API_TARGET
if (-not $apiTarget) {
    $apiTarget = "http://127.0.0.1:3003"
}

try {
    $response = Invoke-WebRequest -Uri "$apiTarget/api/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ API server is running" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️  API server may not be running at $apiTarget" -ForegroundColor Yellow
    Write-Host "   The web app will still start, but API calls may fail" -ForegroundColor Yellow
}
Write-Host ""

# Start the server
Write-Host "Starting offline web server..." -ForegroundColor Green
Write-Host ""

Push-Location servers
node offline_web_server.js
Pop-Location

