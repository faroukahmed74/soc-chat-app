// FCM Diagnostic Script
// Run this to check FCM configuration and status

require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');
const path = require('path');
const fs = require('fs');

let admin;
try {
  admin = require('firebase-admin');
} catch (e) {
  console.error('❌ firebase-admin package not installed:', e.message);
  process.exit(1);
}

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc-chat-app';
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'soc-chat-app-ca57e';

async function diagnoseFCM() {
  console.log('\n🔍 FCM Diagnostic Tool\n');
  console.log('='.repeat(60));
  
  // 1. Check Firebase Admin SDK initialization
  console.log('\n1️⃣ Checking Firebase Admin SDK...');
  let firebaseInitialized = false;
  
  if (admin && admin.apps.length > 0) {
    console.log('   ✅ Firebase Admin SDK is initialized');
    console.log('   📦 Apps:', admin.apps.length);
    firebaseInitialized = true;
  } else {
    console.log('   ❌ Firebase Admin SDK is NOT initialized');
    console.log('   🔧 Attempting to initialize...');
    
    try {
      const NODE_ENV = process.env.NODE_ENV || 'development';
      let serviceAccount;
      
      if (NODE_ENV === 'production') {
        // Use environment variables
        serviceAccount = {
          type: process.env.FIREBASE_TYPE,
          project_id: process.env.FIREBASE_PROJECT_ID,
          private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
          private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
          client_email: process.env.FIREBASE_CLIENT_EMAIL,
          client_id: process.env.FIREBASE_CLIENT_ID,
          auth_uri: process.env.FIREBASE_AUTH_URI,
          token_uri: process.env.FIREBASE_TOKEN_URI,
          auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL,
          client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
        };
        
        if (!serviceAccount.project_id) {
          throw new Error('Firebase environment variables not set');
        }
      } else {
        // Try to load service account file
          const possiblePaths = [
            path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'),
            path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-bc21fed17ba4.json'),
            path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-ebf6280fb64f.json'),
            path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'),
            path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-bc21fed17ba4.json'),
            path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-ebf6280fb64f.json'),
          ];
        
        let serviceAccountPath = null;
        for (const p of possiblePaths) {
          if (fs.existsSync(p)) {
            serviceAccountPath = p;
            break;
          }
        }
        
        if (serviceAccountPath) {
          console.log('   📄 Found service account file:', serviceAccountPath);
          serviceAccount = require(serviceAccountPath);
        } else {
          console.log('   ❌ Service account file not found in any of these locations:');
          possiblePaths.forEach(p => console.log('      -', p));
          throw new Error('Service account file not found');
        }
      }
      
      if (serviceAccount) {
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: FIREBASE_PROJECT_ID,
        });
        console.log('   ✅ Firebase Admin SDK initialized successfully');
        firebaseInitialized = true;
      }
    } catch (error) {
      console.log('   ❌ Failed to initialize Firebase Admin SDK:', error.message);
      console.log('\n   💡 Solutions:');
      console.log('      1. Place Firebase service account JSON file in one of the paths above');
      console.log('      2. Or set FIREBASE_* environment variables for production');
    }
  }
  
  // 2. Check MongoDB connection
  console.log('\n2️⃣ Checking MongoDB connection...');
  let db = null;
  try {
    const client = new MongoClient(MONGODB_URI);
    await client.connect();
    db = client.db();
    await db.admin().ping();
    console.log('   ✅ MongoDB connected successfully');
    console.log('   📍 URI:', MONGODB_URI.replace(/\/\/.*@/, '//***:***@'));
  } catch (error) {
    console.log('   ❌ MongoDB connection failed:', error.message);
    console.log('\n   💡 Solutions:');
    console.log('      1. Make sure MongoDB is running');
    console.log('      2. Check MONGODB_URI environment variable');
    return;
  }
  
  // 3. Check FCM tokens in database
  console.log('\n3️⃣ Checking FCM tokens in database...');
  try {
    const usersWithTokens = await db.collection('users').find({
      fcmToken: { $exists: true, $ne: '' }
    }).toArray();
    
    console.log(`   📱 Found ${usersWithTokens.length} users with FCM tokens`);
    
    if (usersWithTokens.length === 0) {
      console.log('   ⚠️  No FCM tokens found in database');
      console.log('\n   💡 Solutions:');
      console.log('      1. Make sure users are logged in to the app');
      console.log('      2. Check if FCM service is initialized in the app');
      console.log('      3. Verify app can reach the server at /api/users/fcm-token');
    } else {
      console.log('\n   📋 Users with FCM tokens:');
      usersWithTokens.slice(0, 5).forEach((user, index) => {
        const tokenPreview = user.fcmToken ? user.fcmToken.substring(0, 20) + '...' : 'N/A';
        const platform = user.fcmPlatform || 'unknown';
        const updated = user.fcmTokenUpdatedAt ? new Date(user.fcmTokenUpdatedAt).toLocaleString() : 'N/A';
        console.log(`      ${index + 1}. User: ${user._id}`);
        console.log(`         Token: ${tokenPreview}`);
        console.log(`         Platform: ${platform}`);
        console.log(`         Updated: ${updated}`);
      });
      
      if (usersWithTokens.length > 5) {
        console.log(`      ... and ${usersWithTokens.length - 5} more`);
      }
    }
  } catch (error) {
    console.log('   ❌ Error checking FCM tokens:', error.message);
  }
  
  // 4. Test FCM notification sending
  if (firebaseInitialized) {
    console.log('\n4️⃣ Testing FCM notification...');
    
    try {
      // Get first user with FCM token
      const testUser = await db.collection('users').findOne({
        fcmToken: { $exists: true, $ne: '' }
      });
      
      if (testUser && testUser.fcmToken) {
        console.log(`   🧪 Testing with user: ${testUser._id}`);
        console.log(`   📱 Platform: ${testUser.fcmPlatform || 'unknown'}`);
        
        const testMessage = {
          token: testUser.fcmToken,
          notification: {
            title: '🔔 FCM Test Notification',
            body: 'This is a test notification from the diagnostic tool',
          },
          data: {
            type: 'test',
            timestamp: new Date().toISOString(),
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'chat_notifications',
              priority: 'high',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };
        
        try {
          const response = await admin.messaging().send(testMessage);
          console.log('   ✅ Test notification sent successfully!');
          console.log('   📨 Message ID:', response);
          console.log('\n   💡 Check the device to see if notification was received');
        } catch (error) {
          console.log('   ❌ Failed to send test notification:', error.message);
          console.log('   📋 Error code:', error.code);
          
          if (error.code === 'messaging/invalid-registration-token') {
            console.log('\n   💡 The FCM token is invalid. The app needs to refresh its token.');
          } else if (error.code === 'messaging/registration-token-not-registered') {
            console.log('\n   💡 The FCM token is not registered. User may have uninstalled the app.');
          } else {
            console.log('\n   💡 Check Firebase Console for more details');
          }
        }
      } else {
        console.log('   ⚠️  No users with FCM tokens found to test with');
      }
    } catch (error) {
      console.log('   ❌ Error testing FCM:', error.message);
    }
  } else {
    console.log('\n4️⃣ Skipping FCM test (Firebase not initialized)');
  }
  
  // 5. Check server configuration
  console.log('\n5️⃣ Server Configuration:');
  console.log('   📍 MongoDB URI:', MONGODB_URI.replace(/\/\/.*@/, '//***:***@'));
  console.log('   🔥 Firebase Project ID:', FIREBASE_PROJECT_ID);
  console.log('   🌍 Node Environment:', process.env.NODE_ENV || 'development');
  
  // 6. Summary
  console.log('\n' + '='.repeat(60));
  console.log('\n📊 Summary:');
  console.log(`   Firebase Admin SDK: ${firebaseInitialized ? '✅ Initialized' : '❌ Not Initialized'}`);
  console.log(`   MongoDB Connection: ${db ? '✅ Connected' : '❌ Not Connected'}`);
  
  if (db) {
    try {
      const tokenCount = await db.collection('users').countDocuments({
        fcmToken: { $exists: true, $ne: '' }
      });
      console.log(`   FCM Tokens in DB: ${tokenCount > 0 ? `✅ ${tokenCount} tokens` : '❌ No tokens'}`);
    } catch (e) {
      console.log(`   FCM Tokens in DB: ❓ Could not check`);
    }
  }
  
  console.log('\n💡 Next Steps:');
  if (!firebaseInitialized) {
    console.log('   1. Fix Firebase Admin SDK initialization (see errors above)');
  }
  if (db) {
    const tokenCount = await db.collection('users').countDocuments({
      fcmToken: { $exists: true, $ne: '' }
    });
    if (tokenCount === 0) {
      console.log('   2. Ensure users log in to the app to register FCM tokens');
      console.log('   3. Check app logs for FCM token registration errors');
    }
  }
  console.log('   4. Check server logs when sending messages to see FCM notification attempts');
  console.log('   5. Verify the server is accessible from your app');
  
  console.log('\n');
  
  if (db) {
    await db.client.close();
  }
}

// Run diagnostic
diagnoseFCM().catch(error => {
  console.error('\n❌ Diagnostic failed:', error);
  process.exit(1);
});

