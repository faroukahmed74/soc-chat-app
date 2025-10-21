@echo off
echo ========================================
echo   MongoDB Installation Guide
echo ========================================
echo.
echo MongoDB is required for the SOC Chat App to work.
echo.
echo INSTALLATION OPTIONS:
echo.
echo 1. DOWNLOAD AND INSTALL MANUALLY:
echo    - Go to: https://www.mongodb.com/try/download/community
echo    - Download MongoDB Community Server for Windows
echo    - Run the installer and follow the setup wizard
echo    - Make sure to check "Install MongoDB as a Service"
echo    - Add MongoDB to your system PATH during installation
echo.
echo 2. INSTALL VIA CHOCOLATEY (if you have Chocolatey):
echo    - Open PowerShell as Administrator
echo    - Run: choco install mongodb
echo.
echo 3. INSTALL VIA WINGET (Windows 10/11):
echo    - Open PowerShell as Administrator
echo    - Run: winget install MongoDB.Server
echo.
echo 4. PORTABLE INSTALLATION:
echo    - Download MongoDB Community Server ZIP
echo    - Extract to C:\mongodb
echo    - Add C:\mongodb\bin to your system PATH
echo    - Create C:\data\db directory
echo.
echo AFTER INSTALLATION:
echo - Restart your command prompt/PowerShell
echo - Run: mongod --version (to verify installation)
echo - Run the services manager again
echo.
echo TROUBLESHOOTING:
echo - If MongoDB is installed but not found, check your PATH
echo - If you get permission errors, run as Administrator
echo - If port 27017 is in use, stop other MongoDB instances
echo.
pause
