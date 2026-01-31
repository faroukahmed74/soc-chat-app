# =============================================================================
# SOC Chat App - Real-Time Backup Script
# =============================================================================
# This script monitors data directories and backs up changes in real-time
# Uses FileSystemWatcher to detect file changes and sync immediately
# =============================================================================

param(
    [string]$RealtimeBackupDir = "F:\soc-chat-realtime",
    [switch]$Quiet = $false,
    [switch]$Stop = $false
)

# Check if stopping
if ($Stop) {
    $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -like "*realtime_backup.ps1*" -and $_.ProcessId -ne $PID }
    if ($procs) {
        foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
        Write-Host "[OK] Real-time backup stopped" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No real-time backup process found" -ForegroundColor Yellow
    }
    exit 0
}

# Colors for output
function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[INFO] $Message" -ForegroundColor Yellow
    }
}

Write-Header "SOC Chat App - Real-Time Backup Service"
Write-Info "Real-Time Backup Directory: $RealtimeBackupDir"
Write-Info "Press Ctrl+C to stop"

# Create backup directory structure
try {
    New-Item -ItemType Directory -Path $RealtimeBackupDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $RealtimeBackupDir "MongoDB\data\db") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $RealtimeBackupDir "uploads") -Force | Out-Null
    Write-Success "Real-time backup directory ready"
} catch {
    Write-Error "Failed to create backup directory: $_"
    exit 1
}

# Initial sync (copy everything first)
Write-Header "Initial Sync - Copying All Data"

$mongoSource = "D:\soc-chat-data\MongoDB\data\db"
$mongoDest = Join-Path $RealtimeBackupDir "MongoDB\data\db"
$mediaSource = "D:\soc-chat-data\uploads"
$mediaDest = Join-Path $RealtimeBackupDir "uploads"

# Initial MongoDB sync
if (Test-Path $mongoSource) {
    Write-Info "Initial MongoDB sync..."
    $robocopyArgs = @(
        "`"$mongoSource`"",
        "`"$mongoDest`"",
        "/E",
        "/R:1",
        "/W:1",
        "/NP",
        "/NDL",
        "/NFL"
    )
    & robocopy @robocopyArgs | Out-Null
    Write-Success "MongoDB initial sync completed"
}

# Initial media sync
if (Test-Path $mediaSource) {
    Write-Info "Initial media sync..."
    $robocopyArgs = @(
        "`"$mediaSource`"",
        "`"$mediaDest`"",
        "/E",
        "/R:1",
        "/W:1",
        "/NP",
        "/NDL",
        "/NFL"
    )
    & robocopy @robocopyArgs | Out-Null
    Write-Success "Media initial sync completed"
}

Write-Header "Real-Time Monitoring Started"

# Function to sync file/directory
function Sync-Item {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$ChangeType
    )
    
    try {
        $relativePath = $SourcePath.Replace($mongoSource, "").Replace($mediaSource, "").TrimStart("\")
        
        if ($ChangeType -eq "Deleted") {
            # File was deleted, remove from backup
            if (Test-Path $DestPath) {
                Remove-Item -Path $DestPath -Recurse -Force -ErrorAction SilentlyContinue
                if (-not $Quiet) {
                    Write-Info "Deleted: $relativePath"
                }
            }
        } elseif ($ChangeType -eq "Created" -or $ChangeType -eq "Changed") {
            # File was created or changed, sync it
            if (Test-Path $SourcePath) {
                $destDir = Split-Path $DestPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                if (Test-Path $SourcePath -PathType Container) {
                    # It's a directory
                    $robocopyArgs = @(
                        "`"$SourcePath`"",
                        "`"$DestPath`"",
                        "/E",
                        "/R:1",
                        "/W:1",
                        "/NP",
                        "/NDL",
                        "/NFL"
                    )
                    & robocopy @robocopyArgs | Out-Null
                } else {
                    # It's a file
                    Copy-Item -Path $SourcePath -Destination $DestPath -Force -ErrorAction SilentlyContinue
                }
                
                if (-not $Quiet) {
                    Write-Info "Synced: $relativePath ($ChangeType)"
                }
            }
        }
    } catch {
        # Silently handle errors to avoid spam
    }
}

# Create FileSystemWatcher for MongoDB
$mongoWatcher = New-Object System.IO.FileSystemWatcher
$mongoWatcher.Path = $mongoSource
$mongoWatcher.IncludeSubdirectories = $true
$mongoWatcher.EnableRaisingEvents = $true
$mongoWatcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor 
                             [System.IO.NotifyFilters]::DirectoryName -bor 
                             [System.IO.NotifyFilters]::LastWrite

# Create FileSystemWatcher for Media
$mediaWatcher = New-Object System.IO.FileSystemWatcher
$mediaWatcher.Path = $mediaSource
$mediaWatcher.IncludeSubdirectories = $true
$mediaWatcher.EnableRaisingEvents = $true
$mediaWatcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor 
                             [System.IO.NotifyFilters]::DirectoryName -bor 
                             [System.IO.NotifyFilters]::LastWrite

# Event handlers for MongoDB
$mongoCreated = Register-ObjectEvent -InputObject $mongoWatcher -EventName "Created" -Action {
    $sourcePath = $Event.SourceEventArgs.FullPath
    $relativePath = $sourcePath.Replace($mongoSource, "").TrimStart("\")
    $destPath = Join-Path $mongoDest $relativePath
    Sync-Item -SourcePath $sourcePath -DestPath $destPath -ChangeType "Created"
}

$mongoChanged = Register-ObjectEvent -InputObject $mongoWatcher -EventName "Changed" -Action {
    $sourcePath = $Event.SourceEventArgs.FullPath
    $relativePath = $sourcePath.Replace($mongoSource, "").TrimStart("\")
    $destPath = Join-Path $mongoDest $relativePath
    Sync-Item -SourcePath $sourcePath -DestPath $destPath -ChangeType "Changed"
}

$mongoDeleted = Register-ObjectEvent -InputObject $mongoWatcher -EventName "Deleted" -Action {
    $sourcePath = $Event.SourceEventArgs.FullPath
    $relativePath = $sourcePath.Replace($mongoSource, "").TrimStart("\")
    $destPath = Join-Path $mongoDest $relativePath
    Sync-Item -SourcePath $sourcePath -DestPath $destPath -ChangeType "Deleted"
}

# Event handlers for Media
$mediaCreated = Register-ObjectEvent -InputObject $mediaWatcher -EventName "Created" -Action {
    $sourcePath = $Event.SourceEventArgs.FullPath
    $relativePath = $sourcePath.Replace($mediaSource, "").TrimStart("\")
    $destPath = Join-Path $mediaDest $relativePath
    Sync-Item -SourcePath $sourcePath -DestPath $destPath -ChangeType "Created"
}

$mediaChanged = Register-ObjectEvent -InputObject $mediaWatcher -EventName "Changed" -Action {
    $sourcePath = $Event.SourceEventArgs.FullPath
    $relativePath = $sourcePath.Replace($mediaSource, "").TrimStart("\")
    $destPath = Join-Path $mediaDest $relativePath
    Sync-Item -SourcePath $sourcePath -DestPath $destPath -ChangeType "Changed"
}

$mediaDeleted = Register-ObjectEvent -InputObject $mediaWatcher -EventName "Deleted" -Action {
    $sourcePath = $Event.SourceEventArgs.FullPath
    $relativePath = $sourcePath.Replace($mediaSource, "").TrimStart("\")
    $destPath = Join-Path $mediaDest $relativePath
    Sync-Item -SourcePath $sourcePath -DestPath $destPath -ChangeType "Deleted"
}

# Create status file
$statusFile = Join-Path $RealtimeBackupDir "realtime_status.json"

function Update-Status {
    $status = @{
        running = $true
        startTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        mongoSource = $mongoSource
        mediaSource = $mediaSource
        backupDir = $RealtimeBackupDir
    } | ConvertTo-Json
    $status | Out-File -FilePath $statusFile -Encoding UTF8
}

Update-Status
Write-Success "Real-time backup monitoring active"
Write-Info "Watching: $mongoSource"
Write-Info "Watching: $mediaSource"
Write-Info "Backup: $RealtimeBackupDir"
Write-Host "`n[Press Ctrl+C to stop]`n" -ForegroundColor Yellow

# Keep script running
try {
    while ($true) {
        Start-Sleep -Seconds 60
        Update-Status
        
        # Periodic full sync check (every hour) to catch any missed changes
        $lastFullSync = Get-Content (Join-Path $RealtimeBackupDir "last_full_sync.txt") -ErrorAction SilentlyContinue
        $now = Get-Date
        $shouldSync = $true
        
        if ($lastFullSync) {
            $lastSyncTime = [DateTime]::Parse($lastFullSync)
            if (($now - $lastSyncTime).TotalHours -lt 1) {
                $shouldSync = $false
            }
        }
        
        if ($shouldSync) {
            Write-Info "Running periodic sync check..."
            
            # Quick sync check using robocopy
            $robocopyArgs = @(
                "`"$mongoSource`"",
                "`"$mongoDest`"",
                "/E",
                "/R:1",
                "/W:1",
                "/NP",
                "/NDL",
                "/NFL"
            )
            & robocopy @robocopyArgs | Out-Null
            
            $robocopyArgs = @(
                "`"$mediaSource`"",
                "`"$mediaDest`"",
                "/E",
                "/R:1",
                "/W:1",
                "/NP",
                "/NDL",
                "/NFL"
            )
            & robocopy @robocopyArgs | Out-Null
            
            $now.ToString("yyyy-MM-dd HH:mm:ss") | Out-File -FilePath (Join-Path $RealtimeBackupDir "last_full_sync.txt") -Encoding UTF8
        }
    }
} finally {
    # Cleanup
    Unregister-Event -SourceIdentifier $mongoCreated.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $mongoChanged.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $mongoDeleted.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $mediaCreated.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $mediaChanged.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $mediaDeleted.Name -ErrorAction SilentlyContinue
    
    $mongoWatcher.Dispose()
    $mediaWatcher.Dispose()
    
    $status = @{
        running = $false
        stopTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json
    $status | Out-File -FilePath $statusFile -Encoding UTF8
    
    Write-Host "`n[OK] Real-time backup stopped" -ForegroundColor Green
}

