# PowerShell script to verify TURN credentials are configured correctly

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TURN Credentials Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check .env file
Write-Host "Step 1: Checking .env file..." -ForegroundColor Yellow
$envPath = Join-Path $PSScriptRoot ".env"
if (Test-Path $envPath) {
    Write-Host "  .env file exists" -ForegroundColor Green
    
    $envContent = Get-Content $envPath -Raw
    $hasTwilioAccountSid = $envContent -match "TWILIO_ACCOUNT_SID="
    $hasTwilioAuthToken = $envContent -match "TWILIO_AUTH_TOKEN="
    $hasCloudTurnEnabled = $envContent -match "CLOUD_TURN_ENABLED=true"
    $hasCloudTurnUrls = $envContent -match "CLOUD_TURN_URLS="
    
    Write-Host "  TWILIO_ACCOUNT_SID: $(if ($hasTwilioAccountSid) { 'SET' } else { 'MISSING' })" -ForegroundColor $(if ($hasTwilioAccountSid) { "Green" } else { "Red" })
    Write-Host "  TWILIO_AUTH_TOKEN: $(if ($hasTwilioAuthToken) { 'SET' } else { 'MISSING' })" -ForegroundColor $(if ($hasTwilioAuthToken) { "Green" } else { "Red" })
    Write-Host "  CLOUD_TURN_ENABLED: $(if ($hasCloudTurnEnabled) { 'true' } else { 'false' })" -ForegroundColor $(if ($hasCloudTurnEnabled) { "Green" } else { "Yellow" })
    Write-Host "  CLOUD_TURN_URLS: $(if ($hasCloudTurnUrls) { 'SET' } else { 'MISSING' })" -ForegroundColor $(if ($hasCloudTurnUrls) { "Green" } else { "Red" })
} else {
    Write-Host "  .env file NOT FOUND!" -ForegroundColor Red
    Write-Host "  Run .\SET_TWILIO_ENV.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Test TURN config endpoint
Write-Host "Step 2: Testing TURN config endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3003/api/webrtc/turn-config" -Method GET -UseBasicParsing -ErrorAction Stop
    $json = $response.Content | ConvertFrom-Json
    
    Write-Host "  Endpoint responded successfully" -ForegroundColor Green
    Write-Host "  Response success: $($json.success)" -ForegroundColor $(if ($json.success) { "Green" } else { "Red" })
    
    if ($json.turnServers) {
        Write-Host "  TURN servers count: $($json.turnServers.Count)" -ForegroundColor Green
        
        $turnServerCount = 0
        $stunServerCount = 0
        $serversWithCredentials = 0
        $serversWithoutCredentials = 0
        
        foreach ($server in $json.turnServers) {
            $urls = $server.urls
            if ($urls -like "turn:*" -or $urls -like "turns:*") {
                $turnServerCount++
                if ($server.username -and $server.credential) {
                    $serversWithCredentials++
                    Write-Host "    TURN: $urls" -ForegroundColor Green
                    Write-Host "      Username: $($server.username) ($($server.username.Length) chars)" -ForegroundColor White
                    Write-Host "      Credential: $($server.credential) ($($server.credential.Length) chars)" -ForegroundColor White
                } else {
                    $serversWithoutCredentials++
                    Write-Host "    TURN: $urls" -ForegroundColor Red
                    Write-Host "      CRITICAL: Missing credentials!" -ForegroundColor Red
                }
            } elseif ($urls -like "stun:*") {
                $stunServerCount++
                Write-Host "    STUN: $urls (no credentials needed)" -ForegroundColor Cyan
            }
        }
        
        Write-Host ""
        Write-Host "  Summary:" -ForegroundColor Yellow
        Write-Host "    TURN servers: $turnServerCount" -ForegroundColor White
        Write-Host "    STUN servers: $stunServerCount" -ForegroundColor White
        Write-Host "    TURN servers WITH credentials: $serversWithCredentials" -ForegroundColor $(if ($serversWithCredentials -gt 0) { "Green" } else { "Red" })
        Write-Host "    TURN servers WITHOUT credentials: $serversWithoutCredentials" -ForegroundColor $(if ($serversWithoutCredentials -eq 0) { "Green" } else { "Red" })
        
        if ($serversWithCredentials -eq 0 -and $turnServerCount -gt 0) {
            Write-Host ""
            Write-Host "  CRITICAL: TURN servers exist but have NO credentials!" -ForegroundColor Red
            Write-Host "  This will prevent cross-network calls from working." -ForegroundColor Red
        } elseif ($serversWithCredentials -gt 0) {
            Write-Host ""
            Write-Host "  SUCCESS: TURN servers have credentials configured!" -ForegroundColor Green
        }
    } else {
        Write-Host "  ERROR: No turnServers in response!" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERROR: Could not reach TURN config endpoint" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Make sure the API server is running on port 3003" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

