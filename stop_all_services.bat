@echo off
title SOC Chat App - Stopping All Services
echo =============================================================================
echo SOC Chat App - Stopping All Services
echo =============================================================================
echo.

echo [1/5] Stopping ngrok...
taskkill /f /im ngrok.exe >nul 2>&1
if errorlevel 1 (
    echo [INFO] ngrok was not running
) else (
    echo [SUCCESS] ngrok stopped
)

echo [2/5] Stopping API Server...
pm2 stop soc-chat-api >nul 2>&1
if errorlevel 1 (
    echo [INFO] API Server was not running
) else (
    echo [SUCCESS] API Server stopped
)

echo [3/5] Stopping Local Network Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - Local Network Server*" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Local Network Server was not running
) else (
    echo [SUCCESS] Local Network Server stopped
)

echo [4/5] Stopping Local Web Server...
taskkill /f /im python.exe /fi "WINDOWTITLE eq SOC Chat App - Web Server*" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Local Web Server was not running
) else (
    echo [SUCCESS] Local Web Server stopped
)

echo [5/5] Stopping MongoDB...
net stop MongoDB >nul 2>&1
if errorlevel 1 (
    echo [INFO] MongoDB service was not running or cannot be stopped
) else (
    echo [SUCCESS] MongoDB stopped
)

echo.
echo =============================================================================
echo ALL SERVICES STOPPED!
echo =============================================================================
echo.
echo To start all services: start_all_services.bat
echo.
pause