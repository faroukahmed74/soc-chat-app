@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM =============================================================================
REM SOC Chat App - Enhanced Database Admin Tool
REM =============================================================================
REM This batch file provides easy access to the enhanced database admin tool
REM with advanced features including user management, statistics, and maintenance
REM
REM Usage: view_database.bat [command]
REM
REM =============================================================================

title SOC Chat App - Enhanced Database Admin Tool

echo.
echo =============================================================================
echo   SOC Chat App - Enhanced Database Admin Tool
echo =============================================================================
echo   Advanced Features:
echo   - User Management (View passwords, Delete users, Update roles)
echo   - Statistics ^& Analytics (Users, Chats, Messages)
echo   - Maintenance (Cleanup, Export database)
echo   - System Health Monitoring
echo   - DANGER ZONE (Delete users, Delete all data, Reset database)
echo =============================================================================
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if we're in the right directory
if not exist "database_admin_tool.js" (
    echo ERROR: database_admin_tool.js not found
    echo Please run this script from the project root directory
    pause
    exit /b 1
)

REM Check if MongoDB is running
echo Checking MongoDB connection...
curl -s http://localhost:3003/health >nul 2>&1
if errorlevel 1 (
    echo API server not running. Starting services...
    call start_all_services.bat
    if errorlevel 1 (
        echo Failed to start services
        pause
        exit /b 1
    )
)

echo MongoDB connection check completed
echo.

REM Check command line arguments
if "%~1"=="" (
    echo Starting enhanced interactive database admin tool...
    echo.
    echo Available command-line commands:
    echo   - stats     : Show database statistics
    echo   - users     : View all users
    echo   - chats     : View all chats
    echo   - messages  : View recent messages
    echo   - admins    : View admin users
    echo   - health    : System health check
    echo.
    echo Interactive mode includes advanced features:
    echo   - User Management (View passwords, Delete users, Update roles)
    echo   - Statistics ^& Analytics (Users, Chats, Messages)
    echo   - Maintenance (Cleanup, Export database)
    echo   - System Health Monitoring
    echo   - DANGER ZONE (Delete users, Delete all data, Reset database)
    echo.
    
    REM Try to run the database tool
    node database_admin_tool.js
    if errorlevel 1 (
        echo.
        echo ERROR: Database tool failed to run
        echo This might be due to missing dependencies
        echo.
        echo Try installing dependencies:
        echo   cd servers\local_api_server
        echo   npm install
        echo.
        pause
        exit /b 1
    )
) else (
    echo Running command: %~1
    node database_admin_tool.js %~1 %~2
    if errorlevel 1 (
        echo.
        echo ERROR: Database tool failed to run
        echo This might be due to missing dependencies
        echo.
        echo Try installing dependencies:
        echo   cd servers\local_api_server
        echo   npm install
        echo.
        pause
        exit /b 1
    )
)

echo.
echo Database viewer completed
pause