@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM SOC Chat App - Services Manager (CLI entrypoint)
REM =============================================================================
REM This file exists so other helpers can reliably call:
REM   - services_manager.bat start-all
REM   - services_manager.bat stop-all
REM   - services_manager.bat status
REM Or open the interactive menu:
REM   - services_manager.bat
REM =============================================================================

cd /d "%~dp0"
set "PROJECT_ROOT=%~dp0"
if defined SOC_CHAT_APP_ROOT set "PROJECT_ROOT=%SOC_CHAT_APP_ROOT%"
if not "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT%\"
if not exist "%PROJECT_ROOT%servers\local_api_server\server.js" set "PROJECT_ROOT=E:\GitHub\soc-chat-app\"
if not exist "%PROJECT_ROOT%servers\local_api_server\server.js" (
    echo ERROR: Project root not found. Run from SOC Chat App folder or set SOC_CHAT_APP_ROOT.
    exit /b 1
)
set "API_SERVER_DIR=%PROJECT_ROOT%servers\local_api_server"

set "CMD=%~1"
if "%CMD%"=="" goto MENU

if /I "%CMD%"=="menu" goto MENU
if /I "%CMD%"=="start-all" goto START_ALL
if /I "%CMD%"=="stop-all" goto STOP_ALL
if /I "%CMD%"=="restart-all" goto RESTART_ALL
if /I "%CMD%"=="status" goto STATUS

echo Unknown command: %CMD%
echo.
echo Usage:
echo   services_manager.bat               ^(interactive menu^)
echo   services_manager.bat menu
echo   services_manager.bat start-all
echo   services_manager.bat stop-all
echo   services_manager.bat restart-all
echo   services_manager.bat status
exit /b 2

:MENU
if exist "%PROJECT_ROOT%services_manager_interactive.bat" (
  call "%PROJECT_ROOT%services_manager_interactive.bat"
  exit /b %errorlevel%
)
echo ERROR: services_manager_interactive.bat not found in %PROJECT_ROOT%
exit /b 1

:START_ALL
echo =============================================================================
echo Starting ALL SOC Chat App services...
echo =============================================================================

REM Ensure ngrok and other tools in E:\Programs are on PATH
if exist "E:\Programs" set "PATH=E:\Programs;E:\Programs\ngrok;%PATH%"
if exist "E:\Programs\ngrok" set "PATH=E:\Programs\ngrok;%PATH%"

echo [1/8] Starting MongoDB...
net start MongoDB >nul 2>&1
if !errorlevel! equ 0 (echo   OK: MongoDB started) else (echo   WARN: MongoDB already running or failed)

echo [2/8] Starting API Server (Port 3003)...
cd /d "%API_SERVER_DIR%"
start "SOC Chat App - API Server" cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"
cd /d "%PROJECT_ROOT%"

echo [3/8] Starting TURN Server (coturn Docker) ^(optional^)...
set "COTURN_COMPOSE=%PROJECT_ROOT%scripts\coturn-docker-compose.yml"
if exist "%COTURN_COMPOSE%" (
  docker-compose -f "%COTURN_COMPOSE%" up -d >nul 2>&1
  if !errorlevel! equ 0 (echo   OK: coturn started) else (echo   WARN: coturn already running or Docker not available)
) else (
  echo   INFO: coturn-docker-compose.yml not found, skipping
)

echo [4/8] Starting ngrok (single instance - All Tunnels)...
taskkill /f /im ngrok.exe >nul 2>&1
timeout /t 3 /nobreak >nul
REM Wait for ngrok to fully terminate before starting (prevents duplicate instances)
set "NGROK_WAIT=0"
:NGROK_KILL_LOOP
tasklist | findstr /i "ngrok.exe" >nul
if !errorlevel! equ 0 (
  set /a NGROK_WAIT+=1
  if !NGROK_WAIT! geq 20 goto NGROK_KILL_DONE
  timeout /t 1 /nobreak >nul
  goto NGROK_KILL_LOOP
)
:NGROK_KILL_DONE
set "NGROK_CONFIG=%PROJECT_ROOT%scripts\ngrok.yml"
set "NGROK_SCRIPTS=%PROJECT_ROOT%scripts"
if not "%NGROK_SCRIPTS:~-1%"=="\" set "NGROK_SCRIPTS=%NGROK_SCRIPTS%\"
if exist "%NGROK_CONFIG%" (
  cd /d "%NGROK_SCRIPTS%"
  start "SOC Chat App - ngrok (All Tunnels)" cmd /k "ngrok start --all --config=ngrok.yml"
  cd /d "%PROJECT_ROOT%"
  echo   OK: ngrok started (all tunnels - API + TURN)
) else (
  cd /d "%NGROK_SCRIPTS%"
  start "SOC Chat App - ngrok (All Tunnels)" cmd /k "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
  cd /d "%PROJECT_ROOT%"
  echo   OK: ngrok started (API tunnel - create scripts\ngrok.yml for TURN)
)

echo [5/8] Starting Web Server (Port 8082)...
cd /d "%PROJECT_ROOT%servers"
start "SOC Chat App - Web Server" cmd /c "set PORT=8082 && set API_TARGET=http://localhost:3003 && node server.js"
cd /d "%PROJECT_ROOT%"

echo [6/8] Starting Network URLs Service ^(optional^)...
cd /d "%API_SERVER_DIR%"
if exist "local_network_config.js" (
  start "Network URLs Service" cmd /c "node local_network_config.js"
  echo   OK: Network URLs service started
) else (
  echo   INFO: local_network_config.js not found, skipping
)
cd /d "%PROJECT_ROOT%"

echo [7/8] Starting FCM Server ^(optional^)...
cd /d "%PROJECT_ROOT%servers"
if exist "fcm_server_production.js" (
  start "SOC Chat App - FCM Server" cmd /c "set PORT=3000 && node fcm_server_production.js"
  echo   OK: FCM Server started on port 3000
) else if exist "fcm_server.js" (
  start "SOC Chat App - FCM Server" cmd /c "set PORT=3000 && node fcm_server.js"
  echo   OK: FCM Server started on port 3000
) else (
  echo   INFO: FCM server not found, skipping
)
cd /d "%PROJECT_ROOT%"

echo [8/8] Starting AI Services ^(OpenAI + Ollama^)...
REM OpenAI: Uses OPENAI_API_KEY from .env - no process to start, API server uses it
findstr /C:"OPENAI_API_KEY=sk-" "%API_SERVER_DIR%\.env" >nul 2>&1
if !errorlevel! equ 0 (
  echo   OK: OpenAI ^(ChatGPT^) configured in .env - primary AI
) else (
  echo   INFO: OpenAI not configured - set OPENAI_API_KEY in .env for ChatGPT
)
REM Ollama: Local fallback when OpenAI unavailable
netstat -an | findstr ":11434" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
  echo   OK: Ollama already running on port 11434 ^(fallback AI^)
  goto OLLAMA_DONE
)
where ollama >nul 2>&1
if !errorlevel! neq 0 goto OLLAMA_NOT_FOUND
start /b "" ollama serve >nul 2>&1
echo   OK: Ollama starting (port 11434 - fallback AI)
goto OLLAMA_DONE
:OLLAMA_NOT_FOUND
echo   WARN: Ollama not found in PATH ^(fallback AI disabled^)
:OLLAMA_DONE

echo.
echo DONE. Web: http://localhost:8082   API: http://localhost:3003
exit /b 0

:STOP_ALL
echo =============================================================================
echo Stopping ALL SOC Chat App services...
echo =============================================================================

echo [1/8] Stopping ngrok...
taskkill /f /im ngrok.exe >nul 2>&1

echo [2/8] Stopping TURN Server (coturn Docker)...
set "COTURN_COMPOSE=%PROJECT_ROOT%scripts\coturn-docker-compose.yml"
if exist "%COTURN_COMPOSE%" (
  docker-compose -f "%COTURN_COMPOSE%" down >nul 2>&1
)

echo [3/8] Stopping API Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - API Server" >nul 2>&1

echo [4/8] Stopping Web Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - Web Server" >nul 2>&1

echo [5/8] Stopping Network URLs Service...
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq Network URLs Service" >nul 2>&1

echo [6/8] Stopping FCM Server...
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - FCM Server" >nul 2>&1

echo [7/8] Stopping Ollama AI Service...
taskkill /f /im ollama.exe >nul 2>&1

echo [8/8] Stopping MongoDB...
net stop MongoDB >nul 2>&1

echo DONE.
exit /b 0

:RESTART_ALL
call "%PROJECT_ROOT%services_manager.bat" stop-all
timeout /t 2 /nobreak >nul
call "%PROJECT_ROOT%services_manager.bat" start-all
exit /b %errorlevel%

:STATUS
echo =============================================================================
echo SOC Chat App - Services Status
echo =============================================================================
echo MongoDB (27017):
netstat -an | findstr ":27017" | findstr "LISTENING" >nul && (echo   LISTENING) || (echo   NOT LISTENING)
echo AI Services:
findstr /C:"OPENAI_API_KEY=sk-" "%API_SERVER_DIR%\.env" >nul 2>&1 && (echo   OpenAI: Configured in .env) || (echo   OpenAI: Not configured)
netstat -an | findstr ":11434" | findstr "LISTENING" >nul && (echo   Ollama: LISTENING) || (echo   Ollama: NOT LISTENING - fallback AI disabled)
echo API (3003):
netstat -an | findstr ":3003" | findstr "LISTENING" >nul && (echo   LISTENING) || (echo   NOT LISTENING)
echo Web (8082):
netstat -an | findstr ":8082" | findstr "LISTENING" >nul && (echo   LISTENING) || (echo   NOT LISTENING)
echo ngrok:
tasklist | findstr /i "ngrok" >nul && (echo   RUNNING) || (netstat -an | findstr ":4040" | findstr "LISTENING" >nul && (echo   RUNNING) || (echo   NOT RUNNING))
echo FCM (3000):
netstat -an | findstr ":3000" | findstr "LISTENING" >nul && (echo   LISTENING) || (echo   NOT LISTENING)
exit /b 0

