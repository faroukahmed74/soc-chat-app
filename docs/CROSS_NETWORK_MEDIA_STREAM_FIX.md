# Cross-Network Media Stream Fix

## Problem
Cross-network calls connect successfully (ICE connection established), but media streams don't appear:
- ✅ Call screen appears
- ✅ Call timer starts
- ✅ Each user sees their own video (local stream)
- ❌ Users cannot see/hear each other (remote streams not appearing)

## Root Cause Analysis

The issue occurs when using **self-hosted coturn** (not cloud TURN like Twilio). The connection is established via TURN relay, but media tracks aren't being properly received or displayed.

### Possible Causes:

1. **Tracks not in SDP**: Media tracks might not be included in the SDP offer/answer
2. **Tracks not received**: Remote tracks might not be triggering `onTrack` events
3. **Stream not created**: Remote stream might not be created from received tracks
4. **UI not updating**: Stream might be received but UI not updating

## Diagnostic Steps

### Step 1: Check Device Logs

Look for these log messages during a cross-network call:

**On Caller Side:**
```
🔵 [CALLER] SDP verification - Audio: true, Video: true
✅ [CALLER] SDP contains media tracks - media should work
```

**On Recipient Side:**
```
🔵 [OFFER] Answer SDP contains - Audio: true, Video: true
🔵 [ON_TRACK] ========== REMOTE TRACK RECEIVED ==========
🔵 [CALL_SCREEN] onRemoteStream callback triggered
```

**If you see:**
- `❌ [CALLER] CRITICAL: SDP does not contain media tracks!` → Tracks not added to peer connection
- `⚠️ [ON_TRACK] WARNING: onRemoteStream callback is null!` → Callback not set
- No `[ON_TRACK]` messages → Tracks not being received

### Step 2: Check ICE Connection State

Look for:
```
🔵 [ICE_CONNECTION] ✅✅✅ Connection established with [userId] - media should flow now!
```

If this appears but no media, the connection is working but tracks aren't flowing.

### Step 3: Verify TURN Server Usage

Check if RELAY candidates are being used:
```
🔵 [ICE_CANDIDATE] RELAY candidate generated
```

## Fixes

### Fix 1: Ensure Tracks Are Added Before Creating Offer/Answer

**Status**: ✅ Already implemented in code

The code already adds tracks before creating offers/answers. Verify this is working by checking logs.

### Fix 2: Force Track Re-negotiation After ICE Connection

Sometimes tracks need to be re-negotiated after ICE connection is established. Add this fix:

**File**: `lib/services/webrtc_call_service.dart`

**Location**: In `onIceConnectionState` handler, after connection is established

```dart
// After ICE connection is established, verify tracks are still active
if (state == RTCIceConnectionState.RTCIceConnectionStateConnected || 
    state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
  
  // Verify senders have tracks
  final senders = await peerConnection.getSenders();
  print('🔵 [ICE_CONNECTION] Verifying senders after connection...');
  for (final sender in senders) {
    if (sender.track == null) {
      print('⚠️ [ICE_CONNECTION] WARNING: Sender has no track!');
      // Re-add local stream tracks if missing
      if (_localStream != null) {
        print('🔵 [ICE_CONNECTION] Re-adding local stream tracks...');
        _localStream!.getTracks().forEach((track) {
          if (!senders.any((s) => s.track?.id == track.id)) {
            peerConnection.addTrack(track, _localStream!);
          }
        });
      }
    }
  }
  
  // Verify receivers have tracks
  final receivers = await peerConnection.getReceivers();
  print('🔵 [ICE_CONNECTION] Found ${receivers.length} receivers');
  for (final receiver in receivers) {
    if (receiver.track != null) {
      print('🔵 [ICE_CONNECTION] Receiver track: ${receiver.track!.kind}, enabled: ${receiver.track!.enabled}');
      if (!receiver.track!.enabled) {
        print('🔵 [ICE_CONNECTION] Enabling receiver track...');
        receiver.track!.enabled = true;
      }
    }
  }
}
```

### Fix 3: Ensure Remote Tracks Are Enabled Immediately

**Status**: ✅ Already implemented

The code already enables tracks when received. This should be working.

### Fix 4: Add Fallback Stream Creation

If `onTrack` doesn't provide streams, create stream from receivers:

**Status**: ✅ Already implemented

The code already has fallback logic to create streams from receivers.

### Fix 5: Verify TURN Server Configuration

Ensure the TURN server is properly configured and accessible:

1. **Check coturn logs:**
   ```powershell
   docker logs soc-chat-coturn | Select-String "session\|relay"
   ```

2. **Verify TURN server in client:**
   - Check device logs for TURN server URLs
   - Should see: `turn:41.33.106.54:3478` (your public IP)

3. **Test TURN server connectivity:**
   - Use online TURN server test tools
   - Verify UDP port 3478 is accessible from external networks

### Fix 6: Use Cloud TURN Instead (Recommended)

If self-hosted coturn continues to have issues, use **Twilio Cloud TURN**:

1. **Get Twilio credentials:**
   - Sign up at https://www.twilio.com/
   - Get Account SID and Auth Token

2. **Configure environment variables:**
   ```env
   # servers/local_api_server/.env
   CLOUD_TURN_ENABLED=true
   TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   TWILIO_AUTH_TOKEN=your_auth_token_here
   ```

3. **Restart API server:**
   - The server will automatically use Twilio TURN
   - No router port forwarding needed
   - More reliable for cross-network calls

## Testing

After applying fixes:

1. **Test same-network call** (baseline):
   - Both devices on same WiFi
   - Should see/hear each other ✅

2. **Test cross-network call**:
   - Device 1 on WiFi
   - Device 2 on mobile data
   - Should see/hear each other ✅

3. **Check logs for:**
   - `[ON_TRACK]` events
   - `[CALL_SCREEN] onRemoteStream callback triggered`
   - `[ICE_CONNECTION] Connection established`

## Common Issues

### Issue: SDP doesn't contain media tracks

**Solution**: Verify tracks are added BEFORE creating offer/answer:
```dart
// Tracks must be added before createOffer/createAnswer
localStream.getTracks().forEach((track) {
  peerConnection.addTrack(track, localStream);
});
await peerConnection.createOffer(); // Now SDP will include tracks
```

### Issue: Tracks received but not displayed

**Solution**: Check if `onRemoteStream` callback is set:
```dart
_callService.onRemoteStream = (userId, stream) async {
  // This should be called when remote stream is received
  _remoteRenderers[userId]!.srcObject = stream;
  setState(() {});
};
```

### Issue: ICE connection established but no tracks

**Solution**: This might be a TURN server issue:
- Verify TURN server is accessible
- Check if UDP ports are forwarded correctly
- Consider using cloud TURN (Twilio)

## Next Steps

1. **Check device logs** during a cross-network call
2. **Identify which step is failing**:
   - Tracks not in SDP?
   - Tracks not received?
   - Stream not created?
   - UI not updating?
3. **Apply appropriate fix** based on the failure point
4. **Test again** and verify media streams work

## Summary

The most likely causes are:
1. **Tracks not properly negotiated** in SDP (check logs)
2. **TURN server not relaying media** properly (verify TURN config)
3. **Remote tracks not triggering callbacks** (check onTrack/onAddStream)

**Recommended**: Use cloud TURN (Twilio) for more reliable cross-network calls.

