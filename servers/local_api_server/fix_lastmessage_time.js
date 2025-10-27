// Fix script to add lastMessageTime to existing chats that don't have it
const { MongoClient, ObjectId } = require('mongodb');

async function fixLastMessageTime() {
  const client = new MongoClient(process.env.MONGODB_URI || 'mongodb://localhost:27017/soc_chat_app');
  
  try {
    await client.connect();
    console.log('Connected to MongoDB');
    
    const db = client.db();
    const chatsCollection = db.collection('chats');
    
    // Find chats without lastMessageTime
    const chats = await chatsCollection.find({ 
      $or: [
        { lastMessageTime: { $exists: false } },
        { lastMessageTime: null }
      ]
    }).toArray();
    
    console.log(`Found ${chats.length} chats without lastMessageTime`);
    
    let updated = 0;
    for (const chat of chats) {
      if (chat.lastMessage && chat.lastMessage.createdAt) {
        await chatsCollection.updateOne(
          { _id: chat._id },
          { $set: { lastMessageTime: chat.lastMessage.createdAt } }
        );
        updated++;
        console.log(`Updated chat ${chat._id} with lastMessageTime: ${chat.lastMessage.createdAt}`);
      } else if (chat.updatedAt) {
        // Use updatedAt if there's no lastMessage
        await chatsCollection.updateOne(
          { _id: chat._id },
          { $set: { lastMessageTime: chat.updatedAt } }
        );
        updated++;
        console.log(`Updated chat ${chat._id} with updatedAt as lastMessageTime`);
      }
    }
    
    console.log(`\n✅ Updated ${updated} chats with lastMessageTime`);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.close();
  }
}

fixLastMessageTime();

