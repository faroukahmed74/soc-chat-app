// Video transcoding utility using ffmpeg
// Converts videos to web-compatible H.264 format

const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');

const execAsync = promisify(exec);

/**
 * Check if ffmpeg is available
 */
async function checkFFmpegAvailable() {
  try {
    await execAsync('ffmpeg -version');
    return true;
  } catch (err) {
    console.warn('ffmpeg not found. Video transcoding will be disabled.');
    return false;
  }
}

/**
 * Transcode video to web-compatible H.264 format
 * @param {string} inputPath - Path to input video file
 * @param {string} outputPath - Path to output video file
 * @returns {Promise<boolean>} - True if successful, false otherwise
 */
async function transcodeVideoToH264(inputPath, outputPath) {
  try {
    // Check if ffmpeg is available
    const ffmpegAvailable = await checkFFmpegAvailable();
    if (!ffmpegAvailable) {
      console.warn('Cannot transcode video: ffmpeg not available');
      return false;
    }

    console.log(`Transcoding video: ${inputPath} -> ${outputPath}`);

    // Create output directory if it doesn't exist
    const outputDir = path.dirname(outputPath);
    await fs.mkdir(outputDir, { recursive: true });

    // Transcode command using ffmpeg
    // Preset: ultrafast for quick processing
    // Codec: libx264 (H.264) for maximum browser compatibility
    // CRF: 23 for good quality/compression balance
    const command = `ffmpeg -i "${inputPath}" ` +
      `-c:v libx264 -preset ultrafast -crf 23 ` +
      `-c:a aac -b:a 128k ` +
      `-movflags +faststart ` + // Enable streaming
      `-pix_fmt yuv420p ` + // Ensure compatibility
      `"${outputPath}"`;

    const { stdout, stderr } = await execAsync(command);
    
    console.log(`Video transcoding complete: ${outputPath}`);
    return true;
  } catch (error) {
    console.error('Error transcoding video:', error.message);
    if (error.stdout) console.log('ffmpeg stdout:', error.stdout);
    if (error.stderr) console.log('ffmpeg stderr:', error.stderr);
    return false;
  }
}

/**
 * Get video metadata using ffprobe
 * @param {string} videoPath - Path to video file
 * @returns {Promise<{duration, width, height, codec}>}
 */
async function getVideoMetadata(videoPath) {
  try {
    const command = `ffprobe -v quiet -print_format json -show_format -show_streams "${videoPath}"`;
    const { stdout } = await execAsync(command);
    const metadata = JSON.parse(stdout);

    let videoStream = metadata.streams.find(s => s.codec_type === 'video');
    
    return {
      duration: parseFloat(metadata.format.duration),
      width: videoStream.width,
      height: videoStream.height,
      codec: videoStream.codec_name,
      bitrate: videoStream.bit_rate ? parseInt(videoStream.bit_rate) : null,
    };
  } catch (error) {
    console.error('Error getting video metadata:', error.message);
    return null;
  }
}

/**
 * Check if video needs transcoding based on codec
 * @param {string} videoPath - Path to video file
 * @returns {Promise<boolean>} - True if video needs transcoding
 */
async function needsTranscoding(videoPath) {
  try {
    const metadata = await getVideoMetadata(videoPath);
    if (!metadata) return true;

    // Common unsupported codecs: hevc (H.265), vp9, etc.
    // Common supported codecs: h264, vp8
    const codec = metadata.codec ? metadata.codec.toLowerCase() : '';
    const unsupportedCodecs = [
      'hevc',
      'h265',
      'hvc1',
      'hev1',
      'av01',
      'av1',
      'vp9',
      'vp90',
    ];
    const needsTransform = unsupportedCodecs.includes(codec);
    
    if (needsTransform) {
      console.log(`Video needs transcoding: codec=${metadata.codec}`);
    }
    
    return needsTransform;
  } catch (error) {
    console.error('Error checking if video needs transcoding:', error.message);
    // If we can't check, assume it needs transcoding for safety
    return true;
  }
}

module.exports = {
  transcodeVideoToH264,
  getVideoMetadata,
  needsTranscoding,
  checkFFmpegAvailable,
};

