<# 
SOC Chat App - "3 backups" helper

Creates a single timestamped backup folder containing:
  1) MongoDB logical backup (mongodump archive)
  2) MongoDB file-level backup (copy of dbPath folder)
  3) App files backup (uploads + .env files)

IMPORTANT: This backup contains secrets (e.g. .env). Store it securely and do NOT commit it to git.
#>

[CmdletBinding()]
param(
  [string]$BackupRoot = "D:\soc-chat-backups",
  [string]$MongoUri = "mongodb://127.0.0.1:27017/soc_chat_app",
  [string]$MongoDbPath = "D:\soc-chat-data\MongoDB\data\db",
  [string]$ProjectRoot = "C:\Users\Administrator\Documents\GitHub\soc-chat-app",
  [switch]$StopMongoForFileCopy = $true
)

$ErrorActionPreference = "Stop"

function Write-Section([string]$s) {
  Write-Host ""
  Write-Host ("=" * 80)
  Write-Host $s
  Write-Host ("=" * 80)
}

function Try-Run([string]$label, [scriptblock]$fn) {
  try {
    & $fn
  } catch {
    Write-Warning "$label failed: $($_.Exception.Message)"
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $BackupRoot ("soc_chat_backup_" + $stamp)
$mongoDir = Join-Path $backupDir "1_mongodb_mongodump"
$mongoFileCopyDir = Join-Path $backupDir "2_mongodb_dbpath_copy"
$appFilesDir = Join-Path $backupDir "3_app_files"

New-Item -ItemType Directory -Force -Path $mongoDir, $mongoFileCopyDir, $appFilesDir | Out-Null

Write-Section "Backup target"
Write-Host "BackupRoot: $BackupRoot"
Write-Host "BackupDir:  $backupDir"

# -----------------------------------------------------------------------------
# Manifest / versions
# -----------------------------------------------------------------------------
Write-Section "Collecting versions (manifest)"
$manifestPath = Join-Path $backupDir "backup_manifest.txt"
$manifest = New-Object System.Collections.Generic.List[string]
$manifest.Add("SOC Chat App backup manifest")
$manifest.Add("Timestamp: $stamp")
$manifest.Add("ProjectRoot: $ProjectRoot")
$manifest.Add("")

Try-Run "OS info" {
  $os = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber | Format-List | Out-String).Trim()
  $manifest.Add("OS:")
  $manifest.Add($os)
  $manifest.Add("")
}

foreach ($cmd in @("git","node","npm","docker","ollama","mongod","mongodump")) {
  Try-Run "$cmd version" {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($c) {
      $src = $c.Source
      if (-not $src) { $src = $c.Path }
      $manifest.Add(($cmd + ": " + $src))
      $out = & $cmd --version 2>&1
      if (-not $out) { $out = & $cmd -v 2>&1 }
      if ($out) {
        $manifest.Add(($out | Out-String).Trim())
      }
      $manifest.Add("")
    }
  }
}

$manifest | Set-Content -Encoding UTF8 -Path $manifestPath
Write-Host "Wrote: $manifestPath"

# -----------------------------------------------------------------------------
# 1) MongoDB logical backup (mongodump archive)
# -----------------------------------------------------------------------------
Write-Section "1/3 MongoDB logical backup (mongodump)"
$archivePath = Join-Path $mongoDir ("soc_chat_app_" + $stamp + ".archive.gz")
$fallbackExportDir = Join-Path $mongoDir ("json_export_" + $stamp)

$cmdInfo = Get-Command mongodump -ErrorAction SilentlyContinue
$mongodumpCmd = $null
if ($cmdInfo) {
  $mongodumpCmd = $cmdInfo.Source
  if (-not $mongodumpCmd) { $mongodumpCmd = $cmdInfo.Path }
}
if (-not $mongodumpCmd) {
  $candidate = "C:\Program Files\MongoDB\Server\6.0\bin\mongodump.exe"
  if (Test-Path $candidate) { $mongodumpCmd = $candidate }
}

if ($mongodumpCmd) {
  Write-Host "Using mongodump: $mongodumpCmd"
  Write-Host "URI: $MongoUri"
  Write-Host "Archive: $archivePath"
  & $mongodumpCmd "--uri=$MongoUri" "--archive=$archivePath" "--gzip" | Out-Host
  Write-Host "OK: created $archivePath"
} else {
  Write-Warning "mongodump not found. Using fallback JSON export instead (slower + restore is manual)."
  $exportScript = Join-Path $ProjectRoot "scripts\run\mongo_export_json.js"
  if (-not (Test-Path $exportScript)) {
    throw "Fallback exporter script not found: $exportScript"
  }
  New-Item -ItemType Directory -Force -Path $fallbackExportDir | Out-Null
  Write-Host "Running fallback export:"
  Write-Host "  Script: $exportScript"
  Write-Host "  URI:    $MongoUri"
  Write-Host "  Out:    $fallbackExportDir"
  $prevNodePath = $env:NODE_PATH
  try {
    # mongodb driver is installed under servers\node_modules in this repo
    $env:NODE_PATH = Join-Path $ProjectRoot "servers\node_modules"
    & node $exportScript --uri $MongoUri --out $fallbackExportDir | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "JSON export failed (node exit code $LASTEXITCODE)."
    }
    Write-Host "OK: JSON export completed: $fallbackExportDir"
  } finally {
    $env:NODE_PATH = $prevNodePath
  }
}

# -----------------------------------------------------------------------------
# 2) MongoDB file-level backup (dbPath copy)
# -----------------------------------------------------------------------------
Write-Section "2/3 MongoDB file-level backup (copy dbPath)"
if (-not (Test-Path $MongoDbPath)) {
  throw "MongoDbPath does not exist: $MongoDbPath"
}

Write-Host "Copying dbPath:"
Write-Host "  From: $MongoDbPath"
Write-Host "  To:   $mongoFileCopyDir"

# Use robocopy for large directories (robust on Windows)
# Exit codes: 0-7 success, >=8 failure.
$robolog = Join-Path $backupDir "robocopy_mongodb_dbpath_copy.log"
$rcArgs = @(
  "`"$MongoDbPath`"",
  "`"$mongoFileCopyDir`"",
  "/E",
  "/COPY:DAT",
  "/DCOPY:DAT",
  "/R:2",
  "/W:2",
  "/NP",
  "/TEE",
  "/LOG:`"$robolog`""
)

if ($StopMongoForFileCopy) {
  Write-Warning "Stopping MongoDB service briefly for a consistent file-level backup..."
}

$mongoWasRunning = $false
try {
  if ($StopMongoForFileCopy) {
    $svc = Get-Service -Name MongoDB -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
      $mongoWasRunning = $true
      Stop-Service -Name MongoDB -Force -ErrorAction Stop
      Start-Sleep -Seconds 2
    }
  }

  $p = Start-Process -FilePath "robocopy.exe" -ArgumentList $rcArgs -Wait -PassThru
  if ($p.ExitCode -ge 8) {
    throw "Robocopy failed with exit code $($p.ExitCode). See: $robolog"
  }
  Write-Host "OK: dbPath copy completed (exit code $($p.ExitCode)). Log: $robolog"
} finally {
  if ($StopMongoForFileCopy -and $mongoWasRunning) {
    Write-Host "Starting MongoDB service again..."
    Start-Service -Name MongoDB -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
  }
}

# -----------------------------------------------------------------------------
# 3) App files backup (uploads + env)
# -----------------------------------------------------------------------------
Write-Section "3/3 App files backup (uploads + env)"

$pathsToCopy = @(
  (Join-Path $ProjectRoot "servers\local_api_server\.env"),
  (Join-Path $ProjectRoot "servers\.env.production"),
  (Join-Path $ProjectRoot "ngrok.yml"),
  (Join-Path $ProjectRoot "servers\local_api_server\uploads"),
  (Join-Path $ProjectRoot "servers\uploads")
)

foreach ($src in $pathsToCopy) {
  if (Test-Path $src) {
    $leaf = Split-Path -Leaf $src
    $dest = Join-Path $appFilesDir $leaf
    Write-Host "Copy: $src -> $dest"
    Copy-Item -Force -Recurse $src $dest
  } else {
    Write-Host "Skip (not found): $src"
  }
}

Write-Section "DONE"
Write-Host "Backup folder created:"
Write-Host "  $backupDir"
Write-Host ""
Write-Host "IMPORTANT: This backup contains secrets. Store it securely."

