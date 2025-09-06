const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['http://localhost:3000'],
  credentials: true,
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Initialize Firebase Admin SDK
let serviceAccount;
try {
  if (NODE_ENV === 'production') {
    // In production, use environment variables
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
    // In development, use local service account file
    serviceAccount = require('./assets/service-account/soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json');
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID || 'soc-chat-app-ca57e',
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || 'soc-chat-app-ca57e.appspot.com',
  });

  console.log('Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('Failed to initialize Firebase Admin SDK:', error);
  process.exit(1);
}

// Request logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  const healthCheck = {
    status: 'OK',
    message: 'FCM Server is running',
    timestamp: new Date().toISOString(),
    environment: NODE_ENV,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0',
  };
  
  res.status(200).json(healthCheck);
});

// Detailed health check endpoint
app.get('/health/detailed', async (req, res) => {
  try {
    const healthCheck = {
      status: 'OK',
      message: 'FCM Server detailed health check',
      timestamp: new Date().toISOString(),
      environment: NODE_ENV,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: process.env.npm_package_version || '1.0.0',
      firebase: {
        projectId: admin.app().options.projectId,
        initialized: admin.app().options.credential !== undefined,
      },
      system: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
        pid: process.pid,
      },
    };
    
    res.status(200).json(healthCheck);
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      message: 'Health check failed',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Send notification to specific FCM token
app.post('/send-notification', async (req, res) => {
  try {
    const { token, title, body, data, priority = 'high' } = req.body;
    
    // Validation
    if (!token || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: token, title, body',
        timestamp: new Date().toISOString(),
      });
    }

    // Validate FCM token format
    if (typeof token !== 'string' || token.length < 100) {
      return res.status(400).json({
        error: 'Invalid FCM token format',
        timestamp: new Date().toISOString(),
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
        priority: priority,
        notification: {
          channelId: data?.channelId || 'chat_channel',
          priority: priority,
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
            category: data?.category || 'default',
          },
        },
        headers: {
          'apns-priority': priority === 'high' ? '10' : '5',
        },
      },
      webpush: {
        headers: {
          'Urgency': priority === 'high' ? 'high' : 'normal',
        },
        notification: {
          icon: '/icon-192x192.png',
          badge: '/badge-72x72.png',
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent message:', response);
    
    // Log successful notification
    await logNotification({
      type: 'individual',
      token: token.substring(0, 20) + '...',
      title,
      body,
      status: 'success',
      messageId: response,
      timestamp: new Date(),
    });
    
    res.json({ 
      success: true, 
      messageId: response,
      message: 'Notification sent successfully',
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('Error sending message:', error);
    
    // Log failed notification
    await logNotification({
      type: 'individual',
      token: req.body.token?.substring(0, 20) + '...',
      title: req.body.title,
      body: req.body.body,
      status: 'failed',
      error: error.message,
      timestamp: new Date(),
    });
    
    res.status(500).json({ 
      error: 'Failed to send notification',
      details: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Send notification to topic
app.post('/send-topic-notification', async (req, res) => {
  try {
    const { topic, title, body, data, priority = 'high' } = req.body;
    
    if (!topic || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: topic, title, body',
        timestamp: new Date().toISOString(),
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
        priority: priority,
        notification: {
          channelId: data?.channelId || 'broadcast_channel',
          priority: priority,
          defaultSound: true,
          icon: '@mipmap/ic_launcher',
          color: '#FF5722',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            category: data?.category || 'broadcast',
          },
        },
        headers: {
          'apns-priority': priority === 'high' ? '10' : '5',
        },
      },
      webpush: {
        headers: {
          'Urgency': priority === 'high' ? 'high' : 'normal',
        },
        notification: {
          icon: '/icon-192x192.png',
          badge: '/badge-72x72.png',
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    console.log('Successfully sent topic message:', response);
    
    // Log successful broadcast
    await logNotification({
      type: 'topic',
      topic,
      title,
      body,
      status: 'success',
      messageId: response,
      timestamp: new Date(),
    });
    
    res.json({ 
      success: true, 
      messageId: response,
      message: 'Topic notification sent successfully',
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('Error sending topic message:', error);
    
    // Log failed broadcast
    await logNotification({
      type: 'topic',
      topic: req.body.topic,
      title: req.body.title,
      body: req.body.body,
      status: 'failed',
      error: error.message,
      timestamp: new Date(),
    });
    
    res.status(500).json({ 
      error: 'Failed to send topic notification',
      details: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Send multicast notification to multiple tokens
app.post('/send-multicast', async (req, res) => {
  try {
    const { tokens, title, body, data, priority = 'high' } = req.body;
    
    if (!tokens || !Array.isArray(tokens) || tokens.length === 0 || !title || !body) {
      return res.status(400).json({ 
        error: 'Missing required fields: tokens (array), title, body',
        timestamp: new Date().toISOString(),
      });
    }

    // Limit batch size
    if (tokens.length > 500) {
      return res.status(400).json({
        error: 'Too many tokens. Maximum 500 tokens per request.',
        timestamp: new Date().toISOString(),
      });
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: priority,
        notification: {
          channelId: data?.channelId || 'chat_channel',
          priority: priority,
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
            category: data?.category || 'default',
          },
        },
        headers: {
          'apns-priority': priority === 'high' ? '10' : '5',
        },
      },
      webpush: {
        headers: {
          'Urgency': priority === 'high' ? 'high' : 'normal',
        },
        notification: {
          icon: '/icon-192x192.png',
          badge: '/badge-72x72.png',
        },
      },
    };

    const response = await admin.messaging().sendMulticast({
      tokens: tokens,
      ...message,
    });
    
    console.log('Successfully sent multicast message:', response);
    
    // Log successful multicast
    await logNotification({
      type: 'multicast',
      tokenCount: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      title,
      body,
      status: 'success',
      timestamp: new Date(),
    });
    
    res.json({ 
      success: true, 
      response: {
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses,
      },
      message: 'Multicast notification sent successfully',
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('Error sending multicast message:', error);
    
    // Log failed multicast
    await logNotification({
      type: 'multicast',
      tokenCount: req.body.tokens?.length || 0,
      title: req.body.title,
      body: req.body.body,
      status: 'failed',
      error: error.message,
      timestamp: new Date(),
    });
    
    res.status(500).json({ 
      error: 'Failed to send multicast notification',
      details: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Subscribe to topic
app.post('/subscribe-topic', async (req, res) => {
  try {
    const { tokens, topic } = req.body;
    
    if (!tokens || !Array.isArray(tokens) || !topic) {
      return res.status(400).json({ 
        error: 'Missing required fields: tokens (array), topic',
        timestamp: new Date().toISOString(),
      });
    }

    const response = await admin.messaging().subscribeToTopic(tokens, topic);
    
    console.log('Successfully subscribed to topic:', response);
    
    res.json({ 
      success: true, 
      response: response,
      message: 'Successfully subscribed to topic',
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('Error subscribing to topic:', error);
    res.status(500).json({ 
      error: 'Failed to subscribe to topic',
      details: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Unsubscribe from topic
app.post('/unsubscribe-topic', async (req, res) => {
  try {
    const { tokens, topic } = req.body;
    
    if (!tokens || !Array.isArray(tokens) || !topic) {
      return res.status(400).json({ 
        error: 'Missing required fields: tokens (array), topic',
        timestamp: new Date().toISOString(),
      });
    }

    const response = await admin.messaging().unsubscribeFromTopic(tokens, topic);
    
    console.log('Successfully unsubscribed from topic:', response);
    
    res.json({ 
      success: true, 
      response: response,
      message: 'Successfully unsubscribed from topic',
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('Error unsubscribing from topic:', error);
    res.status(500).json({ 
      error: 'Failed to unsubscribe from topic',
      details: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Get server statistics
app.get('/stats', async (req, res) => {
  try {
    const stats = {
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      environment: NODE_ENV,
      timestamp: new Date().toISOString(),
      firebase: {
        projectId: admin.app().options.projectId,
        initialized: admin.app().options.credential !== undefined,
      },
    };
    
    res.json(stats);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to get server stats',
      details: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: NODE_ENV === 'development' ? error.message : 'Something went wrong',
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString(),
  });
});

// Log notification function
async function logNotification(logData) {
  try {
    // In production, you might want to save this to a database
    console.log('Notification Log:', JSON.stringify(logData, null, 2));
    
    // Example: Save to Firestore
    if (admin.firestore) {
      await admin.firestore().collection('notification_logs').add({
        ...logData,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    console.error('Error logging notification:', error);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 FCM Server running on port ${PORT}`);
  console.log(`🌍 Environment: ${NODE_ENV}`);
  console.log(`🔐 Firebase Project: ${admin.app().options.projectId}`);
  console.log(`📊 Health Check: http://localhost:${PORT}/health`);
  console.log(`📈 Detailed Health: http://localhost:${PORT}/health/detailed`);
  console.log(`📊 Statistics: http://localhost:${PORT}/stats`);
});

module.exports = app;
