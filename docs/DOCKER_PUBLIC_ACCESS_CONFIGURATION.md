# Docker coturn Public Access Configuration

## Issue Found and Fixed

### ❌ **Previous Configuration (Local-Only Access):**
```yaml
ports:
  - "3478:3478/udp"    # Only accessible via Docker bridge
  - "3478:3478/tcp"
  - "50000-50100:50000-50100/udp"
```

**Problem:** Port mappings without `0.0.0.0` binding may only be accessible through Docker's bridge network, limiting public access.

### ✅ **Fixed Configuration (Public Access):**
```yaml
ports:
  - "0.0.0.0:3478:3478/udp"    # Bind to ALL host interfaces
  - "0.0.0.0:3478:3478/tcp"    # Bind to ALL host interfaces
  - "0.0.0.0:50000-50100:50000-50100/udp"  # Media relay ports
```

**Solution:** Explicitly binding to `0.0.0.0` ensures ports are accessible on all host network interfaces, including the public IP.

---

## Complete Configuration

### Current Docker Compose File:
```yaml
services:
  coturn:
    image: coturn/coturn:latest
    container_name: soc-chat-coturn
    restart: unless-stopped
    ports:
      - "0.0.0.0:3478:3478/udp"    # ✅ Public access enabled
      - "0.0.0.0:3478:3478/tcp"    # ✅ Public access enabled
      - "0.0.0.0:50000-50100:50000-50100/udp"  # ✅ Public access enabled
    environment:
      - EXTERNAL_IP=41.33.106.54   # ✅ Public IP configured
    command:
      -n
      --log-file=stdout
      --external-ip=41.33.106.54   # ✅ Public IP
      --listening-ip=0.0.0.0       # ✅ Listen on all interfaces
      --listening-port=3478
      --min-port=50000
      --max-port=50100
      --realm=soc-chat-app.local
      --user=soc-chat-turn:yG5EJFUdLgT7xqXr
      # ... rest of config
```

---

## Configuration Verification

### ✅ **All Settings Correct for Public Access:**

| Setting | Value | Status | Purpose |
|---------|-------|--------|---------|
| **Port Binding** | `0.0.0.0:3478` | ✅ **FIXED** | Binds to all host interfaces |
| **Listening IP** | `0.0.0.0` | ✅ Correct | Listens on all interfaces |
| **External IP** | `41.33.106.54` | ✅ Correct | Public IP for TURN relay |
| **Port Range** | `50000-50100` | ✅ Correct | Media relay ports |

---

## What `0.0.0.0` Binding Does

### Before (Without `0.0.0.0`):
```
Docker Bridge Network
  └──> Port 3478 (may only be accessible locally)
```

### After (With `0.0.0.0`):
```
Host Network Interfaces
  ├──> 127.0.0.1:3478 (localhost)
  ├──> 10.120.4.230:3478 (local network)
  └──> 41.33.106.54:3478 (public IP) ✅
```

**Result:** Ports are accessible on **ALL** host network interfaces, including the public IP.

---

## Restart Required

After updating the configuration, restart the container:

```powershell
cd scripts
docker-compose -f coturn-docker-compose.yml down
docker-compose -f coturn-docker-compose.yml up -d
```

## Verification Steps

### 1. Check Container Status
```powershell
docker ps | grep soc-chat-coturn
```

### 2. Check Logs
```powershell
docker logs soc-chat-coturn
```

Look for:
```
INFO: IPv4. UDP listener opened on: 0.0.0.0:3478
INFO: IPv4. TCP listener opened on: 0.0.0.0:3478
```

### 3. Check Port Binding
```powershell
netstat -an | findstr "3478"
```

Should show:
```
UDP    0.0.0.0:3478           *:*
TCP    0.0.0.0:3478           *:*
```

### 4. Test Public Access (from external network)
```bash
# Test STUN
turnutils_stunclient 41.33.106.54:3478

# Test TURN (requires credentials)
turnutils_peer -u soc-chat-turn -w yG5EJFUdLgT7xqXr 41.33.106.54:3478
```

---

## Additional Requirements for Public Access

### 1. Windows Firewall
Ensure ports are open:
```powershell
# Run as Administrator
.\scripts\configure_firewall_for_turn.ps1
```

### 2. Router Port Forwarding
If server is behind NAT/router:
- Forward UDP 3478 → `10.120.4.230:3478`
- Forward UDP 50000-50100 → `10.120.4.230:50000-50100`

### 3. Network Configuration
- Server must have public IP or be accessible via port forwarding
- Router must allow incoming UDP traffic
- No firewall blocking TURN ports

---

## Important Note

⚠️ **You're currently using cloud TURN (Twilio)**, so this Docker coturn container is **NOT being used** for cross-network calls.

**Active Configuration:**
- ✅ Cloud TURN (Twilio) - **ACTIVE** for cross-network calls
- ⚠️ Docker coturn - **NOT USED** (only for same-network or if cloud TURN disabled)

**This Docker fix ensures:**
- ✅ Configuration is correct for public access
- ✅ Ready if you need to use self-hosted TURN later
- ✅ Works for same-network calls

---

## Summary

✅ **Docker configuration is now set for public access:**
1. Ports bind to `0.0.0.0` (all interfaces) ✅
2. `listening-ip=0.0.0.0` (listens on all interfaces) ✅
3. `external-ip=41.33.106.54` (public IP configured) ✅
4. Port mappings correct for public access ✅

**Next Steps:**
1. Restart Docker container to apply changes
2. Verify ports are bound to `0.0.0.0`
3. Test public access from external network
4. Configure router port forwarding if needed

