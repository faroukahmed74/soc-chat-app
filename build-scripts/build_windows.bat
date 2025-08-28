@echo off
echo ========================================
echo   SOC Chat App - Windows Build Script
echo ========================================
echo.

echo Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter not found in PATH
    echo Please install Flutter and add it to PATH
    pause
    exit /b 1
)

echo.
echo Checking Windows desktop support...
flutter config --enable-windows-desktop

echo.
echo Running flutter doctor...
flutter doctor

echo.
echo Building Windows executable...
echo This may take several minutes...
echo.

flutter build windows --release

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo   BUILD SUCCESSFUL! 🎉
    echo ========================================
    echo.
    echo Your Windows executable is located at:
    echo build\windows\runner\Release\soc_chat_app.exe
    echo.
    echo You can now distribute this .exe file!
    echo.
) else (
    echo.
    echo ========================================
    echo   BUILD FAILED! ❌
    echo ========================================
    echo.
    echo Please check the error messages above
    echo and ensure all Windows requirements are met
    echo.
)

pause

