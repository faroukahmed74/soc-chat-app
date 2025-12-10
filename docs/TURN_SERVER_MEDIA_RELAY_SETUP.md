# TURN Server Media Relay Setup Guide

## Critical Issue: Media Streams Not Working Across Networks

### Problem
- Calls connect successfully (signaling works)
- Call timer starts
- But no audio/video (users can't see or hear each other)
- Works fine on same WiFi/network
- Fails when devices are on different networks (using mobile data)

### Root Cause

**ngrok TCP tunnels do NOT forward UDP traffic.**

TURN servers require:
1. **Control traffic (TCP port 3478)**: For TURN protocol negotiation
   - ✅ Works through ngrok TCP tunnel
   
2. **Media relay traffic (UDP ports 49152-65535)**: For actual audio/video data
   - ❌ Does NOT work through ngrok TCP tunnel
   - Requires direct UDP access to the server

### Current Configuration Issues

1. **Port Range Too Small**
   - Docker only exposes: `49152-49200` (49 ports)
   - coturn needs: `49152-65535` (16,384 ports)
   - **Fixed**: Updated to full range

2. **Firewall May Block UDP Ports**
   - Windows Firewall may block UDP ports 49152-65535
   - **Solution**: Run `scripts/configure_firewall_for_turn.ps1` as Administrator

3. **External IP Configuration**
   - coturn uses local IP `10.120.4.230`
   - Media relay needs to know the public/ngrok IP
   - **Note**: ngrok TCP can't relay UDP, so this is a limitation

### Solutions

#### Option 1: Server with Public IP (Recommended)
If your server has a public IP address:

1. Configure Windows Firewall:
   ```powershell
   .\scripts\configure_firewall_for_turn.ps1
   ```

2. Update coturn external IP:
   - Get your server's public IP
   - Update `coturn-docker-compose.yml`:
     ```yaml
     --external-ip=<YOUR_PUBLIC_IP>
     ```

3. Configure router port forwarding:
   - Forward UDP ports `49152-65535` to server IP `10.120.4.230`

4. Update TURN config to use public IP for media relay

#### Option 2: Use VPN
- Set up a VPN (WireGuard, OpenVPN, etc.)
- Connect both devices to VPN
- Use VPN IP for TURN server

#### Option 3: ngrok Paid Tier with UDP Support
- Check if ngrok paid tier supports UDP tunnels
- Configure UDP tunnel for ports 49152-65535

#### Option 4: Alternative TURN Service
- Use a cloud TURN service (Twilio, Xirsys, etc.)
- Configure in `webrtc_call_service.dart`

### Immediate Fixes Applied

1. ✅ Expanded Docker port range: `49152-65535`
2. ✅ Created firewall configuration script
3. ✅ Updated documentation

### Next Steps

1. **Run firewall configuration** (as Administrator):
   ```powershell
   .\scripts\configure_firewall_for_turn.ps1
   ```

2. **Restart coturn container**:
   ```powershell
   cd scripts
   docker-compose -f coturn-docker-compose.yml down
   docker-compose -f coturn-docker-compose.yml up -d
   ```

3. **Check if server has public IP**:
   - Visit: https://whatismyipaddress.com/
   - If yes, configure port forwarding on router
   - If no, consider VPN or cloud TURN service

4. **Test media relay**:
   - Make call between devices on different networks
   - Check logs for RELAY candidates
   - Verify audio/video works

### Verification

Check if media relay is working:
```powershell
# Check if UDP ports are accessible
Test-NetConnection -ComputerName <SERVER_IP> -Port 3478 -Udp
```

Monitor coturn logs:
```powershell
docker logs -f soc-chat-coturn
```

Look for:
- `session` entries (TURN sessions established)
- `relay` entries (media relay active)
- Error messages about port binding

### Limitations

**Current setup will NOT work for cross-network calls** because:
- ngrok TCP tunnel only forwards TCP (control)
- Media relay requires UDP (not forwarded by ngrok TCP)
- Devices on different networks can't reach server's UDP ports directly

**Workaround**: Use same network or implement one of the solutions above.

