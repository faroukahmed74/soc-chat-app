@echo off
title SOC Chat App
echo Starting SOC Chat App...
echo.

REM Check if the web build exists
if not exist "build\web\index.html" (
    echo Error: Web build not found!
    echo Please run 'flutter build web' first.
    echo.
    pause
    exit /b 1
)

REM Open the app in default browser
start "" "build\web\index.html"

echo SOC Chat App launched successfully!
echo.
echo You can also access it at:
echo - Local: http://localhost:8080
echo - Network: http://10.120.9.88:8080
echo.
pause
