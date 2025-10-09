@echo off
title SOC Chat App - MongoDB Service
echo =============================================================================
echo SOC Chat App - Starting MongoDB Service
echo =============================================================================
echo.

echo [INFO] Checking MongoDB service...
net start MongoDB >nul 2>&1
if errorlevel 1 (
    echo [INFO] MongoDB service not found or already running
) else (
    echo [SUCCESS] MongoDB service started successfully
)

echo.
echo [INFO] MongoDB is ready!
echo [INFO] Press any key to close this window...
pause >nul


