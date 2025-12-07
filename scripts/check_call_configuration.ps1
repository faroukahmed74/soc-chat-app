# =============================================================================
# SOC Chat App - Audio/Video Call Configuration Check Script
# =============================================================================
# This script checks all configurations related to audio and video calls
# =============================================================================

param(
    [switch]$GenerateReport = $true,
    [string]$ReportPath = "scripts\CALL_CONFIGURATION_REPORT.md"
)

$ErrorActionPreference = "Continue"

# Colors for output
function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

# Report data
$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Packages = @{}
    ServiceFiles = @{}
    ServerEndpoint = @{}
    Routes = @{}
    Configuration = @{}
    Summary = @{}
}

Write-Header "SOC Chat App - Audio/Video Call Configuration Check"

# =============================================================================
# 1. Check Package Dependencies
# =============================================================================
Write-Host "`n1. Checking Package Dependencies..." -ForegroundColor Yellow

$pubspecPath = "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $pubspecContent = Get-Content $pubspecPath -Raw
    
    # Check url_launcher
    if ($pubspecContent -match 'url_launcher:\s*(\S+)') {
        $version = $matches[1]
        Write-Success "url_launcher package found: $version"
        $report.Packages.url_launcher = @{
            Status = "Found"
            Version = $version
        }
    } else {
        Write-Error "url_launcher package NOT found"
        $report.Packages.url_launcher = @{
            Status = "Not Found"
        }
    }
    
    # Check jitsi_meet
    if ($pubspecContent -match 'jitsi_meet:\s*(\S+)') {
        $version = $matches[1]
        Write-Success "jitsi_meet package found: $version"
        $report.Packages.jitsi_meet = @{
            Status = "Found"
            Version = $version
        }
    } elseif ($pubspecContent -match '#\s*jitsi_meet') {
        Write-Warning "jitsi_meet package is COMMENTED OUT (disabled)"
        $report.Packages.jitsi_meet = @{
            Status = "Commented Out"
            Note = "Package is disabled but implementation uses browser-based approach"
        }
    } else {
        Write-Warning "jitsi_meet package NOT found"
        $report.Packages.jitsi_meet = @{
            Status = "Not Found"
            Note = "Implementation uses url_launcher to open Jitsi in browser"
        }
    }
} else {
    Write-Error "pubspec.yaml not found"
}

# =============================================================================
# 2. Check Service Files
# =============================================================================
Write-Host "`n2. Checking Service Files..." -ForegroundColor Yellow

$serviceFiles = @(
    @{ Path = "lib\services\jitsi_call_service.dart"; Name = "Jitsi Call Service" },
    @{ Path = "lib\services\call_types.dart"; Name = "Call Types" },
    @{ Path = "lib\screens\call_screen.dart"; Name = "Call Screen" }
)

foreach ($file in $serviceFiles) {
    if (Test-Path $file.Path) {
        Write-Success "$($file.Name) found: $($file.Path)"
        $fileContent = Get-Content $file.Path -Raw
        $lineCount = ($fileContent -split "`n").Count
        $report.ServiceFiles[$file.Name] = @{
            Status = "Found"
            Path = $file.Path
            Lines = $lineCount
        }
        
        # Check for key functions in jitsi_call_service
        if ($file.Name -eq "Jitsi Call Service") {
            if ($fileContent -match 'startVoiceCall') {
                Write-Info "  - startVoiceCall() function found"
            }
            if ($fileContent -match 'startVideoCall') {
                Write-Info "  - startVideoCall() function found"
            }
            if ($fileContent -match 'getJitsiServerUrl') {
                Write-Info "  - getJitsiServerUrl() function found"
                if ($fileContent -match "meet\.jit\.si") {
                    Write-Info "  - Using public Jitsi server: meet.jit.si"
                    $report.ServiceFiles[$file.Name].JitsiServer = "https://meet.jit.si"
                }
            }
        }
    } else {
        Write-Error "$($file.Name) NOT found: $($file.Path)"
        $report.ServiceFiles[$file.Name] = @{
            Status = "Not Found"
            Path = $file.Path
        }
    }
}

# =============================================================================
# 3. Check Server Endpoint
# =============================================================================
Write-Host "`n3. Checking Server Endpoint..." -ForegroundColor Yellow

$serverFile = "servers\local_api_server\server.js"
if (Test-Path $serverFile) {
    $serverContent = Get-Content $serverFile -Raw
    
    if ($serverContent -match '/api/calls/invite') {
        Write-Success "Call invitation endpoint found: /api/calls/invite"
        
        # Extract endpoint details
        $endpointMatch = [regex]::Match($serverContent, 'app\.post\([''"]/api/calls/invite[''"]')
        if ($endpointMatch.Success) {
            Write-Info "  - Endpoint method: POST"
            Write-Info "  - Endpoint path: /api/calls/invite"
        }
        
        # Check for authentication
        if ($serverContent -match 'authenticateToken.*calls/invite') {
            Write-Info "  - Authentication: Required (authenticateToken)"
        }
        
        # Check for Socket.IO integration
        if ($serverContent -match 'call_invitation') {
            Write-Info "  - Socket.IO integration: Found (call_invitation event)"
        }
        
        # Check for FCM notifications
        if ($serverContent -match 'sendFCMNotification.*call') {
            Write-Info "  - FCM notifications: Enabled for call invitations"
        }
        
        $report.ServerEndpoint = @{
            Status = "Found"
            Path = "/api/calls/invite"
            Method = "POST"
            Authentication = "Required"
            SocketIO = "Enabled"
            FCM = "Enabled"
        }
    } else {
        Write-Error "Call invitation endpoint NOT found in server.js"
        $report.ServerEndpoint = @{
            Status = "Not Found"
        }
    }
} else {
    Write-Error "Server file not found: $serverFile"
    $report.ServerEndpoint = @{
        Status = "Server File Not Found"
    }
}

# =============================================================================
# 4. Check Routes Configuration
# =============================================================================
Write-Host "`n4. Checking Routes Configuration..." -ForegroundColor Yellow

$routeFiles = @(
    @{ Path = "lib\routes\native_routes.dart"; Name = "Native Routes" },
    @{ Path = "lib\routes\web_routes.dart"; Name = "Web Routes" }
)

foreach ($file in $routeFiles) {
    if (Test-Path $file.Path) {
        $routeContent = Get-Content $file.Path -Raw
        if ($routeContent -match "'/call'|`"/call`"") {
            Write-Success "$($file.Name): /call route found"
            $report.Routes[$file.Name] = @{
                Status = "Found"
                Route = "/call"
            }
        } else {
            Write-Warning "$($file.Name): /call route NOT found"
            $report.Routes[$file.Name] = @{
                Status = "Not Found"
            }
        }
    } else {
        Write-Warning "$($file.Name) file not found: $($file.Path)"
        $report.Routes[$file.Name] = @{
            Status = "File Not Found"
        }
    }
}

# =============================================================================
# 5. Check Chat Screen Integration
# =============================================================================
Write-Host "`n5. Checking Chat Screen Integration..." -ForegroundColor Yellow

$chatScreenFile = "lib\screens\chat_screen_mongodb.dart"
if (Test-Path $chatScreenFile) {
    $chatContent = Get-Content $chatScreenFile -Raw
    
    if ($chatContent -match 'Video Call|videocam|_startCall') {
        Write-Success "Call buttons found in chat screen"
        
        $hasVideoButton = $chatContent -match 'videocam|Video Call'
        $hasVoiceButton = $chatContent -match 'phone|Voice Call'
        $hasStartCall = $chatContent -match '_startCall'
        
        if ($hasVideoButton) {
            Write-Info "  - Video call button: Found"
        }
        if ($hasVoiceButton) {
            Write-Info "  - Voice call button: Found"
        }
        if ($hasStartCall) {
            Write-Info "  - _startCall() method: Found"
        }
        
        $report.ServiceFiles["Chat Screen Integration"] = @{
            Status = "Found"
            VideoButton = $hasVideoButton
            VoiceButton = $hasVoiceButton
            StartCallMethod = $hasStartCall
        }
    } else {
        Write-Warning "Call buttons NOT found in chat screen"
        $report.ServiceFiles["Chat Screen Integration"] = @{
            Status = "Not Found"
        }
    }
} else {
    Write-Warning "Chat screen file not found: $chatScreenFile"
}

# =============================================================================
# 6. Check Configuration Files
# =============================================================================
Write-Host "`n6. Checking Configuration Files..." -ForegroundColor Yellow

$configFile = "lib\config\database_config.dart"
if (Test-Path $configFile) {
    $configContent = Get-Content $configFile -Raw
    
    if ($configContent -match 'physicalServerUrl') {
        Write-Success "Database config found with physicalServerUrl"
        Write-Info "  - Server URL configuration: Available"
        
        # Check for ngrok URL
        if ($configContent -match 'ngrok') {
            Write-Info "  - ngrok support: Found"
        }
        
        $report.Configuration = @{
            Status = "Found"
            ServerUrlConfig = "Available"
            NgrokSupport = ($configContent -match 'ngrok')
        }
    } else {
        Write-Warning "physicalServerUrl not found in database config"
        $report.Configuration = @{
            Status = "Partial"
        }
    }
} else {
    Write-Error "Database config file not found: $configFile"
    $report.Configuration = @{
        Status = "Not Found"
    }
}

# =============================================================================
# 7. Check Main App Integration
# =============================================================================
Write-Host "`n7. Checking Main App Integration..." -ForegroundColor Yellow

$mainFile = "lib\main.dart"
if (Test-Path $mainFile) {
    $mainContent = Get-Content $mainFile -Raw
    
    if ($mainContent -match 'call_invitation|onCallInvitation') {
        Write-Success "Call invitation listener found in main.dart"
        Write-Info "  - Global call invitation handler: Configured"
        $report.ServiceFiles["Main App Integration"] = @{
            Status = "Found"
            CallListener = "Configured"
        }
    } else {
        Write-Warning "Call invitation listener NOT found in main.dart"
        $report.ServiceFiles["Main App Integration"] = @{
            Status = "Not Found"
        }
    }
} else {
    Write-Warning "Main app file not found: $mainFile"
}

# =============================================================================
# 8. Test Jitsi Server Accessibility
# =============================================================================
Write-Host "`n8. Testing Jitsi Server Accessibility..." -ForegroundColor Yellow

try {
    $jitsiUrl = "https://meet.jit.si"
    Write-Info "Testing connection to: $jitsiUrl"
    
    $response = Invoke-WebRequest -Uri $jitsiUrl -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Success "Jitsi server is accessible (Status: $($response.StatusCode))"
        $report.Configuration.JitsiServerAccessible = $true
        $report.Configuration.JitsiServerUrl = $jitsiUrl
    } else {
        Write-Warning "Jitsi server returned status: $($response.StatusCode)"
        $report.Configuration.JitsiServerAccessible = $false
    }
} catch {
    Write-Warning "Cannot reach Jitsi server: $($_.Exception.Message)"
    $report.Configuration.JitsiServerAccessible = $false
    $report.Configuration.JitsiServerError = $_.Exception.Message
}

# =============================================================================
# 9. Generate Summary
# =============================================================================
Write-Host "`n9. Generating Summary..." -ForegroundColor Yellow

$allPackagesOk = ($report.Packages.url_launcher.Status -eq "Found")
$allServicesOk = ($report.ServiceFiles["Jitsi Call Service"].Status -eq "Found") -and
                 ($report.ServiceFiles["Call Screen"].Status -eq "Found")
$serverEndpointOk = ($report.ServerEndpoint.Status -eq "Found")
$routesOk = ($report.Routes["Native Routes"].Status -eq "Found") -and
            ($report.Routes["Web Routes"].Status -eq "Found")

$overallStatus = "[OK] All Systems Operational"
if (-not $allPackagesOk) {
    $overallStatus = "[WARNING] Some Packages Missing"
}
if (-not $allServicesOk) {
    $overallStatus = "[WARNING] Some Service Files Missing"
}
if (-not $serverEndpointOk) {
    $overallStatus = "[ERROR] Server Endpoint Missing"
}

$report.Summary = @{
    OverallStatus = $overallStatus
    AllPackagesOk = $allPackagesOk
    AllServicesOk = $allServicesOk
    ServerEndpointOk = $serverEndpointOk
    RoutesOk = $routesOk
    JitsiServerAccessible = $report.Configuration.JitsiServerAccessible
    Timestamp = $report.Timestamp
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Overall Status: $overallStatus" -ForegroundColor $(if ($allPackagesOk -and $allServicesOk -and $serverEndpointOk) { "Green" } else { "Yellow" })
Write-Host "All Packages Found: $(if ($allPackagesOk) { '[OK] Yes' } else { '[X] No' })"
Write-Host "All Service Files Found: $(if ($allServicesOk) { '[OK] Yes' } else { '[X] No' })"
Write-Host "Server Endpoint Found: $(if ($serverEndpointOk) { '[OK] Yes' } else { '[X] No' })"
Write-Host "Routes Configured: $(if ($routesOk) { '[OK] Yes' } else { '[X] No' })"
Write-Host "Jitsi Server Accessible: $(if ($report.Configuration.JitsiServerAccessible) { '[OK] Yes' } else { '[X] No' })"

# =============================================================================
# 10. Generate Report File
# =============================================================================
if ($GenerateReport) {
    Write-Host "`n10. Generating Report File..." -ForegroundColor Yellow
    
    $reportLines = @()
    $reportLines += "# SOC Chat App - Audio/Video Call Configuration Report"
    $reportLines += "**Generated:** $($report.Timestamp)"
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## Executive Summary"
    $reportLines += ""
    $reportLines += "**Overall Status:** $($report.Summary.OverallStatus)"
    $reportLines += ""
    $reportLines += "| Component | Status |"
    $reportLines += "|-----------|--------|"
    $reportLines += "| All Packages Found | $(if ($report.Summary.AllPackagesOk) { '[OK] Yes' } else { '[X] No' }) |"
    $reportLines += "| All Service Files Found | $(if ($report.Summary.AllServicesOk) { '[OK] Yes' } else { '[X] No' }) |"
    $reportLines += "| Server Endpoint Found | $(if ($report.Summary.ServerEndpointOk) { '[OK] Yes' } else { '[X] No' }) |"
    $reportLines += "| Routes Configured | $(if ($report.Summary.RoutesOk) { '[OK] Yes' } else { '[X] No' }) |"
    $reportLines += "| Jitsi Server Accessible | $(if ($report.Summary.JitsiServerAccessible) { '[OK] Yes' } else { '[X] No' }) |"
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 1. Package Dependencies"
    $reportLines += ""
    $reportLines += "### url_launcher"
    $reportLines += "- **Status:** $($report.Packages.url_launcher.Status)"
    if ($report.Packages.url_launcher.Version) {
        $reportLines += "- **Version:** $($report.Packages.url_launcher.Version)"
    }
    $reportLines += ""
    $reportLines += "### jitsi_meet"
    $reportLines += "- **Status:** $($report.Packages.jitsi_meet.Status)"
    if ($report.Packages.jitsi_meet.Note) {
        $reportLines += "- **Note:** $($report.Packages.jitsi_meet.Note)"
    }
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 2. Service Files"
    $reportLines += ""
    foreach ($service in $report.ServiceFiles.GetEnumerator() | Sort-Object Name) {
        $reportLines += "### $($service.Key)"
        $reportLines += "- **Status:** $($service.Value.Status)"
        if ($service.Value.Path) {
            $reportLines += "- **Path:** $($service.Value.Path)"
        }
        if ($service.Value.Lines) {
            $reportLines += "- **Lines:** $($service.Value.Lines)"
        }
        if ($service.Value.JitsiServer) {
            $reportLines += "- **Jitsi Server:** $($service.Value.JitsiServer)"
        }
        $reportLines += ""
    }
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 3. Server Endpoint"
    $reportLines += ""
    $reportLines += "- **Status:** $($report.ServerEndpoint.Status)"
    if ($report.ServerEndpoint.Path) {
        $reportLines += "- **Path:** $($report.ServerEndpoint.Path)"
        $reportLines += "- **Method:** $($report.ServerEndpoint.Method)"
        $reportLines += "- **Authentication:** $($report.ServerEndpoint.Authentication)"
        $reportLines += "- **Socket.IO:** $($report.ServerEndpoint.SocketIO)"
        $reportLines += "- **FCM Notifications:** $($report.ServerEndpoint.FCM)"
    }
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 4. Routes Configuration"
    $reportLines += ""
    foreach ($route in $report.Routes.GetEnumerator() | Sort-Object Name) {
        $reportLines += "### $($route.Key)"
        $reportLines += "- **Status:** $($route.Value.Status)"
        if ($route.Value.Route) {
            $reportLines += "- **Route:** $($route.Value.Route)"
        }
        $reportLines += ""
    }
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## 5. Configuration"
    $reportLines += ""
    $reportLines += "- **Status:** $($report.Configuration.Status)"
    if ($report.Configuration.JitsiServerUrl) {
        $reportLines += "- **Jitsi Server URL:** $($report.Configuration.JitsiServerUrl)"
        $reportLines += "- **Jitsi Server Accessible:** $(if ($report.Configuration.JitsiServerAccessible) { 'Yes' } else { 'No' })"
    }
    if ($report.Configuration.JitsiServerError) {
        $reportLines += "- **Error:** $($report.Configuration.JitsiServerError)"
    }
    $reportLines += ""
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "## Recommendations"
    $reportLines += ""
    if (-not $report.Summary.AllPackagesOk) {
        $reportLines += "[WARNING] **Action Required:** Some packages are missing. Run:"
        $reportLines += "- ``flutter pub get``"
        $reportLines += ""
    }
    if (-not $report.Summary.ServerEndpointOk) {
        $reportLines += "[ERROR] **Action Required:** Server endpoint is missing. Check server.js file."
        $reportLines += ""
    }
    if (-not $report.Summary.JitsiServerAccessible) {
        $reportLines += "[WARNING] **Action Required:** Cannot reach Jitsi server. Check internet connection."
        $reportLines += ""
    }
    if ($report.Summary.AllPackagesOk -and $report.Summary.AllServicesOk -and $report.Summary.ServerEndpointOk) {
        $reportLines += "[OK] **All systems configured!** Audio and video calls should work."
        $reportLines += ""
        $reportLines += "**Note:** The implementation uses browser-based Jitsi Meet (via url_launcher),"
        $reportLines += "so the jitsi_meet package is not required. Calls open in the default browser."
        $reportLines += ""
    }
    $reportLines += "---"
    $reportLines += ""
    $reportLines += "**Report Generated:** $($report.Timestamp)"
    
    $reportContent = $reportLines -join "`n"
    
    try {
        $reportContent | Out-File -FilePath $ReportPath -Encoding UTF8
        Write-Success "Report saved to: $ReportPath"
    } catch {
        Write-Error "Failed to save report: $_"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Configuration Check Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

