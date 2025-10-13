@echo off
title SOC Chat App - ngrok Service (Permanent URL)
echo =============================================================================
echo SOC Chat App - Starting ngrok Service
echo =============================================================================
echo.

echo [INFO] Using PERMANENT RESERVED DOMAIN: soc-chat-app.ngrok-free.app
echo [INFO] This URL will NEVER change!
echo.

echo [INFO] Stopping any existing ngrok processes...
taskkill /f /im ngrok.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [INFO] Checking if API on port 3003 is listening...
netstat -an | findstr ":3003" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Port 3003 not listening yet.
    echo [HINT] Start API first: start_api_server.bat
    echo [INFO] Proceeding anyway; ngrok may fail to connect until API is ready
)

echo [INFO] Starting ngrok with reserved domain...
ngrok http 3003 --domain=soc-chat-app.ngrok-free.app

echo.
echo [INFO] ngrok is running with permanent URL!
echo [INFO] Press any key to close this window...
pause >nul


