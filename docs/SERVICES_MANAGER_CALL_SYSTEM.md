# 📞 Call System Integration with services_manager_interactive.bat

## ✅ Updates Made

The `services_manager_interactive.bat` script has been updated to fully support the call system when you run **Option 1: Start All Services**.

## 🚀 Services Started (Option 1)

When you select option 1, the following services are started in order:

1. **MongoDB** (Database)
   - Port: 27017
   - Purpose: Stores all app data including call information

2. **API Server** (Backend + Call System)
   - Port: 3003
   - Purpose: 
     - Handles all API requests
     - **Manages call invitations via `/api/calls/invite` endpoint**
     - Socket.IO for real-time call notifications
     - FCM notifications for background calls

3. **ngrok Tunnel** (Mobile Connectivity)
   - Port: 4040 (web interface)
   - Purpose: Creates public HTTPS tunnel for mobile devices
   - Required for: Android & iOS to connect and receive calls

4. **Web Server** (Web App)
   - Port: 8082
   - Purpose: 
     - Serves Flutter web build
     - Proxies API requests
     - Handles Socket.IO for web platform
     - **Enables web-to-web calls**

5. **Network URLs Service**
   - Purpose: Provides local network configuration
   - Location: `servers/local_api_server/local_network_config.js`

6. **FCM Server** (Optional - Background Notifications)
   - Port: 3000
   - Purpose: Sends Firebase Cloud Messaging notifications
   - Required for: Call notifications when app is in background/terminated
   - Note: Calls work without this, but users won't get notifications if app is closed

## ⏱️ Startup Improvements

- **Added delays** between service startups to ensure proper initialization
- **Better error handling** with informative messages
- **FCM Server** included as optional service
- **Call system information** displayed in success message

## 🎯 Call System Features Enabled

Once all services are running, the following call features are available:

✅ **Voice Calls**
- Individual calls (one-to-one)
- Group calls (multiple participants)

✅ **Video Calls**
- Individual calls (one-to-one)
- Group calls (multiple participants)

✅ **Screen Sharing**
- Share screen during calls
- Multiple participants can share

✅ **Cross-Platform Support**
- Web (via local network proxy)
- Android (via ngrok)
- iOS (via ngrok)

## 📋 How to Use

1. **Run the script:**
   ```batch
   services_manager_interactive.bat
   ```

2. **Select Option 1:**
   - Choose `1` from the menu
   - All services will start automatically

3. **Wait for initialization:**
   - Services need 5-10 seconds to fully initialize
   - Check status with Option 4 if needed

4. **Test calls:**
   - Open app on two devices
   - Initiate a call from one device
   - Other device should receive call invitation

## 🔍 Service Status Check

Use **Option 4: Check Services Status** to verify all services are running:

- MongoDB: ✅ RUNNING
- API Server (3003): ✅ LISTENING
- ngrok (4040): ✅ RUNNING
- Web Server (8082): ✅ LISTENING
- Network URLs: ✅ RUNNING
- FCM Server (3000): ✅ RUNNING (or ⚠️ Optional)

## 🐛 Troubleshooting

### If calls don't work:

1. **Check all services are running:**
   - Use Option 4 to check status
   - All required services should show ✅

2. **Verify API Server is accessible:**
   - Test: `http://localhost:3003/health`
   - Should return success

3. **Check ngrok is running:**
   - Visit: `http://localhost:4040`
   - Should show ngrok web interface
   - Verify tunnel is active

4. **Check logs:**
   - API Server console should show: `📞 Call invitation from...`
   - No errors in service windows

5. **Restart services:**
   - Use Option 3: Restart All Services
   - Wait for full initialization

## 📝 Notes

- **Startup Order Matters**: Services start in sequence with delays
- **FCM Server is Optional**: Calls work without it, but background notifications won't
- **ngrok Required for Mobile**: Android/iOS devices need ngrok to connect
- **Web Uses Local Proxy**: Web platform uses port 8082, not ngrok

## 🔗 Related Files

- **Script**: `services_manager_interactive.bat`
- **API Server**: `servers/local_api_server/server.js`
- **Call Service**: `lib/services/jitsi_call_service.dart`
- **Call Screen**: `lib/screens/call_screen.dart`
- **Full Guide**: `docs/CALL_SYSTEM_GUIDE.md`

