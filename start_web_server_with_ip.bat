@echo off
title SOC Chat App - Web Server with IP
echo =============================================================================
echo SOC Chat App - Starting Web Server with Your IP Address
echo =============================================================================
echo.

echo [1/4] Getting your IPv4 addresses...
REM Get all IPv4 addresses
set "ip_count=0"
set "ip_list="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    set /a ip_count+=1
    echo [SUCCESS] IP Address !ip_count!: !ip!
    if "!ip_count!"=="1" (
        set "primary_ip=!ip!"
    )
    if "!ip_count!"=="2" (
        set "secondary_ip=!ip!"
    )
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

REM Change to web build directory
cd build\web

REM Start the web server
start "SOC Chat App - Web Server" cmd /c "python -m http.server 8082 --bind 0.0.0.0"

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
echo WEB SERVER STARTED WITH YOUR IP!
echo =============================================================================
echo.
echo [SUCCESS] Your chat app is now accessible on the local network!
echo.
echo [YOUR ACCESS URLS]:
echo   - Primary Network: http://%primary_ip%:8082
if defined secondary_ip (
    echo   - Secondary Network: http://%secondary_ip%:8082
)
echo   - Local: http://localhost:8082
echo.
echo [INSTRUCTIONS FOR OTHER PCS]:
echo   1. Share these URLs with other PCs:
echo      - Network 1: http://%primary_ip%:8082
if defined secondary_ip (
    echo      - Network 2: http://%secondary_ip%:8082
)
echo   2. They can access the app in any web browser
echo   3. No internet required - works on local network only
echo.
echo [INFO] Web server is running in a separate window
echo [INFO] To stop the server: Close the "SOC Chat App - Web Server" window
echo.
pause
