#!/bin/bash

# =============================================================================
# SOC Chat App - Automatic Recovery Script
# =============================================================================
# This script automatically restarts all services after server reboot
# Add this to system startup to ensure automatic recovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_DIR="/home/socchat/soc-chat-app"
API_DIR="$APP_DIR/servers/local_api_server"
LOG_FILE="/var/log/soc-chat-recovery.log"

# Function to log messages
log_message() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

print_status() {
    log_message "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    log_message "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    log_message "${RED}[ERROR]${NC} $1"
}

print_header() {
    log_message "${BLUE}=============================================================================${NC}"
    log_message "${BLUE}  $1${NC}"
    log_message "${BLUE}=============================================================================${NC}"
}

# Function to check if service is running
is_service_running() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name"
}

# Function to wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if is_service_running "$service_name"; then
            print_status "$service_name is running"
            return 0
        fi
        print_warning "Waiting for $service_name to start (attempt $attempt/$max_attempts)..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start after $max_attempts attempts"
    return 1
}

# Function to start MongoDB
start_mongodb() {
    print_status "Starting MongoDB..."
    
    if is_service_running "mongod"; then
        print_status "MongoDB is already running"
        return 0
    fi
    
    sudo systemctl start mongod
    wait_for_service "mongod"
    
    if [ $? -eq 0 ]; then
        print_status "✅ MongoDB started successfully"
        
        # Wait for MongoDB to be ready
        sleep 5
        
        # Test MongoDB connection
        if mongosh --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; then
            print_status "✅ MongoDB connection test passed"
        else
            print_error "❌ MongoDB connection test failed"
            return 1
        fi
    else
        print_error "❌ Failed to start MongoDB"
        return 1
    fi
}

# Function to start Redis
start_redis() {
    print_status "Starting Redis..."
    
    if is_service_running "redis-server"; then
        print_status "Redis is already running"
        return 0
    fi
    
    sudo systemctl start redis-server
    wait_for_service "redis-server"
    
    if [ $? -eq 0 ]; then
        print_status "✅ Redis started successfully"
        
        # Test Redis connection
        if redis-cli ping > /dev/null 2>&1; then
            print_status "✅ Redis connection test passed"
        else
            print_warning "⚠️ Redis connection test failed (optional service)"
        fi
    else
        print_warning "⚠️ Failed to start Redis (optional service)"
    fi
}

# Function to start API server with PM2
start_api_server() {
    print_status "Starting API server with PM2..."
    
    # Check if PM2 is installed
    if ! command -v pm2 &> /dev/null; then
        print_error "PM2 is not installed"
        return 1
    fi
    
    # Change to API directory
    cd "$API_DIR" || {
        print_error "Failed to change to API directory: $API_DIR"
        return 1
    }
    
    # Check if PM2 processes are already running
    if pm2 list | grep -q "soc-chat-api"; then
        print_status "API server is already running, restarting..."
        pm2 restart soc-chat-api
    else
        print_status "Starting API server..."
        pm2 start ../../servers/ecosystem.config.js --env production
    fi
    
    # Wait for API server to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:3003/health > /dev/null 2>&1; then
            print_status "✅ API server is responding"
            break
        fi
        print_warning "Waiting for API server to start (attempt $attempt/$max_attempts)..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "❌ API server failed to start"
        return 1
    fi
}

# Function to start ngrok tunnel
start_ngrok() {
    print_status "Starting ngrok tunnel..."
    
    # Check if ngrok is installed
    if ! command -v ngrok &> /dev/null; then
        print_error "ngrok is not installed"
        return 1
    fi
    
    # Check if ngrok is already running
    if pgrep -f "ngrok" > /dev/null; then
        print_status "ngrok is already running"
        return 0
    fi
    
    # Start ngrok in background
    cd "$APP_DIR"
    nohup ./build-scripts/start_ngrok.sh -p 3003 > /tmp/ngrok.log 2>&1 &
    
    # Wait for ngrok to start
    sleep 10
    
    # Get ngrok URL
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local ngrok_url=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok\.app' | head -1)
        
        if [ -n "$ngrok_url" ]; then
            print_status "✅ ngrok tunnel started: $ngrok_url"
            echo "$ngrok_url" > /tmp/ngrok_url.txt
            return 0
        fi
        
        print_warning "Waiting for ngrok tunnel (attempt $attempt/$max_attempts)..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "❌ ngrok tunnel failed to start"
    return 1
}

# Function to update mobile app configuration
update_mobile_config() {
    local ngrok_url="$1"
    
    if [ -z "$ngrok_url" ]; then
        print_warning "No ngrok URL provided, skipping mobile config update"
        return 0
    fi
    
    print_status "Updating mobile app configuration..."
    
    # Update environment file
    if [ -f "$APP_DIR/servers/env.example" ]; then
        sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=http://localhost:8080,http://192.168.0.117:8080,$ngrok_url|" "$APP_DIR/servers/env.example"
        print_status "✅ Environment file updated with ngrok URL"
    fi
    
    # Update database config if needed
    if [ -f "$APP_DIR/lib/config/database_config.dart" ]; then
        # This would require rebuilding the app, which is not automatic
        print_warning "⚠️ Mobile app needs to be rebuilt with new ngrok URL: $ngrok_url"
        print_warning "⚠️ Run: ./build-scripts/build_mobile_with_ngrok.sh --url $ngrok_url"
    fi
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service for automatic startup..."
    
    sudo tee /etc/systemd/system/soc-chat-recovery.service > /dev/null << EOF
[Unit]
Description=SOC Chat App Auto Recovery
After=network.target mongod.service redis.service
Wants=mongod.service redis.service

[Service]
Type=oneshot
User=socchat
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/build-scripts/auto_recovery.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable soc-chat-recovery.service
    
    print_status "✅ Systemd service created and enabled"
}

# Function to setup cron job as fallback
setup_cron_fallback() {
    print_status "Setting up cron job as fallback..."
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "@reboot $APP_DIR/build-scripts/auto_recovery.sh >> $LOG_FILE 2>&1") | crontab -
    
    print_status "✅ Cron job added for automatic startup"
}

# Main recovery function
main() {
    print_header "SOC Chat App - Automatic Recovery"
    
    # Create log file
    touch "$LOG_FILE"
    
    print_status "Starting automatic recovery process..."
    print_status "Log file: $LOG_FILE"
    
    # Start services in order
    start_mongodb || {
        print_error "MongoDB startup failed"
        exit 1
    }
    
    start_redis || {
        print_warning "Redis startup failed (continuing without Redis)"
    }
    
    start_api_server || {
        print_error "API server startup failed"
        exit 1
    }
    
    start_ngrok || {
        print_error "ngrok startup failed"
        exit 1
    }
    
    # Get ngrok URL
    local ngrok_url=$(cat /tmp/ngrok_url.txt 2>/dev/null || echo "")
    
    if [ -n "$ngrok_url" ]; then
        update_mobile_config "$ngrok_url"
        
        print_header "Recovery Completed Successfully! 🎉"
        print_status "API Server: http://localhost:3003"
        print_status "ngrok URL: $ngrok_url"
        print_status "Health Check: $ngrok_url/health"
        print_status "Mobile apps can connect using: $ngrok_url"
    else
        print_header "Recovery Completed with Warnings ⚠️"
        print_status "API Server: http://localhost:3003"
        print_warning "ngrok URL not available - check ngrok status"
    fi
    
    print_status "All services are now running and ready for mobile connections"
}

# Check if running as root for systemd setup
if [ "$1" = "--setup-systemd" ]; then
    create_systemd_service
    setup_cron_fallback
    exit 0
fi

# Run main recovery
main "$@"
