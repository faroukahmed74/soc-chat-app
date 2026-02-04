# Start self-hosted TURN server (coturn) via Docker
# Optional: Twilio TURN in .env is enough for most calls.
# Requires: Docker installed and running

$compose = Join-Path $PSScriptRoot "coturn-docker-compose.yml"
if (-not (Test-Path $compose)) {
    Write-Host "coturn-docker-compose.yml not found" -ForegroundColor Red
    exit 1
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Host "Docker not found. Install from https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    Write-Host "Calls still work via Twilio TURN (CLOUD_TURN_* in .env)" -ForegroundColor Cyan
    exit 1
}

Write-Host "Starting coturn TURN server..." -ForegroundColor Cyan
Push-Location $PSScriptRoot
try {
    docker-compose -f coturn-docker-compose.yml up -d
    if ($LASTEXITCODE -eq 0) {
        Write-Host "coturn started (port 3478)" -ForegroundColor Green
    } else {
        Write-Host "Failed to start coturn" -ForegroundColor Red
    }
} finally {
    Pop-Location
}
