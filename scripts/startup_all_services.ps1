# =============================================================================
# SOC Chat App - Startup All Services
# =============================================================================
# This script starts all services in the correct order at system startup
# Runs even when user is not logged in
# =============================================================================

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent $PSScriptRoot

# Log file for startup
$logFile = Join-Path $projectRoot "logs\startup.log"
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

Write-Log "========================================"
Write-Log "SOC Chat App - Starting Services"
Write-Log "========================================"

# Step 1: Start Web Server (servers/server.js)
Write-Log "Step 1/3: Starting Web Server (servers/server.js)..."
try {
    $webServerDir = Join-Path $projectRoot "servers"
    $webCommand = 'cmd /c "set PORT=8082 && set API_TARGET=http://localhost:3003 && node server.js"'
    $webServerProcess = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-Command", $webCommand `
        -WorkingDirectory $webServerDir `
        -WindowStyle Hidden `
        -PassThru
    
    if ($webServerProcess) {
        Write-Log "  [OK] Web Server started (PID: $($webServerProcess.Id))"
        Start-Sleep -Seconds 3  # Wait for server to initialize
    } else {
        Write-Log "  [ERROR] Failed to start Web Server"
    }
} catch {
    Write-Log "  [ERROR] Web Server error: $_"
}

# Step 2: Start API Server (servers/local_api_server/server.js)
Write-Log "Step 2/3: Starting API Server (servers/local_api_server/server.js)..."
try {
    $apiServerDir = Join-Path $projectRoot "servers\local_api_server"
    $apiCommand = 'cmd /c "set PORT=3003 && set HOST=0.0.0.0 && node server.js"'
    $apiServerProcess = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-WindowStyle Hidden", "-NoProfile", "-Command", $apiCommand `
        -WorkingDirectory $apiServerDir `
        -WindowStyle Hidden `
        -PassThru
    
    if ($apiServerProcess) {
        Write-Log "  [OK] API Server started (PID: $($apiServerProcess.Id))"
        Start-Sleep -Seconds 5  # Wait for API server to initialize
    } else {
        Write-Log "  [ERROR] Failed to start API Server"
    }
} catch {
    Write-Log "  [ERROR] API Server error: $_"
}

# Step 3: Run services_manager_interactive.bat option 1 (Start All Services)
Write-Log "Step 3/3: Running services_manager_interactive.bat (Option 1)..."
try {
    $servicesManagerBat = Join-Path $projectRoot "services_manager_interactive.bat"
    
    if (Test-Path $servicesManagerBat) {
        # Create a non-interactive version of option 1
        # We'll extract the START_ALL section logic
        
        Write-Log "  Starting MongoDB..."
        $mongoResult = net start MongoDB 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "    [OK] MongoDB started"
        } else {
            Write-Log "    [INFO] MongoDB may already be running or failed to start"
        }
        
        Write-Log "  Starting TURN Server (coturn Docker)..."
        $coturnComposePath = Join-Path $projectRoot "scripts\coturn-docker-compose.yml"
        if (Test-Path $coturnComposePath) {
            try {
                $dockerResult = docker-compose -f $coturnComposePath up -d 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "    [OK] coturn TURN server started"
                } else {
                    Write-Log "    [WARNING] coturn may already be running or Docker not available"
                }
            } catch {
                Write-Log "    [WARNING] Failed to start coturn: $_"
            }
        } else {
            Write-Log "    [INFO] coturn-docker-compose.yml not found, skipping TURN server"
        }
        Start-Sleep -Seconds 2
        
        Write-Log "  Starting ngrok Tunnel (API + TURN)..."
        $ngrokConfigPath = Join-Path $projectRoot "scripts\ngrok.yml"
        if (Test-Path $ngrokConfigPath) {
            # Use config file for both API and TURN tunnels
            $ngrokProcess = Start-Process -FilePath "ngrok" `
                -ArgumentList "start", "--all", "--config", $ngrokConfigPath `
                -WindowStyle Hidden `
                -PassThru
            if ($ngrokProcess) {
                Write-Log "    [OK] ngrok tunnels started (HTTP + TCP) (PID: $($ngrokProcess.Id))"
            } else {
                Write-Log "    [WARNING] ngrok may not be in PATH"
            }
        } else {
            # Fallback to single HTTP tunnel
            $ngrokProcess = Start-Process -FilePath "ngrok" `
                -ArgumentList "http", "3003", "--domain=soc-chat-app.ngrok-free.app" `
                -WindowStyle Hidden `
                -PassThru
            if ($ngrokProcess) {
                Write-Log "    [OK] ngrok HTTP tunnel started (PID: $($ngrokProcess.Id))"
                Write-Log "    [WARNING] TURN server will not be accessible via ngrok (TCP tunnel missing)"
            } else {
                Write-Log "    [WARNING] ngrok may not be in PATH"
            }
        }
        
        Write-Log "  Starting Network URLs Service..."
        $networkConfigJs = Join-Path $projectRoot "servers\local_api_server\local_network_config.js"
        if (Test-Path $networkConfigJs) {
            $networkProcess = Start-Process -FilePath "node" `
                -ArgumentList "local_network_config.js" `
                -WorkingDirectory (Join-Path $projectRoot "servers\local_api_server") `
                -WindowStyle Hidden `
                -PassThru
            
            if ($networkProcess) {
                Write-Log "    [OK] Network URLs service started (PID: $($networkProcess.Id))"
            }
        } else {
            Write-Log "    [INFO] local_network_config.js not found, skipping"
        }
        
        Write-Log "  [OK] All additional services started"
    } else {
        Write-Log "  [ERROR] services_manager_interactive.bat not found"
    }
} catch {
    Write-Log "  [ERROR] Services manager error: $_"
}

Write-Log "========================================"
Write-Log "All services startup completed"
Write-Log "========================================"

# Save process IDs for later reference
$pidsFile = Join-Path $projectRoot "logs\startup_pids.json"
$pids = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    webServer = if ($webServerProcess) { $webServerProcess.Id } else { $null }
    apiServer = if ($apiServerProcess) { $apiServerProcess.Id } else { $null }
    ngrok = if ($ngrokProcess) { $ngrokProcess.Id } else { $null }
    networkUrls = if ($networkProcess) { $networkProcess.Id } else { $null }
} | ConvertTo-Json

$pids | Out-File -FilePath $pidsFile -Encoding UTF8

