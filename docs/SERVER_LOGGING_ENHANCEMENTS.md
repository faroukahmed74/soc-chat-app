# 🔍 Server-Side Logging Enhancements

**Date:** 2025-01-03  
**Purpose:** Enhanced server-side logging to diagnose media stream issues

---

## ✅ Enhancements Applied

### 1. Enhanced `join_call` Handler Logging

**Location:** `servers/local_api_server/server.js`

**Added Logging:**
- ✅ Socket.userId and Socket ID
- ✅ Data received (full JSON)
- ✅ Current rooms before join
- ✅ Rooms after join
- ✅ Total sockets in call room
- ✅ Socket IDs in room

**What to Look For:**
- Are users joining the call room?
- How many sockets are in the room?
- Are the socket IDs correct?

---

### 2. Enhanced `webrtc_offer` Handler Logging

**Location:** `servers/local_api_server/server.js`

**Added Logging:**
- ✅ Full data received (JSON)
- ✅ Socket.userId and Socket ID
- ✅ Room name and target room
- ✅ Target user ID
- ✅ SDP verification (Audio/Video presence)
- ✅ Socket count in target room
- ✅ Socket IDs in target room
- ✅ Warning if no sockets in target room

**What to Look For:**
- Is the offer being received?
- Does the SDP contain media tracks?
- Is the target user in the room?
- Are signals being routed correctly?

---

### 3. Enhanced `webrtc_answer` Handler Logging

**Location:** `servers/local_api_server/server.js`

**Added Logging:**
- ✅ Full data received (JSON)
- ✅ Socket.userId and Socket ID
- ✅ Room name and target room
- ✅ Target user ID
- ✅ SDP verification (Audio/Video presence)
- ✅ Socket count in target room
- ✅ Socket IDs in target room
- ✅ Warning if no sockets in target room

**What to Look For:**
- Is the answer being received?
- Does the SDP contain media tracks?
- Is the target user in the room?
- Are signals being routed correctly?

---

### 4. Enhanced `webrtc_ice_candidate` Handler Logging

**Location:** `servers/local_api_server/server.js`

**Added Logging:**
- ✅ Error details with stack traces
- ✅ Missing data warnings

---

## 🔍 What to Check in Server Logs

### When a Call Starts:

1. **Join Call:**
   ```
   🔵 [SERVER] ========== JOIN CALL ==========
   🔵 [SERVER] Socket.userId: <userId>
   🔵 [SERVER] Data received: {"callId": "..."}
   🔵 [SERVER] Total sockets in call room: <count>
   ```

2. **WebRTC Offer:**
   ```
   🔵 [SERVER] ========== WebRTC OFFER RECEIVED ==========
   🔵 [SERVER] From socket.userId: <userId>
   🔵 [SERVER] Offer SDP contains - Audio: true, Video: true
   🔵 [SERVER] Sockets in target room: <count>
   ```

3. **WebRTC Answer:**
   ```
   🔵 [SERVER] ========== WebRTC ANSWER RECEIVED ==========
   🔵 [SERVER] From socket.userId: <userId>
   🔵 [SERVER] Answer SDP contains - Audio: true, Video: true
   🔵 [SERVER] Sockets in target room: <count>
   ```

---

## ⚠️ Common Issues to Look For

### Issue 1: No Sockets in Target Room
```
⚠️ [SERVER] WARNING: No sockets found in target room: user:<userId>
```
**Meaning:** The target user hasn't joined their personal room or the user ID format doesn't match.

**Solution:** Check if:
- User is connected to Socket.IO
- User has joined their personal room (`user:<userId>`)
- User ID format matches (string vs ObjectId)

---

### Issue 2: SDP Missing Media
```
⚠️ [SERVER] WARNING: Offer SDP does not contain media!
```
**Meaning:** The SDP doesn't have `m=audio` or `m=video` lines.

**Solution:** Check if:
- Local tracks are added before creating offer/answer
- Media stream is obtained correctly
- Tracks are enabled

---

### Issue 3: Room Not Joined
```
🔵 [SERVER] Total sockets in call room: 0
```
**Meaning:** No one has joined the call room.

**Solution:** Check if:
- `join_call` event is being emitted
- `join_call` handler is working
- Call ID format matches

---

## 📊 Testing Checklist

When testing, check the server logs for:

1. ✅ **Both users join call room:**
   - Should see 2 `JOIN CALL` logs
   - Should see 2 sockets in call room

2. ✅ **Offer is sent and received:**
   - Should see `WebRTC OFFER RECEIVED` from caller
   - Should see SDP contains Audio/Video
   - Should see target room has sockets

3. ✅ **Answer is sent and received:**
   - Should see `WebRTC ANSWER RECEIVED` from recipient
   - Should see SDP contains Audio/Video
   - Should see target room has sockets

4. ✅ **ICE candidates are exchanged:**
   - Should see multiple `WebRTC ICE candidate sent` logs
   - Should see candidates from both users

---

## 🔧 Next Steps

1. **Start the server** and monitor logs
2. **Make a test call** between two devices
3. **Check server logs** for the indicators above
4. **Report any warnings or errors** you see

The enhanced logging will help us identify exactly where the media stream flow is breaking.

---

**Status:** ✅ **SERVER LOGGING ENHANCED - READY FOR TESTING**

