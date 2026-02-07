@echo off
setlocal

echo Starting all SOC Chat services (MongoDB, OpenAI + Ollama AI, API, ngrok, Web, etc.)...
call "%~dp0\services_manager.bat" start-all
echo.
echo Use "check_services.bat" to verify health.
echo.
pause

endlocal