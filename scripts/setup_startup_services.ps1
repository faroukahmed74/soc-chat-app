# =============================================================================
# SOC Chat App - Setup Auto-Start Services
# =============================================================================
# This script configures all services to start automatically at system startup
# =============================================================================

param(
    [switch]$Remove = $false
)

$taskName = "SOC_Chat_App_Startup_Services"
$scriptPath = Join-Path $PSScriptRoot "startup_all_services.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup Auto-Start Services" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($Remove) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Auto-start services task removed" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Auto-start services task not found" -ForegroundColor Yellow
    }
    exit 0
}

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "[WARNING] Auto-start services task already exists" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (y/N)"
    if ($overwrite -ne "y") {
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create action
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""

# Create trigger (at startup with delay)
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT2M"  # 2 minute delay to ensure system is ready

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # No time limit

# Create principal (run even when user is not logged in)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest

# Register task
try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Auto-start SOC Chat App services (Web Server, API Server, MongoDB, ngrok) at system startup" | Out-Null
    
    Write-Host "[OK] Auto-start services task created successfully!" -ForegroundColor Green
    Write-Host "`nServices will start automatically after PC restart:" -ForegroundColor Cyan
    Write-Host "  1. Web Server (servers/server.js) - Port 8082" -ForegroundColor White
    Write-Host "  2. API Server (local_api_server/server.js) - Port 3003" -ForegroundColor White
    Write-Host "  3. MongoDB, ngrok, Network URLs (services_manager option 1)" -ForegroundColor White
    Write-Host "`nStartup delay: 2 minutes after boot" -ForegroundColor Yellow
    Write-Host "Logs: logs\startup.log" -ForegroundColor Yellow
    
} catch {
    Write-Host "[ERROR] Failed to create auto-start task: $_" -ForegroundColor Red
    Write-Host "`nNote: You may need to run PowerShell as Administrator" -ForegroundColor Yellow
    exit 1
}

