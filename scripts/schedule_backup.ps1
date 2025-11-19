# =============================================================================
# SOC Chat App - Schedule Automatic Backups
# =============================================================================
# This script sets up Windows Task Scheduler to run backups automatically
# =============================================================================

param(
    [string]$BackupDir = "F:\soc-chat-backups",
    [int]$IntervalHours = 24,
    [int]$RetentionDays = 30,
    [switch]$RemoveSchedule = $false
)

$taskName = "SOC_Chat_App_Backup"
$scriptPath = Join-Path $PSScriptRoot "backup_app_data.ps1"
$taskDescription = "Automatic backup for SOC Chat App data (MongoDB + Media files)"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Backup Scheduler" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($RemoveSchedule) {
    Write-Host "Removing scheduled backup task..." -ForegroundColor Yellow
    
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Scheduled backup task removed" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No scheduled task found" -ForegroundColor Yellow
    }
    exit 0
}

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "[WARNING] Scheduled task already exists: $taskName" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite existing task? (y/N)"
    if ($overwrite -ne "y") {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create action
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -BackupDir `"$BackupDir`" -Compress -RetentionDays $RetentionDays"

# Create trigger (daily at 2 AM)
$trigger = New-ScheduledTaskTrigger -Daily -At "02:00"

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false

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
        -Description $taskDescription | Out-Null
    
    Write-Host "[OK] Scheduled backup task created successfully!" -ForegroundColor Green
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $taskName" -ForegroundColor White
    Write-Host "  Schedule: Daily at 2:00 AM" -ForegroundColor White
    Write-Host "  Backup Directory: $BackupDir" -ForegroundColor White
    Write-Host "  Retention: $RetentionDays days" -ForegroundColor White
    Write-Host "`nTo view/manage the task:" -ForegroundColor Yellow
    Write-Host "  Task Scheduler → Task Scheduler Library → $taskName" -ForegroundColor Gray
    Write-Host "`nTo remove the scheduled task:" -ForegroundColor Yellow
    Write-Host "  .\scripts\schedule_backup.ps1 -RemoveSchedule" -ForegroundColor Gray
    
} catch {
    Write-Host "[ERROR] Failed to create scheduled task: $_" -ForegroundColor Red
    exit 1
}

