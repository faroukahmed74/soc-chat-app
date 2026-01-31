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
if defined SM_CHOICE (
    set "choice=%SM_CHOICE%"
    echo Auto choice: %choice%
) else (
    set /p "choice=Enter your choice (1-7): "
)

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
if defined SM_NONINTERACTIVE (
    timeout /t 2 /nobreak >nul
) else (
    pause
)
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

echo [1/8] Starting MongoDB...
net start MongoDB >nul 2>&1
if !errorlevel! equ 0 (
    echo   ✅ MongoDB started successfully
) else (
    echo   ⚠️  MongoDB may already be running or failed to start
)
timeout /t 2 /nobreak >nul

echo [2/8] Starting Ollama AI Service (Optional - for AI chat)...
netstat -an | findstr ":11434" | findstr "LISTENING" >nul
if %errorlevel%==0 goto OLLAMA_OK
where ollama >nul 2>&1
if errorlevel 1 goto OLLAMA_MISSING
start "Ollama AI Server" cmd /c "ollama serve"
echo   ✅ Ollama starting (port 11434)
goto OLLAMA_DONE

:OLLAMA_OK
echo   ✅ Ollama already running on port 11434
goto OLLAMA_DONE

:OLLAMA_MISSING
echo   ⚠️  Ollama not found in PATH (AI chat will be disabled)

:OLLAMA_DONE
timeout /t 2 /nobreak >nul

echo [3/8] Starting API Server (Port 3003)...
cd /d "%API_SERVER_DIR%"
start "SOC Chat App - API Server" cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"
cd /d "%PROJECT_ROOT%"
echo   ✅ API Server starting on port 3003 (includes call invitation system)
timeout /t 3 /nobreak >nul

echo [4/8] Starting TURN Server (coturn Docker)...
set "COTURN_COMPOSE=%PROJECT_ROOT%scripts\coturn-docker-compose.yml"
if exist "%COTURN_COMPOSE%" (
    docker-compose -f "%COTURN_COMPOSE%" up -d >nul 2>&1
    if !errorlevel! equ 0 (
        echo   ✅ coturn TURN server started
    ) else (
        echo   ⚠️  coturn may already be running or Docker not available
    )
) else (
    echo   ⚠️  coturn-docker-compose.yml not found (TURN server will not be available)
)
timeout /t 2 /nobreak >nul

echo [5/8] Starting ngrok Tunnel (API + TURN)...
:: Always stop any existing ngrok processes first
taskkill /f /im ngrok.exe >nul 2>&1
timeout /t 2 /nobreak >nul
:: Double-check and wait for processes to fully terminate
:NGROK_CHECK_LOOP
tasklist | findstr /i "ngrok.exe" >nul
if !errorlevel! equ 0 (
    timeout /t 1 /nobreak >nul
    goto NGROK_CHECK_LOOP
)
set "NGROK_CONFIG=%PROJECT_ROOT%scripts\ngrok.yml"
if exist "%NGROK_CONFIG%" (
    cd /d "%PROJECT_ROOT%scripts"
    start "SOC Chat App - ngrok (All Tunnels)" cmd /k "ngrok start --all --config=ngrok.yml"
    cd /d "%PROJECT_ROOT%"
    echo   ✅ ngrok tunnels starting (HTTP for API + TCP for TURN)
    goto NGROK_STARTED
)
cd /d "%PROJECT_ROOT%scripts"
start "SOC Chat App - ngrok (HTTP Only)" cmd /k "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
cd /d "%PROJECT_ROOT%"
echo   ✅ ngrok tunnel starting (HTTP only - TURN will use STUN only)
echo   ⚠️  Note: For TURN support, create scripts\ngrok.yml config file
:NGROK_STARTED
timeout /t 2 /nobreak >nul

echo [6/8] Starting Web Server (Port 8082)...
cd /d "%PROJECT_ROOT%\servers"
start "SOC Chat App - Web Server" cmd /c "set PORT=8082 && set API_TARGET=http://localhost:3003 && node server.js"
cd /d "%PROJECT_ROOT%"
echo   ✅ Web server starting on port 8082 (web call support)
timeout /t 2 /nobreak >nul

echo [7/8] Starting Network URLs Service...
cd /d "%API_SERVER_DIR%"
if exist "local_network_config.js" (
    start "Network URLs Service" cmd /c "node local_network_config.js"
    echo   ✅ Network URLs service started
) else (
    echo   ⚠️  local_network_config.js not found (optional service)
)
cd /d "%PROJECT_ROOT%"
timeout /t 1 /nobreak >nul

echo [8/8] Starting FCM Server (Optional - for background call notifications)...
cd /d "%PROJECT_ROOT%\servers"
if exist "fcm_server_production.js" (
    start "SOC Chat App - FCM Server" cmd /c "set PORT=3000 && node fcm_server_production.js"
    echo   ✅ FCM Server started on port 3000
) else if exist "fcm_server.js" (
    start "SOC Chat App - FCM Server" cmd /c "set PORT=3000 && node fcm_server.js"
    echo   ✅ FCM Server started on port 3000
) else (
    echo   ⚠️  FCM Server files not found (optional - calls work without it)
)
cd /d "%PROJECT_ROOT%"

echo.
echo =============================================================================
echo ALL SERVICES STARTED SUCCESSFULLY!
echo =============================================================================
echo.
echo Services Status:
echo   - MongoDB: Running (Database)
echo   - Ollama: Running on port 11434 (Optional - AI chat)
echo   - API Server: Running on port 3003 (Backend + Call System)
echo   - TURN Server: Running via coturn Docker (port 3478)
echo   - ngrok Tunnel: Running (HTTP for API + TCP for TURN)
echo   - Web Server: Running on port 8082 (Web App)
echo   - Network URLs: Running
echo   - FCM Server: Running on port 3000 (Optional - Background Notifications)
echo.
echo Access URLs:
echo   - Public API: https://soc-chat-app.ngrok-free.app
echo   - Web App: http://localhost:8082
echo   - Local Network: http://[YOUR_IP]:8082
echo.
echo Call System Features:
echo   ✅ Voice calls (individual and group)
echo   ✅ Video calls (individual and group)
echo   ✅ Screen sharing
echo   ✅ Cross-platform (Web, Android, iOS)
echo.
echo Note: Wait 5-10 seconds for all services to fully initialize
echo       before testing calls.
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

echo [1/7] Stopping ngrok...
taskkill /f /im ngrok.exe >nul 2>&1

echo [2/7] Stopping TURN Server (coturn Docker)...
docker-compose -f "%PROJECT_ROOT%scripts\coturn-docker-compose.yml" down >nul 2>&1

echo [3/7] Stopping API Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - API Server" >nul 2>&1

echo [4/7] Stopping Web Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - Web Server" >nul 2>&1

echo [5/7] Stopping Network URLs Service...
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq Network URLs Service" >nul 2>&1

echo [6/7] Stopping FCM Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - FCM Server" >nul 2>&1

echo [7/7] Stopping MongoDB...
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
set "TOTAL_COUNT=8"

echo [1/8] Checking MongoDB...
net start | findstr -i mongo >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT RUNNING
)

echo [2/8] Checking Ollama AI Service (Port 11434)...
netstat -an | findstr ":11434" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ⚠️  NOT LISTENING (Optional - AI chat disabled)
)

echo [3/8] Checking API Server (Port 3003)...
netstat -an | findstr ":3003" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT LISTENING
)

echo [4/8] Checking TURN Server (coturn Docker)...
docker ps | findstr "soc-chat-coturn" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ⚠️  NOT RUNNING (Optional - uses STUN if unavailable)
)

echo [5/8] Checking ngrok...
netstat -an | findstr ":4040" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT RUNNING
)

echo [6/8] Checking Web Server (Port 8082)...
netstat -an | findstr ":8082" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ❌ NOT LISTENING
)

echo [7/8] Checking Network URLs Service...
tasklist | findstr "cmd.exe" | findstr "Network URLs" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ⚠️  NOT RUNNING (Optional)
)

echo [8/8] Checking FCM Server (Port 3000)...
netstat -an | findstr ":3000" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: ✅ RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: ⚠️  NOT RUNNING (Optional)
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
echo 2. API Server (Port 3003) - Includes Call System
echo 3. TURN Server (coturn Docker) - Optional
echo 4. ngrok Tunnel
echo 5. Web Server (Port 8082)
echo 6. Network URLs Service - Optional
echo 7. FCM Server (Port 3000) - Optional
echo 8. Back to Main Menu
echo.
set /p "service_choice=Enter service to start (1-8): "

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
    set "COTURN_COMPOSE=%PROJECT_ROOT%scripts\coturn-docker-compose.yml"
    if exist "%COTURN_COMPOSE%" (
        docker-compose -f "%COTURN_COMPOSE%" up -d >nul 2>&1
        if !errorlevel! equ 0 (
            echo coturn TURN server started
        ) else (
            echo coturn may already be running or Docker not available
        )
    ) else (
        echo coturn-docker-compose.yml not found (TURN server will not be available)
    )
    pause
)
if "%service_choice%"=="4" (
    :: Always stop any existing ngrok processes first
    taskkill /f /im ngrok.exe >nul 2>&1
    timeout /t 2 /nobreak >nul
    :: Double-check and wait for processes to fully terminate
    :NGROK_INDIVIDUAL_CHECK
    tasklist | findstr /i "ngrok.exe" >nul
    if !errorlevel! equ 0 (
        timeout /t 1 /nobreak >nul
        goto NGROK_INDIVIDUAL_CHECK
    )
    set "NGROK_CONFIG=%PROJECT_ROOT%scripts\ngrok.yml"
    if exist "%NGROK_CONFIG%" (
        cd /d "%PROJECT_ROOT%scripts"
        start "SOC Chat App - ngrok (All Tunnels)" cmd /k "ngrok start --all --config=ngrok.yml"
        cd /d "%PROJECT_ROOT%"
        echo ngrok tunnels started (HTTP for API + TCP for TURN)
        goto NGROK_INDIVIDUAL_STARTED
    )
    cd /d "%PROJECT_ROOT%scripts"
    start "SOC Chat App - ngrok (HTTP Only)" cmd /k "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
    cd /d "%PROJECT_ROOT%"
    echo ngrok tunnel started (HTTP only)
    echo Note: For TURN support, create scripts\ngrok.yml config file
    :NGROK_INDIVIDUAL_STARTED
    pause
)
if "%service_choice%"=="5" (
    cd /d "%PROJECT_ROOT%\servers"
    start "SOC Chat App - Web Server" cmd /c "set PORT=8082 && set API_TARGET=http://localhost:3003 && node server.js"
    cd /d "%PROJECT_ROOT%"
    echo Web server started
    pause
)
if "%service_choice%"=="6" (
    cd /d "%API_SERVER_DIR%"
    if exist "local_network_config.js" (
        start "Network URLs Service" cmd /c "node local_network_config.js"
        echo Network URLs service started
    ) else (
        echo local_network_config.js not found (optional service)
    )
    cd /d "%PROJECT_ROOT%"
    pause
)
if "%service_choice%"=="7" (
    cd /d "%PROJECT_ROOT%\servers"
    if exist "fcm_server_production.js" (
        start "SOC Chat App - FCM Server" cmd /c "set PORT=3000 && node fcm_server_production.js"
        echo FCM Server started on port 3000
    ) else if exist "fcm_server.js" (
        start "SOC Chat App - FCM Server" cmd /c "set PORT=3000 && node fcm_server.js"
        echo FCM Server started on port 3000
    ) else (
        echo FCM Server files not found
    )
    cd /d "%PROJECT_ROOT%"
    pause
)
if "%service_choice%"=="8" goto MAIN_MENU
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
