# Router Port Forwarding Setup for TURN Server

## Server Information
- **Public IP**: 41.33.106.54
- **Local IP**: 10.120.4.230
- **TURN Control Port**: 3478 (UDP/TCP)
- **Media Relay Ports**: 50000-50100 (UDP)

## Router Configuration Required

### Step 1: Access Router Admin Panel
1. Open browser and go to router admin (usually `192.168.1.1` or `192.168.0.1`)
2. Login with admin credentials
3. Navigate to "Port Forwarding" or "Virtual Server" section

### Step 2: Forward TURN Control Port
**Port Forwarding Rule 1:**
- **External Port**: 3478
- **Internal Port**: 3478
- **Protocol**: UDP
- **Internal IP**: 10.120.4.230
- **Description**: TURN Control

**Port Forwarding Rule 2:**
- **External Port**: 3478
- **Internal Port**: 3478
- **Protocol**: TCP
- **Internal IP**: 10.120.4.230
- **Description**: TURN Control TCP

### Step 3: Forward Media Relay Ports
**Port Forwarding Rule 3:**
- **External Port Range**: 50000-50100
- **Internal Port Range**: 50000-50100
- **Protocol**: UDP
- **Internal IP**: 10.120.4.230
- **Description**: TURN Media Relay

### Step 4: Save and Apply
- Save all rules
- Router may need to restart
- Wait 1-2 minutes for changes to take effect

## Verification

### Test Port Forwarding:
```powershell
# From external network, test if ports are accessible
# (Use online port checker or from mobile device)
```

### Test TURN Server:
```powershell
# Test TCP port (TURN control)
Test-NetConnection -ComputerName 41.33.106.54 -Port 3478

# For UDP testing, use the test script:
.\scripts\test_turn_ports.ps1

# OR use online port checker:
# https://www.yougetsignal.com/tools/open-ports/
# Enter: 41.33.106.54
# Ports: 3478 (UDP), 50000-50100 (UDP)
```

## Important Notes

⚠️ **Security Considerations:**
- Opening ports exposes your server to the internet
- Ensure firewall is configured (Windows Firewall + Router Firewall)
- Use strong TURN credentials
- Monitor for suspicious activity

✅ **After Configuration:**
1. Restart coturn: `docker-compose -f scripts/coturn-docker-compose.yml restart`
2. Configure Windows Firewall: `.\scripts\configure_firewall_for_turn.ps1`
3. Test from external network

## Troubleshooting

**Ports not accessible:**
- Check router firewall settings
- Verify internal IP is correct (10.120.4.230)
- Check if server firewall is blocking
- Verify coturn is running

**Media still not working:**
- Verify port forwarding is active
- Check if public IP changed (may be dynamic)
- Test with port checker tool
- Check coturn logs: `docker logs soc-chat-coturn`

