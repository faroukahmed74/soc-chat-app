# =============================================================================
# SOC Chat App - Schedule Mirror Backup
# =============================================================================
# This script sets up Windows Task Scheduler to run mirror backups automatically
# Mirror backups run more frequently (every 6 hours) for near real-time protection
# =============================================================================

param(
    [string]$MirrorDir = "F:\soc-chat-mirror",
    [int]$IntervalHours = 6,
    [switch]$RemoveSchedule = $false
)

$taskName = "SOC_Chat_App_Mirror_Backup"
$scriptPath = Join-Path $PSScriptRoot "mirror_backup.ps1"
$taskDescription = "Automatic mirror backup for SOC Chat App (exact copy, updated every $IntervalHours hours)"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Mirror Backup Scheduler" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($RemoveSchedule) {
    Write-Host "Removing scheduled mirror backup task..." -ForegroundColor Yellow
    
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Scheduled mirror backup task removed" -ForegroundColor Green
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
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -MirrorDir `"$MirrorDir`""

# Create trigger (every 6 hours, starting at midnight)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date "00:00") -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) -RepetitionDuration (New-TimeSpan -Days 365)

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
    
    Write-Host "[OK] Scheduled mirror backup task created successfully!" -ForegroundColor Green
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $taskName" -ForegroundColor White
    Write-Host "  Schedule: Every $IntervalHours hours (starting at midnight)" -ForegroundColor White
    Write-Host "  Mirror Directory: $MirrorDir" -ForegroundColor White
    Write-Host "`nTo view/manage the task:" -ForegroundColor Yellow
    Write-Host "  Task Scheduler → Task Scheduler Library → $taskName" -ForegroundColor Gray
    Write-Host "`nTo remove the scheduled task:" -ForegroundColor Yellow
    Write-Host "  .\scripts\schedule_mirror_backup.ps1 -RemoveSchedule" -ForegroundColor Gray
    
} catch {
    Write-Host "[ERROR] Failed to create scheduled task: $_" -ForegroundColor Red
    exit 1
}

