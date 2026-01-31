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

$args = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", "`"$scriptPath`"",
  "-RealtimeBackupDir", "`"$RealtimeBackupDir`"",
  "-Quiet"
)
$proc = Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden -PassThru

Write-Host "[OK] Real-time backup started (PID: $($proc.Id))" -ForegroundColor Green
Write-Host "`nTo check status:" -ForegroundColor Cyan
Write-Host "  Get-Content `"F:\soc-chat-realtime\realtime_status.json`"" -ForegroundColor Gray
Write-Host "`nTo stop:" -ForegroundColor Cyan
Write-Host "  .\scripts\realtime_backup.ps1 -Stop" -ForegroundColor Gray

# Save PID for easy access
$pidFile = Join-Path $PSScriptRoot "realtime_backup_pid.txt"
$proc.Id | Out-File -FilePath $pidFile -Encoding UTF8

