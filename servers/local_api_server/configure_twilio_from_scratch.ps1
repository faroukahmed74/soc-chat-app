# Comprehensive Twilio Configuration Script
# This script configures Twilio TURN service from scratch for the calling system

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Twilio TURN Service Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will configure Twilio TURN service for cross-network calls." -ForegroundColor Yellow
Write-Host ""

# Get Twilio credentials from user
Write-Host "Enter your Twilio credentials:" -ForegroundColor Yellow
Write-Host ""

# Get Account SID
$accountSid = Read-Host "Twilio Account SID (starts with 'AC')"
if ([string]::IsNullOrWhiteSpace($accountSid)) {
    Write-Host "❌ Account SID is required!" -ForegroundColor Red
    exit 1
}

# Validate Account SID format
if ($accountSid.Length -lt 30 -or -not $accountSid.StartsWith("AC")) {
    Write-Host "⚠️  Warning: Account SID format may be invalid" -ForegroundColor Yellow
    Write-Host "   Expected format: AC followed by 32 characters" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Get Auth Token
$authToken = Read-Host "Twilio Auth Token"
if ([string]::IsNullOrWhiteSpace($authToken)) {
    Write-Host "❌ Auth Token is required!" -ForegroundColor Red
    exit 1
}

# Validate Auth Token format
if ($authToken.Length -lt 30) {
    Write-Host "⚠️  Warning: Auth Token format may be invalid" -ForegroundColor Yellow
    Write-Host "   Expected length: 32 characters" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

Write-Host ""
Write-Host "Testing Twilio credentials..." -ForegroundColor Yellow

# Test Twilio credentials using Token API
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
        Write-Host "   ✅ Twilio credentials are valid!" -ForegroundColor Green
        Write-Host "   ✅ Generated $($response.ice_servers.Count) TURN server(s)" -ForegroundColor Green
        
        if ($response.ttl) {
            $expiresIn = (Get-Date).AddSeconds($response.ttl)
            Write-Host "   ✅ Credentials expire at: $($expiresIn.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "   TURN Servers:" -ForegroundColor Cyan
        foreach ($server in $response.ice_servers) {
            $url = $server.url -or $server.urls
            Write-Host "      - $url" -ForegroundColor White
            Write-Host "        Username: $($server.username ? '✅ Present' : '❌ Missing')" -ForegroundColor $(if ($server.username) { "Green" } else { "Red" })
            Write-Host "        Credential: $($server.credential ? '✅ Present' : '❌ Missing')" -ForegroundColor $(if ($server.credential) { "Green" } else { "Red" })
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
Write-Host "Updating .env file..." -ForegroundColor Yellow

# Update .env file
$envFile = "servers\local_api_server\.env"
$envContent = ""

if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    Write-Host "   ✅ Found existing .env file" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  .env file not found, will create new one" -ForegroundColor Yellow
}

# Update or add TWILIO_ACCOUNT_SID
if ($envContent -match "TWILIO_ACCOUNT_SID\s*=") {
    $envContent = $envContent -replace "TWILIO_ACCOUNT_SID\s*=.*", "TWILIO_ACCOUNT_SID=$accountSid"
    Write-Host "   ✅ Updated TWILIO_ACCOUNT_SID" -ForegroundColor Green
} else {
    if ($envContent -and -not $envContent.EndsWith("`n")) {
        $envContent += "`n"
    }
    $envContent += "TWILIO_ACCOUNT_SID=$accountSid`n"
    Write-Host "   ✅ Added TWILIO_ACCOUNT_SID" -ForegroundColor Green
}

# Update or add TWILIO_AUTH_TOKEN
if ($envContent -match "TWILIO_AUTH_TOKEN\s*=") {
    $envContent = $envContent -replace "TWILIO_AUTH_TOKEN\s*=.*", "TWILIO_AUTH_TOKEN=$authToken"
    Write-Host "   ✅ Updated TWILIO_AUTH_TOKEN" -ForegroundColor Green
} else {
    if ($envContent -and -not $envContent.EndsWith("`n")) {
        $envContent += "`n"
    }
    $envContent += "TWILIO_AUTH_TOKEN=$authToken`n"
    Write-Host "   ✅ Added TWILIO_AUTH_TOKEN" -ForegroundColor Green
}

# Update or add CLOUD_TURN_ENABLED
if ($envContent -match "CLOUD_TURN_ENABLED\s*=") {
    $envContent = $envContent -replace "CLOUD_TURN_ENABLED\s*=.*", "CLOUD_TURN_ENABLED=true"
    Write-Host "   ✅ Updated CLOUD_TURN_ENABLED=true" -ForegroundColor Green
} else {
    if ($envContent -and -not $envContent.EndsWith("`n")) {
        $envContent += "`n"
    }
    $envContent += "CLOUD_TURN_ENABLED=true`n"
    Write-Host "   ✅ Added CLOUD_TURN_ENABLED=true" -ForegroundColor Green
}

# Update or add CLOUD_TURN_USERNAME (for static credentials fallback)
# Format: ACCOUNT_SID:AUTH_TOKEN
$staticUsername = "${accountSid}:${authToken}"
if ($envContent -match "CLOUD_TURN_USERNAME\s*=") {
    $envContent = $envContent -replace "CLOUD_TURN_USERNAME\s*=.*", "CLOUD_TURN_USERNAME=$staticUsername"
    Write-Host "   ✅ Updated CLOUD_TURN_USERNAME (static fallback)" -ForegroundColor Green
} else {
    if ($envContent -and -not $envContent.EndsWith("`n")) {
        $envContent += "`n"
    }
    $envContent += "CLOUD_TURN_USERNAME=$staticUsername`n"
    Write-Host "   ✅ Added CLOUD_TURN_USERNAME (static fallback)" -ForegroundColor Green
}

# Update or add CLOUD_TURN_PASSWORD (for static credentials fallback)
if ($envContent -match "CLOUD_TURN_PASSWORD\s*=") {
    $envContent = $envContent -replace "CLOUD_TURN_PASSWORD\s*=.*", "CLOUD_TURN_PASSWORD=$authToken"
    Write-Host "   ✅ Updated CLOUD_TURN_PASSWORD (static fallback)" -ForegroundColor Green
} else {
    if ($envContent -and -not $envContent.EndsWith("`n")) {
        $envContent += "`n"
    }
    $envContent += "CLOUD_TURN_PASSWORD=$authToken`n"
    Write-Host "   ✅ Added CLOUD_TURN_PASSWORD (static fallback)" -ForegroundColor Green
}

# Update or add CLOUD_TURN_URLS (for static credentials fallback)
$turnUrls = "turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp"
if ($envContent -match "CLOUD_TURN_URLS\s*=") {
    $envContent = $envContent -replace "CLOUD_TURN_URLS\s*=.*", "CLOUD_TURN_URLS=$turnUrls"
    Write-Host "   ✅ Updated CLOUD_TURN_URLS (static fallback)" -ForegroundColor Green
} else {
    if ($envContent -and -not $envContent.EndsWith("`n")) {
        $envContent += "`n"
    }
    $envContent += "CLOUD_TURN_URLS=$turnUrls`n"
    Write-Host "   ✅ Added CLOUD_TURN_URLS (static fallback)" -ForegroundColor Green
}

# Save .env file
try {
    $envContent | Set-Content -Path $envFile -Encoding UTF8 -NoNewline
    Write-Host ""
    Write-Host "   ✅ .env file updated successfully" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error saving .env file: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Twilio Account SID: $($accountSid.Substring(0, [Math]::Min(10, $accountSid.Length)))..." -ForegroundColor Green
Write-Host "✅ Twilio Auth Token: $($authToken.Substring(0, [Math]::Min(10, $authToken.Length)))..." -ForegroundColor Green
Write-Host "✅ CLOUD_TURN_ENABLED: true" -ForegroundColor Green
Write-Host "✅ Token API: Configured (RECOMMENDED)" -ForegroundColor Green
Write-Host "✅ Static Credentials: Configured (FALLBACK)" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Configuration Details:" -ForegroundColor Cyan
Write-Host "   - Primary Method: Twilio Token API (generates credentials dynamically)" -ForegroundColor White
Write-Host "   - Fallback Method: Static credentials (if Token API fails)" -ForegroundColor White
Write-Host "   - TURN URLs: global.turn.twilio.com (UDP/TCP)" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  IMPORTANT: Restart your API server for changes to take effect!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Restart your API server (Ctrl+C and restart)" -ForegroundColor White
Write-Host "   2. Test TURN config endpoint: http://localhost:8080/api/webrtc/turn-config" -ForegroundColor White
Write-Host "   3. Rebuild and install APK on devices" -ForegroundColor White
Write-Host "   4. Test cross-network calls" -ForegroundColor White
Write-Host ""

