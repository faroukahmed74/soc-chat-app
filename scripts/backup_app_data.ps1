# =============================================================================
# SOC Chat App - Complete Data Backup Script
# =============================================================================
# This script backs up:
#   1. MongoDB database (all collections)
#   2. Media files (uploads/chat_media)
#   3. Configuration files (.env)
#   4. Creates compressed archives with timestamps
# =============================================================================

param(
    [string]$BackupDir = "F:\soc-chat-backups",
    [switch]$Compress = $true,
    [switch]$FullBackup = $true,
    [int]$RetentionDays = 30,
    [switch]$Quiet = $false
)

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

# Create backup directory structure
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupName = "soc_chat_backup_$timestamp"
$backupPath = Join-Path $BackupDir $backupName

Write-Header "SOC Chat App - Data Backup"
Write-Info "Backup Name: $backupName"
Write-Info "Backup Path: $backupPath"
Write-Info "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Create backup directory
try {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Write-Success "Backup directory created: $backupPath"
} catch {
    Write-Error "Failed to create backup directory: $_"
    exit 1
}

# =============================================================================
# 1. BACKUP MONGODB DATABASE
# =============================================================================
Write-Header "Step 1: Backing up MongoDB Database"

$mongoBackupPath = Join-Path $backupPath "mongodb"
$mongoDataPath = "D:\soc-chat-data\MongoDB\data\db"
$mongoLogPath = "D:\soc-chat-data\MongoDB\log"

# Check if MongoDB is running
$mongoProcess = Get-Process -Name "mongod" -ErrorAction SilentlyContinue

if ($mongoProcess) {
    Write-Info "MongoDB is running - using mongodump"
    
    # Try to use mongodump (requires MongoDB tools)
    $mongodumpPath = "C:\Program Files\MongoDB\Server\6.0\bin\mongodump.exe"
    
    if (Test-Path $mongodumpPath) {
        try {
            New-Item -ItemType Directory -Path $mongoBackupPath -Force | Out-Null
            
            # MongoDB connection string
            $mongoUri = "mongodb://localhost:27017/soc_chat_app"
            
            Write-Info "Running mongodump..."
            & $mongodumpPath --uri=$mongoUri --out="$mongoBackupPath" --quiet
            
            if ($LASTEXITCODE -eq 0) {
                $dbSize = (Get-ChildItem $mongoBackupPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
                Write-Success "MongoDB backup completed: $([math]::Round($dbSize, 2)) MB"
            } else {
                Write-Error "mongodump failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Error "Failed to run mongodump: $_"
            Write-Info "Falling back to direct file copy..."
            $mongoProcess = $null  # Force file copy
        }
    } else {
        Write-Info "mongodump not found, using direct file copy..."
        $mongoProcess = $null  # Force file copy
    }
}

# Fallback: Direct file copy (if MongoDB is stopped or mongodump unavailable)
if (-not $mongoProcess) {
    Write-Info "Using direct file copy method (MongoDB should be stopped)"
    
    if (Test-Path $mongoDataPath) {
        try {
            New-Item -ItemType Directory -Path $mongoBackupPath -Force | Out-Null
            
            Write-Info "Copying MongoDB data files..."
            Copy-Item -Path $mongoDataPath -Destination (Join-Path $mongoBackupPath "data\db") -Recurse -Force
            
            if (Test-Path $mongoLogPath) {
                Copy-Item -Path $mongoLogPath -Destination (Join-Path $mongoBackupPath "log") -Recurse -Force
            }
            
            $dbSize = (Get-ChildItem $mongoBackupPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Success "MongoDB files copied: $([math]::Round($dbSize, 2)) MB"
        } catch {
            Write-Error "Failed to copy MongoDB files: $_"
        }
    } else {
        Write-Error "MongoDB data path not found: $mongoDataPath"
    }
}

# =============================================================================
# 2. BACKUP MEDIA FILES
# =============================================================================
Write-Header "Step 2: Backing up Media Files"

$mediaSourcePath = "D:\soc-chat-data\uploads"
$mediaBackupPath = Join-Path $backupPath "uploads"

if (Test-Path $mediaSourcePath) {
    try {
        Write-Info "Copying media files..."
        Copy-Item -Path $mediaSourcePath -Destination $mediaBackupPath -Recurse -Force
        
        $mediaSize = (Get-ChildItem $mediaBackupPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        $mediaCount = (Get-ChildItem $mediaBackupPath -Recurse -File).Count
        Write-Success "Media files backed up: $mediaCount files, $([math]::Round($mediaSize, 2)) MB"
    } catch {
        Write-Error "Failed to backup media files: $_"
    }
} else {
    Write-Error "Media source path not found: $mediaSourcePath"
}

# =============================================================================
# 3. BACKUP CONFIGURATION FILES
# =============================================================================
Write-Header "Step 3: Backing up Configuration Files"

$configBackupPath = Join-Path $backupPath "config"
New-Item -ItemType Directory -Path $configBackupPath -Force | Out-Null

# Backup .env file
$envFile = "servers\local_api_server\.env"
if (Test-Path $envFile) {
    Copy-Item -Path $envFile -Destination (Join-Path $configBackupPath ".env") -Force
    Write-Success "Configuration file backed up"
} else {
    Write-Info ".env file not found (may be filtered)"
}

# Create backup info file
$backupInfo = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    backupName = $backupName
    backupPath = $backupPath
    mongoDataPath = $mongoDataPath
    mediaSourcePath = $mediaSourcePath
    version = "1.0"
} | ConvertTo-Json -Depth 3

$backupInfo | Out-File -FilePath (Join-Path $backupPath "backup_info.json") -Encoding UTF8
Write-Success "Backup info file created"

# =============================================================================
# 4. COMPRESS BACKUP (OPTIONAL)
# =============================================================================
if ($Compress) {
    Write-Header "Step 4: Compressing Backup"
    
    $zipPath = "$backupPath.zip"
    Write-Info "Creating compressed archive..."
    
    try {
        # Use .NET compression for better compatibility
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($backupPath, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Success "Backup compressed: $([math]::Round($zipSize, 2)) MB"
        
        # Remove uncompressed folder
        Remove-Item -Path $backupPath -Recurse -Force
        Write-Info "Uncompressed folder removed"
        
        $finalBackupPath = $zipPath
    } catch {
        Write-Error "Compression failed: $_"
        Write-Info "Keeping uncompressed backup"
        $finalBackupPath = $backupPath
    }
} else {
    $finalBackupPath = $backupPath
}

# =============================================================================
# 5. CLEANUP OLD BACKUPS
# =============================================================================
Write-Header "Step 5: Cleaning up Old Backups"

$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
$oldBackups = Get-ChildItem -Path $BackupDir -Filter "soc_chat_backup_*" | Where-Object {
    $_.LastWriteTime -lt $cutoffDate
}

if ($oldBackups.Count -gt 0) {
    Write-Info "Found $($oldBackups.Count) old backup(s) to remove"
    $oldBackups | ForEach-Object {
        try {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Info "Removed: $($_.Name)"
        } catch {
            Write-Error "Failed to remove: $($_.Name)"
        }
    }
    Write-Success "Old backups cleaned up"
} else {
    Write-Info "No old backups to remove"
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Header "Backup Summary"

$totalSize = if (Test-Path $finalBackupPath) {
    if ((Get-Item $finalBackupPath).PSIsContainer) {
        (Get-ChildItem $finalBackupPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    } else {
        (Get-Item $finalBackupPath).Length / 1MB
    }
} else {
    0
}

Write-Success "Backup completed successfully!"
Write-Host "`nBackup Details:" -ForegroundColor Cyan
Write-Host "  Name: $backupName" -ForegroundColor White
Write-Host "  Location: $finalBackupPath" -ForegroundColor White
Write-Host "  Size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
Write-Host "  Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "`nTo restore this backup, run:" -ForegroundColor Yellow
Write-Host "  .\scripts\restore_app_data.ps1 -BackupPath `"$finalBackupPath`"" -ForegroundColor Gray

# Save backup path to file for easy access
$backupListFile = Join-Path $BackupDir "latest_backup.txt"
$finalBackupPath | Out-File -FilePath $backupListFile -Encoding UTF8

Write-Host "`nBackup process completed!" -ForegroundColor Green

