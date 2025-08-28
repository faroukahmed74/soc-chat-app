@echo off
echo ========================================
echo   Building SOC Chat App Executable
echo ========================================
echo.

echo This script will create a standalone .exe file
echo that can run on any Windows PC without dependencies.
echo.

REM Check if web build exists
if not exist "build\web\index.html" (
    echo Error: Web build not found!
    echo Please run 'flutter build web' first.
    echo.
    pause
    exit /b 1
)

echo Installing Node.js dependencies...
npm install

echo.
echo Building executable...
npm run build

echo.
echo ========================================
echo   Executable Created!
echo ========================================
echo.
echo Location: soc-chat-app.exe
echo.
echo This .exe file:
echo - Can run on ANY Windows PC (no Flutter needed)
echo - No network requirements
echo - Self-contained with embedded web server
echo - Just double-click to run!
echo.
echo To distribute: Copy soc-chat-app.exe to any PC
echo.
pause
