@echo off
title SOC Chat App - Web Server (Simple)
echo =============================================================================
echo SOC Chat App - Starting Web Server (Simple)
echo =============================================================================
echo.

echo [1/2] Getting your IPv4 addresses...
REM Get all IPv4 addresses
set "ip_count=0"
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
    endlocal
)

echo.
echo [2/2] Starting web server...
echo [INFO] Starting server on all network interfaces (0.0.0.0:8082)
echo [INFO] This allows access from any PC on the network
echo.

REM Check if web build exists
if not exist "build\web\index.html" (
    echo [ERROR] Web build not found! Please run start_web_server_optimized.bat first
    pause
    exit /b 1
)

REM Change to web build directory
cd build\web

REM Start the web server
start "SOC Chat App - Web Server" cmd /c "python -m http.server 8082 --bind 0.0.0.0"

REM Wait for server to start
echo [INFO] Waiting for web server to start...
timeout /t 5 /nobreak >nul

echo.
echo =============================================================================
echo WEB SERVER STARTED!
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
