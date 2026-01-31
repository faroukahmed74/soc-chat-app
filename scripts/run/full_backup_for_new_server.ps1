<#
SOC Chat App - Full backup for moving to a new PC/server

Creates a full copy to:
  F:\Full BackupForAppProject\soc_chat_full_backup_<timestamp>\

Includes:
  - Project source (repo) (excluding heavy caches/build outputs)
  - MongoDB dbPath + logs (file-level copy; MongoDB is stopped briefly)
  - Uploads/media folder (D:\soc-chat-data\uploads)
  - A manifest file + robocopy logs

IMPORTANT:
  - This backup contains SECRETS (e.g. .env). Store it securely.
  - Stopping MongoDB briefly will cause the API to show DB errors until MongoDB is restarted.
#>

[CmdletBinding()]
param(
  [string]$DestinationRoot = "F:\Full BackupForAppProject",
  [string]$ProjectRoot = "C:\Users\Administrator\Documents\GitHub\soc-chat-app",
  [string]$MongoDbPath = "D:\soc-chat-data\MongoDB\data\db",
  [string]$MongoLogPath = "D:\soc-chat-data\MongoDB\log",
  [string]$UploadsPath = "D:\soc-chat-data\uploads",
  [switch]$StopMongoForCopy = $true
)

$ErrorActionPreference = "Stop"

function Write-Section([string]$s) {
  Write-Host ""
  Write-Host ("=" * 90)
  Write-Host $s
  Write-Host ("=" * 90)
}

function Ensure-Dir([string]$p) {
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}

function Robocopy-Dir {
  param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Dest,
    [Parameter(Mandatory=$true)][string]$LogPath,
    [string[]]$ExtraArgs = @()
  )

  Ensure-Dir $Dest

  $args = @(
    "`"$Source`"",
    "`"$Dest`"",
    "/E",
    "/COPY:DAT",
    "/DCOPY:DAT",
    "/R:2",
    "/W:2",
    "/NP",
    "/TEE",
    "/LOG:`"$LogPath`""
  ) + $ExtraArgs

  $p = Start-Process -FilePath "robocopy.exe" -ArgumentList $args -Wait -PassThru
  # Robocopy exit codes: 0-7 success, >=8 failure
  if ($p.ExitCode -ge 8) {
    throw "Robocopy failed (exit code $($p.ExitCode)). See log: $LogPath"
  }
  return $p.ExitCode
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupRoot = Join-Path $DestinationRoot ("soc_chat_full_backup_" + $stamp)

$dirProject = Join-Path $backupRoot "project"
$dirData = Join-Path $backupRoot "data"
$dirMongo = Join-Path $dirData "mongodb"
$dirUploads = Join-Path $dirData "uploads"
$dirLogs = Join-Path $backupRoot "logs"

Ensure-Dir $DestinationRoot
Ensure-Dir $backupRoot
Ensure-Dir $dirProject
Ensure-Dir $dirMongo
Ensure-Dir $dirUploads
Ensure-Dir $dirLogs

Write-Section "Backup target"
Write-Host "DestinationRoot: $DestinationRoot"
Write-Host "BackupRoot:      $backupRoot"
Write-Host "ProjectRoot:     $ProjectRoot"
Write-Host "MongoDbPath:     $MongoDbPath"
Write-Host "MongoLogPath:    $MongoLogPath"
Write-Host "UploadsPath:     $UploadsPath"

# -------------------------------------------------------------------------
# Manifest (versions + paths)
# -------------------------------------------------------------------------
Write-Section "Writing manifest"
$manifestPath = Join-Path $backupRoot "MANIFEST.txt"
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("SOC Chat App - Full Backup Manifest")
$lines.Add("Timestamp: $stamp")
$lines.Add("BackupRoot: $backupRoot")
$lines.Add("")
$lines.Add("Included:")
$lines.Add("- project (repo working copy)")
$lines.Add("- MongoDB dbPath + logs (file copy)")
$lines.Add("- uploads/media")
$lines.Add("")
$lines.Add("WARNING: This backup may contain secrets (.env). Keep it private.")
$lines.Add("")

try {
  $os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber
  $lines.Add("OS: $($os.Caption) | Version=$($os.Version) | Build=$($os.BuildNumber)")
} catch {}

foreach ($cmd in @("git","node","npm","docker","ollama")) {
  try {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($c) {
      $ver = & $cmd --version 2>&1
      if (-not $ver) { $ver = & $cmd -v 2>&1 }
      $src = $c.Source
      if (-not $src) { $src = $c.Path }
      $lines.Add(($cmd + ": " + $src))
      if ($ver) { $lines.Add(($ver | Out-String).Trim()) }
      $lines.Add("")
    }
  } catch {}
}

$lines.Add("Restore notes:")
$lines.Add("- Copy project folder to new server (or clone repo).")
$lines.Add("- Restore MongoDB by copying dbPath (when MongoDB is STOPPED) OR use mongodump/mongorestore if available.")
$lines.Add("- Restore uploads/media folder.")
$lines.Add("- Copy .env files into place and then start services.")
$lines.Add("")

$lines | Set-Content -Encoding UTF8 -Path $manifestPath
Write-Host "Wrote: $manifestPath"

# -------------------------------------------------------------------------
# 1) Project copy (exclude heavy caches/build outputs)
# -------------------------------------------------------------------------
Write-Section "1/3 Copying project"
if (-not (Test-Path $ProjectRoot)) { throw "ProjectRoot not found: $ProjectRoot" }

$logProject = Join-Path $dirLogs "robocopy_project.log"
$excludeDirs = @(
  # Flutter
  ".dart_tool",
  ".pub-cache",
  "build",
  "build\\web",
  # Node
  "node_modules",
  "servers\\node_modules",
  "servers\\dist",
  "servers\\build",
  # IDE / misc
  ".vscode",
  ".idea"
)

$extra = @()
foreach ($d in $excludeDirs) { $extra += @("/XD", "`"$d`"") }

# Copy the whole repo working tree
$rc = Robocopy-Dir -Source $ProjectRoot -Dest $dirProject -LogPath $logProject -ExtraArgs $extra
Write-Host "OK: Project copied (robocopy exit code $rc)."

# -------------------------------------------------------------------------
# 2) MongoDB data copy (stop MongoDB briefly for consistency)
# -------------------------------------------------------------------------
Write-Section "2/3 Copying MongoDB data"
if (-not (Test-Path $MongoDbPath)) { throw "MongoDbPath not found: $MongoDbPath" }

$mongoWasRunning = $false
try {
  if ($StopMongoForCopy) {
    $svc = Get-Service -Name MongoDB -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
      $mongoWasRunning = $true
      Write-Host "Stopping MongoDB service briefly..."
      Stop-Service -Name MongoDB -Force -ErrorAction Stop
      Start-Sleep -Seconds 2
    }
  }

  $logMongo = Join-Path $dirLogs "robocopy_mongodb_dbpath.log"
  $destDb = Join-Path $dirMongo "data\\db"
  $rc2 = Robocopy-Dir -Source $MongoDbPath -Dest $destDb -LogPath $logMongo
  Write-Host "OK: MongoDB dbPath copied (robocopy exit code $rc2)."

  if (Test-Path $MongoLogPath) {
    $logMongoLogs = Join-Path $dirLogs "robocopy_mongodb_logs.log"
    $destLogs = Join-Path $dirMongo "log"
    $rc3 = Robocopy-Dir -Source $MongoLogPath -Dest $destLogs -LogPath $logMongoLogs
    Write-Host "OK: MongoDB logs copied (robocopy exit code $rc3)."
  } else {
    Write-Host "Skip: MongoLogPath not found: $MongoLogPath"
  }

  # Sanity checks
  $wt = Join-Path $destDb "WiredTiger.wt"
  if (-not (Test-Path $wt)) {
    Write-Warning "MongoDB backup may be incomplete (missing WiredTiger.wt): $wt"
  }
} finally {
  if ($StopMongoForCopy -and $mongoWasRunning) {
    Write-Host "Starting MongoDB service again..."
    Start-Service -Name MongoDB -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
  }
}

# -------------------------------------------------------------------------
# 3) Uploads/media copy
# -------------------------------------------------------------------------
Write-Section "3/3 Copying uploads/media"
if (Test-Path $UploadsPath) {
  $logUploads = Join-Path $dirLogs "robocopy_uploads.log"
  $rc4 = Robocopy-Dir -Source $UploadsPath -Dest $dirUploads -LogPath $logUploads
  Write-Host "OK: Uploads copied (robocopy exit code $rc4)."
} else {
  Write-Host "Skip: UploadsPath not found: $UploadsPath"
}

Write-Section "DONE"
Write-Host "Full backup created at:"
Write-Host "  $backupRoot"
Write-Host ""
Write-Host "Next step on new server:"
Write-Host "  1) Copy the backup folder"
Write-Host "  2) Restore MongoDB dbPath while MongoDB is STOPPED"
Write-Host "  3) Restore uploads"
Write-Host "  4) Run services_manager.bat (or start services manually)"

