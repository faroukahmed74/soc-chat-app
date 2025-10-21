param(
  [string]$TaskName = "SOCChat-AutoStart",
  [ValidateSet('Startup','Logon')]
  [string]$RunMode = 'Startup',
  [string]$UserId = $env:USERNAME
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Ok($msg)   { Write-Host "[OK]  $msg" -ForegroundColor Green }

# Determine project root (this script is expected under scripts/)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$servicesManagerPath = Join-Path $projectRoot "services_manager.bat"

if (!(Test-Path $servicesManagerPath)) {
  throw "services_manager.bat was not found at: $servicesManagerPath"
}

Write-Info "Project root: $projectRoot"
Write-Info "Services manager: $servicesManagerPath"

# Optionally build web on first install if missing
$webIndex = Join-Path $projectRoot "build\web\index.html"
if (!(Test-Path $webIndex)) {
  $flutter = Get-Command flutter -ErrorAction SilentlyContinue
  if ($flutter) {
    Write-Info "Web build not found. Running 'flutter build web --release'..."
    Push-Location $projectRoot
    try {
      flutter build web --release
      Write-Ok "Web build completed."
    } catch {
      Write-Warn "Failed to build web. Proceeding to register startup task anyway. Error: $_"
    } finally {
      Pop-Location
    }
  } else {
    Write-Warn "Flutter not found in PATH; skipping web build."
  }
} else {
  Write-Info "Web build exists; skipping build."
}

# Prepare Scheduled Task components
if ($RunMode -eq 'Startup') {
  Write-Info "Registering to start at system boot (headless, runs as SYSTEM)."
} else {
  Write-Info "Registering to start at user logon (interactive windows, runs as $UserId)."
}

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$servicesManagerPath`" start-all"

# Trigger: AtStartup (SYSTEM) or AtLogon (current user)
if ($RunMode -eq 'Startup') {
  $trigger = New-ScheduledTaskTrigger -AtStartup
  $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
} else {
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserId
  $principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Highest
}

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -MultipleInstances Queue `
  -RestartInterval (New-TimeSpan -Minutes 1) `
  -RestartCount 3

Write-Info "Task settings: includes restart on failure (every 1 min, up to 3 times)."

# Replace existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
  Write-Info "Existing task '$TaskName' found. Removing before re-registering."
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Register the task
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
Write-Ok "Scheduled task '$TaskName' registered to auto-start all services ($RunMode)."

Write-Info "Verify in Task Scheduler: Task Scheduler Library -> $TaskName"
Write-Info "To test immediately: schtasks /run /TN $TaskName"

Write-Info "Notes:"
Write-Info " - Startup mode runs without visible windows (SYSTEM session)."
Write-Info " - Logon mode opens service windows after you sign in."
Write-Info " - If Node/ngrok aren't in SYSTEM PATH, prefer Logon mode."