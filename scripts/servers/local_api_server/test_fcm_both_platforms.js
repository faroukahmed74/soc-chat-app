// Test FCM notifications on both Android and iOS platforms
// Usage: node test_fcm_both_platforms.js

const { MongoClient, ObjectId } = require('mongodb');
const path = require('path');
const fs = require('fs');

// Firebase Admin SDK
let admin;
try {
  admin = require('firebase-admin');
} catch (e) {
  console.error('❌ firebase-admin not available:', e.message);
  process.exit(1);
}

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/soc_chat_app';

async function testFCMBothPlatforms() {
  let client;
  try {
    // Connect to MongoDB
    console.log('\n🔗 Connecting to MongoDB...');
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    const db = client.db('soc_chat_app');
    console.log('✅ Connected to MongoDB\n');

    // Initialize Firebase Admin SDK
    if (!admin.apps.length) {
      console.log('🔧 Initializing Firebase Admin SDK...');
      const NODE_ENV = process.env.NODE_ENV || 'development';
      let serviceAccount;

      if (NODE_ENV === 'production') {
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

        if (!serviceAccountPath) {
          console.error('❌ Firebase service account file not found');
          console.error('   Tried paths:');
          possiblePaths.forEach(p => console.error(`     - ${p}`));
          process.exit(1);
        }

        console.log(`   Using service account: ${serviceAccountPath}`);
        serviceAccount = require(serviceAccountPath);
      }

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log('✅ Firebase Admin SDK initialized\n');
    }

    // Find users with FCM tokens
    console.log('📱 Finding users with FCM tokens...\n');
    const usersWithTokens = await db.collection('users').find({
      fcmToken: { $exists: true, $ne: '' },
      fcmToken: { $ne: null }
    }).toArray();

    if (usersWithTokens.length === 0) {
      console.log('⚠️  No users with FCM tokens found');
      console.log('   Users need to log in to the app to register FCM tokens.\n');
      process.exit(0);
    }

    // Group users by platform
    const androidUsers = usersWithTokens.filter(u => u.fcmPlatform === 'android');
    const iosUsers = usersWithTokens.filter(u => u.fcmPlatform === 'ios');
    const webUsers = usersWithTokens.filter(u => u.fcmPlatform === 'web');
    const unknownUsers = usersWithTokens.filter(u => !u.fcmPlatform || u.fcmPlatform === 'unknown');

    console.log('📊 FCM Token Summary:');
    console.log(`   Total users with tokens: ${usersWithTokens.length}`);
    console.log(`   Android: ${androidUsers.length}`);
    console.log(`   iOS: ${iosUsers.length}`);
    console.log(`   Web: ${webUsers.length}`);
    console.log(`   Unknown: ${unknownUsers.length}\n`);

    // Test results
    const results = {
      android: { total: androidUsers.length, success: 0, failed: 0, errors: [] },
      ios: { total: iosUsers.length, success: 0, failed: 0, errors: [] },
      web: { total: webUsers.length, success: 0, failed: 0, errors: [] },
    };

    // Test Android users
    if (androidUsers.length > 0) {
      console.log('🤖 Testing Android Notifications...');
      console.log('='.repeat(60));
      for (const user of androidUsers) {
        const testTitle = '🧪 Android Test Notification';
        const testBody = `Testing Android FCM - ${new Date().toLocaleString()}`;
        
        try {
          const message = {
            token: user.fcmToken,
            notification: {
              title: testTitle,
              body: testBody,
            },
            data: {
              chatId: 'test_chat',
              senderId: 'test_sender',
              senderName: 'Test Sender',
              messageType: 'text',
              type: 'chat_message',
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'chat_notifications',
                priority: 'high',
                defaultSound: true,
                icon: '@mipmap/ic_launcher',
                color: '#2196F3',
              },
            },
          };

          const response = await admin.messaging().send(message);
          console.log(`✅ ${user.name || user.email} (${user._id})`);
          console.log(`   Token: ${user.fcmToken.substring(0, 30)}...`);
          console.log(`   Response: ${response}\n`);
          results.android.success++;
        } catch (error) {
          console.log(`❌ ${user.name || user.email} (${user._id})`);
          console.log(`   Error: ${error.message}`);
          if (error.code) {
            console.log(`   Code: ${error.code}`);
          }
          console.log('');
          results.android.failed++;
          results.android.errors.push({
            user: user.name || user.email,
            userId: user._id,
            error: error.message,
            code: error.code,
          });

          // Remove invalid tokens
          if (error.code === 'messaging/invalid-registration-token' || 
              error.code === 'messaging/registration-token-not-registered') {
            console.log(`   ⚠️  Removing invalid token from database...`);
            await db.collection('users').updateOne(
              { _id: user._id },
              { 
                $set: { 
                  fcmToken: '',
                  fcmPlatform: '',
                  fcmTokenUpdatedAt: new Date(),
                }
              }
            );
          }
        }
      }
    }

    // Test iOS users
    if (iosUsers.length > 0) {
      console.log('\n🍎 Testing iOS Notifications...');
      console.log('='.repeat(60));
      for (const user of iosUsers) {
        const testTitle = '🧪 iOS Test Notification';
        const testBody = `Testing iOS FCM - ${new Date().toLocaleString()}`;
        
        try {
          const message = {
            token: user.fcmToken,
            notification: {
              title: testTitle,
              body: testBody,
            },
            data: {
              chatId: 'test_chat',
              senderId: 'test_sender',
              senderName: 'Test Sender',
              messageType: 'text',
              type: 'chat_message',
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  category: 'default',
                },
              },
              headers: {
                'apns-priority': '10',
              },
            },
          };

          const response = await admin.messaging().send(message);
          console.log(`✅ ${user.name || user.email} (${user._id})`);
          console.log(`   Token: ${user.fcmToken.substring(0, 30)}...`);
          console.log(`   Response: ${response}\n`);
          results.ios.success++;
        } catch (error) {
          console.log(`❌ ${user.name || user.email} (${user._id})`);
          console.log(`   Error: ${error.message}`);
          if (error.code) {
            console.log(`   Code: ${error.code}`);
          }
          console.log('');
          results.ios.failed++;
          results.ios.errors.push({
            user: user.name || user.email,
            userId: user._id,
            error: error.message,
            code: error.code,
          });

          // Remove invalid tokens
          if (error.code === 'messaging/invalid-registration-token' || 
              error.code === 'messaging/registration-token-not-registered') {
            console.log(`   ⚠️  Removing invalid token from database...`);
            await db.collection('users').updateOne(
              { _id: user._id },
              { 
                $set: { 
                  fcmToken: '',
                  fcmPlatform: '',
                  fcmTokenUpdatedAt: new Date(),
                }
              }
            );
          }
        }
      }
    }

    // Test Web users (if any)
    if (webUsers.length > 0) {
      console.log('\n🌐 Testing Web Notifications...');
      console.log('='.repeat(60));
      for (const user of webUsers) {
        const testTitle = '🧪 Web Test Notification';
        const testBody = `Testing Web FCM - ${new Date().toLocaleString()}`;
        
        try {
          const message = {
            token: user.fcmToken,
            notification: {
              title: testTitle,
              body: testBody,
            },
            data: {
              chatId: 'test_chat',
              senderId: 'test_sender',
              senderName: 'Test Sender',
              messageType: 'text',
              type: 'chat_message',
            },
            webpush: {
              headers: {
                'Urgency': 'high',
              },
              notification: {
                icon: '/icon-192x192.png',
                badge: '/badge-72x72.png',
              },
            },
          };

          const response = await admin.messaging().send(message);
          console.log(`✅ ${user.name || user.email} (${user._id})`);
          console.log(`   Token: ${user.fcmToken.substring(0, 30)}...`);
          console.log(`   Response: ${response}\n`);
          results.web.success++;
        } catch (error) {
          console.log(`❌ ${user.name || user.email} (${user._id})`);
          console.log(`   Error: ${error.message}`);
          if (error.code) {
            console.log(`   Code: ${error.code}`);
          }
          console.log('');
          results.web.failed++;
          results.web.errors.push({
            user: user.name || user.email,
            userId: user._id,
            error: error.message,
            code: error.code,
          });
        }
      }
    }

    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 TEST RESULTS SUMMARY');
    console.log('='.repeat(60));
    
    if (androidUsers.length > 0) {
      console.log(`\n🤖 Android:`);
      console.log(`   Total: ${results.android.total}`);
      console.log(`   ✅ Success: ${results.android.success}`);
      console.log(`   ❌ Failed: ${results.android.failed}`);
      if (results.android.errors.length > 0) {
        console.log(`   Errors:`);
        results.android.errors.forEach(err => {
          console.log(`     - ${err.user}: ${err.error} (${err.code || 'N/A'})`);
        });
      }
    }

    if (iosUsers.length > 0) {
      console.log(`\n🍎 iOS:`);
      console.log(`   Total: ${results.ios.total}`);
      console.log(`   ✅ Success: ${results.ios.success}`);
      console.log(`   ❌ Failed: ${results.ios.failed}`);
      if (results.ios.errors.length > 0) {
        console.log(`   Errors:`);
        results.ios.errors.forEach(err => {
          console.log(`     - ${err.user}: ${err.error} (${err.code || 'N/A'})`);
        });
      }
    }

    if (webUsers.length > 0) {
      console.log(`\n🌐 Web:`);
      console.log(`   Total: ${results.web.total}`);
      console.log(`   ✅ Success: ${results.web.success}`);
      console.log(`   ❌ Failed: ${results.web.failed}`);
      if (results.web.errors.length > 0) {
        console.log(`   Errors:`);
        results.web.errors.forEach(err => {
          console.log(`     - ${err.user}: ${err.error} (${err.code || 'N/A'})`);
        });
      }
    }

    // Overall status
    console.log('\n' + '='.repeat(60));
    const totalSuccess = results.android.success + results.ios.success + results.web.success;
    const totalFailed = results.android.failed + results.ios.failed + results.web.failed;
    const total = totalSuccess + totalFailed;

    if (total === 0) {
      console.log('⚠️  No users with FCM tokens found');
      console.log('   Users need to log in to register FCM tokens.\n');
    } else if (totalFailed === 0) {
      console.log(`✅ ALL TESTS PASSED! (${totalSuccess}/${total} notifications sent successfully)`);
    } else {
      console.log(`⚠️  PARTIAL SUCCESS: ${totalSuccess}/${total} notifications sent successfully`);
      console.log(`   ${totalFailed} failed - check errors above\n`);
    }

    console.log('='.repeat(60) + '\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

testFCMBothPlatforms();

