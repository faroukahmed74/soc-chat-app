// Test script to send a test FCM notification to a specific user
// Usage: node test_send_notification.js [userId] [email]

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

async function sendTestNotification() {
  const userIdArg = process.argv[2];
  const emailArg = process.argv[3];
  
  let client;
  try {
    // Connect to MongoDB
    console.log('\n🔗 Connecting to MongoDB...');
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    const db = client.db('soc_chat_app');
    console.log('✅ Connected to MongoDB\n');

    // Find user
    let user;
    if (userIdArg) {
      if (!ObjectId.isValid(userIdArg)) {
        console.error('❌ Invalid user ID format');
        process.exit(1);
      }
      user = await db.collection('users').findOne({ _id: new ObjectId(userIdArg) });
    } else if (emailArg) {
      user = await db.collection('users').findOne({ email: emailArg });
    } else {
      // Default: farouk@soc.com
      user = await db.collection('users').findOne({ email: 'farouk@soc.com' });
    }

    if (!user) {
      console.error('❌ User not found');
      process.exit(1);
    }

    console.log('👤 User found:');
    console.log(`   Name: ${user.name || 'N/A'}`);
    console.log(`   Email: ${user.email || 'N/A'}`);
    console.log(`   ID: ${user._id}`);
    console.log(`   FCM Token: ${user.fcmToken ? '✅ Present' : '❌ Missing'}`);
    console.log(`   Platform: ${user.fcmPlatform || 'unknown'}\n`);

    if (!user.fcmToken || !user.fcmToken.trim()) {
      console.error('❌ User does not have an FCM token registered');
      process.exit(1);
    }

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

    // Prepare test notification
    const testTitle = '🧪 Test Notification';
    const testBody = `This is a test notification sent at ${new Date().toLocaleString()}`;
    const testData = {
      chatId: 'test_chat_id',
      senderId: 'test_sender_id',
      senderName: 'Test Sender',
      messageType: 'text',
      messageId: 'test_message_id',
      type: 'chat_message',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      sound: 'default',
    };

    console.log('📤 Sending test notification...');
    console.log(`   Title: ${testTitle}`);
    console.log(`   Body: ${testBody}`);
    console.log(`   Token: ${user.fcmToken.substring(0, 30)}...`);
    console.log(`   Platform: ${user.fcmPlatform || 'unknown'}\n`);

    // Prepare FCM message
    const message = {
      token: user.fcmToken,
      notification: {
        title: testTitle,
        body: testBody,
      },
      data: testData,
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

    // Send notification
    try {
      const response = await admin.messaging().send(message);
      console.log('✅ Test notification sent successfully!');
      console.log(`   Response: ${response}`);
      console.log('\n📱 The user should see a notification on their device.');
      console.log('   If the app is open, it will appear as a banner.');
      console.log('   If the app is closed, it will appear in the notification tray.');
      console.log('   Tapping the notification should open the app.\n');
    } catch (error) {
      console.error('❌ Failed to send notification:');
      console.error(`   Error: ${error.message}`);
      if (error.code) {
        console.error(`   Code: ${error.code}`);
      }
      if (error.errorInfo) {
        console.error(`   Details: ${JSON.stringify(error.errorInfo, null, 2)}`);
      }
      process.exit(1);
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

sendTestNotification();

