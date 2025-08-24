# SOC Chat App - Built Web App Runner (PowerShell)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Built Web App Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Starting built web app..." -ForegroundColor Yellow
Write-Host "App will be available at: http://localhost:8080" -ForegroundColor Green
Write-Host ""

Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Red
Write-Host ""

# Change to the built web directory
Set-Location "build\web"

# Start Python HTTP server
try {
    python -m http.server 8080
} catch {
    Write-Host "Python not found. Trying alternative methods..." -ForegroundColor Yellow
    
    # Try using Node.js if available
    try {
        npx http-server -p 8080
    } catch {
        Write-Host "No HTTP server found. Please install Python or Node.js." -ForegroundColor Red
        Write-Host "Or use the development version: .\run_local_network.bat" -ForegroundColor Yellow
    }
}

Read-Host "Press Enter to exit"
