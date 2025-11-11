// SOC Chat App - Local API Server
// Replacement for Firebase services using MongoDB and Express

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { MongoClient, ObjectId } = require('mongodb');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const http = require('http');
const socketIo = require('socket.io');
const { jwtVerify, createRemoteJWKSet } = require('jose');

// Firebase Admin SDK for FCM notifications
let admin;
try {
  admin = require('firebase-admin');
} catch (e) {
  console.warn('firebase-admin not available, FCM notifications will be disabled:', e.message);
  admin = null;
}

// Initialize Express app
const app = express();
const server = http.createServer(app);
// Trust reverse proxies (e.g., ngrok) so Express uses X-Forwarded-For for req.ip
app.set('trust proxy', true);
// CORS allowed origins (comma-separated). Example: https://api.example.com,http://localhost:8080
// Allow any local network IP on common ports
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:8080,http://localhost:8082')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);
  
// Note: Local network IPs (192.168.x.x, 10.x.x.x, 172.16-31.x.x) are 
// automatically allowed by CORS configuration below

// Add mobile-specific origins for better compatibility
const mobileOrigins = [
  'capacitor://localhost',
  'ionic://localhost',
  'http://localhost',
  'https://localhost',
  'http://127.0.0.1',
  'https://127.0.0.1'
];

const allOrigins = [...allowedOrigins, ...mobileOrigins];
const io = socketIo(server, {
  cors: {
    origin: allOrigins,
    methods: ["GET", "POST"],
    credentials: true,
  }
});

// Make Socket.IO accessible to all routes
app.set('io', io);

// Middleware
// Compression middleware (should be first for maximum efficiency)
app.use(compression({
  level: 6, // Compression level (1-9, 6 is good balance)
  threshold: 1024, // Only compress responses larger than 1KB
  filter: (req, res) => {
    // Don't compress responses if the request includes 'x-no-compression' header
    if (req.headers['x-no-compression']) {
      return false;
    }
    // Use compression filter function
    return compression.filter(req, res);
  }
}));

// Security headers with enhanced CSP
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https:", "wss:", "ws:"],
      fontSrc: ["'self'", "https:", "data:"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'", "https:"],
      frameSrc: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
      upgradeInsecureRequests: []
    },
    reportOnly: false
  },
  crossOriginEmbedderPolicy: false, // Disable for API compatibility
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS - More permissive for local development
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl)
    if (!origin) return callback(null, true);
    
    // Allow localhost on any port
    if (origin.startsWith('http://localhost:') || origin.startsWith('https://localhost:')) {
      return callback(null, true);
    }
    
    // Allow 127.0.0.1 on any port
    if (origin.startsWith('http://127.0.0.1:') || origin.startsWith('https://127.0.0.1:')) {
      return callback(null, true);
    }
    
    // Allow local network IPs on any port (IPv4 ranges)
    // 192.168.x.x - private network
    if (origin.match(/^http:\/\/192\.168\.\d{1,3}\.\d{1,3}:\d+$/)) {
      return callback(null, true);
    }
    
    // 10.x.x.x - private network
    if (origin.match(/^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$/)) {
      return callback(null, true);
    }
    
    // 172.16-31.x.x - private network
    if (origin.match(/^http:\/\/172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}:\d+$/)) {
      return callback(null, true);
    }
    
    // Allow all IPv4 addresses on localhost/bound network (like 160.2.x.x)
    if (origin.match(/^http:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$/)) {
      return callback(null, true);
    }
    
    // Check against explicit allowed origins
    if (allOrigins.indexOf(origin) !== -1) {
      return callback(null, true);
    }
    
    console.log('CORS blocked origin:', origin);
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'ngrok-skip-browser-warning', 'X-Requested-With'],
}));

// Middleware to handle ngrok browser warning
app.use((req, res, next) => {
  // Add ngrok-skip-browser-warning header to bypass ngrok warning page
  res.setHeader('ngrok-skip-browser-warning', 'true');
  next();
});

// DEBUG: Log all POST requests to /api/chats BEFORE body parsing
app.use((req, res, next) => {
  if (req.method === 'POST' && req.path === '/api/chats') {
    console.error('\n🔍🔍🔍 BEFORE BODY PARSING 🔍🔍🔍');
    console.error('Path:', req.path);
    console.error('Content-Type:', req.headers['content-type']);
    console.error('Content-Length:', req.headers['content-length']);
  }
  next();
});

// JSON parsing
app.use(express.json({ limit: '2mb' }));

// DEBUG: Log all POST requests to /api/chats AFTER body parsing
app.use((req, res, next) => {
  if (req.method === 'POST' && req.path === '/api/chats') {
    console.error('\n✅✅✅ AFTER BODY PARSING ✅✅✅');
    console.error('Body type:', typeof req.body);
    console.error('Body:', req.body);
    console.error('Body keys:', req.body ? Object.keys(req.body) : 'null');
  }
  next();
});

app.use(morgan('dev'));
// Helper to rewrite media URLs to same-origin for web clients
// Accepts either an Express req or a plain headers object
function rewriteMediaUrlIfNeeded(originalUrl, reqOrHeaders) {
  try {
    if (!originalUrl) return originalUrl;
    const headers = (reqOrHeaders && (reqOrHeaders.headers || reqOrHeaders)) || {};
    const clientBaseHeader = (headers['x-client-base'] || '').toString();
    const clientPlatform = (headers['x-client-platform'] || '').toString();
    if (clientPlatform === 'web' && clientBaseHeader.startsWith('http')) {
      const parts = originalUrl.split('/uploads/');
      if (parts.length >= 2) {
        return `${clientBaseHeader}/uploads/${parts[1]}`;
      }
    }
    return originalUrl;
  } catch (_) {
    return originalUrl;
  }
}

// Rate limiting disabled for development
// const limiter = rateLimit({
//   windowMs: 15 * 60 * 1000, // 15 minutes
//   max: parseInt(process.env.RATE_LIMIT_MAX || '10000', 10),
//   standardHeaders: true,
//   legacyHeaders: false,
//   message: {
//     error: 'Too many requests from this IP',
//     message: 'Please try again later'
//   },
//   keyGenerator: rateLimit.ipKeyGenerator,
//   skip: (req) => {
//     const p = req.path || '';
//     const m = (req.method || 'GET').toUpperCase();
//     if (p === '/health' || p.startsWith('/api/health') || p.startsWith('/api/status/')) return true;
//     if (m === 'OPTIONS' || m === 'HEAD') return true;
//     if (m === 'GET' && (p === '/api/chats' || (p.startsWith('/api/chats/') && p.endsWith('/messages')))) return true;
//     if (p.startsWith('/api/messages') || p.startsWith('/api/auth')) return true;
//     return false;
//   }
// });
// app.use(limiter);

// User search rate limiting disabled for development
// const userSearchLimiter = rateLimit({
//   windowMs: 1 * 60 * 1000, // 1 minute
//   max: 50, // 50 requests per minute for user search
//   standardHeaders: true,
//   legacyHeaders: false,
//   message: {
//     error: 'Too many user search requests',
//     message: 'Please wait a moment before searching again'
//   }
// });

// =========================================
// Static uploads directory and multer setup
// =========================================
const UPLOADS_DIR = path.join(__dirname, 'uploads');
try {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
} catch (e) {
  console.warn('Failed to ensure uploads directory exists:', e.message);
}

// Serve uploaded media statically
app.use('/uploads', express.static(UPLOADS_DIR));

// Backward-compatibility alias: serve legacy /chat_media paths from uploads/chat_media
app.use('/chat_media', express.static(path.join(UPLOADS_DIR, 'chat_media')));

// Test endpoint to verify static file serving
app.get('/test-uploads', (req, res) => {
  try {
    const fs = require('fs');
    const files = fs.readdirSync(UPLOADS_DIR, { recursive: true });
    res.json({
      uploadsDir: UPLOADS_DIR,
      files: files.slice(0, 10), // Show first 10 files
      totalFiles: files.length
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Configure multer storage for chat media
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    try {
      const chatId = (req.body?.chatId || 'unknown').toString();
      const baseDir = path.join(UPLOADS_DIR, 'chat_media', chatId);
      fs.mkdirSync(baseDir, { recursive: true });
      cb(null, baseDir);
    } catch (err) {
      cb(err);
    }
  },
  filename: (req, file, cb) => {
    const safeOriginal = (file.originalname || 'media').replace(/[^\w.-]/g, '_');
    const ext = path.extname(safeOriginal);
    const mediaType = (req.body?.type || 'media').toString();
    const ts = Date.now();
    cb(null, `${ts}_${mediaType}${ext || ''}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: (parseInt(process.env.MAX_UPLOAD_MB || '50', 10)) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    // Basic filter: accept common media types; extend as needed
    const allowed = [
      'image/', 'video/', 'audio/', 'application/pdf',
      'application/msword', 'application/vnd', 'text/plain', 'application/octet-stream'
    ];
    if (allowed.some(prefix => file.mimetype.startsWith(prefix))) {
      return cb(null, true);
    }
    // Allow unknown types but warn
    console.warn('Rejected upload with mimetype:', file.mimetype);
    return cb(new Error('Unsupported file type'));
  }
});

// MongoDB Connection with Enhanced Monitoring
// Use MONGO_URI from environment; ensure it matches your local auth setup
const mongoURI = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';
let client = new MongoClient(mongoURI, {
  // Connection pool settings
  maxPoolSize: 10,
  minPoolSize: 2,
  maxIdleTimeMS: 30000,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
  // Monitoring options
  monitorCommands: true,
  // Retry settings
  retryWrites: true,
  retryReads: true
});
let db;

// Connection monitoring variables
let connectionStatus = 'disconnected';
let lastConnectionTime = null;
let connectionAttempts = 0;
let totalQueries = 0;
let failedQueries = 0;

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_here';

// Connect to MongoDB with retry logic and enhanced monitoring
async function connectToMongo(retryCount = 0) {
  const maxRetries = 5;
  const retryDelay = 5000; // 5 seconds
  
  connectionAttempts++;
  
  try {
    await client.connect();
    db = client.db('soc_chat_app');
    // Expose database handle on app.locals for downstream routes (e.g., admin)
    app.locals.db = db;
    connectionStatus = 'connected';
    lastConnectionTime = new Date();
    
    console.log('✅ Connected to MongoDB successfully');
    console.log(`📊 Connection attempt: ${connectionAttempts}`);
    
    // Set up comprehensive connection monitoring
    setupMongoMonitoring();
    
    // Set database connection for route modules (after routes are loaded)
    if (chatRoutes && typeof chatRoutes.setDatabase === 'function') {
      chatRoutes.setDatabase(db);
    }
    
    // Test the connection
    await db.admin().ping();
    console.log('✅ MongoDB ping successful');
    
    // Initialize Firebase Admin SDK for FCM notifications
    if (admin && !admin.apps.length) {
      try {
        const NODE_ENV = process.env.NODE_ENV || 'development';
        let serviceAccount;
        
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
          // In development, try to load service account file
          try {
            // Try different possible paths
            const possiblePaths = [
              path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'),
              path.join(__dirname, '..', 'assets', 'service-account', 'soc-chat-app-ca57e-bc21fed17ba4.json'),
              path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-firebase-adminsdk-fbsvc-b395336526.json'),
              path.join(__dirname, 'assets', 'service-account', 'soc-chat-app-ca57e-bc21fed17ba4.json'),
            ];
            
            let serviceAccountPath = null;
            for (const p of possiblePaths) {
              if (fs.existsSync(p)) {
                serviceAccountPath = p;
                break;
              }
            }
            
            if (serviceAccountPath) {
              serviceAccount = require(serviceAccountPath);
            } else {
              console.warn('⚠️ Firebase service account file not found. FCM notifications will be disabled.');
              console.warn('   Searched paths:', possiblePaths);
            }
          } catch (e) {
            console.warn('⚠️ Could not load Firebase service account:', e.message);
          }
        }
        
        if (serviceAccount) {
          admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || 'soc-chat-app-ca57e',
          });
          console.log('✅ Firebase Admin SDK initialized successfully');
        }
      } catch (firebaseErr) {
        console.warn('⚠️ Failed to initialize Firebase Admin SDK:', firebaseErr.message);
        console.warn('   FCM notifications will be disabled');
      }
    }
    
  } catch (err) {
    connectionStatus = 'failed';
    console.error(`❌ Failed to connect to MongoDB (attempt ${retryCount + 1}/${maxRetries}):`, err.message);
    
    // Fallback: try connecting without authentication if auth failed
    if (err && (err.code === 18 || err.codeName === 'AuthenticationFailed')) {
      try {
        console.warn('🔄 Retrying MongoDB connection without auth to localhost:27017');
        client = new MongoClient('mongodb://localhost:27017/soc_chat_app', {
          maxPoolSize: 10,
          minPoolSize: 2,
          maxIdleTimeMS: 30000,
          serverSelectionTimeoutMS: 5000,
          socketTimeoutMS: 45000,
          monitorCommands: true,
          retryWrites: true,
          retryReads: true
        });
        await client.connect();
        db = client.db('soc_chat_app');
        // Ensure app.locals has the db in fallback path as well
        app.locals.db = db;
        // Set database connection for route modules
        if (typeof chatRoutes.setDatabase === 'function') {
          chatRoutes.setDatabase(db);
        }
        connectionStatus = 'connected';
        lastConnectionTime = new Date();
        console.log('✅ Connected to MongoDB (no auth fallback)');
        setupMongoMonitoring();
        return;
      } catch (fallbackErr) {
        console.error('❌ Fallback MongoDB connection failed:', fallbackErr.message);
      }
    }
    
    // Retry logic
    if (retryCount < maxRetries) {
      console.log(`🔄 Retrying MongoDB connection in ${retryDelay/1000} seconds...`);
      setTimeout(() => connectToMongo(retryCount + 1), retryDelay);
    } else {
      console.error('❌ Maximum retry attempts reached. Exiting...');
      process.exit(1);
    }
  }
}

// Set up comprehensive MongoDB monitoring
function setupMongoMonitoring() {
  // Connection event monitoring
  client.on('error', (err) => {
    connectionStatus = 'error';
    console.error('❌ MongoDB connection error:', err.message);
    // Attempt to reconnect
    setTimeout(() => connectToMongo(), 5000);
  });
  
  client.on('disconnect', () => {
    connectionStatus = 'disconnected';
    console.warn('⚠️ MongoDB disconnected, attempting to reconnect...');
    setTimeout(() => connectToMongo(), 5000);
  });
  
  client.on('reconnect', () => {
    connectionStatus = 'connected';
    lastConnectionTime = new Date();
    console.log('✅ MongoDB reconnected successfully');
  });
  
  client.on('close', () => {
    connectionStatus = 'closed';
    console.warn('⚠️ MongoDB connection closed');
  });
  
  // Command monitoring
  client.on('commandStarted', (event) => {
    totalQueries++;
    console.log(`📝 MongoDB command started: ${event.commandName}`);
  });
  
  client.on('commandSucceeded', (event) => {
    console.log(`✅ MongoDB command succeeded: ${event.commandName} (${event.duration}ms)`);
  });
  
  client.on('commandFailed', (event) => {
    failedQueries++;
    console.error(`❌ MongoDB command failed: ${event.commandName} - ${event.failure.message}`);
  });
  
  // Server monitoring
  client.on('serverDescriptionChanged', (event) => {
    console.log(`🔄 MongoDB server description changed: ${event.address}`);
  });
  
  client.on('topologyDescriptionChanged', (event) => {
    console.log(`🔄 MongoDB topology changed: ${event.newDescription.type}`);
  });
}

// Get MongoDB connection status
function getMongoStatus() {
  return {
    status: connectionStatus,
    lastConnection: lastConnectionTime,
    connectionAttempts: connectionAttempts,
    totalQueries: totalQueries,
    failedQueries: failedQueries,
    successRate: totalQueries > 0 ? ((totalQueries - failedQueries) / totalQueries * 100).toFixed(2) + '%' : '0%'
  };
}

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    console.error('[AUTH] ❌ No token provided for', req.method, req.path);
    return res.status(401).json({ error: 'Access denied' });
  }
  
  jwt.verify(token, JWT_SECRET, async (err, user) => {
    if (err) {
      console.error('[AUTH] ❌ Token verification failed for', req.method, req.path, ':', err.message);
      return res.status(403).json({ error: 'Invalid token' });
    }
    
    // Check if user is disabled or locked
    if (db) {
      try {
        const userDoc = await db.collection('users').findOne({ _id: new ObjectId(user.id) });
        if (userDoc) {
          if (userDoc.disabled === true) {
            console.error('[AUTH] ❌ User is disabled:', user.id);
            return res.status(403).json({ error: 'Your account has been disabled. Please contact an administrator.' });
          }
          if (userDoc.isLocked === true) {
            console.error('[AUTH] ❌ User is locked:', user.id);
            return res.status(403).json({ error: 'Your account has been locked. Please contact an administrator.' });
          }
        }
      } catch (dbErr) {
        console.error('[AUTH] Error checking user status:', dbErr);
        // Continue with authentication if DB check fails (don't block legitimate users)
      }
    }
    
    console.error('[AUTH] ✅ Token verified for user:', user.id);
    req.user = user;
    console.log('[AUTH] Calling next() for', req.method, req.path);
    next();
  });
};

// Routes

// Enhanced Health Check with MongoDB Status
app.get('/health', async (req, res) => {
  try {
    const mongoStatus = getMongoStatus();
    const healthStatus = {
      status: mongoStatus.status === 'connected' ? 'ok' : 'degraded',
      message: 'API server is running',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: {
        status: mongoStatus.status,
        lastConnection: mongoStatus.lastConnection,
        connectionAttempts: mongoStatus.connectionAttempts,
        totalQueries: mongoStatus.totalQueries,
        failedQueries: mongoStatus.failedQueries,
        successRate: mongoStatus.successRate
      },
      server: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
        pid: process.pid
      }
    };
    
    res.status(mongoStatus.status === 'connected' ? 200 : 503).json(healthStatus);
  } catch (error) {
    res.status(503).json({
      status: 'error',
      message: 'Health check failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Helper function to send FCM notification to a user
async function sendFCMNotification(userId, title, body, data = {}) {
  if (!admin || !admin.apps.length) {
    console.warn('⚠️ FCM not available, skipping notification for user:', userId);
    return false;
  }
  
  if (!db) {
    console.warn('⚠️ Database not available, skipping FCM notification');
    return false;
  }
  
  try {
    // Get user's FCM token from database
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user || !user.fcmToken || !user.fcmToken.trim()) {
      console.log(`📱 No FCM token found for user ${userId}, skipping notification`);
      return false;
    }
    
    const fcmToken = user.fcmToken;
    const platform = user.fcmPlatform || 'unknown';
    
    // Prepare FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        sound: 'default',
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
      apns: {
        payload: {
          aps: {
            sound: process.env.APNS_SOUND || 'default',
            badge: 1,
            category: data?.category || 'default',
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
    const response = await admin.messaging().send(message);
    console.log(`✅ FCM notification sent to user ${userId} (platform: ${platform}):`, response);
    return true;
  } catch (error) {
    // Handle invalid token errors gracefully
    if (error.code === 'messaging/invalid-registration-token' || 
        error.code === 'messaging/registration-token-not-registered') {
      console.warn(`⚠️ Invalid FCM token for user ${userId}, removing from database`);
      // Remove invalid token from database
      try {
        await db.collection('users').updateOne(
          { _id: new ObjectId(userId) },
          { 
            $set: { 
              fcmToken: '',
              fcmPlatform: '',
              fcmTokenUpdatedAt: new Date(),
            }
          }
        );
      } catch (dbErr) {
        console.error('Error removing invalid FCM token:', dbErr);
      }
    } else {
      console.error(`❌ Error sending FCM notification to user ${userId}:`, error.message);
    }
    return false;
  }
}

// Alias for clients expecting /api/health
app.get('/api/health', async (req, res) => {
  try {
    const mongoStatus = getMongoStatus();
    const healthStatus = {
      status: mongoStatus.status === 'connected' ? 'ok' : 'degraded',
      message: 'API server is running',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: {
        status: mongoStatus.status,
        lastConnection: mongoStatus.lastConnection,
        connectionAttempts: mongoStatus.connectionAttempts,
        totalQueries: mongoStatus.totalQueries,
        failedQueries: mongoStatus.failedQueries,
        successRate: mongoStatus.successRate
      },
      server: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
        pid: process.pid
      }
    };
    
    res.status(mongoStatus.status === 'connected' ? 200 : 503).json(healthStatus);
  } catch (error) {
    res.status(503).json({
      status: 'error',
      message: 'Health check failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Detailed MongoDB Status Endpoint
app.get('/api/status/mongodb', (req, res) => {
  const mongoStatus = getMongoStatus();
  res.json({
    mongodb: mongoStatus,
    timestamp: new Date().toISOString()
  });
});

// Import routes
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chats');
const messageRoutes = require('./routes/messages');
const notificationRoutes = require('./routes/notifications');
const adminRoutes = require('./routes/admin');

// Use routes
app.use('/auth', authRoutes);
app.use('/chats', chatRoutes);
app.use('/messages', messageRoutes);
app.use('/notifications', notificationRoutes);
app.use('/admin', adminRoutes);
// Also mount API-prefixed routes for client compatibility
app.use('/api/auth', authRoutes);
app.use('/api/chats', chatRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);

// Profile endpoints
app.get('/api/auth/profile', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await db.collection('users').findOne({ _id: new ObjectId(decoded.id) });
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Return user data without password
    const { password, ...userData } = user;
    res.json(userData);
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.put('/api/auth/profile', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    // Support both 'phone' and 'phoneNumber' for compatibility
    const { displayName, email, phone, phoneNumber, password } = req.body;
    const finalPhoneNumber = phoneNumber || phone || '';
    
    if (!displayName || !email) {
      return res.status(400).json({ message: 'Display name and email are required' });
    }

    // Check if email is already taken by another user
    const existingUser = await db.collection('users').findOne({ 
      email: email,
      _id: { $ne: new ObjectId(decoded.id) }
    });
    
    if (existingUser) {
      return res.status(400).json({ message: 'Email is already taken' });
    }

    const updateData = {
      displayName: displayName.trim(),
      name: displayName.trim(), // Also update name for backward compatibility
      email: email.trim(),
      phoneNumber: finalPhoneNumber.trim(),
      phone: finalPhoneNumber.trim(), // Also save as phone for backward compatibility
      updatedAt: new Date()
    };

    // If password is provided, hash it
    if (password && password.trim() !== '') {
      const saltRounds = 10;
      updateData.password = await bcrypt.hash(password, saltRounds);
    }

    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(decoded.id) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const updatedUser = await db.collection('users').findOne({ _id: new ObjectId(decoded.id) });
    const { password: _, ...userData } = updatedUser;
    
    res.json({
      message: 'Profile updated successfully',
      user: userData
    });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Legacy User Authentication - keeping for backward compatibility
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, displayName, name, phoneNumber } = req.body;
    // Support both 'displayName' and 'name' for compatibility
    const finalDisplayName = displayName || name;
    
    // Check if user exists
    const existingUser = await db.collection('users').findOne({ email });
    if (existingUser) {
      // If user exists but phone number or displayName is missing, update them
      const updateFields = {};
      if (phoneNumber && !existingUser.phoneNumber) {
        updateFields.phoneNumber = phoneNumber;
      }
      if (finalDisplayName && !existingUser.displayName) {
        updateFields.displayName = finalDisplayName;
        updateFields.name = finalDisplayName; // Also update name for backward compatibility
      }
      
      if (Object.keys(updateFields).length > 0) {
        updateFields.updatedAt = new Date();
        await db.collection('users').updateOne(
          { _id: existingUser._id },
          { $set: updateFields }
        );
        const token = jwt.sign(
          { id: existingUser._id, email, displayName: existingUser.displayName || finalDisplayName, role: 'user' },
          JWT_SECRET,
          { expiresIn: '7d' }
        );
        return res.status(200).json({
          token,
          user: {
            id: existingUser._id,
            email,
            displayName: existingUser.displayName || finalDisplayName,
            phoneNumber: existingUser.phoneNumber || phoneNumber || '',
            role: 'user'
          }
        });
      }
      return res.status(400).json({ error: 'User already exists' });
    }
    
    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    
    // Create user - save as displayName (primary) and name (for backward compatibility)
    const now = new Date();
    const user = {
      email,
      password: hashedPassword,
      displayName: finalDisplayName,
      name: finalDisplayName, // Also save as name for backward compatibility
      phoneNumber: phoneNumber || '',
      role: 'user',
      createdAt: now,
      updatedAt: now,
      status: 'online',
      isOnline: false, // New users start offline until they log in
      lastSeen: now
    };
    
    const result = await db.collection('users').insertOne(user);
    
    // Generate token
    const token = jwt.sign(
      { id: result.insertedId, email, displayName: finalDisplayName, role: 'user' },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.status(201).json({
      token,
      user: {
        id: result.insertedId,
        email,
        displayName: finalDisplayName,
        phoneNumber: phoneNumber || '',
        role: 'user'
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Find user
    const user = await db.collection('users').findOne({ email });
    if (!user) {
      return res.status(400).json({ error: 'Invalid credentials' });
    }
    
    // Check password
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid credentials' });
    }
    
    // Check if user is disabled
    if (user.disabled === true) {
      return res.status(403).json({ 
        error: 'Your account has been disabled. Please contact an administrator.' 
      });
    }
    
    // Check if user is locked
    if (user.isLocked === true) {
      const lockReason = user.lockedReason || 'No reason provided';
      const lockedAt = user.lockedAt ? new Date(user.lockedAt).toLocaleString() : 'Unknown';
      return res.status(403).json({ 
        error: `Your account has been locked. Reason: ${lockReason}. Locked at: ${lockedAt}. Please contact an administrator.` 
      });
    }
    
    // Update status and online presence
    const now = new Date();
    await db.collection('users').updateOne(
      { _id: user._id },
      { 
        $set: { 
          status: 'online',
          isOnline: true,
          lastSeen: now,
          updatedAt: now
        } 
      }
    );
    
    // Generate token - ensure id is always a string
    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, displayName: user.displayName, role: user.role || 'user' },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.json({
      token,
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        role: user.role || 'user'
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Verify token endpoint
app.get('/api/auth/verify', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }
    
    const token = authHeader.substring(7);
    
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Check if user is disabled or locked
      if (db) {
        const user = await db.collection('users').findOne({ _id: new ObjectId(decoded.id) });
        if (user) {
          if (user.disabled === true) {
            return res.status(403).json({ 
              valid: false,
              error: 'Your account has been disabled. Please contact an administrator.' 
            });
          }
          if (user.isLocked === true) {
            return res.status(403).json({ 
              valid: false,
              error: 'Your account has been locked. Please contact an administrator.' 
            });
          }
        }
      }
      
      res.json({ 
        valid: true, 
        user: {
          id: decoded.id,
          email: decoded.email,
          displayName: decoded.displayName,
          role: decoded.role || 'user'
        }
      });
    } catch (err) {
      res.status(401).json({ error: 'Invalid token' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// =========================================
// Media Upload Route
// =========================================
app.post('/api/media/upload', authenticateToken, async (req, res) => {
  // Expect fields: chatId, type (image|video|audio|document), optional caption
  upload.single('file')(req, res, async (err) => {
    if (err) {
      console.error('Upload error:', err);
      const status = err.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
      return res.status(status).json({ error: err.message || 'Upload failed' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const chatId = (req.body?.chatId || 'unknown').toString();
    const type = (req.body?.type || 'media').toString();
    const caption = (req.body?.caption || '').toString();

    // If it's a video, check if transcoding is needed and transcode if necessary
    let finalFilePath = req.file.path;
    let finalFileName = req.file.filename;
    
    if (type === 'video' && req.file.mimetype?.startsWith('video/')) {
      console.log('Video upload detected:', {
        path: req.file.path,
        filename: req.file.filename,
        mimetype: req.file.mimetype
      });
      
      try {
        const transcode = require('./transcode_video');
        
        // Check if ffmpeg is available
        const ffmpegAvailable = await transcode.checkFFmpegAvailable();
        if (!ffmpegAvailable) {
          console.warn('⚠️  FFmpeg not available - video transcoding disabled');
          console.warn('⚠️  Video may not play in web browsers. Install ffmpeg to enable transcoding.');
        } else {
          console.log('✓ FFmpeg is available');
          
          // Check if video needs transcoding
          console.log('Checking if video needs transcoding...');
          const needsTranscode = await transcode.needsTranscoding(req.file.path);
          console.log('Needs transcoding:', needsTranscode);
          
          if (needsTranscode) {
            console.log('🔄 Transcoding video to web-compatible format...');
            
            // Generate transcoded filename
            const originalPath = path.parse(req.file.path);
            const transcodedPath = path.join(originalPath.dir, `transcoded_${originalPath.name}.mp4`);
            
            // Transcode the video
            const success = await transcode.transcodeVideoToH264(req.file.path, transcodedPath);
            
            if (success) {
              // Use transcoded file
              finalFilePath = transcodedPath;
              finalFileName = `transcoded_${req.file.filename}`;
              
              // Delete original file to save space
              fs.unlinkSync(req.file.path);
              
              console.log('✅ Video transcoded successfully');
            } else {
              console.warn('❌ Video transcoding failed, using original file');
            }
          } else {
            console.log('✓ Video already in compatible format');
          }
        }
      } catch (transcodeErr) {
        console.error('❌ Error during video transcoding:', transcodeErr);
        // Continue with original file if transcoding fails
      }
    }

    // Build public URL to the uploaded file (original or transcoded)
    const relativePath = path.join('chat_media', chatId, finalFileName).replace(/\\/g, '/');

    // Determine platform and generate appropriate base URL:
    // - Web: use same-origin base passed via proxy header (x-client-base) to work offline/local
    // - Mobile: keep existing ngrok/public URL for cross-network access
    const clientBaseHeader = (req.headers['x-client-base'] || '').toString();
    const clientPlatform = (req.headers['x-client-platform'] || '').toString();

    let baseUrl;
    if (clientPlatform === 'web' && clientBaseHeader.startsWith('http')) {
      baseUrl = clientBaseHeader; // e.g., http://localhost:8086
    } else {
      baseUrl = process.env.MOBILE_BASE_URL || 'https://soc-chat-app.ngrok-free.app';
    }

    const mediaUrl = `${baseUrl}/uploads/${relativePath}`;
    
    console.log('Media URL generated:', {
      platform: clientPlatform || 'unknown',
      baseUrl,
      relativePath,
      mediaUrl
    });
    
    console.log('Media upload successful:', {
      fileName: finalFileName,
      chatId,
      type,
      mediaUrl,
      fileSize: fs.statSync(finalFilePath).size
    });

    return res.status(201).json({
      mediaUrl,
      type,
      caption,
      fileName: finalFileName,
      size: fs.statSync(finalFilePath).size,
      mimeType: req.file.mimetype,
    });
  });
});

// User Routes
// Get all users (for user search functionality)
app.get('/api/users', authenticateToken, async (req, res) => {
  try {
    const users = await db.collection('users')
      .find({}, { projection: { password: 0 } })
      .toArray();
    
    // Transform users to match expected format
    const transformedUsers = users.map(user => ({
      _id: user._id.toString(),
      email: user.email,
      displayName: user.displayName || user.name,
      username: user.username || user.email.split('@')[0],
      phoneNumber: user.phoneNumber || user.phone || '',
      phone: user.phoneNumber || user.phone || '', // Also include as phone for backward compatibility
      status: user.status || 'offline',
      role: user.role || 'user',
      createdAt: user.createdAt,
      profilePicture: user.profilePicture,
      photoUrl: user.photoUrl || user.profilePicture || ''
    }));
    
    res.json(transformedUsers);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/users/:userId', authenticateToken, async (req, res) => {
  try {
    const user = await db.collection('users').findOne(
      { _id: new ObjectId(req.params.userId) },
      { projection: { password: 0 } }
    );
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Format user response with proper status fields
    const formattedUser = {
      _id: user._id.toString(),
      id: user._id.toString(),
      username: user.username || '',
      displayName: user.displayName || user.username || '',
      email: user.email || '',
      phoneNumber: user.phoneNumber || user.phone || '',
      phone: user.phoneNumber || user.phone || '', // Also include as phone for backward compatibility
      role: user.role || 'user',
      status: user.status || 'offline',
      // Ensure isOnline and lastSeen are always present with proper formatting
      isOnline: user.isOnline === true || user.isOnline === 'true',
      lastSeen: user.lastSeen 
        ? (user.lastSeen instanceof Date 
            ? user.lastSeen.toISOString() 
            : (typeof user.lastSeen === 'string' ? user.lastSeen : new Date().toISOString()))
        : (user.updatedAt 
            ? (user.updatedAt instanceof Date ? user.updatedAt.toISOString() : new Date().toISOString())
            : new Date().toISOString()),
      createdAt: user.createdAt 
        ? (user.createdAt instanceof Date ? user.createdAt.toISOString() : user.createdAt)
        : null,
      updatedAt: user.updatedAt 
        ? (user.updatedAt instanceof Date ? user.updatedAt.toISOString() : user.updatedAt)
        : null,
    };
    
    res.json(formattedUser);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.put('/api/users/:userId/status', authenticateToken, async (req, res) => {
  try {
    const { status } = req.body;
    
    await db.collection('users').updateOne(
      { _id: new ObjectId(req.params.userId) },
      { $set: { status } }
    );
    
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// FCM Token Management Routes
// Store or update FCM token for a user
app.post('/api/users/fcm-token', authenticateToken, async (req, res) => {
  try {
    const { userId, fcmToken, platform, timestamp } = req.body;
    
    // Validate required fields
    if (!userId || !fcmToken) {
      return res.status(400).json({ 
        error: 'Missing required fields: userId and fcmToken are required' 
      });
    }
    
    // Verify the userId matches the authenticated user
    const authenticatedUserId = req.user.id;
    if (userId !== authenticatedUserId) {
      return res.status(403).json({ 
        error: 'Forbidden: Cannot update FCM token for another user' 
      });
    }
    
    // Validate userId format (MongoDB ObjectId)
    if (!ObjectId.isValid(userId)) {
      return res.status(400).json({ error: 'Invalid userId format' });
    }
    
    // Update or insert FCM token in users collection
    const updateResult = await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { 
        $set: { 
          fcmToken: fcmToken,
          fcmPlatform: platform || 'unknown',
          fcmTokenUpdatedAt: timestamp ? new Date(timestamp) : new Date(),
          updatedAt: new Date()
        }
      },
      { upsert: false } // Don't create user if doesn't exist
    );
    
    if (updateResult.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log(`FCM token updated for user ${userId} (platform: ${platform || 'unknown'})`);
    
    res.status(200).json({ 
      success: true, 
      message: 'FCM token stored successfully',
      userId: userId,
      platform: platform || 'unknown'
    });
  } catch (err) {
    console.error('Error storing FCM token:', err);
    res.status(500).json({ error: 'Server error while storing FCM token' });
  }
});

// Delete FCM token for a user (on logout)
app.delete('/api/users/fcm-token', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.body;
    
    // Validate required fields
    if (!userId) {
      return res.status(400).json({ 
        error: 'Missing required field: userId is required' 
      });
    }
    
    // Verify the userId matches the authenticated user
    const authenticatedUserId = req.user.id;
    if (userId !== authenticatedUserId) {
      return res.status(403).json({ 
        error: 'Forbidden: Cannot delete FCM token for another user' 
      });
    }
    
    // Validate userId format (MongoDB ObjectId)
    if (!ObjectId.isValid(userId)) {
      return res.status(400).json({ error: 'Invalid userId format' });
    }
    
    // Remove FCM token from users collection
    const updateResult = await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { 
        $unset: { 
          fcmToken: "",
          fcmPlatform: "",
          fcmTokenUpdatedAt: ""
        },
        $set: {
          updatedAt: new Date()
        }
      }
    );
    
    if (updateResult.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log(`FCM token deleted for user ${userId}`);
    
    res.status(200).json({ 
      success: true, 
      message: 'FCM token deleted successfully',
      userId: userId
    });
  } catch (err) {
    console.error('Error deleting FCM token:', err);
    res.status(500).json({ error: 'Server error while deleting FCM token' });
  }
});

// Helper function to get client IP address
function getClientIp(req) {
  // Check X-Forwarded-For header (for proxies like ngrok)
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    // X-Forwarded-For can contain multiple IPs, take the first one
    const ips = forwarded.split(',');
    const clientIp = ips[0].trim();
    // Validate IPv4 format
    if (/^(\d{1,3}\.){3}\d{1,3}$/.test(clientIp)) {
      return clientIp;
    }
  }
  
  // Check X-Real-IP header (some proxies use this)
  const realIp = req.headers['x-real-ip'];
  if (realIp && /^(\d{1,3}\.){3}\d{1,3}$/.test(realIp)) {
    return realIp;
  }
  
  // Fallback to req.ip (works with trust proxy enabled)
  if (req.ip && /^(\d{1,3}\.){3}\d{1,3}$/.test(req.ip)) {
    return req.ip;
  }
  
  // Last resort: try req.connection.remoteAddress
  const remoteAddress = req.connection?.remoteAddress || req.socket?.remoteAddress;
  if (remoteAddress && /^(\d{1,3}\.){3}\d{1,3}$/.test(remoteAddress)) {
    return remoteAddress;
  }
  
  return null;
}

// Device Tracking Routes
// Track device login/usage
app.post('/api/devices/track', authenticateToken, async (req, res) => {
  try {
    const { userId, deviceInfo } = req.body;
    const authenticatedUserId = req.user.id;
    
    // Validate required fields
    if (!userId || !deviceInfo) {
      return res.status(400).json({ 
        error: 'Missing required fields: userId and deviceInfo are required' 
      });
    }
    
    // Verify the userId matches the authenticated user
    if (userId.toString() !== authenticatedUserId.toString()) {
      return res.status(403).json({ 
        error: 'Forbidden: Cannot track device for another user' 
      });
    }
    
    // Validate userId format
    if (!ObjectId.isValid(userId)) {
      return res.status(400).json({ error: 'Invalid userId format' });
    }
    
    const deviceId = deviceInfo.deviceId || deviceInfo.device_id || 'unknown';
    const platform = deviceInfo.platform || 'unknown';
    
    // Get client IP address (especially important for web devices)
    const clientIp = getClientIp(req);
    
    // Create or update device record
    const deviceRecord = {
      userId: new ObjectId(userId),
      deviceId: deviceId,
      platform: platform,
      deviceModel: deviceInfo.deviceModel || deviceInfo.device_model || 'Unknown',
      deviceName: deviceInfo.deviceName || deviceInfo.device_name || 'Unknown',
      osVersion: deviceInfo.osVersion || deviceInfo.os_version || 'Unknown',
      appVersion: deviceInfo.appVersion || deviceInfo.app_version || '1.0.16',
      manufacturer: deviceInfo.manufacturer || '',
      brand: deviceInfo.brand || '',
      androidVersion: deviceInfo.androidVersion || deviceInfo.android_version || '',
      sdkInt: deviceInfo.sdkInt || deviceInfo.sdk_int || null,
      iosVersion: deviceInfo.iosVersion || deviceInfo.ios_version || '',
      systemName: deviceInfo.systemName || deviceInfo.system_name || '',
      // Web-specific fields
      browserName: deviceInfo.browserName || '',
      browserVersion: deviceInfo.browserVersion || '',
      userAgent: deviceInfo.userAgent || '',
      language: deviceInfo.language || '',
      // IP address (captured from server for web, can be set by client for mobile)
      ipAddress: clientIp || deviceInfo.ipAddress || deviceInfo.ip_address || '',
      lastLoginAt: new Date(),
      firstSeenAt: new Date(), // Will be set only on first insert
      loginCount: 1, // Will be incremented
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    
    // Check if device already exists for this user
    const existingDevice = await db.collection('devices').findOne({
      userId: new ObjectId(userId),
      deviceId: deviceId,
    });
    
    if (existingDevice) {
      // Update existing device
      await db.collection('devices').updateOne(
        { _id: existingDevice._id },
        {
          $set: {
            ...deviceRecord,
            firstSeenAt: existingDevice.firstSeenAt || new Date(), // Keep original firstSeenAt
          },
          $inc: { loginCount: 1 },
        }
      );
    } else {
      // Insert new device
      await db.collection('devices').insertOne(deviceRecord);
    }
    
    console.log(`✅ Device tracked for user ${userId} (${platform} - ${deviceRecord.deviceModel})`);
    
    res.status(200).json({ 
      success: true, 
      message: 'Device tracked successfully',
      deviceId: deviceId,
      platform: platform,
    });
  } catch (err) {
    console.error('Error tracking device:', err);
    res.status(500).json({ error: 'Server error while tracking device' });
  }
});

// Get device statistics (Admin only)
app.get('/api/admin/devices/stats', authenticateToken, async (req, res) => {
  try {
    // Check if user is admin
    const user = await db.collection('users').findOne({ _id: new ObjectId(req.user.id) });
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }
    
    // Get total device count
    const totalDevices = await db.collection('devices').countDocuments();
    
    // Get devices by platform
    const androidDevices = await db.collection('devices').countDocuments({ platform: 'android' });
    const iosDevices = await db.collection('devices').countDocuments({ platform: 'ios' });
    const webDevices = await db.collection('devices').countDocuments({ platform: 'web' });
    
    // Get unique users with devices
    const uniqueUsers = await db.collection('devices').distinct('userId');
    
    // Get devices with multiple logins (same account on multiple devices)
    const devicesByUser = await db.collection('devices').aggregate([
      {
        $group: {
          _id: '$userId',
          deviceCount: { $sum: 1 },
          devices: { $push: '$$ROOT' }
        }
      },
      {
        $match: { deviceCount: { $gt: 1 } }
      }
    ]).toArray();
    
    const multiDeviceUsers = devicesByUser.length;
    const totalMultiDeviceCount = devicesByUser.reduce((sum, user) => sum + user.deviceCount, 0);
    
    // Get recent device logins (last 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentLogins = await db.collection('devices').countDocuments({
      lastLoginAt: { $gte: oneDayAgo }
    });
    
    res.status(200).json({
      totalDevices,
      platformBreakdown: {
        android: androidDevices,
        ios: iosDevices,
        web: webDevices,
        other: totalDevices - androidDevices - iosDevices - webDevices,
      },
      uniqueUsers: uniqueUsers.length,
      multiDeviceUsers,
      totalMultiDeviceCount,
      recentLogins24h: recentLogins,
    });
  } catch (err) {
    console.error('Error getting device statistics:', err);
    res.status(500).json({ error: 'Server error while getting device statistics' });
  }
});

// Get devices for a specific user (Admin only)
app.get('/api/admin/devices/user/:userId', authenticateToken, async (req, res) => {
  try {
    // Check if user is admin
    const user = await db.collection('users').findOne({ _id: new ObjectId(req.user.id) });
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }
    
    const targetUserId = req.params.userId;
    
    if (!ObjectId.isValid(targetUserId)) {
      return res.status(400).json({ error: 'Invalid userId format' });
    }
    
    const devices = await db.collection('devices')
      .find({ userId: new ObjectId(targetUserId) })
      .sort({ lastLoginAt: -1 })
      .toArray();
    
    const formattedDevices = devices.map(device => ({
      _id: device._id.toString(),
      deviceId: device.deviceId,
      platform: device.platform,
      deviceModel: device.deviceModel,
      deviceName: device.deviceName,
      osVersion: device.osVersion,
      appVersion: device.appVersion,
      manufacturer: device.manufacturer || '',
      brand: device.brand || '',
      androidVersion: device.androidVersion || '',
      iosVersion: device.iosVersion || '',
      browserName: device.browserName || '',
      browserVersion: device.browserVersion || '',
      userAgent: device.userAgent || '',
      language: device.language || '',
      ipAddress: device.ipAddress || '',
      loginCount: device.loginCount || 1,
      firstSeenAt: device.firstSeenAt ? device.firstSeenAt.toISOString() : null,
      lastLoginAt: device.lastLoginAt ? device.lastLoginAt.toISOString() : null,
      createdAt: device.createdAt ? device.createdAt.toISOString() : null,
    }));
    
    res.status(200).json({
      userId: targetUserId,
      deviceCount: formattedDevices.length,
      devices: formattedDevices,
    });
  } catch (err) {
    console.error('Error getting user devices:', err);
    res.status(500).json({ error: 'Server error while getting user devices' });
  }
});

// Get all devices with user info (Admin only)
app.get('/api/admin/devices', authenticateToken, async (req, res) => {
  try {
    // Check if user is admin
    const user = await db.collection('users').findOne({ _id: new ObjectId(req.user.id) });
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }
    
    const limit = parseInt(req.query.limit) || 100;
    const skip = parseInt(req.query.skip) || 0;
    const platform = req.query.platform; // Optional filter
    
    const query = platform ? { platform: platform } : {};
    
    const devices = await db.collection('devices')
      .find(query)
      .sort({ lastLoginAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();
    
    // Get user info for each device
    const devicesWithUsers = await Promise.all(devices.map(async (device) => {
      const deviceUser = await db.collection('users').findOne(
        { _id: device.userId },
        { projection: { password: 0 } }
      );
      
      return {
        _id: device._id.toString(),
        deviceId: device.deviceId,
        platform: device.platform,
        deviceModel: device.deviceModel,
        deviceName: device.deviceName,
        osVersion: device.osVersion,
        appVersion: device.appVersion,
        manufacturer: device.manufacturer || '',
        brand: device.brand || '',
        browserName: device.browserName || '',
        browserVersion: device.browserVersion || '',
        userAgent: device.userAgent || '',
        language: device.language || '',
        ipAddress: device.ipAddress || '',
        loginCount: device.loginCount || 1,
        firstSeenAt: device.firstSeenAt ? device.firstSeenAt.toISOString() : null,
        lastLoginAt: device.lastLoginAt ? device.lastLoginAt.toISOString() : null,
        user: deviceUser ? {
          _id: deviceUser._id.toString(),
          email: deviceUser.email,
          displayName: deviceUser.displayName || deviceUser.username || '',
          username: deviceUser.username || '',
        } : null,
      };
    }));
    
    const total = await db.collection('devices').countDocuments(query);
    
    res.status(200).json({
      devices: devicesWithUsers,
      total,
      limit,
      skip,
      hasMore: skip + limit < total,
    });
  } catch (err) {
    console.error('Error getting all devices:', err);
    res.status(500).json({ error: 'Server error while getting devices' });
  }
});

// Chat Routes
app.get('/api/chats', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const chats = await db.collection('chats')
      .find({ members: new ObjectId(userId) })
      .toArray();
    
    // Format chats to include type field for frontend
    const formattedChats = chats.map(chat => ({
      _id: chat._id.toString(),
      id: chat._id.toString(),
      name: chat.name,
      type: chat.type || 'group', // Default to 'group' for existing chats
      members: chat.members.map(id => id.toString()),
      createdBy: chat.createdBy ? chat.createdBy.toString() : null,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      lastMessage: chat.lastMessage,
      lastMessageTime: chat.lastMessageTime
    }));
    
    res.json(formattedChats);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Middleware to log POST /api/chats requests BEFORE authentication
app.use('/api/chats', (req, res, next) => {
  if (req.method === 'POST') {
    console.error('\n\n🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
    console.error('🔥 POST /api/chats REQUEST RECEIVED (BEFORE AUTH)');
    console.error('🔥 Timestamp:', new Date().toISOString());
    console.error('🔥 Method:', req.method);
    console.error('🔥 Path:', req.path);
    console.error('🔥 Headers:', {
      'authorization': req.headers.authorization ? 'Present' : 'Missing',
      'content-type': req.headers['content-type'],
      'content-length': req.headers['content-length']
    });
    console.error('🔥 Raw body exists?', !!req.body);
    console.error('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥\n');
  }
  next();
});

// Create a new chat
app.post('/api/chats', authenticateToken, async (req, res) => {
  // Log immediately - use console.log to ensure it appears
  console.log('\n\n🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
  console.log('🔥🔥🔥 POST /api/chats HANDLER CALLED 🔥🔥🔥');
  console.log('🔥 Timestamp:', new Date().toISOString());
  console.log('🔥 Request body type:', typeof req.body);
  console.log('🔥 Request body:', JSON.stringify(req.body));
  console.log('🔥 Request body keys:', req.body ? Object.keys(req.body) : 'null');
  console.log('🔥 Request user:', JSON.stringify(req.user));
  console.log('🔥 Request user id:', req.user?.id);
  console.log('🔥 Content-Type header:', req.headers['content-type']);
  console.log('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥\n');
  
  // Check if body is empty or undefined
  if (!req.body || Object.keys(req.body).length === 0) {
    console.error('❌❌❌ REQUEST BODY IS EMPTY OR UNDEFINED ❌❌❌');
    return res.status(400).json({ 
      error: 'Request body is required',
      received: req.body,
      bodyType: typeof req.body
    });
  }
  
  try {
    const { type, name, members } = req.body;
    
    console.log('🔥🔥🔥 AFTER DESTRUCTURING 🔥🔥🔥');
    console.log('🔥 type:', type, '(type:', typeof type, ')');
    console.log('🔥 name:', name, '(type:', typeof name, ')');
    console.log('🔥 members:', members, '(type:', typeof members, ')');
    console.log('🔥 members isArray:', Array.isArray(members));
    console.log('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥\n');
    
    // Validate authenticated user
    if (!req.user || !req.user.id) {
      console.log('[POST /api/chats] Validation failed: no authenticated user');
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    // Intercept response to log it
    const originalJson = res.json.bind(res);
    res.json = function(data) {
      console.error('\n📤📤📤 SENDING RESPONSE 📤📤📤');
      console.error('Status:', res.statusCode);
      console.error('Response data:', JSON.stringify(data, null, 2));
      console.error('Response size:', JSON.stringify(data).length, 'bytes');
      console.error('📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤📤\n');
      return originalJson(data);
    };
    
    // Validate name - check if empty, but we'll generate default after members are processed
    let needsDefaultName = !name || (typeof name === 'string' && name.trim().length === 0);
    
    // Trim the name if it exists
    let trimmedName = name && typeof name === 'string' ? name.trim() : String(name || '');
    
    // Don't error on empty name yet - we'll generate default after processing members
    // Just log that we need a default
    if (needsDefaultName || trimmedName.length === 0) {
      console.log('\n⚠️⚠️⚠️ WARNING: Empty chat name detected, will generate default ⚠️⚠️⚠️');
      console.log('Original name:', name);
      trimmedName = ''; // Will be set later
    }
    
    console.log('🔥 NAME VALIDATION: needsDefaultName=', needsDefaultName, 'trimmedName=', trimmedName);
    
    // Validate members array
    if (!members || !Array.isArray(members)) {
      const errorResponse = { 
        error: 'Members array is required',
        received: { type, name, members, membersType: typeof members, isArray: Array.isArray(members) }
      };
      console.error('\n❌❌❌ VALIDATION FAILED: invalid members array ❌❌❌');
      console.error('Members value:', members);
      console.error('Members type:', typeof members);
      console.error('Is array?', Array.isArray(members));
      console.error('Error response:', JSON.stringify(errorResponse, null, 2));
      console.error('========================================\n');
      return res.status(400).json(errorResponse);
    }
    
    // Filter out empty/null members and validate ObjectIds
    const validMembers = members.filter(memberId => {
      const isValid = memberId != null && 
             typeof memberId === 'string' && 
             memberId.trim().length > 0 && 
             ObjectId.isValid(memberId);
      if (!isValid && memberId != null) {
        console.log('[POST /api/chats] Invalid member ID filtered out:', memberId);
      }
      return isValid;
    });
    
    console.log('[POST /api/chats] Valid members after filtering:', validMembers);
    
    // Convert to ObjectIds
    const memberObjectIds = validMembers.map(id => new ObjectId(id));
    
    // Ensure the current user is included in members
    let currentUserId;
    try {
      if (!ObjectId.isValid(req.user.id)) {
        console.log('[POST /api/chats] Validation failed: invalid current user ID:', req.user.id);
        return res.status(400).json({ error: 'Invalid authenticated user ID' });
      }
      currentUserId = new ObjectId(req.user.id);
    } catch (err) {
      console.log('[POST /api/chats] Validation failed: cannot convert current user ID to ObjectId:', req.user.id, err);
      return res.status(400).json({ error: 'Invalid authenticated user ID format' });
    }
    
    const currentUserIdStr = currentUserId.toString();
    const hasCurrentUser = memberObjectIds.some(id => id.toString() === currentUserIdStr);
    
    if (!hasCurrentUser) {
      console.log('[POST /api/chats] Adding current user to members:', currentUserIdStr);
      memberObjectIds.push(currentUserId);
    } else {
      console.log('[POST /api/chats] Current user already in members');
    }
    
    // Remove duplicates (in case current user was sent in members array)
    const uniqueMemberIds = [];
    const seenIds = new Set();
    for (const id of memberObjectIds) {
      const idStr = id.toString();
      if (!seenIds.has(idStr)) {
        seenIds.add(idStr);
        uniqueMemberIds.push(id);
      }
    }
    const finalMemberIds = uniqueMemberIds;
    
    // CRITICAL: Ensure current user is ALWAYS in finalMemberIds
    const hasCurrentUserInFinal = finalMemberIds.some(id => id.toString() === currentUserIdStr);
    if (!hasCurrentUserInFinal) {
      console.error('[POST /api/chats] ⚠️ WARNING: Current user not in finalMemberIds! Adding now...');
      finalMemberIds.push(currentUserId);
    }
    
    console.log('[POST /api/chats] Final member IDs (unique):', finalMemberIds.map(id => id.toString()));
    console.log('[POST /api/chats] Current user ID:', currentUserIdStr);
    console.log('[POST /api/chats] Current user in finalMemberIds:', finalMemberIds.some(id => id.toString() === currentUserIdStr));
    
    // Validate member count after adding current user
    if (finalMemberIds.length === 0) {
      console.log('[POST /api/chats] Validation failed: no valid members');
      return res.status(400).json({ error: 'At least one valid member ID is required' });
    }
    
    // Validate that current user is in the members list
    if (!finalMemberIds.some(id => id.toString() === currentUserIdStr)) {
      console.error('[POST /api/chats] ❌ CRITICAL ERROR: Current user not in finalMemberIds after all processing!');
      return res.status(500).json({ error: 'Failed to add creator to group members' });
    }
    
    // For private chats, ensure exactly 2 members
    if (type === 'private') {
      if (finalMemberIds.length !== 2) {
        const errorResponse = { 
          error: `Private chats must have exactly 2 members. Got ${finalMemberIds.length} members.`,
          details: {
            originalMembers: members,
            validMembers: validMembers,
            finalMemberIds: finalMemberIds.map(id => id.toString()),
            currentUserId: currentUserIdStr
          }
        };
        console.error('\n❌❌❌ VALIDATION FAILED: private chat needs exactly 2 members ❌❌❌');
        console.error('Got', finalMemberIds.length, 'members');
        console.error('Final member IDs:', finalMemberIds.map(id => id.toString()));
        console.error('Original members:', members);
        console.error('Valid members after filter:', validMembers);
        console.error('Current user ID:', currentUserIdStr);
        console.error('Error response:', JSON.stringify(errorResponse, null, 2));
        console.error('========================================\n');
        return res.status(400).json(errorResponse);
      }
      
      // Generate default name if needed (after we have finalMemberIds)
      if (!trimmedName || trimmedName.length === 0) {
        console.error('\n⚠️⚠️⚠️ GENERATING DEFAULT NAME FOR PRIVATE CHAT ⚠️⚠️⚠️');
        try {
          // Get the other user (not the current user)
          const otherUserId = finalMemberIds.find(id => id.toString() !== currentUserIdStr);
          if (otherUserId) {
            const otherUser = await db.collection('users').findOne(
              { _id: otherUserId },
              { projection: { username: 1, displayName: 1, email: 1, name: 1 } }
            );
            if (otherUser) {
              const otherUserName = otherUser.displayName || 
                                   otherUser.username || 
                                   otherUser.name || 
                                   (otherUser.email ? otherUser.email.split('@')[0] : null) || 
                                   'User';
              trimmedName = `Chat with ${otherUserName}`;
              console.error('Generated default name:', trimmedName);
            } else {
              trimmedName = 'Chat with User';
              console.error('User not found, using:', trimmedName);
            }
          } else {
            trimmedName = 'Chat with User';
            console.error('Other user ID not found, using:', trimmedName);
          }
        } catch (err) {
          console.error('Error fetching other user for default name:', err);
          trimmedName = 'Chat with User';
        }
      }
    } else {
      // For group chats, ensure at least 1 member (after adding creator)
      if (finalMemberIds.length < 1) {
        console.log('[POST /api/chats] Validation failed: group chat needs at least 1 member');
        return res.status(400).json({ error: 'Group chats must have at least one member' });
      }
    }
    
    // For private chats, check if chat already exists between the two users
    if (type === 'private' && finalMemberIds.length === 2) {
      console.log('[POST /api/chats] Checking for existing private chat between:', finalMemberIds.map(id => id.toString()));
      
      const existingChat = await db.collection('chats').findOne({
        type: 'private',
        members: { 
          $all: finalMemberIds,
          $size: 2
        }
      });
      
      if (existingChat) {
        console.log('[POST /api/chats] Found existing chat:', existingChat._id.toString());
        return res.json({
          _id: existingChat._id.toString(),
          id: existingChat._id.toString(),
          name: existingChat.name,
          type: existingChat.type,
          members: existingChat.members.map(id => id.toString()),
          createdBy: existingChat.createdBy.toString(),
          createdAt: existingChat.createdAt,
          updatedAt: existingChat.updatedAt,
          lastMessage: existingChat.lastMessage,
          lastMessageTime: existingChat.lastMessageTime
        });
      } else {
        console.log('[POST /api/chats] No existing chat found, creating new one');
      }
    }
    
    // Create memberRoles object - creator is group admin (not app admin), others are members
    const memberRoles = {};
    
    // CRITICAL: Always set creator as admin FIRST
    memberRoles[currentUserIdStr] = 'admin'; // Creator is group admin (group-level, not app-level)
    console.log('[POST /api/chats] Set creator role:', currentUserIdStr, '-> admin');
    
    // Set roles for all other members
    for (const memberId of finalMemberIds) {
      const memberIdStr = memberId.toString();
      if (memberIdStr !== currentUserIdStr) {
        memberRoles[memberIdStr] = 'member'; // Others are members
        console.log('[POST /api/chats] Set member role:', memberIdStr, '-> member');
      }
    }
    
    // Validate that creator role is set
    if (memberRoles[currentUserIdStr] !== 'admin') {
      console.error('[POST /api/chats] ❌ CRITICAL ERROR: Creator role not set correctly!');
      memberRoles[currentUserIdStr] = 'admin'; // Force set it
    }
    
    console.log('[POST /api/chats] Final memberRoles:', JSON.stringify(memberRoles));
    console.log('[POST /api/chats] Creator role check:', memberRoles[currentUserIdStr] === 'admin' ? '✅ PASS' : '❌ FAIL');
    
    // Create new chat
    const chat = {
      type: type || 'group',
      name: trimmedName,
      members: finalMemberIds,
      memberRoles: memberRoles, // Store member roles
      createdBy: currentUserId,
      createdAt: new Date(),
      updatedAt: new Date(),
      lastMessage: null,
      lastMessageTime: null
    };
    
    console.log('[POST /api/chats] Creating chat with data:', {
      type: chat.type,
      name: chat.name,
      members: chat.members.map(id => id.toString()),
      createdBy: chat.createdBy.toString()
    });
    
    const result = await db.collection('chats').insertOne(chat);
    const createdChat = await db.collection('chats').findOne({ _id: result.insertedId });
    
    if (!createdChat) {
      console.error('[POST /api/chats] Failed to retrieve created chat');
      return res.status(500).json({ error: 'Failed to create chat' });
    }
    
    // FINAL VALIDATION: Ensure current user is in members and has admin role
    const createdMembers = createdChat.members.map(id => id.toString());
    const createdMemberRoles = createdChat.memberRoles || {};
    const creatorInMembers = createdMembers.includes(currentUserIdStr);
    const creatorIsAdmin = createdMemberRoles[currentUserIdStr] === 'admin';
    
    console.log('[POST /api/chats] ✅ Final validation:');
    console.log('  - Creator in members:', creatorInMembers ? '✅ YES' : '❌ NO');
    console.log('  - Creator is admin:', creatorIsAdmin ? '✅ YES' : '❌ NO');
    console.log('  - Members:', createdMembers);
    console.log('  - Member roles:', JSON.stringify(createdMemberRoles));
    
    if (!creatorInMembers) {
      console.error('[POST /api/chats] ❌ CRITICAL: Creator not in members after creation! Fixing...');
      // Fix it by updating the chat
      await db.collection('chats').updateOne(
        { _id: result.insertedId },
        { 
          $addToSet: { members: currentUserId },
          $set: { [`memberRoles.${currentUserIdStr}`]: 'admin', updatedAt: new Date() }
        }
      );
      // Re-fetch the chat
      const fixedChat = await db.collection('chats').findOne({ _id: result.insertedId });
      if (fixedChat) {
        console.log('[POST /api/chats] ✅ Fixed: Creator added to members');
        return res.status(201).json({
          _id: fixedChat._id.toString(),
          id: fixedChat._id.toString(),
          name: fixedChat.name,
          type: fixedChat.type,
          members: fixedChat.members.map(id => id.toString()),
          memberRoles: fixedChat.memberRoles || {},
          createdBy: fixedChat.createdBy.toString(),
          createdAt: fixedChat.createdAt,
          updatedAt: fixedChat.updatedAt,
          lastMessage: fixedChat.lastMessage,
          lastMessageTime: fixedChat.lastMessageTime
        });
      }
    }
    
    if (!creatorIsAdmin) {
      console.error('[POST /api/chats] ❌ CRITICAL: Creator not admin after creation! Fixing...');
      // Fix it by updating the chat
      await db.collection('chats').updateOne(
        { _id: result.insertedId },
        { 
          $set: { [`memberRoles.${currentUserIdStr}`]: 'admin', updatedAt: new Date() }
        }
      );
      // Re-fetch the chat
      const fixedChat = await db.collection('chats').findOne({ _id: result.insertedId });
      if (fixedChat) {
        console.log('[POST /api/chats] ✅ Fixed: Creator set as admin');
        return res.status(201).json({
          _id: fixedChat._id.toString(),
          id: fixedChat._id.toString(),
          name: fixedChat.name,
          type: fixedChat.type,
          members: fixedChat.members.map(id => id.toString()),
          memberRoles: fixedChat.memberRoles || {},
          createdBy: fixedChat.createdBy.toString(),
          createdAt: fixedChat.createdAt,
          updatedAt: fixedChat.updatedAt,
          lastMessage: fixedChat.lastMessage,
          lastMessageTime: fixedChat.lastMessageTime
        });
      }
    }
    
    console.log('[POST /api/chats] Chat created successfully:', createdChat._id.toString());
    
    res.status(201).json({
      _id: createdChat._id.toString(),
      id: createdChat._id.toString(),
      name: createdChat.name,
      type: createdChat.type,
      members: createdChat.members.map(id => id.toString()),
      memberRoles: createdChat.memberRoles || {},
      createdBy: createdChat.createdBy.toString(),
      createdAt: createdChat.createdAt,
      updatedAt: createdChat.updatedAt,
      lastMessage: createdChat.lastMessage,
      lastMessageTime: createdChat.lastMessageTime
    });
  } catch (err) {
    console.error('\n❌❌❌ UNEXPECTED ERROR IN POST /api/chats ❌❌❌');
    console.error('Error:', err);
    console.error('Error message:', err.message);
    console.error('Error stack:', err.stack);
    
    let errorResponse;
    // Provide more specific error messages
    if (err.message && err.message.includes('ObjectId')) {
      errorResponse = { error: 'Invalid member ID format: ' + err.message };
    } else {
      errorResponse = { error: 'Server error: ' + err.message };
    }
    
    console.error('Sending error response:', JSON.stringify(errorResponse, null, 2));
    console.error('========================================\n');
    
    if (err.message && err.message.includes('ObjectId')) {
      return res.status(400).json(errorResponse);
    }
    res.status(500).json(errorResponse);
  }
});

// Find existing chat between two users
app.post('/api/chats/find-existing', authenticateToken, async (req, res) => {
  try {
    const { userId1, userId2 } = req.body;
    
    if (!userId1 || !userId2) {
      return res.status(400).json({ error: 'Both userId1 and userId2 are required' });
    }
    
    // Find chat where both users are members and it's a private chat
    const chat = await db.collection('chats').findOne({
      type: 'private',
      members: { 
        $all: [new ObjectId(userId1), new ObjectId(userId2)],
        $size: 2
      }
    });
    
    if (chat) {
      res.json({
        chat: {
          _id: chat._id.toString(),
          id: chat._id.toString(),
          name: chat.name,
          type: chat.type,
          members: chat.members.map(id => id.toString()),
          createdBy: chat.createdBy.toString(),
          createdAt: chat.createdAt,
          updatedAt: chat.updatedAt,
          lastMessage: chat.lastMessage,
          lastMessageTime: chat.lastMessageTime
        }
      });
    } else {
      res.status(404).json({ message: 'No existing chat found' });
    }
  } catch (err) {
    console.error('Find existing chat error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.put('/api/chats/:chatId/members', authenticateToken, async (req, res) => {
  try {
    const { userId, action } = req.body;
    const chatId = req.params.chatId;
    const currentUserIdStr = req.user.id;
    
    // Get chat to check permissions
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(chatId) });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    // Check if user is a member
    const isMember = chat.members.some(m => m.toString() === currentUserIdStr);
    if (!isMember) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }
    
    // Get user's role in the group (group admin is different from app admin)
    const memberRoles = chat.memberRoles || {};
    const userRole = memberRoles[currentUserIdStr] || 'member';
    const isCreator = chat.createdBy && chat.createdBy.toString() === currentUserIdStr;
    const isGroupAdmin = userRole === 'admin' || isCreator; // Group admin, not app admin
    const isGroupManager = userRole === 'manager' || isGroupAdmin;
    
    if (action === 'add') {
      // Only group admins and group managers can add members (not app admins)
      if (!isGroupManager) {
        return res.status(403).json({ error: 'Only group admins and managers can add members' });
      }
      
      // Check if user is already a member
      const isAlreadyMember = chat.members.some(m => m.toString() === userId);
      if (isAlreadyMember) {
        return res.status(400).json({ error: 'User is already a member' });
      }
      
      // Add member with default 'member' role
      await db.collection('chats').updateOne(
        { _id: new ObjectId(chatId) },
        { 
          $addToSet: { members: new ObjectId(userId) },
          $set: { 
            [`memberRoles.${userId}`]: 'member',
            updatedAt: new Date()
          }
        }
      );
      
      res.json({ success: true });
    } else if (action === 'remove') {
      // Only group admins can remove members (not app admins, only group admins)
      if (!isGroupAdmin) {
        return res.status(403).json({ error: 'Only group admins can remove members' });
      }
      
      // Creator cannot remove themselves
      if (isCreator && userId === currentUserIdStr) {
        return res.status(400).json({ error: 'Group creator cannot remove themselves' });
      }
      
      await db.collection('chats').updateOne(
        { _id: new ObjectId(chatId) },
        { 
          $pull: { members: new ObjectId(userId) },
          $unset: { [`memberRoles.${userId}`]: '' },
          $set: { updatedAt: new Date() }
        }
      );
      
      res.json({ success: true });
    } else {
      res.status(400).json({ error: 'Invalid action. Use "add" or "remove"' });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Update member role (only group creator can do this)
app.put('/api/chats/:chatId/members/:userId/role', authenticateToken, async (req, res) => {
  try {
    const chatId = req.params.chatId;
    const targetUserId = req.params.userId;
    const { role } = req.body;
    const currentUserIdStr = req.user.id;
    
    // Validate role
    if (!role || !['member', 'manager'].includes(role)) {
      return res.status(400).json({ error: 'Invalid role. Must be "member" or "manager"' });
    }
    
    // Get chat
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(chatId) });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    // Check if current user is the creator
    const isCreator = chat.createdBy && chat.createdBy.toString() === currentUserIdStr;
    if (!isCreator) {
      return res.status(403).json({ error: 'Only the group creator can change member roles' });
    }
    
    // Check if target user is a member
    const isMember = chat.members.some(m => m.toString() === targetUserId);
    if (!isMember) {
      return res.status(400).json({ error: 'User is not a member of this group' });
    }
    
    // Cannot change creator's role
    if (targetUserId === currentUserIdStr) {
      return res.status(400).json({ error: 'Cannot change the group creator\'s role' });
    }
    
    // Update role
    await db.collection('chats').updateOne(
      { _id: new ObjectId(chatId) },
      { 
        $set: { 
          [`memberRoles.${targetUserId}`]: role,
          updatedAt: new Date()
        }
      }
    );
    
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get broadcast messages for current user
app.get('/api/broadcasts', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    // Get broadcast messages for this user
    const broadcasts = await db.collection('messages')
      .find({
        type: 'broadcast',
        recipientId: new ObjectId(userId)
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    // Get sender names
    const broadcastsWithSenders = await Promise.all(
      broadcasts.map(async (broadcast) => {
        let senderName = 'Admin';
        if (broadcast.senderId) {
          try {
            const sender = await db.collection('users').findOne({ _id: new ObjectId(broadcast.senderId) });
            if (sender) {
              senderName = sender.displayName || sender.email || 'Admin';
            }
          } catch (e) {
            console.error('Error getting sender name:', e);
          }
        }
        
        return {
          id: broadcast._id.toString(),
          _id: broadcast._id.toString(),
          content: broadcast.content,
          senderId: broadcast.senderId?.toString(),
          senderName: senderName,
          createdAt: broadcast.createdAt,
          read: broadcast.read || false
        };
      })
    );
    
    const total = await db.collection('messages').countDocuments({
      type: 'broadcast',
      recipientId: new ObjectId(userId)
    });
    
    res.json({
      broadcasts: broadcastsWithSenders,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (err) {
    console.error('Error getting broadcasts:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Mark broadcast as read
app.patch('/api/broadcasts/:id/read', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const broadcastId = req.params.id;
    
    await db.collection('messages').updateOne(
      {
        _id: new ObjectId(broadcastId),
        recipientId: new ObjectId(userId),
        type: 'broadcast'
      },
      {
        $set: { read: true }
      }
    );
    
    res.json({ success: true });
  } catch (err) {
    console.error('Error marking broadcast as read:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Message Routes
app.get('/api/chats/:chatId/messages', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    const chatId = req.params.chatId;
    
    // Verify user is a member of the chat using `members`
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(req.user.id),
    });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found or access denied' });
    }
    
    let messages = await db.collection('messages')
      .find({ chatId })
      .sort({ createdAt: 1 })
      .skip(offset)
      .limit(limit)
      .toArray();
    // Format messages to include readBy and status
    messages = messages.map(m => {
      const formatted = {
        _id: m._id.toString(),
        id: m._id.toString(),
        chatId: m.chatId.toString(),
        senderId: m.senderId.toString(),
        content: m.content,
        type: m.type,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
        edited: m.edited || false,
        readBy: m.readBy ? m.readBy.map(id => id.toString()) : [],
        status: m.status || (m.readBy && m.readBy.length > 0 ? 'read' : 'sent')
      };
    // Rewrite media URLs for web clients to same-origin
      if (m.mediaUrl) {
        try {
          formatted.mediaUrl = rewriteMediaUrlIfNeeded(m.mediaUrl, req);
        } catch (_) {
          formatted.mediaUrl = m.mediaUrl;
        }
      }
      return formatted;
    });
    res.json(messages);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/chats/:chatId/messages', authenticateToken, async (req, res) => {
  try {
    const { content, messageType, mediaUrl, replyTo } = req.body;
    const userId = req.user.id;
    const chatId = req.params.chatId;
    
    // Verify user is a member of the chat using `members`
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(userId),
    });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found or access denied' });
    }
    
    // Get sender's display name
    const sender = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    const senderName = sender?.displayName || sender?.username || 'Someone';
    
    // If replyTo is provided, verify the message exists in this chat
    let replyToMessage = null;
    if (replyTo) {
      replyToMessage = await db.collection('messages').findOne({
        _id: new ObjectId(replyTo),
        chatId: chatId,
      });
      if (!replyToMessage) {
        return res.status(400).json({ error: 'Reply message not found' });
      }
    }
    
    const message = {
      chatId,
      senderId: userId,
      content,
      messageType: messageType || 'text',
      mediaUrl,
      replyTo: replyTo || null,
      reactions: {}, // Initialize empty reactions map
      createdAt: new Date(),
      readBy: [], // Initialize empty readBy array
      status: 'sent' // Initialize status as 'sent'
    };
    
    const result = await db.collection('messages').insertOne(message);
    
    const now = new Date();
    // Update chat's updatedAt and lastMessageTime
    await db.collection('chats').updateOne(
      { _id: new ObjectId(chatId) },
      { 
        $set: { 
          updatedAt: now,
          lastMessageTime: now, // This is the timestamp for display
          lastMessage: {
            content,
            senderId: userId, // Keep as string for easy matching
            senderName: senderName, // Add sender name for group chat display
            timestamp: now.toISOString(), // Also add timestamp to lastMessage object
            createdAt: now,
          },
        }
      }
    );
    
    // Get other chat members (not the sender)
    const otherMembers = chat.members
      .filter(m => m.toString() !== userId.toString())
      .map(m => m.toString());
    
    // Increment unread count for each recipient
    for (const memberId of otherMembers) {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(chatId) },
        { 
          $inc: { 
            [`unreadCount.${memberId}`]: 1 
          }
        }
      );
    }
    
    // Emit to sockets in the chat room, tailoring media URL per client
    try {
      const sockets = await io.in(chatId).fetchSockets();
      for (const socket of sockets) {
        const mediaUrlForThisSocket = rewriteMediaUrlIfNeeded(message.mediaUrl, socket.handshake?.headers || {});
        socket.emit('new_message', {
          id: result.insertedId.toString(),
          _id: result.insertedId.toString(),
          senderName: senderName,
          chatId: chatId.toString(),
          senderId: userId.toString(),
          content: message.content,
          messageType: message.messageType,
          mediaUrl: mediaUrlForThisSocket,
          replyTo: message.replyTo || null,
          reactions: message.reactions || {},
          createdAt: message.createdAt,
          readBy: [], // Include readBy array (empty for new messages)
          status: 'sent' // Include status (sent for new messages)
        });
      }
    } catch (e) {
      console.warn('Socket emission failed:', e?.message || e);
    }
    
    // Send notifications to other chat members
    console.log(`📨 Sending notifications to ${otherMembers.length} members`);
    console.log(`   Member IDs: ${JSON.stringify(otherMembers)}`);
    
    // Get all connected socket IDs for debugging
    const allRooms = io.sockets.adapter.rooms;
    console.log(`   Total Socket.IO rooms: ${allRooms.size}`);
    
    // Get list of online users (connected via Socket.IO)
    const onlineUsers = new Set();
    try {
      const sockets = await io.fetchSockets();
      for (const socket of sockets) {
        if (socket.userId) {
          onlineUsers.add(socket.userId.toString());
        }
      }
    } catch (e) {
      console.warn('Error fetching online users:', e?.message || e);
    }
    
    for (const memberId of otherMembers) {
      // Determine title based on chat type
      const title = (chat.type === 'group' || chat.type === 'Group') ? chat.name : senderName;
      const body = messageType === 'text' ? content : messageType === 'image' ? '📷 Image' : '📎 ' + messageType;
      
      console.log(`📤 Emitting chat_notification to room: "${memberId}" (sender: ${userId})`);
      console.log(`   Available rooms include memberId: ${allRooms.has(memberId)}`);
      
      // Send socket notification
      io.to(memberId).emit('chat_notification', {
        title: title,
        body: body,
        chatId: chatId,
        senderId: userId,
        senderName: senderName,
        messageType: messageType || 'text',
        timestamp: new Date(),
      });
      
      // Send FCM push notification if user is offline
      const isOnline = onlineUsers.has(memberId);
      if (!isOnline) {
        console.log(`📱 User ${memberId} is offline, sending FCM notification`);
        // Send FCM notification asynchronously (don't block response)
        sendFCMNotification(
          memberId,
          title,
          body,
          {
            chatId: chatId.toString(),
            senderId: userId.toString(),
            senderName: senderName,
            messageType: messageType || 'text',
            messageId: result.insertedId.toString(),
            type: 'chat_message',
          }
        ).catch(err => {
          console.error(`Error sending FCM to user ${memberId}:`, err.message);
        });
      } else {
        console.log(`✅ User ${memberId} is online, skipping FCM notification`);
      }
    }
    
    // Return created message (with media URL rewritten for web clients)
    const mediaUrlForWeb = rewriteMediaUrlIfNeeded(message.mediaUrl, req.headers || {});
    res.status(201).json({
      id: result.insertedId.toString(),
      replyTo: message.replyTo || null,
      reactions: message.reactions || {},
      _id: result.insertedId.toString(),
      chatId: chatId.toString(),
      senderId: userId.toString(),
      content: message.content,
      messageType: message.messageType,
      mediaUrl: mediaUrlForWeb,
      createdAt: message.createdAt,
      readBy: [], // Include readBy array (empty for new messages)
      status: 'sent' // Include status (sent for new messages)
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Add or remove reaction to a message
app.post('/api/messages/:messageId/reactions', authenticateToken, async (req, res) => {
  try {
    const { emoji } = req.body;
    const userId = req.user.id;
    const messageId = req.params.messageId;
    
    if (!emoji || typeof emoji !== 'string') {
      return res.status(400).json({ error: 'Emoji is required' });
    }
    
    // Get the message
    const message = await db.collection('messages').findOne({
      _id: new ObjectId(messageId),
    });
    
    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    // Verify user is a member of the chat
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(message.chatId),
      members: new ObjectId(userId),
    });
    
    if (!chat) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    // Initialize reactions if not exists
    const reactions = message.reactions || {};
    const userIdStr = userId.toString();
    
    // Initialize emoji array if not exists
    if (!reactions[emoji]) {
      reactions[emoji] = [];
    }
    
    // Toggle reaction: remove if exists, add if not
    const emojiReactions = reactions[emoji];
    const userIndex = emojiReactions.indexOf(userIdStr);
    
    if (userIndex >= 0) {
      // Remove reaction
      emojiReactions.splice(userIndex, 1);
      if (emojiReactions.length === 0) {
        delete reactions[emoji];
      }
    } else {
      // Add reaction
      emojiReactions.push(userIdStr);
    }
    
    // Update message
    await db.collection('messages').updateOne(
      { _id: new ObjectId(messageId) },
      { $set: { reactions: reactions } }
    );
    
    // Emit to socket room (works offline - if Socket.IO fails, reactions still saved to DB)
    try {
      io.to(message.chatId.toString()).emit('message_reaction', {
        messageId: messageId,
        emoji: emoji,
        userId: userIdStr,
        reactions: reactions,
        action: userIndex >= 0 ? 'removed' : 'added',
      });
    } catch (socketError) {
      // Socket.IO failure is non-critical - reactions are saved to MongoDB
      // Clients will sync reactions via polling (every 2 seconds)
      console.warn('Socket.IO emit failed for reaction (offline mode):', socketError);
    }
    
    res.status(200).json({
      success: true,
      reactions: reactions,
      action: userIndex >= 0 ? 'removed' : 'added',
    });
  } catch (err) {
    console.error('Error updating reaction:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Mark messages as read
app.patch('/api/chats/:chatId/messages/read', authenticateToken, async (req, res) => {
  try {
    const { messageIds } = req.body || {};
    const userId = req.user.id;
    const chatId = req.params.chatId;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ error: 'messageIds must be a non-empty array' });
    }

    // Verify user is a member of the chat
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(userId),
    });

    if (!chat) {
      return res.status(404).json({ error: 'Chat not found or access denied' });
    }

    // Convert to ObjectId and filter invalid ids
    const validIds = messageIds
      .filter(id => ObjectId.isValid(id))
      .map(id => new ObjectId(id));

    if (validIds.length === 0) {
      return res.status(400).json({ error: 'No valid messageIds provided' });
    }

    const result = await db.collection('messages').updateMany(
      { _id: { $in: validIds }, chatId },
      { $addToSet: { readBy: userId }, $set: { updatedAt: new Date() } }
    );

    res.status(200).json({
      message: 'Messages marked as read',
      updatedCount: result.modifiedCount,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Reset unread count for a chat
app.patch('/api/chats/:chatId/read', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const chatId = req.params.chatId;
    
    // Verify user is a member of the chat
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(userId),
    });
    
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found or access denied' });
    }
    
    // Reset unread count for this user
    // Ensure we use string format for consistency
    const userIdStr = userId.toString();
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(chatId) },
      { 
        $set: { 
          [`unreadCount.${userIdStr}`]: 0,
        } 
      }
    );
    
    console.log(`✅ Reset unread count for user ${userIdStr} in chat ${chatId}`);
    
    res.status(200).json({
      message: 'Unread count reset',
      chatId: chatId,
      userId: userIdStr,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Socket.IO authentication middleware
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  
  if (!token) {
    return next(new Error('Authentication error: Token required'));
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    // Handle both uid and id for compatibility, ensure it's always a string
    const userId = decoded.uid || decoded.id;
    socket.userId = userId ? userId.toString() : null;
    socket.user = decoded;
    
    if (!socket.userId) {
      return next(new Error('Authentication error: No user ID in token'));
    }
    
    console.log(`Socket authenticated for user: ${socket.userId} (type: ${typeof socket.userId})`);
    
    // Update user's online status
    if (db) {
      try {
        await db.collection('users').updateOne(
          { _id: new ObjectId(socket.userId) },
          { $set: { isOnline: true, lastSeen: new Date() } }
        );
      } catch (updateError) {
        console.error(`Failed to update online status for user ${socket.userId}:`, updateError);
        // Don't fail authentication if update fails
      }
    }
    
    next();
  } catch (error) {
    console.error('Socket authentication error:', error);
    return next(new Error('Authentication error: Invalid token'));
  }
});

// Socket.IO
io.on('connection', async (socket) => {
  console.log(`🔌 User connected: ${socket.userId}`);
  console.log(`   Socket ID: ${socket.id}`);
  console.log(`   User ID type: ${typeof socket.userId}`);
  console.log(`   User ID value: "${socket.userId}"`);
  
  // Join user to their personal room using socket.userId
  socket.join(socket.userId);
  console.log(`✅ User ${socket.userId} joined personal notification room: "${socket.userId}"`);
  
  // Also ensure user is joined to their MongoDB _id room (in case of format mismatch)
  // This is a safety measure - if socket.userId already matches _id, this is a no-op
  if (db && socket.userId) {
    try {
      const user = await db.collection('users').findOne({ _id: new ObjectId(socket.userId) });
      if (user) {
        const mongoId = user._id.toString();
        if (mongoId !== socket.userId) {
          socket.join(mongoId);
          console.log(`✅ User also joined MongoDB _id room: "${mongoId}"`);
        }
      }
    } catch (error) {
      console.error(`Error joining MongoDB _id room for user ${socket.userId}:`, error);
    }
  }
  
  // Debug: List all rooms after join
  setTimeout(() => {
    const rooms = Array.from(socket.rooms);
    console.log(`   User is in rooms: ${JSON.stringify(rooms)}`);
  }, 1000);
  
  // Join user to all their chat rooms
  if (db) {
    try {
      const chats = await db.collection('chats').find({
        members: new ObjectId(socket.userId)
      }).toArray();
      
      chats.forEach(chat => {
        socket.join(`chat:${chat._id}`);
      });
      
      console.log(`User ${socket.userId} joined ${chats.length} chat rooms`);
    } catch (error) {
      console.error('Error joining chat rooms:', error);
    }
  }
  
  socket.on('join_chat', (chatId) => {
    socket.join(chatId);
    console.log(`Client joined chat: ${chatId}`);
  });
  
  socket.on('leave_chat', (chatId) => {
    socket.leave(chatId);
    console.log(`Client left chat: ${chatId}`);
  });
  
  // Handle join_user event for notification room
  socket.on('join_user', (userId) => {
    socket.join(userId);
    console.log(`User ${socket.userId} joined notification room: ${userId}`);
  });
  
  socket.on('disconnect', async () => {
    console.log(`User disconnected: ${socket.userId}`);
    
    // Update user's online status
    if (db) {
      await db.collection('users').updateOne(
        { _id: new ObjectId(socket.userId) },
        { $set: { isOnline: false, lastSeen: new Date() } }
      );
    }
  });
});

// =========================================
// NOTIFICATION ENDPOINTS (Integrated into main server)
// =========================================

// Test notification endpoint
app.post('/api/notifications/test', async (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization token required' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Send test notification to the user
    io.to(decoded.id).emit('notification', {
      title: 'Test Notification',
      body: 'This is a test notification from the server',
      data: { type: 'test', timestamp: new Date() },
      timestamp: new Date(),
      senderId: decoded.id
    });
    
    return res.status(200).json({ success: true, message: 'Test notification sent' });
  } catch (error) {
    console.error('Test notification error:', error);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
});

// Send notification to specific user
app.post('/api/notifications/send', async (req, res) => {
  const { userId, title, body, data } = req.body;
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization token required' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    if (!userId || !title || !body) {
      return res.status(400).json({ error: 'userId, title, and body are required' });
    }
    
    // Send notification to user via socket
    io.to(userId).emit('notification', {
      title,
      body,
      data: data || {},
      timestamp: new Date(),
      senderId: decoded.id
    });
    
    // Store notification in database
    if (db) {
      await db.collection('notifications').insertOne({
        userId,
        title,
        body,
        data: data || {},
        timestamp: new Date(),
        senderId: decoded.id,
        read: false
      });
    }
    
    return res.status(200).json({ success: true, message: 'Notification sent' });
  } catch (error) {
    console.error('Send notification error:', error);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
});

// Send notification to chat room
app.post('/api/notifications/chat', async (req, res) => {
  const { chatId, title, body, data } = req.body;
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization token required' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    if (!chatId || !title || !body) {
      return res.status(400).json({ error: 'chatId, title, and body are required' });
    }
    
    // Send notification to chat room via socket
    io.to(`chat:${chatId}`).emit('chat_notification', {
      chatId,
      title,
      body,
      data: data || {},
      timestamp: new Date(),
      senderId: decoded.id
    });
    
    return res.status(200).json({ success: true, message: 'Chat notification sent' });
  } catch (error) {
    console.error('Send chat notification error:', error);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
});

// Get user's notifications
app.get('/api/notifications', async (req, res) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization token required' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    if (!db) {
      return res.status(500).json({ error: 'Database connection not available' });
    }
    
    // Get user's notifications
    const notifications = await db.collection('notifications')
      .find({ userId: decoded.id })
      .sort({ timestamp: -1 })
      .limit(50)
      .toArray();
    
    return res.status(200).json({ notifications });
  } catch (error) {
    console.error('Get notifications error:', error);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
});

// Mark notification as read
app.put('/api/notifications/:id/read', async (req, res) => {
  const { id } = req.params;
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization token required' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    if (!db) {
      return res.status(500).json({ error: 'Database connection not available' });
    }
    
    // Mark notification as read
    const result = await db.collection('notifications').updateOne(
      { _id: new ObjectId(id), userId: decoded.id },
      { $set: { read: true } }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    return res.status(200).json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    console.error('Mark notification as read error:', error);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
});

// Start server
const PORT = process.env.PORT || 3003;
const HOST = process.env.HOST || '0.0.0.0';

// Cloudflare Access protection for admin routes
const CF_ACCESS_CERTS_URL = process.env.CF_ACCESS_CERTS_URL || '';
const CF_ACCESS_AUD = process.env.CF_ACCESS_AUD || '';
const CF_ACCESS_REQUIRED = (process.env.CF_ACCESS_REQUIRED || 'false').toLowerCase() === 'true';

let jwks;
if (CF_ACCESS_CERTS_URL) {
  try {
    jwks = createRemoteJWKSet(new URL(CF_ACCESS_CERTS_URL));
    console.log('Cloudflare Access JWKS configured');
  } catch (e) {
    console.warn('Invalid CF_ACCESS_CERTS_URL provided');
  }
}

async function requireCloudflareAccess(req, res, next) {
  if (!CF_ACCESS_REQUIRED) {
    // Access check disabled (e.g., local dev)
    return next();
  }
  try {
    const assertion = req.headers['cf-access-jwt-assertion'];
    if (!assertion) {
      return res.status(401).json({ error: 'Cloudflare Access token required' });
    }
    if (!jwks || !CF_ACCESS_AUD) {
      return res.status(500).json({ error: 'Cloudflare Access not configured' });
    }
    const { payload } = await jwtVerify(assertion, jwks, {
      issuer: undefined, // Cloudflare Access uses team domain issuer; optional check
      audience: CF_ACCESS_AUD,
    });
    // Attach identity for auditing
    req.cfAccessIdentity = payload?.email || payload?.sub || 'unknown';
    return next();
  } catch (err) {
    console.error('Cloudflare Access verification failed:', err.message);
    return res.status(403).json({ error: 'Invalid Cloudflare Access token' });
  }
}

async function startServer() {
  await connectToMongo();
  server.listen(PORT, HOST, () => {
    console.log(`Server running on http://${HOST}:${PORT}`);
    console.log(`Allowed origins: ${allOrigins.join(', ')}`);
  });
}

// Example protected admin route (replace with your admin panel routes)
// Apply protection to all /admin routes
app.use('/admin', requireCloudflareAccess);
app.get('/admin/health', requireCloudflareAccess, (req, res) => {
  res.status(200).json({ status: 'ok', protectedBy: 'Cloudflare Access', user: req.cfAccessIdentity || null });
});

startServer();
startServer();