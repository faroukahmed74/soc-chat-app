# Restore from backup_3_items format (1_mongodb_mongodump, 2_mongodb_dbpath_copy, 3_app_files)
# Usage: .\restore_from_backup_3_items.ps1 -BackupPath "D:\soc-chat-backups\soc_chat_backup_20260131_110002"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "E:\GitHub\soc-chat-app"
$MongoDataPath = "D:\soc-chat-data\MongoDB\data\db"
$UploadsPath = "D:\soc-chat-data\uploads"

if (-not (Test-Path $BackupPath)) {
    Write-Host "ERROR: Backup path not found: $BackupPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SOC Chat App - Restore from backup_3_items" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Backup: $BackupPath" -ForegroundColor White

if (-not $Force) {
    Write-Host "`nWARNING: This will OVERWRITE existing MongoDB data and config!" -ForegroundColor Yellow
    $confirm = Read-Host "Type YES to continue"
    if ($confirm -ne "YES") {
        Write-Host "Restore cancelled." -ForegroundColor Gray
        exit 0
    }
}

# 1. Stop MongoDB
Write-Host "`n[1/4] Stopping MongoDB..." -ForegroundColor Cyan
$mongoStopped = $false
$svc = Get-Service -Name MongoDB -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Stop-Service -Name MongoDB -Force -ErrorAction SilentlyContinue
    $mongoStopped = $true
    Start-Sleep -Seconds 3
}
# Also stop any mongod process
Get-Process -Name mongod -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 2. Restore MongoDB dbpath
Write-Host "[2/4] Restoring MongoDB data..." -ForegroundColor Cyan
$sourceDb = Join-Path $BackupPath "2_mongodb_dbpath_copy"
if (-not (Test-Path $sourceDb)) {
    Write-Host "ERROR: 2_mongodb_dbpath_copy not found in backup" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path $MongoDataPath) | Out-Null
if (Test-Path $MongoDataPath) {
    $backupCurrent = "$MongoDataPath.before_restore_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "  Backing up current data to: $backupCurrent" -ForegroundColor Gray
    Move-Item -Path $MongoDataPath -Destination $backupCurrent -Force
}
Copy-Item -Path $sourceDb -Destination $MongoDataPath -Recurse -Force
Write-Host "  OK: MongoDB data restored" -ForegroundColor Green

# 3. Restore config
Write-Host "[3/4] Restoring config files..." -ForegroundColor Cyan
$appFiles = Join-Path $BackupPath "3_app_files"
if (Test-Path (Join-Path $appFiles ".env")) {
    $destEnv = Join-Path $ProjectRoot "servers\local_api_server\.env"
    Copy-Item -Path (Join-Path $appFiles ".env") -Destination $destEnv -Force
    Write-Host "  OK: .env restored" -ForegroundColor Green
}
if (Test-Path (Join-Path $appFiles ".env.production")) {
    $destEnvProd = Join-Path $ProjectRoot "servers\.env.production"
    Copy-Item -Path (Join-Path $appFiles ".env.production") -Destination $destEnvProd -Force
    Write-Host "  OK: .env.production restored" -ForegroundColor Green
}

# 4. Restore uploads (if in backup)
$uploadsBackup = Join-Path $appFiles "uploads"
if (Test-Path $uploadsBackup) {
    Write-Host "[4/4] Restoring uploads..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $UploadsPath | Out-Null
    Copy-Item -Path "$uploadsBackup\*" -Destination $UploadsPath -Recurse -Force
    Write-Host "  OK: Uploads restored" -ForegroundColor Green
} else {
    Write-Host "[4/4] No uploads in backup (skipped)" -ForegroundColor Gray
}

# 5. Start MongoDB
if ($mongoStopped) {
    Write-Host "`nStarting MongoDB service..." -ForegroundColor Cyan
    Start-Service -Name MongoDB -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  RESTORE COMPLETED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNext: Restart API server (services_manager option 1)" -ForegroundColor White
