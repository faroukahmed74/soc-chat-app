# Switch from Cloud TURN to Docker coturn
# This script disables cloud TURN and enables Docker coturn for testing

$envFile = Join-Path $PSScriptRoot ".env"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Switch to Docker coturn" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $envFile)) {
    Write-Host "[ERROR] .env file not found at: $envFile" -ForegroundColor Red
    Write-Host "   Creating new .env file..." -ForegroundColor Yellow
    
    # Create new .env file with Docker coturn enabled
    $newEnvContent = @"
# Docker coturn Configuration (Cloud TURN disabled)
CLOUD_TURN_ENABLED=false
"@
    $newEnvContent | Out-File -FilePath $envFile -Encoding utf8
    
    Write-Host "[SUCCESS] Created new .env file with Docker coturn enabled" -ForegroundColor Green
} else {
    # Read existing .env file
    $envContent = Get-Content $envFile -Raw
    
    # Update CLOUD_TURN_ENABLED to false
    if ($envContent -match "CLOUD_TURN_ENABLED\s*=") {
        $envContent = $envContent -replace "CLOUD_TURN_ENABLED\s*=.*", "CLOUD_TURN_ENABLED=false"
        Write-Host "[UPDATE] Set CLOUD_TURN_ENABLED=false" -ForegroundColor Yellow
    } else {
        $envContent = $envContent + "`nCLOUD_TURN_ENABLED=false"
        Write-Host "[ADD] Added CLOUD_TURN_ENABLED=false" -ForegroundColor Green
    }
    
    # Write updated content back to .env file
    $envContent | Out-File -FilePath $envFile -Encoding utf8 -NoNewline
}

Write-Host ""
Write-Host "Docker coturn is now enabled!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT REQUIREMENTS:" -ForegroundColor Yellow
Write-Host "   1. Router port forwarding REQUIRED for cross-network calls:" -ForegroundColor Yellow
Write-Host "      - UDP 3478 (TURN control)" -ForegroundColor White
Write-Host "      - UDP 50000-50100 (Media relay ports)" -ForegroundColor White
Write-Host "   2. Forward these ports to server IP: 10.120.4.230" -ForegroundColor White
Write-Host "   3. Docker coturn is already running and configured" -ForegroundColor White
Write-Host ""
Write-Host "Docker coturn Configuration:" -ForegroundColor Cyan
Write-Host "   - Public IP: 41.33.106.54" -ForegroundColor White
Write-Host "   - Port: 3478" -ForegroundColor White
Write-Host "   - Username: soc-chat-turn" -ForegroundColor White
Write-Host "   - Password: yG5EJFUdLgT7xqXr" -ForegroundColor White
Write-Host "   - Media relay ports: 50000-50100" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Configure router port forwarding (if you have router access)" -ForegroundColor White
Write-Host "   2. Restart the API server for changes to take effect" -ForegroundColor White
Write-Host "   3. Test cross-network calls" -ForegroundColor White
Write-Host ""
Write-Host "WARNING: If you do not have router access, Docker coturn will NOT work for cross-network calls." -ForegroundColor Red
Write-Host "   In that case, you must use cloud TURN (Twilio) instead." -ForegroundColor Red
Write-Host ""
