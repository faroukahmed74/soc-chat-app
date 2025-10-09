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

echo [INFO] Starting ngrok with reserved domain...
ngrok http 3003 --domain=soc-chat-app.ngrok-free.app

echo.
echo [INFO] ngrok is running with permanent URL!
echo [INFO] Press any key to close this window...
pause >nul


