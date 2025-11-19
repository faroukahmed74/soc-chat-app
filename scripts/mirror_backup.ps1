# =============================================================================
# SOC Chat App - Mirror Backup Script
# =============================================================================
# This script creates a MIRROR backup - an exact copy of current data
# Mirror backups:
#   - Keep only the latest version (no history)
#   - Update/sync existing files
#   - Delete files that no longer exist in source
#   - Perfect for quick disaster recovery
# =============================================================================

param(
    [string]$MirrorDir = "F:\soc-chat-mirror",
    [switch]$Quiet = $false,
    [switch]$DryRun = $false
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

Write-Header "SOC Chat App - Mirror Backup"
Write-Info "Mirror Directory: $MirrorDir"
Write-Info "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

if ($DryRun) {
    Write-Info "DRY RUN MODE - No files will be modified"
}

# Create mirror directory structure
try {
    New-Item -ItemType Directory -Path $MirrorDir -Force | Out-Null
    Write-Success "Mirror directory ready: $MirrorDir"
} catch {
    Write-Error "Failed to create mirror directory: $_"
    exit 1
}

# =============================================================================
# 1. MIRROR MONGODB DATABASE
# =============================================================================
Write-Header "Step 1: Mirroring MongoDB Database"

$mongoSourcePath = "D:\soc-chat-data\MongoDB\data\db"
$mongoMirrorPath = Join-Path $MirrorDir "MongoDB\data\db"
$mongoLogSource = "D:\soc-chat-data\MongoDB\log"
$mongoLogMirror = Join-Path $MirrorDir "MongoDB\log"

if (Test-Path $mongoSourcePath) {
    try {
        New-Item -ItemType Directory -Path $mongoMirrorPath -Force | Out-Null
        
        if ($DryRun) {
            Write-Info "DRY RUN: Would mirror MongoDB from $mongoSourcePath to $mongoMirrorPath"
        } else {
            Write-Info "Mirroring MongoDB database files..."
            
            # Use robocopy for efficient mirroring (Windows built-in)
            # /MIR = Mirror mode (deletes files in destination that don't exist in source)
            # /R:3 = Retry 3 times on failure
            # /W:1 = Wait 1 second between retries
            # /NP = No progress (cleaner output)
            # /NDL = No directory list
            # /NFL = No file list
            
            $robocopyArgs = @(
                "`"$mongoSourcePath`"",
                "`"$mongoMirrorPath`"",
                "/MIR",
                "/R:3",
                "/W:1",
                "/NP",
                "/NDL",
                "/NFL"
            )
            
            $robocopyResult = & robocopy @robocopyArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            # Robocopy returns 0-7 for success, 8+ for errors
            if ($exitCode -le 7) {
                $dbSize = (Get-ChildItem $mongoMirrorPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
                Write-Success "MongoDB mirrored: $([math]::Round($dbSize, 2)) MB"
            } else {
                Write-Error "MongoDB mirror failed (exit code: $exitCode)"
            }
            
            # Mirror logs if they exist
            if (Test-Path $mongoLogSource) {
                New-Item -ItemType Directory -Path $mongoLogMirror -Force | Out-Null
                $logRobocopyArgs = @(
                    "`"$mongoLogSource`"",
                    "`"$mongoLogMirror`"",
                    "/MIR",
                    "/R:3",
                    "/W:1",
                    "/NP",
                    "/NDL",
                    "/NFL"
                )
                & robocopy @logRobocopyArgs | Out-Null
            }
        }
    } catch {
        Write-Error "Failed to mirror MongoDB: $_"
    }
} else {
    Write-Error "MongoDB source path not found: $mongoSourcePath"
}

# =============================================================================
# 2. MIRROR MEDIA FILES
# =============================================================================
Write-Header "Step 2: Mirroring Media Files"

$mediaSourcePath = "D:\soc-chat-data\uploads"
$mediaMirrorPath = Join-Path $MirrorDir "uploads"

if (Test-Path $mediaSourcePath) {
    try {
        if ($DryRun) {
            Write-Info "DRY RUN: Would mirror media files from $mediaSourcePath to $mediaMirrorPath"
            $mediaCount = (Get-ChildItem $mediaSourcePath -Recurse -File -ErrorAction SilentlyContinue).Count
            Write-Info "DRY RUN: Would mirror $mediaCount files"
        } else {
            Write-Info "Mirroring media files..."
            
            # Use robocopy for efficient mirroring
            $robocopyArgs = @(
                "`"$mediaSourcePath`"",
                "`"$mediaMirrorPath`"",
                "/MIR",
                "/R:3",
                "/W:1",
                "/NP",
                "/NDL",
                "/NFL"
            )
            
            $robocopyResult = & robocopy @robocopyArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -le 7) {
                $mediaSize = (Get-ChildItem $mediaMirrorPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
                $mediaCount = (Get-ChildItem $mediaMirrorPath -Recurse -File -ErrorAction SilentlyContinue).Count
                Write-Success "Media files mirrored: $mediaCount files, $([math]::Round($mediaSize, 2)) MB"
            } else {
                Write-Error "Media mirror failed (exit code: $exitCode)"
            }
        }
    } catch {
        Write-Error "Failed to mirror media files: $_"
    }
} else {
    Write-Error "Media source path not found: $mediaSourcePath"
}

# =============================================================================
# 3. MIRROR CONFIGURATION FILES
# =============================================================================
Write-Header "Step 3: Mirroring Configuration Files"

$configMirrorPath = Join-Path $MirrorDir "config"
$envFile = "servers\local_api_server\.env"

New-Item -ItemType Directory -Path $configMirrorPath -Force | Out-Null

if (Test-Path $envFile) {
    try {
        if ($DryRun) {
            Write-Info "DRY RUN: Would copy configuration file"
        } else {
            Copy-Item -Path $envFile -Destination (Join-Path $configMirrorPath ".env") -Force
            Write-Success "Configuration file mirrored"
        }
    } catch {
        Write-Error "Failed to mirror configuration: $_"
    }
} else {
    Write-Info "Configuration file not found (may be filtered)"
}

# Create mirror info file
$mirrorInfo = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    mirrorPath = $MirrorDir
    mongoSourcePath = $mongoSourcePath
    mediaSourcePath = $mediaSourcePath
    type = "mirror"
    version = "1.0"
} | ConvertTo-Json -Depth 3

if (-not $DryRun) {
    $mirrorInfo | Out-File -FilePath (Join-Path $MirrorDir "mirror_info.json") -Encoding UTF8
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Header "Mirror Backup Summary"

if (-not $DryRun) {
    $totalSize = (Get-ChildItem $MirrorDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    
    Write-Success "Mirror backup completed!"
    Write-Host "`nMirror Details:" -ForegroundColor Cyan
    Write-Host "  Location: $MirrorDir" -ForegroundColor White
    Write-Host "  Total Size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
    Write-Host "  Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "`nNote: Mirror backup contains only the latest version of your data." -ForegroundColor Yellow
    Write-Host "For version history, use the regular backup script." -ForegroundColor Yellow
} else {
    Write-Info "Dry run completed - no files were modified"
}

Write-Host "`nMirror backup process completed!" -ForegroundColor Green

