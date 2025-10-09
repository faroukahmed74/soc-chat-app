@echo off
title SOC Chat App - Restarting All Services
echo =============================================================================
echo SOC Chat App - Restarting All Services
echo =============================================================================
echo.

echo [INFO] Stopping all services first...
call stop_all_services.bat

echo.
echo [INFO] Waiting 3 seconds before restarting...
timeout /t 3 /nobreak >nul

echo.
echo [INFO] Starting all services...
call start_all_services.bat