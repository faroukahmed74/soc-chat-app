@echo off
title SOC Chat App - API Server Service
echo =============================================================================
echo SOC Chat App - Starting API Server Service
echo =============================================================================
echo.

echo [INFO] Changing to API server directory...
cd servers\local_api_server

echo [INFO] Starting API Server with PM2...
pm2 start server.js --name "soc-chat-api" >nul 2>&1
if errorlevel 1 (
    echo [INFO] API Server already running, restarting...
    pm2 restart soc-chat-api >nul 2>&1
    echo [SUCCESS] API Server restarted successfully
) else (
    echo [SUCCESS] API Server started successfully
)

echo.
echo [INFO] Waiting for API server to initialize...
timeout /t 3 /nobreak >nul

echo [INFO] Testing API server...
curl -s http://localhost:3003/health >nul 2>&1
if errorlevel 1 (
    echo [WARNING] API server may still be starting...
) else (
    echo [SUCCESS] API server is responding!
)

echo.
echo [INFO] API Server is running on: http://localhost:3003
echo [INFO] Press any key to close this window...
pause >nul


