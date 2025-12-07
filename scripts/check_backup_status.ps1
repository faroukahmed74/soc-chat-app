# =============================================================================
# SOC Chat App - Backup Status Check Script
# =============================================================================
# This script checks the status of all backup types and generates a report
# =============================================================================

param(
    [switch]$GenerateReport = $true,
    [string]$ReportPath = "scripts\BACKUP_STATUS_REPORT.md"
)

$ErrorActionPreference = "Continue"

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

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

# Report data
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    FullBackup = @{}
    MirrorBackup = @{}
    RealTimeBackup = @{}
    StorageLocations = @{}
    Summary = @{}
}

Write-Header "SOC Chat App - Backup Status Check"

# =============================================================================
# 1. Check Full Backup Scheduled Task
# =============================================================================
Write-Host "`n1. Checking Full Backup Scheduled Task..." -ForegroundColor Yellow

$fullBackupTask = Get-ScheduledTask -TaskName "SOC_Chat_App_Backup" -ErrorAction SilentlyContinue

if ($fullBackupTask) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName "SOC_Chat_App_Backup"
    $taskState = $fullBackupTask.State
    
    Write-Success "Full Backup Task Found"
    Write-Info "  Task Name: SOC_Chat_App_Backup"
    Write-Info "  State: $taskState"
    Write-Info "  Last Run: $($taskInfo.LastRunTime)"
    Write-Info "  Last Result: $($taskInfo.LastTaskResult)"
    Write-Info "  Next Run: $($taskInfo.NextRunTime)"
    
    $report.FullBackup = @{
        Status = "Found"
        State = $taskState.ToString()
        LastRunTime = $taskInfo.LastRunTime.ToString()
        LastResult = $taskInfo.LastTaskResult.ToString()
        NextRunTime = $taskInfo.NextRunTime.ToString()
        Enabled = $fullBackupTask.Settings.Enabled
    }
    
    if ($taskState -eq "Running") {
        Write-Success "  Task is currently running"
    } elseif ($taskState -eq "Ready") {
        Write-Success "  Task is ready and scheduled"
    } else {
        Write-Warning "  Task state: $taskState"
    }
    
    if ($taskInfo.LastTaskResult -eq 0) {
        Write-Success "  Last run completed successfully"
    } elseif ($taskInfo.LastTaskResult -ne 267009) { # 267009 = task hasn't run yet
        Write-Warning "  Last run result: $($taskInfo.LastTaskResult)"
    }
} else {
    Write-Error "Full Backup Task NOT Found"
    $report.FullBackup = @{
        Status = "Not Found"
        State = "N/A"
    }
}

# =============================================================================
# 2. Check Mirror Backup Scheduled Task
# =============================================================================
Write-Host "`n2. Checking Mirror Backup Scheduled Task..." -ForegroundColor Yellow

$mirrorBackupTask = Get-ScheduledTask -TaskName "SOC_Chat_App_Mirror_Backup" -ErrorAction SilentlyContinue

if ($mirrorBackupTask) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName "SOC_Chat_App_Mirror_Backup"
    $taskState = $mirrorBackupTask.State
    
    Write-Success "Mirror Backup Task Found"
    Write-Info "  Task Name: SOC_Chat_App_Mirror_Backup"
    Write-Info "  State: $taskState"
    Write-Info "  Last Run: $($taskInfo.LastRunTime)"
    Write-Info "  Last Result: $($taskInfo.LastTaskResult)"
    Write-Info "  Next Run: $($taskInfo.NextRunTime)"
    
    $report.MirrorBackup = @{
        Status = "Found"
        State = $taskState.ToString()
        LastRunTime = $taskInfo.LastRunTime.ToString()
        LastResult = $taskInfo.LastTaskResult.ToString()
        NextRunTime = $taskInfo.NextRunTime.ToString()
        Enabled = $mirrorBackupTask.Settings.Enabled
    }
    
    if ($taskState -eq "Running") {
        Write-Success "  Task is currently running"
    } elseif ($taskState -eq "Ready") {
        Write-Success "  Task is ready and scheduled"
    } else {
        Write-Warning "  Task state: $taskState"
    }
    
    if ($taskInfo.LastTaskResult -eq 0) {
        Write-Success "  Last run completed successfully"
    } elseif ($taskInfo.LastTaskResult -ne 267009) {
        Write-Warning "  Last run result: $($taskInfo.LastTaskResult)"
    }
} else {
    Write-Error "Mirror Backup Task NOT Found"
    $report.MirrorBackup = @{
        Status = "Not Found"
        State = "N/A"
    }
}

# =============================================================================
# 3. Check Real-Time Backup Auto-Start Task
# =============================================================================
Write-Host "`n3. Checking Real-Time Backup Auto-Start Task..." -ForegroundColor Yellow

$realtimeStartTask = Get-ScheduledTask -TaskName "SOC_Chat_App_Start_RealTime_Backup" -ErrorAction SilentlyContinue

if ($realtimeStartTask) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName "SOC_Chat_App_Start_RealTime_Backup"
    $taskState = $realtimeStartTask.State
    
    Write-Success "Real-Time Backup Start Task Found"
    Write-Info "  Task Name: SOC_Chat_App_Start_RealTime_Backup"
    Write-Info "  State: $taskState"
    Write-Info "  Last Run: $($taskInfo.LastRunTime)"
    Write-Info "  Last Result: $($taskInfo.LastTaskResult)"
    
    $report.RealTimeBackup.Task = @{
        Status = "Found"
        State = $taskState.ToString()
        LastRunTime = $taskInfo.LastRunTime.ToString()
        LastResult = $taskInfo.LastTaskResult.ToString()
        Enabled = $realtimeStartTask.Settings.Enabled
    }
} else {
    Write-Error "Real-Time Backup Start Task NOT Found"
    $report.RealTimeBackup.Task = @{
        Status = "Not Found"
        State = "N/A"
    }
}

# =============================================================================
# 4. Check Real-Time Backup Process
# =============================================================================
Write-Host "`n4. Checking Real-Time Backup Process..." -ForegroundColor Yellow

$realtimeProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
        $cmdLine -like "*realtime_backup.ps1*" -and $_.Id -ne $PID
    } catch {
        $false
    }
}

if ($realtimeProcesses) {
    Write-Success "Real-Time Backup Process Running"
    $processCount = ($realtimeProcesses | Measure-Object).Count
    Write-Info "  Running Processes: $processCount"
    foreach ($proc in $realtimeProcesses) {
        Write-Info "  Process ID: $($proc.Id), CPU: $([math]::Round($proc.CPU, 2))s, Memory: $([math]::Round($proc.WS / 1MB, 2)) MB"
    }
    
    $report.RealTimeBackup.Process = @{
        Status = "Running"
        ProcessCount = $processCount
        ProcessIds = ($realtimeProcesses | ForEach-Object { $_.Id }) -join ", "
    }
} else {
    Write-Warning "Real-Time Backup Process NOT Running"
    $report.RealTimeBackup.Process = @{
        Status = "Not Running"
        ProcessCount = 0
    }
}

# =============================================================================
# 5. Check Backup Storage Locations
# =============================================================================
Write-Host "`n5. Checking Backup Storage Locations..." -ForegroundColor Yellow

$backupDirs = @(
    @{ Name = "Full Backups"; Path = "F:\soc-chat-backups" },
    @{ Name = "Mirror Backups"; Path = "F:\soc-chat-mirror" },
    @{ Name = "Real-Time Backups"; Path = "F:\soc-chat-realtime" }
)

foreach ($dir in $backupDirs) {
    $path = $dir.Path
    if (Test-Path $path) {
        Write-Success "$($dir.Name) Directory Exists"
        $items = Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue
        $fileCount = ($items | Where-Object { -not $_.PSIsContainer } | Measure-Object).Count
        $dirCount = ($items | Where-Object { $_.PSIsContainer } | Measure-Object).Count
        $totalSize = ($items | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
        
        $sizeGB = [math]::Round($totalSize / 1GB, 2)
        $sizeMB = [math]::Round($totalSize / 1MB, 2)
        
        Write-Info "  Path: $path"
        Write-Info "  Files: $fileCount"
        Write-Info "  Directories: $dirCount"
        Write-Info "  Total Size: $sizeGB GB ($sizeMB MB)"
        
        $report.StorageLocations[$dir.Name] = @{
            Exists = $true
            Path = $path
            FileCount = $fileCount
            DirectoryCount = $dirCount
            TotalSizeGB = $sizeGB
            TotalSizeMB = $sizeMB
        }
        
        # Check for recent backups (full backups only)
        if ($dir.Name -eq "Full Backups") {
            $backupFiles = Get-ChildItem $path -Filter "*.zip" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | Select-Object -First 5
            if ($backupFiles) {
                Write-Info "  Recent Backups:"
                foreach ($backup in $backupFiles) {
                    $backupSize = [math]::Round($backup.Length / 1MB, 2)
                    Write-Info "    - $($backup.Name) ($backupSize MB) - $($backup.LastWriteTime)"
                }
                $report.StorageLocations[$dir.Name].RecentBackups = $backupFiles.Count
                $report.StorageLocations[$dir.Name].LatestBackup = $backupFiles[0].Name
                $report.StorageLocations[$dir.Name].LatestBackupTime = $backupFiles[0].LastWriteTime.ToString()
            }
        }
    } else {
        Write-Error "$($dir.Name) Directory NOT Found: $path"
        $report.StorageLocations[$dir.Name] = @{
            Exists = $false
            Path = $path
        }
    }
}

# =============================================================================
# 6. Generate Summary
# =============================================================================
Write-Host "`n6. Generating Summary..." -ForegroundColor Yellow

$allTasksFound = ($report.FullBackup.Status -eq "Found") -and 
                 ($report.MirrorBackup.Status -eq "Found") -and 
                 ($report.RealTimeBackup.Task.Status -eq "Found")

$allTasksReady = ($report.FullBackup.State -eq "Ready") -and 
                 ($report.MirrorBackup.State -eq "Ready")

$realtimeRunning = $report.RealTimeBackup.Process.Status -eq "Running"

$allDirsExist = ($report.StorageLocations["Full Backups"].Exists) -and 
                ($report.StorageLocations["Mirror Backups"].Exists) -and 
                ($report.StorageLocations["Real-Time Backups"].Exists)

$overallStatus = "[OK] All Systems Operational"
if (-not $allTasksFound) {
    $overallStatus = "[WARNING] Some Tasks Missing"
}
if (-not $realtimeRunning) {
    $overallStatus = "[WARNING] Real-Time Backup Not Running"
}

$report.Summary = @{
    OverallStatus = $overallStatus
    AllTasksFound = $allTasksFound
    AllTasksReady = $allTasksReady
    RealTimeRunning = $realtimeRunning
    AllDirsExist = $allDirsExist
    Timestamp = $report.Timestamp
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Overall Status: $overallStatus" -ForegroundColor $(if ($allTasksFound -and $realtimeRunning -and $allDirsExist) { "Green" } else { "Yellow" })
Write-Host "All Scheduled Tasks Found: $(if ($allTasksFound) { '[OK] Yes' } else { '[X] No' })"
Write-Host "All Tasks Ready: $(if ($allTasksReady) { '[OK] Yes' } else { '[X] No' })"
Write-Host "Real-Time Backup Running: $(if ($realtimeRunning) { '[OK] Yes' } else { '[X] No' })"
Write-Host "All Storage Directories Exist: $(if ($allDirsExist) { '[OK] Yes' } else { '[X] No' })"

# =============================================================================
# 7. Generate Report File
# =============================================================================
if ($GenerateReport) {
    Write-Host "`n7. Generating Report File..." -ForegroundColor Yellow
    
    # Build report content step by step
    $reportLines = @()
    $reportLines += "# SOC Chat App - Backup Status Report"
    $reportLines += "**Generated:** $($report.Timestamp)"
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## Executive Summary"
    $reportLines += ""
    $reportLines += "**Overall Status:** $($report.Summary.OverallStatus)"
    $reportLines += ""
    $reportLines += "| Component | Status |"
    $reportLines += "|-----------|--------|"
    $allTasksFoundStatus = if ($report.Summary.AllTasksFound) { '[OK] Yes' } else { '[X] No' }
    $allTasksReadyStatus = if ($report.Summary.AllTasksReady) { '[OK] Yes' } else { '[X] No' }
    $realtimeRunningStatus = if ($report.Summary.RealTimeRunning) { '[OK] Yes' } else { '[X] No' }
    $allDirsExistStatus = if ($report.Summary.AllDirsExist) { '[OK] Yes' } else { '[X] No' }
    $reportLines += "| All Scheduled Tasks Found | $allTasksFoundStatus |"
    $reportLines += "| All Tasks Ready | $allTasksReadyStatus |"
    $reportLines += "| Real-Time Backup Running | $realtimeRunningStatus |"
    $reportLines += "| All Storage Directories Exist | $allDirsExistStatus |"
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 1. Full Backup System"
    $reportLines += ""
    $reportLines += "### Scheduled Task Status"
    $reportLines += "- **Task Name:** SOC_Chat_App_Backup"
    $reportLines += "- **Status:** $($report.FullBackup.Status)"
    $reportLines += "- **State:** $($report.FullBackup.State)"
    $reportLines += "- **Enabled:** $($report.FullBackup.Enabled)"
    $reportLines += "- **Last Run:** $($report.FullBackup.LastRunTime)"
    $reportLines += "- **Last Result:** $($report.FullBackup.LastResult)"
    $reportLines += "- **Next Run:** $($report.FullBackup.NextRunTime)"
    $reportLines += ""
    $reportLines += "### Storage Location"
    $reportLines += "- **Path:** F:\soc-chat-backups"
    $fullBackupExists = if ($report.StorageLocations["Full Backups"].Exists) { '[OK] Yes' } else { '[X] No' }
    $reportLines += "- **Exists:** $fullBackupExists"
    if ($report.StorageLocations["Full Backups"].Exists) {
        $reportLines += "- **Files:** $($report.StorageLocations["Full Backups"].FileCount)"
        $reportLines += "- **Directories:** $($report.StorageLocations["Full Backups"].DirectoryCount)"
        $reportLines += "- **Total Size:** $($report.StorageLocations["Full Backups"].TotalSizeGB) GB ($($report.StorageLocations["Full Backups"].TotalSizeMB) MB)"
        if ($report.StorageLocations["Full Backups"].RecentBackups) {
            $reportLines += "- **Recent Backups:** $($report.StorageLocations["Full Backups"].RecentBackups)"
            $reportLines += "- **Latest Backup:** $($report.StorageLocations["Full Backups"].LatestBackup)"
            $reportLines += "- **Latest Backup Time:** $($report.StorageLocations["Full Backups"].LatestBackupTime)"
        }
    }
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 2. Mirror Backup System"
    $reportLines += ""
    $reportLines += "### Scheduled Task Status"
    $reportLines += "- **Task Name:** SOC_Chat_App_Mirror_Backup"
    $reportLines += "- **Status:** $($report.MirrorBackup.Status)"
    $reportLines += "- **State:** $($report.MirrorBackup.State)"
    $reportLines += "- **Enabled:** $($report.MirrorBackup.Enabled)"
    $reportLines += "- **Last Run:** $($report.MirrorBackup.LastRunTime)"
    $reportLines += "- **Last Result:** $($report.MirrorBackup.LastResult)"
    $reportLines += "- **Next Run:** $($report.MirrorBackup.NextRunTime)"
    $reportLines += ""
    $reportLines += "### Storage Location"
    $reportLines += "- **Path:** F:\soc-chat-mirror"
    $mirrorBackupExists = if ($report.StorageLocations["Mirror Backups"].Exists) { '[OK] Yes' } else { '[X] No' }
    $reportLines += "- **Exists:** $mirrorBackupExists"
    if ($report.StorageLocations["Mirror Backups"].Exists) {
        $reportLines += "- **Files:** $($report.StorageLocations["Mirror Backups"].FileCount)"
        $reportLines += "- **Directories:** $($report.StorageLocations["Mirror Backups"].DirectoryCount)"
        $reportLines += "- **Total Size:** $($report.StorageLocations["Mirror Backups"].TotalSizeGB) GB ($($report.StorageLocations["Mirror Backups"].TotalSizeMB) MB)"
    }
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 3. Real-Time Backup System"
    $reportLines += ""
    $reportLines += "### Auto-Start Task Status"
    $reportLines += "- **Task Name:** SOC_Chat_App_Start_RealTime_Backup"
    $reportLines += "- **Status:** $($report.RealTimeBackup.Task.Status)"
    $reportLines += "- **State:** $($report.RealTimeBackup.Task.State)"
    $reportLines += "- **Enabled:** $($report.RealTimeBackup.Task.Enabled)"
    $reportLines += "- **Last Run:** $($report.RealTimeBackup.Task.LastRunTime)"
    $reportLines += "- **Last Result:** $($report.RealTimeBackup.Task.LastResult)"
    $reportLines += ""
    $reportLines += "### Process Status"
    $reportLines += "- **Status:** $($report.RealTimeBackup.Process.Status)"
    $reportLines += "- **Process Count:** $($report.RealTimeBackup.Process.ProcessCount)"
    if ($report.RealTimeBackup.Process.ProcessIds) {
        $reportLines += "- **Process IDs:** $($report.RealTimeBackup.Process.ProcessIds)"
    }
    $reportLines += ""
    $reportLines += "### Storage Location"
    $reportLines += "- **Path:** F:\soc-chat-realtime"
    $realtimeBackupExists = if ($report.StorageLocations["Real-Time Backups"].Exists) { '[OK] Yes' } else { '[X] No' }
    $reportLines += "- **Exists:** $realtimeBackupExists"
    if ($report.StorageLocations["Real-Time Backups"].Exists) {
        $reportLines += "- **Files:** $($report.StorageLocations["Real-Time Backups"].FileCount)"
        $reportLines += "- **Directories:** $($report.StorageLocations["Real-Time Backups"].DirectoryCount)"
        $reportLines += "- **Total Size:** $($report.StorageLocations["Real-Time Backups"].TotalSizeGB) GB ($($report.StorageLocations["Real-Time Backups"].TotalSizeMB) MB)"
    }
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## Recommendations"
    $reportLines += ""
    if (-not $report.Summary.AllTasksFound) {
        $reportLines += "[WARNING] **Action Required:** Some scheduled tasks are missing. Run the setup scripts:"
        $reportLines += "- Full Backup: ``.\scripts\schedule_backup.ps1``"
        $reportLines += "- Mirror Backup: ``.\scripts\schedule_mirror_backup.ps1``"
        $reportLines += "- Real-Time Backup: ``.\scripts\setup_autostart_backups.ps1``"
        $reportLines += ""
    }
    if (-not $report.Summary.RealTimeRunning) {
        $reportLines += "[WARNING] **Action Required:** Real-Time backup is not running. Start it with:"
        $reportLines += "- ``.\scripts\start_realtime_backup.ps1``"
        $reportLines += ""
    }
    if (-not $report.Summary.AllDirsExist) {
        $reportLines += "[WARNING] **Action Required:** Some backup directories are missing. They will be created automatically on first backup run."
        $reportLines += ""
    }
    if ($report.Summary.AllTasksFound -and $report.Summary.RealTimeRunning -and $report.Summary.AllDirsExist) {
        $reportLines += "[OK] **All systems operational!** No action required."
        $reportLines += ""
    }
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "**Report Generated:** $($report.Timestamp)"
    
    $reportContent = $reportLines -join "`n"

    try {
        $reportContent | Out-File -FilePath $ReportPath -Encoding UTF8
        Write-Success "Report saved to: $ReportPath"
    } catch {
        Write-Error "Failed to save report: $_"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Status Check Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

