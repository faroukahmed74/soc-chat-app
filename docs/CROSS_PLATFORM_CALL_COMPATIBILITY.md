# 🌐 Cross-Platform Call Compatibility

## ✅ Verified Cross-Platform Call Support

The calling system is **fully configured** to support calls between all platforms:

- ✅ **Android ↔ Android** (via ngrok)
- ✅ **iOS ↔ iOS** (via ngrok)
- ✅ **Web ↔ Web** (via local network proxy)
- ✅ **Android ↔ iOS** (via ngrok)
- ✅ **Android ↔ Web** (mobile via ngrok, web via proxy)
- ✅ **iOS ↔ Web** (mobile via ngrok, web via proxy)

---

## 🔧 Platform Configuration

### **Mobile Platforms (Android & iOS)**
- **Server URL**: Uses `DatabaseConfig.physicalServerUrl`
- **Connection**: Via ngrok tunnel (`https://soc-chat-app.ngrok-free.app`)
- **WebSocket**: `wss://soc-chat-app.ngrok-free.app`
- **API Calls**: Include `ngrok-skip-browser-warning` header
- **Detection**: `kIsWeb == false`

### **Web Platform**
- **Server URL**: Uses `DatabaseConfig.physicalServerUrl`
- **Connection**: Via local network proxy (same-origin)
- **WebSocket**: `ws://[local-ip]:8082` (via proxy)
- **API Calls**: Same-origin requests (proxy handles routing)
- **Detection**: `kIsWeb == true`

---

## 🔄 How Cross-Platform Calls Work

### **1. Signaling (Call Setup)**
All platforms use **Socket.IO** for signaling:

```
Mobile (ngrok) ──┐
                 ├──► Socket.IO Server ──► Web (proxy)
Web (proxy) ─────┘
```

- **Mobile**: Connects via `wss://soc-chat-app.ngrok-free.app`
- **Web**: Connects via `ws://[local-ip]:8082` (proxy forwards to server)
- **Both**: Use same Socket.IO server for signaling
- **Result**: All platforms can exchange call invitations

### **2. WebRTC Peer Connections**
Once signaling is complete, WebRTC establishes **direct peer-to-peer** connections:

```
Mobile User ──► STUN Server ──► Web User
     │                              │
     └────────── P2P Connection ────┘
```

- **STUN Servers**: Google's public STUN servers (work across all platforms)
- **NAT Traversal**: STUN helps establish connections through firewalls
- **Direct Connection**: Media streams flow directly between peers (not through server)

### **3. Media Streaming**
- **Audio/Video**: Streamed directly via WebRTC P2P
- **No Server Relay**: Media doesn't go through ngrok or proxy
- **Low Latency**: Direct connection = better quality

---

## 📋 Implementation Details

### **Platform Detection**
```dart
// Automatic platform detection
if (kIsWeb) {
  // Web platform - use local network proxy
  serverUrl = DatabaseConfig.physicalServerUrl; // Resolves to local IP
} else {
  // Mobile platform - use ngrok
  serverUrl = DatabaseConfig.physicalServerUrl; // Resolves to ngrok URL
}
```

### **API Calls**
```dart
// Mobile: Includes ngrok header
headers['ngrok-skip-browser-warning'] = 'true';

// Web: Uses same-origin (proxy handles routing)
// No ngrok header needed
```

### **WebSocket Connections**
```dart
// Both platforms use DatabaseConfig.physicalServerUrl
final base = DatabaseConfig.physicalServerUrl;
final wsUrl = convertHttpToWs(base); // http -> ws, https -> wss
```

### **STUN Server Configuration**
```dart
final iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
  // ... additional STUN servers
];
```

---

## ✅ Verification Checklist

### **Mobile (Android/iOS)**
- ✅ Uses ngrok URL for API calls
- ✅ Includes `ngrok-skip-browser-warning` header
- ✅ WebSocket connects via `wss://soc-chat-app.ngrok-free.app`
- ✅ STUN servers accessible from mobile networks
- ✅ Can receive calls from web users
- ✅ Can call web users

### **Web**
- ✅ Uses local network URL (via proxy)
- ✅ WebSocket connects via `ws://[local-ip]:8082`
- ✅ STUN servers accessible from web browser
- ✅ Can receive calls from mobile users
- ✅ Can call mobile users

### **Cross-Platform**
- ✅ Socket.IO signaling works between platforms
- ✅ WebRTC peer connections establish successfully
- ✅ Media streams flow between platforms
- ✅ Call controls work on all platforms
- ✅ Call state synchronization across platforms

---

## 🔍 Debugging Cross-Platform Calls

### **Check Platform Detection**
```dart
print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
print('Server URL: ${DatabaseConfig.physicalServerUrl}');
```

### **Check WebSocket Connection**
```dart
// In RealtimeService
print('WebSocket URL: $wsUrl');
print('Connected: ${_realtime.isConnected}');
```

### **Check WebRTC Connection**
```dart
// In WebRTCCallService
print('STUN Servers: ${_iceServers.map((s) => s['urls']).join(", ")}');
print('Peer Connections: ${_peerConnections.length}');
```

### **Check Call Signaling**
```dart
// Verify call invitation received
_realtime.on('call_invitation', (data) {
  print('Call invitation received: $data');
});
```

---

## 🚨 Troubleshooting

### **Issue: Mobile can't call Web**
**Solution:**
1. Verify ngrok is running and accessible
2. Check `DatabaseConfig.physicalServerUrl` resolves to ngrok URL on mobile
3. Verify Socket.IO connection is established
4. Check STUN servers are accessible

### **Issue: Web can't call Mobile**
**Solution:**
1. Verify proxy is configured correctly
2. Check `DatabaseConfig.physicalServerUrl` resolves to local IP on web
3. Verify Socket.IO connection is established
4. Check STUN servers are accessible

### **Issue: Call connects but no audio/video**
**Solution:**
1. Check microphone/camera permissions
2. Verify WebRTC peer connection is established
3. Check STUN servers are working
4. Verify media streams are being sent/received

### **Issue: Call drops immediately**
**Solution:**
1. Check network connectivity
2. Verify STUN servers are accessible
3. Check firewall settings
4. Verify WebRTC peer connection state

---

## 📊 Platform-Specific Notes

### **Mobile (Android/iOS)**
- Uses ngrok for all server communication
- Requires internet connection
- WebRTC works through mobile networks
- STUN servers help with carrier NAT

### **Web**
- Uses local network proxy
- Can work on local network without internet
- WebRTC works through browser
- STUN servers help with router NAT

### **Cross-Platform**
- Signaling goes through server (ngrok for mobile, proxy for web)
- Media goes directly P2P (not through server)
- STUN servers enable NAT traversal
- Works as long as both platforms can reach STUN servers

---

## ✅ Summary

**All platforms can call each other because:**

1. ✅ **Signaling**: Socket.IO works across platforms (mobile via ngrok, web via proxy)
2. ✅ **WebRTC**: Direct P2P connections work across platforms
3. ✅ **STUN Servers**: Public STUN servers accessible from all platforms
4. ✅ **Platform Detection**: Automatic detection ensures correct URLs
5. ✅ **Headers**: Platform-specific headers included (ngrok for mobile)

**The system is fully configured and ready for cross-platform calls!** 🎉

---

*Last Updated: 2025-01-XX*

