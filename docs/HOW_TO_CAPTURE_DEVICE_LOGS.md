# How to Capture Device Logs for Call Diagnostics

## Quick Start

### Option 1: Use the Automated Script
```powershell
.\scripts\capture_call_logs.ps1
```

The script will:
- Find ADB automatically
- Check for connected devices
- Clear log buffer
- Capture relevant logs during a call

**Steps:**
1. Connect both devices via USB
2. Enable USB debugging on both devices
3. Run the script
4. Make a call between devices
5. Wait for logs to appear
6. Press Ctrl+C to stop

### Option 2: Manual Commands

If ADB is in your PATH:
```powershell
# Clear log buffer first
adb logcat -c

# Start capturing (run this, then make a call)
adb logcat | findstr /i "ICE_CONNECTION ON_TRACK ON_ADD_STREAM CALL_SCREEN TURN_CONFIG RELAY"
```

If ADB is NOT in your PATH:
```powershell
# Find ADB first (usually in one of these locations):
# %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
# %ANDROID_HOME%\platform-tools\adb.exe

# Then run:
& "C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools\adb.exe" logcat | findstr /i "ICE_CONNECTION ON_TRACK ON_ADD_STREAM CALL_SCREEN"
```

## What to Look For

### ✅ Good Signs (Working Correctly):

1. **ICE Connection Completes:**
   ```
   🔵 [ICE_CONNECTION] ✅✅✅ Connection established with [userId] - media should flow now!
   🔵 [ICE_CONNECTION] State: RTCIceConnectionStateCompleted
   ```

2. **Media Tracks Received:**
   ```
   🔵 [ON_TRACK] ========== REMOTE TRACK RECEIVED ==========
   🔵 [ON_TRACK] Track kind: audio
   🔵 [ON_TRACK] Track kind: video
   ```

3. **UI Updates:**
   ```
   🔵 [CALL_SCREEN] onRemoteStream callback triggered for user: [userId]
   🔵 [CALL_SCREEN] Renderer initialized and stream set
   ```

### ❌ Bad Signs (Issues):

1. **ICE Connection Stuck:**
   ```
   🔵 [ICE_CONNECTION] State changed to RTCIceConnectionStateChecking
   (No "Connection established" message)
   ```

2. **No Media Tracks:**
   ```
   (No [ON_TRACK] or [ON_ADD_STREAM] messages)
   ```

3. **No UI Updates:**
   ```
   (No [CALL_SCREEN] onRemoteStream messages)
   ```

## Specific Diagnostic Commands

### Check ICE Connection State:
```powershell
adb logcat -d | findstr /i "ICE_CONNECTION"
```

### Check for Media Tracks:
```powershell
adb logcat -d | findstr /i "ON_TRACK ON_ADD_STREAM"
```

### Check UI Updates:
```powershell
adb logcat -d | findstr /i "CALL_SCREEN.*onRemoteStream"
```

### Check TURN Configuration:
```powershell
adb logcat -d | findstr /i "TURN_CONFIG RELAY"
```

### Get All Call-Related Logs:
```powershell
adb logcat -d | findstr /i "ICE_CONNECTION ON_TRACK ON_ADD_STREAM CALL_SCREEN TURN_CONFIG RELAY ICE_CANDIDATE"
```

## Troubleshooting

### "adb: command not found"
- Install Android SDK Platform Tools
- Add to PATH: `%LOCALAPPDATA%\Android\Sdk\platform-tools`
- Or set `ANDROID_HOME` environment variable

### "No devices found"
- Connect device via USB
- Enable USB debugging
- Accept the "Allow USB debugging" prompt on device

### "No logs appearing"
- Make sure you're making a call
- Check that the app is running
- Try clearing log buffer first: `adb logcat -c`

## Saving Logs to File

To save logs for later analysis:
```powershell
adb logcat > call_logs.txt
# Make a call, then press Ctrl+C
# Then filter:
Get-Content call_logs.txt | Select-String -Pattern "ICE_CONNECTION|ON_TRACK|CALL_SCREEN" -CaseSensitive:$false
```

## Next Steps

After capturing logs:
1. Look for the messages listed above
2. Share the relevant log snippets
3. Check which step is failing:
   - ICE connection not completing?
   - Media tracks not received?
   - UI not updating?

