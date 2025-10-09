@echo off
title SOC Chat App - Network IP Addresses
echo =============================================================================
echo SOC Chat App - Network IP Addresses
echo =============================================================================
echo.

echo [INFO] Getting IPv4 addresses for all network cards...
echo.

REM Get all IPv4 addresses
set "ip_count=0"
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    set /a ip_count+=1
    echo    Network Card !ip_count!: !ip!
    endlocal
)

echo.
echo =============================================================================
echo NETWORK ACCESS INFORMATION
echo =============================================================================
echo.

REM Get the primary IP for web access
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "primary_ip=%%a"
    setlocal enabledelayedexpansion
    set "primary_ip=!primary_ip: =!"
    echo [PRIMARY ACCESS]:
    echo   - Local Network Server: http://!primary_ip!:3004
    echo   - Main API Server: http://!primary_ip!:3003
    echo   - Web App: http://!primary_ip!:8082
    echo.
    echo [INFO] Use these URLs to access from other PCs on the network
    echo [INFO] All servers use the SAME MongoDB database
    echo.
    endlocal
    goto :found_primary
)

:found_primary

echo [INSTRUCTIONS]:
echo   1. Start local network server: start_local_network_server.bat
echo   2. Share the IP address with other PCs
echo   3. They can access the app at: http://[IP]:3004
echo   4. All data is shared - same database, same users
echo.
pause


