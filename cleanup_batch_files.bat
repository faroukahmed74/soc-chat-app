@echo off
echo =============================================================================
echo SOC Chat App - Batch Files Cleanup
echo =============================================================================
echo.
echo This script will remove all conflicting batch files and keep only the
echo new unified services_manager.bat file.
echo.
echo Files to be removed:
echo   - start_all_services.bat
echo   - stop_all_services.bat
echo   - restart_all_services.bat
echo   - check_services_status.bat
echo   - start_api_server.bat
echo   - start_mongodb.bat
echo   - start_ngrok.bat
echo   - start_web_server_*.bat
echo   - start_local_network_server*.bat
echo   - start_network_urls_service.bat
echo   - And many more conflicting files...
echo.
set /p "confirm=Are you sure you want to proceed? (y/N): "
if /i not "%confirm%"=="y" goto :eof

echo.
echo Removing conflicting batch files...

:: Remove main service management files
if exist "start_all_services.bat" del "start_all_services.bat"
if exist "stop_all_services.bat" del "stop_all_services.bat"
if exist "restart_all_services.bat" del "restart_all_services.bat"
if exist "check_services_status.bat" del "check_services_status.bat"

:: Remove individual service files
if exist "start_api_server.bat" del "start_api_server.bat"
if exist "start_mongodb.bat" del "start_mongodb.bat"
if exist "start_ngrok.bat" del "start_ngrok.bat"
if exist "start_network_urls_service.bat" del "start_network_urls_service.bat"

:: Remove web server files
if exist "start_web_server_optimized.bat" del "start_web_server_optimized.bat"
if exist "start_web_server_simple.bat" del "start_web_server_simple.bat"
if exist "start_web_server_with_ip.bat" del "start_web_server_with_ip.bat"
if exist "start_local_web_server.bat" del "start_local_web_server.bat"

:: Remove local network server files
if exist "start_local_network_server.bat" del "start_local_network_server.bat"
if exist "start_local_network_server_fixed.bat" del "start_local_network_server_fixed.bat"
if exist "create_local_network.bat" del "create_local_network.bat"

:: Remove build files
if exist "build_mobile_with_ngrok.bat" del "build_mobile_with_ngrok.bat"
if exist "build_for_dub_lx1.bat" del "build_for_dub_lx1.bat"

:: Remove installation files
if exist "install_sm_t585.bat" del "install_sm_t585.bat"
if exist "install_dub_lx1.bat" del "install_dub_lx1.bat"
if exist "install_android_device.bat" del "install_android_device.bat"
if exist "run_for_sm_t585.bat" del "run_for_sm_t585.bat"

:: Remove utility files
if exist "show_network_ips.bat" del "show_network_ips.bat"
if exist "show_network_ips_simple.bat" del "show_network_ips_simple.bat"
if exist "view_database.bat" del "view_database.bat"
if exist "fix_web_app_api_config.bat" del "fix_web_app_api_config.bat"

:: Remove autostart files
if exist "setup_autostart_services.bat" del "setup_autostart_services.bat"
if exist "setup_autostart_disable.bat" del "setup_autostart_disable.bat"
if exist "check_autostart_status.bat" del "check_autostart_status.bat"

echo.
echo ✅ Cleanup completed!
echo.
echo The following files remain:
echo   - services_manager.bat (NEW - Unified service manager)
echo   - cleanup_batch_files.bat (This cleanup script)
echo.
echo You can now use 'services_manager.bat' to manage all services.
echo.
pause
