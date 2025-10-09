@echo off
title SOC Chat App - Check Auto-Start Status
echo =============================================================================
echo SOC Chat App - Auto-Start Status Checker
echo =============================================================================
echo.

echo [INFO] Checking auto-start configuration...
echo.

REM Check if running as administrator
net session >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Not running as administrator - some checks may be limited
    echo.
)

echo [1/4] Checking Scheduled Task...
schtasks /query /tn "SOC Chat App Services" >nul 2>&1
if errorlevel 1 (
    echo    Status: [RED] NOT CONFIGURED
) else (
    echo    Status: [GREEN] CONFIGURED
    echo    Task Name: SOC Chat App Services
)

echo.
echo [2/4] Checking Startup Folder Shortcut...
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if exist "%STARTUP_FOLDER%\SOC Chat App Services.lnk" (
    echo    Status: [GREEN] EXISTS
    echo    Location: %STARTUP_FOLDER%\SOC Chat App Services.lnk
) else (
    echo    Status: [RED] NOT FOUND
)

echo.
echo [3/4] Checking Desktop Shortcut...
set "DESKTOP=%USERPROFILE%\Desktop"
if exist "%DESKTOP%\SOC Chat App - Check Status.lnk" (
    echo    Status: [GREEN] EXISTS
    echo    Location: %DESKTOP%\SOC Chat App - Check Status.lnk
) else (
    echo    Status: [RED] NOT FOUND
)

echo.
echo [4/4] Checking Temporary Files...
if exist "%TEMP%\soc_chat_startup.bat" (
    echo    Status: [GREEN] EXISTS
    echo    File: %TEMP%\soc_chat_startup.bat
    echo    Contains: MongoDB, API Server, ngrok, Local Network Server
) else (
    echo    Status: [RED] NOT FOUND
)

echo.
echo =============================================================================
echo AUTO-START STATUS SUMMARY
echo =============================================================================
echo.

REM Count configured items
set "CONFIGURED_COUNT=0"
set "TOTAL_COUNT=4"

REM Check scheduled task
schtasks /query /tn "SOC Chat App Services" >nul 2>&1
if not errorlevel 1 set /a CONFIGURED_COUNT+=1

REM Check startup shortcut
if exist "%STARTUP_FOLDER%\SOC Chat App Services.lnk" set /a CONFIGURED_COUNT+=1

REM Check desktop shortcut
if exist "%DESKTOP%\SOC Chat App - Check Status.lnk" set /a CONFIGURED_COUNT+=1

REM Check temp files
if exist "%TEMP%\soc_chat_startup.bat" set /a CONFIGURED_COUNT+=1

echo [SUMMARY] %CONFIGURED_COUNT%/%TOTAL_COUNT% auto-start items are configured
echo.

if %CONFIGURED_COUNT%==%TOTAL_COUNT% (
    echo [SUCCESS] AUTO-START IS FULLY CONFIGURED!
    echo [INFO] Services will start automatically when PC boots:
    echo   - MongoDB Database
    echo   - API Server (port 3003)
    echo   - ngrok Tunnel (permanent URL)
    echo   - Local Network Server (port 3004)
    echo [INFO] To disable: setup_autostart_disable.bat
) else if %CONFIGURED_COUNT%==0 (
    echo [INFO] AUTO-START IS NOT CONFIGURED
    echo [INFO] To enable: setup_autostart_services.bat
) else (
    echo [WARNING] AUTO-START IS PARTIALLY CONFIGURED
    echo [INFO] Some items may be missing
    echo [INFO] To fix: setup_autostart_services.bat
)

echo.
echo [INFO] Press any key to close this window...
pause >nul