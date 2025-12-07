# 📞 Call System - User Guide

## 🎯 Overview

The app supports **individual** and **group** calls with both **voice** (audio-only) and **video** options. All calls use WebRTC for real-time peer-to-peer communication.

---

## 🚀 How to Start a Call

### **Step 1: Open a Chat**
- Navigate to any individual chat or group chat
- The chat screen displays the conversation

### **Step 2: Tap Call Buttons**
In the chat screen's **AppBar** (top toolbar), you'll see two call buttons:

1. **📞 Voice Call Button** (Phone icon)
   - Starts an audio-only call
   - No video is transmitted

2. **📹 Video Call Button** (Video camera icon)
   - Starts a video call with audio
   - Both video and audio are transmitted

### **Step 3: Call Process**
After tapping a call button:

1. **Outgoing Call Screen** appears showing:
   - Contact/Group name
   - "Calling..." or "Video calling..." status
   - Cancel button (red end call button)

2. **Call Invitation** is sent to participants:
   - Individual chat: Sent to the other user
   - Group chat: Sent to all group members (except you)

3. **Participants receive notification**:
   - **If online**: Real-time notification via Socket.IO
   - **If offline**: Push notification (FCM) on mobile devices

---

## 📱 Incoming Call Flow

### **When You Receive a Call:**

1. **Incoming Call Screen** appears automatically showing:
   - Caller's name (or group name)
   - Call type indicator ("Incoming Voice Call" or "Incoming Video Call")
   - Two buttons:
     - **❌ Reject** (red button) - Declines the call
     - **✅ Answer** (green button) - Accepts the call

2. **Accepting the Call:**
   - Tap the green **Answer** button
   - Call screen transitions to **Active Call** view
   - Media streams start (audio/video)

3. **Rejecting the Call:**
   - Tap the red **Reject** button
   - Call is declined
   - Caller sees "Call Rejected" message

---

## 🎬 Active Call Features

Once a call is active, you have access to the following features:

### **1. Call Duration Timer** ⏱️
- Displays at the top of the call controls
- Shows elapsed time in format: `MM:SS` or `HH:MM:SS`
- Updates in real-time

### **2. Mute/Unmute Audio** 🎤
- **Button**: Microphone icon
- **Location**: Bottom control bar
- **Function**: 
  - Toggle to mute/unmute your microphone
  - When muted: Icon turns red (mic_off)
  - When unmuted: Icon is white (mic)
- **Effect**: Other participants won't hear you when muted

### **3. Enable/Disable Video** 📹
- **Button**: Video camera icon
- **Location**: Bottom control bar (only visible in video calls)
- **Function**:
  - Toggle to turn video on/off
  - When disabled: Icon turns red (videocam_off)
  - When enabled: Icon is white (videocam)
- **Effect**: Your video stream stops/starts for other participants

### **4. Switch Camera** 🔄
- **Button**: Switch camera icon
- **Location**: Bottom control bar (only visible in video calls)
- **Function**:
  - Toggles between front and back camera
  - Updates the local preview immediately
- **Effect**: Other participants see the new camera view

### **5. End Call** 📴
- **Button**: Red end call button (largest button)
- **Location**: Bottom control bar (rightmost)
- **Function**: 
  - Ends the call for all participants
  - Returns to chat screen
  - Cleans up all media resources

---

## 🎥 Video Call UI Features

### **Individual Video Calls:**
- **Main View**: Full-screen remote video feed
- **Local Preview**: Picture-in-picture (PIP) in top-right corner
  - Shows your own video
  - Size: 120x160px (mobile) or 160x213px (tablet/desktop)
  - Mirrored when using front camera
  - White border for visibility

### **Group Video Calls:**
- **Layout**: Grid view showing all participants
  - Mobile: 2 columns
  - Tablet/Desktop: 3 columns
- **Each Participant**: 
  - Individual video tile
  - Rounded corners
  - Black background if video unavailable
- **Local Preview**: Still shown in top-right corner

### **Voice Call UI:**
- **Main View**: 
  - Large avatar/icon
  - Contact/Group name
  - Call duration timer
  - Clean, minimal interface

---

## 🔄 Call States & Transitions

### **Call States:**

1. **🟡 Initiating** (Outgoing)
   - Call is being set up
   - WebRTC connections are being established

2. **🟡 Ringing** (Outgoing/Incoming)
   - Outgoing: Waiting for participants to answer
   - Incoming: Call is ringing, waiting for your response

3. **🟢 Active** (Connected)
   - Call is connected
   - Media streams are active
   - All features available

4. **🔴 Ended** (Terminated)
   - Call has ended
   - Shows "Call Ended" message
   - Auto-closes after 2 seconds

5. **🔴 Rejected** (Declined)
   - Call was rejected
   - Shows "Call Rejected" message
   - Auto-closes after 2 seconds

---

## 👥 Individual vs Group Calls

### **Individual Calls:**
- **Participants**: 2 people (you + 1 other)
- **Start**: Tap call button in individual chat
- **UI**: 
  - Video: Full-screen remote video + local PIP
  - Voice: Large avatar with name and timer
- **Features**: All standard features available

### **Group Calls:**
- **Participants**: Multiple people (you + 2+ others)
- **Start**: Tap call button in group chat
- **UI**:
  - Video: Grid layout showing all participants
  - Voice: Large group icon with group name and timer
- **Features**: All standard features available
- **Note**: Each participant can independently mute/video toggle

---

## 🎨 Responsive Design

The call UI adapts to different screen sizes:

### **Mobile (< 600px):**
- Compact call buttons (60px)
- Smaller text sizes
- 2-column grid for group calls
- Optimized touch targets

### **Tablet (600px - 1200px):**
- Medium-sized buttons (70px)
- Medium text sizes
- 3-column grid for group calls
- Touch-friendly interactions

### **Desktop (> 1200px):**
- Larger buttons (70px)
- Larger text sizes
- 3-column grid for group calls
- Mouse-friendly interactions

---

## 🔧 Technical Features

### **WebRTC Implementation:**
- **Peer-to-Peer**: Direct connections between participants
- **STUN Servers**: Google's public STUN servers for NAT traversal
- **Signaling**: Socket.IO for call setup and control
- **Encryption**: DTLS-SRTP encryption (built into WebRTC)

### **Real-Time Communication:**
- **Low Latency**: Direct P2P connections
- **Quality**: Adaptive bitrate based on network conditions
- **Reliability**: Automatic reconnection on network issues

### **Permissions Required:**
- **Microphone**: For audio in all calls
- **Camera**: For video in video calls
- Permissions are requested automatically when needed

---

## 📋 Quick Reference

### **Starting a Call:**
1. Open chat → Tap 📞 (voice) or 📹 (video) button
2. Wait for participants to answer
3. Call becomes active

### **Receiving a Call:**
1. Incoming call screen appears
2. Tap ✅ to answer or ❌ to reject
3. If answered, call becomes active

### **During a Call:**
- **Mute**: Tap 🎤 button
- **Video Toggle**: Tap 📹 button (video calls only)
- **Switch Camera**: Tap 🔄 button (video calls only)
- **End Call**: Tap 📴 button

### **Call Controls Location:**
- **Bottom Bar**: All call controls
- **Top-Right**: Local video preview (video calls)
- **Center**: Remote video/avatar

---

## ⚠️ Important Notes

1. **Internet Required**: All calls require an active internet connection
2. **Permissions**: Grant microphone/camera permissions when prompted
3. **Battery**: Video calls consume more battery than voice calls
4. **Data Usage**: Video calls use more data than voice calls
5. **Group Calls**: Performance may vary with number of participants
6. **Network Quality**: Call quality adapts to available bandwidth

---

## 🐛 Troubleshooting

### **Call Not Starting:**
- Check internet connection
- Verify permissions are granted
- Try restarting the app

### **No Audio:**
- Check microphone permissions
- Verify device volume is not muted
- Check if you're muted in the call

### **No Video:**
- Check camera permissions
- Verify video is enabled (not toggled off)
- Try switching camera

### **Call Drops:**
- Check network stability
- Ensure app is not in background (mobile)
- Try reconnecting

---

## 📞 Summary

**Available Call Types:**
- ✅ Individual Voice Calls
- ✅ Individual Video Calls
- ✅ Group Voice Calls
- ✅ Group Video Calls

**Call Features:**
- ✅ Mute/Unmute Audio
- ✅ Enable/Disable Video
- ✅ Switch Camera (Front/Back)
- ✅ Call Duration Timer
- ✅ Picture-in-Picture (Video Calls)
- ✅ Grid Layout (Group Video Calls)
- ✅ Real-Time Media Streaming
- ✅ Responsive UI

**Call Flow:**
1. Tap call button in chat
2. Wait for answer (outgoing) or answer incoming call
3. Use controls during active call
4. End call when finished

---

*Last Updated: 2025-01-XX*

