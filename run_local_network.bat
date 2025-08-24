@echo off
echo ========================================
echo   SOC Chat App - Local Network Runner
echo ========================================
echo.

echo Your Local IP Address: 10.120.9.88
echo.

echo Starting Flutter app on local network...
echo App will be available at: http://10.120.9.88:8080
echo.

echo Press Ctrl+C to stop the server
echo.

flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

pause
