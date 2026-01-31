@echo off
REM =============================================================================
REM SOC Chat App - Interactive Services Manager (Launcher)
REM =============================================================================
REM This wrapper exists to match the documented path:
REM   services_manager\interactive\services_manager_interactive.bat
REM It forwards to the repo-root interactive manager.
REM =============================================================================

cd /d "%~dp0"
call "..\..\services_manager_interactive.bat"

