// Quick FCM Token Query Script
// Usage: node query_fcm_tokens.js [options]
// Options:
//   --export    Export tokens to JSON file
//   --platform  Filter by platform (ios, android, web)
//   --active    Show only active tokens (updated in last 5 minutes)
//   --all       Show all users, even without tokens

require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');
const fs = require('fs');
const path = require('path');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc-chat-app';

// Parse command line arguments
const args = process.argv.slice(2);
const exportToFile = args.includes('--export');
const platformFilter = args.find(arg => arg.startsWith('--platform='))?.split('=')[1];
const activeOnly = args.includes('--active');
const showAll = args.includes('--all');

async function queryFCMTokens() {
  let client;
  
  try {
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    const db = client.db();
    
    // Build query
    let query = {};
    
    if (!showAll) {
      query.fcmToken = { $exists: true, $ne: '' };
    }
    
    if (platformFilter) {
      query.fcmPlatform = platformFilter;
    }
    
    // Get users
    const users = await db.collection('users').find(query).toArray();
    
    if (users.length === 0) {
      console.log('No users found matching criteria.');
      return;
    }
    
    // Filter active tokens if requested
    let filteredUsers = users;
    if (activeOnly && !showAll) {
      filteredUsers = users.filter(user => {
        if (!user.fcmTokenUpdatedAt) return false;
        const tokenAge = (Date.now() - new Date(user.fcmTokenUpdatedAt).getTime()) / 1000 / 60;
        return tokenAge < 5;
      });
    }
    
    // Prepare output data
    const outputData = filteredUsers.map(user => {
      const tokenAge = user.fcmTokenUpdatedAt 
        ? (Date.now() - new Date(user.fcmTokenUpdatedAt).getTime()) / 1000 / 60
        : null;
      
      return {
        userId: user._id.toString(),
        email: user.email || null,
        displayName: user.displayName || user.name || null,
        platform: user.fcmPlatform || null,
        fcmToken: user.fcmToken || null,
        tokenLength: user.fcmToken ? user.fcmToken.length : null,
        tokenUpdatedAt: user.fcmTokenUpdatedAt ? new Date(user.fcmTokenUpdatedAt).toISOString() : null,
        tokenAgeMinutes: tokenAge ? Math.round(tokenAge) : null,
        isActive: tokenAge !== null && tokenAge < 5,
        createdAt: user.createdAt ? new Date(user.createdAt).toISOString() : null,
        lastSeen: user.lastSeen ? new Date(user.lastSeen).toISOString() : null,
      };
    });
    
    // Display results
    console.log('\n📱 FCM Token Query Results\n');
    console.log('='.repeat(80));
    console.log(`Found ${filteredUsers.length} user(s)\n`);
    
    filteredUsers.forEach((user, index) => {
      console.log(`${index + 1}. User: ${user._id}`);
      if (user.email) console.log(`   Email: ${user.email}`);
      if (user.displayName || user.name) console.log(`   Name: ${user.displayName || user.name}`);
      if (user.fcmToken) {
        console.log(`   Token: ${user.fcmToken}`);
        console.log(`   Platform: ${user.fcmPlatform || 'unknown'}`);
        if (user.fcmTokenUpdatedAt) {
          const age = (Date.now() - new Date(user.fcmTokenUpdatedAt).getTime()) / 1000 / 60;
          console.log(`   Updated: ${new Date(user.fcmTokenUpdatedAt).toLocaleString()} (${Math.round(age)} min ago)`);
        }
      } else {
        console.log(`   ⚠️  No FCM token`);
      }
      console.log('');
    });
    
    // Export to file if requested
    if (exportToFile) {
      const exportPath = path.join(__dirname, `fcm_tokens_export_${Date.now()}.json`);
      fs.writeFileSync(exportPath, JSON.stringify(outputData, null, 2));
      console.log(`\n✅ Exported to: ${exportPath}`);
    }
    
    // Statistics
    const withTokens = filteredUsers.filter(u => u.fcmToken).length;
    const platforms = {};
    filteredUsers.forEach(user => {
      if (user.fcmToken) {
        const platform = user.fcmPlatform || 'unknown';
        platforms[platform] = (platforms[platform] || 0) + 1;
      }
    });
    
    console.log('\n📊 Statistics:');
    console.log(`   Total users: ${filteredUsers.length}`);
    console.log(`   With tokens: ${withTokens}`);
    console.log(`   Without tokens: ${filteredUsers.length - withTokens}`);
    if (Object.keys(platforms).length > 0) {
      console.log('\n   By platform:');
      Object.entries(platforms).forEach(([platform, count]) => {
        console.log(`      ${platform}: ${count}`);
      });
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

queryFCMTokens();

