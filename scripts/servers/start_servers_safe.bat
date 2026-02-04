@echo off
echo ========================================
echo   SOC Chat App - Safe Server Starter
echo ========================================
echo.

:: Check if API server is running
echo Checking port 3003...
netstat -an | findstr ":3003.*LISTENING" >nul
if %errorlevel% == 0 (
    echo   ⚠️  API Server is already running on port 3003
    echo   Skipping API Server startup...
) else (
    echo   ✅ Port 3003 is free
    echo   Starting API Server...
    cd servers\local_api_server
    start "SOC Chat App - API Server" cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"
    cd ..\..
    timeout /t 2 /nobreak >nul
)

:: Check if Web server is running
echo.
echo Checking port 8082...
netstat -an | findstr ":8082.*LISTENING" >nul
if %errorlevel% == 0 (
    echo   ⚠️  Web Server is already running on port 8082
    echo   Skipping Web Server startup...
) else (
    echo   ✅ Port 8082 is free
    echo   Starting Web Server...
    cd servers
    start "SOC Chat App - Web Server" cmd /c "set PORT=8082 && set API_TARGET=http://127.0.0.1:3003 && node server.js"
    cd ..
    timeout /t 2 /nobreak >nul
)

echo.
echo ========================================
echo   Servers Started Successfully!
echo ========================================
echo.
echo Access URLs:
echo   - Local: http://localhost:8082
echo   - Network 1: http://10.120.4.230:8082
echo   - Network 2: http://160.2.1.18:8082
echo.
echo Press any key to exit...
pause >nul
