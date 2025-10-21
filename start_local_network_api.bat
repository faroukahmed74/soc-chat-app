@echo off
setlocal enabledelayedexpansion

:: Start the Local Network API server interactively
cd /d "%~dp0\servers\local_api_server"
echo Starting Local Network API on port 3004...
echo Press Ctrl+C in this window to stop.
start "Local Network API (3004)" cmd /k "node local_network_config.js"

endlocal