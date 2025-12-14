# coturn Cross-Network Media Stream Fix

## Problem
Media streams (audio/video) only work when devices are on the same WiFi network. Cross-network calls fail - users cannot hear or see each other.

## Root Cause

From the Docker logs, coturn is only listening on:
- `127.0.0.1` (localhost) - not accessible from outside
- `172.19.0.2` (Docker internal IP) - not accessible from outside

**coturn needs to listen on `0.0.0.0` (all interfaces) so Docker can forward ports.**

## Fix Applied

✅ **Updated `scripts/coturn-docker-compose.yml`** to add `--listening-ip=0.0.0.0`

This allows coturn to accept connections from outside the Docker container.

## Additional Steps Required

### Step 1: Restart coturn Container

After updating the Docker compose file, restart the container:

```powershell
cd scripts
docker-compose -f coturn-docker-compose.yml down
docker-compose -f coturn-docker-compose.yml up -d
```

### Step 2: Verify coturn is Listening on All Interfaces

Check the Docker logs:

```powershell
docker logs soc-chat-coturn
```

You should now see:
```
INFO: IPv4. UDP listener opened on: 0.0.0.0:3478
INFO: IPv4. TCP listener opened on: 0.0.0.0:3478
```

Instead of only `127.0.0.1` and `172.19.0.2`.

### Step 3: Configure Router Port Forwarding (CRITICAL)

For cross-network calls to work, your router must forward UDP ports to your server:

**Required Ports:**
- **UDP 3478**: TURN control port
- **UDP 50000-50100**: Media relay ports (101 ports)

**Router Configuration:**
1. Access your router admin panel (usually `192.168.1.1` or `192.168.0.1`)
2. Find "Port Forwarding" or "Virtual Server" settings
3. Add these rules:
   - **Rule 1**: External Port `3478` (UDP) → Internal IP `10.120.4.230:3478`
   - **Rule 2**: External Port `50000-50100` (UDP) → Internal IP `10.120.4.230:50000-50100`

**Note**: If you don't have router access, you **MUST** use a cloud TURN service (Twilio) instead.

### Step 4: Configure Windows Firewall

Allow UDP traffic through Windows Firewall:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "TURN Server UDP 3478" -Direction Inbound -Protocol UDP -LocalPort 3478 -Action Allow
New-NetFirewallRule -DisplayName "TURN Server UDP 50000-50100" -Direction Inbound -Protocol UDP -LocalPort 50000-50100 -Action Allow
```

Or use the existing script:
```powershell
.\scripts\configure_firewall_for_turn.ps1
```

### Step 5: Verify Public IP Configuration

Ensure your server's public IP (`41.33.106.54`) is correctly configured:

1. **Check if public IP matches your actual public IP:**
   ```powershell
   (Invoke-WebRequest -Uri "https://api.ipify.org").Content
   ```

2. **Update `scripts/coturn-docker-compose.yml` if different:**
   ```yaml
   --external-ip=YOUR_ACTUAL_PUBLIC_IP
   ```

3. **Update `servers/local_api_server/server.js` if different:**
   ```javascript
   publicIp: 'YOUR_ACTUAL_PUBLIC_IP', // Public IP for direct access (media relay)
   ```

## Alternative Solution: Use Cloud TURN (Recommended)

If you don't have router access, **use Twilio Cloud TURN** instead of self-hosted coturn:

### Advantages:
- ✅ No router configuration needed
- ✅ Works from anywhere (no port forwarding)
- ✅ More reliable for cross-network calls
- ✅ Handles NAT traversal automatically

### Setup:

1. **Get Twilio credentials:**
   - Sign up at https://www.twilio.com/
   - Get Account SID and Auth Token
   - Enable Network Traversal Service

2. **Configure environment variables:**
   ```env
   # servers/local_api_server/.env
   CLOUD_TURN_ENABLED=true
   TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   TWILIO_AUTH_TOKEN=your_auth_token_here
   ```

3. **Restart the API server:**
   ```powershell
   # The server will automatically use Twilio TURN instead of coturn
   ```

## Testing

After applying fixes:

1. **Test same-network call** (should work):
   - Both devices on same WiFi
   - Should see/hear each other

2. **Test cross-network call** (should now work):
   - Device 1 on WiFi
   - Device 2 on mobile data (different network)
   - Should see/hear each other

3. **Check logs:**
   ```powershell
   # coturn logs
   docker logs -f soc-chat-coturn
   
   # Look for:
   # - "session" messages showing active connections
   # - "relay" messages showing media relay activity
   ```

## Troubleshooting

### Issue: Still not working after fixes

1. **Check if ports are accessible:**
   ```powershell
   # Test from external network (use online port checker)
   # Test UDP port 3478 on your public IP
   ```

2. **Check router logs:**
   - Verify port forwarding rules are active
   - Check if firewall is blocking traffic

3. **Check coturn logs:**
   ```powershell
   docker logs soc-chat-coturn | Select-String "session\|relay\|error"
   ```

4. **Verify TURN server in client:**
   - Check device logs for TURN server configuration
   - Verify it's using public IP (`41.33.106.54:3478`), not local IP

### Issue: Router doesn't support port forwarding

**Solution**: Use cloud TURN (Twilio) - see "Alternative Solution" above.

## Summary

✅ **Fixed**: coturn now listens on `0.0.0.0` (all interfaces)
⏳ **Required**: Router port forwarding for UDP ports 3478 and 50000-50100
⏳ **Required**: Windows Firewall rules to allow UDP traffic
⏳ **Optional**: Use cloud TURN (Twilio) if router access unavailable

