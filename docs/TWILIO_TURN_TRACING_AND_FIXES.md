# Twilio TURN Server Tracing and Fixes

## Issue Identified
Server logs showed:
- ✅ TURN config is being fetched successfully (`GET /api/webrtc/turn-config 200`)
- ✅ Server returns 3 Twilio TURN servers with credentials
- ❌ **NO RELAY candidates generated** - only HOST and SRFLX candidates

This indicates TURN servers are configured but **not being used** by WebRTC.

## Root Causes Found

### 1. TURN Server Removal Logic Issue
**Problem:** The code only removed servers starting with `turn:`, but Twilio also uses `turns:` (secure TURN). This could cause duplicates or old servers to interfere.

**Fix:** Updated removal logic to handle both `turn:` and `turns:`:
```dart
_iceServers.removeWhere((server) {
  final urls = server['urls']?.toString() ?? '';
  return urls.startsWith('turn:') == true || urls.startsWith('turns:') == true;
});
```

### 2. Twilio Credential Format Issue
**Problem:** The environment setup script was using incorrect format:
- `CLOUD_TURN_USERNAME=ACCOUNT_SID:AUTH_TOKEN` (67 chars) ❌
- `CLOUD_TURN_PASSWORD=AUTH_TOKEN` (32 chars) ✅

For Twilio TURN static credentials, the format should be:
- Username: Just the Account SID (not `ACCOUNT_SID:AUTH_TOKEN`)
- Credential: Auth Token

**Better Solution:** Use Twilio's Token API (recommended) instead of static credentials.

### 3. Missing Twilio Token API Support
**Problem:** Server was using static credentials instead of Twilio's Token API, which:
- Generates proper time-limited credentials
- Is more secure
- Is the recommended approach by Twilio

**Fix:** Added Twilio Token API support:
- Added `generateTwilioTurnCredentials()` function
- Server now tries Token API first, falls back to static credentials
- Updated environment variables to include `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`

### 4. TURN Server Prioritization
**Problem:** TURN servers might not be prioritized correctly in WebRTC configuration.

**Fix:** Added reordering logic to ensure TURN servers are first in the ICE servers list:
```dart
// For mobile: TURN servers FIRST (critical for cross-network calls)
reorderedIceServers.addAll(turnServersList);
reorderedIceServers.addAll(stunServersList);
```

### 5. Insufficient Tracing/Logging
**Problem:** No comprehensive logging to verify TURN servers are:
- Fetched from API
- Added to `_iceServers`
- Passed to WebRTC peer connections
- Used to generate RELAY candidates

**Fix:** Added comprehensive verification logging:
- Logs each TURN server being added with full details
- Verifies credentials are present
- Logs final `_iceServers` configuration
- Shows TURN server type (Twilio, ngrok, local)

## Changes Made

### Server-Side (`servers/local_api_server/server.js`)
1. ✅ Added `https` module for Twilio API calls
2. ✅ Added `generateTwilioTurnCredentials()` function
3. ✅ Updated TURN config endpoint to use Token API first
4. ✅ Falls back to static credentials if Token API fails
5. ✅ Added environment variables: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`

### Client-Side (`lib/services/webrtc_call_service.dart`)
1. ✅ Fixed TURN server removal to handle both `turn:` and `turns:`
2. ✅ Added TURN server prioritization (TURN first for mobile)
3. ✅ Added comprehensive verification logging
4. ✅ Added detailed logging of each TURN server with credentials

### Environment Setup (`servers/local_api_server/SET_TWILIO_ENV.ps1`)
1. ✅ Updated to set `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN` for Token API
2. ✅ Fixed static credential format (username = Account SID only)
3. ✅ Kept static credentials as fallback

## Verification Steps

### 1. Update Environment Variables
Run the updated setup script:
```powershell
cd servers/local_api_server
.\SET_TWILIO_ENV.ps1
```
<!-- 
This will set:
- `TWILIO_ACCOUNT_SID=your_account_sid_here` (your Twilio Account SID from Twilio console)
- `TWILIO_AUTH_TOKEN=your_auth_token_here` (your Twilio Auth Token from Twilio console)
- `CLOUD_TURN_ENABLED=true`
- `CLOUD_TURN_URLS=...` (Twilio TURN URLs) -->

### 2. Restart API Server
Restart the API server to load new environment variables.

### 3. Check Server Logs
When `/api/webrtc/turn-config` is called, you should see:
```
✅ [TURN_CONFIG] Twilio Token API: Generated TURN credentials successfully
✅ [TURN_CONFIG] Twilio Token API: Generated X TURN servers
```

OR (if Token API fails):
```
⚠️ [TURN_CONFIG] Twilio Token API failed, falling back to static credentials
```

### 4. Check Client Logs
On mobile devices, look for:
```
🔵 [TURN_CONFIG] ========== VERIFICATION: TURN Servers in _iceServers ==========
   1. URL: turn:global.turn.twilio.com:3478?transport=udp
      Username: ✅ Present (XX chars)
      Credential: ✅ Present (32 chars)
      Type: ✅ Twilio TURN
```

### 5. Check for RELAY Candidates
In server logs during a call, you should see:
```
🔵 [SERVER] ✅✅✅ RELAY (TURN) ICE candidate for call ...
   TURN Server: X.X.X.X:XXXX (CLOUD (Twilio) ✅)
```

## Expected Behavior After Fixes

1. **Server:** Uses Twilio Token API to generate proper credentials
2. **Client:** Fetches TURN config, adds Twilio TURN servers to `_iceServers`
3. **WebRTC:** Uses TURN servers to generate RELAY candidates
4. **Media Stream:** RELAY candidates allow cross-network media streaming

## Next Steps

1. ✅ Run `SET_TWILIO_ENV.ps1` to update environment variables
2. ✅ Restart API server
3. ✅ Rebuild APK with fixes
4. ✅ Test cross-network call
5. ✅ Verify RELAY candidates appear in logs
6. ✅ Verify media streams work across networks

## Troubleshooting

### If Token API Fails
- Check `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN` are correct
- Verify Twilio account is active
- Check network connectivity to `api.twilio.com`
- Server will fall back to static credentials automatically

### If Still No RELAY Candidates
- Check client logs for TURN server verification messages
- Verify TURN servers are in `_iceServers` when peer connections are created
- Check if TURN servers have valid credentials
- Verify network can reach Twilio TURN servers (ports 3478 UDP/TCP, 5349 TCP)

### If Media Still Not Working
- Verify RELAY candidates are being generated (check server logs)
- Check if ICE connection state reaches "connected"
- Verify both devices are using TURN servers (check logs from both devices)
- Test with Twilio Network Test: https://networktest.twilio.com/

