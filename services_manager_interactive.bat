@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: SOC Chat App - Interactive Services Manager
:: =============================================================================

title SOC Chat App - Services Manager
cd /d "%~dp0"

:: Configuration
set "PROJECT_ROOT=%~dp0"
set "API_SERVER_DIR=%PROJECT_ROOT%servers\local_api_server"
set "WEB_BUILD_DIR=%PROJECT_ROOT%build\web"

:: Main menu loop
:MAIN_MENU
cls
echo =============================================================================
echo SOC Chat App - Services Manager
echo =============================================================================
echo.
echo 1. Start All Services
echo 2. Stop All Services  
echo 3. Restart All Services
echo 4. Check Services Status
echo 5. Start Individual Service
echo 6. Build and Deploy
echo 7. Clean Up and Exit
echo.
set /p "choice=Enter your choice (1-7): "

if "%choice%"=="1" goto START_ALL
if "%choice%"=="2" goto STOP_ALL
if "%choice%"=="3" goto RESTART_ALL
if "%choice%"=="4" goto CHECK_STATUS
if "%choice%"=="5" goto START_INDIVIDUAL
if "%choice%"=="6" goto BUILD_DEPLOY
if "%choice%"=="7" goto CLEANUP_EXIT

echo.
echo Invalid choice! Please enter a number between 1-7.
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: START ALL SERVICES
:: =============================================================================
:START_ALL
cls
echo =============================================================================
echo Starting All Services...
echo =============================================================================
echo.

echo [1/5] Starting MongoDB...
net start MongoDB >nul 2>&1
if !errorlevel! equ 0 (
    echo   ✅ MongoDB started successfully
) else (
    echo   ❌ MongoDB failed to start
)

echo [2/5] Starting API Server (Port 3003)...
cd /d "%API_SERVER_DIR%"
start "SOC Chat App - API Server" cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"
cd /d "%PROJECT_ROOT%"
echo   ✅ API Server started on port 3003

echo [3/5] Starting ngrok Tunnel...
start "SOC Chat App - ngrok Tunnel" cmd /c "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
echo   ✅ ngrok tunnel started

echo [4/5] Starting Web Server (Port 8082)...
cd /d "%WEB_BUILD_DIR%"
start "SOC Chat App - Web Server" cmd /c "python -m http.server 8082"
cd /d "%PROJECT_ROOT%"
echo   ✅ Web server started on port 8082

echo [5/5] Starting Network URLs Service...
start "Network URLs Service" cmd /c "node local_network_config.js"
echo   ✅ Network URLs service started

echo.
echo =============================================================================
echo ALL SERVICES STARTED SUCCESSFULLY!
echo =============================================================================
echo.
echo Services Status:
echo   - MongoDB: Running
echo   - API Server: Running on port 3003
echo   - ngrok Tunnel: Running
echo   - Web Server: Running on port 8082
echo   - Network URLs: Running
echo.
echo Access URLs:
echo   - Public API: https://soc-chat-app.ngrok-free.app
echo   - Web App: http://localhost:8082
echo   - Local Network: http://[YOUR_IP]:8082
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: STOP ALL SERVICES
:: =============================================================================
:STOP_ALL
cls
echo =============================================================================
echo Stopping All Services...
echo =============================================================================
echo.

echo [1/5] Stopping ngrok...
taskkill /f /im ngrok.exe >nul 2>&1

echo [2/5] Stopping API Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - API Server" >nul 2>&1

echo [3/5] Stopping Web Server...
taskkill /f /im python.exe /fi "WINDOWTITLE eq SOC Chat App - Web Server" >nul 2>&1

echo [4/5] Stopping Network URLs Service...
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq Network URLs Service" >nul 2>&1

echo [5/5] Stopping MongoDB...
net stop MongoDB >nul 2>&1

echo.
echo All services stopped successfully!
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: RESTART ALL SERVICES
:: =============================================================================
:RESTART_ALL
cls
echo =============================================================================
echo Restarting All Services...
echo =============================================================================
echo.
call :STOP_ALL
timeout /t 2 /nobreak >nul
call :START_ALL
goto MAIN_MENU

:: =============================================================================
:: CHECK SERVICES STATUS
:: =============================================================================
:CHECK_STATUS
cls
echo =============================================================================
echo Checking Services Status...
echo =============================================================================
echo.

set "RUNNING_COUNT=0"
set "TOTAL_COUNT=5"

echo [1/5] Checking MongoDB...
net start | findstr -i mongo >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT RUNNING
)

echo [2/5] Checking API Server (Port 3003)...
netstat -an | findstr ":3003" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT LISTENING
)

echo [3/5] Checking ngrok...
netstat -an | findstr ":4040" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT RUNNING
)

echo [4/5] Checking Web Server (Port 8082)...
netstat -an | findstr ":8082" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT LISTENING
)

echo [5/5] Checking Network URLs Service...
tasklist | findstr "cmd.exe" | findstr "Network URLs" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT RUNNING
)

echo.
echo =============================================================================
echo SERVICES STATUS SUMMARY
echo =============================================================================
echo [SUMMARY] %RUNNING_COUNT%/%TOTAL_COUNT% services are running
if %RUNNING_COUNT% equ %TOTAL_COUNT% (
    echo [STATUS] All services are running perfectly!
) else (
    echo [WARNING] Some services are not running
)
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: START INDIVIDUAL SERVICE
:: =============================================================================
:START_INDIVIDUAL
cls
echo =============================================================================
echo Start Individual Service
echo =============================================================================
echo.
echo 1. MongoDB
echo 2. API Server (Port 3003)
echo 3. ngrok Tunnel
echo 4. Web Server (Port 8082)
echo 5. Network URLs Service
echo 6. Back to Main Menu
echo.
set /p "service_choice=Enter service to start (1-6): "

if "%service_choice%"=="1" (
    net start MongoDB >nul 2>&1
    echo MongoDB started
    pause
)
if "%service_choice%"=="2" (
    cd /d "%API_SERVER_DIR%"
    start "SOC Chat App - API Server" cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"
    cd /d "%PROJECT_ROOT%"
    echo API Server started
    pause
)
if "%service_choice%"=="3" (
    start "SOC Chat App - ngrok Tunnel" cmd /c "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
    echo ngrok tunnel started
    pause
)
if "%service_choice%"=="4" (
    cd /d "%WEB_BUILD_DIR%"
    start "SOC Chat App - Web Server" cmd /c "python -m http.server 8082"
    cd /d "%PROJECT_ROOT%"
    echo Web server started
    pause
)
if "%service_choice%"=="5" (
    start "Network URLs Service" cmd /c "node local_network_config.js"
    echo Network URLs service started
    pause
)
if "%service_choice%"=="6" goto MAIN_MENU
goto START_INDIVIDUAL

:: =============================================================================
:: BUILD AND DEPLOY
:: =============================================================================
:BUILD_DEPLOY
cls
echo =============================================================================
echo Build and Deploy Options
echo =============================================================================
echo.
echo 1. Build Web App
echo 2. Build Android APK
echo 3. Build for SM-T585
echo 4. Build for DUB LX1
echo 5. Build iOS App
echo 6. Build iOS for Release
echo 7. Back to Main Menu
echo.
set /p "build_choice=Enter build option (1-7): "

if "%build_choice%"=="1" (
    echo Building web app...
    flutter build web --release
    echo Web app build completed
    pause
)
if "%build_choice%"=="2" (
    echo Building Android APK...
    flutter build apk --release
    echo Android APK build completed
    pause
)
if "%build_choice%"=="3" (
    echo Building for SM-T585...
    flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
    echo SM-T585 APK build completed
    pause
)
if "%build_choice%"=="4" (
    echo Building for DUB LX1...
    flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
    echo DUB LX1 APK build completed
    pause
)
if "%build_choice%"=="5" (
    echo Building iOS App (Debug)...
    echo Note: iOS builds require macOS and Xcode
    flutter build ios --debug --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
    echo iOS Debug build completed
    pause
)
if "%build_choice%"=="6" (
    echo Building iOS App (Release)...
    echo Note: Release builds require macOS, Xcode, and Apple Developer account
    flutter build ios --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
    echo iOS Release build completed
    pause
)
if "%build_choice%"=="7" goto MAIN_MENU
goto BUILD_DEPLOY

:: =============================================================================
:: CLEANUP AND EXIT
:: =============================================================================
:CLEANUP_EXIT
cls
echo =============================================================================
echo Cleanup and Exit
echo =============================================================================
echo.
echo Stopping all services before exit...
call :STOP_ALL
echo.
echo Cleanup completed. Goodbye!
timeout /t 2 /nobreak >nul
exit
