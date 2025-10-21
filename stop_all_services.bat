@echo off
setlocal

echo Stopping all SOC Chat services...
call "%~dp0\services_manager.bat" stop-all
echo.
pause

endlocal