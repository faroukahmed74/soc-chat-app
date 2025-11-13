// Check existing users in MongoDB
const { MongoClient } = require('mongodb');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc_chat_app';

async function checkUsers() {
  let client;
  try {
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    const db = client.db('soc_chat_app');
    
    const users = await db.collection('users').find({}).toArray();
    
    console.log(`\n📊 Total users in database: ${users.length}\n`);
    
    if (users.length === 0) {
      console.log('⚠️  No users found in database');
      console.log('   Database name: soc_chat_app');
      console.log('   Collection: users');
      return;
    }
    
    console.log('👤 Users in database:');
    users.forEach((user, index) => {
      const email = user.email || 'No email';
      const name = user.name || user.displayName || 'No name';
      const hasToken = user.fcmToken && user.fcmToken.trim() ? '✅' : '❌';
      const platform = user.fcmPlatform || 'N/A';
      const lastSeen = user.lastSeen ? new Date(user.lastSeen).toLocaleString() : 'Never';
      
      console.log(`\n   ${index + 1}. ${name} (${email})`);
      console.log(`      ID: ${user._id}`);
      console.log(`      FCM Token: ${hasToken} ${platform}`);
      console.log(`      Last Seen: ${lastSeen}`);
    });
    
    const usersWithTokens = users.filter(u => u.fcmToken && u.fcmToken.trim());
    const usersWithoutTokens = users.filter(u => !u.fcmToken || !u.fcmToken.trim());
    
    console.log(`\n📊 Summary:`);
    console.log(`   Total users: ${users.length}`);
    console.log(`   With FCM tokens: ${usersWithTokens.length}`);
    console.log(`   Without FCM tokens: ${usersWithoutTokens.length}`);
    
    if (usersWithoutTokens.length > 0) {
      console.log(`\n💡 Solution:`);
      console.log(`   Existing users just need to LOG IN again (no need to register)`);
      console.log(`   After login, FCM tokens will be automatically registered`);
      console.log(`   Make sure the app is rebuilt with the latest FCM service changes`);
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

checkUsers();

