# =============================================================================
# Call Issue Diagnostic Script
# =============================================================================
# This script checks all potential issues with call functionality
# =============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Call Issue Diagnostic" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Check if server is running
Write-Host "1. Checking Server Status..." -ForegroundColor Yellow
$serverProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
  try {
    $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
    $cmdLine -like "*server.js*"
  } catch {
    $false
  }
}

if ($serverProcesses) {
  Write-Host "  [OK] Server is running" -ForegroundColor Green
  $serverProcesses | ForEach-Object {
    Write-Host "    Process ID: $($_.Id)" -ForegroundColor Gray
  }
} else {
  Write-Host "  [ERROR] Server is NOT running" -ForegroundColor Red
}

# 2. Check server port
Write-Host "`n2. Checking Server Port (3003)..." -ForegroundColor Yellow
$portCheck = Test-NetConnection -ComputerName localhost -Port 3003 -InformationLevel Quiet -WarningAction SilentlyContinue
if ($portCheck) {
  Write-Host "  [OK] Port 3003 is accessible" -ForegroundColor Green
} else {
  Write-Host "  [ERROR] Port 3003 is NOT accessible" -ForegroundColor Red
}

# 3. Check ngrok
Write-Host "`n3. Checking ngrok..." -ForegroundColor Yellow
$ngrokProcesses = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
if ($ngrokProcesses) {
  Write-Host "  [OK] ngrok is running" -ForegroundColor Green
  $ngrokProcesses | ForEach-Object {
    Write-Host "    Process ID: $($_.Id)" -ForegroundColor Gray
  }
  
  # Try to get ngrok URL
  try {
    $ngrokApi = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -ErrorAction SilentlyContinue
    if ($ngrokApi.tunnels) {
      foreach ($tunnel in $ngrokApi.tunnels) {
        Write-Host "    Tunnel: $($tunnel.public_url) -> $($tunnel.config.addr)" -ForegroundColor Gray
      }
    }
  } catch {
    Write-Host "    [WARNING] Cannot access ngrok API (port 4040)" -ForegroundColor Yellow
  }
} else {
  Write-Host "  [WARNING] ngrok is NOT running" -ForegroundColor Yellow
  Write-Host "    Mobile devices need ngrok for external access" -ForegroundColor Gray
}

# 4. Test ngrok URL
Write-Host "`n4. Testing ngrok URL..." -ForegroundColor Yellow
$ngrokUrl = "https://soc-chat-app.ngrok-free.app"
try {
  $response = Invoke-WebRequest -Uri "$ngrokUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop -Headers @{"ngrok-skip-browser-warning"="true"}
  if ($response.StatusCode -eq 200) {
    Write-Host "  [OK] ngrok URL is accessible: $ngrokUrl" -ForegroundColor Green
  } else {
    Write-Host "  [WARNING] ngrok URL returned status: $($response.StatusCode)" -ForegroundColor Yellow
  }
} catch {
  Write-Host "  [ERROR] Cannot reach ngrok URL: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "    URL: $ngrokUrl" -ForegroundColor Gray
}

# 5. Test local server endpoint
Write-Host "`n5. Testing Local Server Endpoint..." -ForegroundColor Yellow
try {
  $response = Invoke-WebRequest -Uri "http://localhost:3003/api/health" -Method Get -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
  if ($response.StatusCode -eq 200) {
    Write-Host "  [OK] Local server endpoint is accessible" -ForegroundColor Green
  }
} catch {
  Write-Host "  [ERROR] Cannot reach local server: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Check call endpoint exists
Write-Host "`n6. Checking Call Endpoint in server.js..." -ForegroundColor Yellow
$serverFile = "servers\local_api_server\server.js"
if (Test-Path $serverFile) {
  $serverContent = Get-Content $serverFile -Raw
  if ($serverContent -match '/api/calls/invite') {
    Write-Host "  [OK] Call endpoint found: /api/calls/invite" -ForegroundColor Green
  } else {
    Write-Host "  [ERROR] Call endpoint NOT found" -ForegroundColor Red
  }
} else {
  Write-Host "  [ERROR] server.js not found" -ForegroundColor Red
}

# 7. Check connected devices
Write-Host "`n7. Checking Connected Devices..." -ForegroundColor Yellow
$devices = flutter devices 2>&1 | Select-String "mobile.*android"
if ($devices) {
  Write-Host "  [OK] Android devices connected:" -ForegroundColor Green
  $devices | ForEach-Object {
    Write-Host "    $_" -ForegroundColor Gray
  }
} else {
  Write-Host "  [WARNING] No Android devices detected" -ForegroundColor Yellow
}

# 8. Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Diagnostic Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$issues = @()
if (-not $serverProcesses) { $issues += "Server not running" }
if (-not $portCheck) { $issues += "Port 3003 not accessible" }
if (-not $ngrokProcesses) { $issues += "ngrok not running (needed for mobile)" }

if ($issues.Count -eq 0) {
  Write-Host "  [OK] All basic checks passed" -ForegroundColor Green
  Write-Host "`n  Next: Check Flutter logs for call-specific errors" -ForegroundColor Yellow
} else {
  Write-Host "  [WARNING] Issues found:" -ForegroundColor Yellow
  foreach ($issue in $issues) {
    Write-Host "    - $issue" -ForegroundColor Red
  }
}

Write-Host "`n========================================`n" -ForegroundColor Cyan

