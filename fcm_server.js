const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const path = require('path');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK with your service account
const serviceAccount = require('./assets/service-account/soc-chat-app-ca57e-bc21fed17ba4.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'soc-chat-app-ca57e'
});

// Routes

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'FCM Server is running',
    timestamp: new Date().toISOString()
  });
});

// Send notification to specific FCM token
app.post('/send-notification', async (req, res) => {
  try {
    const { token, title, body, data } = req.body;
    
    if (!token || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: token, title, body' 
      });
    }

    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_channel',
          priority: 'high',
          defaultSound: true,
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

    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent message:', response);
    res.json({ 
      success: true, 
      messageId: response,
      message: 'Notification sent successfully' 
    });
    
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ 
      error: 'Failed to send notification',
      details: error.message 
    });
  }
});

// Send notification to topic
app.post('/send-topic-notification', async (req, res) => {
  try {
    const { topic, title, body, data } = req.body;
    
    if (!topic || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: topic, title, body' 
      });
    }

    const message = {
      topic: topic,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'broadcast_channel',
          priority: 'high',
          defaultSound: true,
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

    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent topic message:', response);
    res.json({ 
      success: true, 
      messageId: response,
      message: 'Topic notification sent successfully' 
    });
    
  } catch (error) {
    console.error('Error sending topic message:', error);
    res.status(500).json({ 
      error: 'Failed to send topic notification',
      details: error.message 
    });
  }
});

// Send notification to multiple tokens
app.post('/send-multicast', async (req, res) => {
  try {
    const { tokens, title, body, data } = req.body;
    
    if (!tokens || !Array.isArray(tokens) || tokens.length === 0 || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: tokens (array), title, body' 
      });
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_channel',
          priority: 'high',
          defaultSound: true,
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

    const response = await admin.messaging().sendMulticast({
      tokens: tokens,
      notification: message.notification,
      data: message.data,
      android: message.android,
      apns: message.apns
    });
    
    console.log('Successfully sent multicast message:', response);
    res.json({ 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      message: 'Multicast notification sent successfully' 
    });
    
  } catch (error) {
    console.error('Error sending multicast message:', error);
    res.status(500).json({ 
      error: 'Failed to send multicast notification',
      details: error.message 
    });
  }
});

// Subscribe to topic
app.post('/subscribe-topic', async (req, res) => {
  try {
    const { tokens, topic } = req.body;
    
    if (!tokens || !Array.isArray(tokens) || tokens.length === 0 || !topic) {
      return res.status(400).json({ 
        error: 'Missing required fields: tokens (array), topic' 
      });
    }

    const response = await admin.messaging().subscribeToTopic(tokens, topic);
    
    console.log('Successfully subscribed to topic:', response);
    res.json({ 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      message: `Successfully subscribed ${response.successCount} tokens to topic: ${topic}` 
    });
    
  } catch (error) {
    console.error('Error subscribing to topic:', error);
    res.status(500).json({ 
      error: 'Failed to subscribe to topic',
      details: error.message 
    });
  }
});

// Unsubscribe from topic
app.post('/unsubscribe-topic', async (req, res) => {
  try {
    const { tokens, topic } = req.body;
    
    if (!tokens || !Array.isArray(tokens) || tokens.length === 0 || !topic) {
      return res.status(400).json({ 
        error: 'Missing required fields: tokens (array), topic' 
      });
    }

    const response = await admin.messaging().unsubscribeFromTopic(tokens, topic);
    
    console.log('Successfully unsubscribed from topic:', response);
    res.json({ 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      message: `Successfully unsubscribed ${response.successCount} tokens from topic: ${topic}` 
    });
    
  } catch (error) {
    console.error('Error unsubscribing from topic:', error);
    res.status(500).json({ 
      error: 'Failed to unsubscribe from topic',
      details: error.message 
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 FCM Server running on port ${PORT}`);
  console.log(`📱 Health check: http://localhost:${PORT}/health`);
  console.log(`📨 Send notification: POST http://localhost:${PORT}/send-notification`);
  console.log(`📢 Send topic notification: POST http://localhost:${PORT}/send-topic-notification`);
  console.log(`📤 Send multicast: POST http://localhost:${PORT}/send-multicast`);
  console.log(`➕ Subscribe to topic: POST http://localhost:${PORT}/subscribe-topic`);
  console.log(`➖ Unsubscribe from topic: POST http://localhost:${PORT}/unsubscribe-topic`);
});

module.exports = app;
