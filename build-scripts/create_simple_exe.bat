@echo off
title SOC Chat App - Standalone
echo ========================================
echo   SOC Chat App - Standalone Version
echo ========================================
echo.

REM Check if web build exists
if not exist "build\web\index.html" (
    echo Error: Web build not found!
    echo Please run 'flutter build web' first.
    echo.
    pause
    exit /b 1
)

echo Starting SOC Chat App...
echo.

REM Create temporary server directory
if not exist "%TEMP%\soc_chat_server" mkdir "%TEMP%\soc_chat_server"
xcopy "build\web\*" "%TEMP%\soc_chat_server\" /E /I /Y

REM Change to temp directory and start server
cd /d "%TEMP%\soc_chat_server"

echo App is starting at: http://localhost:8080
echo.
echo Opening in browser...
start "" "http://localhost:8080"

echo.
echo Starting local server...
echo Press Ctrl+C to stop the server
echo.

REM Try Python first, then fallback to other methods
python -m http.server 8080 2>nul
if errorlevel 1 (
    echo Python not found, trying alternative...
    REM Try using PowerShell to start a simple server
    powershell -Command "& { $listener = New-Object System.Net.HttpListener; $listener.Prefixes.Add('http://localhost:8080/'); $listener.Start(); Write-Host 'Server running at http://localhost:8080/'; while ($listener.IsListening) { $context = $listener.GetContext(); $request = $context.Request; $response = $context.Response; $localPath = $request.Url.LocalPath; $localPath = $localPath -replace '^/', ''; if ($localPath -eq '') { $localPath = 'index.html' }; $filePath = Join-Path (Get-Location) $localPath; if (Test-Path $filePath) { $content = [System.IO.File]::ReadAllBytes($filePath); $response.ContentLength64 = $content.Length; $response.OutputStream.Write($content, 0, $content.Length); } else { $response.StatusCode = 404; } $response.Close(); } }"
)

echo.
echo Server stopped.
pause
