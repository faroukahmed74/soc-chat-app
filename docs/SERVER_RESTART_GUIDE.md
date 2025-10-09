# 🔄 SOC Chat App - Server Restart Guide

This guide explains what happens when your physical server restarts and how to ensure seamless operation without requiring mobile app reinstalls.

## 📋 **Table of Contents**

1. [What Happens During Server Restart](#what-happens-during-server-restart)
2. [Automatic Recovery Setup](#automatic-recovery-setup)
3. [Manual Recovery Procedures](#manual-recovery-procedures)
4. [Mobile App Behavior](#mobile-app-behavior)
5. [URL Changes and Impact](#url-changes-and-impact)
6. [Prevention Strategies](#prevention-strategies)
7. [Monitoring and Alerts](#monitoring-and-alerts)

## 🔄 **What Happens During Server Restart**

### **✅ What Stays the Same (No App Reinstall Needed)**

#### **Mobile App Configuration**
- ✅ **App Binary**: The installed APK/IPA remains unchanged
- ✅ **API Endpoints**: Hardcoded ngrok URL in the app
- ✅ **User Data**: Local app data and preferences preserved
- ✅ **Authentication**: Stored JWT tokens remain valid
- ✅ **App Settings**: All user preferences maintained

#### **Database and Data**
- ✅ **MongoDB Data**: All data persists on disk
- ✅ **User Accounts**: All user accounts intact
- ✅ **Chat History**: All messages and media preserved
- ✅ **Media Files**: All uploaded files stored on disk
- ✅ **Database Indexes**: Indexes persist and remain effective

#### **Application Code**
- ✅ **Source Code**: All application files preserved
- ✅ **Configuration**: Environment files maintained
- ✅ **Dependencies**: Node.js packages remain installed

### **⚠️ What Needs to be Restarted**

#### **Server Processes**
- 🔄 **API Server**: Node.js application (port 3003)
- 🔄 **MongoDB Service**: Database server
- 🔄 **Redis Service**: Cache server (if used)
- 🔄 **PM2 Processes**: Process manager
- 🔄 **ngrok Tunnel**: Public tunnel service

#### **Network Services**
- 🔄 **ngrok URL**: May change (free ngrok) or stay same (paid ngrok)
- 🔄 **PM2 Clustering**: Multi-process management
- 🔄 **Nginx**: Reverse proxy (if used)
- 🔄 **SSL Certificates**: HTTPS connections

## 🚀 **Automatic Recovery Setup**

### **1. Setup Automatic Recovery (Linux/macOS)**

```bash
# Make recovery script executable
chmod +x build-scripts/auto_recovery.sh

# Setup systemd service for automatic startup
sudo ./build-scripts/auto_recovery.sh --setup-systemd

# Test recovery script
./build-scripts/auto_recovery.sh
```

### **2. Setup Automatic Recovery (Windows)**

```powershell
# Setup Windows service for automatic startup
.\build-scripts\auto_recovery.ps1 -SetupService

# Test recovery script
.\build-scripts\auto_recovery.ps1
```

### **3. What Automatic Recovery Does**

1. **Starts MongoDB Service**
   - Ensures database is running
   - Tests database connection
   - Verifies data integrity

2. **Starts Redis Service** (if configured)
   - Initializes cache server
   - Tests cache connection
   - Clears old cache data

3. **Starts API Server with PM2**
   - Launches Node.js application
   - Enables process clustering
   - Tests API health endpoints

4. **Starts ngrok Tunnel**
   - Creates public tunnel
   - Gets new ngrok URL
   - Updates configuration files

5. **Updates Mobile Configuration**
   - Updates environment files
   - Logs new ngrok URL
   - Provides rebuild instructions

## 🔧 **Manual Recovery Procedures**

### **If Automatic Recovery Fails**

#### **Step 1: Check System Status**
```bash
# Check system resources
htop
df -h
free -h

# Check network connectivity
ping google.com
```

#### **Step 2: Start Services Manually**
```bash
# Start MongoDB
sudo systemctl start mongod
sudo systemctl status mongod

# Start Redis (if used)
sudo systemctl start redis-server
sudo systemctl status redis-server

# Start API server
cd servers/local_api_server
pm2 start ../../servers/ecosystem.config.js --env production
pm2 status
```

#### **Step 3: Start ngrok Tunnel**
```bash
# Start ngrok
./build-scripts/start_ngrok.sh -p 3003

# Get ngrok URL
curl http://localhost:4040/api/tunnels
```

#### **Step 4: Verify Everything Works**
```bash
# Test API server
curl http://localhost:3003/health

# Test ngrok tunnel
curl https://your-ngrok-url.ngrok.app/health

# Check PM2 processes
pm2 monit
```

## 📱 **Mobile App Behavior**

### **What Users Experience**

#### **During Server Restart**
- ⏳ **Temporary Disconnection**: App shows "Connecting..." or "Offline"
- ⏳ **Retry Attempts**: App automatically retries connection
- ⏳ **Cached Data**: Users can still view cached messages
- ⏳ **No Data Loss**: No messages or data lost

#### **After Server Restart**
- ✅ **Automatic Reconnection**: App reconnects automatically
- ✅ **Seamless Experience**: Users continue where they left off
- ✅ **No App Restart Needed**: App continues running
- ✅ **All Features Work**: Chat, media, notifications resume

### **Connection Flow**

```
Mobile App → ngrok URL → Physical Server → MongoDB
     ↓           ↓            ↓            ↓
  Retry      Tunnel      API Server    Database
  Logic    Restarts    Restarts     Persists
```

## 🌐 **URL Changes and Impact**

### **ngrok URL Behavior**

#### **Free ngrok Account**
- ⚠️ **URL Changes**: New URL after each restart
- ⚠️ **Impact**: Mobile apps need new URL
- ⚠️ **Solution**: Rebuild mobile apps with new URL

#### **Paid ngrok Account**
- ✅ **Stable URL**: Reserved domain stays the same
- ✅ **No Impact**: Mobile apps continue working
- ✅ **No Rebuild**: No need to rebuild apps

### **URL Change Scenarios**

#### **Scenario 1: Free ngrok (URL Changes)**
```
Before Restart: https://abc123.ngrok.app
After Restart:  https://def456.ngrok.app
Action Needed:  Rebuild mobile apps
```

#### **Scenario 2: Paid ngrok (URL Stable)**
```
Before Restart: https://myapp.ngrok.app
After Restart:  https://myapp.ngrok.app
Action Needed:  None (automatic reconnection)
```

#### **Scenario 3: Custom Domain**
```
Before Restart: https://api.yourdomain.com
After Restart:  https://api.yourdomain.com
Action Needed:  None (automatic reconnection)
```

## 🛡️ **Prevention Strategies**

### **1. Use Stable ngrok URL**

#### **Option A: Paid ngrok (Recommended)**
```bash
# Reserve a domain
ngrok http --domain=myapp.ngrok.app 3003

# Update ngrok.yml
tunnels:
  api:
    proto: http
    addr: 3003
    subdomain: myapp  # Reserved subdomain
```

#### **Option B: Custom Domain with SSL**
```bash
# Use your own domain
# Point DNS to your server
# Use Let's Encrypt SSL
```

### **2. Implement URL Discovery**

#### **Dynamic URL Discovery**
```dart
// In Flutter app
class ServerDiscovery {
  static Future<String> discoverServerUrl() async {
    // Try multiple known URLs
    final urls = [
      'https://myapp.ngrok.app',
      'https://api.yourdomain.com',
      'http://192.168.0.117:3003'
    ];
    
    for (final url in urls) {
      try {
        final response = await http.get(Uri.parse('$url/health'));
        if (response.statusCode == 200) {
          return url;
        }
      } catch (e) {
        continue;
      }
    }
    
    throw Exception('No server found');
  }
}
```

### **3. Implement Offline Mode**

#### **Offline Message Queuing**
```dart
// Queue messages when offline
class OfflineMessageQueue {
  static Future<void> queueMessage(Message message) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('message_queue') ?? [];
    queue.add(json.encode(message.toJson()));
    await prefs.setStringList('message_queue', queue);
  }
  
  static Future<void> sendQueuedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('message_queue') ?? [];
    
    for (final messageJson in queue) {
      try {
        await ApiService.sendMessage(Message.fromJson(json.decode(messageJson)));
        queue.remove(messageJson);
      } catch (e) {
        break; // Stop on first failure
      }
    }
    
    await prefs.setStringList('message_queue', queue);
  }
}
```

## 📊 **Monitoring and Alerts**

### **1. Server Health Monitoring**

#### **Health Check Endpoints**
```bash
# API server health
curl http://localhost:3003/health

# MongoDB health
curl http://localhost:3003/api/status/mongodb

# ngrok tunnel health
curl http://localhost:4040/api/tunnels
```

#### **Automated Health Checks**
```bash
# Create health check script
cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash
API_HEALTH=$(curl -s http://localhost:3003/health | jq -r '.status')
NGROK_HEALTH=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [ "$API_HEALTH" != "ok" ] || [ -z "$NGROK_HEALTH" ]; then
    echo "Health check failed - restarting services"
    /path/to/auto_recovery.sh
fi
EOF

# Add to crontab (check every 5 minutes)
echo "*/5 * * * * /usr/local/bin/health-check.sh" | crontab -
```

### **2. Alert System**

#### **Email Alerts**
```bash
# Install mail utility
sudo apt install mailutils

# Create alert script
cat > /usr/local/bin/send-alert.sh << 'EOF'
#!/bin/bash
echo "SOC Chat App server restart detected at $(date)" | mail -s "Server Restart Alert" admin@yourdomain.com
EOF
```

#### **SMS Alerts** (using Twilio)
```bash
# Create SMS alert script
cat > /usr/local/bin/sms-alert.sh << 'EOF'
#!/bin/bash
curl -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json" \
  --data-urlencode "From=+1234567890" \
  --data-urlencode "To=+0987654321" \
  --data-urlencode "Body=SOC Chat App server restarted at $(date)" \
  -u $TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN
EOF
```

## 🔄 **Recovery Scenarios**

### **Scenario 1: Planned Restart**

#### **Before Restart**
```bash
# Notify users (optional)
# Stop services gracefully
pm2 stop all
sudo systemctl stop mongod

# Restart server
sudo reboot
```

#### **After Restart**
```bash
# Automatic recovery runs
# All services start automatically
# Mobile apps reconnect automatically
```

### **Scenario 2: Unexpected Restart**

#### **What Happens**
1. **Server reboots** (power failure, crash, etc.)
2. **Automatic recovery script runs** (if configured)
3. **Services start in order**: MongoDB → API → ngrok
4. **Mobile apps detect reconnection** and resume
5. **Users continue seamlessly** (if URL stable)

#### **If Recovery Fails**
1. **Manual intervention required**
2. **Follow manual recovery procedures**
3. **Check logs for errors**
4. **Restart services individually**

### **Scenario 3: ngrok URL Change**

#### **Free ngrok Account**
```bash
# After restart, get new URL
curl http://localhost:4040/api/tunnels

# Rebuild mobile apps
./build-scripts/build_mobile_with_ngrok.sh --url https://new-url.ngrok.app

# Distribute new APK/IPA to users
```

#### **Paid ngrok Account**
```bash
# URL stays the same
# No action needed
# Mobile apps reconnect automatically
```

## 📱 **Mobile App Reconnection Logic**

### **Automatic Reconnection**

#### **Connection Retry Logic**
```dart
class ConnectionManager {
  static const int maxRetries = 5;
  static const Duration retryDelay = Duration(seconds: 5);
  
  static Future<bool> ensureConnection() async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/health'),
          headers: {'Authorization': 'Bearer ${await getToken()}'}
        );
        
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        if (attempt == maxRetries) {
          return false;
        }
        await Future.delayed(retryDelay * attempt);
      }
    }
    return false;
  }
}
```

#### **Background Reconnection**
```dart
class BackgroundReconnection {
  static Timer? _reconnectTimer;
  
  static void startBackgroundReconnection() {
    _reconnectTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      if (!await ConnectionManager.ensureConnection()) {
        // Show offline indicator
        showOfflineIndicator();
      } else {
        // Hide offline indicator
        hideOfflineIndicator();
        // Send queued messages
        await OfflineMessageQueue.sendQueuedMessages();
      }
    });
  }
}
```

## 🎯 **Best Practices**

### **1. Use Stable URLs**
- ✅ **Paid ngrok**: Reserved domain
- ✅ **Custom domain**: Your own domain with SSL
- ✅ **Load balancer**: Multiple server instances

### **2. Implement Graceful Degradation**
- ✅ **Offline mode**: Basic functionality when offline
- ✅ **Message queuing**: Queue messages when offline
- ✅ **Cached data**: Show cached content when offline

### **3. Monitor and Alert**
- ✅ **Health checks**: Regular health monitoring
- ✅ **Automated recovery**: Automatic service restart
- ✅ **Alert system**: Notify administrators of issues

### **4. Prepare for Failures**
- ✅ **Backup systems**: Database backups
- ✅ **Recovery procedures**: Documented recovery steps
- ✅ **Testing**: Regular disaster recovery testing

## 📞 **Emergency Contacts**

### **When Server Restarts**
1. **Check automatic recovery**: Wait 2-3 minutes
2. **Check health endpoints**: Verify services are running
3. **Check ngrok URL**: Get new URL if needed
4. **Rebuild mobile apps**: If URL changed
5. **Notify users**: If extended downtime

### **Recovery Time Expectations**
- **Automatic recovery**: 2-3 minutes
- **Manual recovery**: 5-10 minutes
- **Mobile app rebuild**: 10-15 minutes
- **Full system recovery**: 15-20 minutes

## ✅ **Summary**

### **What Users Experience**
- ✅ **No app reinstall needed** (app continues working)
- ✅ **Automatic reconnection** (seamless experience)
- ✅ **No data loss** (all data preserved)
- ✅ **Minimal downtime** (2-3 minutes typically)

### **What Administrators Need to Do**
- ✅ **Setup automatic recovery** (one-time setup)
- ✅ **Monitor health checks** (ongoing monitoring)
- ✅ **Rebuild mobile apps** (only if URL changes)
- ✅ **Handle alerts** (if automatic recovery fails)

### **URL Stability Options**
1. **Free ngrok**: URL changes, requires app rebuild
2. **Paid ngrok**: URL stable, no app rebuild needed
3. **Custom domain**: URL stable, no app rebuild needed

Your SOC Chat App is designed to handle server restarts gracefully with minimal impact on users! 🎉

---

**Last Updated**: $(date)
**Version**: 1.0.0
**Maintained by**: SOC Chat App Team
