@echo off
title SOC Chat App - Starting All Services
echo =============================================================================
echo SOC Chat App - Starting All Services
echo =============================================================================
echo.

echo [INFO] Opening individual service windows...
echo [INFO] Each service will run in its own window for better visibility
echo.

echo [1/5] Starting MongoDB Service...
start "MongoDB Service" start_mongodb.bat

echo [2/5] Starting API Server Service...
start "API Server Service" start_api_server.bat

echo [3/5] Starting ngrok Service...
start "ngrok Service" start_ngrok.bat

echo [4/5] Starting Local Network Server...
start "Local Network Server" start_local_network_server.bat

echo [5/5] Starting Local Web Server...
start "Local Web Server" start_web_server_optimized.bat

echo.
echo =============================================================================
echo ALL SERVICES STARTED!
echo =============================================================================
echo.
echo Services Status:
echo   - MongoDB: Starting in separate window
echo   - API Server: Starting in separate window  
echo   - ngrok Tunnel: Starting in separate window
echo   - Local Network Server: Starting in separate window
echo   - Local Web Server: Starting in separate window
echo.
echo Your PERMANENT URL: https://soc-chat-app.ngrok-free.app
echo This URL will NEVER change!
echo.
echo Local Network Access:
echo   - Check IPs: show_network_ips_simple.bat
echo   - API Server: http://[YOUR_IP]:3004 (same database, same users)
echo   - Web App: http://[YOUR_IP]:8082 (Flutter web interface)
echo   - Local network only, no internet required
echo.
echo To stop all services: stop_all_services.bat
echo To restart all services: restart_all_services.bat
echo.
echo [INFO] Each service is running in its own window
echo [INFO] You can monitor each service individually
echo.
pause