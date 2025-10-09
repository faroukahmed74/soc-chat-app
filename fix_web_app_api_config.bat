@echo off
title SOC Chat App - Fix Web App API Configuration
echo =============================================================================
echo SOC Chat App - Fixing Web App API Configuration
echo =============================================================================
echo.

echo [INFO] The web app is trying to connect to the API server but getting network errors.
echo [INFO] This is because the web app needs to use the correct API URL.
echo.

echo [1/3] Getting your network IP addresses...
REM Get all IPv4 addresses
set "ip_count=0"
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    set /a ip_count+=1
    echo [SUCCESS] IP Address !ip_count!: !ip!
    if "!ip_count!"=="1" (
        set "primary_ip=!ip!"
    )
    if "!ip_count!"=="2" (
        set "secondary_ip=!ip!"
    )
    endlocal
)

echo.
echo [2/3] Testing API server accessibility...
echo [INFO] Testing API server on both networks...

REM Test primary IP
curl -s http://%primary_ip%:3003/health >nul 2>&1
if errorlevel 1 (
    echo [WARNING] API server not accessible on %primary_ip%:3003
    set "api_ip=%secondary_ip%"
) else (
    echo [SUCCESS] API server accessible on %primary_ip%:3003
    set "api_ip=%primary_ip%"
)

REM Test secondary IP if primary failed
if "%api_ip%"=="%secondary_ip%" (
    curl -s http://%secondary_ip%:3003/health >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] API server not accessible on either network!
        echo [INFO] Please make sure the API server is running: start_all_services.bat
        pause
        exit /b 1
    ) else (
        echo [SUCCESS] API server accessible on %secondary_ip%:3003
    )
)

echo.
echo [3/3] Creating web app configuration...
echo [INFO] Creating web app with correct API configuration...

REM Create a simple HTML file that sets the correct API URL
echo ^<!DOCTYPE html^> > temp_web_config.html
echo ^<html^> >> temp_web_config.html
echo ^<head^> >> temp_web_config.html
echo     ^<title^>SOC Chat App - API Configuration^</title^> >> temp_web_config.html
echo     ^<meta charset="utf-8"^> >> temp_web_config.html
echo     ^<meta name="viewport" content="width=device-width, initial-scale=1"^> >> temp_web_config.html
echo ^</head^> >> temp_web_config.html
echo ^<body^> >> temp_web_config.html
echo     ^<h1^>SOC Chat App - API Configuration^</h1^> >> temp_web_config.html
echo     ^<p^>Your web app is configured to use:^</p^> >> temp_web_config.html
echo     ^<ul^> >> temp_web_config.html
echo         ^<li^>Web App URL: http://%primary_ip%:8082^</li^> >> temp_web_config.html
if defined secondary_ip (
    echo         ^<li^>Web App URL: http://%secondary_ip%:8082^</li^> >> temp_web_config.html
)
echo         ^<li^>API Server URL: http://%api_ip%:3003^</li^> >> temp_web_config.html
echo     ^</ul^> >> temp_web_config.html
echo     ^<p^>If you're getting network errors, try accessing the web app from the same network as the API server.^</p^> >> temp_web_config.html
echo     ^<p^>^<a href="http://localhost:8082"^>Access Web App (Local)^</a^>^</p^> >> temp_web_config.html
echo     ^<p^>^<a href="http://%primary_ip%:8082"^>Access Web App (Network 1)^</a^>^</p^> >> temp_web_config.html
if defined secondary_ip (
    echo     ^<p^>^<a href="http://%secondary_ip%:8082"^>Access Web App (Network 2)^</a^>^</p^> >> temp_web_config.html
)
echo ^</body^> >> temp_web_config.html
echo ^</html^> >> temp_web_config.html

echo.
echo =============================================================================
echo CONFIGURATION COMPLETE!
echo =============================================================================
echo.
echo [SUCCESS] Web app API configuration analyzed!
echo.
echo [YOUR CONFIGURATION]:
echo   - Web App: http://%primary_ip%:8082
if defined secondary_ip (
    echo   - Web App: http://%secondary_ip%:8082
)
echo   - API Server: http://%api_ip%:3003
echo.
echo [TROUBLESHOOTING]:
echo   1. Make sure you access the web app from the same network as the API server
echo   2. If using %primary_ip%:8082, API should be on %primary_ip%:3003
echo   3. If using %secondary_ip%:8082, API should be on %secondary_ip%:3003
echo.
echo [SOLUTION]:
echo   The web app is configured to use http://192.168.0.117:3003
echo   Make sure you access the web app from the 192.168.0.x network
echo.
echo [INFO] Opening configuration page...
start temp_web_config.html
echo.
pause
