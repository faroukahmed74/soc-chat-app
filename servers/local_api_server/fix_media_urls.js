// Fix Media URLs Migration Script
// This script updates old localhost URLs to use the ngrok URL so all platforms can access media

require('dotenv').config();
const { MongoClient } = require('mongodb');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc_chat_app';
const OLD_BASE_URL = 'http://localhost:3003';
const NEW_BASE_URL = process.env.MOBILE_BASE_URL || 'https://soc-chat-app.ngrok-free.app';

async function fixMediaUrls() {
  const client = new MongoClient(MONGODB_URI);
  
  try {
    await client.connect();
    console.log('✅ Connected to MongoDB');
    
    const db = client.db();
    const messagesCollection = db.collection('messages');
    
    // Find all messages with localhost media URLs
    const messagesWithLocalhost = await messagesCollection.find({
      mediaUrl: { $regex: 'localhost' }
    }).toArray();
    
    console.log(`\n📊 Found ${messagesWithLocalhost.length} messages with localhost URLs`);
    
    if (messagesWithLocalhost.length === 0) {
      console.log('✅ No media URLs need updating');
      return;
    }
    
    // Show some examples
    console.log('\n📝 Examples of old URLs:');
    messagesWithLocalhost.slice(0, 3).forEach(msg => {
      console.log(`   - ${msg.mediaUrl}`);
    });
    
    // Update all messages
    let updated = 0;
    let failed = 0;
    
    for (const message of messagesWithLocalhost) {
      try {
        const newUrl = message.mediaUrl.replace(OLD_BASE_URL, NEW_BASE_URL);
        
        await messagesCollection.updateOne(
          { _id: message._id },
          { $set: { mediaUrl: newUrl } }
        );
        
        updated++;
        
        if (updated % 10 === 0) {
          console.log(`   Updated ${updated}/${messagesWithLocalhost.length}...`);
        }
      } catch (error) {
        console.error(`   Error updating message ${message._id}:`, error.message);
        failed++;
      }
    }
    
    console.log('\n✅ Migration complete!');
    console.log(`   ✅ Successfully updated: ${updated}`);
    console.log(`   ❌ Failed: ${failed}`);
    
    // Show some examples of new URLs
    const sampleMessages = await messagesCollection.find({
      mediaUrl: { $regex: 'ngrok' }
    }).limit(3).toArray();
    
    console.log('\n📝 Examples of new URLs:');
    sampleMessages.forEach(msg => {
      console.log(`   - ${msg.mediaUrl}`);
    });
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await client.close();
    console.log('\n✅ Connection closed');
  }
}

// Run the migration
fixMediaUrls()
  .then(() => {
    console.log('\n🎉 All done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  });
