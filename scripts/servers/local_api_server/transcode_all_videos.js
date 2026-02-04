// Script to transcode all existing videos to web-compatible format
// Run this once to convert all existing videos

const { MongoClient } = require('mongodb');
const path = require('path');
const fs = require('fs');
const { transcodeVideoToH264, needsTranscoding } = require('./transcode_video');
require('dotenv').config();

async function transcodeAllVideos() {
  const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017';
  const dbName = process.env.DB_NAME || 'soc-chat-app';
  const uploadsDir = path.join(__dirname, 'uploads');

  const client = new MongoClient(mongoUri);
  
  try {
    await client.connect();
    console.log('Connected to MongoDB');
    
    const db = client.db(dbName);
    const messages = await db.collection('messages')
      .find({ type: 'video' })
      .toArray();
    
    console.log(`Found ${messages.length} video messages to check`);
    
    let transcodedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    
    for (const message of messages) {
      try {
        if (!message.mediaUrl) {
          console.log(`Skipping message ${message._id}: no mediaUrl`);
          skippedCount++;
          continue;
        }
        
        // Extract file path from URL
        // URL format: https://domain.com/uploads/chat_media/chatId/filename
        const urlParts = message.mediaUrl.split('/uploads/');
        if (urlParts.length < 2) {
          console.log(`Skipping message ${message._id}: invalid URL format`);
          skippedCount++;
          continue;
        }
        
        const filePath = path.join(uploadsDir, urlParts[1]);
        
        // Check if file exists
        if (!fs.existsSync(filePath)) {
          console.log(`Skipping message ${message._id}: file not found: ${filePath}`);
          skippedCount++;
          continue;
        }
        
        // Check if already transcoded
        if (filePath.includes('transcoded_')) {
          console.log(`Skipping message ${message._id}: already transcoded`);
          skippedCount++;
          continue;
        }
        
        // Check if transcoding is needed
        const needsTranscode = await needsTranscoding(filePath);
        
        if (!needsTranscode) {
          console.log(`Skipping message ${message._id}: already in compatible format`);
          skippedCount++;
          continue;
        }
        
        console.log(`Transcoding video for message ${message._id}...`);
        
        // Generate transcoded file path
        const originalPath = path.parse(filePath);
        const transcodedPath = path.join(originalPath.dir, `transcoded_${originalPath.name}.mp4`);
        
        // Transcode the video
        const success = await transcodeVideoToH264(filePath, transcodedPath);
        
        if (success) {
          console.log(`✓ Successfully transcoded: ${originalPath.base}`);
          
          // Delete original file
          fs.unlinkSync(filePath);
          
          // Update message with new URL
          const newRelativePath = filePath.replace(uploadsDir + path.sep, '').replace(/\\/g, '/');
          const newFileName = `transcoded_${originalPath.base}`;
          const newRelativePathTranscoded = path.join(path.dirname(newRelativePath), newFileName).replace(/\\/g, '/');
          
          const baseUrl = process.env.MOBILE_BASE_URL || 'https://soc-chat-app.ngrok-free.app';
          const newMediaUrl = `${baseUrl}/uploads/${newRelativePathTranscoded}`;
          
          await db.collection('messages').updateOne(
            { _id: message._id },
            { $set: { mediaUrl: newMediaUrl } }
          );
          
          transcodedCount++;
        } else {
          console.log(`✗ Failed to transcode: ${originalPath.base}`);
          errorCount++;
        }
      } catch (error) {
        console.error(`Error processing message ${message._id}:`, error.message);
        errorCount++;
      }
    }
    
    console.log('\n=== Transcoding Summary ===');
    console.log(`Total videos: ${messages.length}`);
    console.log(`Transcoded: ${transcodedCount}`);
    console.log(`Skipped: ${skippedCount}`);
    console.log(`Errors: ${errorCount}`);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.close();
  }
}

// Run the script
transcodeAllVideos();

