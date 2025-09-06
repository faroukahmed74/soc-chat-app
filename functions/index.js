const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Cloud Function to send FCM notification
exports.sendFCMNotification = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { token, title, body, data: notificationData } = data;

    if (!token || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: token, title, body');
    }

    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: notificationData || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_notifications',
          priority: 'high',
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            category: 'chat_category',
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent message:', response);
    return { 
      success: true, 
      messageId: response,
      message: 'Notification sent successfully' 
    };
    
  } catch (error) {
    console.error('Error sending message:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification', error.message);
  }
});

// Cloud Function to send notification to multiple users
exports.sendNotificationToUsers = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { userIds, title, body, data: notificationData } = data;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0 || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: userIds array, title, body');
    }

    // Get FCM tokens for all users
    const userDocs = await Promise.all(
      userIds.map(userId => admin.firestore().collection('users').doc(userId).get())
    );

    const fcmTokens = [];
    for (const doc of userDocs) {
      if (doc.exists) {
        const userData = doc.data();
        const fcmToken = userData.fcmToken;
        if (fcmToken && fcmToken.length > 0) {
          fcmTokens.push(fcmToken);
        }
      }
    }

    if (fcmTokens.length === 0) {
      return { success: false, message: 'No FCM tokens found for users' };
    }

    // Send notification to all tokens (in batches of 500)
    const batchSize = 500;
    const results = [];

    for (let i = 0; i < fcmTokens.length; i += batchSize) {
      const batch = fcmTokens.slice(i, i + batchSize);
      
      const message = {
        tokens: batch,
        notification: {
          title: title,
          body: body,
        },
        data: notificationData || {},
        android: {
          priority: 'high',
          notification: {
            channelId: 'chat_notifications',
            priority: 'high',
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              category: 'chat_category',
            },
          },
        },
      };

      const response = await admin.messaging().sendMulticast(message);
      results.push({
        batchIndex: i / batchSize,
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses,
      });
    }

    const totalSuccess = results.reduce((sum, result) => sum + result.successCount, 0);
    const totalFailure = results.reduce((sum, result) => sum + result.failureCount, 0);

    console.log(`Sent notifications: ${totalSuccess} success, ${totalFailure} failure`);
    
    return { 
      success: true, 
      totalSuccess,
      totalFailure,
      results,
      message: `Notifications sent: ${totalSuccess} success, ${totalFailure} failure`
    };
    
  } catch (error) {
    console.error('Error sending notifications to users:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notifications', error.message);
  }
});

// Cloud Function to handle new chat message
exports.handleNewChatMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const { senderId, senderName, text, type } = messageData;
      const chatId = context.params.chatId;

      // Don't send notification to sender
      if (!senderId) return;

      // Get chat details
      const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data();
      const isGroupChat = chatData.isGroupChat || false;
      const chatName = chatData.name || 'Chat';
      const memberIds = chatData.memberIds || chatData.userIds || [];

      // Determine notification content
      let title, body;
      
      switch (type) {
        case 'text':
          title = isGroupChat ? `👥 ${chatName}` : `💬 ${senderName}`;
          body = isGroupChat 
            ? `${senderName}: ${text.length > 50 ? text.substring(0, 50) + '...' : text}`
            : text.length > 50 ? text.substring(0, 50) + '...' : text;
          break;
        case 'image':
          title = isGroupChat ? `👥 ${chatName}` : `📷 ${senderName}`;
          body = isGroupChat ? `${senderName} sent a photo` : 'Sent you a photo';
          break;
        case 'video':
          title = isGroupChat ? `👥 ${chatName}` : `🎥 ${senderName}`;
          body = isGroupChat ? `${senderName} sent a video` : 'Sent you a video';
          break;
        case 'audio':
          title = isGroupChat ? `👥 ${chatName}` : `🎤 ${senderName}`;
          body = isGroupChat ? `${senderName} sent a voice message` : 'Sent you a voice message';
          break;
        case 'document':
          title = isGroupChat ? `👥 ${chatName}` : `📄 ${senderName}`;
          body = isGroupChat ? `${senderName} sent a document` : 'Sent you a document';
          break;
        default:
          title = isGroupChat ? `👥 ${chatName}` : `💬 ${senderName}`;
          body = isGroupChat ? `${senderName} sent a message` : 'Sent you a message';
      }

      // Get recipient IDs (exclude sender)
      const recipientIds = memberIds.filter(id => id !== senderId);
      if (recipientIds.length === 0) return;

      // Send notification to recipients
      const notificationData = {
        type: isGroupChat ? 'group_message' : 'chat_message',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        messageType: type,
        timestamp: new Date().toISOString(),
      };

      // Call the sendNotificationToUsers function
      const { sendNotificationToUsers } = require('./index');
      await sendNotificationToUsers({
        userIds: recipientIds,
        title: title,
        body: body,
        data: notificationData,
      }, { auth: { uid: senderId } });

      console.log(`Notification sent for message in chat ${chatId}`);
      
    } catch (error) {
      console.error('Error handling new chat message:', error);
    }
  });

// Cloud Function to handle broadcast messages
exports.handleBroadcastMessage = functions.firestore
  .document('broadcasts/{broadcastId}')
  .onCreate(async (snap, context) => {
    try {
      const broadcastData = snap.data();
      const { senderId, senderName, text, type } = broadcastData;

      // Determine notification content
      let title, body;
      
      switch (type) {
        case 'text':
          title = '📢 Broadcast';
          body = `${senderName}: ${text.length > 50 ? text.substring(0, 50) + '...' : text}`;
          break;
        case 'image':
          title = '📢 Broadcast';
          body = `${senderName} sent a photo`;
          break;
        case 'video':
          title = '📢 Broadcast';
          body = `${senderName} sent a video`;
          break;
        case 'audio':
          title = '📢 Broadcast';
          body = `${senderName} sent a voice message`;
          break;
        case 'document':
          title = '📢 Broadcast';
          body = `${senderName} sent a document`;
          break;
        default:
          title = '📢 Broadcast';
          body = `${senderName} sent a message`;
      }

      // Get all users with FCM tokens
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('fcmToken', '!=', null)
        .get();

      const userIds = [];
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmToken && userData.fcmToken.length > 0) {
          userIds.push(doc.id);
        }
      });

      if (userIds.length === 0) return;

      // Send broadcast notification
      const notificationData = {
        type: 'broadcast_message',
        senderId: senderId,
        senderName: senderName,
        messageType: type,
        timestamp: new Date().toISOString(),
      };

      // Call the sendNotificationToUsers function
      const { sendNotificationToUsers } = require('./index');
      await sendNotificationToUsers({
        userIds: userIds,
        title: title,
        body: body,
        data: notificationData,
      }, { auth: { uid: senderId } });

      console.log(`Broadcast notification sent to ${userIds.length} users`);
      
    } catch (error) {
      console.error('Error handling broadcast message:', error);
    }
  });

// Health check endpoint
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.json({
    status: 'OK',
    message: 'Firebase Cloud Functions FCM Server is running',
    timestamp: new Date().toISOString(),
    environment: 'production',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: '1.0.0'
  });
});

