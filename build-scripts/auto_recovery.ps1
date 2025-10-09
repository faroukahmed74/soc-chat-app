# =============================================================================
# SOC Chat App - Automatic Recovery Script (Windows)
# =============================================================================
# This script automatically restarts all services after server reboot
# Add this to Windows startup to ensure automatic recovery

param(
    [switch]$SetupService,
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# Configuration
$AppDir = "C:\Users\Administrator\Documents\GitHub\soc-chat-app"
$ApiDir = "$AppDir\servers\local_api_server"
$LogFile = "C:\logs\soc-chat-recovery.log"

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $logMessage
}

function Write-Status {
    param([string]$Message)
    Write-Log "[INFO] $Message" $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Log "[WARNING] $Message" $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Log "[ERROR] $Message" $Red
}

function Write-Header {
    param([string]$Message)
    Write-Log "=============================================================================" $Blue
    Write-Log "  $Message" $Blue
    Write-Log "=============================================================================" $Blue
}

# Function to check if service is running
function Test-ServiceRunning {
    param([string]$ServiceName)
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    return $service -and $service.Status -eq "Running"
}

# Function to wait for service to be ready
function Wait-ForService {
    param([string]$ServiceName, [int]$MaxAttempts = 30)
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (Test-ServiceRunning $ServiceName) {
            Write-Status "$ServiceName is running"
            return $true
        }
        Write-Warning "Waiting for $ServiceName to start (attempt $attempt/$MaxAttempts)..."
        Start-Sleep -Seconds 2
    }
    
    Write-Error "$ServiceName failed to start after $MaxAttempts attempts"
    return $false
}

# Function to start MongoDB
function Start-MongoDB {
    Write-Status "Starting MongoDB..."
    
    if (Test-ServiceRunning "MongoDB") {
        Write-Status "MongoDB is already running"
        return $true
    }
    
    try {
        Start-Service -Name "MongoDB"
        if (Wait-ForService "MongoDB") {
            Write-Status "✅ MongoDB started successfully"
            
            # Wait for MongoDB to be ready
            Start-Sleep -Seconds 5
            
            # Test MongoDB connection
            try {
                $result = mongosh --eval "db.adminCommand('ping')" --quiet 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "✅ MongoDB connection test passed"
                    return $true
                }
            }
            catch {
                Write-Error "❌ MongoDB connection test failed"
                return $false
            }
        }
    }
    catch {
        Write-Error "❌ Failed to start MongoDB: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

# Function to start API server with PM2
function Start-ApiServer {
    Write-Status "Starting API server with PM2..."
    
    # Check if PM2 is installed
    if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
        Write-Error "PM2 is not installed"
        return $false
    }
    
    # Change to API directory
    Set-Location $ApiDir
    
    # Check if PM2 processes are already running
    $pm2List = pm2 list 2>$null
    if ($pm2List -match "soc-chat-api") {
        Write-Status "API server is already running, restarting..."
        pm2 restart soc-chat-api
    }
    else {
        Write-Status "Starting API server..."
        pm2 start "..\..\servers\ecosystem.config.js" --env production
    }
    
    # Wait for API server to be ready
    $maxAttempts = 30
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3003/health" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Status "✅ API server is responding"
                return $true
            }
        }
        catch {
            # Continue waiting
        }
        
        Write-Warning "Waiting for API server to start (attempt $attempt/$maxAttempts)..."
        Start-Sleep -Seconds 2
    }
    
    Write-Error "❌ API server failed to start"
    return $false
}

# Function to start ngrok tunnel
function Start-Ngrok {
    Write-Status "Starting ngrok tunnel..."
    
    # Check if ngrok is installed
    if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
        Write-Error "ngrok is not installed"
        return $false
    }
    
    # Check if ngrok is already running
    $ngrokProcess = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
    if ($ngrokProcess) {
        Write-Status "ngrok is already running"
        return $true
    }
    
    # Start ngrok in background
    Set-Location $AppDir
    Start-Process -FilePath ".\build-scripts\start_ngrok.sh" -ArgumentList "-p 3003" -WindowStyle Hidden
    
    # Wait for ngrok to start
    Start-Sleep -Seconds 10
    
    # Get ngrok URL
    $maxAttempts = 30
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -TimeoutSec 5
            $ngrokUrl = ($response.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1).public_url
            
            if ($ngrokUrl) {
                Write-Status "✅ ngrok tunnel started: $ngrokUrl"
                $ngrokUrl | Out-File -FilePath "C:\tmp\ngrok_url.txt" -Encoding UTF8
                return $true
            }
        }
        catch {
            # Continue waiting
        }
        
        Write-Warning "Waiting for ngrok tunnel (attempt $attempt/$maxAttempts)..."
        Start-Sleep -Seconds 2
    }
    
    Write-Error "❌ ngrok tunnel failed to start"
    return $false
}

# Function to update mobile app configuration
function Update-MobileConfig {
    param([string]$NgrokUrl)
    
    if (-not $NgrokUrl) {
        Write-Warning "No ngrok URL provided, skipping mobile config update"
        return
    }
    
    Write-Status "Updating mobile app configuration..."
    
    # Update environment file
    $envFile = "$AppDir\servers\env.example"
    if (Test-Path $envFile) {
        $content = Get-Content $envFile -Raw
        $content = $content -replace "ALLOWED_ORIGINS=.*", "ALLOWED_ORIGINS=http://localhost:8080,http://192.168.0.117:8080,$NgrokUrl"
        Set-Content -Path $envFile -Value $content -NoNewline
        Write-Status "✅ Environment file updated with ngrok URL"
    }
    
    Write-Warning "⚠️ Mobile app needs to be rebuilt with new ngrok URL: $NgrokUrl"
    Write-Warning "⚠️ Run: .\build-scripts\build_mobile_with_ngrok.ps1 -NgrokUrl $NgrokUrl"
}

# Function to create Windows service
function New-WindowsService {
    Write-Status "Creating Windows service for automatic startup..."
    
    $serviceName = "SOC-Chat-Recovery"
    $servicePath = "$AppDir\build-scripts\auto_recovery.ps1"
    
    # Create service using sc command
    try {
        & sc create $serviceName binPath= "powershell.exe -ExecutionPolicy Bypass -File `"$servicePath`"" start= auto
        Write-Status "✅ Windows service created: $serviceName"
    }
    catch {
        Write-Error "Failed to create Windows service: $($_.Exception.Message)"
    }
}

# Function to setup task scheduler
function Set-TaskScheduler {
    Write-Status "Setting up Task Scheduler for automatic startup..."
    
    $taskName = "SOC-Chat-Recovery"
    $taskPath = "$AppDir\build-scripts\auto_recovery.ps1"
    
    try {
        # Create scheduled task
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$taskPath`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId "Administrator" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        
        Write-Status "✅ Scheduled task created: $taskName"
    }
    catch {
        Write-Error "Failed to create scheduled task: $($_.Exception.Message)"
    }
}

# Function to show help
function Show-Help {
    Write-Header "SOC Chat App - Automatic Recovery Script Help"
    Write-Host ""
    Write-Host "Usage: .\auto_recovery.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -SetupService    Create Windows service for automatic startup"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\auto_recovery.ps1                 # Run recovery now"
    Write-Host "  .\auto_recovery.ps1 -SetupService   # Setup automatic startup"
    Write-Host ""
}

# Main recovery function
function Start-Recovery {
    Write-Header "SOC Chat App - Automatic Recovery"
    
    # Create log directory
    $logDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    Write-Status "Starting automatic recovery process..."
    Write-Status "Log file: $LogFile"
    
    # Start services in order
    if (-not (Start-MongoDB)) {
        Write-Error "MongoDB startup failed"
        exit 1
    }
    
    if (-not (Start-ApiServer)) {
        Write-Error "API server startup failed"
        exit 1
    }
    
    if (-not (Start-Ngrok)) {
        Write-Error "ngrok startup failed"
        exit 1
    }
    
    # Get ngrok URL
    $ngrokUrl = Get-Content "C:\tmp\ngrok_url.txt" -ErrorAction SilentlyContinue
    
    if ($ngrokUrl) {
        Update-MobileConfig $ngrokUrl
        
        Write-Header "Recovery Completed Successfully! 🎉"
        Write-Status "API Server: http://localhost:3003"
        Write-Status "ngrok URL: $ngrokUrl"
        Write-Status "Health Check: $ngrokUrl/health"
        Write-Status "Mobile apps can connect using: $ngrokUrl"
    }
    else {
        Write-Header "Recovery Completed with Warnings ⚠️"
        Write-Status "API Server: http://localhost:3003"
        Write-Warning "ngrok URL not available - check ngrok status"
    }
    
    Write-Status "All services are now running and ready for mobile connections"
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Setup service if requested
if ($SetupService) {
    New-WindowsService
    Set-TaskScheduler
    Write-Status "Automatic startup configured successfully!"
    exit 0
}

# Run main recovery
Start-Recovery
