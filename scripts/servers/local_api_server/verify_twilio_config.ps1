# Verify Twilio Configuration
# This script verifies that Twilio is properly configured and working

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Twilio Configuration Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$envFile = "servers\local_api_server\.env"
$issues = @()
$warnings = @()
$success = @()

# 1. Check .env file exists
Write-Host "1. Checking .env file..." -ForegroundColor Yellow
if (Test-Path $envFile) {
    Write-Host "   ✅ .env file exists" -ForegroundColor Green
    $success += ".env file exists"
} else {
    Write-Host "   ❌ .env file not found at $envFile" -ForegroundColor Red
    $issues += ".env file not found"
    Write-Host ""
    Write-Host "   Run configure_twilio_from_scratch.ps1 to create configuration" -ForegroundColor Yellow
    exit 1
}

# 2. Check environment variables
Write-Host ""
Write-Host "2. Checking environment variables..." -ForegroundColor Yellow
$envContent = Get-Content $envFile -Raw

# Check TWILIO_ACCOUNT_SID
if ($envContent -match "TWILIO_ACCOUNT_SID\s*=\s*(.+)") {
    $accountSid = $matches[1].Trim()
    if ($accountSid -and $accountSid.Length -ge 30 -and $accountSid.StartsWith("AC")) {
        Write-Host "   ✅ TWILIO_ACCOUNT_SID: $($accountSid.Substring(0, [Math]::Min(10, $accountSid.Length)))..." -ForegroundColor Green
        $success += "TWILIO_ACCOUNT_SID is configured"
    } else {
        Write-Host "   ⚠️  TWILIO_ACCOUNT_SID format may be invalid" -ForegroundColor Yellow
        $warnings += "TWILIO_ACCOUNT_SID format validation"
    }
} else {
    Write-Host "   ❌ TWILIO_ACCOUNT_SID not found" -ForegroundColor Red
    $issues += "TWILIO_ACCOUNT_SID not configured"
}

# Check TWILIO_AUTH_TOKEN
if ($envContent -match "TWILIO_AUTH_TOKEN\s*=\s*(.+)") {
    $authToken = $matches[1].Trim()
    if ($authToken -and $authToken.Length -ge 30) {
        Write-Host "   ✅ TWILIO_AUTH_TOKEN: $($authToken.Substring(0, [Math]::Min(10, $authToken.Length)))..." -ForegroundColor Green
        $success += "TWILIO_AUTH_TOKEN is configured"
    } else {
        Write-Host "   ⚠️  TWILIO_AUTH_TOKEN format may be invalid" -ForegroundColor Yellow
        $warnings += "TWILIO_AUTH_TOKEN format validation"
    }
} else {
    Write-Host "   ❌ TWILIO_AUTH_TOKEN not found" -ForegroundColor Red
    $issues += "TWILIO_AUTH_TOKEN not configured"
}

# Check CLOUD_TURN_ENABLED
if ($envContent -match "CLOUD_TURN_ENABLED\s*=\s*(.+)") {
    $cloudTurnEnabled = $matches[1].Trim().ToLower()
    if ($cloudTurnEnabled -eq "true") {
        Write-Host "   ✅ CLOUD_TURN_ENABLED: true" -ForegroundColor Green
        $success += "CLOUD_TURN_ENABLED is set to true"
    } else {
        Write-Host "   ⚠️  CLOUD_TURN_ENABLED: $cloudTurnEnabled (should be 'true')" -ForegroundColor Yellow
        $warnings += "CLOUD_TURN_ENABLED is not set to true"
    }
} else {
    Write-Host "   ⚠️  CLOUD_TURN_ENABLED not found (will default to false)" -ForegroundColor Yellow
    $warnings += "CLOUD_TURN_ENABLED not configured"
}

# 3. Test Twilio Token API
Write-Host ""
Write-Host "3. Testing Twilio Token API..." -ForegroundColor Yellow
if ($accountSid -and $authToken) {
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
            Write-Host "   ✅ Twilio Token API is working!" -ForegroundColor Green
            Write-Host "   ✅ Generated $($response.ice_servers.Count) TURN server(s)" -ForegroundColor Green
            
            if ($response.ttl) {
                $expiresIn = (Get-Date).AddSeconds($response.ttl)
                Write-Host "   ✅ Credentials expire at: $($expiresIn.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
            }
            
            Write-Host ""
            Write-Host "   TURN Servers from Token API:" -ForegroundColor Cyan
            foreach ($server in $response.ice_servers) {
                $url = if ($server.url) { $server.url } else { $server.urls }
                $hasUsername = if ($server.username) { $true } else { $false }
                $hasCredential = if ($server.credential) { $true } else { $false }
                $usernameText = if ($hasUsername) { "✅ Present" } else { "❌ Missing" }
                $credentialText = if ($hasCredential) { "✅ Present" } else { "❌ Missing" }
                $usernameColor = if ($hasUsername) { "Green" } else { "Red" }
                $credentialColor = if ($hasCredential) { "Green" } else { "Red" }
                Write-Host "      - $url" -ForegroundColor White
                Write-Host "        Username: $usernameText" -ForegroundColor $usernameColor
                Write-Host "        Credential: $credentialText" -ForegroundColor $credentialColor
            }
            
            $success += "Twilio Token API is working"
        } else {
            Write-Host "   ❌ Twilio API returned no TURN servers" -ForegroundColor Red
            $issues += "Twilio Token API returned no TURN servers"
        }
    } catch {
        Write-Host "   ❌ Error testing Twilio Token API: $_" -ForegroundColor Red
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "   ⚠️  Authentication failed - check your credentials" -ForegroundColor Yellow
            $issues += "Twilio authentication failed (401)"
        } elseif ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "   ⚠️  Account not found - check your Account SID" -ForegroundColor Yellow
            $issues += "Twilio account not found (404)"
        } else {
            $issues += "Twilio Token API test failed"
        }
    }
} else {
    Write-Host "   ⚠️  Cannot test - credentials not configured" -ForegroundColor Yellow
    $warnings += "Cannot test Twilio Token API (credentials missing)"
}

# 4. Check server TURN config endpoint
Write-Host ""
Write-Host "4. Checking server TURN config endpoint..." -ForegroundColor Yellow
try {
    $serverUrl = "http://localhost:8080"
    $response = Invoke-WebRequest -Uri "$serverUrl/api/webrtc/turn-config" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
    
    if ($response.StatusCode -eq 200) {
        $turnConfig = $response.Content | ConvertFrom-Json
        
        if ($turnConfig.success -eq $true) {
            Write-Host "   ✅ TURN config endpoint is accessible" -ForegroundColor Green
            Write-Host "   ✅ Returns $($turnConfig.turnServers.Count) TURN server(s)" -ForegroundColor Green
            
            # Check if Twilio servers are in response
            $hasTwilio = $turnConfig.turnServers | Where-Object { $_.urls -match "twilio\.com" }
            if ($hasTwilio) {
                Write-Host "   ✅ Twilio TURN servers found in response" -ForegroundColor Green
                $success += "Server returns Twilio TURN servers"
                
                Write-Host ""
                Write-Host "   TURN Servers from endpoint:" -ForegroundColor Cyan
                foreach ($server in $turnConfig.turnServers) {
                    $url = $server.urls
                    $isTwilio = $url -match "twilio\.com"
                $urlColor = if ($isTwilio) { "Green" } else { "White" }
                $typeText = if ($isTwilio) { "Twilio (Cloud TURN)" } else { "Other" }
                $typeColor = if ($isTwilio) { "Green" } else { "Yellow" }
                Write-Host "      - $url" -ForegroundColor $urlColor
                Write-Host "        Type: $typeText" -ForegroundColor $typeColor
                }
            } else {
                Write-Host "   ⚠️  Twilio TURN servers NOT found in response" -ForegroundColor Yellow
                $warnings += "Server response does not contain Twilio TURN servers"
            }
        } else {
            Write-Host "   ⚠️  TURN config endpoint returned success=false" -ForegroundColor Yellow
            $warnings += "TURN config endpoint returned error"
        }
    } else {
        Write-Host "   ⚠️  TURN config endpoint returned status $($response.StatusCode)" -ForegroundColor Yellow
        $warnings += "TURN config endpoint not accessible"
    }
} catch {
    Write-Host "   ⚠️  Server is not running or not accessible: $_" -ForegroundColor Yellow
    Write-Host "   💡 Start your API server and try again" -ForegroundColor Cyan
    $warnings += "Server not accessible"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($success.Count -gt 0) {
    Write-Host "✅ Success ($($success.Count)):" -ForegroundColor Green
    $success | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Green
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠️  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($issues.Count -gt 0) {
    Write-Host "❌ Issues ($($issues.Count)):" -ForegroundColor Red
    $issues | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Red
    }
    Write-Host ""
}

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✅ All checks passed! Twilio is properly configured." -ForegroundColor Green
} elseif ($issues.Count -eq 0) {
    Write-Host "⚠️  Some warnings found, but configuration should work." -ForegroundColor Yellow
} else {
    Write-Host "❌ Critical issues found! Fix these before using Twilio TURN." -ForegroundColor Red
}

Write-Host ""

