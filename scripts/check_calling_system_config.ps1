# Comprehensive Calling System Configuration Check
# This script verifies all configurations needed for WebRTC calls to work

$ErrorActionPreference = "Continue"
$env:PATH += ";C:\Users\Administrator\AppData\Local\Android\sdk\platform-tools"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Calling System Configuration Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$issues = @()
$warnings = @()
$success = @()

# 1. Check Docker coturn container
Write-Host "1. Checking Docker coturn container..." -ForegroundColor Yellow
try {
    $coturnStatus = docker ps --filter "name=soc-chat-coturn" --format "{{.Status}}" 2>&1
    if ($coturnStatus -match "Up") {
        Write-Host "   ✅ Docker coturn is running" -ForegroundColor Green
        $success += "Docker coturn container is running"
        
        # Check if it's listening on correct ports
        $coturnPorts = docker port soc-chat-coturn 2>&1
        if ($coturnPorts -match "3478") {
            Write-Host "   ✅ Port 3478 is mapped" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Port 3478 mapping not found" -ForegroundColor Yellow
            $warnings += "Docker coturn port 3478 mapping not found"
        }
    } else {
        Write-Host "   ❌ Docker coturn is NOT running" -ForegroundColor Red
        $issues += "Docker coturn container is not running"
    }
} catch {
    Write-Host "   ❌ Error checking Docker coturn: $_" -ForegroundColor Red
    $issues += "Cannot check Docker coturn status"
}

# 2. Check Docker coturn logs for errors
Write-Host ""
Write-Host "2. Checking Docker coturn logs for errors..." -ForegroundColor Yellow
try {
    $coturnLogs = docker logs --tail 50 soc-chat-coturn 2>&1
    $errorCount = ($coturnLogs | Select-String -Pattern "ERROR|FATAL" -CaseSensitive).Count
    if ($errorCount -eq 0) {
        Write-Host "   ✅ No errors in recent logs" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Found $errorCount error(s) in logs" -ForegroundColor Yellow
        $warnings += "Docker coturn logs contain errors"
        Write-Host "   Recent errors:" -ForegroundColor Yellow
        $coturnLogs | Select-String -Pattern "ERROR|FATAL" | Select-Object -Last 3 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ⚠️  Cannot check Docker coturn logs" -ForegroundColor Yellow
    $warnings += "Cannot check Docker coturn logs"
}

# 3. Check server .env configuration
Write-Host ""
Write-Host "3. Checking server TURN configuration..." -ForegroundColor Yellow
$envFile = "servers\local_api_server\.env"
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    $cloudTurnEnabled = $envContent | Select-String -Pattern "CLOUD_TURN_ENABLED=(true|false)"
    
    if ($cloudTurnEnabled -match "CLOUD_TURN_ENABLED=false") {
        Write-Host "   ✅ CLOUD_TURN_ENABLED=false (Docker coturn mode)" -ForegroundColor Green
        $success += "Server configured for Docker coturn"
    } elseif ($cloudTurnEnabled -match "CLOUD_TURN_ENABLED=true") {
        Write-Host "   ⚠️  CLOUD_TURN_ENABLED=true (Twilio mode)" -ForegroundColor Yellow
        $warnings += "Server is using Twilio TURN instead of Docker coturn"
    } else {
        Write-Host "   ⚠️  CLOUD_TURN_ENABLED not found in .env" -ForegroundColor Yellow
        $warnings += "CLOUD_TURN_ENABLED not configured"
    }
} else {
    Write-Host "   ❌ .env file not found at $envFile" -ForegroundColor Red
    $issues += ".env file not found"
}

# 4. Check if server is running and accessible
Write-Host ""
Write-Host "4. Checking server accessibility..." -ForegroundColor Yellow
try {
    $serverUrl = "http://localhost:8080"
    $response = Invoke-WebRequest -Uri "$serverUrl/api/health" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Server is running and accessible" -ForegroundColor Green
        $success += "Server is accessible"
        
        # Check TURN config endpoint
        try {
            $turnConfigResponse = Invoke-WebRequest -Uri "$serverUrl/api/webrtc/turn-config" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($turnConfigResponse.StatusCode -eq 200) {
                $turnConfig = $turnConfigResponse.Content | ConvertFrom-Json
                $turnServerCount = $turnConfig.turnServers.Count
                Write-Host "   ✅ TURN config endpoint returns $turnServerCount server(s)" -ForegroundColor Green
                
                # Check if Docker coturn is in the response
                $hasDockerCoturn = $turnConfig.turnServers | Where-Object { $_.urls -match "41\.33\.106\.54" }
                if ($hasDockerCoturn) {
                    Write-Host "   ✅ Docker coturn (41.33.106.54) found in TURN config" -ForegroundColor Green
                    $success += "Docker coturn is in TURN config response"
                } else {
                    Write-Host "   ⚠️  Docker coturn (41.33.106.54) NOT found in TURN config" -ForegroundColor Yellow
                    $warnings += "Docker coturn not in TURN config response"
                }
            } else {
                Write-Host "   ⚠️  TURN config endpoint returned status $($turnConfigResponse.StatusCode)" -ForegroundColor Yellow
                $warnings += "TURN config endpoint not accessible"
            }
        } catch {
            Write-Host "   ⚠️  Cannot access TURN config endpoint: $_" -ForegroundColor Yellow
            $warnings += "TURN config endpoint not accessible"
        }
    } else {
        Write-Host "   ⚠️  Server returned status $($response.StatusCode)" -ForegroundColor Yellow
        $warnings += "Server health check returned non-200 status"
    }
} catch {
    Write-Host "   ❌ Server is NOT accessible: $_" -ForegroundColor Red
    $issues += "Server is not accessible"
}

# 5. Check Windows Firewall rules
Write-Host ""
Write-Host "5. Checking Windows Firewall rules..." -ForegroundColor Yellow
try {
    $firewallRules = Get-NetFirewallRule -DisplayName "*TURN*" -ErrorAction SilentlyContinue
    if ($firewallRules) {
        Write-Host "   ✅ Found $($firewallRules.Count) TURN firewall rule(s)" -ForegroundColor Green
        $success += "Firewall rules for TURN are configured"
    } else {
        Write-Host "   ⚠️  No TURN firewall rules found" -ForegroundColor Yellow
        $warnings += "Windows Firewall rules for TURN not found"
    }
} catch {
    Write-Host "   ⚠️  Cannot check firewall rules (may need admin privileges)" -ForegroundColor Yellow
    $warnings += "Cannot check firewall rules"
}

# 6. Check port listening status
Write-Host ""
Write-Host "6. Checking port listening status..." -ForegroundColor Yellow
try {
    $port3478 = Get-NetTCPConnection -LocalPort 3478 -ErrorAction SilentlyContinue
    if ($port3478) {
        Write-Host "   ✅ Port 3478 is listening" -ForegroundColor Green
        $success += "Port 3478 is listening"
    } else {
        Write-Host "   ⚠️  Port 3478 is NOT listening" -ForegroundColor Yellow
        $warnings += "Port 3478 is not listening"
    }
} catch {
    Write-Host "   ⚠️  Cannot check port status (may need admin privileges)" -ForegroundColor Yellow
    $warnings += "Cannot check port status"
}

# 7. Check Docker port mappings
Write-Host ""
Write-Host "7. Checking Docker port mappings..." -ForegroundColor Yellow
try {
    $dockerPorts = docker port soc-chat-coturn 2>&1
    if ($dockerPorts -match "3478") {
        Write-Host "   ✅ Docker port 3478 is mapped" -ForegroundColor Green
        if ($dockerPorts -match "0\.0\.0\.0:3478") {
            Write-Host "   ✅ Port is bound to 0.0.0.0 (public access)" -ForegroundColor Green
            $success += "Docker ports are correctly mapped and bound"
        } else {
            Write-Host "   ⚠️  Port is NOT bound to 0.0.0.0" -ForegroundColor Yellow
            $warnings += "Docker port not bound to 0.0.0.0"
        }
    } else {
        Write-Host "   ❌ Docker port 3478 mapping not found" -ForegroundColor Red
        $issues += "Docker port 3478 not mapped"
    }
} catch {
    Write-Host "   ⚠️  Cannot check Docker port mappings" -ForegroundColor Yellow
    $warnings += "Cannot check Docker port mappings"
}

# 8. Check connected Android devices
Write-Host ""
Write-Host "8. Checking connected Android devices..." -ForegroundColor Yellow
try {
    $devices = adb devices 2>&1 | Select-String -Pattern "device$"
    $deviceCount = ($devices | Measure-Object).Count
    if ($deviceCount -gt 0) {
        Write-Host "   ✅ Found $deviceCount connected device(s)" -ForegroundColor Green
        $devices | ForEach-Object {
            $deviceId = ($_ -split "\s+")[0]
            Write-Host "      - $deviceId" -ForegroundColor White
        }
        $success += "Android devices are connected"
    } else {
        Write-Host "   ⚠️  No Android devices connected" -ForegroundColor Yellow
        $warnings += "No Android devices connected for testing"
    }
} catch {
    Write-Host "   ⚠️  Cannot check Android devices: $_" -ForegroundColor Yellow
    $warnings += "Cannot check Android devices"
}

# 9. Check router port forwarding (informational)
Write-Host ""
Write-Host "9. Router port forwarding check (manual verification needed)..." -ForegroundColor Yellow
Write-Host "   ⚠️  This requires manual verification:" -ForegroundColor Yellow
Write-Host "      - UDP 3478 (TURN control)" -ForegroundColor White
Write-Host "      - UDP 50000-50100 (Media relay)" -ForegroundColor White
Write-Host "      - Forward to server IP: 10.120.4.230" -ForegroundColor White
Write-Host "   💡 Use test_port_forwarding.ps1 or test from external device" -ForegroundColor Cyan

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
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
    Write-Host "✅ All checks passed! System is ready for calls." -ForegroundColor Green
} elseif ($issues.Count -eq 0) {
    Write-Host "⚠️  Some warnings found, but no critical issues." -ForegroundColor Yellow
    Write-Host "   System may work, but review warnings above." -ForegroundColor Yellow
} else {
    Write-Host "❌ Critical issues found! Fix these before testing calls." -ForegroundColor Red
}

Write-Host ""

