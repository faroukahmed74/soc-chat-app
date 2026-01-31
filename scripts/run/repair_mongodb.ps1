<#
SOC Chat App - MongoDB Repair Helper (Windows)

WHY YOU NEED THIS
- Your MongoDB service is failing to start due to WiredTiger corruption.
- This script makes a safety copy of the db folder, then runs: mongod --repair

DEFAULT PATHS (match this repo)
- mongod.exe: C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe
- dbPath:    D:\soc-chat-data\MongoDB\data\db
- logDir:    D:\soc-chat-data\MongoDB\log

WARNING
`--repair` can recover a broken database, but it MAY lose some data.
If you have a recent backup (mongodump or file backup), restoring is safer.
#>

param(
  [string]$MongoBin = "C:\Program Files\MongoDB\Server\6.0\bin",
  [string]$DbPath   = "D:\soc-chat-data\MongoDB\data\db",
  [string]$LogDir   = "D:\soc-chat-data\MongoDB\log",
  [switch]$SkipBackup,
  [switch]$DoNotStartService
)

$ErrorActionPreference = "Stop"

$mongod = Join-Path $MongoBin "mongod.exe"
if (!(Test-Path $mongod)) { throw "mongod.exe not found at: $mongod" }
if (!(Test-Path $DbPath)) { throw "MongoDB dbPath not found: $DbPath" }
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host "Stopping MongoDB service (if installed)..."
try {
  $svc = Get-Service -Name "MongoDB" -ErrorAction Stop
  if ($svc.Status -ne "Stopped") {
    Stop-Service -Name "MongoDB" -Force
    Start-Sleep -Seconds 2
  }
} catch {
  Write-Host "MongoDB service not found; continuing."
}

Write-Host "Stopping any mongod.exe processes..."
Get-Process mongod -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if (-not $SkipBackup) {
  $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $dbParent = Split-Path -Parent $DbPath            # ...\data
  $mongoRoot = Split-Path -Parent $dbParent         # ...\MongoDB
  $backupDir = Join-Path $mongoRoot ("data\\db_BACKUP_" + $timestamp)

  Write-Host "Creating backup copy of DB folder (this can take time)..."
  Write-Host "  From: $DbPath"
  Write-Host "  To:   $backupDir"

  New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

  # Robocopy exit codes: 0-7 success, >=8 failure.
  $p = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
    "`"$DbPath`"",
    "`"$backupDir`"",
    "/MIR",
    "/R:1",
    "/W:1",
    "/NFL",
    "/NDL"
  ) -Wait -PassThru

  if ($p.ExitCode -ge 8) {
    throw "Robocopy backup failed with exit code $($p.ExitCode)."
  }
}

$repairLog = Join-Path $LogDir "mongod_repair.log"
Write-Host "Running MongoDB repair..."
Write-Host "Repair log: $repairLog"

& $mongod --dbpath "$DbPath" --repair --logpath "$repairLog" --logappend

Write-Host "Repair finished."

if (-not $DoNotStartService) {
  Write-Host "Starting MongoDB service (if installed)..."
  try {
    Start-Service -Name "MongoDB"
    Start-Sleep -Seconds 2
    Get-Service -Name "MongoDB" | Select-Object Status,Name,DisplayName
  } catch {
    Write-Host "Could not start MongoDB service automatically. Start it manually, or run mongod directly."
  }
}

Write-Host "Done."

