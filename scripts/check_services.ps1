param()

$ErrorActionPreference = 'SilentlyContinue'

function Add-Result($name, $ok, $info) {
  $script:results += [pscustomobject]@{ Service = $name; Status = if ($ok) { 'OK' } else { 'FAIL' }; Info = $info }
}

function Check-Port([int]$port) {
  try {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop
    return $true
  } catch {
    $out = netstat -ano | Select-String ":$port" | Select-String "LISTENING"
    return [bool]$out
  }
}

function Check-Http($url) {
  try {
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
    return $resp.StatusCode -eq 200
  } catch { return $false }
}

$results = @()

# MongoDB :27017
$mongo = Check-Port 27017
Add-Result "MongoDB :27017" $mongo (if ($mongo) { 'listening' } else { 'not listening' })

# API :3003
$apiPort = Check-Port 3003
$apiHealth = Check-Http "http://localhost:3003/health"
Add-Result "API :3003" ($apiPort -and $apiHealth) ("port=$apiPort, health=$apiHealth")

# Web Proxy :8082
$webPort = Check-Port 8082
$webHealth = Check-Http "http://localhost:8082/api/health"
Add-Result "Web Proxy :8082" ($webPort -and $webHealth) ("port=$webPort, /api/health=$webHealth")

# Local Network :3004
$netPort = Check-Port 3004
$netHealth = Check-Http "http://localhost:3004/health"
Add-Result "Local Network :3004" ($netPort -and $netHealth) ("port=$netPort, health=$netHealth")

# FCM :3000
$fcmPort = Check-Port 3000
Add-Result "FCM :3000" $fcmPort ("port=$fcmPort")

# ngrok admin :4040
$ngrokPort = Check-Port 4040
Add-Result "ngrok admin :4040" $ngrokPort ("port=$ngrokPort")

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path (Split-Path -Parent $scriptDir) 'scripts\\run'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$summaryPath = Join-Path $runDir 'services_health.txt'
$ts = Get-Date -Format o
Set-Content -Path $summaryPath -Value "==== Services Health ($ts) ===="
$results | ForEach-Object { Add-Content -Path $summaryPath -Value ("{0,-22} {1,-5} {2}" -f $_.Service, $_.Status, $_.Info) }
$okCount = ($results | Where-Object { $_.Status -eq 'OK' }).Count
Add-Content -Path $summaryPath -Value ("Summary: {0}/{1} OK" -f $okCount, $results.Count)

$results | Format-Table -AutoSize