@echo off
echo =============================================================================
echo   SOC Chat App - Complete Test for Samsung Galaxy Tab A (SM-T585)
echo =============================================================================
echo.

echo This will:
echo 1. Start all services (MongoDB, API Server, ngrok)
echo 2. Build Android APK for SM-T585
echo 3. Show installation instructions
echo.
pause

echo Step 1: Starting services...
call start_all_services.bat
if errorlevel 1 (
    echo Failed to start services
    pause
    exit /b 1
)

echo.
echo Step 2: Building APK...
call build_mobile_with_ngrok.bat
if errorlevel 1 (
    echo Failed to build APK
    pause
    exit /b 1
)

echo.
echo =============================================================================
echo   Ready for Samsung Galaxy Tab A (SM-T585)!
echo =============================================================================
echo.
echo Installation:
echo 1. Enable "Unknown Sources" in Settings ^> Security
echo 2. Copy SOC_Chat_App_SM-T585.apk to your tablet
echo 3. Tap the APK to install
echo 4. Open the app and test!
echo.
pause
