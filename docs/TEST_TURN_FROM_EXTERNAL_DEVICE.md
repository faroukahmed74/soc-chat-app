# How to Test TURN Server from External Device

This guide explains how to test if router port forwarding is working by testing the TURN server from a device outside your network.

## Prerequisites

- A device on a **different network** (not connected to the same WiFi as your server)
  - Mobile phone using **mobile data** (4G/5G)
  - Laptop on a **different WiFi network**
  - Friend's device on their network

## Method 1: WebRTC Trickle ICE Test (Recommended)

This is the easiest and most reliable method.

### Steps:

1. **On your external device**, open a web browser (Chrome, Firefox, or Edge)

2. **Visit the Trickle ICE test page:**
   ```
   https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
   ```

3. **Add TURN server configuration:**
   - Scroll down to "ICE Servers" section
   - Click "Add Server"
   - Fill in the following:
     - **URLs:** `turn:41.33.106.54:3478`
     - **Username:** `soc-chat-turn`
     - **Password:** `yG5EJFUdLgT7xqXr`
   - Click "Add"

4. **Optional: Add TCP version too:**
   - Click "Add Server" again
   - Fill in:
     - **URLs:** `turn:41.33.106.54:3478?transport=tcp`
     - **Username:** `soc-chat-turn`
     - **Password:** `yG5EJFUdLgT7xqXr`
   - Click "Add"

5. **Gather candidates:**
   - Click the "Gather candidates" button
   - Wait for the test to complete (usually 10-30 seconds)

6. **Check the results:**
   Look at the candidate list. You should see entries like:
   ```
   candidate:... typ relay raddr 41.33.106.54 rport 50000 ...
   ```

### Interpreting Results:

✅ **Port Forwarding is WORKING if you see:**
- Candidates with `typ relay` (TURN relay candidates)
- `raddr 41.33.106.54` (your public IP)
- `rport` values between 50000-50100 (media relay ports)

❌ **Port Forwarding is NOT WORKING if you see:**
- Only `typ host` (local network candidates)
- Only `typ srflx` (STUN reflexive candidates)
- No `typ relay` candidates at all
- Connection errors or timeouts

## Method 2: ICE Test Tool (Alternative)

1. **Visit:**
   ```
   https://icetest.info/
   ```

2. **Enter TURN server details:**
   - **TURN Server:** `turn:41.33.106.54:3478`
   - **Username:** `soc-chat-turn`
   - **Password:** `yG5EJFUdLgT7xqXr`

3. **Click "Test"**

4. **Check results:**
   - Green checkmark = Port forwarding working
   - Red X or timeout = Port forwarding not configured

## Method 3: Test from Mobile App (Your Chat App)

If you have the app installed on a mobile device on a different network:

1. **Ensure the device is on mobile data** (not WiFi)
2. **Make a call** to another device on a different network
3. **Check the logs** for RELAY candidates:
   - Look for: `[ICE_CANDIDATE] ✅✅✅ RELAY candidate`
   - Check TURN server IP: Should show `41.33.106.54`
   - If you see RELAY candidates, port forwarding is working!

## Troubleshooting

### If you don't see RELAY candidates:

1. **Check router port forwarding:**
   - Verify UDP 3478 is forwarded to `10.120.4.230:3478`
   - Verify UDP 50000-50100 is forwarded to `10.120.4.230:50000-50100`

2. **Check router firewall:**
   - Some routers have an additional firewall that might block UDP
   - Temporarily disable router firewall for testing

3. **Check ISP restrictions:**
   - Some ISPs block incoming UDP traffic
   - Contact your ISP if needed

4. **Test from different external network:**
   - Try from a completely different network (mobile data vs different WiFi)

### If you see RELAY candidates but calls still fail:

1. **Check TURN server logs:**
   ```powershell
   docker logs --tail 50 soc-chat-coturn
   ```
   Look for connection attempts and errors

2. **Check Windows Firewall:**
   - Ensure firewall rules are enabled (they should be from the test script)

3. **Check Docker coturn configuration:**
   - Verify external IP is correct: `41.33.106.54`
   - Verify credentials match: `soc-chat-turn:yG5EJFUdLgT7xqXr`

## Quick Test Checklist

- [ ] Device is on a different network (mobile data or different WiFi)
- [ ] TURN server URL: `turn:41.33.106.54:3478`
- [ ] Username: `soc-chat-turn`
- [ ] Password: `yG5EJFUdLgT7xqXr`
- [ ] See `typ relay` candidates in results
- [ ] `raddr` shows `41.33.106.54`
- [ ] `rport` is between 50000-50100

## Expected Output (Success)

When port forwarding is working, you should see candidates like:

```
candidate:842163049 1 udp 2113667327 41.33.106.54 50000 typ relay raddr 41.33.106.54 rport 50000 generation 0 ufrag Vz11 network-id 1 network-cost 10
```

Key indicators:
- `typ relay` = TURN relay candidate (✅ working!)
- `raddr 41.33.106.54` = Your public IP (✅ correct!)
- `rport 50000` = Media relay port (✅ correct!)

## Next Steps

If port forwarding test **succeeds**:
- ✅ Router port forwarding is configured correctly
- ✅ Docker coturn should work for cross-network calls
- Test actual calls between devices on different networks

If port forwarding test **fails**:
- ❌ Router port forwarding is not configured
- Configure router port forwarding (see router admin panel)
- Or switch back to cloud TURN (Twilio) which doesn't need port forwarding

