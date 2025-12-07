# Setup coturn TURN Server on Windows
# This script installs and configures coturn for WebRTC TURN relay

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "coturn TURN Server Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Get server IP address
Write-Host "[INFO] Detecting server IP address..." -ForegroundColor Yellow
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and 
    $_.IPAddress -notlike "169.254.*" 
} | Select-Object -First 1

if ($ipAddresses) {
    $serverIP = $ipAddresses.IPAddress
    Write-Host "[OK] Server IP detected: $serverIP" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Could not detect server IP address" -ForegroundColor Red
    $serverIP = Read-Host "Please enter your server's public IP address"
}

# Get server port (default 3003 for API server)
$apiPort = Read-Host "Enter API server port (default: 3003)"
if ([string]::IsNullOrWhiteSpace($apiPort)) {
    $apiPort = "3003"
}

# TURN server configuration
$turnPort = "3478"
$turnTlsPort = "5349"
$turnRealm = "soc-chat-app.local"

# Generate TURN credentials
$turnUsername = "soc-chat-turn"
$turnPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_})

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TURN Server Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Server IP: $serverIP" -ForegroundColor White
Write-Host "TURN Port (UDP/TCP): $turnPort" -ForegroundColor White
Write-Host "TURN TLS Port: $turnTlsPort" -ForegroundColor White
Write-Host "Realm: $turnRealm" -ForegroundColor White
Write-Host "Username: $turnUsername" -ForegroundColor White
Write-Host "Password: $turnPassword" -ForegroundColor White
Write-Host ""

# Check if coturn is installed (via WSL or Docker)
Write-Host "[INFO] Checking for coturn installation..." -ForegroundColor Yellow

# Option 1: Check for Docker
$dockerAvailable = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerAvailable) {
    Write-Host "[OK] Docker is available" -ForegroundColor Green
    Write-Host "[INFO] Setting up coturn via Docker..." -ForegroundColor Yellow
    
    # Create Docker compose file for coturn
    $dockerComposeContent = @"
version: '3.8'

services:
  coturn:
    image: coturn/coturn:latest
    container_name: soc-chat-coturn
    network_mode: host
    restart: unless-stopped
    environment:
      - EXTERNAL_IP=$serverIP
    volumes:
      - ./coturn:/etc/coturn
    command: |
      -n
      --log-file=stdout
      --external-ip=$serverIP
      --listening-port=$turnPort
      --tls-listening-port=$turnTlsPort
      --min-port=49152
      --max-port=65535
      --realm=$turnRealm
      --user=$turnUsername`:$turnPassword
      --no-cli
      --no-tls
      --no-dtls
      --fingerprint
      --lt-cred-mech
      --verbose
"@
    
    $dockerComposePath = Join-Path $PSScriptRoot "coturn-docker-compose.yml"
    $dockerComposeContent | Out-File -FilePath $dockerComposePath -Encoding UTF8
    Write-Host "[OK] Docker Compose file created: $dockerComposePath" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "[INFO] To start coturn, run:" -ForegroundColor Yellow
    Write-Host "  docker-compose -f $dockerComposePath up -d" -ForegroundColor Cyan
    Write-Host ""
    
} else {
    Write-Host "[WARN] Docker not found. coturn setup options:" -ForegroundColor Yellow
    Write-Host "  1. Install Docker Desktop for Windows" -ForegroundColor White
    Write-Host "  2. Use WSL2 to run coturn" -ForegroundColor White
    Write-Host "  3. Use a cloud TURN service (Twilio, etc.)" -ForegroundColor White
    Write-Host ""
}

# Create configuration file for Flutter app
$configContent = @"
# TURN Server Configuration
# Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

TURN_SERVER_IP=$serverIP
TURN_SERVER_PORT=$turnPort
TURN_SERVER_TLS_PORT=$turnTlsPort
TURN_USERNAME=$turnUsername
TURN_PASSWORD=$turnPassword
TURN_REALM=$turnRealm

# Flutter WebRTC Configuration
# Add these to lib/services/webrtc_call_service.dart:
#
# {
#   'urls': 'turn:$serverIP`:$turnPort',
#   'username': '$turnUsername',
#   'credential': '$turnPassword',
# },
# {
#   'urls': 'turn:$serverIP`:$turnPort?transport=tcp',
#   'username': '$turnUsername',
#   'credential': '$turnPassword',
# },
"@

$configPath = Join-Path $PSScriptRoot "turn_server_config.txt"
$configContent | Out-File -FilePath $configPath -Encoding UTF8
Write-Host "[OK] Configuration saved to: $configPath" -ForegroundColor Green

# Create Windows Firewall rules
Write-Host ""
Write-Host "[INFO] Creating Windows Firewall rules..." -ForegroundColor Yellow
try {
    # UDP rule
    New-NetFirewallRule -DisplayName "coturn TURN Server UDP" -Direction Inbound -Protocol UDP -LocalPort $turnPort -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "[OK] Firewall rule created for UDP port $turnPort" -ForegroundColor Green
    
    # TCP rule
    New-NetFirewallRule -DisplayName "coturn TURN Server TCP" -Direction Inbound -Protocol TCP -LocalPort $turnPort -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "[OK] Firewall rule created for TCP port $turnPort" -ForegroundColor Green
    
    # TLS rule
    New-NetFirewallRule -DisplayName "coturn TURN Server TLS" -Direction Inbound -Protocol TCP -LocalPort $turnTlsPort -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "[OK] Firewall rule created for TLS port $turnTlsPort" -ForegroundColor Green
    
    # Media port range
    New-NetFirewallRule -DisplayName "coturn TURN Media Ports" -Direction Inbound -Protocol UDP -LocalPort 49152-65535 -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "[OK] Firewall rule created for media ports 49152-65535" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not create firewall rules: $_" -ForegroundColor Yellow
    Write-Host "[INFO] You may need to manually open ports $turnPort, $turnTlsPort, and 49152-65535" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "TURN Server Configuration:" -ForegroundColor Yellow
Write-Host "  Server IP: $serverIP" -ForegroundColor White
Write-Host "  Port: $turnPort" -ForegroundColor White
Write-Host "  Username: $turnUsername" -ForegroundColor White
Write-Host "  Password: $turnPassword" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Start coturn server (Docker or WSL)" -ForegroundColor White
Write-Host "2. Configure TURN in your Flutter app (see below)" -ForegroundColor White
Write-Host "3. Test TURN connectivity using WebRTC test tools" -ForegroundColor White
Write-Host ""
Write-Host "Configuration saved to: $configPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To configure in Flutter app, add this code:" -ForegroundColor Yellow
Write-Host "  WebRTCCallService().setTurnServerConfig(" -ForegroundColor Cyan
Write-Host "    serverIp: '$serverIP'," -ForegroundColor Cyan
Write-Host "    port: '$turnPort'," -ForegroundColor Cyan
Write-Host "    username: '$turnUsername'," -ForegroundColor Cyan
Write-Host "    password: '$turnPassword'," -ForegroundColor Cyan
Write-Host "  );" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

