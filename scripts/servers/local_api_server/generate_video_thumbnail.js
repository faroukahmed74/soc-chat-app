// Generate video thumbnail using ffmpeg
// This requires ffmpeg to be installed on the server

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

async function generateVideoThumbnail(videoPath, outputDir, fileName) {
  try {
    // Create output directory if it doesn't exist
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    const thumbnailPath = path.join(outputDir, `${fileName}_thumb.jpg`);
    
    // Check if ffmpeg is available
    try {
      await execAsync('ffmpeg -version');
    } catch (err) {
      console.error('ffmpeg not found. Please install ffmpeg to generate video thumbnails.');
      return null;
    }

    // Generate thumbnail using ffmpeg
    // Extract frame at 1 second mark, resize to 320x240
    const command = `ffmpeg -i "${videoPath}" -ss 00:00:01 -vframes 1 -vf "scale=320:240:force_original_aspect_ratio=decrease" "${thumbnailPath}"`;
    
    await execAsync(command);
    
    console.log(`Video thumbnail generated: ${thumbnailPath}`);
    return thumbnailPath;
  } catch (error) {
    console.error('Error generating video thumbnail:', error);
    return null;
  }
}

async function generateThumbnailFromUrl(videoUrl, outputDir, chatId) {
  try {
    // Extract filename from URL
    const urlParts = videoUrl.split('/');
    const fileName = urlParts[urlParts.length - 1];
    const baseName = path.parse(fileName).name;
    
    // Download video temporarily
    const tempDir = path.join(outputDir, 'temp');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    
    const tempVideoPath = path.join(tempDir, fileName);
    
    // Download the video
    const https = require('https');
    const file = fs.createWriteStream(tempVideoPath);
    
    await new Promise((resolve, reject) => {
      https.get(videoUrl, (response) => {
        response.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      }).on('error', reject);
    });
    
    // Generate thumbnail
    const thumbnailPath = await generateVideoThumbnail(tempVideoPath, outputDir, baseName);
    
    // Clean up temp file
    fs.unlinkSync(tempVideoPath);
    
    return thumbnailPath;
  } catch (error) {
    console.error('Error generating thumbnail from URL:', error);
    return null;
  }
}

module.exports = { generateVideoThumbnail, generateThumbnailFromUrl };

