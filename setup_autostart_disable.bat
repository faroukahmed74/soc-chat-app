@echo off
title SOC Chat App - Disable Auto-Start Services
echo =============================================================================
echo SOC Chat App - Disabling Auto-Start Services
echo =============================================================================
echo.

echo [INFO] This will disable automatic startup of services
echo [INFO] Services will no longer start when PC boots
echo [INFO] Affected services: MongoDB, API Server, ngrok, Local Network Server
echo.

REM Check if running as administrator
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] This script requires Administrator privileges
    echo [INFO] Please right-click and "Run as administrator"
    pause
    exit /b 1
)

echo [1/3] Removing scheduled task...
schtasks /delete /tn "SOC Chat App Services" /f >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Scheduled task not found or already removed
) else (
    echo [SUCCESS] Scheduled task removed
)

echo [2/3] Removing startup folder shortcut...
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if exist "%STARTUP_FOLDER%\SOC Chat App Services.lnk" (
    del "%STARTUP_FOLDER%\SOC Chat App Services.lnk" >nul 2>&1
    echo [SUCCESS] Startup folder shortcut removed
) else (
    echo [INFO] Startup folder shortcut not found
)

echo [3/4] Stopping any running local network server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - Local Network Server*" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Local Network Server was not running
) else (
    echo [SUCCESS] Local Network Server stopped
)

echo [4/4] Cleaning up temporary files...
if exist "%TEMP%\soc_chat_startup.bat" del "%TEMP%\soc_chat_startup.bat" >nul 2>&1
if exist "%TEMP%\create_shortcut.vbs" del "%TEMP%\create_shortcut.vbs" >nul 2>&1
if exist "%TEMP%\create_desktop_shortcut.vbs" del "%TEMP%\create_desktop_shortcut.vbs" >nul 2>&1
echo [SUCCESS] Temporary files cleaned up

echo.
echo =============================================================================
echo AUTO-START DISABLED!
echo =============================================================================
echo.
echo [SUCCESS] Services will no longer start automatically
echo [INFO] You can still start services manually using:
echo   - start_all_services.bat (starts all 4 services)
echo   - check_services_status.bat (check service status)
echo   - start_local_network_server.bat (local network only)
echo.
echo [INFO] Services that will NOT auto-start:
echo   - MongoDB Database
echo   - API Server (port 3003)
echo   - ngrok Tunnel (permanent URL)
echo   - Local Network Server (port 3004)
echo.
echo [INFO] To re-enable auto-start: setup_autostart_services.bat
echo.
pause