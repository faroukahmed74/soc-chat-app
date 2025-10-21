param()

$ErrorActionPreference = 'Stop'

function Write-Line($msg) { Add-Content -Path $logPath -Value $msg }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $scriptDir 'run'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$logPath = Join-Path $runDir 'system_path_diag.txt'

Set-Content -Path $logPath -Value "==== SOC Chat - SYSTEM PATH Diagnostic ===="
Write-Line "Timestamp: $(Get-Date -Format o)"
Write-Line "User: $env:USERNAME"
Write-Line "Session: $env:SESSIONNAME"

# Machine and process PATH
$machinePath = [System.Environment]::GetEnvironmentVariable('Path','Machine')
$userPath = [System.Environment]::GetEnvironmentVariable('Path','User')
Write-Line "Machine PATH:"
Write-Line $machinePath
Write-Line "User PATH:"
Write-Line $userPath

# Node diagnostics
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
  Write-Line "Node found: $($nodeCmd.Path)"
  try {
    $nodeVer = & $nodeCmd.Path -v
    Write-Line "Node version: $nodeVer"
  } catch { Write-Line "Node version check failed: $($_.Exception.Message)" }
} else {
  Write-Line "Node not found in PATH (SYSTEM)."
  if (Test-Path 'C:\Program Files\nodejs\node.exe') {
    Write-Line "Candidate: C:\\Program Files\\nodejs\\node.exe exists"
  }
}

# ngrok diagnostics
$ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
if ($ngrokCmd) {
  Write-Line "ngrok found: $($ngrokCmd.Path)"
  try {
    $ngVer = & $ngrokCmd.Path version
    Write-Line "ngrok version: $ngVer"
  } catch { Write-Line "ngrok version check failed: $($_.Exception.Message)" }
} else {
  Write-Line "ngrok not found in PATH (SYSTEM)."
}

Write-Line "==== End Diagnostic ===="
Write-Host "SYSTEM PATH diagnostic written to $logPath"