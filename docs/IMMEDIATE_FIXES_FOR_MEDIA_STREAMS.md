# Immediate Fixes for Media Streams Across Networks

## Problem
Calls connect but no audio/video when devices are on different networks (using mobile data).

## Root Cause
**ngrok TCP tunnels do NOT forward UDP traffic.** Media relay requires UDP ports 49152-65535, which cannot work through ngrok TCP tunnel.

## Immediate Actions Required

### 1. Configure Windows Firewall (REQUIRED)
Run as Administrator:
```powershell
.\scripts\configure_firewall_for_turn.ps1
```

This opens:
- TCP/UDP port 3478 (TURN control)
- UDP ports 49152-65535 (media relay)

### 2. Restart coturn with New Port Range
```powershell
cd scripts
docker-compose -f coturn-docker-compose.yml down
docker-compose -f coturn-docker-compose.yml up -d
```

### 3. Check Server Public IP
```powershell
.\scripts\check_server_public_ip.ps1
```

### 4. If Server Has Public IP
1. Configure router to forward UDP ports 49152-65535 to server IP (10.120.4.230)
2. Update `coturn-docker-compose.yml`:
   ```yaml
   --external-ip=<YOUR_PUBLIC_IP>
   ```
3. Restart coturn

### 5. If Server is Behind NAT (No Public IP)
**Options:**
- **Option A**: Use VPN (WireGuard/OpenVPN) - connect both devices
- **Option B**: Use cloud TURN service (Twilio, Xirsys)
- **Option C**: Configure router port forwarding if you have access

## Current Limitations

⚠️ **ngrok TCP tunnel CANNOT relay UDP media traffic**

- ✅ TURN control (TCP) works through ngrok
- ❌ Media relay (UDP) does NOT work through ngrok
- ✅ Same network calls work (direct UDP access)
- ❌ Cross-network calls fail (no UDP access)

## Verification

After applying fixes, test:
1. Make call between devices on different networks
2. Check logs for RELAY candidates
3. Verify audio/video works

Monitor coturn logs:
```powershell
docker logs -f soc-chat-coturn
```

Look for:
- `session` entries (TURN sessions)
- `relay` entries (media relay active)
- No port binding errors

## Files Changed

1. ✅ `scripts/coturn-docker-compose.yml` - Expanded port range
2. ✅ `scripts/configure_firewall_for_turn.ps1` - Firewall configuration
3. ✅ `scripts/check_server_public_ip.ps1` - Network check
4. ✅ `docs/TURN_SERVER_MEDIA_RELAY_SETUP.md` - Full documentation

