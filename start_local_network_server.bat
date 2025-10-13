@echo off
title SOC Chat App - Start Local Network Server
echo =============================================================================
echo SOC Chat App - Start Local Network Server
echo =============================================================================
echo.

echo [INFO] Starting local network server that uses the same MongoDB database
echo [INFO] Other PCs on the network can access the chat app locally
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not in PATH
    echo [INFO] Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if we're in the right directory
if not exist "servers\local_api_server\server.js" (
    echo [ERROR] Please run this script from the project root directory
    echo [INFO] Expected: servers\local_api_server\server.js
    pause
    exit /b 1
)

echo [1/4] Getting network IP addresses...
echo.

REM Get all IPv4 addresses
set "ip_count=0"
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    set /a ip_count+=1
    echo    IP Address !ip_count!: !ip!
    endlocal
)

echo.
echo [2/4] Checking MongoDB connection...
echo [INFO] Testing connection to MongoDB database...

REM Test MongoDB connection
curl -s http://localhost:3003/health >nul 2>&1
if errorlevel 1 (
    echo [WARNING] MongoDB/API server not running on localhost:3003
    echo [ERROR] Please start all services first using: start_all_services.bat
    echo [INFO] This script only starts the local network server
    echo [INFO] MongoDB and API server must be running first
    pause
    exit /b 1
) else (
    echo [SUCCESS] MongoDB and API server are running
)

echo.
echo [3/4] Starting local network server...
echo [INFO] Starting server on all network interfaces (0.0.0.0:3004)
echo [INFO] This allows access from any PC on the network
echo.

REM Check if port 3004 is already in use
netstat -an | findstr ":3004" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [ERROR] Port 3004 is already in use. Please stop the existing service.
    echo [HINT] Try: stop_all_services.bat
    pause
    exit /b 1
)

REM Change to API server directory
cd servers\local_api_server

REM Start the local network server
start "SOC Chat App - Local Network Server" cmd /c "node local_network_config.js"

REM Wait for server to start
echo [INFO] Waiting for local network server to start...
timeout /t 5 /nobreak >nul

echo.
echo [4/4] Testing local network server...
echo [INFO] Testing if server is responding...

REM Test if server is running
curl -s http://localhost:3004/health >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Server may still be starting...
) else (
    echo [SUCCESS] Local network server is responding!
)

echo.
echo =============================================================================
echo LOCAL NETWORK SERVER STARTED!
echo =============================================================================
echo.

REM Get the primary IP for display
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "primary_ip=%%a"
    setlocal enabledelayedexpansion
    set "primary_ip=!primary_ip: =!"
    echo [SUCCESS] Your chat app is now accessible on the local network!
    echo.
    echo [ACCESS INFORMATION]:
    echo   - Local Network API: http://!primary_ip!:3004
    echo   - Local API (this PC): http://localhost:3004
    echo   - Original API (this PC): http://localhost:3003
    echo.
    echo [DATABASE]:
    echo   - Uses the SAME MongoDB database as the main server
    echo   - All data is shared between local and network access
    echo.
    echo [INSTRUCTIONS FOR OTHER PCS]:
    echo   1. Make sure they are on the same network (WiFi/LAN)
    echo   2. Configure the app to use: http://!primary_ip!:3004
    echo   3. They can now access the chat app locally
    echo.
    endlocal
    goto :found_ip
)

:found_ip

echo [INFO] Local network server is running in a separate window
echo [INFO] To stop the server: Close the "SOC Chat App - Local Network Server" window
echo [INFO] To check IP addresses: run show_network_ips.bat
echo [INFO] To check services: run check_services_status.bat
echo.
pause
