# 📞 Calling System - Comprehensive Detailed Report

## 📋 Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Client-Side Implementation](#client-side-implementation)
4. [Server-Side Implementation](#server-side-implementation)
5. [Call Flow - How Calls Reach Users](#call-flow)
6. [Media Stream Flow - How Streams Reach Users](#media-stream-flow)
7. [Individual vs Group Calls](#individual-vs-group-calls)
8. [Audio vs Video Calls](#audio-vs-video-calls)
9. [TURN/STUN Configuration](#turnstun-configuration)
10. [Key Methods and Functions](#key-methods-and-functions)

---

## 🎯 System Overview

The SOC Chat App implements a **WebRTC-based calling system** supporting:
- ✅ **Individual calls** (1-on-1)
- ✅ **Group calls** (multiple participants)
- ✅ **Audio calls** (voice-only)
- ✅ **Video calls** (audio + video)
- ✅ **Cross-platform** (Android, iOS, Web)
- ✅ **Cross-network** (via Twilio TURN service)

**Technology Stack:**
- **Client**: Flutter with `flutter_webrtc` package
- **Signaling**: Socket.IO (WebSocket)
- **Media**: WebRTC (peer-to-peer with TURN relay)
- **TURN Service**: Twilio Network Traversal Service
- **Backend**: Node.js/Express with Socket.IO

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT-SIDE (Flutter)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Call Screen  │  │ WebRTC       │  │ Realtime     │          │
│  │ (UI)         │→ │ Call Service │→ │ Service      │          │
│  └──────────────┘  └──────────────┘  └──────┬───────┘          │
│                                               │                  │
└───────────────────────────────────────────────┼──────────────────┘
                                                │ Socket.IO
                                                │ (Signaling)
┌───────────────────────────────────────────────┼──────────────────┐
│                    SERVER-SIDE (Node.js)      │                  │
│  ┌──────────────┐  ┌──────────────┐  ┌───────▼───────┐          │
│  │ API Server   │  │ Socket.IO    │  │ MongoDB       │          │
│  │ (Express)     │  │ Server       │  │ (Call State)  │          │
│  └──────────────┘  └──────────────┘  └───────────────┘          │
└──────────────────────────────────────────────────────────────────┘
                                                │
                                                │
┌───────────────────────────────────────────────┼──────────────────┐
│                    MEDIA LAYER (WebRTC)        │                  │
│  ┌──────────────┐                             │                  │
│  │ Device 1     │←───────────P2P──────────────→│ Device 2         │
│  │ (Caller)     │                             │ (Recipient)      │
│  └──────┬───────┘                             └──────┬───────────┘
│         │                                            │
│         └───────────TURN Server (Twilio)────────────┘
│                      (Media Relay)
└──────────────────────────────────────────────────────────────────┘
```

### Two-Layer Architecture

1. **Signaling Layer (Server-Side)**
   - Call invitations
   - WebRTC offers/answers
   - ICE candidates
   - Call control (accept/reject/end)
   - Uses Socket.IO (WebSocket over TCP)

2. **Media Layer (Peer-to-Peer)**
   - Audio/video streams
   - Direct P2P connection when possible
   - TURN relay when direct connection fails
   - Uses WebRTC (UDP for media)

---

## 📱 Client-Side Implementation

### UI Components

#### 1. Call Screen (`lib/screens/call_screen.dart`)

**Purpose**: Main UI for all call interactions

**Key Features:**
- Incoming call UI (ringing state)
- Outgoing call UI (calling state)
- Active call UI (connected state)
- Call controls (mute, video toggle, speaker, end call)
- Video renderers (local and remote)
- Call timer
- Responsive design (handles rotation)

**Key State Variables:**
```dart
CallState _callState;              // ringing, active, ended
bool _isMuted;                     // Audio mute state
bool _isVideoEnabled;               // Video on/off
bool _isFrontCamera;                // Camera facing
bool _isSpeakerOn;                  // Speaker mode
RTCVideoRenderer _localRenderer;    // Local video
Map<String, RTCVideoRenderer> _remoteRenderers; // Remote videos
```

**Key Methods:**
- `_startCall()` - Initiates outgoing call
- `_acceptCall()` - Accepts incoming call
- `_rejectCall()` - Rejects incoming call
- `_endCall()` - Ends active call
- `_toggleMute()` - Toggles audio mute
- `_toggleVideo()` - Toggles video on/off
- `_switchCamera()` - Switches front/back camera
- `_toggleSpeaker()` - Toggles speaker/earpiece

#### 2. Chat Screen (`lib/screens/chat_screen_mongodb.dart`)

**Purpose**: Entry point for starting calls

**Call Buttons:**
- Voice call button (📞) - Starts audio-only call
- Video call button (📹) - Starts video call

**Method:**
```dart
Future<void> _startCall(CallType callType) async {
  // Navigates to CallScreen with call parameters
  // CallScreen handles the actual call initiation
}
```

### Core Services

#### 1. WebRTC Call Service (`lib/services/webrtc_call_service.dart`)

**Purpose**: Core WebRTC functionality and call management

**Key Properties:**
```dart
Map<String, RTCPeerConnection> _peerConnections;  // One per participant
MediaStream? _localStream;                         // Local audio/video
Map<String, MediaStream> _remoteStreams;          // Remote streams per user
List<Map<String, dynamic>> _iceServers;           // STUN/TURN servers
String? _currentCallId;                            // Active call ID
CallType? _currentCallType;                        // audio or video
bool _isInCall;                                    // Call active flag
```

**Key Methods:**

##### Call Management
- `startCall()` - Initiates a new call
- `acceptCall()` - Accepts incoming call
- `rejectCall()` - Rejects incoming call
- `endCall()` - Ends active call

##### WebRTC Operations
- `_createPeerConnection()` - Creates WebRTC peer connection
- `_getLocalStream()` - Gets local audio/video stream
- `_handleWebRTCSignal()` - Handles offers/answers/ICE candidates
- `sendWebRTCSignal()` - Sends WebRTC signaling messages

##### Media Control
- `toggleMute()` - Mutes/unmutes audio
- `toggleVideo()` - Enables/disables video
- `switchCamera()` - Switches camera front/back
- `toggleSpeaker()` - Toggles speaker mode

**Callbacks:**
```dart
Function(MediaStream)? onLocalStream;      // Local stream available
Function(String, MediaStream)? onRemoteStream; // Remote stream available
Function(String)? onCallEnded;             // Call ended
Function(String)? onCallAccepted;         // Call accepted
```

#### 2. Realtime Service (`lib/services/realtime_service.dart`)

**Purpose**: Socket.IO communication wrapper

**Key Methods:**
- `onCallInvitation()` - Listens for call invitations
- `emit()` - Sends Socket.IO events
- `on()` - Listens for Socket.IO events

**Socket.IO Events Handled:**
- `call_invitation` - Incoming call notification
- `call_accepted` - Call accepted by recipient
- `call_rejected` - Call rejected by recipient
- `call_ended` - Call ended notification
- `join_call` - Join call room for signaling (allows room-based message routing)
- `leave_call` - Leave call room
- `webrtc_offer` - WebRTC offer (SDP)
- `webrtc_answer` - WebRTC answer (SDP)
- `webrtc_ice_candidate` - ICE candidate

#### 3. Call Permission Service (`lib/services/call_permission_service.dart`)

**Purpose**: Handles microphone and camera permissions

**Key Methods:**
- `requestCallPermissions()` - Requests mic/camera permissions
- `hasMicrophonePermission()` - Checks mic permission
- `hasCameraPermission()` - Checks camera permission

**Platform-Specific:**
- Android 13+: Granular permissions (RECORD_AUDIO, CAMERA)
- iOS: NSCameraUsageDescription, NSMicrophoneUsageDescription

#### 4. FCM Service (`lib/services/fcm_service.dart`)

**Purpose**: Handles push notifications for calls when app is in background

**Key Methods:**
- `_handleCallInvitationFromFCM()` - Processes call invitation from FCM
- Shows high-priority notification for incoming calls
- Opens call screen when notification is tapped

---

## 🖥️ Server-Side Implementation

### API Endpoints

#### 1. Start Call (`POST /api/calls/start`)

**Location**: `servers/local_api_server/server.js` (line 3269)

**Purpose**: Initiates a call and sends invitations to participants

**Request Body:**
```javascript
{
  callId: "call_1234567890_userId",  // Optional, generated if not provided
  chatId: "chat_id",
  chatName: "Chat Name",
  callType: "audio" | "video",        // Normalized from "voice" to "audio"
  participantIds: ["user1", "user2"], // Array of participant IDs
  isGroupChat: true | false
}
```

**Process:**
1. Validates request (chatId, callType, participantIds)
2. Normalizes callType ("voice" → "audio")
3. Generates callId if not provided
4. Adds caller to participants list
5. Stores call in `activeCalls` Map
6. Sends call invitation to each participant:
   - **If online**: Via Socket.IO (`call_invitation` event)
   - **If offline**: Via FCM push notification
7. Returns success response with callId

**Response:**
```javascript
{
  success: true,
  callId: "call_1234567890_userId",
  message: "Call started successfully"
}
```

#### 2. TURN Configuration (`GET /api/webrtc/turn-config`)

**Location**: `servers/local_api_server/server.js` (line 816)

**Purpose**: Returns TURN server configuration for WebRTC

**Process:**
1. Checks if cloud TURN (Twilio) is enabled
2. If enabled, returns Twilio TURN servers
3. If not enabled, checks for ngrok TCP tunnel
4. Returns TURN servers in priority order:
   - Cloud TURN (Twilio) - First priority
   - ngrok TURN - Second priority
   - Public IP TURN - Third priority
   - Local IP TURN - Fallback

**Response:**
```javascript
{
  success: true,
  turnServers: [
    {
      urls: "turn:global.turn.twilio.com:3478?transport=udp",
      username: "account-sid:auth-token",
      credential: "auth-token"
    },
    // ... more servers
  ]
}
```

### Socket.IO Event Handlers

#### 1. Call Invitation (`call_invitation`)

**Location**: Server automatically sends when call is started

**Data:**
```javascript
{
  callId: "call_1234567890_userId",
  chatId: "chat_id",
  chatName: "Chat Name",
  callType: "audio" | "video",
  callerId: "caller_user_id",
  callerName: "Caller Name",
  isGroupChat: true | false
}
```

**Routing:**
- Emitted to user's personal room: `userId`
- Also emitted to: `user:userId`
- Direct socket emission as backup

#### 2. Call Accept (`call_accept`)

**Location**: `servers/local_api_server/server.js` (line 4181)

**Purpose**: Handles call acceptance

**Process:**
1. Validates callId exists in activeCalls
2. Emits `call_accepted` event to:
   - Call room: `call:${callId}`
   - Target user room: `user:${targetUserId}`
   - All participant rooms
3. Logs acceptance

**Data Emitted:**
```javascript
{
  callId: "call_1234567890_userId",
  acceptedBy: "user_id",
  acceptedAt: "2024-01-01T00:00:00Z"
}
```

#### 3. Call Reject (`call_reject`)

**Location**: `servers/local_api_server/server.js` (line 4243)

**Purpose**: Handles call rejection

**Process:**
1. Validates callId exists
2. Emits `call_rejected` event to call room and participants
3. Optionally cleans up call state

#### 4. Call End (`call_end`)

**Location**: `servers/local_api_server/server.js` (line 4301)

**Purpose**: Handles call termination

**Process:**
1. Validates callId
2. Emits `call_ended` event to all participants
3. Cleans up call state from `activeCalls` Map
4. Updates user records in MongoDB

#### 5. WebRTC Offer (`webrtc_offer`)

**Location**: `servers/local_api_server/server.js` (line 4365)

**Purpose**: Routes WebRTC offer (SDP) to target user

**Data:**
```javascript
{
  callId: "call_1234567890_userId",
  offer: {
    sdp: "v=0\r\no=- 1234567890...",
    type: "offer"
  },
  targetUserId: "target_user_id"  // Optional, for direct routing
}
```

**Process:**
1. Validates callId and offer
2. Checks if offer SDP contains audio/video
3. Routes to target user room: `user:${targetUserId}`
4. Falls back to call room: `call:${callId}` if no targetUserId

#### 6. WebRTC Answer (`webrtc_answer`)

**Location**: `servers/local_api_server/server.js` (line 4438)

**Purpose**: Routes WebRTC answer (SDP) to caller

**Data:**
```javascript
{
  callId: "call_1234567890_userId",
  answer: {
    sdp: "v=0\r\no=- 9876543210...",
    type: "answer"
  },
  targetUserId: "caller_user_id"
}
```

**Process:**
1. Validates callId and answer
2. Routes to target user (caller)
3. Verifies answer SDP contains media

#### 7. ICE Candidate (`webrtc_ice_candidate`)

**Location**: `servers/local_api_server/server.js` (line 4511)

**Purpose**: Routes ICE candidates for NAT traversal

**Data:**
```javascript
{
  callId: "call_1234567890_userId",
  candidate: {
    candidate: "candidate:1 1 UDP 2130706431 192.168.1.1 54321 typ host",
    sdpMid: "0",
    sdpMLineIndex: 0
  },
  targetUserId: "target_user_id"
}
```

**Process:**
1. Validates callId and candidate
2. Routes to target user
3. Enables NAT traversal and connection establishment

### Call State Management

**Active Calls Map:**
```javascript
const activeCalls = new Map(); // In-memory storage

// Structure:
{
  callId: "call_1234567890_userId",
  type: "audio" | "video",
  participants: ["user1", "user2"],
  startedAt: Date,
  callerId: "user1",
  chatId: "chat_id",
  chatName: "Chat Name",
  isGroupChat: true | false
}
```

**User Socket Tracking:**
```javascript
const userSockets = new Map(); // userId → Set<socketId>
const activeConnections = new Map(); // socketId → {userId, socket}
```

---

## 📞 Call Flow - How Calls Reach Users

### Outgoing Call Flow

```
1. User taps call button (voice/video)
   ↓
2. Chat Screen → _startCall(CallType)
   ↓
3. Navigate to CallScreen (direction: outgoing)
   ↓
4. CallScreen.initState() → _startCall()
   ↓
5. WebRTCCallService.startCall()
   ├─ Generate callId: "call_${timestamp}_${userId}"
   ├─ Get local media stream (audio/video)
   ├─ Join call room: emit('join_call', {callId}) for signaling
   ├─ Create peer connections for each participant
   ├─ Add local tracks to peer connections
   ├─ Create WebRTC offers
   ├─ Send offers via Socket.IO (webrtc_offer)
   └─ POST /api/calls/start
       ↓
6. Server processes /api/calls/start
   ├─ Store call in activeCalls Map
   ├─ For each participant:
   │   ├─ If online: Emit call_invitation via Socket.IO
   │   └─ If offline: Send FCM push notification
   └─ Return success
   ↓
7. Recipient receives call_invitation
   ├─ If app is open: Global listener in main.dart
   │   └─ Navigate to CallScreen (direction: incoming)
   └─ If app is closed: FCM notification
       └─ Tap notification → Open CallScreen
```

### Incoming Call Flow

```
1. Recipient receives call_invitation (Socket.IO or FCM)
   ↓
2. Global listener in main.dart
   ├─ Check ActiveCallTracker (prevent duplicates)
   ├─ Check if already on call screen
   └─ Navigate to CallScreen (direction: incoming)
   ↓
3. CallScreen.initState()
   ├─ Set state to CallState.ringing
   ├─ Start ringtone and vibration
   └─ Display incoming call UI
   ↓
4. User taps "Answer"
   ↓
5. CallScreen._acceptCall()
   ├─ Stop ringtone/vibration
   ├─ Set state to CallState.active
   └─ WebRTCCallService.acceptCall(callId)
       ├─ Join call room: emit('join_call', {callId}) for signaling
       ├─ Get local media stream
       ├─ Process pending offers (if any) - offers that arrived before acceptance
       │   └─ Store in _pendingOffers Map, process when acceptCall() is called
       ├─ Create peer connections
       ├─ Add local tracks
       ├─ Set remote description (from offer)
       ├─ Create answer
       ├─ Set local description
       └─ Send answer via Socket.IO (webrtc_answer)
   ↓
6. Server routes webrtc_answer to caller
   ↓
7. Caller receives answer
   ├─ Set remote description
   └─ ICE connection starts
   ↓
8. ICE candidates exchanged
   ├─ Both sides send ICE candidates
   ├─ Server routes candidates
   └─ WebRTC establishes connection
   ↓
9. Media streams flow
   ├─ onTrack events fire
   ├─ Remote streams available
   └─ Call is active!
```

### Call Rejection Flow

```
1. User taps "Reject" on incoming call
   ↓
2. CallScreen._rejectCall()
   ├─ Stop ringtone/vibration
   └─ WebRTCCallService.rejectCall(callId)
       └─ Emit call_reject via Socket.IO
   ↓
3. Server processes call_reject
   ├─ Emit call_rejected to call room
   └─ Notify all participants
   ↓
4. Caller receives call_rejected
   ├─ Update UI (call rejected)
   └─ End call
```

### Call End Flow

```
1. User taps "End Call" button
   ↓
2. CallScreen._endCall()
   └─ WebRTCCallService.endCall()
       ├─ Close all peer connections
       ├─ Stop all media streams
       ├─ Emit call_end via Socket.IO
       └─ Reset call state
   ↓
3. Server processes call_end
   ├─ Emit call_ended to all participants
   ├─ Cleanup call state (activeCalls Map)
   └─ Update MongoDB (remove from user.activeCalls)
   ↓
4. All participants receive call_ended
   ├─ Close peer connections
   ├─ Stop media streams
   └─ Navigate back (pop CallScreen)
```

---

## 📡 Media Stream Flow - How Streams Reach Users

### WebRTC Connection Establishment

```
1. Peer Connection Created
   ├─ Configured with ICE servers (STUN/TURN)
   ├─ Local media stream added
   └─ Event handlers registered
   ↓
2. Offer/Answer Exchange
   ├─ Caller creates offer (SDP)
   ├─ Offer sent via Socket.IO
   ├─ Recipient receives offer
   ├─ Recipient creates answer (SDP)
   └─ Answer sent via Socket.IO
   ↓
3. ICE Candidate Gathering
   ├─ Each peer gathers ICE candidates:
   │   ├─ Host candidates (local IP)
   │   ├─ Server reflexive (STUN)
   │   └─ Relay candidates (TURN)
   ├─ Candidates sent via Socket.IO
   └─ Candidates added to peer connection
   ↓
4. ICE Connection Establishment
   ├─ WebRTC tries candidates in priority order
   ├─ Attempts direct connection (host/srflx)
   ├─ Falls back to TURN relay if needed
   └─ Connection established
   ↓
5. Media Stream Flow
   ├─ onTrack event fires when remote stream arrives
   ├─ Remote stream added to _remoteStreams Map
   ├─ UI updated with remote video renderer
   └─ Audio/video flows through established connection
```

### Reconnection Logic

**On Connection Failure:**
- ICE connection state changes to `Failed` or `Disconnected`
- Reconnection logic triggers automatically
- **Max Attempts**: 3 reconnection attempts
- **Delay**: 2 seconds between attempts
- **Process**:
  1. Check if call is still active (`_currentCallId != null && _isInCall`)
  2. Verify peer connection still exists
  3. Check connection state (skip if already connected)
  4. Re-add local stream tracks if missing
  5. Create new offer for re-negotiation
  6. Send offer via signaling to re-establish connection
- **On Success**: Connection restored, media streams resume
- **On Failure**: After 3 attempts, remote stream is removed and connection is considered lost
```

### Media Stream Paths

#### Same Network (Direct Connection)
```
Device 1 (192.168.1.10) ←───Direct P2P───→ Device 2 (192.168.1.20)
         │                                        │
         └───────────STUN (NAT discovery)─────────┘
```

#### Different Networks (TURN Relay)
```
Device 1 (Mobile Data) ──→ TURN Server (Twilio) ──→ Device 2 (WiFi)
         │                        │                        │
         └───UDP───┐              │              ┌───UDP───┘
                   │              │              │
                   └──────────────┴──────────────┘
                        Media Relay
```

### Stream Types

#### Audio Stream
- **Source**: Microphone
- **Codec**: Opus (default)
- **Bitrate**: Adaptive (based on network)
- **Transport**: UDP (via WebRTC)

#### Video Stream
- **Source**: Camera (front/back)
- **Codec**: VP8/VP9/H.264 (negotiated)
- **Resolution**: Adaptive (640x480 to 1280x720)
- **Frame Rate**: 30fps (adaptive)
- **Transport**: UDP (via WebRTC)

### ICE Candidate Types

1. **Host Candidate** (`typ host`)
   - Local IP address
   - Works only on same network
   - Lowest priority

2. **Server Reflexive Candidate** (`typ srflx`)
   - Public IP discovered via STUN
   - Works if NAT allows
   - Medium priority

3. **Relay Candidate** (`typ relay`)
   - TURN server IP
   - Works across all networks
   - Highest priority (for cross-network)

**Priority Order:**
1. Relay (TURN) - For cross-network calls
2. Server Reflexive (STUN) - For NAT traversal
3. Host - For same-network calls

---

## 👥 Individual vs Group Calls

### Individual Calls (1-on-1)

**Architecture:**
- Single peer connection between two users
- Direct P2P connection (or TURN relay)
- Simpler signaling

**Flow:**
```
Caller ──→ Peer Connection ──→ Recipient
```

**Code:**
```dart
// In startCall():
for (final participantId in filteredParticipants) {
  final peerConnection = await _createPeerConnection(participantId);
  _peerConnections[participantId] = peerConnection;
  // ... add tracks, create offer
}
```

**Characteristics:**
- ✅ Lower latency
- ✅ Lower bandwidth usage
- ✅ Simpler to manage
- ✅ Better quality

### Group Calls (Multiple Participants)

**Architecture:**
- **Mesh Topology**: Each participant connects to every other participant
- N participants = N × (N-1) peer connections total
- Each participant maintains (N-1) peer connections

**Flow:**
```
        Participant 1
         /    |    \
        /     |     \
   P2 ─┴── P3 ┴── P4
   │        │       │
   └────────┴───────┘
   (All connected to all)
```

**Code:**
```dart
// In startCall() - same code, but multiple participants
for (final participantId in filteredParticipants) {
  // Creates peer connection for each participant
  final peerConnection = await _createPeerConnection(participantId);
  _peerConnections[participantId] = peerConnection;
}
```

**Port Usage:**
- Each peer connection uses 2 TURN relay ports (one per participant)
- For N participants: N × (N-1) ports needed
- Example: 5 participants = 5 × 4 = 20 ports

**Limitations:**
- ⚠️ Port exhaustion with large groups (max ~10 participants with 101 ports)
- ⚠️ Higher bandwidth usage (each participant sends to all others)
- ⚠️ More complex signaling

**Future Enhancement:**
- SFU (Selective Forwarding Unit) for larger groups
- Central server receives all streams and forwards to participants
- Reduces peer connections from N×(N-1) to N

---

## 🎤 Audio vs Video Calls

### Audio Calls (Voice-Only)

**Configuration:**
```dart
CallType.voice  // or CallType.audio
```

**Media Stream:**
```dart
constraints = {
  'audio': true,
  'video': false  // No video
}
```

**Characteristics:**
- ✅ Lower bandwidth (~50-100 kbps)
- ✅ Lower CPU usage
- ✅ Works on slower networks
- ✅ Better battery life

**UI:**
- Shows caller/recipient name/avatar
- No video renderers
- Audio controls only

### Video Calls

**Configuration:**
```dart
CallType.video
```

**Media Stream:**
```dart
constraints = {
  'audio': true,
  'video': {
    'facingMode': 'user',  // Front camera
    'width': {'min': 640, 'ideal': 1280},
    'height': {'min': 480, 'ideal': 720}
  }
}
```

**Characteristics:**
- ⚠️ Higher bandwidth (~500-2000 kbps)
- ⚠️ Higher CPU usage
- ⚠️ Requires better network
- ⚠️ Higher battery consumption

**UI:**
- Shows local video (small preview)
- Shows remote video (main view)
- Video controls (toggle, switch camera)
- Picture-in-picture support

**Code Detection:**
```dart
// In offer/answer SDP:
final hasVideo = sdp.contains('m=video');
final hasAudio = sdp.contains('m=audio');
```

**Call Type Flow:**
1. **Client sends**: `CallType.voice` or `CallType.video` (enum)
2. **Client converts to string**: `'voice'` or `'video'` for API
3. **Server normalizes**: `'voice'` → `'audio'` (line 3285)
4. **Server sends**: `'audio'` or `'video'` in call_invitation
5. **Client receives**: `'audio'` or `'video'` string
6. **Client converts back**: `'voice'/'audio'` → `CallType.voice`, `'video'` → `CallType.video`
7. **Client uses**: `CallType` enum throughout UI and logic

**Note**: Server uses `'audio'` internally, but clients handle both `'voice'` and `'audio'` for compatibility.

---

## 🌐 TURN/STUN Configuration

### STUN Servers

**Purpose**: NAT discovery (find public IP)

**Configuration:**
```dart
_iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
  // ... more STUN servers
];
```

**Always Included**: Yes (for NAT traversal)

### TURN Servers

**Purpose**: Media relay (when direct connection fails)

**Current Configuration: Twilio Cloud TURN**

**Priority Order:**
1. **Cloud TURN (Twilio)** - For cross-network calls
   - `turn:global.turn.twilio.com:3478?transport=udp`
   - `turn:global.turn.twilio.com:3478?transport=tcp`
   - `turns:global.turn.twilio.com:5349?transport=tcp`

2. **ngrok TURN** - Fallback (if cloud not enabled)
   - `turn:0.tcp.ngrok.io:12345` (TCP only, limited)

3. **Local IP TURN** - Same network only
   - `turn:10.120.4.230:3478` (excluded for mobile)

**Configuration Source:**
- Fetched from `/api/webrtc/turn-config` endpoint
- Configured in `servers/local_api_server/.env`:
  ```env
  CLOUD_TURN_ENABLED=true
  CLOUD_TURN_USERNAME=ACxxxxx:auth-token
  CLOUD_TURN_PASSWORD=auth-token
  CLOUD_TURN_URLS=turn:global.turn.twilio.com:3478?transport=udp,...
  ```

**Mobile vs Web:**
- **Mobile**: Only cloud/ngrok TURN (local excluded)
- **Web**: Local TURN first, then cloud/ngrok

---

## 🔧 Key Methods and Functions

### Client-Side Methods

#### WebRTCCallService

**`startCall()`** - Initiates a call
```dart
Future<String?> startCall({
  required String chatId,
  required String chatName,
  required List<String> participantIds,
  required CallType callType,
  bool isGroupChat = false,
})
```
- Generates callId
- Gets local media stream
- Creates peer connections
- Creates and sends offers
- Calls API to send invitations

**`acceptCall()`** - Accepts incoming call
```dart
Future<void> acceptCall(String callId)
```
- Gets local media stream
- Processes pending offers
- Creates peer connections
- Creates and sends answers
- Sets up media stream handlers

**`_createPeerConnection()`** - Creates WebRTC peer connection
```dart
Future<RTCPeerConnection> _createPeerConnection(String userId)
```
- Configures ICE servers
- Sets up event handlers (onTrack, onIceCandidate, etc.)
- Returns configured peer connection

**`_getLocalStream()`** - Gets local audio/video
```dart
Future<MediaStream> _getLocalStream({
  bool includeVideo = true,
  BuildContext? context
})
```
- Requests permissions
- Gets media from device
- Returns MediaStream

**`_handleWebRTCSignal()`** - Handles WebRTC signaling
```dart
Future<void> _handleWebRTCSignal(String type, dynamic data)
```
- Processes offers, answers, ICE candidates
- Updates peer connections
- Manages media streams

**`sendWebRTCSignal()`** - Sends WebRTC signaling
```dart
Future<void> sendWebRTCSignal(
  String type,
  Map<String, dynamic> data, {
  String? callId,
  String? targetUserId,
})
```
- Emits Socket.IO events
- Routes to specific user or call room

### Server-Side Methods

#### API Endpoints

**`POST /api/calls/start`** - Start call endpoint
- Validates request
- Stores call state
- Sends invitations (Socket.IO + FCM)

**`GET /api/webrtc/turn-config`** - TURN configuration
- Returns TURN servers
- Prioritizes cloud TURN
- Includes ngrok/local fallback

#### Socket.IO Handlers

**`call_accept`** - Handles call acceptance
- Validates call exists
- Emits acceptance to participants

**`call_reject`** - Handles call rejection
- Validates call exists
- Emits rejection to caller

**`call_end`** - Handles call termination
- Cleans up call state
- Notifies all participants

**`webrtc_offer`** - Routes WebRTC offers
- Validates offer
- Routes to target user

**`webrtc_answer`** - Routes WebRTC answers
- Validates answer
- Routes to caller

**`webrtc_ice_candidate`** - Routes ICE candidates
- Validates candidate
- Routes to target user

---

## 📊 Summary

### How Calls Reach Users

1. **Signaling Path**: Client → Server (Socket.IO) → Client
   - Call invitations
   - WebRTC offers/answers
   - ICE candidates
   - Call control events

2. **Notification Path**:
   - **Online**: Socket.IO real-time event
   - **Offline**: FCM push notification

### How Streams Reach Users

1. **Media Path**: Client ↔ TURN Server ↔ Client
   - Direct P2P when possible (same network)
   - TURN relay when needed (different networks)
   - Uses WebRTC (UDP for media)

2. **Connection Establishment**:
   - Offer/Answer exchange (via Socket.IO)
   - ICE candidate exchange (via Socket.IO)
   - WebRTC establishes connection
   - Media streams flow through connection

### Key Technologies

- **Signaling**: Socket.IO (WebSocket over TCP)
- **Media**: WebRTC (UDP for audio/video)
- **TURN**: Twilio Network Traversal Service
- **STUN**: Google public STUN servers
- **Permissions**: Platform-specific (Android 13+ granular)

### Current Status

✅ **Working:**
- Individual calls (audio/video)
- Group calls (audio/video)
- Cross-platform (Android, iOS, Web)
- Cross-network (via Twilio TURN)
- Call controls (mute, video toggle, etc.)

⚠️ **Limitations:**
- Group calls limited to ~10 participants (port exhaustion)
- Requires Twilio TURN for cross-network (cost: $0.40/GB)
- No SFU for larger groups (mesh topology only)

---

**Report Generated**: 2024-12-09
**System Version**: Current (with Twilio TURN integration)

