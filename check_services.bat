@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\scripts\check_services.ps1"
echo.
echo Health summary written to scripts\run\services_health.txt
echo.
pause

endlocal