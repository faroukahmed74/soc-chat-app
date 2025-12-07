# TURN Server Troubleshooting for Cross-Network Calls

## Issue: Media streams not working when devices are on different networks

When devices are on different networks (e.g., one on Wi-Fi, one on mobile data), media streams may not work if the TURN server is not properly configured or accessible.

## Diagnosis Steps

### 1. Check if ngrok TCP tunnel is running

The TURN server must be accessible via ngrok TCP tunnel for cross-network calls.

```bash
# Check if ngrok is running
curl http://localhost:4040/api/tunnels

# Look for a TCP tunnel on port 3478
# Should see something like: "tcp://0.tcp.ngrok.io:12345"
```

### 2. Check TURN server configuration

The server endpoint `/api/webrtc/turn-config` should return:
- ngrok TCP tunnel TURN servers (first priority)
- Local IP TURN servers (fallback)

### 3. Check client logs

When making a call, look for these log messages:

**On app startup:**
```
🔵 [TURN_CONFIG] Fetching TURN configuration from server: ...
✅ [TURN_CONFIG] TURN servers configured with ngrok TCP tunnel: tcp://...
🔵 [TURN_CONFIG] Final ICE servers (in priority order):
   1. turn:0.tcp.ngrok.io:12345 - TURN (NGROK)
   2. turn:0.tcp.ngrok.io:12345?transport=tcp - TURN (NGROK)
   3. turn:10.120.4.230:3478 - TURN (Local)
   4. turn:10.120.4.230:3478?transport=tcp - TURN (Local)
```

**During call:**
```
🔵 [ICE_CANDIDATE] ✅ RELAY candidate (TURN server) from user...
```

If you see "RELAY candidate", the TURN server is being used correctly.

### 4. Verify ICE connection state

Look for:
```
🔵 [ICE_CONNECTION] State changed to RTCIceConnectionStateConnected
🔵 [ICE_CONNECTION] ✅ Connection established - media should flow now!
```

## Common Issues and Solutions

### Issue 1: ngrok TCP tunnel not found

**Symptoms:**
- Logs show: `⚠️ [TURN_CONFIG] TURN servers configured with local IP only (ngrok TCP tunnel not available)`
- Only local IP TURN servers in configuration

**Solution:**
1. Ensure ngrok is running: `ngrok tcp 3478`
2. Check ngrok API: `curl http://localhost:4040/api/tunnels`
3. Verify the tunnel is for port 3478 (TURN server port)

### Issue 2: TURN server not accessible through ngrok

**Symptoms:**
- ngrok tunnel exists but media still doesn't work
- ICE connection fails or stays in "checking" state

**Solution:**
1. Verify coturn (TURN server) is running: `docker ps | grep coturn`
2. Check coturn logs: `docker logs <coturn-container-id>`
3. Verify coturn is listening on port 3478: `netstat -an | grep 3478`
4. Test TURN server directly: Use a TURN testing tool

### Issue 3: Client not using ngrok TURN server

**Symptoms:**
- ngrok TURN servers are configured but not being used
- Only seeing "host" or "srflx" ICE candidates, no "relay" candidates

**Solution:**
1. Check that ngrok TURN servers are listed FIRST in ICE servers
2. Verify the client fetched TURN config from server API
3. Check network connectivity to ngrok tunnel URL

### Issue 4: ICE connection fails

**Symptoms:**
- ICE connection state stays in "checking" or goes to "failed"
- No media streams received

**Solution:**
1. Check firewall rules - port 3478 (TURN) must be accessible
2. Verify TURN server credentials are correct
3. Check if both devices can reach the TURN server
4. Look for errors in server logs

## Testing TURN Server

### Test 1: Check TURN config endpoint

```bash
curl http://your-server-url/api/webrtc/turn-config
```

Should return:
```json
{
  "success": true,
  "turnServers": [
    {
      "urls": "turn:0.tcp.ngrok.io:12345",
      "username": "soc-chat-turn",
      "credential": "yG5EJFUdLgT7xqXr"
    },
    ...
  ],
  "tcpTunnelUrl": "tcp://0.tcp.ngrok.io:12345"
}
```

### Test 2: Verify ngrok tunnel

```bash
# Check ngrok tunnels
curl http://localhost:4040/api/tunnels | jq '.tunnels[] | select(.proto == "tcp")'

# Should show a TCP tunnel forwarding to localhost:3478
```

### Test 3: Test TURN server directly

Use a TURN testing tool or WebRTC trickle ICE test:
- https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

Enter your TURN server details:
- TURN URI: `turn:0.tcp.ngrok.io:12345`
- Username: `soc-chat-turn`
- Password: `yG5EJFUdLgT7xqXr`

Should see "relay" candidates if TURN is working.

## Expected Behavior

### Same Network (Both on Wi-Fi)
- May use STUN (direct connection) or local TURN server
- Should see "host" or "srflx" ICE candidates
- Media streams work

### Different Networks (One on Wi-Fi, One on Mobile Data)
- **MUST** use ngrok TURN server
- Should see "relay" ICE candidates
- Media streams work through TURN relay

### Both on Mobile Data
- **MUST** use ngrok TURN server
- Should see "relay" ICE candidates
- Media streams work through TURN relay

## Logging

Enhanced logging has been added to help diagnose issues:

1. **TURN Configuration Logs:**
   - Shows which TURN servers are configured
   - Indicates which are ngrok vs local IP
   - Shows priority order

2. **ICE Candidate Logs:**
   - Shows candidate type (host, srflx, relay)
   - "RELAY" indicates TURN server usage
   - Critical for diagnosing cross-network issues

3. **ICE Connection Logs:**
   - Shows connection state changes
   - Indicates when connection is established
   - Helps identify connection failures

## Quick Fix Checklist

- [ ] ngrok TCP tunnel running: `ngrok tcp 3478`
- [ ] coturn (TURN server) running and accessible
- [ ] Server API endpoint `/api/webrtc/turn-config` returns ngrok TURN servers
- [ ] Client logs show ngrok TURN servers in configuration
- [ ] Client logs show "RELAY" ICE candidates during calls
- [ ] ICE connection reaches "Connected" or "Completed" state
- [ ] Media streams are received on both devices

## Next Steps

If media streams still don't work after checking all above:

1. Check server logs for TURN config API calls
2. Check client logs for ICE candidate types
3. Verify network connectivity to ngrok tunnel
4. Test TURN server directly with a testing tool
5. Check firewall/network restrictions

