# Mobile Browser WebRTC Support Issue

## Problem

When testing TURN server on mobile device, you may see:
```
Error creating offer: ReferenceError: Can't find variable: RTCPeerConnection
```

This means your mobile browser doesn't support WebRTC or has limited WebRTC support.

## Solutions

### Solution 1: Use a Different Mobile Browser

Try these browsers that have better WebRTC support:

1. **Chrome (Android/iOS)** - Best WebRTC support
   - Download from Play Store/App Store
   - Visit: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

2. **Firefox (Android)** - Good WebRTC support
   - Download from Play Store
   - Visit: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

3. **Edge (Android/iOS)** - Good WebRTC support
   - Download from Play Store/App Store
   - Visit: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

**Avoid:**
- Safari on iOS (limited WebRTC support)
- Older browsers
- In-app browsers (Facebook, Instagram, etc.)

### Solution 2: Use Desktop Browser

If you have access to a laptop/desktop on a different network:

1. **Open Chrome, Firefox, or Edge** on the desktop
2. **Visit:** https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
3. **Add TURN server:**
   - URLs: `turn:41.33.106.54:3478`
   - Username: `soc-chat-turn`
   - Password: `yG5EJFUdLgT7xqXr`
4. **Click "Gather candidates"**
5. **Check for `relay` candidates**

### Solution 3: Use Alternative TURN Testing Tools

#### Option A: ICE Test Tool
1. **Visit:** https://icetest.info/
2. **Enter TURN server details:**
   - TURN Server: `turn:41.33.106.54:3478`
   - Username: `soc-chat-turn`
   - Password: `yG5EJFUdLgT7xqXr`
3. **Click "Test"**
4. **Check results** - Green checkmark = working

#### Option B: Test from Your Chat App
Since your app uses Flutter WebRTC (which has better mobile support):

1. **Install the app on a device on mobile data** (not WiFi)
2. **Make a test call** to another device on a different network
3. **Check device logs** for RELAY candidates:
   ```bash
   adb logcat -s flutter:* | grep -i "RELAY\|ICE_CANDIDATE"
   ```
4. **Look for:**
   - `[ICE_CANDIDATE] ✅✅✅ RELAY candidate`
   - TURN server IP: `41.33.106.54`
   - If you see RELAY candidates, port forwarding is working!

### Solution 4: Test from Command Line (Advanced)

If you have access to a Linux/Mac machine on a different network:

```bash
# Install turnutils
sudo apt-get install coturn-utils  # Ubuntu/Debian
# or
brew install coturn  # macOS

# Test TURN server
turnutils_stunclient -v 41.33.106.54:3478
```

## Recommended Approach

**Best option:** Use your Flutter app to test directly:

1. **Device 1:** On mobile data (different network)
2. **Device 2:** On WiFi (your server's network) or another different network
3. **Make a call** between them
4. **Check logs** for RELAY candidates

This is the most accurate test since it uses the same WebRTC implementation as your app.

## Quick Checklist

- [ ] Try Chrome browser on mobile
- [ ] Try Firefox browser on mobile
- [ ] Use desktop browser on different network
- [ ] Use https://icetest.info/ alternative tool
- [ ] Test directly from your Flutter app (best option)

## Why This Happens

- Some mobile browsers have limited or no WebRTC support
- Safari on iOS has restricted WebRTC support
- In-app browsers often don't support WebRTC
- Older browsers may not have WebRTC APIs

## Next Steps

1. **Try Chrome on your mobile device** (best mobile browser for WebRTC)
2. **Or test directly from your Flutter app** (most accurate test)
3. **Or use a desktop browser** on a different network

