# Start ngrok with both HTTP (API) and TCP (TURN) tunnels
# This script starts ngrok with a config file that includes both tunnels

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting ngrok with API + TURN tunnels" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if ngrok is installed
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] ngrok is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Install from: https://ngrok.com/download" -ForegroundColor Yellow
    exit 1
}

# Check if ngrok config file exists
$configPath = Join-Path $PSScriptRoot "ngrok.yml"
if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] ngrok config file not found: $configPath" -ForegroundColor Red
    Write-Host "Creating default config file..." -ForegroundColor Yellow
    
    # Create config file
    $configContent = @"
version: "2"
authtoken: # Set your authtoken via: ngrok config add-authtoken YOUR_TOKEN

tunnels:
  api:
    proto: http
    addr: 3003
    domain: soc-chat-app.ngrok-free.app
    inspect: true

  turn:
    proto: tcp
    addr: 3478
    inspect: false
"@
    $configContent | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "[OK] Config file created: $configPath" -ForegroundColor Green
    Write-Host "[INFO] Please set your ngrok authtoken:" -ForegroundColor Yellow
    Write-Host "  ngrok config add-authtoken YOUR_TOKEN" -ForegroundColor Cyan
    Write-Host ""
}

# Check if ngrok is already running
$ngrokProcess = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
if ($ngrokProcess) {
    Write-Host "[WARNING] ngrok is already running (PID: $($ngrokProcess.Id))" -ForegroundColor Yellow
    Write-Host "Stopping existing ngrok process..." -ForegroundColor Yellow
    Stop-Process -Name "ngrok" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Start ngrok with config file
Write-Host "[INFO] Starting ngrok with config: $configPath" -ForegroundColor Yellow
$ngrokProcess = Start-Process -FilePath "ngrok" `
    -ArgumentList "start", "--all", "--config", $configPath `
    -WindowStyle Normal `
    -PassThru

if ($ngrokProcess) {
    Write-Host "[OK] ngrok started (PID: $($ngrokProcess.Id))" -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting for tunnels to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Try to get tunnel information
    try {
        $tunnels = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -TimeoutSec 5
        Write-Host ""
        Write-Host "Active Tunnels:" -ForegroundColor Cyan
        foreach ($tunnel in $tunnels.tunnels) {
            $name = $tunnel.name
            $proto = $tunnel.proto
            $publicUrl = $tunnel.public_url
            Write-Host "  [$name] $proto -> $publicUrl" -ForegroundColor Green
        }
        
        # Find TURN tunnel
        $turnTunnel = $tunnels.tunnels | Where-Object { $_.name -eq "turn" }
        if ($turnTunnel) {
            $turnUrl = $turnTunnel.public_url
            Write-Host ""
            Write-Host "TURN Server Configuration:" -ForegroundColor Cyan
            Write-Host "  ngrok TCP URL: $turnUrl" -ForegroundColor Green
            Write-Host ""
            Write-Host "Update your app with this TURN URL!" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARNING] Could not fetch tunnel info: $_" -ForegroundColor Yellow
        Write-Host "Check ngrok web interface: http://localhost:4040" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "ngrok Web Interface: http://localhost:4040" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "[ERROR] Failed to start ngrok" -ForegroundColor Red
    exit 1
}

