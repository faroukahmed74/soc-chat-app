@echo off
title SOC Chat App - Services Status Checker
echo =============================================================================
echo SOC Chat App - Services Status Checker
echo =============================================================================
echo=

echo [INFO] Checking all services status...
echo=

REM =============================================================================
REM Check MongoDB Service
REM =============================================================================
echo [1/5] Checking MongoDB Service...
sc query MongoDB >nul 2>&1
if errorlevel 1 (
    echo    Status: [RED] NOT INSTALLED OR NOT RUNNING
) else (
    sc query MongoDB | findstr "RUNNING" >nul 2>&1
    if errorlevel 1 (
        echo    Status: [YELLOW] INSTALLED BUT NOT RUNNING
    ) else (
        echo    Status: [GREEN] RUNNING
    )
)

REM =============================================================================
REM Check API Server (PM2)
REM =============================================================================
echo=
echo [2/5] Checking API Server (PM2)...
pm2 list 2>nul | findstr "soc-chat-api" >nul 2>&1
if errorlevel 1 (
    echo    Status: [YELLOW] PM2 process not found, checking Node fallback...
    tasklist | findstr /i "node.exe" >nul 2>&1
    if errorlevel 1 (
        echo    Status: [RED] NOT RUNNING (PM2 and Node)
    ) else (
    echo    Status: [GREEN] RUNNING ^(Node^)
        echo    Note: Could be API or local network server; verify ports below
    )
) else (
    pm2 list | findstr "soc-chat-api" | findstr "online" >nul 2>&1
    if errorlevel 1 (
        echo    Status: [YELLOW] INSTALLED BUT NOT ONLINE
    ) else (
        echo    Status: [GREEN] RUNNING ^(ONLINE^)
        echo    Port: 3003
    )
)

REM =============================================================================
REM Check ngrok Service
REM =============================================================================
echo=
echo [3/5] Checking ngrok Service...
tasklist | findstr "ngrok.exe" >nul 2>&1
if errorlevel 1 (
    echo    Status: [RED] NOT RUNNING
) else (
    echo    Status: [GREEN] RUNNING
    echo    Port: 4040 ^(ngrok web interface^)
    echo    Permanent URL: https://soc-chat-app.ngrok-free.app
    REM Verify ngrok HTTP API is responding
    curl -s http://localhost:4040/api/tunnels >nul 2>&1
    if errorlevel 1 (
        echo    API: [YELLOW] ngrok process running but API not responding
    ) else (
        echo    API: [GREEN] ngrok API responding
    )
)

REM =============================================================================
REM Check Local Network Server
REM =============================================================================
echo=
echo [4/5] Checking Local Network Server...
REM Determine Local Network Server status by port listening instead of generic node.exe
netstat -an | findstr ":3004" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo    Status: [RED] NOT LISTENING (Port 3004)
) else (
    echo    Status: [GREEN] LISTENING ^(Port 3004^)
    echo    Access: http://[YOUR_IP]:3004
)

REM =============================================================================
REM Check Port Status
REM =============================================================================
echo=
echo [5/5] Checking Port Status...
echo    Port 3003 ^(API Server^):
netstat -an | findstr ":3003" >nul 2>&1
if errorlevel 1 (
    echo        [RED] NOT LISTENING
) else (
    echo        [GREEN] LISTENING
)

echo    Port 4040 ^(ngrok Web Interface^):
netstat -an | findstr ":4040" >nul 2>&1
if errorlevel 1 (
    echo        [RED] NOT LISTENING
) else (
    echo        [GREEN] LISTENING
)

echo    Port 27017 ^(MongoDB^):
netstat -an | findstr ":27017" >nul 2>&1
if errorlevel 1 (
    echo        [RED] NOT LISTENING
) else (
    echo        [GREEN] LISTENING
)

echo    Port 3004 ^(Local Network Server^):
netstat -an | findstr ":3004" >nul 2>&1
if errorlevel 1 (
    echo        [RED] NOT LISTENING
) else (
    echo        [GREEN] LISTENING
)

REM =============================================================================
REM Test API Server Response
REM =============================================================================
echo=
echo [BONUS] Testing API Server Response...
curl -s http://localhost:3003/health >nul 2>&1
if errorlevel 1 (
    echo    API Health Check: [RED] NOT RESPONDING
) else (
    echo    API Health Check: [GREEN] RESPONDING
)

echo=
echo [BONUS] Testing Local Network Server Response...
curl -s http://localhost:3004/health >nul 2>&1
if errorlevel 1 (
    echo    Local Network Server: [RED] NOT RESPONDING
) else (
    echo    Local Network Server: [GREEN] RESPONDING
)

REM =============================================================================
REM Test ngrok Tunnel
REM =============================================================================
echo=
echo [BONUS] Testing ngrok Tunnel...
curl -s http://localhost:4040/api/tunnels >nul 2>&1
if errorlevel 1 (
    echo    ngrok Tunnel: [RED] NOT ACCESSIBLE
) else (
    echo    ngrok Tunnel: [GREEN] ACCESSIBLE
)

echo=
echo =============================================================================
echo SERVICES STATUS SUMMARY
echo =============================================================================
echo=

REM Count running services
set "RUNNING_COUNT=0"
set "TOTAL_COUNT=4"

REM Check MongoDB
sc query MongoDB | findstr "RUNNING" >nul 2>&1
if not errorlevel 1 set /a RUNNING_COUNT+=1

REM Check API Server
pm2 list | findstr "soc-chat-api" | findstr "online" >nul 2>&1
if not errorlevel 1 set /a RUNNING_COUNT+=1

REM Check ngrok
tasklist | findstr "ngrok.exe" >nul 2>&1
if not errorlevel 1 set /a RUNNING_COUNT+=1

REM Check Local Network Server
netstat -an | findstr ":3004" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 set /a RUNNING_COUNT+=1

echo [SUMMARY] %RUNNING_COUNT%/%TOTAL_COUNT% services are running
echo=

if "%RUNNING_COUNT%"=="%TOTAL_COUNT%" goto :ALL_OK
goto :SOME_NOT_OK

:ALL_OK
echo [SUCCESS] ALL SERVICES ARE RUNNING!
echo [INFO] Your chat app is ready to use
echo [INFO] Permanent URL: https://soc-chat-app.ngrok-free.app
goto :AFTER_SUMMARY

:SOME_NOT_OK
echo [WARNING] Some services are not running
echo [INFO] To start all services: start_all_services.bat
echo [INFO] To stop all services: stop_all_services.bat
echo [INFO] To restart all services: restart_all_services.bat
goto :AFTER_SUMMARY

:AFTER_SUMMARY

echo=
if /I "%NO_PAUSE%"=="1" goto :NO_PAUSE_DONE
goto :DO_PAUSE

:NO_PAUSE_DONE
echo [INFO] Status check completed (no pause).
goto :END_SCRIPT

:DO_PAUSE
echo [INFO] Press any key to close this window...
pause >nul
goto :END_SCRIPT

:END_SCRIPT
exit /b 0
