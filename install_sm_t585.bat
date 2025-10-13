@echo off
setlocal enabledelayedexpansion

REM Install and launch SOC Chat App release APK on SM-T585
REM Prerequisites: Android platform-tools (adb), USB debugging enabled, device connected

set APK=build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK%" (
  echo [ERROR] Release APK not found: %APK%
  echo [HINT] Build it first: flutter build apk --release
  exit /b 1
)

REM Resolve adb path (prefer local SDK, fallback to PATH)
set ADB=%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb

"%ADB%" version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] adb not found. Install Android platform-tools or add it to PATH.
  echo [HINT] https://developer.android.com/tools/releases/platform-tools
  exit /b 1
)

echo [INFO] Listing connected devices...
"%ADB%" devices

set TARGET=
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do (
  if "%%b"=="device" (
    set TARGET=%%a
    goto :targetFound
  )
)

echo [ERROR] No devices detected. Enable USB debugging and connect SM-T585.
echo [HINT] On the tablet: Settings > Developer options > USB debugging.
exit /b 1

:targetFound
echo [INFO] Target device: %TARGET%
for /f "delims=" %%m in ('"%ADB%" -s %TARGET% shell getprop ro.product.model') do set MODEL=%%m
echo [INFO] Model: %MODEL%

echo [INFO] Installing APK...
"%ADB%" -s %TARGET% install -r "%APK%"
if errorlevel 1 (
  echo [WARN] Install failed, attempting uninstall + reinstall...
  "%ADB%" -s %TARGET% uninstall com.faroukahmed74.socchatapp >nul 2>&1
  "%ADB%" -s %TARGET% install "%APK%"
  if errorlevel 1 (
    echo [ERROR] Install failed. Check device authorization and storage space.
    exit /b 1
  )
)

echo [INFO] Launching app...
"%ADB%" -s %TARGET% shell am start -n com.faroukahmed74.socchatapp/.MainActivity
if errorlevel 1 (
  echo [ERROR] Launch failed. You can try:
  echo   "%ADB%" -s %TARGET% shell monkey -p com.faroukahmed74.socchatapp -c android.intent.category.LAUNCHER 1
  exit /b 1
)

echo [DONE] App installed and launched successfully on %MODEL% (%TARGET%).
exit /b 0