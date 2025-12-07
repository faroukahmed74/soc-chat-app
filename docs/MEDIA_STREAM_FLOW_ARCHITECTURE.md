# 📡 Media Stream Flow Architecture

## Complete Guide: How Media Streams Move Between Devices

This document explains how audio/video media streams flow between different platform combinations in the SOC Chat App.

---

## 🌐 Platform Combinations Supported

| From → To | Android | iOS | Web |
|-----------|---------|-----|-----|
| **Android** | ✅ | ✅ | ✅ |
| **iOS** | ✅ | ✅ | ✅ |
| **Web** | ✅ | ✅ | ✅ |

**All combinations are fully supported!**

---

## 🏗️ Architecture Overview

The calling system uses a **hybrid architecture**:

1. **Signaling (Server-Side)**: Uses Socket.IO for call setup and WebRTC signaling
2. **Media (Peer-to-Peer)**: Uses WebRTC for direct media streaming (no server relay)

```
┌─────────────────────────────────────────────────────────────┐
│                    SIGNALING LAYER                           │
│  (Socket.IO - Server acts as message broker)                 │
│  - Call invitations                                          │
│  - WebRTC offers/answers                                    │
│  - ICE candidates                                            │
│  - Call control (accept/reject/end)                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    MEDIA LAYER                               │
│  (WebRTC - Direct P2P connection)                           │
│  - Audio streams                                             │
│  - Video streams                                             │
│  - Screen sharing                                            │
│  - No server relay (direct device-to-device)                │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Complete Call Flow

### Phase 1: Call Initiation (Signaling)

```
┌─────────────┐                    ┌──────────────┐                    ┌─────────────┐
│   Caller    │                    │   Server    │                    │  Recipient  │
│  (Device A) │                    │  (Socket.IO)│                    │  (Device B) │
└──────┬──────┘                    └──────┬──────┘                    └──────┬──────┘
       │                                   │                                   │
       │ 1. startCall()                    │                                   │
       │    - Get local media stream       │                                   │
       │    - Create peer connection        │                                   │
       │    - Add local tracks             │                                   │
       │    - Create offer                 │                                   │
       ├──────────────────────────────────►│                                   │
       │                                    │                                   │
       │ 2. POST /api/calls/start          │                                   │
       │    {callId, chatId, callType,     │                                   │
       │     participantIds}               │                                   │
       ├──────────────────────────────────►│                                   │
       │                                    │                                   │
       │                                    │ 3. Emit 'call_invitation'         │
       │                                    ├───────────────────────────────────►│
       │                                    │    {callId, chatId, callType,     │
       │                                    │     callerId, callerName}           │
       │                                    │                                   │
       │ 4. Emit 'webrtc_offer'            │                                   │
       │    {callId, offer, targetUserId}  │                                   │
       ├──────────────────────────────────►│                                   │
       │                                    │                                   │
       │                                    │ 5. Emit 'webrtc_offer'            │
       │                                    ├───────────────────────────────────►│
       │                                    │    {callId, offer, fromUserId}    │
       │                                    │                                   │
```

### Phase 2: Call Acceptance (Signaling)

```
       │                                    │                                   │
       │                                    │ 6. acceptCall()                   │
       │                                    │    - Get local media stream       │
       │                                    │    - Create peer connection       │
       │                                    │    - Add local tracks              │
       │                                    │    - Set remote description        │
       │                                    │    - Create answer                │
       │                                    │◄──────────────────────────────────┤
       │                                    │                                   │
       │                                    │ 7. Emit 'call_accept'             │
       │                                    │◄──────────────────────────────────┤
       │                                    │                                   │
       │                                    │ 8. Emit 'webrtc_answer'           │
       │                                    │◄──────────────────────────────────┤
       │                                    │    {callId, answer, fromUserId}   │
       │                                    │                                   │
       │ 9. Receive 'webrtc_answer'        │                                   │
       │◄──────────────────────────────────┤                                   │
       │    - Set remote description        │                                   │
       │                                    │                                   │
```

### Phase 3: ICE Candidate Exchange (NAT Traversal)

```
       │                                    │                                   │
       │ 10. Generate ICE candidates       │                                   │
       │     (via STUN/TURN servers)        │                                   │
       │                                    │                                   │
       │ 11. Emit 'webrtc_ice_candidate'    │                                   │
       ├──────────────────────────────────►│                                   │
       │                                    │                                   │
       │                                    │ 12. Emit 'webrtc_ice_candidate'   │
       │                                    ├───────────────────────────────────►│
       │                                    │                                   │
       │                                    │ 13. Generate ICE candidates       │
       │                                    │     (via STUN/TURN servers)        │
       │                                    │                                   │
       │                                    │ 14. Emit 'webrtc_ice_candidate'   │
       │                                    │◄──────────────────────────────────┤
       │                                    │                                   │
       │ 15. Receive ICE candidates         │                                   │
       │◄──────────────────────────────────┤                                   │
       │     - Add to peer connection      │                                   │
       │                                    │                                   │
```

### Phase 4: Media Stream Establishment (P2P)

```
       │                                    │                                   │
       │ 16. WebRTC Connection Established  │                                   │
       │     (Direct P2P connection)        │                                   │
       │                                    │                                   │
       │◄──────────────────────────────────┼──────────────────────────────────►│
       │                                    │                                   │
       │  Audio/Video Streams               │                                   │
       │  (Direct device-to-device)         │                                   │
       │                                    │                                   │
       │ 17. onTrack event fired             │                                   │
       │     - Remote stream received        │                                   │
       │     - Display in UI                 │                                   │
       │                                    │                                   │
       │                                    │ 18. onTrack event fired            │
       │                                    │     - Remote stream received       │
       │                                    │     - Display in UI                │
       │                                    │                                   │
```

---

## 📱 Platform-Specific Details

### Mobile Platforms (Android & iOS)

#### Connection Setup
```dart
// Platform Detection
if (!kIsWeb) {
  // Mobile platform
  // Server URL: https://soc-chat-app.ngrok-free.app
  // WebSocket: wss://soc-chat-app.ngrok-free.app
}
```

#### STUN/TURN Configuration
```dart
// STUN Servers (Always Available)
- stun:stun.l.google.com:19302
- stun:stun1.l.google.com:19302
- stun:stun2.l.google.com:19302
- stun:stun3.l.google.com:19302
- stun:stun4.l.google.com:19302

// TURN Server (If Configured)
// Mobile uses ngrok TCP tunnel for TURN
- turn:ngrok-hostname:3478?transport=tcp
```

#### Media Stream Capture
```dart
// Android/iOS
final constraints = {
  'audio': true,
  'video': {
    'facingMode': 'user',  // Front camera
    'width': {'min': 640, 'ideal': 1280},
    'height': {'min': 480, 'ideal': 720},
  }
};

final localStream = await navigator.getUserMedia(constraints);
```

#### UI Rendering
```dart
// Android/iOS Video Rendering
RTCVideoView(
  _localRenderer,    // Local video
  mirror: true,       // Mirror for front camera
)

RTCVideoView(
  _remoteRenderers[userId],  // Remote video
)
```

---

### Web Platform

#### Connection Setup
```dart
// Platform Detection
if (kIsWeb) {
  // Web platform
  // Server URL: http://localhost:3003 (via proxy)
  // WebSocket: ws://[local-ip]:8082 (via proxy)
}
```

#### STUN/TURN Configuration
```dart
// STUN Servers (Same as Mobile)
- stun:stun.l.google.com:19302
- stun:stun1.l.google.com:19302
// ... (same as mobile)

// TURN Server (Local Network)
- turn:10.120.4.230:3478
- turn:10.120.4.230:3478?transport=tcp
```

#### Media Stream Capture
```dart
// Web
final constraints = {
  'audio': true,
  'video': {
    'facingMode': 'user',
    'width': {'min': 640, 'ideal': 1280},
    'height': {'min': 480, 'ideal': 720},
  }
};

final localStream = await navigator.getUserMedia(constraints);
```

#### UI Rendering
```dart
// Web Video Rendering
RTCVideoView(
  _localRenderer,    // Local video
  mirror: true,
)

RTCVideoView(
  _remoteRenderers[userId],  // Remote video
)
```

---

## 🔀 Cross-Platform Scenarios

### Scenario 1: Android → Android

```
┌──────────────┐                    ┌──────────────┐                    ┌──────────────┐
│  Android A   │                    │   Server     │                    │  Android B   │
│  (Caller)    │                    │  (Socket.IO) │                    │  (Recipient) │
└──────┬───────┘                    └──────┬───────┘                    └──────┬───────┘
       │                                    │                                   │
       │ 1. Signaling (Socket.IO)           │                                   │
       │    wss://ngrok-url                 │                                   │
       ├────────────────────────────────────►│                                   │
       │                                    │                                   │
       │                                    │    wss://ngrok-url                │
       │                                    ├───────────────────────────────────►│
       │                                    │                                   │
       │ 2. Media (WebRTC P2P)              │                                   │
       │    Direct connection via STUN/TURN │                                   │
       │◄───────────────────────────────────┼───────────────────────────────────►│
       │                                    │                                   │
       │    Audio/Video Streams              │                                   │
       │    (No server involvement)          │                                   │
       │                                    │                                   │
```

**Key Points:**
- Both devices use ngrok for signaling
- Both devices use same STUN/TURN servers
- Direct P2P connection established
- Media streams flow directly between devices

---

### Scenario 2: Web → Mobile (Android/iOS)

```
┌──────────────┐                    ┌──────────────┐                    ┌──────────────┐
│   Web User   │                    │   Server     │                    │  Mobile User │
│  (Caller)    │                    │  (Socket.IO) │                    │  (Recipient) │
└──────┬───────┘                    └──────┬───────┘                    └──────┬───────┘
       │                                    │                                   │
       │ 1. Signaling (Socket.IO)           │                                   │
       │    ws://local-ip:8082 (proxy)      │                                   │
       ├────────────────────────────────────►│                                   │
       │                                    │                                   │
       │                                    │    wss://ngrok-url                │
       │                                    ├───────────────────────────────────►│
       │                                    │                                   │
       │ 2. Media (WebRTC P2P)              │                                   │
       │    Web: turn:10.120.4.230:3478    │                                   │
       │    Mobile: turn:ngrok:3478         │                                   │
       │◄───────────────────────────────────┼───────────────────────────────────►│
       │                                    │                                   │
       │    Audio/Video Streams              │                                   │
       │    (Direct P2P via TURN relay)     │                                   │
       │                                    │                                   │
```

**Key Points:**
- Web uses local proxy for signaling
- Mobile uses ngrok for signaling
- Both connect to same Socket.IO server
- Web uses local TURN server
- Mobile uses ngrok TURN tunnel
- Media streams relayed through TURN servers if direct connection fails

---

### Scenario 3: Mobile → Web

```
┌──────────────┐                    ┌──────────────┐                    ┌──────────────┐
│  Mobile User │                    │   Server     │                    │   Web User   │
│  (Caller)    │                    │  (Socket.IO) │                    │  (Recipient) │
└──────┬───────┘                    └──────┬───────┘                    └──────┬───────┘
       │                                    │                                   │
       │ 1. Signaling (Socket.IO)           │                                   │
       │    wss://ngrok-url                 │                                   │
       ├────────────────────────────────────►│                                   │
       │                                    │                                   │
       │                                    │    ws://local-ip:8082 (proxy)     │
       │                                    ├───────────────────────────────────►│
       │                                    │                                   │
       │ 2. Media (WebRTC P2P)              │                                   │
       │    Mobile: turn:ngrok:3478         │                                   │
       │    Web: turn:10.120.4.230:3478    │                                   │
       │◄───────────────────────────────────┼───────────────────────────────────►│
       │                                    │                                   │
       │    Audio/Video Streams              │                                   │
       │    (Direct P2P via TURN relay)     │                                   │
       │                                    │                                   │
```

**Key Points:**
- Same as Web → Mobile, but roles reversed
- TURN servers handle NAT traversal
- Media streams work bidirectionally

---

## 🖥️ Server-Side Flow (Socket.IO)

### Call Start Endpoint
```javascript
POST /api/calls/start
{
  callId: "call_1234567890_user1",
  chatId: "chat_abc123",
  chatName: "John Doe",
  callType: "voice" | "video",
  participantIds: ["user2", "user3"],
  isGroupChat: false
}
```

**Server Actions:**
1. Validate request
2. Store call in `activeCalls` map
3. Send `call_invitation` event to all participants via Socket.IO
4. Return success response

### Socket.IO Event Handlers

#### 1. Call Invitation
```javascript
// Server emits to recipient
io.to(`user:${participantId}`).emit('call_invitation', {
  callId,
  chatId,
  chatName,
  callType,
  callerId,
  callerName,
  participantIds,
  timestamp
});
```

#### 2. WebRTC Offer
```javascript
// Caller sends offer
socket.on('webrtc_offer', (data) => {
  const { callId, offer, targetUserId } = data;
  
  // Route to target user's room
  io.to(`user:${targetUserId}`).emit('webrtc_offer', {
    callId,
    offer,
    fromUserId: socket.userId
  });
});
```

#### 3. WebRTC Answer
```javascript
// Recipient sends answer
socket.on('webrtc_answer', (data) => {
  const { callId, answer, targetUserId } = data;
  
  // Route to caller's room
  io.to(`user:${targetUserId}`).emit('webrtc_answer', {
    callId,
    answer,
    fromUserId: socket.userId
  });
});
```

#### 4. ICE Candidates
```javascript
// Both parties exchange ICE candidates
socket.on('webrtc_ice_candidate', (data) => {
  const { callId, candidate, targetUserId } = data;
  
  // Route to target user
  io.to(`user:${targetUserId}`).emit('webrtc_ice_candidate', {
    callId,
    candidate,
    fromUserId: socket.userId
  });
});
```

---

## 📊 Media Stream Data Flow

### Local Stream Capture
```dart
// Step 1: Get user media
final localStream = await navigator.getUserMedia({
  'audio': true,
  'video': true  // For video calls
});

// Step 2: Extract tracks
final audioTrack = localStream.getAudioTracks()[0];
final videoTrack = localStream.getVideoTracks()[0];

// Step 3: Add tracks to peer connection
peerConnection.addTrack(audioTrack, localStream);
peerConnection.addTrack(videoTrack, localStream);
```

### Remote Stream Reception
```dart
// Step 1: Listen for remote tracks
peerConnection.onTrack = (RTCTrackEvent event) {
  final stream = event.streams[0];
  
  // Step 2: Store remote stream
  _remoteStreams[userId] = stream;
  
  // Step 3: Notify UI
  onRemoteStream?.call(userId, stream);
};

// Step 4: UI renders stream
_callService.onRemoteStream = (userId, stream) {
  final renderer = RTCVideoRenderer();
  await renderer.initialize();
  renderer.srcObject = stream;
  _remoteRenderers[userId] = renderer;
  setState(() {});  // Update UI
};
```

---

## 🔐 Security & Privacy

### Media Stream Encryption
- **DTLS-SRTP**: All media streams are encrypted end-to-end
- **No Server Access**: Server never sees or processes media content
- **Direct P2P**: Media flows directly between devices

### Signaling Security
- **JWT Authentication**: All Socket.IO connections require valid JWT token
- **HTTPS/WSS**: Encrypted signaling channels
- **Room-Based Routing**: Users can only receive signals for their calls

---

## 🐛 Troubleshooting

### Issue: No Media Stream Received

**Possible Causes:**
1. **ICE Connection Failed**
   - Check STUN/TURN server configuration
   - Verify firewall/NAT settings
   - Check network connectivity

2. **Tracks Not Added**
   - Verify `addTrack()` is called before `setRemoteDescription()`
   - Check that local stream has active tracks
   - Ensure peer connection is created before adding tracks

3. **Platform Mismatch**
   - Verify both platforms use compatible WebRTC implementations
   - Check STUN/TURN server accessibility from both platforms

4. **Call Room Not Joined**
   - Ensure both caller and recipient join call room: `emit('join_call', {callId})`
   - Check server logs for room join confirmations
   - Verify Socket.IO connection is active

### Issue: One-Way Audio/Video

**Possible Causes:**
1. **Tracks Not Added to Recipient**
   - Ensure recipient adds local tracks when accepting call
   - Check that offer handler adds tracks before creating answer
   - Verify `acceptCall()` adds tracks to existing peer connections

2. **Remote Description Not Set**
   - Verify `setRemoteDescription()` is called with correct SDP
   - Check that answer is received and processed
   - Ensure offer/answer exchange completes before expecting media

### Issue: Caller Not Notified When Recipient Answers

**Possible Causes:**
1. **Call Room Not Joined**
   - Caller must join call room: `emit('join_call', {callId})` when starting call
   - Recipient must join call room: `emit('join_call', {callId})` when accepting call
   - Check server logs for room join events

2. **Event Data Mismatch**
   - Server sends `acceptedBy` field, client should handle both `acceptedBy` and `userId`
   - Verify `call_accepted` event is received by checking client logs

3. **Socket.IO Connection Issues**
   - Verify both devices are connected to Socket.IO
   - Check server logs for connection status
   - Ensure authentication token is valid

### Issue: Media Stream Not Appearing After Call Acceptance

**✅ RESOLVED** - The following fixes were applied:

1. **SDP Verification Before Sending**
   - Added verification that offer/answer SDP contains media (`m=audio`, `m=video`) before sending
   - If SDP doesn't contain media, the signal is not sent (prevents invalid connections)
   - This ensures both parties have media tracks in their SDP

2. **Track Addition Verification**
   - Added verification that local tracks are added to peer connection before creating offer/answer
   - Check sender count and track details before creating SDP
   - Ensures tracks are present in the SDP when it's created

3. **Enhanced Error Handling**
   - Added try-catch blocks around critical WebRTC operations (setRemoteDescription, createAnswer, setLocalDescription)
   - Better error messages and logging to identify issues quickly
   - Prevents silent failures that could cause media streams to not work

4. **Improved Timing**
   - Increased delay after setting remote description (100ms → 200ms) to allow proper processing
   - Ensures remote description is fully processed before creating answer

**Previous Possible Causes (Now Fixed):**
1. **Peer Connection Not Created** ✅ Fixed
   - Peer connection is created when offer is received
   - Tracks are verified before creating answer

2. **Local Tracks Not Added** ✅ Fixed
   - Tracks are verified before creating offer/answer
   - SDP verification ensures tracks are included

3. **Remote Stream Not Received** ✅ Fixed
   - Enhanced error handling ensures proper stream handling
   - Better logging helps identify any remaining issues

---

## 📝 Summary

### Key Takeaways

1. **Signaling**: All platforms use Socket.IO through server (ngrok for mobile, proxy for web)
2. **Media**: All platforms use WebRTC for direct P2P media streaming
3. **STUN/TURN**: Used for NAT traversal, works across all platforms
4. **No Server Relay**: Media streams never pass through the server
5. **Platform Agnostic**: Same WebRTC implementation works on all platforms

### Flow Summary

```
Call Initiation
    ↓
Signaling (Socket.IO via Server)
    ↓
WebRTC Offer/Answer Exchange
    ↓
ICE Candidate Exchange
    ↓
P2P Connection Established
    ↓
Media Streams Flow Directly
    ↓
Audio/Video Displayed in UI
```

---

## 🔗 Related Documents

- `CROSS_PLATFORM_FEATURES_COMPATIBILITY.md` - Feature compatibility matrix
- `CALLING_SYSTEM_COMPREHENSIVE_REPORT.md` - Complete calling system documentation
- `SERVER_CALL_CONFIG_REVIEW.md` - Server-side call configuration

---

**Last Updated**: 2025-01-03
**Version**: 1.1
**Status**: ✅ Media Streaming Issue Resolved

