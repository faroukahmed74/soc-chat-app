# =============================================================================
# SOC Chat App - Verify all required services and software
# =============================================================================
# Checks installation and (where applicable) running state of everything
# listed in REQUIRED_SERVICES_AND_SOFTWARE_VERSIONS.md.
# DB path: D:\soc-chat-data
# =============================================================================

param(
    [switch]$EnsureDataPaths  # Create D:\soc-chat-data structure if missing
)

$ErrorActionPreference = "SilentlyContinue"

$results = @()
$baseData = "D:\soc-chat-data"
$mongoDbPath = Join-Path $baseData "MongoDB\data\db"
$mongoLogPath = Join-Path $baseData "MongoDB\log"
$uploadsPath = Join-Path $baseData "uploads"

function Add-Check($Name, $Ok, $Info) {
    $script:results += [pscustomobject]@{
        Category = $Name
        Status   = if ($Ok) { "OK" } else { "FAIL" }
        Info     = $Info
    }
}

function Test-PortListen([int]$Port) {
    try {
        $conn = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop
        return $true
    } catch {
        $out = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"
        return [bool]$out
    }
}

function Test-Http([string]$Url) {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        return $r.StatusCode -eq 200
    } catch { return $false }
}

function Get-CommandVersion($Name, [string]$VersionArg = "-v", [string]$VersionArg2 = "--version") {
    $exe = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $exe) { return $null, "not found" }
    try {
        $out = & $Name $VersionArg 2>&1
        if (-not $out) { $out = & $Name $VersionArg2 2>&1 }
        $v = ($out | Select-Object -First 1) -replace "^\s*", ""
        return $exe.Source, $v
    } catch {
        return $exe.Source, "version unknown"
    }
}

# ----- Data paths -----
if ($EnsureDataPaths) {
    foreach ($p in @($mongoDbPath, $mongoLogPath, $uploadsPath)) {
        $parent = Split-Path $p -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
    }
}

$dbPathExists = Test-Path $mongoDbPath
$logPathExists = Test-Path $mongoLogPath
$uploadsExists = Test-Path $uploadsPath
Add-Check "Data: D:\soc-chat-data paths" ($dbPathExists -and $logPathExists) "db=$dbPathExists log=$logPathExists uploads=$uploadsExists"

# ----- Git -----
$gitPath, $gitVer = Get-CommandVersion "git" "--version"
Add-Check "Git" ($null -ne $gitPath) ($gitVer)

# ----- Node -----
$nodePath, $nodeVer = Get-CommandVersion "node" "-v"
Add-Check "Node.js" ($null -ne $nodePath) ($nodeVer)

# ----- npm -----
$npmPath, $npmVer = Get-CommandVersion "npm" "-v"
Add-Check "npm" ($null -ne $npmPath) ($npmVer)

# ----- MongoDB (port + optional service) -----
$mongoListening = Test-PortListen 27017
$mongoSvc = Get-Service -Name "MongoDB" -ErrorAction SilentlyContinue
$mongoSvcInfo = if ($mongoSvc) { "service=$($mongoSvc.Status)" } else { "no Windows service (use start_mongodb.bat?)" }
Add-Check "MongoDB :27017" $mongoListening $mongoSvcInfo

# ----- API server -----
$apiPort = Test-PortListen 3003
$apiHealth = Test-Http "http://127.0.0.1:3003/health"
Add-Check "API server :3003" ($apiPort -and $apiHealth) "port=$apiPort health=$apiHealth"

# ----- Optional: Web proxy -----
$webPort = Test-PortListen 8082
$webHealth = Test-Http "http://localhost:8082/api/health"
Add-Check "Web proxy :8082 (optional)" $webPort (if ($webPort -and $webHealth) { "listening" } else { "not running" })

# ----- Optional: Ollama -----
$ollamaPath, $ollamaVer = Get-CommandVersion "ollama" "version" "--version"
$ollamaPort = Test-PortListen 11434
Add-Check "Ollama (optional)" ($null -ne $ollamaPath) ($ollamaVer + "; port 11434=" + $ollamaPort)

# ----- Optional: Docker -----
$dockerPath, $dockerVer = Get-CommandVersion "docker" "--version"
Add-Check "Docker (optional)" ($null -ne $dockerPath) ($dockerVer)

# ----- Optional: Flutter -----
$flutterPath, $flutterVer = Get-CommandVersion "flutter" "--version"
Add-Check "Flutter (optional)" ($null -ne $flutterPath) ($flutterVer)

# ----- Optional: FFmpeg -----
$ffmpegPath, $ffmpegVer = Get-CommandVersion "ffmpeg" "-version"
Add-Check "FFmpeg (optional)" ($null -ne $ffmpegPath) (if ($ffmpegPath) { "installed" } else { "not found" })

# ----- Optional: FCM :3000 -----
$fcmPort = Test-PortListen 3000
Add-Check "FCM :3000 (optional)" $fcmPort (if ($fcmPort) { "listening" } else { "not running" })

# ----- Optional: ngrok -----
$ngrokPath, $ngrokVer = Get-CommandVersion "ngrok" "version" "--version"
$ngrokPort = Test-PortListen 4040
Add-Check "ngrok (optional)" ($null -ne $ngrokPath) ($ngrokVer + "; 4040=" + ($ngrokPort -as [string]))

# ----- Output -----
Write-Host ""
Write-Host "==== SOC Chat App - Required Services & Software ====" -ForegroundColor Cyan
Write-Host "DB path: D:\soc-chat-data\MongoDB\data\db" -ForegroundColor Gray
Write-Host ""

$results | Format-Table -AutoSize

$required = @(
    "Data: D:\soc-chat-data paths",
    "Git",
    "Node.js",
    "npm",
    "MongoDB :27017",
    "API server :3003"
)
$requiredOk = ($results | Where-Object { $_.Category -in $required -and $_.Status -eq "OK" }).Count
$requiredTotal = $required.Count
$allOk = ($results | Where-Object { $_.Status -eq "OK" }).Count
$allTotal = $results.Count

Write-Host "Required: $requiredOk/$requiredTotal OK" -ForegroundColor $(if ($requiredOk -eq $requiredTotal) { "Green" } else { "Yellow" })
Write-Host "All checks: $allOk/$allTotal OK" -ForegroundColor Gray
Write-Host ""

if ($requiredOk -lt $requiredTotal) {
    Write-Host "Actions:" -ForegroundColor Yellow
    if (-not (Test-Path $mongoDbPath)) {
        Write-Host "  - Create data paths: .\scripts\ensure_data_paths.ps1" -ForegroundColor White
        Write-Host "  - Or run: .\scripts\verify_all_required.ps1 -EnsureDataPaths" -ForegroundColor White
    }
    if (-not $mongoListening) {
        Write-Host "  - Start MongoDB with dbpath D:\soc-chat-data: scripts\run\start_mongodb.bat" -ForegroundColor White
        Write-Host "    Or configure MongoDB service to use D:\soc-chat-data\MongoDB\data\db and: net start MongoDB" -ForegroundColor White
    }
    if (-not $apiHealth) {
        Write-Host "  - Install Node deps: cd servers && npm install && cd local_api_server && npm install" -ForegroundColor White
        Write-Host "  - Copy servers\local_api_server\.env.example to .env and set MONGO_URI" -ForegroundColor White
        Write-Host "  - Start API: node servers\local_api_server\server.js (PORT=3003)" -ForegroundColor White
    }
    exit 1
}

exit 0
