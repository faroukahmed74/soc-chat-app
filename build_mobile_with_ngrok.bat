@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM =============================================================================
REM SOC Chat App - Mobile Build with ngrok Integration (Windows)
REM =============================================================================
REM This script builds Android APK with dynamically provided ngrok URL
REM Optimized for Samsung Galaxy Tab A (SM-T585)
REM
REM Usage: build_mobile_with_ngrok.bat [--url <ngrok_url>] [--platform <android|ios>]
REM
REM =============================================================================

title SOC Chat App - Mobile Build with ngrok

echo.
echo =============================================================================
echo   SOC Chat App - Mobile Build with ngrok
echo =============================================================================
echo.

REM Set colors for output
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

REM Default values - Using permanent reserved domain
set "NGROK_URL=https://soc-chat-app.ngrok-free.app"
set "PLATFORM=android"

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--url" (
    set "NGROK_URL=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--platform" (
    set "PLATFORM=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--help" (
    goto :show_help
)
echo %RED%Unknown parameter: %~1%NC%
goto :show_help

:args_done

REM Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo %RED%Error: Please run this script from the Flutter project root directory%NC%
    echo %RED%Expected: pubspec.yaml%NC%
    pause
    exit /b 1
)

echo %BLUE%Checking prerequisites...%NC%

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo %RED%Error: Flutter is not installed or not in PATH%NC%
    echo %RED%Please install Flutter from https://flutter.dev/docs/get-started/install%NC%
    pause
    exit /b 1
)

REM Ensure logs directory exists
if not exist "logs" mkdir logs

REM Check if ngrok URL is provided or fetch it
if "%NGROK_URL%"=="" (
    echo %YELLOW%No ngrok URL provided. Attempting to fetch from local ngrok API...%NC%
    
    REM Fetch ngrok URL via PowerShell JSON parsing for reliability
    for /f "usebackq tokens=*" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $t = Invoke-RestMethod -Uri 'http://localhost:4040/api/tunnels' -TimeoutSec 5; $u = $t.tunnels | Where-Object { $_.proto -eq 'https' } | Select-Object -First 1 -ExpandProperty public_url; if ($u) { Write-Output $u } } catch { }"`) do (
        set "NGROK_URL=%%I"
    )
    
    if not "%NGROK_URL%"=="" (
        echo %GREEN%Fetched ngrok URL: %NGROK_URL%%NC%
        goto :url_found
    )
    
    echo %RED%Failed to fetch ngrok URL from local API%NC%
    echo %RED%Please ensure ngrok is running or provide URL with --url parameter%NC%
    echo %RED%Usage: build_mobile_with_ngrok.bat --url https://your-ngrok-url.ngrok.app%NC%
    pause
    exit /b 1
) else (
    echo %GREEN%Using provided ngrok URL: %NGROK_URL%%NC%
)

:url_found

REM Validate ngrok URL
echo %NGROK_URL% | findstr "https://" >nul
if errorlevel 1 (
    echo %RED%Invalid ngrok URL. It must start with 'https://'%NC%
    echo %RED%Provided: %NGROK_URL%%NC%
    pause
    exit /b 1
)

echo %GREEN%ngrok URL validated%NC%
echo.

REM =============================================================================
REM Build Android APK
REM =============================================================================
if "%PLATFORM%"=="android" (
    echo %YELLOW%Building Android APK for Samsung Galaxy Tab A (SM-T585)...%NC%
    
    REM Clean previous builds
    echo %YELLOW%Cleaning previous builds...%NC%
    flutter clean
    
    REM Get dependencies
    echo %YELLOW%Getting Flutter dependencies...%NC%
    flutter pub get
    
    REM Build APK with ngrok URL
    echo Building APK with ngrok URL: %NGROK_URL%
    flutter build apk --release --dart-define=API_BASE_URL_MOBILE=%NGROK_URL% --dart-define=USE_PHYSICAL_SERVER=true
    
    if errorlevel 1 (
        echo %RED%Error building Android APK%NC%
        pause
        exit /b 1
    )
    
    echo %GREEN%Android APK built successfully!%NC%
    echo.
    
    REM Show APK location
    if exist "build\app\outputs\flutter-apk\app-release.apk" (
        echo %GREEN%APK Location: build\app\outputs\flutter-apk\app-release.apk%NC%
        echo %GREEN%APK Size: 
        for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do echo %%~zA bytes
        echo.
        
        REM Copy APK to easier location
        copy "build\app\outputs\flutter-apk\app-release.apk" "SOC_Chat_App_SM-T585.apk" >nul
        echo %GREEN%APK copied to: SOC_Chat_App_SM-T585.apk%NC%
        echo.
    )
)

REM =============================================================================
REM Build iOS (if on macOS)
REM =============================================================================
if "%PLATFORM%"=="ios" (
    echo %YELLOW%Building iOS App...%NC%
    
    REM Check if running on macOS
    ver | findstr "Version 10" >nul
    if errorlevel 1 (
        echo %YELLOW%Skipping iOS build on Windows. iOS builds require macOS.%NC%
    ) else (
        REM Clean previous builds
        echo %YELLOW%Cleaning previous builds...%NC%
        flutter clean
        
        REM Get dependencies
        echo %YELLOW%Getting Flutter dependencies...%NC%
        flutter pub get
        
        REM Build iOS with ngrok URL
        echo %YELLOW%Building iOS with ngrok URL: %NGROK_URL%%NC%
        flutter build ios --release --dart-define=API_BASE_URL_MOBILE=%NGROK_URL% --dart-define=USE_PHYSICAL_SERVER=true --no-codesign
        
        if errorlevel 1 (
            echo %RED%Error building iOS App%NC%
            pause
            exit /b 1
        )
        
        echo %GREEN%iOS App built successfully!%NC%
        echo.
    )
)

REM =============================================================================
REM Success Message
REM =============================================================================
echo =============================================================================
echo   %GREEN%Mobile Build Completed Successfully!%NC%
echo =============================================================================
echo.
echo %GREEN%Build Configuration:%NC%
echo   - Platform: %PLATFORM%
echo   - ngrok URL: %NGROK_URL%
echo   - Physical Server: Enabled
echo.

if "%PLATFORM%"=="android" (
    echo %BLUE%Installation Instructions for Samsung Galaxy Tab A (SM-T585):%NC%
    echo   1. Enable "Unknown Sources" in Settings ^> Security
    echo   2. Transfer SOC_Chat_App_SM-T585.apk to your tablet
    echo   3. Tap the APK file to install
    echo   4. Open the app and test all features
    echo.
    echo %BLUE%Testing Checklist:%NC%
    echo   - [ ] App installs successfully
    echo   - [ ] App opens without crashes
    echo   - [ ] User registration works
    echo   - [ ] User login works
    echo   - [ ] One-to-one chat works
    echo   - [ ] Group chat works
    echo   - [ ] Media sharing works (photos, videos)
    echo   - [ ] Real-time messaging works
    echo   - [ ] Admin panel works (if admin user)
    echo.
)

echo %BLUE%Useful Commands:%NC%
echo   - Start all services: start_all_services.bat
echo   - Stop all services: stop_all_services.bat
echo   - Restart all services: restart_all_services.bat
echo   - View API logs: pm2 logs
echo.
echo %GREEN%Press any key to continue...%NC%
pause >nul
goto :end

:show_help
echo %BLUE%Usage: build_mobile_with_ngrok.bat [OPTIONS]%NC%
echo.
echo %BLUE%Options:%NC%
echo   --url ^<ngrok_url^>    Specify the ngrok URL directly
echo   --platform ^<string^>  Specify platform: 'android' or 'ios' (default: android)
echo   --help                Show this help message
echo.
echo %BLUE%Examples:%NC%
echo   build_mobile_with_ngrok.bat
echo   build_mobile_with_ngrok.bat --url "https://abc123.ngrok.app"
echo   build_mobile_with_ngrok.bat --platform android --url "https://abc123.ngrok.app"
echo.
echo %BLUE%Requirements:%NC%
echo   - Flutter SDK installed and configured
echo   - ngrok running (if not providing URL directly)
echo   - Android SDK configured for Flutter
echo.

:end
endlocal
