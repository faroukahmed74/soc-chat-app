# Test Port Forwarding for Docker coturn
# This script tests if UDP ports 3478 and 50000-50100 are accessible from outside

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Port Forwarding Test for Docker coturn" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$publicIp = "41.33.106.54"
$localIp = "10.120.4.230"
$turnPort = 3478
$mediaPortStart = 50000
$mediaPortEnd = 50100

# Test 1: Check if Docker coturn container is running
Write-Host "Test 1: Checking Docker coturn container..." -ForegroundColor Yellow
$container = docker ps --filter "name=soc-chat-coturn" --format "{{.Names}}"
if ($container -eq "soc-chat-coturn") {
    Write-Host "  ✅ Docker coturn container is running" -ForegroundColor Green
} else {
    Write-Host "  ❌ Docker coturn container is NOT running!" -ForegroundColor Red
    Write-Host "     Start it with: cd scripts; docker-compose -f coturn-docker-compose.yml up -d" -ForegroundColor Yellow
    exit 1
}

# Test 2: Check if ports are listening on the server
Write-Host ""
Write-Host "Test 2: Checking if ports are listening on server..." -ForegroundColor Yellow
Write-Host "  Checking UDP port $turnPort..." -ForegroundColor Gray
$udpPort = Get-NetUDPEndpoint -LocalPort $turnPort -ErrorAction SilentlyContinue
if ($udpPort) {
    Write-Host "  ✅ UDP port $turnPort is listening" -ForegroundColor Green
    Write-Host "     Local Address: $($udpPort.LocalAddress):$($udpPort.LocalPort)" -ForegroundColor Gray
} else {
    Write-Host "  ⚠️  UDP port $turnPort is not listening (may need to check Docker)" -ForegroundColor Yellow
}

Write-Host "  Checking TCP port $turnPort..." -ForegroundColor Gray
$tcpPort = Get-NetTCPConnection -LocalPort $turnPort -State Listen -ErrorAction SilentlyContinue
if ($tcpPort) {
    Write-Host "  ✅ TCP port $turnPort is listening" -ForegroundColor Green
    Write-Host "     Local Address: $($tcpPort.LocalAddress):$($tcpPort.LocalPort)" -ForegroundColor Gray
} else {
    Write-Host "  ⚠️  TCP port $turnPort is not listening (may need to check Docker)" -ForegroundColor Yellow
}

# Test 3: Check Docker port mappings
Write-Host ""
Write-Host "Test 3: Checking Docker port mappings..." -ForegroundColor Yellow
$dockerPorts = docker port soc-chat-coturn 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Docker port mappings:" -ForegroundColor Green
    $dockerPorts | ForEach-Object {
        Write-Host "     $_" -ForegroundColor Gray
    }
} else {
    Write-Host "  ❌ Could not get Docker port mappings" -ForegroundColor Red
}

# Test 4: Test TURN server connectivity using stun/turn client
Write-Host ""
Write-Host "Test 4: Testing TURN server connectivity..." -ForegroundColor Yellow
Write-Host "  Testing: turn:${publicIp}:${turnPort}" -ForegroundColor Gray
Write-Host "  Username: soc-chat-turn" -ForegroundColor Gray
Write-Host "  Password: yG5EJFUdLgT7xqXr" -ForegroundColor Gray
Write-Host ""
Write-Host "  ⚠️  Note: UDP connectivity testing requires external tools" -ForegroundColor Yellow
Write-Host "  ⚠️  You can use online TURN testing tools:" -ForegroundColor Yellow
Write-Host "     - https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/" -ForegroundColor Cyan
Write-Host "     - https://icetest.info/" -ForegroundColor Cyan
Write-Host ""

# Test 5: Check if we can reach the public IP
Write-Host "Test 5: Checking public IP accessibility..." -ForegroundColor Yellow
try {
    $ping = Test-Connection -ComputerName $publicIp -Count 1 -Quiet -ErrorAction Stop
    if ($ping) {
        Write-Host "  ✅ Public IP $publicIp is reachable" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Public IP $publicIp is not responding to ping (may be normal)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Could not ping public IP (may be normal - many servers block ping)" -ForegroundColor Yellow
}

# Test 6: Check Windows Firewall rules
Write-Host ""
Write-Host "Test 6: Checking Windows Firewall rules..." -ForegroundColor Yellow
$firewallRules = Get-NetFirewallRule -DisplayName "*TURN*" -ErrorAction SilentlyContinue
if ($firewallRules) {
    Write-Host "  ✅ Found TURN firewall rules:" -ForegroundColor Green
    $firewallRules | ForEach-Object {
        $enabled = if ($_.Enabled) { "Enabled" } else { "Disabled" }
        $color = if ($_.Enabled) { "Green" } else { "Red" }
        Write-Host "     $($_.DisplayName): $enabled" -ForegroundColor $color
    }
} else {
    Write-Host "  ⚠️  No TURN firewall rules found" -ForegroundColor Yellow
    Write-Host "     Run: .\scripts\configure_firewall_for_turn.ps1" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Port Forwarding Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test if port forwarding is working from OUTSIDE your network:" -ForegroundColor Yellow
Write-Host "  1. Use a device on a DIFFERENT network (mobile data, different WiFi)" -ForegroundColor White
Write-Host "  2. Visit: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/" -ForegroundColor Cyan
Write-Host "  3. Add TURN server:" -ForegroundColor White
Write-Host "     - URL: turn:${publicIp}:${turnPort}" -ForegroundColor Gray
Write-Host "     - Username: soc-chat-turn" -ForegroundColor Gray
Write-Host "     - Password: yG5EJFUdLgT7xqXr" -ForegroundColor Gray
Write-Host "  4. Click 'Gather candidates'" -ForegroundColor White
Write-Host "  5. Look for 'relay' candidates - if you see them, port forwarding is working!" -ForegroundColor White
Write-Host ""
Write-Host "Router Port Forwarding Requirements:" -ForegroundColor Yellow
Write-Host "  - UDP 3478 → $localIp:3478" -ForegroundColor White
Write-Host "  - UDP 50000-50100 → $localIp:50000-50100" -ForegroundColor White
Write-Host ""
Write-Host "If you see 'host' or 'srflx' candidates but NO 'relay' candidates," -ForegroundColor Yellow
Write-Host "  then port forwarding is NOT configured correctly." -ForegroundColor Yellow
Write-Host ""

