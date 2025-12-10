# Media Stream Flow Report
## Comprehensive Analysis of Audio/Video Stream Movement in Calling System

**Date:** Generated on request  
**Scope:** Client-side (UI) and Server-side media stream flow  
**Architecture:** WebRTC peer-to-peer with signaling server

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Client-Side (UI) Media Stream Flow](#client-side-ui-media-stream-flow)
4. [Server-Side Signaling Flow](#server-side-signaling-flow)
5. [WebRTC Peer-to-Peer Media Transmission](#webrtc-peer-to-peer-media-transmission)
6. [Stream Display in UI](#stream-display-in-ui)
7. [Individual vs Group Call Stream Flow](#individual-vs-group-call-stream-flow)
8. [Key Components and Methods](#key-components-and-methods)
9. [Flow Diagrams](#flow-diagrams)

---

## Executive Summary

The calling system uses **WebRTC (Web Real-Time Communication)** for peer-to-peer audio/video transmission. The server acts **only as a signaling intermediary** - it routes WebRTC signaling messages (offers, answers, ICE candidates) but **does NOT handle actual media streams**. Media streams flow directly between clients using peer-to-peer connections.

### Key Points:
- **Media streams are NOT sent through the server** - they use direct peer-to-peer connections
- **Server only handles signaling** - SDP offers/answers and ICE candidates
- **UI displays streams** via `RTCVideoRenderer` and `RTCVideoView` widgets
- **Streams are managed** in `WebRTCCallService` and displayed in `CallScreen`

---

## Architecture Overview

```
┌─────────────────┐         ┌─────────────────┐
│   Client A      │         │   Client B      │
│  (Caller)       │         │  (Recipient)    │
│                 │         │                 │
│  ┌───────────┐ │         │  ┌───────────┐  │
│  │ Local     │ │         │  │ Local     │  │
│  │ Stream    │ │         │  │ Stream    │  │
│  └─────┬─────┘ │         │  └─────┬─────┘  │
│        │       │         │        │        │
│  ┌─────▼─────┐ │         │  ┌─────▼─────┐  │
│  │ Peer      │ │◄───────►│  │ Peer      │  │
│  │Connection │ │  P2P    │  │Connection │  │
│  │           │ │  Media  │  │           │  │
│  └─────┬─────┘ │         │  └─────┬─────┘  │
│        │       │         │        │        │
│  ┌─────▼─────┐ │         │  ┌─────▼─────┐  │
│  │ Remote    │ │         │  │ Remote    │  │
│  │ Stream    │ │         │  │ Stream    │  │
│  └───────────┘ │         │  └───────────┘  │
└────────┬───────┘         └────────┬───────┘
         │                          │
         │  Signaling (SDP/ICE)    │
         │  (via Socket.IO)        │
         └──────────┬───────────────┘
                    │
         ┌──────────▼──────────┐
         │   Signaling Server  │
         │  (Socket.IO Server) │
         │                     │
         │  - Routes offers    │
         │  - Routes answers   │
         │  - Routes ICE       │
         │  - NO media streams │
         └─────────────────────┘
```

---

## Client-Side (UI) Media Stream Flow

### 1. Local Stream Creation

**Location:** `lib/services/webrtc_call_service.dart` → `_getLocalStream()`

**Flow:**
1. **Permission Request** (via `CallPermissionService`)
   - Requests microphone permission (always)
   - Requests camera permission (for video calls)
   - Handles Android 13+ granular permissions

2. **Media Stream Acquisition**
   ```dart
   _localStream = await navigator.getUserMedia(constraints);
   ```
   - Constraints include:
     - `audio: true` (always)
     - `video: {...}` (for video calls with facingMode, width, height)

3. **Stream Storage**
   - Stored in `_localStream` (MediaStream)
   - Triggered callback: `onLocalStream?.call(_localStream!)`

4. **UI Update**
   - `CallScreen` receives stream via `onLocalStream` callback
   - Sets `_localRenderer.srcObject = stream`
   - UI updates via `setState()`

**Key Methods:**
- `_getLocalStream()` - Creates local media stream
- `CallPermissionService.requestCallPermissions()` - Handles permissions
- `navigator.getUserMedia()` - Browser/device media access

### 2. Remote Stream Reception

**Location:** `lib/services/webrtc_call_service.dart` → `_createPeerConnection()`

**Flow:**
1. **Peer Connection Setup**
   - Created per participant in `startCall()` or `acceptCall()`
   - Configured with ICE servers (STUN/TURN)

2. **Track Reception** (via `onTrack` event)
   ```dart
   peerConnection.onTrack = (RTCTrackEvent event) {
     // Extract stream from event
     final stream = event.streams![0];
     _remoteStreams[userId] = stream;
     onRemoteStream?.call(userId, stream);
   }
   ```

3. **Stream Storage**
   - Stored in `_remoteStreams[userId]` Map
   - Each participant has their own stream entry

4. **UI Update**
   - `CallScreen` receives stream via `onRemoteStream` callback
   - Creates/updates `RTCVideoRenderer` for the user
   - Sets `renderer.srcObject = stream`
   - UI updates via `setState()`

**Key Methods:**
- `_createPeerConnection()` - Creates peer connection with event handlers
- `onTrack` event handler - Receives remote tracks
- `onAddStream` event handler - Legacy API support

### 3. Stream Display in UI

**Location:** `lib/screens/call_screen.dart`

**Components:**
- `_localRenderer: RTCVideoRenderer` - Local video renderer
- `_remoteRenderers: Map<String, RTCVideoRenderer>` - Remote video renderers

**Display Flow:**
1. **Local Stream Display**
   ```dart
   RTCVideoView(_localRenderer, mirror: _isFrontCamera)
   ```
   - Shown in small overlay (top-right for individual, grid for group)
   - Mirrored if front camera

2. **Remote Stream Display**
   ```dart
   RTCVideoView(renderer) // For individual calls (full screen)
   // OR
   GridView.builder(...) // For group calls (grid layout)
   ```
   - Individual calls: Full screen with local overlay
   - Group calls: Grid layout (2x2 or 3x3 depending on device)

**Key Widgets:**
- `RTCVideoView` - Flutter WebRTC video widget
- `RTCVideoRenderer` - Video renderer that holds the stream
- `FittedBox` - Ensures proper aspect ratio

---

## Server-Side Signaling Flow

### Important: Server Does NOT Handle Media Streams

The server **only routes signaling messages**. Actual media streams flow directly between clients via peer-to-peer connections.

### 1. WebRTC Offer Signaling

**Location:** `servers/local_api_server/server.js` → `webrtc_offer` handler

**Flow:**
1. **Client Sends Offer**
   - Client creates SDP offer via `peerConnection.createOffer()`
   - Sends via Socket.IO: `emit('webrtc_offer', {callId, offer, targetUserId})`

2. **Server Validation**
   ```javascript
   // Validate call exists
   if (!activeCalls.has(callId)) {
     // Reject offer
   }
   
   // Validate participant
   if (!call.participants.includes(socket.userId)) {
     // Reject offer
   }
   ```

3. **Server Routing**
   ```javascript
   io.to(targetRoom).emit('webrtc_offer', {
     callId,
     offer,
     userId: socket.userId
   });
   ```
   - Routes to target user's room: `user:${targetUserId}`
   - Or broadcasts to call room: `call:${callId}`

4. **Client Receives Offer**
   - Target client receives offer via Socket.IO
   - Processes in `_handleWebRTCSignal()` → `webrtc_offer` handler
   - Sets remote description: `peerConnection.setRemoteDescription(offer)`

**Key Server Methods:**
- `socket.on('webrtc_offer')` - Receives and routes offers
- `io.to(room).emit()` - Routes to specific room

### 2. WebRTC Answer Signaling

**Location:** `servers/local_api_server/server.js` → `webrtc_answer` handler

**Flow:**
1. **Client Creates Answer**
   - After setting remote description
   - Creates answer: `peerConnection.createAnswer()`
   - Sends via Socket.IO: `emit('webrtc_answer', {callId, answer, targetUserId})`

2. **Server Routing**
   ```javascript
   io.to(targetRoom).emit('webrtc_answer', {
     callId,
     answer,
     userId: socket.userId
   });
   ```

3. **Client Receives Answer**
   - Caller receives answer
   - Sets remote description: `peerConnection.setRemoteDescription(answer)`

### 3. ICE Candidate Signaling

**Location:** `servers/local_api_server/server.js` → `webrtc_ice_candidate` handler

**Flow:**
1. **ICE Candidate Generation**
   - Generated automatically by WebRTC
   - Includes connection information (IP, port, type: host/srflx/relay)

2. **Client Sends Candidate**
   ```dart
   peerConnection.onIceCandidate = (candidate) {
     sendWebRTCSignal('ice_candidate', {
       'candidate': candidate.candidate,
       'sdpMLineIndex': candidate.sdpMLineIndex,
     });
   }
   ```

3. **Server Routing**
   ```javascript
   io.to(targetRoom).emit('webrtc_ice_candidate', {
     callId,
     candidate,
     userId: socket.userId
   });
   ```

4. **Client Receives Candidate**
   - Adds to peer connection: `peerConnection.addCandidate(candidate)`
   - Used for NAT traversal and connection establishment

**ICE Candidate Types:**
- **host** - Direct local connection
- **srflx** - Server reflexive (via STUN)
- **relay** - Relayed (via TURN) - **Required for cross-network calls**

---

## WebRTC Peer-to-Peer Media Transmission

### Connection Establishment Flow

1. **Offer/Answer Exchange** (via server signaling)
   - Caller creates offer → Server routes → Recipient receives
   - Recipient creates answer → Server routes → Caller receives

2. **ICE Candidate Exchange** (via server signaling)
   - Both clients exchange ICE candidates
   - WebRTC selects best connection path

3. **Direct P2P Connection Established**
   - Once ICE completes, direct connection is established
   - **Media streams flow directly between clients**
   - **Server is no longer involved in media transmission**

### Media Stream Transmission

**Audio Stream:**
- Encoded using Opus codec (default)
- Transmitted via RTP (Real-Time Transport Protocol)
- UDP-based for low latency

**Video Stream:**
- Encoded using VP8/VP9/H.264 (negotiated)
- Transmitted via RTP
- UDP-based for low latency

**Stream Path:**
```
Client A (Microphone/Camera)
    ↓
Local MediaStream
    ↓
PeerConnection.addTrack()
    ↓
WebRTC Encoding (Opus/VP8/H.264)
    ↓
RTP Packets (UDP)
    ↓
Direct P2P Connection (via ICE)
    ↓
RTP Packets (UDP)
    ↓
WebRTC Decoding
    ↓
Remote MediaStream
    ↓
PeerConnection.onTrack()
    ↓
Client B (Speaker/Display)
```

---

## Stream Display in UI

### CallScreen Widget Structure

**State Variables:**
```dart
final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
final Map<String, RTCVideoRenderer> _remoteRenderers = {};
```

**Initialization:**
```dart
await _localRenderer.initialize();
// Remote renderers initialized on-demand when streams arrive
```

**Stream Callbacks:**
```dart
_callService.onLocalStream = (stream) {
  _localRenderer.srcObject = stream;
  setState(() {});
};

_callService.onRemoteStream = (userId, stream) async {
  if (!_remoteRenderers.containsKey(userId)) {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _remoteRenderers[userId] = renderer;
  }
  _remoteRenderers[userId]!.srcObject = stream;
  setState(() {});
};
```

### Individual Call Display

**Layout:**
- **Full Screen:** Remote video (main display)
- **Overlay:** Local video (small, top-right corner)
- **Controls:** Bottom overlay (mute, video toggle, end call)

**Code:**
```dart
Stack(
  children: [
    // Remote video (full screen)
    RTCVideoView(remoteRenderer),
    
    // Local video (overlay)
    Positioned(
      top: 20,
      right: 20,
      child: RTCVideoView(_localRenderer, mirror: true),
    ),
    
    // Controls
    Positioned(
      bottom: 0,
      child: _buildCallControls(),
    ),
  ],
)
```

### Group Call Display

**Layout:**
- **Grid View:** All participants in grid (2x2 or 3x3)
- **Local Video:** Included in grid
- **Controls:** Bottom overlay

**Code:**
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: isMobile ? 2 : 3,
  ),
  itemBuilder: (context, index) {
    final userId = remoteStreams.keys.elementAt(index);
    final renderer = _remoteRenderers[userId];
    return RTCVideoView(renderer);
  },
)
```

---

## Individual vs Group Call Stream Flow

### Individual Call (2 Participants)

**Stream Flow:**
```
Caller (A)                    Recipient (B)
    │                              │
    ├─ Local Stream ───────────────┤
    │                              │
    ├─ Peer Connection ────────────┤
    │                              │
    ├─ Remote Stream ──────────────┤
    │                              │
    └─ Display in UI ──────────────┘
```

**Peer Connections:**
- 1 peer connection per participant
- Each participant has 1 remote stream

### Group Call (3+ Participants)

**Stream Flow (Mesh Topology):**
```
Participant A
    ├─ Peer Connection → B
    ├─ Peer Connection → C
    └─ Peer Connection → D

Participant B
    ├─ Peer Connection → A
    ├─ Peer Connection → C
    └─ Peer Connection → D

... (each participant connects to all others)
```

**Peer Connections:**
- N-1 peer connections per participant (where N = total participants)
- Each participant has N-1 remote streams
- Example: 4 participants = 3 peer connections each = 12 total connections

**UI Display:**
- Grid layout showing all participants
- Each participant's stream displayed in grid cell

---

## Key Components and Methods

### Client-Side (Flutter/Dart)

#### WebRTCCallService (`lib/services/webrtc_call_service.dart`)

**Stream Management:**
- `_localStream: MediaStream?` - Local media stream
- `_remoteStreams: Map<String, MediaStream>` - Remote streams by user ID
- `onLocalStream: Function(MediaStream)?` - Callback for local stream
- `onRemoteStream: Function(String userId, MediaStream stream)?` - Callback for remote streams

**Key Methods:**
- `_getLocalStream()` - Creates local media stream from device
- `_createPeerConnection()` - Creates peer connection with event handlers
- `startCall()` - Initiates call and creates peer connections
- `acceptCall()` - Accepts incoming call and creates peer connections
- `sendWebRTCSignal()` - Sends signaling messages via Socket.IO

**Event Handlers:**
- `peerConnection.onTrack` - Receives remote tracks (modern API)
- `peerConnection.onAddStream` - Receives remote streams (legacy API)
- `peerConnection.onIceCandidate` - Handles ICE candidates
- `peerConnection.onIceConnectionState` - Monitors connection state

#### CallScreen (`lib/screens/call_screen.dart`)

**Renderers:**
- `_localRenderer: RTCVideoRenderer` - Local video renderer
- `_remoteRenderers: Map<String, RTCVideoRenderer>` - Remote video renderers

**Key Methods:**
- `initState()` - Initializes renderers and sets up callbacks
- `_buildVideoStreams()` - Builds UI for video display
- `_buildParticipantList()` - Builds participant list for group calls
- `dispose()` - Cleans up renderers and streams

### Server-Side (Node.js)

#### Socket.IO Handlers (`servers/local_api_server/server.js`)

**Signaling Handlers:**
- `socket.on('webrtc_offer')` - Routes SDP offers
- `socket.on('webrtc_answer')` - Routes SDP answers
- `socket.on('webrtc_ice_candidate')` - Routes ICE candidates

**Key Functions:**
- Validates call exists in `activeCalls`
- Validates user is participant
- Routes messages to target rooms (`user:${userId}` or `call:${callId}`)

**Important:** Server does NOT:
- Store media streams
- Process media streams
- Relay media streams
- Only routes signaling messages

---

## Flow Diagrams

### Complete Call Flow (Outgoing Call)

```
┌─────────────┐
│  Caller UI  │
└──────┬──────┘
       │
       ├─ 1. User initiates call
       │
       ▼
┌─────────────────────┐
│  CallScreen Widget   │
│  - Sets up renderers │
│  - Registers callbacks│
└──────┬──────────────┘
       │
       ├─ 2. Calls startCall()
       │
       ▼
┌──────────────────────┐
│ WebRTCCallService    │
│                      │
│  3. Request permissions│
│  4. Get local stream │
│  5. Create call (API)│
│  6. Create peer conn │
│  7. Add local tracks │
│  8. Create offer     │
└──────┬───────────────┘
       │
       ├─ 9. Send offer via Socket.IO
       │
       ▼
┌──────────────────────┐
│  Signaling Server    │
│  - Validates call     │
│  - Routes to target   │
└──────┬───────────────┘
       │
       ├─ 10. Routes offer to recipient
       │
       ▼
┌──────────────────────┐
│  Recipient Service    │
│  - Receives offer     │
│  - Creates peer conn  │
│  - Sets remote desc   │
│  - Creates answer     │
└──────┬───────────────┘
       │
       ├─ 11. Send answer via Socket.IO
       │
       ▼
┌──────────────────────┐
│  Signaling Server    │
│  - Routes answer      │
└──────┬───────────────┘
       │
       ├─ 12. Routes answer to caller
       │
       ▼
┌──────────────────────┐
│  Caller Service      │
│  - Sets remote desc   │
│  - ICE negotiation    │
└──────┬───────────────┘
       │
       ├─ 13. Direct P2P connection established
       │
       ▼
┌──────────────────────┐
│  Media Streams Flow   │
│  - Audio: P2P        │
│  - Video: P2P        │
│  - NO server involved│
└──────┬───────────────┘
       │
       ├─ 14. onTrack events fire
       │
       ▼
┌──────────────────────┐
│  UI Updates           │
│  - Remote streams     │
│  - Video renderers    │
│  - Display updates    │
└──────────────────────┘
```

### Media Stream Path (Detailed)

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT A (Caller)                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Device Hardware                                       │
│    ├─ Microphone ──────────────┐                       │
│    └─ Camera ──────────────────┤                       │
│                                 │                       │
│  Media Capture                  │                       │
│    └─ getUserMedia() ──────────┘                       │
│                                                         │
│  Local MediaStream              │                       │
│    ├─ Audio Track ─────────────┤                       │
│    └─ Video Track ─────────────┤                       │
│                                 │                       │
│  PeerConnection                 │                       │
│    └─ addTrack() ───────────────┘                       │
│                                                         │
│  WebRTC Encoding                │                       │
│    ├─ Opus (Audio) ─────────────┤                       │
│    └─ VP8/H.264 (Video) ────────┤                       │
│                                 │                       │
│  RTP Packets (UDP)               │                       │
│    └─ Direct P2P ───────────────┼──────────────────────┼─┐
└─────────────────────────────────┼──────────────────────┼─┤
                                   │                      │ │
                                   │  ICE Connection      │ │
                                   │  (via STUN/TURN)     │ │
                                   │                      │ │
┌─────────────────────────────────┼──────────────────────┼─┤
│                    CLIENT B (Recipient)                 │ │
├─────────────────────────────────┼──────────────────────┼─┤
│                                 │                      │ │
│  RTP Packets (UDP)               │                      │ │
│    └─ Direct P2P ───────────────┼──────────────────────┼─┘
│                                 │                      │
│  WebRTC Decoding                │                      │
│    ├─ Opus (Audio) ─────────────┤                      │
│    └─ VP8/H.264 (Video) ────────┤                      │
│                                 │                      │
│  PeerConnection                 │                      │
│    └─ onTrack() ────────────────┘                      │
│                                                         │
│  Remote MediaStream              │                      │
│    ├─ Audio Track ──────────────┤                      │
│    └─ Video Track ──────────────┤                      │
│                                 │                      │
│  UI Display                      │                      │
│    ├─ RTCVideoRenderer ─────────┤                      │
│    └─ RTCVideoView ─────────────┘                      │
│                                                         │
│  Device Output                   │                      │
│    ├─ Speaker ──────────────────┘                      │
│    └─ Display ──────────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

---

## Summary

### Key Takeaways

1. **Media streams are peer-to-peer** - They flow directly between clients, NOT through the server
2. **Server only handles signaling** - Routes SDP offers/answers and ICE candidates
3. **UI displays streams** via `RTCVideoRenderer` and `RTCVideoView` widgets
4. **Streams are managed** in `WebRTCCallService` and displayed in `CallScreen`
5. **Group calls use mesh topology** - Each participant connects to all others
6. **TURN servers required** for cross-network calls (relay candidates)

### Stream Lifecycle

1. **Creation:** `getUserMedia()` → Local MediaStream
2. **Transmission Setup:** PeerConnection → addTrack() → createOffer()
3. **Signaling:** Server routes SDP offers/answers
4. **Connection:** ICE negotiation → Direct P2P connection
5. **Reception:** onTrack() → Remote MediaStream
6. **Display:** RTCVideoRenderer → RTCVideoView → UI

### Important Notes

- **No media passes through server** - All audio/video is peer-to-peer
- **Server is signaling-only** - Routes WebRTC signaling messages
- **TURN servers required** for cross-network calls (when direct P2P fails)
- **Mesh topology** for group calls (each participant connects to all others)
- **Streams are real-time** - Low latency via UDP/RTP

---

**End of Report**

