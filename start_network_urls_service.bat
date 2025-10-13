@echo off
title SOC Chat App - Network URLs Service
echo =============================================================================
echo SOC Chat App - Network URLs Service
echo =============================================================================
echo.

echo [INFO] Detecting IPv4 addresses on all network cards...
set "primary_ip="
set "secondary_ip="
set "ip_list="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    rem Trim leading spaces from the value after ':'
    for /f "tokens=* delims= " %%b in ("%%a") do (
        if not "%%b"=="" if not "%%b"=="127.0.0.1" (
            if not defined primary_ip (
                set "primary_ip=%%b"
            ) else if not defined secondary_ip (
                set "secondary_ip=%%b"
            )
            if not defined ip_list (
                set "ip_list=%%b"
            ) else (
                set "ip_list=!ip_list!, %%b"
            )
        )
    )
)

REM Determine custom port (default 3004). Pass as arg1 if desired.
set "CUSTOM_PORT=%~1"
if "%CUSTOM_PORT%"=="" set "CUSTOM_PORT=3004"

echo.
echo =============================================================================
echo YOUR LOCAL NETWORK URL LINKS
echo =============================================================================
echo.
if defined primary_ip echo   - Primary: http://%primary_ip%:%CUSTOM_PORT%
if defined secondary_ip echo   - Secondary: http://%secondary_ip%:%CUSTOM_PORT%
echo   - Local: http://localhost:%CUSTOM_PORT%
echo.
echo [SERVICES]
if defined primary_ip (
    echo   - API Server:       http://localhost:3003   ^| http://%primary_ip%:3003
    echo   - Local Net Server: http://localhost:3004   ^| http://%primary_ip%:3004
    echo   - Web App:          http://localhost:8082   ^| http://%primary_ip%:8082
) else (
    echo   - API Server:       http://localhost:3003
    echo   - Local Net Server: http://localhost:3004
    echo   - Web App:          http://localhost:8082
)
echo.
echo [Permanent Remote URL]
echo   - ngrok Reserved Domain: https://soc-chat-app.ngrok-free.app
echo.
echo [INFO] All addresses above use the same MongoDB database.
echo [INFO] Share the Primary/Secondary URLs with other PCs on the LAN.
echo.
if not defined primary_ip (
    echo [WARNING] No IPv4 detected via parser. Showing helper output...
    call show_network_ips_simple.bat
    echo.
)

REM Optional: pass arg2=start to launch all services in separate windows
if /I "%~2"=="start" (
    echo [INFO] Starting all services in background windows...
    start "Start All Services" cmd /c "start_all_services.bat"
)

echo.
if /I "%NO_PAUSE%"=="1" (
    echo [INFO] Done. (no pause)
) else (
    echo [INFO] Press any key to close this window...
    pause >nul
)
exit /b 0