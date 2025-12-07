# Cross-Network Calling Setup

## Overview

The app now supports calling between users on different networks:
- **Web clients** (via local network/proxy)
- **Mobile clients** (via ngrok/public network)
- **Cross-platform calls** (Web ↔ Mobile)

## How It Works

### TURN Server Configuration

Both web and mobile clients fetch TURN server configuration from the server API endpoint:
- **Endpoint**: `GET /api/webrtc/turn-config`
- **Returns**: 
  - ngrok TCP tunnel TURN servers (if available) - for cross-network calls
  - Local IP TURN servers - for same-network calls

### Client Configuration

#### Web Clients
1. **Local IP TURN** (`10.120.4.230:3478`) - Added first (preferred for same-network)
2. **ngrok TCP tunnel TURN** - Fetched from server API (for cross-platform calls)

#### Mobile Clients
1. **Local IP TURN** (`10.120.4.230:3478`) - Added first (fallback for same-network)
2. **ngrok TCP tunnel TURN** - Fetched from server API (for cross-network calls)

## Supported Call Scenarios

### ✅ Scenario 1: Web to Web (Same Network)
- **Network**: Both on local network (e.g., `10.120.4.230`)
- **TURN Server**: Local IP (`10.120.4.230:3478`)
- **Status**: ✅ Works - Direct local network connection

### ✅ Scenario 2: Mobile to Mobile (Different Networks)
- **Network**: One on Wi-Fi, one on mobile data
- **TURN Server**: ngrok TCP tunnel (e.g., `turn:0.tcp.ngrok.io:12345`)
- **Status**: ✅ Works - Both use ngrok TCP tunnel TURN server

### ✅ Scenario 3: Mobile to Mobile (Same Network)
- **Network**: Both on same Wi-Fi network
- **TURN Server**: Local IP (fallback) or STUN
- **Status**: ✅ Works - Can use local IP TURN or STUN

### ✅ Scenario 4: Web to Mobile (Cross-Platform, Same Network)
- **Network**: Both on local network
- **TURN Server**: Local IP (`10.120.4.230:3478`)
- **Status**: ✅ Works - Both can reach local TURN server

### ✅ Scenario 5: Web to Mobile (Cross-Platform, Different Networks)
- **Network**: Web on local network, Mobile on mobile data
- **TURN Server**: ngrok TCP tunnel
- **Status**: ✅ Works - Both have ngrok TCP tunnel option

## Requirements

### 1. TURN Server (coturn)
- Must be running on `10.120.4.230:3478`
- Credentials: `soc-chat-turn` / `yG5EJFUdLgT7xqXr`
- Accessible from local network

### 2. ngrok TCP Tunnel (for cross-network calls)
- Must be running: `ngrok tcp 3478`
- Forwards to: `localhost:3478` (TURN server)
- Provides public URL: `tcp://0.tcp.ngrok.io:XXXXX`

### 3. Server API Endpoint
- `/api/webrtc/turn-config` must be accessible
- Server must be able to access `http://localhost:4040/api/tunnels` (ngrok API)

## Configuration Flow

1. **App Initialization**:
   - Web: Adds local IP TURN, then fetches ngrok TCP tunnel from server
   - Mobile: Adds local IP TURN, then fetches ngrok TCP tunnel from server

2. **Server API Response**:
   ```json
   {
     "success": true,
     "turnServers": [
       {
         "urls": "turn:0.tcp.ngrok.io:12345",
         "username": "soc-chat-turn",
         "credential": "yG5EJFUdLgT7xqXr"
       },
       {
         "urls": "turn:0.tcp.ngrok.io:12345?transport=tcp",
         "username": "soc-chat-turn",
         "credential": "yG5EJFUdLgT7xqXr"
       },
       {
         "urls": "turn:10.120.4.230:3478",
         "username": "soc-chat-turn",
         "credential": "yG5EJFUdLgT7xqXr"
       },
       {
         "urls": "turn:10.120.4.230:3478?transport=tcp",
         "username": "soc-chat-turn",
         "credential": "yG5EJFUdLgT7xqXr"
       }
     ],
     "tcpTunnelUrl": "tcp://0.tcp.ngrok.io:12345"
   }
   ```

3. **WebRTC Peer Connection**:
   - Uses all TURN servers in order (ngrok first, then local IP)
   - WebRTC automatically selects the best TURN server based on network conditions

## Testing

### Test Same-Network Calls
1. Both devices on same Wi-Fi
2. Make a call
3. Should use local IP TURN server (faster, lower latency)

### Test Cross-Network Calls
1. One device on Wi-Fi, one on mobile data
2. Make a call
3. Should use ngrok TCP tunnel TURN server
4. Check logs for `[TURN_CONFIG]` and `[PEER_CONNECTION]` to verify TURN server used

### Test Cross-Platform Calls
1. Web client on local network
2. Mobile client on mobile data
3. Make a call
4. Should use ngrok TCP tunnel TURN server
5. Both clients have access to same TURN servers

## Troubleshooting

### Media streams not working across networks
1. **Check ngrok TCP tunnel**: Ensure `ngrok tcp 3478` is running
2. **Check server logs**: Look for `[TURN_CONFIG]` messages
3. **Check client logs**: Look for `[TURN_CONFIG]` and `[PEER_CONNECTION]` messages
4. **Verify TURN server**: Ensure coturn is running on `10.120.4.230:3478`

### Web clients can't reach mobile clients
- Ensure web clients are fetching TURN config from server API
- Check that server can access ngrok API (`localhost:4040`)
- Verify ngrok TCP tunnel is running

### Mobile clients can't reach web clients
- Ensure mobile clients have ngrok TCP tunnel TURN servers
- Check that mobile clients can access server API endpoint
- Verify TURN server credentials match

## Summary

✅ **All call scenarios are now supported:**
- Web ↔ Web (same network)
- Mobile ↔ Mobile (same or different networks)
- Web ↔ Mobile (cross-platform, same or different networks)

The key is that both platforms now have access to:
- **Local IP TURN server** (for same-network calls)
- **ngrok TCP tunnel TURN server** (for cross-network calls)

WebRTC automatically selects the best TURN server based on network conditions.

