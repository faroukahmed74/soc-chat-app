# How to Transcode Existing Videos

## Problem
Existing videos sent before adding the transcoding feature are in HEVC/H.265 format, which browsers don't support.

## Solution
Run the transcoding script to convert all existing videos to web-compatible H.264 format.

## Steps

1. **SSH into your server** (the one running node.js services)

2. **Install ffmpeg** (if not already installed):
   ```bash
   sudo apt-get update
   sudo apt-get install -y ffmpeg
   ```

3. **Navigate to the project directory**:
   ```bash
   cd /path/to/soc-chat-app/servers/local_api_server
   ```

4. **Run the transcoding script**:
   ```bash
   node transcode_all_videos.js
   ```

5. **Wait for it to complete**. You'll see output like:
   ```
   Found 15 video messages to check
   Transcoding video for message 12345...
   ✓ Successfully transcoded: video_filename.mp4
   ...
   
   === Transcoding Summary ===
   Total videos: 15
   Transcoded: 12
   Skipped: 3
   Errors: 0
   ```

6. **After completion, refresh the web page** and the videos should now play.

## Alternative: Send New Videos
- If you don't want to transcode existing videos, just send NEW videos from mobile
- New videos will be automatically transcoded when uploaded

## Troubleshooting

**"ffmpeg not found" error:**
- Make sure ffmpeg is installed: `ffmpeg -version`
- Install it: `sudo apt-get install -y ffmpeg`

**"No videos found":**
- Check your database connection
- Verify that videos exist in the `messages` collection

**"Permission denied":**
- Make sure you can write to the uploads directory
- Check: `ls -la uploads/`

