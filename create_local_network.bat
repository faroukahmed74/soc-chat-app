@echo off
title SOC Chat App - Create Local Network Access
echo =============================================================================
echo SOC Chat App - Create Local Network Access
echo =============================================================================
echo.

echo [INFO] This will create a local network access point for your chat app
echo [INFO] Other PCs on the same network can access the app via IP address
echo.

REM Get all network adapters and their IP addresses
echo [1/3] Getting network adapter information...
echo.

REM Get IPv4 addresses for all active network adapters
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    echo    Active IP Address: !ip!
    endlocal
)

echo.
echo [2/3] Starting local web server...
echo [INFO] Starting web server on all available IP addresses
echo.

REM Start the web server on port 8082 (Flutter web build)
echo [INFO] Starting Flutter web server...
start "Flutter Web Server" /min cmd /c "flutter run -d web-server --web-port 8082 --web-hostname 0.0.0.0"

REM Wait for Flutter to start
echo [INFO] Waiting for Flutter web server to start...
timeout /t 10 /nobreak >nul

echo.
echo [3/3] Creating network access URLs...
echo.

REM Get the primary IP address (usually the first one)
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "primary_ip=%%a"
    setlocal enabledelayedexpansion
    set "primary_ip=!primary_ip: =!"
    echo [SUCCESS] Primary access URL: http://!primary_ip!:8082
    echo [INFO] Other PCs can access the app at: http://!primary_ip!:8082
    endlocal
    goto :found_ip
)

:found_ip

echo.
echo =============================================================================
echo LOCAL NETWORK ACCESS CREATED!
echo =============================================================================
echo.
echo [SUCCESS] Your chat app is now accessible on the local network!
echo.
echo Access URLs:
echo   - Primary: http://%primary_ip%:8082
echo   - Alternative: Use any IP address shown above with :8082
echo.
echo [INFO] Other PCs on the same network can access the app using these URLs
echo [INFO] No internet connection required - works on local network only
echo.
echo [INFO] To stop the web server: Close the Flutter web server window
echo [INFO] To check network IPs: run show_network_ips.bat
echo.
pause


