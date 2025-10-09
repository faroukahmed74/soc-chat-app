#!/bin/bash

# =============================================================================
# SOC Chat App - ngrok Tunnel Startup Script
# =============================================================================
# This script starts ngrok tunnel for the SOC Chat API server
# Usage: ./start_ngrok.sh [port] [subdomain]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_PORT=3003
DEFAULT_SUBDOMAIN=""
NGROK_CONFIG_FILE="$(dirname "$0")/ngrok.yml"

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
    echo -e "${BLUE}  SOC Chat App - ngrok Tunnel Manager${NC}"
    echo -e "${BLUE}=============================================================================${NC}"
}

# Function to check if ngrok is installed
check_ngrok() {
    if ! command -v ngrok &> /dev/null; then
        print_error "ngrok is not installed or not in PATH"
        echo "Please install ngrok:"
        echo "  - Download from: https://ngrok.com/download"
        echo "  - Or install via package manager:"
        echo "    - macOS: brew install ngrok"
        echo "    - Ubuntu: snap install ngrok"
        echo "    - Windows: choco install ngrok"
        exit 1
    fi
    print_status "ngrok is installed: $(ngrok version)"
}

# Function to check if ngrok is authenticated
check_auth() {
    if ! ngrok config check &> /dev/null; then
        print_warning "ngrok is not authenticated"
        echo "Please authenticate ngrok:"
        echo "  1. Sign up at https://dashboard.ngrok.com/get-started/setup"
        echo "  2. Copy your authtoken"
        echo "  3. Run: ngrok config add-authtoken YOUR_AUTHTOKEN"
        exit 1
    fi
    print_status "ngrok is authenticated"
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_status "Port $port is in use (API server should be running)"
    else
        print_warning "Port $port is not in use"
        echo "Please start your API server first:"
        echo "  cd servers/local_api_server && npm start"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to start ngrok tunnel
start_tunnel() {
    local port=$1
    local subdomain=$2
    
    print_header
    print_status "Starting ngrok tunnel for SOC Chat API..."
    print_status "Port: $port"
    
    if [ -n "$subdomain" ]; then
        print_status "Subdomain: $subdomain"
        print_status "Command: ngrok http --config=$NGROK_CONFIG_FILE --subdomain=$subdomain $port"
        ngrok http --config="$NGROK_CONFIG_FILE" --subdomain="$subdomain" "$port"
    else
        print_status "Command: ngrok http --config=$NGROK_CONFIG_FILE $port"
        ngrok http --config="$NGROK_CONFIG_FILE" "$port"
    fi
}

# Function to get tunnel URL
get_tunnel_url() {
    print_status "Getting tunnel URL..."
    sleep 3  # Wait for ngrok to start
    
    # Try to get URL from ngrok API
    local url=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok\.app' | head -1)
    
    if [ -n "$url" ]; then
        print_status "Tunnel URL: $url"
        echo ""
        print_status "Use this URL for mobile builds:"
        echo "  flutter build apk --dart-define=API_BASE_URL_MOBILE=$url"
        echo ""
        print_status "Or update your .env file:"
        echo "  ALLOWED_ORIGINS=http://localhost:8080,$url"
    else
        print_warning "Could not retrieve tunnel URL automatically"
        print_status "Check ngrok web interface: http://localhost:4040"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT        Port to tunnel (default: $DEFAULT_PORT)"
    echo "  -s, --subdomain NAME   Use custom subdomain (requires paid ngrok)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start tunnel on port 3003"
    echo "  $0 -p 3000           # Start tunnel on port 3000"
    echo "  $0 -s myapp          # Start tunnel with subdomain 'myapp'"
    echo "  $0 -p 3003 -s socchat # Start tunnel on port 3003 with subdomain 'socchat'"
}

# Parse command line arguments
PORT=$DEFAULT_PORT
SUBDOMAIN=$DEFAULT_SUBDOMAIN

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -s|--subdomain)
            SUBDOMAIN="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header
    
    # Pre-flight checks
    check_ngrok
    check_auth
    check_port "$PORT"
    
    # Start tunnel
    start_tunnel "$PORT" "$SUBDOMAIN" &
    TUNNEL_PID=$!
    
    # Get tunnel URL
    get_tunnel_url
    
    # Wait for user to stop
    print_status "Tunnel is running (PID: $TUNNEL_PID)"
    print_status "Press Ctrl+C to stop the tunnel"
    
    # Trap Ctrl+C
    trap 'print_status "Stopping ngrok tunnel..."; kill $TUNNEL_PID 2>/dev/null; exit 0' INT
    
    # Wait for tunnel process
    wait $TUNNEL_PID
}

# Run main function
main "$@"
