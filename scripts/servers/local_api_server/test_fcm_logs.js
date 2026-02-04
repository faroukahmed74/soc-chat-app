// Check server logs for FCM token registration attempts
// This helps debug if requests are reaching the server

const { MongoClient } = require('mongodb');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc-chat-app';

async function checkFCMLogs() {
  console.log('\n🔍 Checking FCM Token Registration Status\n');
  console.log('='.repeat(60));
  
  let client;
  try {
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    const db = client.db();
    
    // Check users collection
    const users = await db.collection('users').find({}).toArray();
    console.log(`\n📊 Total users in database: ${users.length}`);
    
    // Check users with FCM tokens
    const usersWithTokens = users.filter(u => u.fcmToken && u.fcmToken.trim());
    console.log(`📱 Users with FCM tokens: ${usersWithTokens.length}`);
    
    // Check users without tokens
    const usersWithoutTokens = users.filter(u => !u.fcmToken || !u.fcmToken.trim());
    console.log(`❌ Users without FCM tokens: ${usersWithoutTokens.length}`);
    
    if (usersWithoutTokens.length > 0) {
      console.log('\n👤 Users without FCM tokens:');
      usersWithoutTokens.slice(0, 10).forEach((user, i) => {
        console.log(`   ${i + 1}. ${user.email || user.name || user._id} (ID: ${user._id})`);
      });
      if (usersWithoutTokens.length > 10) {
        console.log(`   ... and ${usersWithoutTokens.length - 10} more`);
      }
    }
    
    // Check recent user activity
    console.log('\n📅 Recent user activity (last 24 hours):');
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentUsers = users.filter(u => 
      u.lastSeen && new Date(u.lastSeen) > oneDayAgo ||
      u.updatedAt && new Date(u.updatedAt) > oneDayAgo
    );
    console.log(`   Active users: ${recentUsers.length}`);
    
    if (recentUsers.length > 0 && usersWithTokens.length === 0) {
      console.log('\n⚠️  WARNING: Users are active but no FCM tokens registered!');
      console.log('   This suggests:');
      console.log('   1. App is not sending tokens to server');
      console.log('   2. Firebase not initialized in app');
      console.log('   3. Network/authentication issues');
      console.log('   4. FCM service not being called after login');
    }
    
    console.log('\n💡 Next steps:');
    console.log('   1. Check app logs for FCM-related errors');
    console.log('   2. Verify Firebase is initialized in app');
    console.log('   3. Check server logs for POST /api/users/fcm-token requests');
    console.log('   4. Verify app can reach server URL');
    console.log('   5. Check authentication token is valid');
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

checkFCMLogs();

