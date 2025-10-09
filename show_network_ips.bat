@echo off
title SOC Chat App - Show Network IP Addresses
echo =============================================================================
echo SOC Chat App - Network IP Addresses
echo =============================================================================
echo.

echo [INFO] Getting all network adapter IP addresses...
echo.

REM Get detailed network adapter information
echo [1/3] Network Adapter Details:
echo =============================================================================
wmic path win32_networkadapter where "NetEnabled=true" get Name,NetConnectionID,AdapterTypeID /format:table
echo.

echo [2/3] IPv4 Addresses for Active Network Adapters:
echo =============================================================================

REM Get IPv4 addresses with adapter names
for /f "tokens=*" %%a in ('ipconfig /all ^| findstr /c:"Ethernet adapter" /c:"Wireless LAN adapter" /c:"IPv4 Address"') do (
    echo %%a
)

echo.
echo [3/3] Quick IP List:
echo =============================================================================

REM Get just the IP addresses
set "ip_count=0"
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    set /a ip_count+=1
    echo    IP Address !ip_count!: !ip!
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
    echo [PRIMARY ACCESS] Web App URL: http://!primary_ip!:8082
    echo [PRIMARY ACCESS] API Server URL: http://!primary_ip!:3003
    echo.
    echo [INFO] Use these URLs to access the app from other PCs on the network
    echo [INFO] Replace !primary_ip! with any of the IP addresses shown above
    echo.
    endlocal
    goto :found_primary
)

:found_primary

echo [NETWORK SETUP INSTRUCTIONS]:
echo   1. Make sure all PCs are on the same network (WiFi/LAN)
echo   2. Use the IP addresses shown above
echo   3. Access the web app at: http://[IP]:8082
echo   4. Access the API at: http://[IP]:3003
echo.
echo [TROUBLESHOOTING]:
echo   - If connection fails, check Windows Firewall settings
echo   - Ensure the web server is running (create_local_network.bat)
echo   - Verify all PCs are on the same network
echo.
pause


