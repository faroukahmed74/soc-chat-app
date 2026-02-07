@echo off
:: Keep window open - re-launch in a persistent titled window
if "%~1"==":RUN:" goto :SKIP_LAUNCHER
start "SOC Chat App - Services Manager" cmd /k "cd /d %~dp0 && %~f0 :RUN:"
exit /b
:SKIP_LAUNCHER
shift

setlocal enabledelayedexpansion

:: =============================================================================
:: SOC Chat App - Interactive Services Manager
:: =============================================================================

title SOC Chat App - Services Manager
cd /d "%~dp0"

:: Configuration - PROJECT_ROOT must be the folder that contains "servers" and "build"
set "PROJECT_ROOT=%~dp0"
if defined SOC_CHAT_APP_ROOT set "PROJECT_ROOT=%SOC_CHAT_APP_ROOT%"
if not "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT%\"
if not exist "%PROJECT_ROOT%servers\local_api_server\server.js" set "PROJECT_ROOT=E:\GitHub\soc-chat-app\"
if not exist "%PROJECT_ROOT%servers\local_api_server\server.js" (
    echo ERROR: Project root not found. Run this script from the SOC Chat App folder.
    echo   Expected: E:\GitHub\soc-chat-app\services_manager_interactive.bat
    echo   Or set SOC_CHAT_APP_ROOT=E:\GitHub\soc-chat-app
    echo   Current dir: %~dp0
    pause
    exit /b 1
)
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
echo 7. Configure Firewall (allow IP:8082 from network)
echo 8. Clean Up and Exit
echo.
if defined SM_CHOICE (
    set "choice=%SM_CHOICE%"
    echo Auto choice: %choice%
) else (
    set /p "choice=Enter your choice (1-8): "
)

if "%choice%"=="1" goto RUN_START_ALL_BAT
if "%choice%"=="2" goto STOP_ALL
if "%choice%"=="3" goto RESTART_ALL
if "%choice%"=="4" goto CHECK_STATUS
if "%choice%"=="5" goto START_INDIVIDUAL
if "%choice%"=="6" goto BUILD_DEPLOY
if "%choice%"=="7" goto CONFIGURE_FIREWALL
if "%choice%"=="8" goto CLEANUP_EXIT

echo.
echo Invalid choice! Please enter a number between 1-8.
echo.
if defined SM_NONINTERACTIVE (
    ping 127.0.0.1 -n 1 -w 2000 >nul
) else (
    pause
)
goto MAIN_MENU

:: =============================================================================
:: OPTION 1: Run start_all_services.bat (opens in new window)
:: =============================================================================
:RUN_START_ALL_BAT
cls
echo =============================================================================
echo Starting All Services...
echo =============================================================================
echo.
echo Opening start_all_services.bat in a new window...
start "SOC Chat App - Start All Services" cmd /k "cd /d "%PROJECT_ROOT%" && start_all_services.bat"
echo.
echo start_all_services.bat has been launched. Check the new window for progress.
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: START ALL SERVICES (used by RESTART and internal calls)
:: =============================================================================
:START_ALL
cls
echo =============================================================================
echo Starting All Services...
echo =============================================================================
echo.

:: Ensure ngrok and other tools in E:\Programs are on PATH
if exist "E:\Programs" set "PATH=E:\Programs;E:\Programs\ngrok;%PATH%"
if exist "E:\Programs\ngrok" set "PATH=E:\Programs\ngrok;%PATH%"
cd /d "%PROJECT_ROOT%"

:: Initialize result flags
set "SVC1=FAIL"&set "SVC2=FAIL"&set "SVC3=FAIL"&set "SVC4=FAIL"
set "SVC5=FAIL"&set "SVC6=FAIL"&set "SVC7=FAIL"&set "SVC8=FAIL"

:: [1/8] MongoDB
echo [1/8] Starting MongoDB...
netstat -an | findstr ":27017" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   [OK] MongoDB already listening on port 27017
    set "SVC1=OK"
    goto SVC1_DONE
)
net start MongoDB >nul 2>&1
if !errorlevel! equ 0 (
    echo   [OK] MongoDB service started
    set "SVC1=OK"
    goto SVC1_DONE
)
echo   [WARN]  MongoDB service failed - trying manual start...
set "MONGO_BAT=%PROJECT_ROOT%scripts\run\start_mongodb.bat"
if not exist "!MONGO_BAT!" goto SVC1_FAIL
call "!MONGO_BAT!"
ping 127.0.0.1 -n 1 -w 3000 >nul
netstat -an | findstr ":27017" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   [OK] MongoDB started via scripts\run\start_mongodb.bat
    set "SVC1=OK"
    goto SVC1_DONE
)
:SVC1_FAIL
echo   [X] MongoDB not listening. Install MongoDB 6.0 or run: scripts\run\start_mongodb_docker.ps1
:SVC1_DONE
ping 127.0.0.1 -n 1 -w 2000 >nul

:: [2/8] AI Services (OpenAI + Ollama)
echo [2/8] Starting AI Services (OpenAI + Ollama)...
REM OpenAI: Uses OPENAI_API_KEY from .env - no process to start
findstr /C:"OPENAI_API_KEY=sk-" "%API_SERVER_DIR%\.env" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [OK] OpenAI ^(ChatGPT^) configured in .env - primary AI
) else (
    echo   [INFO] OpenAI not configured - set OPENAI_API_KEY in .env for ChatGPT
)
REM Ollama: Local fallback when OpenAI unavailable
netstat -an | findstr ":11434" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   [OK] Ollama already running on port 11434 ^(fallback AI^)
    set "SVC2=OK"
    goto SVC2_DONE
)
where ollama >nul 2>&1
if !errorlevel! neq 0 goto SVC2_FAIL
start /b "" ollama serve >nul 2>&1
echo   [OK] Ollama starting (port 11434 - fallback AI)
set "SVC2=OK"
goto SVC2_DONE
:SVC2_FAIL
echo   [WARN]  Ollama not found in PATH ^(fallback AI disabled^)
:SVC2_DONE
ping 127.0.0.1 -n 1 -w 2000 >nul

:: [3/8] API Server
echo [3/8] Starting API Server (Port 3003)...
if not exist "%API_SERVER_DIR%\server.js" goto SVC3_FAIL
if not exist "%API_SERVER_DIR%\node_modules" (
    echo   Installing API server dependencies (npm install)...
    cd /d "%API_SERVER_DIR%"
    call npm install
    cd /d "%PROJECT_ROOT%"
)
start /D "%API_SERVER_DIR%" "SOC Chat App - API Server" cmd /c "set PORT=3003 ^&^& set HOST=0.0.0.0 ^&^& node server.js"
echo   [OK] API Server starting on port 3003
set "SVC3=OK"
goto SVC3_DONE
:SVC3_FAIL
echo   [WARN]  API Server not found at %API_SERVER_DIR%
:SVC3_DONE
cd /d "%PROJECT_ROOT%"
ping 127.0.0.1 -n 1 -w 3000 >nul

:: [4/8] TURN Server (coturn)
echo [4/8] Starting TURN Server (coturn Docker)...
set "COTURN_COMPOSE=%PROJECT_ROOT%scripts\coturn-docker-compose.yml"
if not exist "%COTURN_COMPOSE%" goto SVC4_FAIL
docker-compose -f "%COTURN_COMPOSE%" up -d >nul 2>&1
if !errorlevel! equ 0 (
    echo   [OK] coturn TURN server started
    set "SVC4=OK"
) else (
    echo   [WARN]  coturn may already be running or Docker not available
)
goto SVC4_DONE
:SVC4_FAIL
echo   [WARN]  coturn-docker-compose.yml not found
:SVC4_DONE
ping 127.0.0.1 -n 1 -w 2000 >nul

:: [5/8] ngrok
echo [5/8] Starting ngrok Tunnel (API + TURN)...
taskkill /f /im ngrok.exe >nul 2>&1
ping 127.0.0.1 -n 1 -w 2000 >nul
set "NGROK_WAIT=0"
:NGROK_CHECK_LOOP
tasklist | findstr /i "ngrok.exe" >nul
if !errorlevel! equ 0 (
    set /a NGROK_WAIT+=1
    if !NGROK_WAIT! geq 15 goto NGROK_LOOP_DONE
    ping 127.0.0.1 -n 1 -w 1000 >nul
    goto NGROK_CHECK_LOOP
)
:NGROK_LOOP_DONE
set "NGROK_SCRIPTS=%PROJECT_ROOT%scripts"
set "NGROK_CONFIG=%NGROK_SCRIPTS%\ngrok.yml"
if exist "%NGROK_CONFIG%" (
    start /D "%NGROK_SCRIPTS%" "SOC Chat App - ngrok (All Tunnels)" cmd /k "ngrok start --all --config=ngrok.yml"
    echo   [OK] ngrok tunnels starting (HTTP for API + TCP for TURN)
    set "SVC5=OK"
) else (
    start /D "%NGROK_SCRIPTS%" "SOC Chat App - ngrok (HTTP Only)" cmd /k "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
    echo   [OK] ngrok tunnel starting (HTTP only)
    echo   [WARN]  Note: For TURN support, create scripts\ngrok.yml config file
    set "SVC5=OK"
)
ping 127.0.0.1 -n 1 -w 2000 >nul

:: [6/8] Web Server
echo [6/8] Starting Web Server (Port 8082)...
set "WEB_SERVER_DIR=%PROJECT_ROOT%servers"
if not exist "%WEB_SERVER_DIR%\server.js" goto SVC6_FAIL
if not exist "%WEB_SERVER_DIR%\node_modules" (
    echo   Installing web server dependencies (npm install)...
    cd /d "%WEB_SERVER_DIR%"
    call npm install
    cd /d "%PROJECT_ROOT%"
)
start /D "%WEB_SERVER_DIR%" "SOC Chat App - Web Server" cmd /c "set PORT=8082 ^&^& set API_TARGET=http://localhost:3003 ^&^& node server.js"
echo   [OK] Web server starting on port 8082
set "SVC6=OK"
goto SVC6_DONE
:SVC6_FAIL
echo   [WARN]  Web Server not found at %WEB_SERVER_DIR%
:SVC6_DONE
cd /d "%PROJECT_ROOT%"
ping 127.0.0.1 -n 1 -w 2000 >nul

:: [7/8] Network URLs Service
echo [7/8] Starting Network URLs Service...
if not exist "%API_SERVER_DIR%\local_network_config.js" goto SVC7_FAIL
start /D "%API_SERVER_DIR%" "Network URLs Service" cmd /c "node local_network_config.js"
echo   [OK] Network URLs service started
set "SVC7=OK"
goto SVC7_DONE
:SVC7_FAIL
echo   [WARN]  local_network_config.js not found (optional service)
:SVC7_DONE
cd /d "%PROJECT_ROOT%"
ping 127.0.0.1 -n 1 -w 1000 >nul

:: [8/8] FCM Server
echo [8/8] Starting FCM Server (Optional - for background call notifications)...
set "FCM_DIR=%PROJECT_ROOT%servers"
if exist "%FCM_DIR%\fcm_server_production.js" (
    start /D "%FCM_DIR%" "SOC Chat App - FCM Server" cmd /c "set PORT=3000 ^&^& node fcm_server_production.js"
    echo   [OK] FCM Server started on port 3000
    set "SVC8=OK"
) else (
    if exist "%FCM_DIR%\fcm_server.js" (
        start /D "%FCM_DIR%" "SOC Chat App - FCM Server" cmd /c "set PORT=3000 ^&^& node fcm_server.js"
        echo   [OK] FCM Server started on port 3000
        set "SVC8=OK"
    ) else (
        echo   [WARN]  FCM Server files not found (optional - calls work without it)
    )
)
cd /d "%PROJECT_ROOT%"

:: Final summary
echo.
echo =============================================================================
echo START ALL SERVICES - SUMMARY
echo =============================================================================
echo.
echo SUCCEEDED:
if "!SVC1!"=="OK" echo   [OK] 1. MongoDB (port 27017)
if "!SVC2!"=="OK" echo   [OK] 2. Ollama (port 11434)
if "!SVC3!"=="OK" echo   [OK] 3. API Server (port 3003)
if "!SVC4!"=="OK" echo   [OK] 4. TURN Server (coturn Docker)
if "!SVC5!"=="OK" echo   [OK] 5. ngrok Tunnel
if "!SVC6!"=="OK" echo   [OK] 6. Web Server (port 8082)
if "!SVC7!"=="OK" echo   [OK] 7. Network URLs Service
if "!SVC8!"=="OK" echo   [OK] 8. FCM Server (port 3000)
echo.
echo FAILED or NOT STARTED:
if "!SVC1!"=="FAIL" echo   [X] 1. MongoDB
if "!SVC2!"=="FAIL" echo   [X] 2. Ollama
if "!SVC3!"=="FAIL" echo   [X] 3. API Server
if "!SVC4!"=="FAIL" echo   [X] 4. TURN Server (coturn)
if "!SVC5!"=="FAIL" echo   [X] 5. ngrok Tunnel
if "!SVC6!"=="FAIL" echo   [X] 6. Web Server
if "!SVC7!"=="FAIL" echo   [X] 7. Network URLs Service
if "!SVC8!"=="FAIL" echo   [X] 8. FCM Server
echo.
echo Access URLs:
echo   - Public API: https://soc-chat-app.ngrok-free.app
echo   - Web App: http://localhost:8082
echo   - Local Network: http://[YOUR_IP]:8082
echo.
echo If other PCs cannot access via IP:8082, run as Admin:
echo   scripts\run_configure_firewall_web.bat
echo.
echo Verifying key ports (27017, 3003, 8082)...
netstat -an | findstr ":27017" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (echo   MongoDB 27017: OK) else (echo   MongoDB 27017: NOT listening)
netstat -an | findstr ":3003" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (echo   API 3003: OK) else (echo   API 3003: NOT listening)
netstat -an | findstr ":8082" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (echo   Web 8082: OK) else (echo   Web 8082: NOT listening)
echo.
if defined SM_NONINTERACTIVE (
    ping 127.0.0.1 -n 1 -w 2000 >nul
    if defined SM_ONE_SHOT exit /b 0
) else (
    echo Press any key to return to menu...
    pause >nul
)
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

echo [1/8] Stopping ngrok...
taskkill /f /im ngrok.exe >nul 2>&1

echo [2/8] Stopping TURN Server (coturn Docker)...
docker-compose -f "%PROJECT_ROOT%scripts\coturn-docker-compose.yml" down >nul 2>&1

echo [3/8] Stopping API Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - API Server" >nul 2>&1

echo [4/8] Stopping Web Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - Web Server" >nul 2>&1

echo [5/8] Stopping Network URLs Service...
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq Network URLs Service" >nul 2>&1

echo [6/7] Stopping FCM Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - FCM Server" >nul 2>&1

echo [7/8] Stopping Ollama AI Service...
taskkill /f /im ollama.exe >nul 2>&1

echo [8/8] Stopping MongoDB...
net stop MongoDB >nul 2>&1

echo.
echo All services stopped successfully!
echo.
if defined STOP_ALL_AS_SUB (
    set "STOP_ALL_AS_SUB="
    exit /b 0
)
echo Press any key to return to menu...
pause >nul
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
echo Running stop-all then start-all (single ngrok instance)...
call "%PROJECT_ROOT%services_manager.bat" stop-all
ping 127.0.0.1 -n 1 -w 3000 >nul
call "%PROJECT_ROOT%services_manager.bat" start-all
echo.
echo Restart complete.
pause
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

echo [1/8] Checking MongoDB (Port 27017)...
netstat -an | findstr ":27017" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: [X] NOT LISTENING
)

echo [2/8] Checking AI Services (OpenAI + Ollama)...
findstr /C:"OPENAI_API_KEY=sk-" "%API_SERVER_DIR%\.env" >nul 2>&1
if !errorlevel! equ 0 (
    echo   OpenAI: [OK] Configured in .env ^(primary AI^)
) else (
    echo   OpenAI: [INFO] Not configured - set OPENAI_API_KEY in .env for ChatGPT
)
netstat -an | findstr ":11434" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Ollama: [OK] LISTENING on port 11434 ^(fallback AI^)
    set /a RUNNING_COUNT+=1
) else (
    echo   Ollama: [WARN]  NOT LISTENING ^(fallback AI disabled^)
)

echo [3/8] Checking API Server (Port 3003)...
netstat -an | findstr ":3003" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: [X] NOT LISTENING
)

echo [4/8] Checking TURN Server (coturn Docker)...
docker ps | findstr "soc-chat-coturn" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: [WARN]  NOT RUNNING (Optional - uses STUN if unavailable)
)

echo [5/8] Checking ngrok...
tasklist | findstr /i "ngrok" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] RUNNING
    set /a RUNNING_COUNT+=1
) else (
    netstat -an | findstr ":4040" | findstr "LISTENING" >nul
    if !errorlevel! equ 0 (
        echo   Status: [OK] RUNNING
        set /a RUNNING_COUNT+=1
    ) else (
        echo   Status: [X] NOT RUNNING
    )
)

echo [6/8] Checking Web Server (Port 8082)...
netstat -an | findstr ":8082" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] LISTENING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: [X] NOT LISTENING
)

echo [7/8] Checking Network URLs Service (Port 3004)...
netstat -an | findstr ":3004" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: [WARN]  NOT RUNNING (Optional - local network discovery)
)

echo [8/8] Checking FCM Server (Port 3000)...
netstat -an | findstr ":3000" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: [OK] RUNNING
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: [WARN]  NOT RUNNING (Optional)
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
echo 2. Ollama AI ^(fallback - port 11434^)
echo 3. API Server (Port 3003) - Includes Call System
echo 4. TURN Server (coturn Docker) - Optional
echo 5. ngrok Tunnel
echo 6. Web Server (Port 8082)
echo 7. Network URLs Service - Optional
echo 8. FCM Server (Port 3000) - Optional
echo 9. Back to Main Menu
echo.
echo Note: OpenAI ^(ChatGPT^) is configured via OPENAI_API_KEY in .env - no separate start.
echo.
set /p "service_choice=Enter service to start (1-9): "

if "%service_choice%"=="1" (
    netstat -an | findstr ":27017" | findstr "LISTENING" >nul
    if !errorlevel! equ 0 (echo MongoDB already listening on 27017) else (
        net start MongoDB >nul 2>&1
        if !errorlevel! neq 0 (
            if exist "%PROJECT_ROOT%scripts\run\start_mongodb.bat" (call "%PROJECT_ROOT%scripts\run\start_mongodb.bat") else (echo Run scripts\run\start_mongodb_docker.ps1 or install MongoDB 6.0)
        ) else (echo MongoDB service started)
    )
    pause
)
if "%service_choice%"=="2" (
    netstat -an | findstr ":11434" | findstr "LISTENING" >nul
    if !errorlevel! equ 0 (
        echo Ollama already running on port 11434
    ) else (
        where ollama >nul 2>&1
        if !errorlevel! equ 0 (
            start /b "" ollama serve >nul 2>&1
            echo Ollama AI started on port 11434 ^(fallback AI^)
        ) else (
            echo Ollama not found in PATH. Install from https://ollama.ai
        )
    )
    pause
)
if "%service_choice%"=="3" (
    start /D "%API_SERVER_DIR%" "SOC Chat App - API Server" cmd /c "set PORT=3003 ^&^& set HOST=0.0.0.0 ^&^& node server.js"
    echo API Server started
    pause
)
if "%service_choice%"=="4" (
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
if "%service_choice%"=="5" (
    :: Always stop any existing ngrok processes first
    taskkill /f /im ngrok.exe >nul 2>&1
    ping 127.0.0.1 -n 1 -w 2000 >nul
    :: Double-check and wait for processes to fully terminate (max 15 sec)
    set "NGROK_WAIT=0"
    :NGROK_INDIVIDUAL_CHECK
    tasklist | findstr /i "ngrok.exe" >nul
    if !errorlevel! equ 0 (
        set /a NGROK_WAIT+=1
        if !NGROK_WAIT! geq 15 goto NGROK_INDIVIDUAL_DONE
        ping 127.0.0.1 -n 1 -w 1000 >nul
        goto NGROK_INDIVIDUAL_CHECK
    )
    :NGROK_INDIVIDUAL_DONE
    set "NGROK_SCRIPTS=%PROJECT_ROOT%scripts"
    set "NGROK_CONFIG=%NGROK_SCRIPTS%\ngrok.yml"
    if exist "%NGROK_CONFIG%" (
        start /D "%NGROK_SCRIPTS%" "SOC Chat App - ngrok (All Tunnels)" cmd /k "ngrok start --all --config=ngrok.yml"
        echo ngrok tunnels started (HTTP for API + TCP for TURN)
        goto NGROK_INDIVIDUAL_STARTED
    )
    start /D "%NGROK_SCRIPTS%" "SOC Chat App - ngrok (HTTP Only)" cmd /k "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
    echo ngrok tunnel started (HTTP only)
    echo Note: For TURN support, create scripts\ngrok.yml config file
    :NGROK_INDIVIDUAL_STARTED
    pause
)
if "%service_choice%"=="6" (
    start /D "%PROJECT_ROOT%servers" "SOC Chat App - Web Server" cmd /c "set PORT=8082 ^&^& set API_TARGET=http://localhost:3003 ^&^& node server.js"
    echo Web server started
    pause
)
if "%service_choice%"=="7" (
    if exist "%API_SERVER_DIR%\local_network_config.js" (
        start /D "%API_SERVER_DIR%" "Network URLs Service" cmd /c "node local_network_config.js"
        echo Network URLs service started
    ) else (
        echo local_network_config.js not found (optional service)
    )
    pause
)
if "%service_choice%"=="8" (
    set "FCM_DIR=%PROJECT_ROOT%servers"
    if exist "%FCM_DIR%\fcm_server_production.js" (
        start /D "%FCM_DIR%" "SOC Chat App - FCM Server" cmd /c "set PORT=3000 ^&^& node fcm_server_production.js"
        echo FCM Server started on port 3000
    ) else if exist "%FCM_DIR%\fcm_server.js" (
        start /D "%FCM_DIR%" "SOC Chat App - FCM Server" cmd /c "set PORT=3000 ^&^& node fcm_server.js"
        echo FCM Server started on port 3000
    ) else (
        echo FCM Server files not found
    )
    pause
)
if "%service_choice%"=="9" goto MAIN_MENU
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
    if exist "%PROJECT_ROOT%scripts\run_build_web.ps1" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%scripts\run_build_web.ps1"
    ) else (
        flutter build web --release
    )
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
:: CONFIGURE FIREWALL (Option 7)
:: =============================================================================
:CONFIGURE_FIREWALL
cls
echo =============================================================================
echo Configure Firewall for Local Network Access
echo =============================================================================
echo.
echo This allows other PCs to access http://YOUR_IP:8082
echo Requires Administrator privileges.
echo.
call "%PROJECT_ROOT%scripts\run_configure_firewall_web.bat"
goto MAIN_MENU

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
set "STOP_ALL_AS_SUB=1"
call :STOP_ALL
set "STOP_ALL_AS_SUB="
echo.
echo Cleanup completed. Goodbye!
ping 127.0.0.1 -n 1 -w 2000 >nul
exit /b 0
