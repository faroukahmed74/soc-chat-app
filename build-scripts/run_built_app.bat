@echo off
echo ========================================
echo   SOC Chat App - Built Web App Runner
echo ========================================
echo.

echo Starting built web app...
echo App will be available at: http://localhost:8080
echo.

echo Press Ctrl+C to stop the server
echo.

cd build\web
python -m http.server 8080

pause
