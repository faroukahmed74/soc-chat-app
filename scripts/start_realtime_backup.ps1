# =============================================================================
# SOC Chat App - Start Real-Time Backup Service
# =============================================================================
# This script starts the real-time backup as a background service
# =============================================================================

param(
    [string]$RealtimeBackupDir = "F:\soc-chat-realtime",
    [switch]$InstallService = $false
)

$scriptPath = Join-Path $PSScriptRoot "realtime_backup.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Starting Real-Time Backup Service" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if already running
$existingProcess = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*realtime_backup.ps1*" -and $_.Id -ne $PID
}

if ($existingProcess) {
    Write-Host "[WARNING] Real-time backup is already running (PID: $($existingProcess.Id))" -ForegroundColor Yellow
    $restart = Read-Host "Restart it? (y/N)"
    if ($restart -eq "y") {
        Stop-Process -Id $existingProcess.Id -Force
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Keeping existing process running" -ForegroundColor Yellow
        exit 0
    }
}

if ($InstallService) {
    # Install as Windows Service (requires NSSM or similar)
    Write-Host "[INFO] Service installation requires additional setup" -ForegroundColor Yellow
    Write-Host "For now, starting as background process..." -ForegroundColor Yellow
}

# Start as background process
Write-Host "Starting real-time backup in background..." -ForegroundColor Yellow

$job = Start-Job -ScriptBlock {
    param($script, $backupDir)
    & $script -RealtimeBackupDir $backupDir -Quiet
} -ArgumentList $scriptPath, $RealtimeBackupDir

Write-Host "[OK] Real-time backup started (Job ID: $($job.Id))" -ForegroundColor Green
Write-Host "`nTo check status:" -ForegroundColor Cyan
Write-Host "  Get-Job -Id $($job.Id)" -ForegroundColor Gray
Write-Host "`nTo view output:" -ForegroundColor Cyan
Write-Host "  Receive-Job -Id $($job.Id)" -ForegroundColor Gray
Write-Host "`nTo stop:" -ForegroundColor Cyan
Write-Host "  .\scripts\realtime_backup.ps1 -Stop" -ForegroundColor Gray
Write-Host "  or" -ForegroundColor Gray
Write-Host "  Stop-Job -Id $($job.Id)" -ForegroundColor Gray

# Save job ID for easy access
$jobIdFile = Join-Path $PSScriptRoot "realtime_backup_job.txt"
$job.Id | Out-File -FilePath $jobIdFile -Encoding UTF8

