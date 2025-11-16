# =============================================================================
# SERVE WEB OFFLINE APP SCRIPT
# =============================================================================
# This script serves the offline web app on local network
# Accessible at http://[YOUR_IPV4]:8082

$PORT = "8082"
$BUILD_DIR = "build\web"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Offline Web Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if build directory exists
if (-not (Test-Path $BUILD_DIR)) {
    Write-Host "Error: Build directory not found: $BUILD_DIR" -ForegroundColor Red
    Write-Host "Please run build_web_offline_release.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Serving web app from: $BUILD_DIR" -ForegroundColor Green
Write-Host "Port: $PORT" -ForegroundColor Green
Write-Host ""

# Get local IP address
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress

if ($localIP) {
    Write-Host "Access the app from other devices on your network:" -ForegroundColor Yellow
    Write-Host "  http://$localIP`:$PORT" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "Access the app at:" -ForegroundColor Yellow
    Write-Host "  http://localhost:$PORT" -ForegroundColor Cyan
    Write-Host "  http://[YOUR_IPV4]:$PORT" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Try to use Python http.server first
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    Write-Host "Starting Python HTTP server..." -ForegroundColor Green
    Set-Location $BUILD_DIR
    python -m http.server $PORT
} else {
    # Try Node.js http-server
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        Write-Host "Starting Node.js http-server..." -ForegroundColor Green
        Write-Host "Installing http-server if needed..." -ForegroundColor Gray
        npx --yes http-server $BUILD_DIR -p $PORT -c-1 --cors
    } else {
        Write-Host "Error: Neither Python nor Node.js found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install one of the following:" -ForegroundColor Yellow
        Write-Host "  1. Python 3.x (for: python -m http.server)" -ForegroundColor Gray
        Write-Host "  2. Node.js (for: npx http-server)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Or manually serve the files from: $BUILD_DIR" -ForegroundColor Yellow
        exit 1
    }
}

