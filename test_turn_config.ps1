$response = Invoke-WebRequest -Uri "http://localhost:3003/api/webrtc/turn-config" -Method GET -UseBasicParsing -ErrorAction SilentlyContinue
if ($response) {
    $data = $response.Content | ConvertFrom-Json
    Write-Host "
 TURN Configuration Analysis:" -ForegroundColor Cyan
    Write-Host "   Success: $($data.success)" -ForegroundColor White
    Write-Host "   Total TURN Servers: $($data.turnServers.Count)" -ForegroundColor White
    
    $cloudCount = 0
    $ngrokCount = 0
    $localCount = 0
    $publicCount = 0
    
    foreach ($server in $data.turnServers) {
        $url = $server.urls
        if ($url -match "twilio\.com|turn\.twilio\.com") { $cloudCount++ }
        elseif ($url -match "ngrok") { $ngrokCount++ }
        elseif ($url -match "10\.120\.4\.230|192\.168") { $localCount++ }
        elseif ($url -match "41\.33\.106\.54") { $publicCount++ }
    }
    
    Write-Host "
 TURN Server Breakdown:" -ForegroundColor Yellow
    Write-Host "   Cloud TURN (Twilio): $cloudCount" -ForegroundColor 
    Write-Host "   ngrok TURN: $ngrokCount" -ForegroundColor White
    Write-Host "   Local IP TURN: $localCount" -ForegroundColor White
    Write-Host "   Public IP TURN: $publicCount" -ForegroundColor White
    
    if ($cloudCount -eq 0) {
        Write-Host "
 CRITICAL: No Cloud TURN servers found!" -ForegroundColor Red
        Write-Host "   This means Twilio TURN is not being returned by the server" -ForegroundColor Yellow
    } else {
        Write-Host "
 Cloud TURN servers are being returned" -ForegroundColor Green
    }
}
