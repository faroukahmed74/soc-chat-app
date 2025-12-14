# Debugging Cross-Network Media Streams

## Current Status from Server Logs

✅ **TURN Server Working**: RELAY candidates are being generated
✅ **SDP Contains Media**: Both offer and answer have `m=audio` and `m=video`
✅ **Call Established**: Both users joined the call room
⚠️ **Media Streams**: Not appearing (user reports)

## Key Observations

1. **TURN Server**: Using Twilio TURN (`18.156.18.191`) - this should work for cross-network
2. **RELAY Candidates**: Multiple RELAY candidates generated
3. **SDP Exchange**: Offers and answers are being exchanged successfully

## Diagnostic Steps

### Step 1: Check Device Logs During Call

Run these commands on both devices during an active call:

**Device 1:**
```powershell
adb -s 52001c52494e6747 logcat | findstr "ICE_CONNECTION|ON_TRACK|ON_ADD_STREAM|CALL_SCREEN|Receiver|TURN|RELAY"
```

**Device 2:**
```powershell
adb -s BVK6R19807005234 logcat | findstr "ICE_CONNECTION|ON_TRACK|ON_ADD_STREAM|CALL_SCREEN|Receiver|TURN|RELAY"
```

### Step 2: Look for These Critical Log Messages

**ICE Connection:**
- `[ICE_CONNECTION] ✅✅✅ Connection established`
- `[ICE_CONNECTION] Getting receivers to create remote stream`

**Track Reception:**
- `[ON_TRACK] ========== REMOTE TRACK RECEIVED ==========`
- `[ON_TRACK] Stream found in event!`
- `[ON_TRACK] Found X receivers`

**Stream Creation:**
- `[ICE_CONNECTION] Found X audio and Y video tracks`
- `[ICE_CONNECTION] Created stream with X audio and Y video tracks`
- `[ICE_CONNECTION] ✅ Callback triggered - UI should update now!`

**UI Updates:**
- `[CALL_SCREEN] onRemoteStream callback triggered`
- `[CALL_SCREEN] Renderer initialized and stream set`

### Step 3: Check for Errors

Look for:
- `❌ [ON_TRACK] Error creating stream`
- `⚠️ [ICE_CONNECTION] No tracks found in receivers`
- `⚠️ [ON_TRACK] WARNING: onRemoteStream callback is null!`

## Possible Issues

### Issue 1: onTrack Not Firing
**Symptom**: No `[ON_TRACK]` messages in logs
**Cause**: WebRTC not receiving tracks through TURN relay
**Solution**: Check if TURN server is actually relaying media

### Issue 2: Tracks in Receivers But No Stream
**Symptom**: `[ICE_CONNECTION] Found X receivers` but no stream created
**Cause**: Stream creation from receivers failing
**Solution**: Check error messages in stream creation code

### Issue 3: Stream Created But UI Not Updating
**Symptom**: `[ICE_CONNECTION] ✅ Callback triggered` but no video
**Cause**: UI callback not working or renderer issue
**Solution**: Check `[CALL_SCREEN]` logs

### Issue 4: Tracks Not Enabled
**Symptom**: Tracks exist but `enabled=false`
**Cause**: Tracks not being enabled
**Solution**: Code should enable tracks automatically (already implemented)

## Next Steps

1. **Capture device logs** during a cross-network call
2. **Share the logs** to identify which step is failing
3. **Check if onTrack is firing** - this is critical
4. **Verify receivers have tracks** - if not, TURN isn't relaying media

## Quick Test

To verify TURN is working:
1. Check server logs for RELAY candidates (✅ Already confirmed)
2. Check device logs for `[ICE_CANDIDATE] RELAY candidate`
3. Check if connection completes: `[ICE_CONNECTION] ✅✅✅ Connection established`

If connection completes but no media:
- TURN is working for signaling
- But media tracks aren't being received
- This is the issue we need to fix

