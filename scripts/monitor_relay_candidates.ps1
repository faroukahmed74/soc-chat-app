# Monitor Flutter logs for RELAY candidates (TURN server usage)
# This script helps verify if port forwarding is working by checking for RELAY candidates

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Monitoring for RELAY Candidates" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will monitor your device logs for RELAY candidates." -ForegroundColor Yellow
Write-Host "RELAY candidates indicate TURN server is being used." -ForegroundColor Yellow
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. Make sure your device is connected via USB" -ForegroundColor White
Write-Host "2. Make a call from a device on mobile data (different network)" -ForegroundColor White
Write-Host "3. Watch for RELAY candidates in the logs below" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

# Add adb to PATH if not already there
$adbPath = "C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"
if (Test-Path $adbPath) {
    $env:PATH += ";$adbPath"
}

# Check if adb is available
try {
    $adbVersion = adb version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb not found"
    }
    Write-Host "✅ ADB found" -ForegroundColor Green
} catch {
    Write-Host "❌ ADB not found. Please install Android SDK Platform Tools." -ForegroundColor Red
    Write-Host "   Or add adb to your PATH." -ForegroundColor Yellow
    exit 1
}

# Check if device is connected
$devices = adb devices
if ($devices -notmatch "device$") {
    Write-Host "❌ No device connected. Please connect your device via USB." -ForegroundColor Red
    Write-Host "   Make sure USB debugging is enabled." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Device connected" -ForegroundColor Green
Write-Host ""

# Clear previous logs
Write-Host "Clearing previous logs..." -ForegroundColor Gray
adb logcat -c | Out-Null

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Monitoring logs... (Make a call now!)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Looking for:" -ForegroundColor Yellow
Write-Host "  ✅ RELAY candidate = Port forwarding is WORKING!" -ForegroundColor Green
Write-Host "  ⚠️  HOST candidate = Local network only" -ForegroundColor Yellow
Write-Host "  ⚠️  SRFLX candidate = STUN reflexive (no TURN)" -ForegroundColor Yellow
Write-Host ""

# Monitor logs for RELAY and ICE_CANDIDATE patterns
$foundRelay = $false
$relayCount = 0

adb logcat -s flutter:* | ForEach-Object {
    $line = $_
    
    # Check for RELAY candidates
    if ($line -match "RELAY|relay") {
        $foundRelay = $true
        $relayCount++
        Write-Host "[RELAY FOUND] $line" -ForegroundColor Green
        
        # Check if it's from our TURN server
        if ($line -match "41\.33\.106\.54") {
            Write-Host "  ✅ TURN Server IP: 41.33.106.54 (Docker coturn)" -ForegroundColor Green
        }
        
        # Check for port range
        if ($line -match "rport\s+(\d+)") {
            $port = $matches[1]
            if ([int]$port -ge 50000 -and [int]$port -le 50100) {
                Write-Host "  ✅ Media relay port: $port (correct range)" -ForegroundColor Green
            }
        }
    }
    
    # Check for ICE_CANDIDATE
    if ($line -match "ICE_CANDIDATE|ICE candidate") {
        Write-Host "[ICE] $line" -ForegroundColor Cyan
        
        # Check for TURN server info
        if ($line -match "41\.33\.106\.54") {
            Write-Host "  ✅ Using Docker coturn TURN server" -ForegroundColor Green
        }
    }
    
    # Check for connection state
    if ($line -match "ICE_CONNECTION|Connection established|Connection lost|Failed") {
        Write-Host "[CONNECTION] $line" -ForegroundColor $(if ($line -match "established|connected") { "Green" } elseif ($line -match "Failed|lost") { "Red" } else { "Yellow" })
    }
}

# Summary (if script exits)
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($foundRelay) {
    Write-Host "✅ Found $relayCount RELAY candidate(s)" -ForegroundColor Green
    Write-Host "   Port forwarding appears to be WORKING!" -ForegroundColor Green
} else {
    Write-Host "❌ No RELAY candidates found" -ForegroundColor Red
    Write-Host "   Port forwarding may NOT be configured" -ForegroundColor Red
    Write-Host "   Or TURN server is not accessible" -ForegroundColor Red
}

