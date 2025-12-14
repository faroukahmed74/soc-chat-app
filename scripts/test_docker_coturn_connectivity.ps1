# Test Docker coturn Connectivity
# Tests if Docker coturn is accessible from external networks

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker coturn Connectivity Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$publicIp = "41.33.106.54"
$turnPort = 3478
$turnUsername = "soc-chat-turn"
$turnPassword = "yG5EJFUdLgT7xqXr"

# 1. Check Docker container status
Write-Host "1. Checking Docker coturn container..." -ForegroundColor Yellow
try {
    $coturnStatus = docker ps --filter "name=soc-chat-coturn" --format "{{.Status}}" 2>&1
    if ($coturnStatus -match "Up") {
        Write-Host "   ✅ Docker coturn is running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Docker coturn is NOT running" -ForegroundColor Red
        Write-Host "   💡 Start it with: cd scripts; docker-compose -f coturn-docker-compose.yml up -d" -ForegroundColor Cyan
        exit 1
    }
} catch {
    Write-Host "   ❌ Error checking Docker coturn: $_" -ForegroundColor Red
    exit 1
}

# 2. Check Docker port mappings
Write-Host ""
Write-Host "2. Checking Docker port mappings..." -ForegroundColor Yellow
try {
    $dockerPorts = docker port soc-chat-coturn 2>&1
    if ($dockerPorts -match "3478") {
        Write-Host "   ✅ Port 3478 is mapped" -ForegroundColor Green
        if ($dockerPorts -match "0\.0\.0\.0:3478") {
            Write-Host "   ✅ Port is bound to 0.0.0.0 (public access)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Port is NOT bound to 0.0.0.0" -ForegroundColor Yellow
            Write-Host "   💡 Update coturn-docker-compose.yml to bind to 0.0.0.0" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   ❌ Port 3478 mapping not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ❌ Cannot check Docker port mappings: $_" -ForegroundColor Red
    exit 1
}

# 3. Test local connectivity (UDP)
Write-Host ""
Write-Host "3. Testing local UDP connectivity..." -ForegroundColor Yellow
try {
    $udpClient = New-Object System.Net.Sockets.UdpClient
    $udpClient.Client.ReceiveTimeout = 2000
    $endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse("127.0.0.1"), $turnPort)
    
    # Send STUN binding request
    $stunRequest = [byte[]](0x00, 0x01, 0x00, 0x00, 0x21, 0x12, 0xA4, 0x42, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    $udpClient.Send($stunRequest, $stunRequest.Length, $endpoint) | Out-Null
    
    try {
        $response = $udpClient.Receive([ref]$endpoint)
        if ($response.Length -gt 0) {
            Write-Host "   ✅ Local UDP connectivity works" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  No response from local TURN server" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️  No response from local TURN server (timeout)" -ForegroundColor Yellow
        Write-Host "      This is normal if TURN requires authentication" -ForegroundColor Gray
    }
    $udpClient.Close()
} catch {
    Write-Host "   ⚠️  Cannot test local UDP connectivity: $_" -ForegroundColor Yellow
}

# 4. Test public IP connectivity (if accessible)
Write-Host ""
Write-Host "4. Testing public IP connectivity..." -ForegroundColor Yellow
Write-Host "   ⚠️  This requires router port forwarding to be configured" -ForegroundColor Yellow
Write-Host "   💡 Use trickle-ice.webrtc.github.io to test from external device" -ForegroundColor Cyan
Write-Host ""
Write-Host "   TURN Server Configuration for Testing:" -ForegroundColor Cyan
Write-Host "   - URLs: turn:$publicIp`:$turnPort" -ForegroundColor White
Write-Host "   - Username: $turnUsername" -ForegroundColor White
Write-Host "   - Password: $turnPassword" -ForegroundColor White
Write-Host ""

# 5. Check Docker logs for connection attempts
Write-Host "5. Checking Docker coturn logs for recent activity..." -ForegroundColor Yellow
try {
    $recentLogs = docker logs --tail 20 soc-chat-coturn 2>&1
    $hasConnections = $recentLogs | Select-String -Pattern "session|connection|client|relay" -CaseSensitive:$false
    if ($hasConnections) {
        Write-Host "   ✅ Recent activity found in logs" -ForegroundColor Green
        Write-Host "   Recent log entries:" -ForegroundColor Gray
        $recentLogs | Select-Object -Last 5 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ⚠️  No recent connection activity in logs" -ForegroundColor Yellow
        Write-Host "      (This is normal if no clients have connected recently)" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⚠️  Cannot check Docker logs: $_" -ForegroundColor Yellow
}

# 6. Instructions for external testing
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "External Testing Instructions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test from an external device:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open https://trickle-ice.webrtc.github.io in a browser" -ForegroundColor White
Write-Host ""
Write-Host "2. Click 'Add Server' and enter:" -ForegroundColor White
Write-Host "   - URLs: turn:$publicIp`:$turnPort" -ForegroundColor Cyan
Write-Host "   - Username: $turnUsername" -ForegroundColor Cyan
Write-Host "   - Password: $turnPassword" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Click 'Gather candidates'" -ForegroundColor White
Write-Host ""
Write-Host "4. Look for 'relay' candidates with IP $publicIp" -ForegroundColor White
Write-Host "   ✅ If you see relay candidates, TURN server is working!" -ForegroundColor Green
Write-Host "   ❌ If you don't see relay candidates, check:" -ForegroundColor Red
Write-Host "      - Router port forwarding (UDP 3478, UDP 50000-50100)" -ForegroundColor Yellow
Write-Host "      - Windows Firewall rules" -ForegroundColor Yellow
Write-Host "      - Docker port mappings" -ForegroundColor Yellow
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Docker coturn container is running" -ForegroundColor Green
Write-Host "✅ Port mappings are configured" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Verify router port forwarding is configured" -ForegroundColor White
Write-Host "   2. Test from external device using trickle-ice" -ForegroundColor White
Write-Host "   3. Check Docker logs during test for connection attempts" -ForegroundColor White
Write-Host ""

