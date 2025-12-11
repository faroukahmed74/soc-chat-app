# Set Twilio Credentials in .env file
# This script updates the TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in the .env file

$envFile = Join-Path $PSScriptRoot ".env"

# New Twilio Credentials
$newAccountSid = "ACbd7662379a26ed6cde62bfbc8a9a998e"
$newAuthToken = "452e23b1ce6dcae1b9eaf4cb92ae3b4a"

Write-Host "`n[UPDATE] Updating Twilio Credentials in .env file..." -ForegroundColor Cyan
Write-Host "   File: $envFile" -ForegroundColor Gray

if (-not (Test-Path $envFile)) {
    Write-Host "[ERROR] .env file not found at: $envFile" -ForegroundColor Red
    Write-Host "   Creating new .env file..." -ForegroundColor Yellow
    
    # Create new .env file with Twilio credentials
    $newEnvContent = @"
# Twilio TURN Service Configuration
TWILIO_ACCOUNT_SID=$newAccountSid
TWILIO_AUTH_TOKEN=$newAuthToken
CLOUD_TURN_ENABLED=true
CLOUD_TURN_USERNAME=$newAccountSid
CLOUD_TURN_PASSWORD=$newAuthToken
CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp
"@
    $newEnvContent | Out-File -FilePath $envFile -Encoding utf8
    
    Write-Host "[SUCCESS] Created new .env file with Twilio credentials" -ForegroundColor Green
    exit 0
}

# Read existing .env file
$envContent = Get-Content $envFile -Raw

# Update or add TWILIO_ACCOUNT_SID
if ($envContent -match "TWILIO_ACCOUNT_SID\s*=") {
    $envContent = $envContent -replace "TWILIO_ACCOUNT_SID\s*=.*", "TWILIO_ACCOUNT_SID=$newAccountSid"
    Write-Host "[SUCCESS] Updated TWILIO_ACCOUNT_SID" -ForegroundColor Green
} else {
    $envContent += "`nTWILIO_ACCOUNT_SID=$newAccountSid"
    Write-Host "[SUCCESS] Added TWILIO_ACCOUNT_SID" -ForegroundColor Green
}

# Update or add TWILIO_AUTH_TOKEN
if ($envContent -match "TWILIO_AUTH_TOKEN\s*=") {
    $envContent = $envContent -replace "TWILIO_AUTH_TOKEN\s*=.*", "TWILIO_AUTH_TOKEN=$newAuthToken"
    Write-Host "[SUCCESS] Updated TWILIO_AUTH_TOKEN" -ForegroundColor Green
} else {
    $envContent += "`nTWILIO_AUTH_TOKEN=$newAuthToken"
    Write-Host "[SUCCESS] Added TWILIO_AUTH_TOKEN" -ForegroundColor Green
}

# Update or add CLOUD_TURN_USERNAME (for static fallback)
if ($envContent -match "CLOUD_TURN_USERNAME\s*=") {
    $envContent = $envContent -replace "CLOUD_TURN_USERNAME\s*=.*", "CLOUD_TURN_USERNAME=$newAccountSid"
} else {
    $envContent += "`nCLOUD_TURN_USERNAME=$newAccountSid"
}

# Update or add CLOUD_TURN_PASSWORD (for static fallback)
if ($envContent -match "CLOUD_TURN_PASSWORD\s*=") {
    $envContent = $envContent -replace "CLOUD_TURN_PASSWORD\s*=.*", "CLOUD_TURN_PASSWORD=$newAuthToken"
} else {
    $envContent += "`nCLOUD_TURN_PASSWORD=$newAuthToken"
}

# Ensure CLOUD_TURN_ENABLED is set
if (-not ($envContent -match "CLOUD_TURN_ENABLED\s*=")) {
    $envContent += "`nCLOUD_TURN_ENABLED=true"
} elseif ($envContent -match "CLOUD_TURN_ENABLED\s*=\s*false") {
    $envContent = $envContent -replace "CLOUD_TURN_ENABLED\s*=\s*false", "CLOUD_TURN_ENABLED=true"
}

# Ensure CLOUD_TURN_URLS is set
if (-not ($envContent -match "CLOUD_TURN_URLS\s*=")) {
    $envContent += "`nCLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp"
}

# Write updated content back to .env file
$envContent | Out-File -FilePath $envFile -Encoding utf8 -NoNewline

Write-Host "`n[SUCCESS] Twilio credentials updated successfully!" -ForegroundColor Green
Write-Host "   Account SID: $newAccountSid" -ForegroundColor Gray
Write-Host "   Auth Token: $($newAuthToken.Substring(0,8))..." -ForegroundColor Gray
Write-Host "`n[WARNING] IMPORTANT: Restart the API server for changes to take effect!" -ForegroundColor Yellow

