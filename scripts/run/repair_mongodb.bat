@echo off
REM SOC Chat App - MongoDB repair helper (Windows)
REM WARNING: --repair can cause data loss. Prefer restore from backup if available.

set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%repair_mongodb.ps1"

@echo off
REM SOC Chat App - MongoDB repair helper (Windows)
REM WARNING: --repair can cause data loss. Prefer restoring from backup if available.

set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%repair_mongodb.ps1"

