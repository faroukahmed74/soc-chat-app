# Cross-Network Media Stream Debugging Guide

## Current Status
- ✅ Server TURN Configuration: CORRECT (3 Twilio TURN servers with credentials)
- ✅ Twilio Token API: Working
- ❌ Media streams still not working cross-network

## Diagnostic Steps

### Step 1: Verify API Server Restart
**CRITICAL:** The API server MUST be restarted after updating the `.env` file.

1. **Check if server was restarted:**
   - Look at server startup time
   - Check if server logs show the new token being used

2. **Restart the server:**
   ```powershell
   # Stop current server (Ctrl+C)
   cd servers/local_api_server
   node server.js
   ```

3. **Verify new token is loaded:**
   - Look for: `✅ [TURN_CONFIG] Twilio Token API: Generated TURN credentials successfully`
   - If you see errors about token authentication, the server wasn't restarted

### Step 2: Check Device TURN Configuration

**On both devices, check logs for:**

1. **TURN Config Fetch:**
   ```
   🔵 [TURN_CONFIG] Fetching TURN configuration from server
   🔵 [TURN_CONFIG] URL: https://your-ngrok-url/api/webrtc/turn-config
   🔵 [TURN_CONFIG] Response status: 200
   🔵 [TURN_CONFIG] Turn servers count: 3
   ```

2. **TURN Servers Added:**
   ```
   🔵 [TURN_CONFIG] ✅ Mobile TURN servers configured with cloud/ngrok
   🔵 [TURN_CONFIG] Found 3 cloud/ngrok TURN server(s)
   ```

3. **TURN Servers in Peer Connection:**
   ```
   🔵 [PEER_CONNECTION] ICE servers being used for this peer connection:
      - URL: turn:global.turn.twilio.com:3478?transport=udp
        Type: CLOUD (Twilio/Xirsys)
        Credentials: ✅ Present
   ```

### Step 3: Check ICE Candidates During Call

**In server logs, look for:**

1. **RELAY Candidates (TURN):**
   ```
   🔵 [SERVER] ✅✅✅ RELAY ICE candidate (TURN) for call ...
      TURN Server: 196.156.29.213:XXXX (CLOUD (Twilio) ✅)
   ```

2. **If you only see HOST and SRFLX:**
   - Devices are not using TURN servers
   - Check if TURN servers were fetched correctly
   - Check if TURN servers have valid credentials

### Step 4: Verify Network Connectivity

**Test if devices can reach Twilio TURN servers:**

1. **From Device 1:**
   - Check if UDP port 3478 is accessible
   - Check if TCP ports 3478 and 5349 are accessible

2. **From Device 2:**
   - Same checks as Device 1

3. **Common Issues:**
   - Carrier blocking TURN servers
   - Firewall blocking UDP/TCP ports
   - Network restrictions

### Step 5: Check Server Logs During Call

**Look for these patterns:**

1. **Successful TURN Usage:**
   ```
   ✅ [TURN_CONFIG] Twilio Token API: Generated TURN credentials successfully
   🔵 [SERVER] ✅✅✅ RELAY ICE candidate (TURN)
   ```

2. **Failed TURN Usage:**
   ```
   ⚠️ [TURN_CONFIG] Twilio Token API failed
   🔵 [SERVER] HOST (local) ICE candidate
   🔵 [SERVER] SRFLX (STUN) ICE candidate
   (NO RELAY candidates)
   ```

## Common Issues and Solutions

### Issue 1: API Server Not Restarted
**Symptom:** Server still using old token, TURN API fails
**Solution:** Restart API server

### Issue 2: Devices Not Fetching TURN Config
**Symptom:** No `[TURN_CONFIG]` logs on devices
**Solution:** 
- Check `DatabaseConfig.physicalServerUrl` is set correctly
- Check network connectivity to server
- Check if TURN initialization completes before calls start

### Issue 3: TURN Servers Not Added to _iceServers
**Symptom:** TURN config fetched but no TURN servers in peer connection
**Solution:**
- Check if `_turnServersConfigured` flag is preventing reset
- Check if TURN servers are being filtered out incorrectly

### Issue 4: Network Blocking TURN Servers
**Symptom:** RELAY candidates generated but connection fails
**Solution:**
- Test on different network (different WiFi or mobile data)
- Check carrier restrictions
- Verify firewall rules

### Issue 5: Wrong Token Being Used
**Symptom:** TURN API authentication errors
**Solution:**
- Verify `.env` file has correct token
- Restart API server
- Check server logs for token errors

## Quick Diagnostic Commands

### Check Server TURN Config:
```powershell
curl http://localhost:3003/api/webrtc/turn-config
```

### Test Twilio Token API:
```powershell
cd servers/local_api_server
node TEST_TWILIO_CREDENTIALS.js
```

### Check .env File:
```powershell
cd servers/local_api_server
Get-Content .env | Select-String "TWILIO"
```

## Expected Behavior

### When Working Correctly:

1. **Server:**
   - Returns 3 Twilio TURN servers with credentials
   - Token API generates credentials successfully

2. **Device 1:**
   - Fetches TURN config on app start
   - Adds 3 Twilio TURN servers to `_iceServers`
   - Generates RELAY candidates during call

3. **Device 2:**
   - Same as Device 1

4. **During Call:**
   - Both devices generate RELAY candidates
   - Server logs show RELAY candidates from both devices
   - Media streams work cross-network

## Next Steps

1. ✅ Verify API server was restarted
2. ⏳ Check device logs for TURN configuration
3. ⏳ Check server logs during a call
4. ⏳ Verify RELAY candidates are generated
5. ⏳ Test on different networks if needed

