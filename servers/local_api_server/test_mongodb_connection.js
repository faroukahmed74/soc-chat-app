// Test MongoDB Connection and API Routes
const { MongoClient } = require('mongodb');

async function testMongoDBConnection() {
  console.log('🔍 Testing MongoDB Connection...');
  
  const mongoURI = 'mongodb://localhost:27017/soc_chat_app';
  const client = new MongoClient(mongoURI);
  
  try {
    // Test connection
    await client.connect();
    console.log('✅ MongoDB connection successful');
    
    // Test database access
    const db = client.db('soc_chat_app');
    const collections = await db.listCollections().toArray();
    console.log('✅ Database access successful');
    console.log('📋 Available collections:', collections.map(c => c.name));
    
    // Test users collection
    const usersCollection = db.collection('users');
    const userCount = await usersCollection.countDocuments();
    console.log(`👥 Users in database: ${userCount}`);
    
    if (userCount > 0) {
      const sampleUsers = await usersCollection.find({}).limit(3).toArray();
      console.log('📝 Sample users:');
      sampleUsers.forEach(user => {
        console.log(`   - ${user.email} (${user.name}) - Role: ${user.role || 'user'}`);
      });
    }
    
    // Test chats collection
    const chatsCollection = db.collection('chats');
    const chatCount = await chatsCollection.countDocuments();
    console.log(`💬 Chats in database: ${chatCount}`);
    
    // Test messages collection
    const messagesCollection = db.collection('messages');
    const messageCount = await messagesCollection.countDocuments();
    console.log(`📨 Messages in database: ${messageCount}`);
    
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error.message);
  } finally {
    await client.close();
  }
}

// Run the test
testMongoDBConnection();
