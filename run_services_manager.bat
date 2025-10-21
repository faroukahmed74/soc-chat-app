@echo off
title SOC Chat App - Services Manager
cd /d "%~dp0"

echo =============================================================================
echo SOC Chat App - Services Manager
echo =============================================================================
echo.
echo Starting the unified services manager (auto-start all services)...
echo.
rem Small delay to allow the window to render
timeout /t 1 /nobreak >nul

rem Ensure services_manager.bat exists
if not exist "%~dp0services_manager.bat" (
  echo ERROR: services_manager.bat not found in %~dp0
  echo Please ensure the file exists and try again.
  pause
  exit /b 1
)

:: Run the main services manager
call services_manager.bat start-all

:: If we get here, the manager exited
echo.
echo Services manager has exited.
pause
