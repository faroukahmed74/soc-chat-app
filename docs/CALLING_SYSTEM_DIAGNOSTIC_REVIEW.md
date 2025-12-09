# SOC Chat App - Calling System Comprehensive Diagnostic Review
**Date:** December 8, 2025  
**Issue:** Media streams not reaching devices on different networks

---

## 🔍 Executive Summary

This document provides a comprehensive review of the entire calling system to diagnose why media streams are not working across different networks.

---

## 1. TURN Server Configuration ✅

### API Server Configuration
- **Endpoint:** `/api/webrtc/turn-config`
- **Status:** ✅ Working
- **ngrok TCP Tunnel:** `tcp://7.tcp.eu.ngrok.io:18111`
- **TURN Servers Returned:**
  1. `turn:7.tcp.eu.ngrok.io:18111` (ngrok - PRIMARY for mobile)
  2. `turn:7.tcp.eu.ngrok.io:18111?transport=tcp` (ngrok TCP - PRIMARY for mobile)
  3. `turn:10.120.4.230:3478` (local IP - fallback)
  4. `turn:10.120.4.230:3478?transport=tcp` (local IP TCP - fallback)

### Mobile App Configuration
- **Location:** `lib/main.dart` → `_initializeWebRTCCallService()`
- **Status:** ✅ Configured
- **ngrok URL:** `https://soc-chat-app.ngrok-free.app`
- **TURN Config Fetch:** `_configureMobileTurnWithNgrok()` in `webrtc_call_service.dart`

### Potential Issues:
- ⚠️ **TURN config might not be fetched before calls start** (fixed with await)
- ⚠️ **Need to verify mobile app actually receives ngrok TURN servers**

---

## 2. ICE Server Configuration ✅

### Peer Connection Setup
- **Location:** `lib/services/webrtc_call_service.dart` → `_createPeerConnection()`
- **ICE Servers:** Configured from `_iceServers` list
- **Priority Order (Mobile):**
  1. ngrok TURN servers (first)
  2. Local IP TURN servers (fallback)
  3. STUN servers (always included)

### Logging
- ✅ Logs show which TURN servers are configured
- ✅ Warns if ngrok TURN servers are missing
- ✅ Logs ICE candidate types (host, srflx, relay)

### Potential Issues:
- ⚠️ **Need to verify RELAY candidates are being generated**
- ⚠️ **ICE candidates might not be using TURN servers**

---

## 3. ICE Candidate Exchange ✅

### Client Side
- **Location:** `lib/services/webrtc_call_service.dart`
- **Event:** `webrtc_ice_candidate`
- **Handler:** `_handleWebRTCSignal()` → case 'ice-candidate'
- **Status:** ✅ Implemented

### Server Side
- **Location:** `servers/local_api_server/server.js`
- **Event:** `webrtc_ice_candidate`
- **Routing:** Routes to target user or call room
- **Status:** ✅ Implemented

### ICE Candidate Logging
- ✅ Logs RELAY candidates (TURN usage)
- ✅ Logs srflx candidates (STUN usage)
- ✅ Logs host candidates (local)

### Potential Issues:
- ⚠️ **ICE candidates might not be exchanged properly**
- ⚠️ **RELAY candidates might not be generated**

---

## 4. Media Stream Setup ✅

### Local Stream
- **Location:** `lib/services/webrtc_call_service.dart` → `_getLocalStream()`
- **Tracks Added:** Before creating offer/answer
- **Status:** ✅ Implemented

### Remote Stream
- **Handlers:** `onAddStream` (legacy) and `onTrack` (modern)
- **Status:** ✅ Both implemented
- **Stream Storage:** Stored in `_remoteStreams` map

### Potential Issues:
- ⚠️ **Tracks might not be added before offer/answer**
- ⚠️ **Remote stream might not be received**

---

## 5. Connection State Handling ✅

### ICE Connection State
- **States Monitored:** Connected, Completed, Disconnected, Failed, Closed
- **Logging:** ✅ Comprehensive logging
- **Reconnection:** ✅ Implemented

### Peer Connection State
- **States Monitored:** Connected, Disconnected, Failed, Closed
- **Logging:** ✅ Comprehensive logging

### Potential Issues:
- ⚠️ **Connection might not reach Connected state**
- ⚠️ **ICE connection might fail before using TURN**

---

## 6. Critical Issues to Check

### Issue 1: TURN Servers Not Being Used
**Symptoms:**
- Only host/srflx candidates in logs
- No RELAY candidates
- Connection fails on different networks

**Diagnosis:**
- Check mobile app logs for "RELAY candidate" messages
- Verify TURN servers are in ICE configuration
- Check if TURN server credentials are correct

**Fix:**
- Ensure ngrok TURN servers are fetched before calls
- Verify TURN server credentials match coturn config
- Check if TURN server is accessible from mobile devices

### Issue 2: ICE Candidates Not Exchanged
**Symptoms:**
- Connection state stuck at "checking"
- No remote stream received
- ICE connection fails

**Diagnosis:**
- Check if `webrtc_ice_candidate` events are being sent/received
- Verify Socket.IO connection is active
- Check server logs for ICE candidate routing

**Fix:**
- Ensure Socket.IO connection is established
- Verify event names match (client vs server)
- Check network connectivity

### Issue 3: Media Tracks Not Added
**Symptoms:**
- Connection established but no audio/video
- Remote stream exists but no tracks
- SDP doesn't include media

**Diagnosis:**
- Check if tracks are added before offer/answer
- Verify SDP includes media lines
- Check if tracks are enabled

**Fix:**
- Ensure tracks are added before creating offer/answer
- Verify track permissions are granted
- Check if tracks are enabled

---

## 7. Diagnostic Checklist

### Pre-Call Checks
- [ ] TURN config is fetched on app startup
- [ ] ngrok TURN servers are in ICE configuration
- [ ] TURN server credentials are correct
- [ ] Socket.IO connection is established
- [ ] Camera/microphone permissions are granted

### During Call Checks
- [ ] RELAY candidates are generated (check logs)
- [ ] ICE candidates are exchanged (check logs)
- [ ] Connection reaches "Connected" state
- [ ] Local tracks are added to peer connection
- [ ] Remote tracks are received via onTrack

### Post-Call Checks
- [ ] Connection state logs show "Connected"
- [ ] Remote stream exists in `_remoteStreams` map
- [ ] UI displays remote video/audio
- [ ] No errors in logs

---

## 8. Recommended Debugging Steps

### Step 1: Verify TURN Configuration
```bash
# Check API server returns ngrok TURN servers
curl http://localhost:3003/api/webrtc/turn-config

# Check mobile app logs for TURN config fetch
# Look for: "[TURN_CONFIG] Fetching TURN configuration..."
# Look for: "✅ TURN servers configured with ngrok TCP tunnel"
```

### Step 2: Check ICE Candidates
```bash
# On mobile device, check logs for:
# - "[ICE_CANDIDATE] ✅ RELAY candidate" (TURN usage)
# - "[ICE_CANDIDATE] Server reflexive candidate" (STUN usage)
# - "[ICE_CANDIDATE] Host candidate" (local)
```

### Step 3: Verify Connection State
```bash
# Check logs for:
# - "[ICE_CONNECTION] ✅ Connection established"
# - "[CONNECTION] ✅ Peer connection connected"
# - "[ON_TRACK] ✅ REMOTE TRACK RECEIVED"
```

### Step 4: Check Media Streams
```bash
# Check logs for:
# - "[ON_ADD_STREAM] ✅ REMOTE STREAM RECEIVED"
# - "[ON_TRACK] ✅ Stream found in event!"
# - Remote stream tracks count > 0
```

---

## 9. Known Issues and Fixes

### Issue: TURN Config Not Fetched Before Calls
**Status:** ✅ FIXED
**Fix:** Added `await` to `_initializeWebRTCCallService()` in `main.dart`

### Issue: Duplicate Call Screens
**Status:** ✅ FIXED
**Fix:** Made `ActiveCallTracker.setActiveCall()` atomic

### Issue: Media Streams Not Reaching
**Status:** 🔴 INVESTIGATING
**Possible Causes:**
1. TURN servers not being used (no RELAY candidates)
2. ICE candidates not exchanged
3. Connection not establishing
4. Media tracks not added correctly

---

## 10. Next Steps

1. **Add Enhanced Logging:**
   - Log all ICE candidates with full details
   - Log TURN server usage confirmation
   - Log connection state transitions
   - Log media track addition/removal

2. **Verify TURN Server:**
   - Test coturn server directly
   - Verify ngrok tunnel is accessible
   - Check TURN server credentials

3. **Test Cross-Network Calls:**
   - Use mobile data on one device
   - Check logs for RELAY candidates
   - Verify connection establishes
   - Confirm media streams flow

4. **Monitor Real-Time:**
   - Use `adb logcat` or Flutter DevTools
   - Filter for WebRTC-related logs
   - Check for errors or warnings

---

## 11. Critical Code Sections to Review

1. **TURN Configuration:** `lib/services/webrtc_call_service.dart:204-301`
2. **Peer Connection:** `lib/services/webrtc_call_service.dart:881-928`
3. **ICE Candidates:** `lib/services/webrtc_call_service.dart:933-956`
4. **Media Streams:** `lib/services/webrtc_call_service.dart:958-1112`
5. **Connection State:** `lib/services/webrtc_call_service.dart:1116-1199`

---

**Last Updated:** December 8, 2025

