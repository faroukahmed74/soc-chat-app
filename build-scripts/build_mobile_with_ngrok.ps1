# =============================================================================
# SOC Chat App - Mobile Build Script with ngrok Integration
# =============================================================================
# This script builds mobile apps with ngrok URL integration for global access
# Usage: .\build_mobile_with_ngrok.ps1 [options]

param(
    [string]$NgrokUrl = "https://soc-chat-app.ngrok-free.app",
    [string]$Platform = "all",
    [switch]$SkipNgrokCheck,
    [switch]$Help
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Cyan = "Cyan"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "=============================================================================" -ForegroundColor $Blue
    Write-Host "  $Message" -ForegroundColor $Blue
    Write-Host "=============================================================================" -ForegroundColor $Blue
}

# Function to show help
function Show-Help {
    Write-Header "SOC Chat App - Mobile Build Script Help"
    Write-Host ""
    Write-Host "Usage: .\build_mobile_with_ngrok.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -NgrokUrl URL        ngrok URL to use (e.g., https://abc123.ngrok.app)"
    Write-Host "  -Platform PLATFORM   Platform to build (android, ios, all) [default: all]"
    Write-Host "  -SkipNgrokCheck      Skip ngrok URL validation"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build_mobile_with_ngrok.ps1"
    Write-Host "  .\build_mobile_with_ngrok.ps1 -NgrokUrl https://abc123.ngrok.app"
    Write-Host "  .\build_mobile_with_ngrok.ps1 -Platform android"
    Write-Host "  .\build_mobile_with_ngrok.ps1 -Platform ios -NgrokUrl https://myapp.ngrok.app"
    Write-Host ""
    Write-Host "Prerequisites:"
    Write-Host "  1. Flutter SDK installed and in PATH"
    Write-Host "  2. Android SDK installed (for Android builds)"
    Write-Host "  3. Xcode installed (for iOS builds on macOS)"
    Write-Host "  4. ngrok tunnel running (or provide -NgrokUrl)"
    Write-Host ""
}

# Function to check if Flutter is installed
function Test-Flutter {
    try {
        $flutterVersion = flutter --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Flutter is installed"
            return $true
        }
    }
    catch {
        Write-Error "Flutter is not installed or not in PATH"
        Write-Host "Please install Flutter: https://flutter.dev/docs/get-started/install"
        return $false
    }
    return $false
}

# Function to check if ngrok is running
function Test-Ngrok {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -TimeoutSec 5
        if ($response.tunnels -and $response.tunnels.Count -gt 0) {
            $httpsTunnel = $response.tunnels | Where-Object { $_.proto -eq "https" }
            if ($httpsTunnel) {
                Write-Status "ngrok tunnel found: $($httpsTunnel.public_url)"
                return $httpsTunnel.public_url
            }
        }
    }
    catch {
        Write-Warning "Could not connect to ngrok API (http://localhost:4040)"
    }
    return $null
}

# Function to validate ngrok URL
function Test-NgrokUrl {
    param([string]$Url)
    
    if ([string]::IsNullOrEmpty($Url)) {
        return $false
    }
    
    if ($Url -notmatch "^https://.*\.ngrok\.app$") {
        Write-Error "Invalid ngrok URL format. Expected: https://*.ngrok.app"
        return $false
    }
    
    try {
        $response = Invoke-WebRequest -Uri "$Url/health" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Status "ngrok URL is accessible: $Url"
            return $true
        }
    }
    catch {
        Write-Error "Cannot access ngrok URL: $Url"
        Write-Host "Error: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

# Function to build Android APK
function Build-Android {
    param([string]$ApiUrl)
    
    Write-Header "Building Android APK"
    
    try {
        Write-Status "Building Android APK with API URL: $ApiUrl"
        
        # Clean previous builds
        Write-Status "Cleaning previous builds..."
        flutter clean
        
        # Get dependencies
        Write-Status "Getting Flutter dependencies..."
        flutter pub get
        
        # Build APK
        Write-Status "Building APK..."
        $buildCommand = "flutter build apk --dart-define=API_BASE_URL_MOBILE=$ApiUrl --dart-define=USE_PHYSICAL_SERVER=true --release"
        Invoke-Expression $buildCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✅ Android APK built successfully!"
            Write-Status "APK location: build\app\outputs\flutter-apk\app-release.apk"
        }
        else {
            Write-Error "❌ Android APK build failed"
            return $false
        }
    }
    catch {
        Write-Error "Error building Android APK: $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# Function to build iOS
function Build-iOS {
    param([string]$ApiUrl)
    
    Write-Header "Building iOS App"
    
    # Check if running on macOS
    if ($env:OS -ne "Darwin" -and -not (Test-Path "/System/Library/CoreServices/SystemVersion.plist")) {
        Write-Warning "iOS builds require macOS. Skipping iOS build."
        return $true
    }
    
    try {
        Write-Status "Building iOS app with API URL: $ApiUrl"
        
        # Clean previous builds
        Write-Status "Cleaning previous builds..."
        flutter clean
        
        # Get dependencies
        Write-Status "Getting Flutter dependencies..."
        flutter pub get
        
        # Build iOS
        Write-Status "Building iOS..."
        $buildCommand = "flutter build ios --dart-define=API_BASE_URL_MOBILE=$ApiUrl --dart-define=USE_PHYSICAL_SERVER=true --release --no-codesign"
        Invoke-Expression $buildCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✅ iOS app built successfully!"
            Write-Status "iOS build location: build\ios\iphoneos\Runner.app"
            Write-Warning "Note: iOS app requires code signing for device installation"
        }
        else {
            Write-Error "❌ iOS build failed"
            return $false
        }
    }
    catch {
        Write-Error "Error building iOS app: $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# Function to update environment file
function Update-EnvironmentFile {
    param([string]$ApiUrl)
    
    $envFile = "servers\env.example"
    if (Test-Path $envFile) {
        Write-Status "Updating environment file with ngrok URL..."
        
        $content = Get-Content $envFile -Raw
        $content = $content -replace "ALLOWED_ORIGINS=.*", "ALLOWED_ORIGINS=http://localhost:8080,http://192.168.0.117:8080,$ApiUrl"
        
        Set-Content -Path $envFile -Value $content -NoNewline
        Write-Status "Environment file updated with ngrok URL"
    }
}

# Main execution
function Main {
    # Show help if requested
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Header "SOC Chat App - Mobile Build with ngrok Integration"
    
    # Check prerequisites
    if (-not (Test-Flutter)) {
        return
    }
    
    # Get ngrok URL
    $apiUrl = $NgrokUrl
    
    if ([string]::IsNullOrEmpty($apiUrl)) {
        Write-Status "No ngrok URL provided, checking for running tunnel..."
        $apiUrl = Test-Ngrok
        
        if ([string]::IsNullOrEmpty($apiUrl)) {
            Write-Error "No ngrok tunnel found and no URL provided"
            Write-Host ""
            Write-Host "Please either:"
            Write-Host "  1. Start ngrok tunnel: .\build-scripts\start_ngrok.sh"
            Write-Host "  2. Provide ngrok URL: -NgrokUrl https://your-url.ngrok.app"
            Write-Host ""
            return
        }
    }
    
    # Validate ngrok URL
    if (-not $SkipNgrokCheck) {
        if (-not (Test-NgrokUrl -Url $apiUrl)) {
            Write-Error "ngrok URL validation failed"
            return
        }
    }
    
    Write-Status "Using API URL: $apiUrl"
    
    # Update environment file
    Update-EnvironmentFile -ApiUrl $apiUrl
    
    # Build based on platform
    $buildSuccess = $true
    
    switch ($Platform.ToLower()) {
        "android" {
            $buildSuccess = Build-Android -ApiUrl $apiUrl
        }
        "ios" {
            $buildSuccess = Build-iOS -ApiUrl $apiUrl
        }
        "all" {
            $androidSuccess = Build-Android -ApiUrl $apiUrl
            $iosSuccess = Build-iOS -ApiUrl $apiUrl
            $buildSuccess = $androidSuccess -and $iosSuccess
        }
        default {
            Write-Error "Invalid platform: $Platform. Use 'android', 'ios', or 'all'"
            return
        }
    }
    
    # Final status
    if ($buildSuccess) {
        Write-Header "Build Completed Successfully! 🎉"
        Write-Status "Mobile apps built with ngrok URL: $apiUrl"
        Write-Status "You can now install and test the apps on your devices"
    }
    else {
        Write-Header "Build Failed ❌"
        Write-Error "Some builds failed. Check the output above for details."
    }
}

# Run main function
Main
