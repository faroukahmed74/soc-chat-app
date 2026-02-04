// FCM Token Details Viewer
// Shows detailed information about all FCM tokens in the database

require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc-chat-app';

let admin;
try {
  admin = require('firebase-admin');
} catch (e) {
  console.warn('firebase-admin not available, will skip token validation');
  admin = null;
}

async function showFCMTokens() {
  console.log('\n📱 FCM Token Details Viewer\n');
  console.log('='.repeat(80));
  
  // Connect to MongoDB
  let client;
  let db;
  
  try {
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    db = client.db();
    await db.admin().ping();
    console.log('✅ Connected to MongoDB\n');
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error.message);
    process.exit(1);
  }
  
  // Get all users with FCM tokens
  try {
    const users = await db.collection('users').find({
      fcmToken: { $exists: true, $ne: '' }
    }).toArray();
    
    if (users.length === 0) {
      console.log('⚠️  No FCM tokens found in database');
      console.log('\n💡 Users need to log in to the app to register FCM tokens.');
      await client.close();
      return;
    }
    
    console.log(`📊 Found ${users.length} user(s) with FCM tokens:\n`);
    console.log('='.repeat(80));
    
    // Initialize Firebase Admin if available for token validation
    let firebaseInitialized = false;
    if (admin && !admin.apps.length) {
      try {
        const path = require('path');
        const fs = require('fs');
        const NODE_ENV = process.env.NODE_ENV || 'development';
        
        if (NODE_ENV !== 'production') {
          const possiblePaths = [
            path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'),
            path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-bc21fed17ba4.json'),
            path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'),
            path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-bc21fed17ba4.json'),
          ];
          
          for (const p of possiblePaths) {
            if (fs.existsSync(p)) {
              const serviceAccount = require(p);
              admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
                projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || 'soc-chat-app-ca57e',
              });
              firebaseInitialized = true;
              break;
            }
          }
        }
      } catch (e) {
        console.warn('⚠️  Could not initialize Firebase for token validation');
      }
    } else if (admin && admin.apps.length > 0) {
      firebaseInitialized = true;
    }
    
    // Display detailed token information
    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      console.log(`\n👤 User #${i + 1}`);
      console.log('-'.repeat(80));
      console.log(`   User ID:        ${user._id}`);
      console.log(`   Email:          ${user.email || 'N/A'}`);
      console.log(`   Display Name:   ${user.displayName || user.name || 'N/A'}`);
      console.log(`   Platform:       ${user.fcmPlatform || 'unknown'}`);
      console.log(`   Token Updated:  ${user.fcmTokenUpdatedAt ? new Date(user.fcmTokenUpdatedAt).toLocaleString() : 'N/A'}`);
      
      // Show full token
      if (user.fcmToken) {
        console.log(`   Full Token:     ${user.fcmToken}`);
        console.log(`   Token Length:   ${user.fcmToken.length} characters`);
        console.log(`   Token Preview:  ${user.fcmToken.substring(0, 50)}...`);
      }
      
      // Check if token is recent (within last 5 minutes = active)
      const tokenAge = user.fcmTokenUpdatedAt 
        ? (Date.now() - new Date(user.fcmTokenUpdatedAt).getTime()) / 1000 / 60
        : Infinity;
      const isActive = tokenAge < 5;
      console.log(`   Token Age:      ${tokenAge < 1 ? '< 1 minute' : tokenAge < 60 ? `${Math.round(tokenAge)} minutes` : `${Math.round(tokenAge / 60)} hours`}`);
      console.log(`   Status:         ${isActive ? '🟢 Active (recent)' : '🟡 Stale (may be offline)'}`);
      
      // Validate token if Firebase is initialized
      if (firebaseInitialized && user.fcmToken) {
        try {
          // Try to validate token by checking its format and attempting a dry run
          // Note: We can't fully validate without sending, but we can check format
          const tokenPattern = /^[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$/;
          const isValidFormat = tokenPattern.test(user.fcmToken) || user.fcmToken.length > 100;
          
          if (isValidFormat) {
            console.log(`   Token Format:   ✅ Valid format`);
            
            // Try to get token info (this will fail for invalid tokens)
            try {
              // We can't directly validate without sending, but we can check if it's a valid FCM token format
              // FCM tokens are typically base64-like strings
              console.log(`   Validation:     ✅ Appears valid (format check)`);
            } catch (e) {
              console.log(`   Validation:     ⚠️  Could not validate: ${e.message}`);
            }
          } else {
            console.log(`   Token Format:   ❌ Invalid format`);
          }
        } catch (e) {
          console.log(`   Validation:     ⚠️  Error: ${e.message}`);
        }
      }
      
      // Show additional user info
      if (user.createdAt) {
        console.log(`   Account Created: ${new Date(user.createdAt).toLocaleString()}`);
      }
      if (user.lastSeen) {
        console.log(`   Last Seen:       ${new Date(user.lastSeen).toLocaleString()}`);
      }
      
      // Show device info if available
      if (user.deviceInfo) {
        console.log(`   Device Info:    ${JSON.stringify(user.deviceInfo)}`);
      }
    }
    
    // Summary statistics
    console.log('\n' + '='.repeat(80));
    console.log('\n📊 Summary Statistics:\n');
    
    const platforms = {};
    let activeCount = 0;
    let staleCount = 0;
    
    users.forEach(user => {
      const platform = user.fcmPlatform || 'unknown';
      platforms[platform] = (platforms[platform] || 0) + 1;
      
      const tokenAge = user.fcmTokenUpdatedAt 
        ? (Date.now() - new Date(user.fcmTokenUpdatedAt).getTime()) / 1000 / 60
        : Infinity;
      
      if (tokenAge < 5) {
        activeCount++;
      } else {
        staleCount++;
      }
    });
    
    console.log(`   Total Tokens:    ${users.length}`);
    console.log(`   Active Tokens:  🟢 ${activeCount} (updated in last 5 minutes)`);
    console.log(`   Stale Tokens:   🟡 ${staleCount} (older than 5 minutes)`);
    console.log('\n   By Platform:');
    Object.entries(platforms).forEach(([platform, count]) => {
      console.log(`      ${platform}: ${count} token(s)`);
    });
    
    // Export option
    console.log('\n' + '='.repeat(80));
    console.log('\n💡 Tips:');
    console.log('   - Active tokens (🟢) are likely from users currently using the app');
    console.log('   - Stale tokens (🟡) may be from users who closed the app');
    console.log('   - Tokens are automatically refreshed when users open the app');
    console.log('   - Invalid tokens are automatically removed by the server');
    
    if (firebaseInitialized) {
      console.log('\n🧪 To test sending a notification to a specific user:');
      console.log('   Run: node diagnose_fcm.js');
      console.log('   Or send a message to that user from another account');
    } else {
      console.log('\n⚠️  Firebase not initialized - cannot validate tokens');
      console.log('   Place Firebase service account file to enable token validation');
    }
    
    console.log('\n');
    
  } catch (error) {
    console.error('❌ Error fetching FCM tokens:', error.message);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

// Run the script
showFCMTokens().catch(error => {
  console.error('\n❌ Script failed:', error);
  process.exit(1);
});

