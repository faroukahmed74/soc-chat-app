@echo off
echo ========================================
echo   Creating Portable SOC Chat App
echo ========================================
echo.

echo This script will create a portable executable package
echo that can run on any PC without network requirements.
echo.

REM Check if web build exists
if not exist "build\web\index.html" (
    echo Error: Web build not found!
    echo Please run 'flutter build web' first.
    echo.
    pause
    exit /b 1
)

echo Creating portable package...
echo.

REM Create portable directory
if not exist "portable" mkdir portable
if not exist "portable\app" mkdir portable\app
if not exist "portable\server" mkdir portable\server

REM Copy web build
echo Copying web app files...
xcopy "build\web\*" "portable\app\" /E /I /Y

REM Create portable server
echo Creating portable server...
echo @echo off > "portable\server\start_server.bat"
echo title SOC Chat App Server >> "portable\server\start_server.bat"
echo echo Starting SOC Chat App... >> "portable\server\start_server.bat"
echo echo. >> "portable\server\start_server.bat"
echo cd /d "%%~dp0..\app" >> "portable\server\start_server.bat"
echo echo App will be available at: http://localhost:8080 >> "portable\server\start_server.bat"
echo echo. >> "portable\server\start_server.bat"
echo echo Press Ctrl+C to stop the server >> "portable\server\start_server.bat"
echo echo. >> "portable\server\start_server.bat"
echo python -m http.server 8080 >> "portable\server\start_server.bat"
echo pause >> "portable\server\start_server.bat"

REM Create main launcher
echo Creating main launcher...
echo @echo off > "portable\SOC_Chat_App.bat"
echo title SOC Chat App >> "portable\SOC_Chat_App.bat"
echo echo ======================================== >> "portable\SOC_Chat_App.bat"
echo echo   SOC Chat App - Portable Version >> "portable\SOC_Chat_App.bat"
echo echo ======================================== >> "portable\SOC_Chat_App.bat"
echo echo. >> "portable\SOC_Chat_App.bat"
echo echo Starting portable SOC Chat App... >> "portable\SOC_Chat_App.bat"
echo echo. >> "portable\SOC_Chat_App.bat"
echo start "" "%%~dp0app\index.html" >> "portable\SOC_Chat_App.bat"
echo echo. >> "portable\SOC_Chat_App.bat"
echo echo App launched! Opening in browser... >> "portable\SOC_Chat_App.bat"
echo echo. >> "portable\SOC_Chat_App.bat"
echo echo To run with local server (recommended): >> "portable\SOC_Chat_App.bat"
echo echo   Run: server\start_server.bat >> "portable\SOC_Chat_App.bat"
echo echo echo Then open: http://localhost:8080 >> "portable\SOC_Chat_App.bat"
echo echo. >> "portable\SOC_Chat_App.bat"
echo pause >> "portable\SOC_Chat_App.bat"

REM Create README
echo Creating README...
echo SOC Chat App - Portable Version > "portable\README.txt"
echo ================================ >> "portable\README.txt"
echo. >> "portable\README.txt"
echo This is a portable version of the SOC Chat App that can run on any PC. >> "portable\README.txt"
echo. >> "portable\README.txt"
echo How to use: >> "portable\README.txt"
echo 1. Double-click SOC_Chat_App.bat to launch the app >> "portable\README.txt"
echo 2. For better performance, run server\start_server.bat first >> "portable\README.txt"
echo 3. Then open http://localhost:8080 in your browser >> "portable\README.txt"
echo. >> "portable\README.txt"
echo Requirements: >> "portable\README.txt"
echo - Windows PC with a web browser >> "portable\README.txt"
echo - Python (optional, for local server) >> "portable\README.txt"
echo. >> "portable\README.txt"
echo Copy this entire 'portable' folder to any PC to run the app! >> "portable\README.txt"

echo.
echo ========================================
echo   Portable Package Created!
echo ========================================
echo.
echo Location: portable\
echo.
echo Files created:
echo - portable\SOC_Chat_App.bat (Main launcher)
echo - portable\app\ (Web app files)
echo - portable\server\start_server.bat (Local server)
echo - portable\README.txt (Instructions)
echo.
echo To distribute: Copy the entire 'portable' folder
echo to any PC and run SOC_Chat_App.bat
echo.
pause
