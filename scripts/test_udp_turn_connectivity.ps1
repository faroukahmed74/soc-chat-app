# UDP Connectivity Test for TURN Servers
# This script tests UDP connectivity to Twilio TURN servers

Write-Host "Testing UDP connectivity to Twilio TURN servers..."
Write-Host ""

$twilioServers = @(
    @{Host="global.turn.twilio.com"; Port=3478},
    @{Host="52.59.186.19"; Port=3478}
)

foreach ($server in $twilioServers) {
    Write-Host "Testing $($server.Host):$($server.Port) (UDP)..." -ForegroundColor Cyan
    
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Client.ReceiveTimeout = 3000
        $udpClient.Client.SendTimeout = 3000
        
        # Try to send a test packet (STUN binding request)
        $stunRequest = [byte[]](0x00, 0x01, 0x00, 0x00, 0x21, 0x12, 0xA4, 0x42)
        $endpoint = New-Object System.Net.IPEndPoint([System.Net.Dns]::GetHostAddresses($server.Host)[0], $server.Port)
        
        $bytesSent = $udpClient.Send($stunRequest, $stunRequest.Length, $endpoint)
        Write-Host "  [OK] Sent $bytesSent bytes to $($server.Host):$($server.Port)" -ForegroundColor Green
        
        # Try to receive response
        try {
            $response = $udpClient.Receive([ref]$endpoint)
            Write-Host "  [OK] Received response from $($endpoint.Address):$($endpoint.Port)" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] No response received (may be blocked or server doesn't respond to test)" -ForegroundColor Yellow
        }
        
        $udpClient.Close()
    } catch {
        Write-Host "  [ERROR] UDP test failed: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Note: UDP is connectionless, so lack of response doesn't always mean blocking."
Write-Host "For accurate testing, use trickle-ice.webrtc.github.io from mobile devices."
