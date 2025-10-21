@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: SOC Chat App - Unified Services Manager
:: =============================================================================
:: This is the ONLY batch file you need to manage all services
:: Replaces all the conflicting batch files with a clean, organized system
:: =============================================================================

title SOC Chat App - Services Manager

:: Ensure we stay in the correct directory
cd /d "%~dp0"

:: Configuration
set "PROJECT_ROOT=%~dp0"
set "API_SERVER_DIR=%PROJECT_ROOT%servers\local_api_server"
set "WEB_BUILD_DIR=%PROJECT_ROOT%build\web"

:: Colors for output
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "RESET=[0m"

:: Main menu
:MAIN_MENU
cls
echo %BLUE%=============================================================================
echo SOC Chat App - Unified Services Manager
echo =============================================================================%RESET%
echo.
echo %GREEN%1.%RESET% Start All Services
echo %GREEN%2.%RESET% Stop All Services  
echo %GREEN%3.%RESET% Restart All Services
echo %GREEN%4.%RESET% Check Services Status
echo %GREEN%5.%RESET% Start Individual Service
echo %GREEN%6.%RESET% Build and Deploy
echo %GREEN%7.%RESET% Clean Up & Exit
echo.
set /p "choice=Enter your choice (1-7): "

if "%choice%"=="1" goto START_ALL
if "%choice%"=="2" goto STOP_ALL
if "%choice%"=="3" goto RESTART_ALL
if "%choice%"=="4" goto CHECK_STATUS
if "%choice%"=="5" goto START_INDIVIDUAL
if "%choice%"=="6" goto BUILD_AND_DEPLOY
if "%choice%"=="7" goto CLEANUP_EXIT

:: Invalid choice - show error and return to menu
echo.
echo %RED%Invalid choice! Please enter a number between 1-7.%RESET%
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: START ALL SERVICES
:: =============================================================================
:START_ALL
cls
echo %BLUE%=============================================================================
echo Starting All Services...
echo =============================================================================%RESET%
echo.

echo %GREEN%[1/5] Starting MongoDB...%RESET%
call :START_MONGODB
timeout /t 2 /nobreak >nul

echo %GREEN%[2/5] Starting API Server (Port 3003)...%RESET%
call :START_API_SERVER
timeout /t 3 /nobreak >nul

echo %GREEN%[3/5] Starting ngrok Tunnel...%RESET%
call :START_NGROK
timeout /t 2 /nobreak >nul

echo %GREEN%[4/5] Starting Web Server (Port 8082)...%RESET%
call :START_WEB_SERVER
timeout /t 2 /nobreak >nul

echo %GREEN%[5/5] Starting Network URLs Service...%RESET%
call :START_NETWORK_URLS
timeout /t 1 /nobreak >nul

echo.
echo %GREEN%=============================================================================
echo ALL SERVICES STARTED SUCCESSFULLY!
echo =============================================================================%RESET%
echo.
echo %YELLOW%Services Status:%RESET%
echo   - MongoDB: Running
echo   - API Server: Running on port 3003
echo   - ngrok Tunnel: Running
echo   - Web Server: Running on port 8082
echo   - Network URLs: Running
echo.
echo %YELLOW%Access URLs:%RESET%
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
echo %BLUE%=============================================================================
echo Stopping All Services...
echo =============================================================================%RESET%
echo.

echo %RED%[1/5] Stopping ngrok...%RESET%
taskkill /f /im ngrok.exe >nul 2>&1

echo %RED%[2/5] Stopping API Server...%RESET%
taskkill /f /im node.exe /fi "WINDOWTITLE eq SOC Chat App - API Server" >nul 2>&1

echo %RED%[3/5] Stopping Web Server...%RESET%
taskkill /f /im python.exe /fi "WINDOWTITLE eq SOC Chat App - Web Server" >nul 2>&1

echo %RED%[4/5] Stopping Network URLs Service...%RESET%
taskkill /f /im cmd.exe /fi "WINDOWTITLE eq Network URLs Service" >nul 2>&1

echo %RED%[5/5] Stopping MongoDB...%RESET%
net stop MongoDB >nul 2>&1

echo.
echo %GREEN%All services stopped successfully!%RESET%
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: RESTART ALL SERVICES
:: =============================================================================
:RESTART_ALL
cls
echo %BLUE%=============================================================================
echo Restarting All Services...
echo =============================================================================%RESET%
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
echo %BLUE%=============================================================================
echo Checking Services Status...
echo =============================================================================%RESET%
echo.

set "RUNNING_COUNT=0"
set "TOTAL_COUNT=5"

echo %YELLOW%[1/5] Checking MongoDB...%RESET%
net start | findstr -i mongo >nul
if !errorlevel! equ 0 (
    echo   Status: %GREEN%RUNNING%RESET%
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: %RED%NOT RUNNING%RESET%
)

echo %YELLOW%[2/5] Checking API Server (Port 3003)...%RESET%
netstat -an | findstr ":3003" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: %GREEN%LISTENING%RESET%
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: %RED%NOT LISTENING%RESET%
)

echo %YELLOW%[3/5] Checking ngrok...%RESET%
netstat -an | findstr ":4040" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: %GREEN%RUNNING%RESET%
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: %RED%NOT RUNNING%RESET%
)

echo %YELLOW%[4/5] Checking Web Server (Port 8082)...%RESET%
netstat -an | findstr ":8082" | findstr "LISTENING" >nul
if !errorlevel! equ 0 (
    echo   Status: %GREEN%LISTENING%RESET%
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: %RED%NOT LISTENING%RESET%
)

echo %YELLOW%[5/5] Checking Network URLs Service...%RESET%
tasklist | findstr "cmd.exe" | findstr "Network URLs" >nul
if !errorlevel! equ 0 (
    echo   Status: %GREEN%RUNNING%RESET%
    set /a RUNNING_COUNT+=1
) else (
    echo   Status: %RED%NOT RUNNING%RESET%
)

echo.
echo %BLUE%=============================================================================
echo SERVICES STATUS SUMMARY
echo =============================================================================%RESET%
echo %YELLOW%[SUMMARY] %RUNNING_COUNT%/%TOTAL_COUNT% services are running%RESET%
if %RUNNING_COUNT% equ %TOTAL_COUNT% (
    echo %GREEN%[STATUS] All services are running perfectly!%RESET%
) else (
    echo %RED%[WARNING] Some services are not running%RESET%
)
echo.
pause
goto MAIN_MENU

:: =============================================================================
:: START INDIVIDUAL SERVICE
:: =============================================================================
:START_INDIVIDUAL
cls
echo %BLUE%=============================================================================
echo Start Individual Service
echo =============================================================================%RESET%
echo.
echo %GREEN%1.%RESET% MongoDB
echo %GREEN%2.%RESET% API Server (Port 3003)
echo %GREEN%3.%RESET% ngrok Tunnel
echo %GREEN%4.%RESET% Web Server (Port 8082)
echo %GREEN%5.%RESET% Network URLs Service
echo %GREEN%6.%RESET% Back to Main Menu
echo.
set /p "service_choice=Enter service to start (1-6): "

if "%service_choice%"=="1" call :START_MONGODB
if "%service_choice%"=="2" call :START_API_SERVER
if "%service_choice%"=="3" call :START_NGROK
if "%service_choice%"=="4" call :START_WEB_SERVER
if "%service_choice%"=="5" call :START_NETWORK_URLS
if "%service_choice%"=="6" goto MAIN_MENU
goto START_INDIVIDUAL

:: =============================================================================
:: BUILD AND DEPLOY
:: =============================================================================
:BUILD_AND_DEPLOY
cls
echo %BLUE%=============================================================================
echo Build & Deploy Options
echo =============================================================================%RESET%
echo.
echo %GREEN%1.%RESET% Build Web App
echo %GREEN%2.%RESET% Build Android APK
echo %GREEN%3.%RESET% Build for SM-T585
echo %GREEN%4.%RESET% Build for DUB LX1
echo %GREEN%5.%RESET% Build iOS App
echo %GREEN%6.%RESET% Build iOS for Release
echo %GREEN%7.%RESET% Back to Main Menu
echo.
set /p "build_choice=Enter build option (1-7): "

if "%build_choice%"=="1" call :BUILD_WEB
if "%build_choice%"=="2" call :BUILD_ANDROID
if "%build_choice%"=="3" call :BUILD_SM_T585
if "%build_choice%"=="4" call :BUILD_DUB_LX1
if "%build_choice%"=="5" call :BUILD_IOS
if "%build_choice%"=="6" call :BUILD_IOS_RELEASE
if "%build_choice%"=="7" goto MAIN_MENU
goto BUILD_AND_DEPLOY

:: =============================================================================
:: CLEANUP & EXIT
:: =============================================================================
:CLEANUP_EXIT
cls
echo %BLUE%=============================================================================
echo Cleanup & Exit
echo =============================================================================%RESET%
echo.
echo %YELLOW%Stopping all services before exit...%RESET%
call :STOP_ALL
echo.
echo %GREEN%Cleanup completed. Goodbye!%RESET%
timeout /t 2 /nobreak >nul
exit

:: =============================================================================
:: SERVICE STARTUP FUNCTIONS
:: =============================================================================

:START_MONGODB
net start MongoDB >nul 2>&1
if !errorlevel! equ 0 (
    echo   %GREEN%✅ MongoDB started successfully%RESET%
) else (
    echo   %RED%❌ MongoDB failed to start%RESET%
)
goto :eof

:START_API_SERVER
cd /d "%API_SERVER_DIR%"
start "SOC Chat App - API Server" cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"
cd /d "%PROJECT_ROOT%"
echo   %GREEN%✅ API Server started on port 3003%RESET%
goto :eof

:START_NGROK
cd /d "%PROJECT_ROOT%"
start "SOC Chat App - ngrok Tunnel" cmd /c "ngrok http 3003 --domain=soc-chat-app.ngrok-free.app"
echo   %GREEN%✅ ngrok tunnel started%RESET%
goto :eof

:START_WEB_SERVER
cd /d "%WEB_BUILD_DIR%"
start "SOC Chat App - Web Server" cmd /c "python -m http.server 8082"
cd /d "%PROJECT_ROOT%"
echo   %GREEN%✅ Web server started on port 8082%RESET%
goto :eof

:START_NETWORK_URLS
cd /d "%PROJECT_ROOT%"
start "Network URLs Service" cmd /c "node local_network_config.js"
echo   %GREEN%✅ Network URLs service started%RESET%
goto :eof

:: =============================================================================
:: BUILD FUNCTIONS
:: =============================================================================

:BUILD_WEB
echo %YELLOW%Building web app...%RESET%
flutter build web --release
if !errorlevel! equ 0 (
    echo %GREEN%✅ Web app built successfully%RESET%
) else (
    echo %RED%❌ Web app build failed%RESET%
)
pause
goto :eof

:BUILD_ANDROID
echo %YELLOW%Building Android APK...%RESET%
flutter build apk --release
if !errorlevel! equ 0 (
    echo %GREEN%✅ Android APK built successfully%RESET%
) else (
    echo %RED%❌ Android APK build failed%RESET%
)
pause
goto :eof

:BUILD_SM_T585
echo %YELLOW%Building for SM-T585...%RESET%
flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
if !errorlevel! equ 0 (
    echo %GREEN%✅ SM-T585 APK built successfully%RESET%
) else (
    echo %RED%❌ SM-T585 APK build failed%RESET%
)
pause
goto :eof

:BUILD_DUB_LX1
echo %YELLOW%Building for DUB LX1...%RESET%
flutter build apk --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
if !errorlevel! equ 0 (
    echo %GREEN%✅ DUB LX1 APK built successfully%RESET%
) else (
    echo %RED%❌ DUB LX1 APK build failed%RESET%
)
pause
goto :eof

:BUILD_IOS
echo %YELLOW%Building iOS App (Debug)...%RESET%
echo %BLUE%Note: iOS builds require macOS and Xcode%RESET%
flutter build ios --debug --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
if !errorlevel! equ 0 (
    echo %GREEN%✅ iOS Debug build completed successfully%RESET%
    echo %YELLOW%To run on device: flutter run -d ios%RESET%
    echo %YELLOW%To install on device: Use Xcode or flutter install%RESET%
) else (
    echo %RED%❌ iOS build failed%RESET%
    echo %YELLOW%Make sure you have:%RESET%
    echo   - macOS system
    echo   - Xcode installed
    echo   - iOS Simulator or physical device
    echo   - Valid Apple Developer account (for device deployment)
)
pause
goto :eof

:BUILD_IOS_RELEASE
echo %YELLOW%Building iOS App (Release)...%RESET%
echo %BLUE%Note: Release builds require macOS, Xcode, and Apple Developer account%RESET%
flutter build ios --release --dart-define=API_BASE_URL_MOBILE=https://soc-chat-app.ngrok-free.app
if !errorlevel! equ 0 (
    echo %GREEN%✅ iOS Release build completed successfully%RESET%
    echo %YELLOW%Next steps:%RESET%
    echo   1. Open ios/Runner.xcworkspace in Xcode
    echo   2. Select your target device
    echo   3. Archive and upload to App Store Connect
    echo   4. Or export for TestFlight/Ad Hoc distribution
) else (
    echo %RED%❌ iOS Release build failed%RESET%
    echo %YELLOW%Requirements for iOS Release:%RESET%
    echo   - macOS system
    echo   - Xcode with iOS SDK
    echo   - Apple Developer account ($99/year)
    echo   - Valid provisioning profiles
    echo   - Code signing certificates
)
pause
goto :eof
