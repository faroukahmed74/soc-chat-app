@echo off
title SOC Chat App - Setup Auto-Start Services
echo =============================================================================
echo SOC Chat App - Setting Up Auto-Start Services
echo =============================================================================
echo.

echo [INFO] This will set up all services to start automatically when PC boots
echo [INFO] Services will start in the background when Windows starts
echo.

REM Check if running as administrator
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] This script requires Administrator privileges
    echo [INFO] Please right-click and "Run as administrator"
    pause
    exit /b 1
)

echo [1/4] Creating startup script...
REM Create a startup script that will run all services
echo @echo off > "%TEMP%\soc_chat_startup.bat"
echo title SOC Chat App - Auto-Start Services >> "%TEMP%\soc_chat_startup.bat"
echo echo Starting SOC Chat App services... >> "%TEMP%\soc_chat_startup.bat"
echo timeout /t 30 /nobreak ^>nul >> "%TEMP%\soc_chat_startup.bat"
echo cd /d "%~dp0" >> "%TEMP%\soc_chat_startup.bat"
echo call start_all_services.bat >> "%TEMP%\soc_chat_startup.bat"

echo [2/4] Creating Windows Scheduled Task...
REM Create a scheduled task that runs at startup
schtasks /create /tn "SOC Chat App Services" /tr "\"%TEMP%\soc_chat_startup.bat\"" /sc onstart /ru SYSTEM /f >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to create scheduled task
    pause
    exit /b 1
) else (
    echo [SUCCESS] Scheduled task created successfully
)

echo [3/4] Creating startup folder shortcut...
REM Create a shortcut in the startup folder as backup
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if not exist "%STARTUP_FOLDER%" mkdir "%STARTUP_FOLDER%"

REM Create a VBS script to create the shortcut
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\create_shortcut.vbs"
echo sLinkFile = "%STARTUP_FOLDER%\SOC Chat App Services.lnk" >> "%TEMP%\create_shortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\create_shortcut.vbs"
echo oLink.TargetPath = "%~dp0start_all_services.bat" >> "%TEMP%\create_shortcut.vbs"
echo oLink.WorkingDirectory = "%~dp0" >> "%TEMP%\create_shortcut.vbs"
echo oLink.Description = "SOC Chat App - Start All Services" >> "%TEMP%\create_shortcut.vbs"
echo oLink.Save >> "%TEMP%\create_shortcut.vbs"

cscript //nologo "%TEMP%\create_shortcut.vbs" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Failed to create startup folder shortcut
) else (
    echo [SUCCESS] Startup folder shortcut created
)

echo [4/4] Creating service status checker...
REM Create a desktop shortcut for easy status checking
set "DESKTOP=%USERPROFILE%\Desktop"
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\create_desktop_shortcut.vbs"
echo sLinkFile = "%DESKTOP%\SOC Chat App - Check Status.lnk" >> "%TEMP%\create_desktop_shortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\create_desktop_shortcut.vbs"
echo oLink.TargetPath = "%~dp0check_services_status.bat" >> "%TEMP%\create_desktop_shortcut.vbs"
echo oLink.WorkingDirectory = "%~dp0" >> "%TEMP%\create_desktop_shortcut.vbs"
echo oLink.Description = "SOC Chat App - Check Services Status" >> "%TEMP%\create_desktop_shortcut.vbs"
echo oLink.Save >> "%TEMP%\create_desktop_shortcut.vbs"

cscript //nologo "%TEMP%\create_desktop_shortcut.vbs" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Failed to create desktop shortcut
) else (
    echo [SUCCESS] Desktop shortcut created
)

echo.
echo =============================================================================
echo AUTO-START SETUP COMPLETE!
echo =============================================================================
echo.
echo [SUCCESS] All services will now start automatically when PC boots
echo.
echo What was created:
echo   - Scheduled Task: "SOC Chat App Services" (runs at startup)
echo   - Startup Folder Shortcut: SOC Chat App Services.lnk
echo   - Desktop Shortcut: SOC Chat App - Check Status.lnk
echo.
echo Services that will auto-start:
echo   - MongoDB Database
echo   - API Server (port 3003)
echo   - ngrok Tunnel (permanent URL)
echo   - Local Network Server (port 3004)
echo   - Local Web Server (port 8082)
echo.
echo [INFO] Services will start 30 seconds after Windows boots
echo [INFO] Use the desktop shortcut to check service status anytime
echo [INFO] Local network access will be available at:
echo   - API Server: http://[YOUR_IP]:3004
echo   - Web App: http://[YOUR_IP]:8082
echo.
echo [INFO] To disable auto-start: setup_autostart_disable.bat
echo.
pause
