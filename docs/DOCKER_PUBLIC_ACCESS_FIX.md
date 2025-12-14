# Docker coturn Public Access Configuration Fix

## Issue Found

The Docker coturn configuration was using **bridge network mode** (default), which can limit public access:

### Problems with Bridge Network Mode:
1. **Port Mapping Required**: Docker creates a virtual network, requiring port mapping
2. **Double NAT**: Traffic goes through Docker bridge + host network
3. **Router Port Forwarding**: Requires router to forward ports to Docker bridge IP
4. **Limited Public Access**: May not work reliably for external connections

## Fix Applied

### ✅ **Changed to `network_mode: host`**

This configuration:
- ✅ **Bypasses Docker networking** - binds directly to host interfaces
- ✅ **Direct public access** - no port mapping complications
- ✅ **Better for TURN servers** - reduces network latency
- ✅ **Works with public IP** - external IP `41.33.106.54` is directly accessible

### Updated Configuration:

```yaml
services:
  coturn:
    image: coturn/coturn:latest
    container_name: soc-chat-coturn
    restart: unless-stopped
    network_mode: host  # ✅ ADDED: Direct host network access
    environment:
      - EXTERNAL_IP=41.33.106.54
    command:
      -n
      --log-file=stdout
      --external-ip=41.33.106.54  # Public IP
      --listening-ip=0.0.0.0       # Listen on all interfaces
      --listening-port=3478
      --min-port=50000
      --max-port=50100
      # ... rest of config
```

## Important Notes

### ⚠️ **When using `network_mode: host`:**
1. **Port mappings are ignored** - Docker doesn't map ports, they're bound directly
2. **No port conflicts** - Make sure ports 3478, 50000-50100 are not used by other services
3. **Direct host access** - Container uses host's network stack directly
4. **Better performance** - No Docker networking overhead

### ✅ **Current Configuration Status:**

| Setting | Value | Status |
|---------|-------|--------|
| `network_mode` | `host` | ✅ **FIXED** |
| `listening-ip` | `0.0.0.0` | ✅ Correct |
| `external-ip` | `41.33.106.54` | ✅ Public IP |
| Ports | 3478 UDP/TCP, 50000-50100 UDP | ✅ Correct |

## Restart Required

After updating the Docker compose file, restart the container:

```powershell
cd scripts
docker-compose -f coturn-docker-compose.yml down
docker-compose -f coturn-docker-compose.yml up -d
```

## Verification

### 1. Check Container Status
```powershell
docker ps | grep soc-chat-coturn
```

### 2. Check Logs
```powershell
docker logs soc-chat-coturn
```

You should see:
```
INFO: IPv4. UDP listener opened on: 0.0.0.0:3478
INFO: IPv4. TCP listener opened on: 0.0.0.0:3478
```

### 3. Test Public Access
From an external network, test TURN server connectivity:
```bash
# Test STUN
turnutils_stunclient 41.33.106.54:3478

# Test TURN (requires credentials)
turnutils_peer -u soc-chat-turn -w yG5EJFUdLgT7xqXr 41.33.106.54:3478
```

## Router Port Forwarding

Even with `network_mode: host`, you may still need router port forwarding if:
- Server is behind NAT
- Router blocks incoming UDP traffic
- Firewall rules need to be configured

**Required Ports:**
- UDP 3478 (TURN control)
- UDP 50000-50100 (Media relay)

**Router Configuration:**
- External Port `3478` (UDP) → Internal IP `10.120.4.230:3478`
- External Port `50000-50100` (UDP) → Internal IP `10.120.4.230:50000-50100`

## Windows Firewall

Ensure Windows Firewall allows incoming traffic:

```powershell
# Run as Administrator
.\scripts\configure_firewall_for_turn.ps1
```

This opens:
- UDP/TCP port 3478
- UDP ports 50000-50100

## Important Note

⚠️ **You're currently using cloud TURN (Twilio)**, so the self-hosted coturn Docker container is **NOT being used** for cross-network calls.

The Docker coturn configuration is only used if:
- Cloud TURN is disabled (`CLOUD_TURN_ENABLED=false`)
- Devices are on the same network (local TURN)
- Router port forwarding is configured (public IP TURN)

For cross-network calls, **cloud TURN (Twilio) is the active solution**.

## Summary

✅ **Docker configuration is now set for public access:**
- `network_mode: host` - Direct host network access
- `listening-ip=0.0.0.0` - Listens on all interfaces
- `external-ip=41.33.106.54` - Public IP configured
- Ports configured correctly

⚠️ **But remember:** Since you're using cloud TURN (Twilio), this Docker coturn is not used for cross-network calls. The configuration is correct for future use if needed.

