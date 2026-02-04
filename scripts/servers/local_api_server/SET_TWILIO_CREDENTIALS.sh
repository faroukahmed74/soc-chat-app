#!/bin/bash
# Set Twilio Credentials in .env file (macOS/Linux version)
# This script updates the TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in the .env file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# New Twilio Credentials
NEW_ACCOUNT_SID="ACbd7662379a26ed6cde62bfbc8a9a998e"
NEW_AUTH_TOKEN="452e23b1ce6dcae1b9eaf4cb92ae3b4a"

echo ""
echo "🔧 Updating Twilio Credentials in .env file..."
echo "   File: $ENV_FILE"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found. Creating new .env file..."
    
    # Create new .env file with Twilio credentials
    cat > "$ENV_FILE" << EOF
# Twilio TURN Service Configuration
TWILIO_ACCOUNT_SID=$NEW_ACCOUNT_SID
TWILIO_AUTH_TOKEN=$NEW_AUTH_TOKEN
CLOUD_TURN_ENABLED=true
CLOUD_TURN_USERNAME=$NEW_ACCOUNT_SID
CLOUD_TURN_PASSWORD=$NEW_AUTH_TOKEN
CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp
EOF
    
    echo "✅ Created new .env file with Twilio credentials"
    exit 0
fi

# Read existing .env file
ENV_CONTENT=$(cat "$ENV_FILE")

# Update or add TWILIO_ACCOUNT_SID
if echo "$ENV_CONTENT" | grep -q "TWILIO_ACCOUNT_SID="; then
    ENV_CONTENT=$(echo "$ENV_CONTENT" | sed "s/TWILIO_ACCOUNT_SID=.*/TWILIO_ACCOUNT_SID=$NEW_ACCOUNT_SID/")
    echo "✅ Updated TWILIO_ACCOUNT_SID"
else
    ENV_CONTENT="$ENV_CONTENT
TWILIO_ACCOUNT_SID=$NEW_ACCOUNT_SID"
    echo "✅ Added TWILIO_ACCOUNT_SID"
fi

# Update or add TWILIO_AUTH_TOKEN
if echo "$ENV_CONTENT" | grep -q "TWILIO_AUTH_TOKEN="; then
    ENV_CONTENT=$(echo "$ENV_CONTENT" | sed "s/TWILIO_AUTH_TOKEN=.*/TWILIO_AUTH_TOKEN=$NEW_AUTH_TOKEN/")
    echo "✅ Updated TWILIO_AUTH_TOKEN"
else
    ENV_CONTENT="$ENV_CONTENT
TWILIO_AUTH_TOKEN=$NEW_AUTH_TOKEN"
    echo "✅ Added TWILIO_AUTH_TOKEN"
fi

# Update or add CLOUD_TURN_USERNAME
if echo "$ENV_CONTENT" | grep -q "CLOUD_TURN_USERNAME="; then
    ENV_CONTENT=$(echo "$ENV_CONTENT" | sed "s/CLOUD_TURN_USERNAME=.*/CLOUD_TURN_USERNAME=$NEW_ACCOUNT_SID/")
else
    ENV_CONTENT="$ENV_CONTENT
CLOUD_TURN_USERNAME=$NEW_ACCOUNT_SID"
fi

# Update or add CLOUD_TURN_PASSWORD
if echo "$ENV_CONTENT" | grep -q "CLOUD_TURN_PASSWORD="; then
    ENV_CONTENT=$(echo "$ENV_CONTENT" | sed "s/CLOUD_TURN_PASSWORD=.*/CLOUD_TURN_PASSWORD=$NEW_AUTH_TOKEN/")
else
    ENV_CONTENT="$ENV_CONTENT
CLOUD_TURN_PASSWORD=$NEW_AUTH_TOKEN"
fi

# Ensure CLOUD_TURN_ENABLED is set
if ! echo "$ENV_CONTENT" | grep -q "CLOUD_TURN_ENABLED="; then
    ENV_CONTENT="$ENV_CONTENT
CLOUD_TURN_ENABLED=true"
elif echo "$ENV_CONTENT" | grep -q "CLOUD_TURN_ENABLED=false"; then
    ENV_CONTENT=$(echo "$ENV_CONTENT" | sed "s/CLOUD_TURN_ENABLED=false/CLOUD_TURN_ENABLED=true/")
fi

# Ensure CLOUD_TURN_URLS is set
if ! echo "$ENV_CONTENT" | grep -q "CLOUD_TURN_URLS="; then
    ENV_CONTENT="$ENV_CONTENT
CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,turn:global.turn.twilio.com:3478?transport=tcp,turn:global.turn.twilio.com:443?transport=tcp"
fi

# Write updated content back to .env file
echo "$ENV_CONTENT" > "$ENV_FILE"

echo ""
echo "✅ Twilio credentials updated successfully!"
echo "   Account SID: $NEW_ACCOUNT_SID"
echo "   Auth Token: ${NEW_AUTH_TOKEN:0:8}..."
echo ""
echo "⚠️  IMPORTANT: Restart the API server for changes to take effect!"

