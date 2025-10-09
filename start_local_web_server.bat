@echo off
title SOC Chat App - Start Local Web Server
echo =============================================================================
echo SOC Chat App - Start Local Web Server
echo =============================================================================
echo.

echo [INFO] Starting local web server for network access...
echo [INFO] This will make the app accessible from other PCs on the network
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter is not installed or not in PATH
    echo [INFO] Please install Flutter from https://flutter.dev
    pause
    exit /b 1
)

REM Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo [ERROR] Please run this script from the Flutter project root directory
    echo [INFO] Expected: pubspec.yaml file
    pause
    exit /b 1
)

echo [1/4] Getting network IP addresses...
echo.

REM Get all IPv4 addresses
set "ip_list="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    echo    Available IP: !ip!
    if "!ip_list!"=="" (
        set "ip_list=!ip!"
    ) else (
        set "ip_list=!ip_list!, !ip!"
    )
    endlocal
)

echo.
echo [2/4] Building Flutter web app...
echo [INFO] This may take a few minutes...
flutter build web --release
if errorlevel 1 (
    echo [ERROR] Failed to build web app
    pause
    exit /b 1
)

echo.
echo [3/4] Starting web server...
echo [INFO] Starting server on all network interfaces (0.0.0.0:8082)
echo [INFO] This allows access from any PC on the network
echo.

REM Start the web server
start "SOC Chat App - Web Server" cmd /c "cd build\web && python -m http.server 8082 --bind 0.0.0.0"

REM Wait for server to start
echo [INFO] Waiting for web server to start...
timeout /t 5 /nobreak >nul

echo.
echo [4/4] Testing server...
echo [INFO] Testing if server is responding...

REM Test if server is running
curl -s http://localhost:8082 >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Server may still be starting...
) else (
    echo [SUCCESS] Web server is responding!
)

echo.
echo =============================================================================
echo LOCAL WEB SERVER STARTED!
echo =============================================================================
echo.
echo [SUCCESS] Your chat app is now accessible on the local network!
echo.

REM Get the primary IP for display
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "primary_ip=%%a"
    setlocal enabledelayedexpansion
    set "primary_ip=!primary_ip: =!"
    echo [ACCESS URLS]:
    echo   - Primary: http://!primary_ip!:8082
    echo   - Local: http://localhost:8082
    echo   - All IPs: %ip_list%
    echo.
    echo [INSTRUCTIONS]:
    echo   1. Share the IP address with other PCs on the network
    echo   2. They can access the app at: http://!primary_ip!:8082
    echo   3. No internet required - works on local network only
    echo.
    endlocal
    goto :found_ip
)

:found_ip

echo [INFO] Web server is running in a separate window
echo [INFO] To stop the server: Close the "SOC Chat App - Web Server" window
echo [INFO] To check IP addresses: run show_network_ips.bat
echo.
pause


