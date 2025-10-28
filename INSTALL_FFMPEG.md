# How to Install FFmpeg on Your Server

## Important
FFmpeg needs to be installed on your **SERVER** (the main PC where Node.js is running), not on your local Mac.

## Steps

1. **SSH into your server:**
   ```bash
   ssh your-username@your-server-ip
   ```

2. **Install ffmpeg:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y ffmpeg
   ```

3. **Verify installation:**
   ```bash
   ffmpeg -version
   ```
   You should see output showing ffmpeg version.

4. **Pull the latest code:**
   ```bash
   cd /path/to/soc-chat-app
   git pull origin main
   ```

5. **Restart your Node.js services**

6. **Upload a NEW video** from mobile - it will now be transcoded automatically!

## After Installation

Once ffmpeg is installed, when you upload videos, you'll see in the server logs:
```
✓ FFmpeg is available
Checking if video needs transcoding...
Needs transcoding: true
🔄 Transcoding video to web-compatible format...
✅ Video transcoded successfully
```

Your videos will now play in web browsers!

