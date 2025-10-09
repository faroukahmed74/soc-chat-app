#!/bin/bash

# =============================================================================
# SOC Chat App - Mobile Build Script with ngrok Integration
# =============================================================================
# This script builds mobile apps with ngrok URL integration for global access
# Usage: ./build_mobile_with_ngrok.sh [options]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
NGROK_URL=""
PLATFORM="all"
SKIP_NGROK_CHECK=false
HELP=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=============================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Function to show help
show_help() {
    print_header "SOC Chat App - Mobile Build Script Help"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --url URL         ngrok URL to use (e.g., https://abc123.ngrok.app)"
    echo "  -p, --platform PLAT   Platform to build (android, ios, all) [default: all]"
    echo "  -s, --skip-check      Skip ngrok URL validation"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --url https://abc123.ngrok.app"
    echo "  $0 --platform android"
    echo "  $0 --platform ios --url https://myapp.ngrok.app"
    echo ""
    echo "Prerequisites:"
    echo "  1. Flutter SDK installed and in PATH"
    echo "  2. Android SDK installed (for Android builds)"
    echo "  3. Xcode installed (for iOS builds on macOS)"
    echo "  4. ngrok tunnel running (or provide --url)"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            NGROK_URL="$2"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -s|--skip-check)
            SKIP_NGROK_CHECK=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Show help if requested
if [ "$HELP" = true ]; then
    show_help
    exit 0
fi

# Function to check if Flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        echo "Please install Flutter: https://flutter.dev/docs/get-started/install"
        exit 1
    fi
    print_status "Flutter is installed: $(flutter --version | head -1)"
}

# Function to check if ngrok is running
check_ngrok() {
    local url=""
    
    # Try to get URL from ngrok API
    if command -v curl &> /dev/null; then
        local response=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null || echo "")
        if [ -n "$response" ]; then
            url=$(echo "$response" | grep -o 'https://[^"]*\.ngrok\.app' | head -1)
        fi
    fi
    
    if [ -n "$url" ]; then
        print_status "ngrok tunnel found: $url"
        echo "$url"
    else
        print_warning "Could not connect to ngrok API (http://localhost:4040)"
        echo ""
    fi
}

# Function to validate ngrok URL
validate_ngrok_url() {
    local url="$1"
    
    if [ -z "$url" ]; then
        return 1
    fi
    
    if [[ ! "$url" =~ ^https://.*\.ngrok\.app$ ]]; then
        print_error "Invalid ngrok URL format. Expected: https://*.ngrok.app"
        return 1
    fi
    
    if command -v curl &> /dev/null; then
        if curl -s --max-time 10 "$url/health" > /dev/null 2>&1; then
            print_status "ngrok URL is accessible: $url"
            return 0
        else
            print_error "Cannot access ngrok URL: $url"
            return 1
        fi
    else
        print_warning "curl not available, skipping URL validation"
        return 0
    fi
}

# Function to build Android APK
build_android() {
    local api_url="$1"
    
    print_header "Building Android APK"
    
    print_status "Building Android APK with API URL: $api_url"
    
    # Clean previous builds
    print_status "Cleaning previous builds..."
    flutter clean
    
    # Get dependencies
    print_status "Getting Flutter dependencies..."
    flutter pub get
    
    # Build APK
    print_status "Building APK..."
    if flutter build apk --dart-define=API_BASE_URL_MOBILE="$api_url" --dart-define=USE_PHYSICAL_SERVER=true --release; then
        print_status "✅ Android APK built successfully!"
        print_status "APK location: build/app/outputs/flutter-apk/app-release.apk"
        return 0
    else
        print_error "❌ Android APK build failed"
        return 1
    fi
}

# Function to build iOS
build_ios() {
    local api_url="$1"
    
    print_header "Building iOS App"
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS builds require macOS. Skipping iOS build."
        return 0
    fi
    
    print_status "Building iOS app with API URL: $api_url"
    
    # Clean previous builds
    print_status "Cleaning previous builds..."
    flutter clean
    
    # Get dependencies
    print_status "Getting Flutter dependencies..."
    flutter pub get
    
    # Build iOS
    print_status "Building iOS..."
    if flutter build ios --dart-define=API_BASE_URL_MOBILE="$api_url" --dart-define=USE_PHYSICAL_SERVER=true --release --no-codesign; then
        print_status "✅ iOS app built successfully!"
        print_status "iOS build location: build/ios/iphoneos/Runner.app"
        print_warning "Note: iOS app requires code signing for device installation"
        return 0
    else
        print_error "❌ iOS build failed"
        return 1
    fi
}

# Function to update environment file
update_environment_file() {
    local api_url="$1"
    local env_file="servers/env.example"
    
    if [ -f "$env_file" ]; then
        print_status "Updating environment file with ngrok URL..."
        
        # Use sed to update the ALLOWED_ORIGINS line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed
            sed -i '' "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=http://localhost:8080,http://192.168.0.117:8080,$api_url|" "$env_file"
        else
            # Linux sed
            sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=http://localhost:8080,http://192.168.0.117:8080,$api_url|" "$env_file"
        fi
        
        print_status "Environment file updated with ngrok URL"
    fi
}

# Main execution
main() {
    print_header "SOC Chat App - Mobile Build with ngrok Integration"
    
    # Check prerequisites
    check_flutter
    
    # Get ngrok URL
    local api_url="$NGROK_URL"
    
    if [ -z "$api_url" ]; then
        print_status "No ngrok URL provided, checking for running tunnel..."
        api_url=$(check_ngrok)
        
        if [ -z "$api_url" ]; then
            print_error "No ngrok tunnel found and no URL provided"
            echo ""
            echo "Please either:"
            echo "  1. Start ngrok tunnel: ./build-scripts/start_ngrok.sh"
            echo "  2. Provide ngrok URL: --url https://your-url.ngrok.app"
            echo ""
            exit 1
        fi
    fi
    
    # Validate ngrok URL
    if [ "$SKIP_NGROK_CHECK" = false ]; then
        if ! validate_ngrok_url "$api_url"; then
            print_error "ngrok URL validation failed"
            exit 1
        fi
    fi
    
    print_status "Using API URL: $api_url"
    
    # Update environment file
    update_environment_file "$api_url"
    
    # Build based on platform
    local build_success=true
    
    case "$PLATFORM" in
        "android")
            if ! build_android "$api_url"; then
                build_success=false
            fi
            ;;
        "ios")
            if ! build_ios "$api_url"; then
                build_success=false
            fi
            ;;
        "all")
            local android_success=true
            local ios_success=true
            
            if ! build_android "$api_url"; then
                android_success=false
            fi
            
            if ! build_ios "$api_url"; then
                ios_success=false
            fi
            
            if [ "$android_success" = false ] || [ "$ios_success" = false ]; then
                build_success=false
            fi
            ;;
        *)
            print_error "Invalid platform: $PLATFORM. Use 'android', 'ios', or 'all'"
            exit 1
            ;;
    esac
    
    # Final status
    if [ "$build_success" = true ]; then
        print_header "Build Completed Successfully! 🎉"
        print_status "Mobile apps built with ngrok URL: $api_url"
        print_status "You can now install and test the apps on your devices"
    else
        print_header "Build Failed ❌"
        print_error "Some builds failed. Check the output above for details."
        exit 1
    fi
}

# Run main function
main "$@"
