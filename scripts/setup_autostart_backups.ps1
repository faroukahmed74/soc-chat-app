# =============================================================================
# SOC Chat App - Setup Auto-Start Backups After Restart
# =============================================================================
# This script configures backups to automatically start after PC restart
# =============================================================================

param(
    [switch]$Remove = $false
)

$taskName = "SOC_Chat_App_Start_RealTime_Backup"
$scriptPath = Join-Path $PSScriptRoot "start_realtime_backup.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup Auto-Start Backups" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($Remove) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Auto-start task removed" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Auto-start task not found" -ForegroundColor Yellow
    }
    exit 0
}

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "[WARNING] Auto-start task already exists" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (y/N)"
    if ($overwrite -ne "y") {
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create action
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""

# Create trigger (at startup)
$trigger = New-ScheduledTaskTrigger -AtStartup

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
        -Description "Auto-start real-time backup after system restart" | Out-Null
    
    Write-Host "[OK] Auto-start task created successfully!" -ForegroundColor Green
    Write-Host "`nReal-time backup will start automatically after PC restart" -ForegroundColor Cyan
    
} catch {
    Write-Host "[ERROR] Failed to create auto-start task: $_" -ForegroundColor Red
    Write-Host "`nNote: You may need to run PowerShell as Administrator" -ForegroundColor Yellow
    exit 1
}

