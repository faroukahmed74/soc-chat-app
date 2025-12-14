# Troubleshooting: Media Stream Not Working After Credential Change

## Issue
After updating Twilio credentials, cross-network media streams stop working.

## Root Causes

### 1. API Server Not Restarted (MOST COMMON)
**Problem:** The API server loads environment variables when it starts. If you update `.env` but don't restart the server, it will continue using the old credentials.

**Solution:**
1. Stop the API server (Ctrl+C in the terminal where it's running)
2. Start it again:
   ```bash
   cd servers/local_api_server
   node server.js
   ```

### 2. Invalid Credentials
**Problem:** The new credentials might be incorrect, expired, or the account might be suspended.

**Solution:**
1. Verify credentials in Twilio Console: https://console.twilio.com/
2. Test credentials using the test script:
   ```bash
   cd servers/local_api_server
   node TEST_TWILIO_CREDENTIALS.js
   ```
3. If credentials are invalid, update them:
   - Windows: Run `SET_TWILIO_CREDENTIALS.ps1`
   - macOS/Linux: Run `SET_TWILIO_CREDENTIALS.sh`

### 3. Mobile Apps Using Cached TURN Config
**Problem:** Mobile apps might have cached the old TURN configuration.

**Solution:**
1. **Force close the app** on both devices
2. **Clear app data** (Android: Settings > Apps > [App Name] > Storage > Clear Data)
3. **Restart the app** - it will fetch fresh TURN config from server

### 4. Server Not Loading .env File
**Problem:** The server might not be loading the `.env` file correctly.

**Solution:**
1. Verify `.env` file exists: `servers/local_api_server/.env`
2. Check file has correct format (no extra spaces, correct line endings)
3. Verify server.js has: `require('dotenv').config();` at the top
4. Restart server after any `.env` changes

## Verification Steps

### Step 1: Verify Credentials in .env
```bash
# Windows PowerShell
cd servers/local_api_server
Get-Content .env | Select-String "TWILIO"

# macOS/Linux
cd servers/local_api_server
grep TWILIO .env
```

Should show:
```
TWILIO_ACCOUNT_SID=YOUR_ACCOUNT_SID_HERE
TWILIO_AUTH_TOKEN=YOUR_AUTH_TOKEN_HERE
CLOUD_TURN_ENABLED=true
```

### Step 2: Test Twilio API
```bash
cd servers/local_api_server
node TEST_TWILIO_CREDENTIALS.js
```

Should show:
```
✅ SUCCESS: Twilio Token API is working!
   Generated X TURN server(s)
```

### Step 3: Check Server Logs
When a client requests TURN config (`GET /api/webrtc/turn-config`), server logs should show:
```
✅ [TURN_CONFIG] Twilio Token API: Generated TURN credentials successfully
✅ [TURN_CONFIG] Twilio Token API: Generated X TURN servers
```

If you see:
```
⚠️ [TURN_CONFIG] Twilio Token API failed, falling back to static credentials
```
This means the credentials are invalid or there's a network issue.

### Step 4: Check Client Logs
On mobile devices, check logs for:
```
✅ [TURN_CONFIG] TURN servers configured with CLOUD TURN service (Twilio/Xirsys)
✅ [TURN_CONFIG] Cross-network calls will work!
```

If you see:
```
❌ [TURN_CONFIG] CRITICAL: No cloud/ngrok TURN servers found!
```
The client is not receiving TURN servers from the server.

## Quick Fix Checklist

- [ ] ✅ Credentials updated in `.env` file
- [ ] ✅ API server **RESTARTED** after credential update
- [ ] ✅ Twilio credentials test passes (`node TEST_TWILIO_CREDENTIALS.js`)
- [ ] ✅ Server logs show "Twilio Token API: Generated TURN credentials successfully"
- [ ] ✅ Mobile apps **force closed and restarted** (to clear cached config)
- [ ] ✅ Both devices fetch TURN config when app starts
- [ ] ✅ Both devices generate RELAY candidates during calls

## Common Mistakes

1. **Updating .env but not restarting server** ❌
   - Server only reads `.env` when it starts
   - Always restart after credential changes

2. **Using wrong credentials** ❌
   - Account SID should start with `AC`
   - Auth Token should be 32 characters
   - Verify in Twilio Console

3. **Not clearing app cache** ❌
   - Mobile apps cache TURN config
   - Force close and restart app

4. **Testing on same network** ❌
   - Cross-network requires TURN servers
   - Test with one device on WiFi, other on mobile data

## Still Not Working?

1. Check server logs for errors
2. Check client logs for TURN config messages
3. Verify Twilio account is active (not suspended)
4. Test credentials directly with Twilio API
5. Check network connectivity to `api.twilio.com`

