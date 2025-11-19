# =============================================================================
# SOC Chat App - Data Restore Script
# =============================================================================
# This script restores:
#   1. MongoDB database
#   2. Media files
#   3. Configuration files
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    [switch]$RestoreMongoDB = $true,
    [switch]$RestoreMedia = $true,
    [switch]$RestoreConfig = $true,
    [switch]$Force = $false
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
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Yellow
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

# Validate backup path
if (-not (Test-Path $BackupPath)) {
    Write-Error "Backup path not found: $BackupPath"
    exit 1
}

Write-Header "SOC Chat App - Data Restore"
Write-Info "Backup Path: $BackupPath"

# Check if backup is compressed
$backupDir = $BackupPath
if ($BackupPath.EndsWith(".zip")) {
    Write-Info "Backup is compressed, extracting..."
    $extractPath = $BackupPath -replace "\.zip$", "_extracted"
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($BackupPath, $extractPath)
        $backupDir = $extractPath
        Write-Success "Backup extracted to: $extractPath"
    } catch {
        Write-Error "Failed to extract backup: $_"
        exit 1
    }
}

# Read backup info
$backupInfoPath = Join-Path $backupDir "backup_info.json"
if (Test-Path $backupInfoPath) {
    $backupInfo = Get-Content $backupInfoPath | ConvertFrom-Json
    Write-Info "Backup created: $($backupInfo.timestamp)"
}

# Confirmation
if (-not $Force) {
    Write-Warning "WARNING: This will overwrite existing data!"
    Write-Warning "Make sure you have a current backup before proceeding."
    $confirm = Read-Host "Type 'YES' to continue"
    if ($confirm -ne "YES") {
        Write-Info "Restore cancelled"
        exit 0
    }
}

# =============================================================================
# 1. RESTORE MONGODB DATABASE
# =============================================================================
if ($RestoreMongoDB) {
    Write-Header "Step 1: Restoring MongoDB Database"
    
    $mongoBackupPath = Join-Path $backupDir "mongodb"
    $mongoDataPath = "D:\soc-chat-data\MongoDB\data\db"
    
    if (-not (Test-Path $mongoBackupPath)) {
        Write-Error "MongoDB backup not found in: $mongoBackupPath"
    } else {
        # Check if MongoDB is running
        $mongoProcess = Get-Process -Name "mongod" -ErrorAction SilentlyContinue
        
        if ($mongoProcess) {
            Write-Warning "MongoDB is running. Please stop MongoDB before restoring."
            Write-Info "Run: Stop-Service MongoDB (or stop mongod process)"
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne "y") {
                Write-Info "MongoDB restore skipped"
            } else {
                # Try to use mongorestore
                $mongorestorePath = "C:\Program Files\MongoDB\Server\6.0\bin\mongorestore.exe"
                
                if (Test-Path $mongorestorePath) {
                    try {
                        $mongoUri = "mongodb://localhost:27017/soc_chat_app"
                        Write-Info "Running mongorestore..."
                        & $mongorestorePath --uri=$mongoUri --dir="$mongoBackupPath" --drop
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "MongoDB restored successfully"
                        } else {
                            Write-Error "mongorestore failed"
                        }
                    } catch {
                        Write-Error "Failed to run mongorestore: $_"
                    }
                } else {
                    Write-Error "mongorestore not found. Please restore manually."
                }
            }
        } else {
            # MongoDB is stopped - direct file copy
            Write-Info "MongoDB is stopped - using direct file copy"
            
            try {
                # Backup current data first
                $currentBackup = "$mongoDataPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                if (Test-Path $mongoDataPath) {
                    Write-Info "Backing up current MongoDB data to: $currentBackup"
                    Copy-Item -Path $mongoDataPath -Destination $currentBackup -Recurse -Force
                }
                
                # Restore from backup
                Write-Info "Restoring MongoDB data..."
                $sourcePath = Join-Path $mongoBackupPath "data\db"
                if (Test-Path $sourcePath) {
                    Remove-Item -Path $mongoDataPath -Recurse -Force -ErrorAction SilentlyContinue
                    Copy-Item -Path $sourcePath -Destination $mongoDataPath -Recurse -Force
                    Write-Success "MongoDB data restored"
                } else {
                    # Try mongodump format
                    $dumpPath = Join-Path $mongoBackupPath "soc_chat_app"
                    if (Test-Path $dumpPath) {
                        Write-Info "Found mongodump format, use mongorestore when MongoDB is running"
                    }
                }
            } catch {
                Write-Error "Failed to restore MongoDB: $_"
            }
        }
    }
}

# =============================================================================
# 2. RESTORE MEDIA FILES
# =============================================================================
if ($RestoreMedia) {
    Write-Header "Step 2: Restoring Media Files"
    
    $mediaBackupPath = Join-Path $backupDir "uploads"
    $mediaTargetPath = "D:\soc-chat-data\uploads"
    
    if (-not (Test-Path $mediaBackupPath)) {
        Write-Error "Media backup not found in: $mediaBackupPath"
    } else {
        try {
            # Backup current media
            if (Test-Path $mediaTargetPath) {
                $currentBackup = "$mediaTargetPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Write-Info "Backing up current media to: $currentBackup"
                Copy-Item -Path $mediaTargetPath -Destination $currentBackup -Recurse -Force
            }
            
            # Restore media
            Write-Info "Restoring media files..."
            Copy-Item -Path $mediaBackupPath -Destination $mediaTargetPath -Recurse -Force
            
            $mediaCount = (Get-ChildItem $mediaTargetPath -Recurse -File).Count
            Write-Success "Media files restored: $mediaCount files"
        } catch {
            Write-Error "Failed to restore media files: $_"
        }
    }
}

# =============================================================================
# 3. RESTORE CONFIGURATION
# =============================================================================
if ($RestoreConfig) {
    Write-Header "Step 3: Restoring Configuration Files"
    
    $configBackupPath = Join-Path $backupDir "config"
    $configTargetPath = "servers\local_api_server\.env"
    
    if (Test-Path (Join-Path $configBackupPath ".env")) {
        try {
            # Backup current config
            if (Test-Path $configTargetPath) {
                $currentBackup = "$configTargetPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item -Path $configTargetPath -Destination $currentBackup -Force
            }
            
            # Restore config
            Copy-Item -Path (Join-Path $configBackupPath ".env") -Destination $configTargetPath -Force
            Write-Success "Configuration file restored"
        } catch {
            Write-Error "Failed to restore configuration: $_"
        }
    } else {
        Write-Info "No configuration backup found"
    }
}

# Cleanup extracted backup if it was compressed
if ($backupDir -ne $BackupPath -and $backupDir.EndsWith("_extracted")) {
    Write-Info "Cleaning up extracted files..."
    Remove-Item -Path $backupDir -Recurse -Force
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Header "Restore Summary"

Write-Success "Restore completed!"
Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Restart MongoDB service (if stopped)" -ForegroundColor White
Write-Host "  2. Restart API server" -ForegroundColor White
Write-Host "  3. Verify data integrity" -ForegroundColor White

Write-Host "`n✅ Restore process completed!" -ForegroundColor Green

