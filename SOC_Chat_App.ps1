# SOC Chat App - Standalone Launcher
# This script can be converted to an .exe file

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Standalone Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if web build exists
if (-not (Test-Path "build\web\index.html")) {
    Write-Host "Error: Web build not found!" -ForegroundColor Red
    Write-Host "Please run 'flutter build web' first." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Starting SOC Chat App..." -ForegroundColor Green
Write-Host ""

# Create temporary server directory
$tempDir = "$env:TEMP\soc_chat_server"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

# Copy web build files
Write-Host "Copying app files..." -ForegroundColor Yellow
Copy-Item "build\web\*" $tempDir -Recurse -Force

# Change to temp directory
Set-Location $tempDir

Write-Host "App is starting at: http://localhost:8080" -ForegroundColor Green
Write-Host ""

# Open browser
Write-Host "Opening in browser..." -ForegroundColor Yellow
Start-Process "http://localhost:8080"

Write-Host ""
Write-Host "Starting local server..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Red
Write-Host ""

# Start simple HTTP server using PowerShell
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:8080/")
    $listener.Start()
    
    Write-Host "Server running at http://localhost:8080/" -ForegroundColor Green
    Write-Host ""
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $localPath = $request.Url.LocalPath
        $localPath = $localPath -replace '^/', ''
        if ($localPath -eq '') { $localPath = 'index.html' }
        
        $filePath = Join-Path (Get-Location) $localPath
        
        if (Test-Path $filePath) {
            $content = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
        } else {
            $response.StatusCode = 404
        }
        
        $response.Close()
    }
} catch {
    Write-Host "Error starting server: $_" -ForegroundColor Red
    Write-Host "Please ensure no other application is using port 8080" -ForegroundColor Yellow
} finally {
    if ($listener) {
        $listener.Stop()
        $listener.Close()
    }
}

Write-Host ""
Write-Host "Server stopped." -ForegroundColor Yellow
Read-Host "Press Enter to exit"
