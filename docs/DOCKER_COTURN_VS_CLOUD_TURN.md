# Docker coturn vs Cloud TURN: Which to Use?

## Current Situation

You're experiencing cross-network media stream issues despite:
- ✅ RELAY candidates being generated (TURN server is being used)
- ✅ Cloud TURN (Twilio) is configured and working
- ❌ ICE connection still fails after a short period

## Why Cloud TURN Might Be Failing

Even though RELAY candidates are generated, the ICE connection can fail due to:

1. **TURN Authentication Issues**
   - Credentials might be expired or invalid
   - Twilio Token API might be returning invalid credentials
   - Check server logs for authentication errors

2. **Network Connectivity**
   - Firewall blocking TURN traffic
   - ISP blocking UDP traffic
   - Network restrictions on mobile devices

3. **TURN Server Overload**
   - Twilio TURN servers might be experiencing issues
   - Rate limiting or quota exceeded

4. **Client-Side Issues**
   - WebRTC implementation might have bugs
   - Media stream handling issues

## Docker coturn vs Cloud TURN

### Cloud TURN (Twilio) - Currently Enabled

**Advantages:**
- ✅ Works without router access
- ✅ No port forwarding needed
- ✅ Reliable cloud infrastructure
- ✅ Handles high traffic

**Disadvantages:**
- ❌ Requires valid Twilio credentials
- ❌ May have costs/quotas
- ❌ Currently failing in your setup

### Docker coturn - Self-Hosted

**Advantages:**
- ✅ Full control over TURN server
- ✅ No external dependencies
- ✅ Can be more reliable if configured correctly
- ✅ No external service costs

**Disadvantages:**
- ❌ **REQUIRES router port forwarding** for cross-network calls
- ❌ Won't work without router access
- ❌ More complex setup
- ❌ Requires public IP and firewall configuration

## How to Switch to Docker coturn

### Step 1: Disable Cloud TURN

Run the PowerShell script:
```powershell
cd servers/local_api_server
.\SWITCH_TO_DOCKER_COTURN.ps1
```

This sets `CLOUD_TURN_ENABLED=false` in the `.env` file.

### Step 2: Configure Router Port Forwarding (REQUIRED)

**Without router port forwarding, Docker coturn will NOT work for cross-network calls!**

You need to forward these ports on your router:
- **UDP 3478** → `10.120.4.230:3478` (TURN control)
- **UDP 50000-50100** → `10.120.4.230:50000-50100` (Media relay)

**Router Configuration:**
1. Access your router admin panel (usually `192.168.1.1` or `192.168.0.1`)
2. Find "Port Forwarding" or "Virtual Server" settings
3. Add these rules:
   - **Rule 1:**
     - External Port: `3478`
     - Internal IP: `10.120.4.230`
     - Internal Port: `3478`
     - Protocol: `UDP`
   - **Rule 2:**
     - External Port: `50000-50100`
     - Internal IP: `10.120.4.230`
     - Internal Port: `50000-50100`
     - Protocol: `UDP`

### Step 3: Verify Docker coturn is Running

```powershell
cd scripts
docker ps | Select-String "soc-chat-coturn"
docker logs --tail 20 soc-chat-coturn
```

You should see:
```
INFO: IPv4. UDP listener opened on: 0.0.0.0:3478
INFO: IPv4. TCP listener opened on : 0.0.0.0:3478
```

### Step 4: Restart API Server

Restart the API server to load the new configuration:
```powershell
# Stop the server (Ctrl+C if running in terminal)
# Then restart it
cd servers/local_api_server
npm start
```

### Step 5: Test TURN Configuration

Check the TURN config endpoint:
```powershell
curl http://localhost:3003/api/webrtc/turn-config
```

You should see Docker coturn servers:
```json
{
  "turnServers": [
    {
      "urls": "turn:41.33.106.54:3478",
      "username": "soc-chat-turn",
      "credential": "yG5EJFUdLgT7xqXr"
    }
  ]
}
```

## Troubleshooting

### If Docker coturn Still Doesn't Work

1. **Check Router Port Forwarding**
   - Verify ports are forwarded correctly
   - Test with `telnet` or `nc` from external network
   - Use online port checker tools

2. **Check Firewall**
   - Windows Firewall should allow UDP 3478 and 50000-50100
   - Run `.\scripts\configure_firewall_for_turn.ps1` if needed

3. **Check Docker coturn Logs**
   - Look for connection attempts in logs
   - Check for authentication failures
   - Verify external IP is correct

4. **Test TURN Server Directly**
   - Use TURN server testing tools
   - Verify credentials are correct

### If You Don't Have Router Access

**You MUST use cloud TURN (Twilio) instead.**

To re-enable cloud TURN:
```powershell
cd servers/local_api_server
# Edit .env file and set:
CLOUD_TURN_ENABLED=true
```

Then investigate why cloud TURN is failing:
1. Check Twilio credentials are valid
2. Check Twilio Token API is working
3. Check server logs for TURN authentication errors
4. Test TURN connectivity from mobile devices

## Recommendation

**If you have router access:**
- Try Docker coturn first (more control, no external dependencies)
- If it doesn't work, investigate router/firewall issues

**If you don't have router access:**
- You MUST use cloud TURN (Twilio)
- Investigate why cloud TURN is failing
- Check Twilio credentials and connectivity

## Current Docker coturn Configuration

- **Container:** `soc-chat-coturn`
- **Public IP:** `41.33.106.54`
- **Port:** `3478` (UDP/TCP)
- **Media Relay Ports:** `50000-50100` (UDP)
- **Username:** `soc-chat-turn`
- **Password:** `yG5EJFUdLgT7xqXr`
- **Status:** ✅ Running and configured for public access

