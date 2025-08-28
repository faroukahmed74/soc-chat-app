#!/bin/bash

echo "========================================"
echo "  SOC Chat App - Local Network Runner"
echo "========================================"
echo

echo "Getting local IP address..."
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)

if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
fi

echo "Local IP: $LOCAL_IP"
echo

echo "Starting Flutter app on local network..."
echo "App will be available at: http://$LOCAL_IP:8080"
echo

echo "Press Ctrl+C to stop the server"
echo

# Make the script executable and run Flutter
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
