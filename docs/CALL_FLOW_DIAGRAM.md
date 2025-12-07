# 📞 Call Flow Diagram

## 🎯 Visual Call Process Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHAT SCREEN (Starting Point)                  │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  📞 Voice    │  │  📹 Video    │  │  📎 Media    │         │
│  │   Call       │  │   Call       │  │   Gallery    │         │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘         │
│         │                 │                                    │
└─────────┼─────────────────┼────────────────────────────────────┘
          │                 │
          ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              OUTGOING CALL SCREEN                                │
│                                                                 │
│         ┌──────────────────────┐                               │
│         │   Contact/Group Name  │                               │
│         └──────────────────────┘                               │
│                                                                 │
│         ┌──────────────────────┐                               │
│         │   "Calling..."        │                               │
│         │   or                  │                               │
│         │   "Video calling..."  │                               │
│         └──────────────────────┘                               │
│                                                                 │
│              ┌──────────┐                                       │
│              │   ❌     │  Cancel/End Call                      │
│              └──────────┘                                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Backend Process:                                         │ │
│  │  1. Generate unique Call ID                               │ │
│  │  2. Get local media stream (audio/video)                   │ │
│  │  3. Create WebRTC peer connections                        │ │
│  │  4. Send call invitation via API                           │ │
│  │  5. Send Socket.IO notification to participants           │ │
│  │  6. Send FCM push notification (if offline)              │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
          │
          │ (Participant receives invitation)
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│              INCOMING CALL SCREEN (Participant)                  │
│                                                                 │
│         ┌──────────────────────┐                               │
│         │   Caller/Group Name   │                               │
│         └──────────────────────┘                               │
│                                                                 │
│         ┌──────────────────────┐                               │
│         │ "Incoming Voice Call" │                               │
│         │   or                  │                               │
│         │ "Incoming Video Call" │                               │
│         └──────────────────────┘                               │
│                                                                 │
│    ┌──────────┐          ┌──────────┐                         │
│    │   ❌      │          │   ✅     │                         │
│    │  Reject   │          │  Answer  │                         │
│    └──────────┘          └──────────┘                         │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  User Action:                                            │ │
│  │  • Tap ✅ Answer → Call becomes active                    │ │
│  │  • Tap ❌ Reject → Call ends, returns to chat            │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
          │
          │ (User taps Answer)
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ACTIVE CALL SCREEN                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────┐    │  │
│  │  │                                                │    │  │
│  │  │     REMOTE VIDEO STREAM                        │    │  │
│  │  │     (Full screen for individual)               │    │  │
│  │  │     (Grid layout for group)                    │    │  │
│  │  │                                                │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                                                          │  │
│  │  ┌──────────────┐                                        │  │
│  │  │              │  Local Video Preview (PIP)            │  │
│  │  │   Your Video │  (Top-right corner)                    │  │
│  │  │              │  (Video calls only)                   │  │
│  │  └──────────────┘                                        │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              CALL CONTROLS (Bottom Bar)                  │  │
│  │                                                          │  │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐      │  │
│  │  │ 🎤  │  │ 📹  │  │ 🔄  │  │      │  │ 📴  │      │  │
│  │  │Mute │  │Video│  │Camera│  │      │  │ End │      │  │
│  │  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘      │  │
│  │                                                          │  │
│  │  ⏱️ Call Duration: MM:SS                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Available Features:                                      │  │
│  │  • 🎤 Mute/Unmute Audio                                   │  │
│  │  • 📹 Enable/Disable Video (video calls only)            │  │
│  │  • 🔄 Switch Camera (video calls only)                   │  │
│  │  • 📴 End Call                                            │  │
│  │  • ⏱️ Call Duration Timer                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │
          │ (User taps End Call or call ends)
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CALL ENDED SCREEN                             │
│                                                                 │
│              ┌──────────┐                                       │
│              │   📴     │                                       │
│              └──────────┘                                       │
│                                                                 │
│         ┌──────────────────────┐                               │
│         │   "Call Ended"        │                               │
│         │   or                  │                               │
│         │   "Call Rejected"     │                               │
│         └──────────────────────┘                               │
│                                                                 │
│              ┌──────────┐                                       │
│              │  Close   │                                       │
│              └──────────┘                                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Backend Process:                                         │  │
│  │  1. Close all WebRTC peer connections                    │  │
│  │  2. Stop local media streams                              │  │
│  │  3. Clean up resources                                    │  │
│  │  4. Notify all participants                              │  │
│  │  5. Return to chat screen                                │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Call State Transitions

```
┌─────────────┐
│   IDLE      │  (No call active)
└──────┬──────┘
       │
       │ User taps call button
       ▼
┌─────────────┐
│ INITIATING  │  (Setting up call)
└──────┬──────┘
       │
       │ Call invitation sent
       ▼
┌─────────────┐
│  RINGING    │  (Waiting for answer)
└──────┬──────┘
       │
       │ Participant answers
       ▼
┌─────────────┐
│   ACTIVE    │  (Call connected)
└──────┬──────┘
       │
       │ User ends call OR
       │ Participant rejects/ends
       ▼
┌─────────────┐
│   ENDED     │  (Call terminated)
└──────┬──────┘
       │
       │ Auto-close after 2 seconds
       ▼
┌─────────────┐
│   IDLE      │  (Back to chat)
└─────────────┘
```

---

## 👥 Individual vs Group Call Flow

### **Individual Call:**
```
User A                    User B
   │                         │
   │─── Tap Call Button ────▶│
   │                         │
   │─── Outgoing Screen ────▶│─── Incoming Screen
   │                         │
   │─── Ringing ────────────▶│─── Ringing
   │                         │
   │                         │─── Tap Answer
   │                         │
   │◀── Active Call ────────▶│─── Active Call
   │                         │
   │    (Full-screen video)  │    (Full-screen video)
   │    (Local PIP)          │    (Local PIP)
   │                         │
   │─── End Call ───────────▶│
   │                         │
   │─── Call Ended ─────────▶│─── Call Ended
```

### **Group Call:**
```
User A          User B          User C          User D
   │               │               │               │
   │─── Tap Call ──┼───────────────┼───────────────▶│
   │               │               │               │
   │─── Outgoing ───┼───────────────┼───────────────▶│─── Incoming
   │               │               │               │
   │               │─── Incoming ──┼───────────────▶│─── Incoming
   │               │               │               │
   │               │               │─── Incoming ──▶│─── Incoming
   │               │               │               │
   │               │─── Answer ────┼───────────────▶│─── Answer
   │               │               │               │
   │               │               │─── Answer ────▶│─── Answer
   │               │               │               │
   │◀── Active ────┼───────────────┼───────────────▶│─── Active
   │               │               │               │
   │  (Grid view)   │  (Grid view)  │  (Grid view)  │  (Grid view)
   │  (All users)   │  (All users)   │  (All users)   │  (All users)
   │               │               │               │
   │─── End ────────┼───────────────┼───────────────▶│
   │               │               │               │
   │─── Ended ──────┼───────────────┼───────────────▶│─── Ended
```

---

## 🎮 Control Button Layout

### **Active Call Controls (Bottom Bar):**

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              ⏱️ Call Duration: 05:23                    │
│                                                         │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐     │
│  │ 🎤  │  │ 📹  │  │ 🔄  │  │      │  │ 📴  │     │
│  │Mute │  │Video│  │Camera│  │      │  │ End │     │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Button Functions:**
- **🎤 Mute**: Toggle microphone on/off
- **📹 Video**: Toggle video on/off (video calls only)
- **🔄 Camera**: Switch front/back camera (video calls only)
- **📴 End**: End the call

---

## 📊 Feature Availability Matrix

| Feature | Voice Call | Video Call | Individual | Group |
|--------|-----------|------------|------------|-------|
| Audio | ✅ | ✅ | ✅ | ✅ |
| Video | ❌ | ✅ | ✅ | ✅ |
| Mute/Unmute | ✅ | ✅ | ✅ | ✅ |
| Video Toggle | N/A | ✅ | ✅ | ✅ |
| Switch Camera | N/A | ✅ | ✅ | ✅ |
| Call Timer | ✅ | ✅ | ✅ | ✅ |
| Local Preview | N/A | ✅ | ✅ | ✅ |
| Grid Layout | N/A | N/A | ❌ | ✅ |
| Full Screen | N/A | ✅ | ✅ | ❌ |

---

## 🔐 Security & Privacy

- **Encryption**: All calls use DTLS-SRTP encryption (built into WebRTC)
- **Peer-to-Peer**: Direct connections between participants
- **No Recording**: Calls are not recorded by the app
- **Permissions**: Microphone/Camera permissions required and requested

---

*This diagram shows the complete call flow from initiation to termination.*

