# SOC Chat App - Check Server Public IP
# This script checks if the server has a public IP address

Write-Host "=== Checking Server Network Configuration ===" -ForegroundColor Cyan

# Get local IP addresses
Write-Host "`nLocal IP Addresses:" -ForegroundColor Yellow
$localIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -ExpandProperty IPAddress
foreach ($ip in $localIPs) {
    Write-Host "  - $ip" -ForegroundColor White
}

# Get public IP
Write-Host "`nPublic IP Address:" -ForegroundColor Yellow
try {
    $publicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 5).Content
    Write-Host "  - $publicIP" -ForegroundColor Green
    Write-Host "`n✅ Server has a public IP address!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  1. Configure router to forward UDP ports 49152-65535 to server" -ForegroundColor White
    Write-Host "  2. Update coturn external-ip to: $publicIP" -ForegroundColor White
    Write-Host "  3. Run firewall configuration script" -ForegroundColor White
} catch {
    Write-Host "  - Could not determine public IP" -ForegroundColor Yellow
    Write-Host "`n⚠️  Server may be behind NAT/firewall" -ForegroundColor Yellow
    Write-Host "`nConsider:" -ForegroundColor Cyan
    Write-Host "  - Using VPN for both devices" -ForegroundColor White
    Write-Host "  - Using cloud TURN service (Twilio, Xirsys)" -ForegroundColor White
    Write-Host "  - Configuring router port forwarding" -ForegroundColor White
}

# Check if ports are accessible
Write-Host "`nChecking TURN port accessibility..." -ForegroundColor Yellow
$testPort = 3478
try {
    $listener = [System.Net.Sockets.UdpClient]::new($testPort)
    Write-Host "  - Port $testPort is available for binding" -ForegroundColor Green
    $listener.Close()
} catch {
    Write-Host "  - Port $testPort may be in use or blocked" -ForegroundColor Yellow
}

Write-Host "`n=== Network Check Complete ===" -ForegroundColor Cyan

