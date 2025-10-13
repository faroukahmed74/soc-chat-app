@echo off
title SOC Chat App - API Server Service
echo =============================================================================
echo SOC Chat App - Starting API Server Service
echo =============================================================================
echo.

echo [INFO] Changing to API server directory...
cd servers\local_api_server

REM Ensure expected files exist
if not exist "server.js" (
    echo [ERROR] server.js not found in servers\local_api_server
    echo [HINT] Run this from the project root or check the repo
    pause
    exit /b 1
)

REM Force host/port to match project expectations
set "HOST=0.0.0.0"
set "PORT=3003"

echo [INFO] Checking if port 3003 is free...
netstat -an | findstr ":3003" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [WARNING] Port 3003 appears to be in use.
    echo [HINT] If start fails, run stop_all_services.bat to free the port
)

REM Check if PM2 is available
pm2 -v >nul 2>&1
if errorlevel 1 (
    echo [WARNING] PM2 not available. Starting API with Node directly...
    start "SOC Chat App - API Server (Node)" cmd /c "node server.js"
    set "START_METHOD=Node"
) else (
    echo [INFO] Starting API Server with PM2...
    pm2 start server.js --name "soc-chat-api" --update-env >nul 2>&1
    if errorlevel 1 (
        echo [INFO] PM2 start failed or process exists, attempting restart...
        pm2 restart soc-chat-api --update-env >nul 2>&1
        if errorlevel 1 (
            echo [ERROR] PM2 restart failed. Falling back to Node...
            start "SOC Chat App - API Server (Node)" cmd /c "node server.js"
            set "START_METHOD=Node"
        ) else (
            echo [SUCCESS] API Server restarted successfully (PM2)
            set "START_METHOD=PM2"
        )
    ) else (
        echo [SUCCESS] API Server started successfully (PM2)
        set "START_METHOD=PM2"
    )
)

echo.
echo [INFO] Waiting for API server to initialize...
timeout /t 3 /nobreak >nul

echo [INFO] Testing API server...
curl -s http://localhost:3003/health >nul 2>&1
if errorlevel 1 (
    echo [WARNING] API server may still be starting or not responding...
    echo [INFO] Retrying health check...
    timeout /t 2 /nobreak >nul
    curl -s http://localhost:3003/health >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] API server is NOT responding on port 3003
        echo [HINT] Ensure port is open and not blocked by firewall
        echo [HINT] Check logs in the API server window
        echo [HINT] If using PM2, try: pm2 logs soc-chat-api
    ) else (
        echo [SUCCESS] API server is responding!
    )
) else (
    echo [SUCCESS] API server is responding!
)

echo.
echo [INFO] API Server is running on: http://localhost:3003
echo [INFO] Start method: %START_METHOD%
echo [INFO] Press any key to close this window...
pause >nul


