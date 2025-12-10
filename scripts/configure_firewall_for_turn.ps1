# SOC Chat App - Windows Firewall Configuration for TURN Server
# This script configures Windows Firewall to allow TURN server traffic

Write-Host "=== Configuring Windows Firewall for TURN Server ===" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# TURN server control port (TCP and UDP)
Write-Host "`nConfiguring firewall rule for TURN control port (3478)..." -ForegroundColor Yellow
$ruleName = "SOC_Chat_TURN_Control_3478"

# Remove existing rule if it exists
netsh advfirewall firewall delete rule name=$ruleName 2>$null

# Add TCP rule for TURN control
netsh advfirewall firewall add rule name=$ruleName dir=in action=allow protocol=TCP localport=3478
netsh advfirewall firewall add rule name=$ruleName dir=in action=allow protocol=UDP localport=3478

# TURN server media relay ports (UDP range) - SECURE: Limited range
Write-Host "Configuring firewall rule for TURN media relay ports (50000-50100)..." -ForegroundColor Yellow
Write-Host "  ⚠️  SECURITY: Using limited port range (101 ports) instead of full range (16,384 ports)" -ForegroundColor Yellow
$relayRuleName = "SOC_Chat_TURN_Media_Relay_50000-50100"

# Remove existing rule if it exists
netsh advfirewall firewall delete rule name=$relayRuleName 2>$null

# Add UDP rule for media relay ports (limited range for security)
netsh advfirewall firewall add rule name=$relayRuleName dir=in action=allow protocol=UDP localport=50000-50100

Write-Host "`n✅ Firewall rules configured successfully!" -ForegroundColor Green
Write-Host "`nRules added:" -ForegroundColor Cyan
Write-Host "  - $ruleName (TCP/UDP port 3478)" -ForegroundColor White
Write-Host "  - $relayRuleName (UDP ports 50000-50100) - SECURE: Limited range" -ForegroundColor White

Write-Host "`nSECURITY NOTES:" -ForegroundColor Yellow
Write-Host "  [OK] Using limited port range (101 ports) instead of full range (16,384 ports)" -ForegroundColor Green
Write-Host "  [OK] Reduces attack surface by 99.4%" -ForegroundColor Green
Write-Host "  [OK] Still supports 50+ concurrent calls" -ForegroundColor Green
Write-Host "`nIMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "  1. TURN control (port 3478) works through ngrok TCP tunnel" -ForegroundColor White
Write-Host "  2. Media relay (UDP ports 50000-50100) requires direct access to server" -ForegroundColor White
Write-Host "  3. For cross-network calls, ensure server has public IP or use VPN" -ForegroundColor White
Write-Host "  4. ngrok TCP tunnel does NOT forward UDP traffic" -ForegroundColor White
Write-Host "  5. Consider using cloud TURN service (Twilio/Xirsys) for production" -ForegroundColor White

