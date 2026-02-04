# Complete Twilio Reconfiguration Script
# This script reconfigures Twilio from scratch using existing credentials

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete Twilio Reconfiguration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get credentials from existing SET_TWILIO_CREDENTIALS.ps1 or use provided ones
$credentialsScript = Join-Path $PSScriptRoot "SET_TWILIO_CREDENTIALS.ps1"
$accountSid = $null
$authToken = $null

if (Test-Path $credentialsScript) {
    Write-Host "Reading credentials from SET_TWILIO_CREDENTIALS.ps1..." -ForegroundColor Yellow
    $scriptContent = Get-Content $credentialsScript -Raw
    
    if ($scriptContent -match '\$newAccountSid\s*=\s*"([^"]+)"') {
        $accountSid = $matches[1]
        Write-Host "   ✅ Found Account SID: $($accountSid.Substring(0, [Math]::Min(10, $accountSid.Length)))..." -ForegroundColor Green
    }
    
    if ($scriptContent -match '\$newAuthToken\s*=\s*"([^"]+)"') {
        $authToken = $matches[1]
        Write-Host "   ✅ Found Auth Token: $($authToken.Substring(0, [Math]::Min(10, $authToken.Length)))..." -ForegroundColor Green
    }
}

# If credentials not found, prompt user
if (-not $accountSid -or -not $authToken) {
    Write-Host ""
    Write-Host "Credentials not found in SET_TWILIO_CREDENTIALS.ps1" -ForegroundColor Yellow
    Write-Host "Please enter your Twilio credentials:" -ForegroundColor Yellow
    Write-Host ""
    
    if (-not $accountSid) {
        $accountSid = Read-Host "Twilio Account SID (starts with 'AC')"
    }
    
    if (-not $authToken) {
        $authToken = Read-Host "Twilio Auth Token"
    }
}

if ([string]::IsNullOrWhiteSpace($accountSid) -or [string]::IsNullOrWhiteSpace($authToken)) {
    Write-Host "❌ Account SID and Auth Token are required!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 1: Testing Twilio credentials..." -ForegroundColor Cyan

# Test Twilio credentials
try {
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${accountSid}:${authToken}"))
    $headers = @{
        "Authorization" = "Basic $auth"
        "Content-Type" = "application/x-www-form-urlencoded"
    }
    
    $uri = "https://api.twilio.com/2010-04-01/Accounts/$accountSid/Tokens.json"
    
    Write-Host "   Making request to Twilio Token API..." -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -TimeoutSec 10 -ErrorAction Stop
    
    if ($response.ice_servers -and $response.ice_servers.Count -gt 0) {
        Write-Host "   ✅ Twilio credentials are VALID!" -ForegroundColor Green
        Write-Host "   ✅ Generated $($response.ice_servers.Count) TURN server(s)" -ForegroundColor Green
        
        if ($response.ttl) {
            $expiresIn = (Get-Date).AddSeconds($response.ttl)
            Write-Host "   ✅ Credentials expire at: $($expiresIn.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "   TURN Servers from Token API:" -ForegroundColor Cyan
        foreach ($server in $response.ice_servers) {
            $url = if ($server.url) { $server.url } else { $server.urls }
            Write-Host "      - $url" -ForegroundColor White
        }
    } else {
        Write-Host "   ❌ Twilio API returned no TURN servers" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ❌ Error testing Twilio credentials: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "   ⚠️  Authentication failed - check your Account SID and Auth Token" -ForegroundColor Yellow
    } elseif ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "   ⚠️  Account not found - check your Account SID" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host ""
Write-Host "Step 2: Updating .env file..." -ForegroundColor Cyan

# Update .env file
$envFile = Join-Path $PSScriptRoot ".env"
$envContent = ""

if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    Write-Host "   ✅ Found existing .env file" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  .env file not found, will create new one" -ForegroundColor Yellow
}

# Remove all existing Twilio-related entries
$envContent = $envContent -replace "TWILIO_ACCOUNT_SID\s*=.*\r?\n", ""
$envContent = $envContent -replace "TWILIO_AUTH_TOKEN\s*=.*\r?\n", ""
$envContent = $envContent -replace "CLOUD_TURN_ENABLED\s*=.*\r?\n", ""
$envContent = $envContent -replace "CLOUD_TURN_USERNAME\s*=.*\r?\n", ""
$envContent = $envContent -replace "CLOUD_TURN_PASSWORD\s*=.*\r?\n", ""
$envContent = $envContent -replace "CLOUD_TURN_URLS\s*=.*\r?\n", ""

# Add Twilio configuration
if ($envContent -and -not $envContent.EndsWith("`n") -and -not $envContent.EndsWith("`r`n")) {
    $envContent += "`n"
}

$envContent += "# Twilio TURN Service Configuration (Reconfigured)`n"
$envContent += "TWILIO_ACCOUNT_SID=$accountSid`n"
$envContent += "TWILIO_AUTH_TOKEN=$authToken`n"
$envContent += "CLOUD_TURN_ENABLED=true`n"
$envContent += "# Static credentials fallback (format: ACCOUNT_SID:AUTH_TOKEN)`n"
$envContent += "CLOUD_TURN_USERNAME=${accountSid}:${authToken}`n"
$envContent += "CLOUD_TURN_PASSWORD=$authToken`n"
$envContent += "CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp`n"

# Save .env file
try {
    $envContent | Set-Content -Path $envFile -Encoding UTF8 -NoNewline
    Write-Host "   ✅ .env file updated successfully" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error saving .env file: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Verifying configuration..." -ForegroundColor Cyan

# Verify the configuration was saved correctly
$verifyContent = Get-Content $envFile -Raw
$hasAccountSid = $verifyContent -match "TWILIO_ACCOUNT_SID\s*=\s*$([regex]::Escape($accountSid))"
$hasAuthToken = $verifyContent -match "TWILIO_AUTH_TOKEN\s*=\s*$([regex]::Escape($authToken))"
$hasCloudTurnEnabled = $verifyContent -match "CLOUD_TURN_ENABLED\s*=\s*true"

if ($hasAccountSid -and $hasAuthToken -and $hasCloudTurnEnabled) {
    Write-Host "   ✅ All Twilio settings verified in .env file" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Some settings may not be correctly saved" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 4: Testing server endpoint (if server is running)..." -ForegroundColor Cyan

try {
    $serverUrl = "http://localhost:8080"
    $response = Invoke-WebRequest -Uri "$serverUrl/api/webrtc/turn-config" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
    
    if ($response.StatusCode -eq 200) {
        $turnConfig = $response.Content | ConvertFrom-Json
        
        if ($turnConfig.success -eq $true) {
            $twilioServers = $turnConfig.turnServers | Where-Object { $_.urls -match "twilio\.com" }
            if ($twilioServers) {
                Write-Host "   ✅ Server endpoint returns Twilio TURN servers!" -ForegroundColor Green
                Write-Host "   ✅ Found $($twilioServers.Count) Twilio TURN server(s)" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Server endpoint does not return Twilio servers yet" -ForegroundColor Yellow
                Write-Host "   💡 Restart the API server for changes to take effect" -ForegroundColor Cyan
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Server not running or not accessible (this is OK if server is stopped)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Reconfiguration Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Twilio Account SID: $($accountSid.Substring(0, [Math]::Min(10, $accountSid.Length)))..." -ForegroundColor Green
Write-Host "✅ Twilio Auth Token: $($authToken.Substring(0, [Math]::Min(10, $authToken.Length)))..." -ForegroundColor Green
Write-Host "✅ CLOUD_TURN_ENABLED: true" -ForegroundColor Green
Write-Host "✅ Token API: Tested and working" -ForegroundColor Green
Write-Host "✅ Static Credentials: Configured (fallback)" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Configuration Method:" -ForegroundColor Cyan
Write-Host "   - Primary: Twilio Token API (dynamic credentials)" -ForegroundColor White
Write-Host "   - Fallback: Static credentials (if Token API fails)" -ForegroundColor White
Write-Host ""
Write-Host "CRITICAL: Restart your API server for changes to take effect!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Restart API server (Ctrl+C and restart)" -ForegroundColor White
Write-Host "   2. Verify: .\verify_twilio_config.ps1" -ForegroundColor White
Write-Host "   3. Test endpoint: http://localhost:8080/api/webrtc/turn-config" -ForegroundColor White
Write-Host "   4. Rebuild APK and test cross-network calls" -ForegroundColor White
Write-Host ""

