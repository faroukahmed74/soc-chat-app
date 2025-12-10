# SOC Chat App - Test TURN Server Ports
# Tests if TURN server ports are accessible

param(
    [string]$ServerIP = "41.33.106.54",
    [int]$ControlPort = 3478,
    [int]$MinRelayPort = 50000,
    [int]$MaxRelayPort = 50100
)

Write-Host "=== Testing TURN Server Ports ===" -ForegroundColor Cyan
Write-Host "Server IP: $ServerIP" -ForegroundColor White
Write-Host ""

# Test TCP port (TURN control)
Write-Host "Testing TCP port $ControlPort (TURN control)..." -ForegroundColor Yellow
try {
    $tcpTest = Test-NetConnection -ComputerName $ServerIP -Port $ControlPort -InformationLevel Quiet
    if ($tcpTest) {
        Write-Host "  ✅ TCP port $ControlPort is accessible" -ForegroundColor Green
    } else {
        Write-Host "  ❌ TCP port $ControlPort is NOT accessible" -ForegroundColor Red
        Write-Host "     Check router port forwarding and firewall" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Error testing TCP port: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Note about UDP testing
Write-Host "Testing UDP ports..." -ForegroundColor Yellow
Write-Host "  ⚠️  PowerShell Test-NetConnection doesn't support UDP testing" -ForegroundColor Yellow
Write-Host "  Use one of these methods:" -ForegroundColor White
Write-Host ""
Write-Host "  Option 1: Use online port checker:" -ForegroundColor Cyan
Write-Host "    https://www.yougetsignal.com/tools/open-ports/" -ForegroundColor White
Write-Host "    Enter: $ServerIP" -ForegroundColor White
Write-Host "    Ports: $ControlPort (UDP), $MinRelayPort-$MaxRelayPort (UDP)" -ForegroundColor White
Write-Host ""
Write-Host "  Option 2: Use nmap (if installed):" -ForegroundColor Cyan
Write-Host "    nmap -sU -p $ControlPort,$MinRelayPort-$MaxRelayPort $ServerIP" -ForegroundColor White
Write-Host ""
Write-Host "  Option 3: Test from mobile device:" -ForegroundColor Cyan
Write-Host "    Make a call and check logs for RELAY candidates" -ForegroundColor White
Write-Host ""

# Check if coturn is running
Write-Host "Checking coturn container..." -ForegroundColor Yellow
try {
    $coturn = docker ps --filter "name=soc-chat-coturn" --format "{{.Names}}"
    if ($coturn) {
        Write-Host "  ✅ coturn container is running: $coturn" -ForegroundColor Green
    } else {
        Write-Host "  ❌ coturn container is NOT running" -ForegroundColor Red
        Write-Host "     Start it: cd scripts && docker-compose -f coturn-docker-compose.yml up -d" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Docker not available or coturn not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Port Test Complete ===" -ForegroundColor Cyan

