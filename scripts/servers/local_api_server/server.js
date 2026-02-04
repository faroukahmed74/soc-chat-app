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
const https = require('https');
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
// Make Firebase Admin accessible to all routes
app.set('firebaseAdmin', admin);

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
    
    // Don't compress binary media files (images, videos, audio) - they're already compressed
    const path = req.path || '';
    const mediaExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.mp4', '.webm', '.mp3', '.wav', '.ogg', '.pdf'];
    if (mediaExtensions.some(ext => path.toLowerCase().endsWith(ext))) {
      return false;
    }
    
    // Check content type header
    const contentType = res.getHeader('content-type') || '';
    if (contentType.startsWith('image/') || 
        contentType.startsWith('video/') || 
        contentType.startsWith('audio/') ||
        contentType === 'application/pdf') {
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
const UPLOADS_DIR = process.env.UPLOADS_DIR || path.join(__dirname, 'uploads');
try {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
} catch (e) {
  console.warn('Failed to ensure uploads directory exists:', e.message);
}

// Optimized static file serving with Range request support and caching
function serveMediaWithRange(dir) {
  return (req, res, next) => {
    const filePath = path.join(dir, req.path);
    
    // Check if file exists
    fs.stat(filePath, (err, stats) => {
      if (err || !stats.isFile()) {
        return next();
      }

      // Set caching headers for media files
      const maxAge = 31536000; // 1 year
      res.setHeader('Cache-Control', `public, max-age=${maxAge}, immutable`);
      res.setHeader('ETag', `"${stats.mtime.getTime()}-${stats.size}"`);
      res.setHeader('Last-Modified', stats.mtime.toUTCString());
      
      // Handle conditional requests (304 Not Modified)
      const ifNoneMatch = req.headers['if-none-match'];
      const ifModifiedSince = req.headers['if-modified-since'];
      
      if (ifNoneMatch && ifNoneMatch === res.getHeader('ETag')) {
        return res.status(304).end();
      }
      
      if (ifModifiedSince && new Date(ifModifiedSince) >= stats.mtime) {
        return res.status(304).end();
      }

      // Set content type
      const ext = path.extname(filePath).toLowerCase();
      const mimeTypes = {
        // Images
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.bmp': 'image/bmp',
        '.svg': 'image/svg+xml',
        // Videos
        '.mp4': 'video/mp4',
        '.webm': 'video/webm',
        '.mov': 'video/quicktime',
        '.avi': 'video/x-msvideo',
        '.mkv': 'video/x-matroska',
        // Audio
        '.mp3': 'audio/mpeg',
        '.wav': 'audio/wav',
        '.m4a': 'audio/mp4',
        '.ogg': 'audio/ogg',
        '.aac': 'audio/aac',
        // Documents
        '.pdf': 'application/pdf',
        '.doc': 'application/msword',
        '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.xls': 'application/vnd.ms-excel',
        '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.ppt': 'application/vnd.ms-powerpoint',
        '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.txt': 'text/plain',
        '.rtf': 'application/rtf',
        '.csv': 'text/csv',
        // Archives
        '.zip': 'application/zip',
        '.rar': 'application/x-rar-compressed',
        '.7z': 'application/x-7z-compressed',
        '.tar': 'application/x-tar',
        '.gz': 'application/gzip',
      };
      res.setHeader('Content-Type', mimeTypes[ext] || 'application/octet-stream');
      
      // Set Content-Disposition header for downloads (optional, helps with file naming)
      const fileName = path.basename(filePath);
      res.setHeader('Content-Disposition', `inline; filename="${fileName}"`);
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Content-Length', stats.size);

      // Handle Range requests for partial content (crucial for video/audio streaming)
      const range = req.headers.range;
      if (range) {
        const parts = range.replace(/bytes=/, '').split('-');
        let start = parseInt(parts[0], 10);
        let end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
        
        // Validate range bounds
        if (isNaN(start)) start = 0;
        if (isNaN(end)) end = stats.size - 1;
        if (start < 0) start = 0;
        if (end >= stats.size) end = stats.size - 1;
        if (start > end) {
          // Invalid range, send entire file
          const stream = fs.createReadStream(filePath);
          return stream.pipe(res);
        }
        
        const chunksize = (end - start) + 1;
        
        res.status(206); // Partial Content
        res.setHeader('Content-Range', `bytes ${start}-${end}/${stats.size}`);
        res.setHeader('Content-Length', chunksize);

        const stream = fs.createReadStream(filePath, { start, end });
        stream.pipe(res);
      } else {
        // No range request - stream entire file
        const stream = fs.createReadStream(filePath);
        stream.pipe(res);
      }
    });
  };
}

// Serve uploaded media with Range request support and caching
app.use('/uploads', serveMediaWithRange(UPLOADS_DIR));

// Backward-compatibility alias: serve legacy /chat_media paths from uploads/chat_media
app.use('/chat_media', serveMediaWithRange(path.join(UPLOADS_DIR, 'chat_media')));

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

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_here';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';
const SOCKET_TOKEN_REFRESH_GRACE_DAYS = parseInt(
  process.env.SOCKET_TOKEN_REFRESH_GRACE_DAYS || '30',
  10
);
const SOCKET_TOKEN_REFRESH_GRACE_MS = SOCKET_TOKEN_REFRESH_GRACE_DAYS * 24 * 60 * 60 * 1000;
const SOCKET_TOKEN_REFRESH_EVENT = 'auth:token_refreshed';

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
    // Expose FCM notification function for routes
    app.locals.sendFCMNotification = sendFCMNotification;
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
        // Ensure FCM function is also available
        app.locals.sendFCMNotification = sendFCMNotification;
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
    
    // Check if this is a call notification and get custom ringtone
    const isCallNotification = data.type === 'call_invitation';
    const customRingtone = user.customRingtone || null;
    const soundName = isCallNotification && customRingtone 
      ? customRingtone 
      : 'default';
    
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
        sound: soundName,
        customRingtone: customRingtone || 'default',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: isCallNotification ? 'call_notifications' : 'chat_notifications',
          priority: 'high',
          sound: soundName !== 'default' ? soundName : undefined,
          defaultSound: soundName === 'default',
          icon: '@mipmap/ic_launcher',
          color: isCallNotification ? '#4CAF50' : '#2196F3',
        },
      },
      apns: {
        payload: {
          aps: {
            // Firebase automatically creates 'alert' from 'notification' field above
            // Explicitly setting sound, badge, and other iOS-specific properties
            sound: soundName !== 'default' ? `${soundName}.caf` : (process.env.APNS_SOUND || 'default'),
            badge: 1,
            category: isCallNotification ? 'call_invitation' : (data?.category || 'default'),
            contentAvailable: 1, // Required for background notifications on iOS
            mutableContent: 1, // Required for notification extensions
            // Note: 'alert' is automatically generated by Firebase from the 'notification' field
          },
        },
        headers: {
          'apns-priority': '10', // High priority for immediate delivery
          'apns-push-type': 'alert', // Required for iOS 13+ (both dev and prod)
          'apns-expiration': '0', // Don't expire notifications
          // apns-topic is automatically set by Firebase based on bundle ID
        },
        fcmOptions: {
          analyticsLabel: isCallNotification ? 'ios_call_notification' : 'ios_notification',
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

// Helper function to generate Twilio TURN credentials via Token API
// This is the RECOMMENDED way to get Twilio TURN credentials
async function generateTwilioTurnCredentials(accountSid, authToken) {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
    const options = {
      hostname: 'api.twilio.com',
      path: `/2010-04-01/Accounts/${accountSid}/Tokens.json`,
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          if (res.statusCode === 200 || res.statusCode === 201) {
            const response = JSON.parse(data);
            if (response.ice_servers && response.ice_servers.length > 0) {
              console.log('✅ [TURN_CONFIG] Twilio Token API: Generated TURN credentials successfully');
              resolve(response.ice_servers);
            } else {
              reject(new Error('Twilio API returned no ice_servers'));
            }
          } else {
            reject(new Error(`Twilio API error: ${res.statusCode} - ${data}`));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', (e) => {
      console.error('❌ [TURN_CONFIG] Twilio Token API request failed:', e.message);
      reject(e);
    });

    req.end();
  });
}

// TURN Server Configuration Endpoint
// Returns TURN server configuration including ngrok TCP tunnel URL
app.get('/api/webrtc/turn-config', async (req, res) => {
  try {
    // TURN server credentials
    // Option 1: Self-hosted coturn (requires router port forwarding)
    // Option 2: Cloud TURN service (Twilio/Xirsys) - recommended for networks without router access
    const turnConfig = {
      // Self-hosted TURN (coturn)
      username: 'soc-chat-turn',
      password: 'yG5EJFUdLgT7xqXr',
      port: '3478',
      localIp: '10.120.4.230', // Local network IP
      publicIp: '41.33.106.54', // Public IP for direct access (media relay)
      
      // Cloud TURN Service (Twilio/Xirsys) - Set these if you don't have router access
      // Get credentials from: https://www.twilio.com/docs/stun-turn
      cloudTurnEnabled: process.env.CLOUD_TURN_ENABLED === 'true' || false,
      cloudTurnUsername: process.env.CLOUD_TURN_USERNAME || '',
      cloudTurnPassword: process.env.CLOUD_TURN_PASSWORD || '',
      cloudTurnUrls: process.env.CLOUD_TURN_URLS ? process.env.CLOUD_TURN_URLS.split(',') : [],
      // Twilio Account SID and Auth Token for Token API (recommended)
      twilioAccountSid: process.env.TWILIO_ACCOUNT_SID || '',
      twilioAuthToken: process.env.TWILIO_AUTH_TOKEN || '',
    };
    
    // Try to fetch ngrok TCP tunnel URL from ngrok API
    // Check both ports 4040 and 4041 (ngrok may use either)
    let tcpTunnelUrl = null;
    try {
      // Try port 4040 first, then 4041
      const ngrokPorts = [4040, 4041];
      let ngrokApiUrl = null;
      for (const port of ngrokPorts) {
        try {
          const testUrl = `http://localhost:${port}/api/tunnels`;
          const testResponse = await new Promise((resolve, reject) => {
            http.get(testUrl, (res) => {
              if (res.statusCode === 200) {
                ngrokApiUrl = testUrl;
                resolve(true);
              } else {
                reject(new Error(`Status ${res.statusCode}`));
              }
            }).on('error', reject);
          });
          if (ngrokApiUrl) break;
        } catch (e) {
          // Try next port
          continue;
        }
      }
      
      if (!ngrokApiUrl) {
        console.warn('⚠️ [TURN_CONFIG] ngrok API not accessible on ports 4040 or 4041');
        throw new Error('ngrok API not accessible');
      }
      
      const response = await new Promise((resolve, reject) => {
          http.get(ngrokApiUrl, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
              try {
                const tunnels = JSON.parse(data).tunnels || [];
                // Find TCP tunnel for port 3478
                // Check both tunnel name and config address
                for (const tunnel of tunnels) {
                  const isTurnTunnel = tunnel.name === 'turn' || 
                                      (tunnel.proto === 'tcp' && (
                                        tunnel.config?.addr?.includes('3478') ||
                                        tunnel.config?.addr === '3478' ||
                                        tunnel.config?.addr === 'localhost:3478'
                                      ));
                  if (isTurnTunnel) {
                    console.log('📡 [TURN_CONFIG] Found TURN tunnel:', tunnel.name, tunnel.public_url);
                    resolve(tunnel.public_url);
                    return;
                  }
                }
                console.warn('⚠️ [TURN_CONFIG] No TCP tunnel found for port 3478. Available tunnels:', tunnels.map(t => `${t.name} (${t.proto})`).join(', '));
                resolve(null);
              } catch (e) {
                reject(e);
              }
            });
          }).on('error', reject);
        });
      
      if (response) {
        tcpTunnelUrl = response; // Format: tcp://0.tcp.ngrok.io:12345
        console.log('📡 [TURN_CONFIG] Found ngrok TCP tunnel:', tcpTunnelUrl);
      }
    } catch (e) {
      console.warn('⚠️ [TURN_CONFIG] Could not fetch ngrok TCP tunnel URL:', e.message);
    }
    
    // Parse TCP tunnel URL if available
    let turnServers = [];
    
    // PRIORITY 1: Cloud TURN Service (if configured) - Works without router access!
    // This is the ONLY solution that works for cross-network calls without router access
    if (turnConfig.cloudTurnEnabled && turnConfig.cloudTurnUrls.length > 0) {
      console.log('✅ [TURN_CONFIG] Using CLOUD TURN service (Twilio/Xirsys) - no router config needed!');
      console.log('   ✅ This is the ONLY solution that works for cross-network calls without router access');
      
      // Try to use Twilio Token API first (RECOMMENDED - generates proper credentials)
      let twilioIceServers = null;
      if (turnConfig.twilioAccountSid && turnConfig.twilioAuthToken) {
        try {
          console.log('🔵 [TURN_CONFIG] Attempting to generate Twilio TURN credentials via Token API...');
          twilioIceServers = await generateTwilioTurnCredentials(turnConfig.twilioAccountSid, turnConfig.twilioAuthToken);
          console.log(`✅ [TURN_CONFIG] Twilio Token API: Generated ${twilioIceServers.length} TURN servers`);
          
          // Add Twilio TURN servers from Token API
          twilioIceServers.forEach((server) => {
            turnServers.push({
              urls: server.url || server.urls,
              username: server.username,
              credential: server.credential,
            });
          });
          console.log(`   Configured ${turnServers.length} cloud TURN servers (via Twilio Token API)`);
        } catch (twilioError) {
          console.warn('⚠️ [TURN_CONFIG] Twilio Token API failed, falling back to static credentials:', twilioError.message);
          console.warn('   Using static credentials (less secure, but may work for testing)');
          twilioIceServers = null; // Fall through to static credentials
        }
      }
      
      // Fallback to static credentials if Token API failed or not configured
      if (!twilioIceServers && turnConfig.cloudTurnUsername && turnConfig.cloudTurnPassword) {
        console.log('🔵 [TURN_CONFIG] Using static Twilio TURN credentials (fallback)');
        console.warn('   ⚠️  Static credentials are less secure - consider using Twilio Token API');
        turnConfig.cloudTurnUrls.forEach((url) => {
          const cleanUrl = url.trim();
          if (cleanUrl.startsWith('turn:') || cleanUrl.startsWith('turns:')) {
            turnServers.push({
              urls: cleanUrl,
              username: turnConfig.cloudTurnUsername,
              credential: turnConfig.cloudTurnPassword,
            });
          } else {
            // If URL doesn't have turn: prefix, add it
            turnServers.push({
              urls: `turn:${cleanUrl}`,
              username: turnConfig.cloudTurnUsername,
              credential: turnConfig.cloudTurnPassword,
            });
            turnServers.push({
              urls: `turn:${cleanUrl}?transport=tcp`,
              username: turnConfig.cloudTurnUsername,
              credential: turnConfig.cloudTurnPassword,
            });
          }
        });
        console.log(`   Configured ${turnServers.length} cloud TURN servers (static credentials)`);
      }
      
      if (turnServers.length > 0) {
        console.log('   ✅ No router port forwarding needed!');
        console.log('   ✅ Cross-network calls will work!');
      } else {
        console.error('❌ [TURN_CONFIG] No Twilio TURN servers configured!');
        console.error('   Please set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN (for Token API)');
        console.error('   OR set CLOUD_TURN_USERNAME and CLOUD_TURN_PASSWORD (for static credentials)');
      }
      
      // CRITICAL: When cloud TURN is enabled, DO NOT add ngrok TCP or public IP TURN
      // ngrok TCP cannot forward UDP traffic (media streams require UDP)
      // Public IP TURN requires router port forwarding (user may not have access)
      // Only cloud TURN works reliably for cross-network calls
      console.log('   ⚠️  ngrok TCP and public IP TURN servers NOT added (cloud TURN is sufficient)');
    } else {
      // Cloud TURN not configured - fallback to self-hosted options
      // WARNING: These options have limitations:
      // - ngrok TCP cannot forward UDP (won't work for media relay)
      // - Public IP requires router port forwarding
      
      console.warn('⚠️ [TURN_CONFIG] Cloud TURN not configured - using fallback options');
      console.warn('   ⚠️  WARNING: Fallback options may not work for cross-network calls!');
      
      // PRIORITY 2: Self-hosted TURN via ngrok TCP (FALLBACK - has limitations)
      // CRITICAL: ngrok TCP tunnels CANNOT forward UDP traffic required for media relay
      // This is a fundamental limitation - ngrok TCP only forwards TCP, not UDP
      // Media streams (RTP) require UDP, so ngrok TCP TURN servers will NOT work for media relay
      // We include this as a fallback, but it will only work for signaling, not media
      if (tcpTunnelUrl && !turnConfig.cloudTurnEnabled) {
        console.warn('   ⚠️  [TURN_CONFIG] ngrok TCP tunnel found, but it CANNOT relay UDP media streams!');
        console.warn('   ⚠️  ngrok TCP only forwards TCP traffic, not UDP (required for RTP media)');
        console.warn('   ⚠️  This TURN server will NOT work for cross-network media streams!');
        // NOTE: We're NOT adding ngrok TCP as TURN server because it cannot relay UDP media
        // If you need cross-network calls, you MUST use cloud TURN service (Twilio/Xirsys)
      }
      
      // PRIORITY 3: Self-hosted TURN with public IP (FALLBACK - requires router access)
      // Requires router port forwarding for UDP ports 50000-50100
      // Won't work if user doesn't have router access
      if (!turnConfig.cloudTurnEnabled) {
        if (turnConfig.publicIp) {
          console.log('✅ [TURN_CONFIG] Adding PUBLIC IP TURN server for media relay (UDP)');
          console.log(`   Public IP: ${turnConfig.publicIp}:${turnConfig.port}`);
          console.log('   ⚠️  REQUIRES router port forwarding for UDP ports 50000-50100');
          console.warn('   ⚠️  If router access is unavailable, this will NOT work for cross-network calls!');
          turnServers.push(
            {
              urls: `turn:${turnConfig.publicIp}:${turnConfig.port}`,
              username: turnConfig.username,
              credential: turnConfig.password,
            },
            {
              urls: `turn:${turnConfig.publicIp}:${turnConfig.port}?transport=tcp`,
              username: turnConfig.username,
              credential: turnConfig.password,
            }
          );
        }
        
        // Include local IP as fallback (for same-network calls only)
        console.log('✅ [TURN_CONFIG] Adding LOCAL IP TURN server (same network only)');
        turnServers.push(
          {
            urls: `turn:${turnConfig.localIp}:${turnConfig.port}`,
            username: turnConfig.username,
            credential: turnConfig.password,
          },
          {
            urls: `turn:${turnConfig.localIp}:${turnConfig.port}?transport=tcp`,
            username: turnConfig.username,
            credential: turnConfig.password,
          }
        );
      }
    }
    
    // Log the TURN server configuration being returned
    console.log('📡 [TURN_CONFIG] Returning TURN configuration:');
    console.log(`   - Total TURN servers: ${turnServers.length}`);
    turnServers.forEach((server, index) => {
      const isNgrok = server.urls.includes('ngrok');
      const isCloud = server.urls.includes('twilio.com') || 
                      server.urls.includes('turn.twilio.com') ||
                      server.urls.includes('xirsys') ||
                      server.urls.includes('metered.ca');
      const isPublic = server.urls.includes(turnConfig.publicIp || '');
      const isLocal = server.urls.includes(turnConfig.localIp);
      let label = '';
      if (isCloud) {
        label = '(CLOUD TURN - Twilio/Xirsys - ✅ WORKS for cross-network calls!)';
      } else if (isNgrok) {
        label = '(NGROK - ⚠️  CANNOT relay UDP media - will NOT work for cross-network)';
      } else if (isPublic) {
        label = '(PUBLIC IP - ⚠️  requires router port forwarding)';
      } else if (isLocal) {
        label = '(Local IP - same network only)';
      }
      console.log(`   ${index + 1}. ${server.urls} ${label}`);
    });
    
    res.json({
      success: true,
      turnServers: turnServers,
      tcpTunnelUrl: tcpTunnelUrl,
      localIp: turnConfig.localIp,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ [TURN_CONFIG] Error getting TURN configuration:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Import routes
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chats');
const messageRoutes = require('./routes/messages');
const notificationRoutes = require('./routes/notifications');
const adminRoutes = require('./routes/admin');

// AI Service for local LLM integration (Ollama)
let aiService;
try {
  aiService = require('./services/aiService');
  console.log('✅ AI Service loaded (Ollama integration available)');
  // Make AI Service accessible to all routes
  app.locals.aiService = aiService;
  
  // Preload Ollama models in background (non-blocking)
  // This makes first AI response faster
  setTimeout(async () => {
    try {
      console.log('🔄 Preloading Ollama models in background...');
      const textModel = process.env.OLLAMA_MODEL || 'llama3.1';
      const visionModel = process.env.OLLAMA_VISION_MODEL || 'llava';
      const http = require('http');
      
      // Preload text model
      const textRequestData = JSON.stringify({
        model: textModel,
        messages: [{ role: 'user', content: 'Hi' }],
        stream: false,
        keep_alive: '2m',
        options: { num_predict: 10 }
      });
      
      const textReq = http.request({
        hostname: process.env.OLLAMA_HOST || 'localhost',
        port: parseInt(process.env.OLLAMA_PORT || '11434'),
        path: '/api/chat',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(textRequestData)
        },
        timeout: 300000 // 5 minutes for first load
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200) {
            console.log(`✅ Text model (${textModel}) preloaded successfully`);
          } else {
            console.warn(`⚠️ Text model preload returned status ${res.statusCode}`);
          }
        });
      });
      
      textReq.on('error', () => {
        console.warn('⚠️ Text model preload failed (non-critical)');
      });
      
      textReq.on('timeout', () => {
        textReq.destroy();
        console.warn('⚠️ Text model preload timeout (non-critical)');
      });
      
      textReq.write(textRequestData);
      textReq.end();
      
      // Preload vision model (smaller test to avoid long wait)
      setTimeout(() => {
        const visionRequestData = JSON.stringify({
          model: visionModel,
          messages: [{ role: 'user', content: 'test', images: [] }],
          stream: false,
          keep_alive: '5m',
          options: { num_predict: 5 }
        });
        
        const visionReq = http.request({
          hostname: process.env.OLLAMA_HOST || 'localhost',
          port: parseInt(process.env.OLLAMA_PORT || '11434'),
          path: '/api/chat',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(visionRequestData)
          },
          timeout: 300000
        }, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk; });
          res.on('end', () => {
            if (res.statusCode === 200) {
              console.log(`✅ Vision model (${visionModel}) preloaded successfully`);
            } else {
              console.warn(`⚠️ Vision model preload returned status ${res.statusCode}`);
            }
          });
        });
        
        visionReq.on('error', () => {
          console.warn('⚠️ Vision model preload failed (non-critical)');
        });
        
        visionReq.on('timeout', () => {
          visionReq.destroy();
          console.warn('⚠️ Vision model preload timeout (non-critical)');
        });
        
        visionReq.write(visionRequestData);
        visionReq.end();
      }, 10000); // Wait 10 seconds before preloading vision model
      
    } catch (e) {
      console.warn('⚠️ Model preload error (non-critical):', e.message);
    }
  }, 5000); // Wait 5 seconds after server starts
  
} catch (e) {
  console.warn('⚠️ AI Service not available:', e.message);
  aiService = null;
  app.locals.aiService = null;
}

// Use routes
app.use('/auth', authRoutes);
app.use('/chats', chatRoutes);
app.use('/messages', messageRoutes);
app.use('/notifications', notificationRoutes);
// Performance monitoring middleware
const performanceMonitor = require('./middleware/performanceMonitor');
app.use(performanceMonitor.performanceMonitorMiddleware);

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
          { expiresIn: JWT_EXPIRES_IN }
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
    
    // Emit admin activity event for user registration
    try {
      const io = req.app.get('io');
      if (io) {
        io.to('admin_room').emit('admin_activity', {
          type: 'system',
          action: 'user_registered',
          description: `New user registered: ${finalDisplayName}`,
          userId: result.insertedId.toString(),
          userName: finalDisplayName,
          timestamp: new Date().toISOString(),
          details: { email }
        });
      }
    } catch (e) {
      console.warn('Error emitting admin activity for user registration:', e);
    }
    
    // Generate token
    const token = jwt.sign(
      { id: result.insertedId, email, displayName: finalDisplayName, role: 'user' },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
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
      { expiresIn: JWT_EXPIRES_IN }
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

    // Use original file immediately - transcoding will happen in background if needed
    let finalFilePath = req.file.path;
    let finalFileName = req.file.filename;
    
    // Start video transcoding in background (non-blocking)
    if (type === 'video' && req.file.mimetype?.startsWith('video/')) {
      console.log('Video upload detected - will transcode in background:', {
        path: req.file.path,
        filename: req.file.filename,
        mimetype: req.file.mimetype
      });
      
      // Transcode asynchronously without blocking the response
      setImmediate(async () => {
        try {
          const transcode = require('./transcode_video');
          
          // Check if ffmpeg is available
          const ffmpegAvailable = await transcode.checkFFmpegAvailable();
          if (!ffmpegAvailable) {
            console.warn('⚠️  FFmpeg not available - video transcoding disabled');
            return;
          }
          
          console.log('✓ FFmpeg is available, checking if transcoding needed...');
          const needsTranscode = await transcode.needsTranscoding(req.file.path);
          
          if (needsTranscode) {
            console.log('🔄 Starting background transcoding...');
            
            // Generate transcoded filename
            const originalPath = path.parse(req.file.path);
            const transcodedPath = path.join(originalPath.dir, `transcoded_${originalPath.name}.mp4`);
            
            // Transcode the video (this happens in background)
            const success = await transcode.transcodeVideoToH264(req.file.path, transcodedPath);
            
            if (success) {
              // Delete original file to save space
              try {
                fs.unlinkSync(req.file.path);
                console.log('✅ Video transcoded successfully, original deleted');
              } catch (unlinkErr) {
                console.warn('⚠️  Could not delete original file:', unlinkErr.message);
              }
            } else {
              console.warn('❌ Video transcoding failed, keeping original file');
            }
          } else {
            console.log('✓ Video already in compatible format');
          }
        } catch (transcodeErr) {
          console.error('❌ Error during background video transcoding:', transcodeErr);
          // Original file remains available
        }
      });
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
    const { content, messageType, mediaUrl } = req.body;
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
    
    const message = {
      chatId,
      senderId: userId,
      content,
      messageType: messageType || 'text',
      mediaUrl,
      createdAt: new Date(),
      readBy: [], // Initialize empty readBy array
      status: 'sent', // Initialize status as 'sent'
      replies: [], // Initialize empty replies array
      reactions: {} // Initialize empty reactions object (emoji -> [userId1, userId2, ...])
    };
    
    const result = await db.collection('messages').insertOne(message);
    
    // Emit admin activity event for message sent
    try {
      const io = req.app.get('io');
      if (io) {
        io.to('admin_room').emit('admin_activity', {
          type: 'system',
          action: 'message_sent',
          description: `${senderName} sent a message`,
          userId: userId,
          userName: senderName,
          chatId: chatId,
          messageId: result.insertedId.toString(),
          timestamp: new Date().toISOString(),
          details: { messageType: message.messageType || 'text' }
        });
      }
    } catch (e) {
      console.warn('Error emitting admin activity for message:', e);
    }
    
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
        // CRITICAL: Ensure createdAt is sent as ISO string for consistent parsing
        const createdAtIso = message.createdAt instanceof Date 
          ? message.createdAt.toISOString() 
          : (typeof message.createdAt === 'string' 
              ? message.createdAt 
              : new Date().toISOString());
        
        socket.emit('new_message', {
          id: result.insertedId.toString(),
          _id: result.insertedId.toString(),
          senderName: senderName,
          chatId: chatId.toString(),
          senderId: userId.toString(),
          content: message.content,
          messageType: message.messageType,
          mediaUrl: mediaUrlForThisSocket,
          createdAt: createdAtIso, // Always send as ISO string
          timestamp: createdAtIso, // Also include as timestamp for compatibility
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
    
    // Fallback: Check if user has active FCM token (indicates they might be online)
    // This is a backup mechanism if Socket.IO check fails
    const usersWithActiveTokens = new Set();
    try {
      const usersWithTokens = await db.collection('users').find(
        { 
          _id: { $in: otherMembers.map(id => new ObjectId(id)) },
          fcmToken: { $exists: true, $ne: '' },
          fcmTokenUpdatedAt: { 
            $gte: new Date(Date.now() - 5 * 60 * 1000) // Updated in last 5 minutes
          }
        },
        { projection: { _id: 1 } }
      ).toArray();
      
      for (const user of usersWithTokens) {
        usersWithActiveTokens.add(user._id.toString());
      }
    } catch (e) {
      console.warn('Error checking active FCM tokens:', e?.message || e);
    }
    
    for (const memberId of otherMembers) {
      // Determine title based on chat type
      const isGroupChat = chat.type === 'group' || chat.type === 'Group';
      const title = isGroupChat ? `${chat.name}` : senderName;
      const body = messageType === 'text' 
        ? (isGroupChat ? `${senderName}: ${content}` : content)
        : messageType === 'image' 
          ? (isGroupChat ? `${senderName} sent a photo` : '📷 Photo')
          : messageType === 'video'
            ? (isGroupChat ? `${senderName} sent a video` : '🎥 Video')
            : messageType === 'audio' || messageType === 'voice'
              ? (isGroupChat ? `${senderName} sent a voice message` : '🎤 Voice message')
              : (isGroupChat ? `${senderName} sent a ${messageType}` : `📎 ${messageType}`);
      
      console.log(`📤 Emitting chat_notification to room: "${memberId}" (sender: ${userId})`);
      console.log(`   Available rooms include memberId: ${allRooms.has(memberId)}`);
      
      // Check if user is online via Socket.IO
      const isOnlineViaSocket = onlineUsers.has(memberId);
      
      // Send socket notification if user is online
      if (isOnlineViaSocket) {
        try {
          io.to(memberId).emit('chat_notification', {
            title: title,
            body: body,
            chatId: chatId,
            senderId: userId,
            senderName: senderName,
            messageType: messageType || 'text',
            timestamp: new Date(),
          });
          console.log(`✅ User ${memberId} is online, sent Socket.IO notification (skipping FCM to avoid duplicates)`);
        } catch (socketErr) {
          console.warn(`Error sending socket notification to ${memberId}:`, socketErr?.message || socketErr);
        }
      }
      
      // Send FCM notification for both iOS and Android (always)
      // Both platforms require FCM even when "online" because:
      // - Background apps need push notifications
      // - Terminated apps can only receive push notifications
      // - Socket.IO doesn't work when app is terminated
      const user = await db.collection('users').findOne({ _id: new ObjectId(memberId) });
      const userPlatform = user?.fcmPlatform || 'unknown';
      const isIOS = userPlatform === 'ios';
      const isAndroid = userPlatform === 'android';
      
      // Always send FCM for both iOS and Android (needed for background/terminated state)
      // Socket.IO notifications are sent separately for real-time updates when app is active
      if (isIOS || isAndroid) {
        const reason = isIOS 
          ? 'iOS device (always send FCM for background/terminated support)'
          : 'Android device (always send FCM for background/terminated support)';
        console.log(`📱 User ${memberId} is ${reason}, sending FCM notification`);
        sendFCMNotification(
          memberId,
          title,
          body.length > 100 ? body.substring(0, 100) + '...' : body,
          {
            chatId: chatId.toString(),
            senderId: userId.toString(),
            senderName: senderName,
            messageType: messageType || 'text',
            messageId: result.insertedId.toString(),
            type: isGroupChat ? 'group_message' : 'chat_message',
          }
        ).catch(err => {
          console.error(`Error sending FCM to user ${memberId}:`, err.message);
        });
      } else if (!isOnlineViaSocket) {
        // For other platforms (web, etc.), only send if offline
        console.log(`📱 User ${memberId} is offline, sending FCM notification`);
        sendFCMNotification(
          memberId,
          title,
          body.length > 100 ? body.substring(0, 100) + '...' : body,
          {
            chatId: chatId.toString(),
            senderId: userId.toString(),
            senderName: senderName,
            messageType: messageType || 'text',
            messageId: result.insertedId.toString(),
            type: isGroupChat ? 'group_message' : 'chat_message',
          }
        ).catch(err => {
          console.error(`Error sending FCM to user ${memberId}:`, err.message);
        });
      }
    }
    
    // Process AI response (non-blocking - runs in background)
    if (aiService && aiService.processMessageForAI) {
      // Don't await - let it run in background so user gets immediate response
      console.log(`[AI Service] Triggering AI processing for chat ${chatId}, members: ${(chat.members || []).map(m => m.toString()).join(', ')}`);
      aiService.processMessageForAI(
        {
          ...message,
          _id: result.insertedId,
          chatId: chatId.toString(),
          senderId: userId.toString()
        },
        chat,
        db,
        io
      ).catch(err => {
        console.error('[AI Service] Background processing error:', err);
        console.error('[AI Service] Error stack:', err.stack);
      });
    }
    
    // Return created message (with media URL rewritten for web clients)
    const mediaUrlForWeb = rewriteMediaUrlIfNeeded(message.mediaUrl, req.headers || {});
    res.status(201).json({
      id: result.insertedId.toString(),
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

// AI Bot Management Endpoints
if (aiService) {
  // Rate limiting for AI endpoints (per user)
  const aiRateLimiter = rateLimit({
    windowMs: parseInt(process.env.AI_RATE_LIMIT_WINDOW || '60000'), // 1 minute
    max: parseInt(process.env.AI_RATE_LIMIT_MAX || '10'), // 10 requests per minute per user
    message: {
      error: 'Too many AI requests. Please wait before trying again.',
      retryAfter: 60
    },
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => {
      // Rate limit per user ID
      return req.user ? req.user.id : req.ip;
    },
    skip: (req) => {
      // Skip rate limiting for status checks
      return req.path === '/api/ai/status';
    }
  });

  // Get AI bot status and info
  app.get('/api/ai/status', authenticateToken, async (req, res) => {
    try {
      console.log('[AI Status] Request received from user:', req.user?.id);
      
      if (!db) {
        console.error('[AI Status] Database not connected');
        return res.status(503).json({ error: 'Database not connected' });
      }
      
      const aiBotId = await aiService.getAIBotUserId(db);
      const ollamaHealth = await aiService.checkOllamaHealth();
      
      const status = {
        enabled: !!aiBotId,
        aiBotId: aiBotId,
        ollamaAvailable: ollamaHealth,
        model: process.env.OLLAMA_MODEL || 'llama3.2',
        host: process.env.OLLAMA_HOST || 'localhost',
        port: process.env.OLLAMA_PORT || 11434
      };
      
      console.log('[AI Status] Response:', JSON.stringify(status));
      res.json(status);
    } catch (error) {
      console.error('[AI Status] Error:', error);
      res.status(500).json({ error: 'Failed to get AI status' });
    }
  });

  // Add AI bot to a chat
  app.post('/api/chats/:chatId/ai/add', authenticateToken, aiRateLimiter, async (req, res) => {
    try {
      if (!db) {
        return res.status(503).json({ error: 'Database not connected' });
      }
      const chatId = req.params.chatId;
      const userId = req.user.id;
      
      // Verify user is a member of the chat
      const chat = await db.collection('chats').findOne({
        _id: new ObjectId(chatId),
        members: new ObjectId(userId)
      });
      
      if (!chat) {
        return res.status(404).json({ error: 'Chat not found or access denied' });
      }
      
      // Get AI bot user ID
      const aiBotId = await aiService.getAIBotUserId(db);
      if (!aiBotId) {
        return res.status(404).json({ error: 'AI bot user not found. Run create-ai-bot.js script first.' });
      }
      
      const aiBotObjectId = new ObjectId(aiBotId);
      
      // Check if AI bot is already in the chat
      const hasAIBot = chat.members.some(m => m.toString() === aiBotId.toString());
      if (hasAIBot) {
        return res.json({ message: 'AI bot is already in this chat', chatId });
      }
      
      // Add AI bot to chat
      await db.collection('chats').updateOne(
        { _id: new ObjectId(chatId) },
        { $addToSet: { members: aiBotObjectId } }
      );
      
      res.json({ 
        message: 'AI bot added to chat successfully',
        chatId,
        aiBotId 
      });
    } catch (error) {
      console.error('Error adding AI bot to chat:', error);
      res.status(500).json({ error: 'Failed to add AI bot to chat' });
    }
  });

  // Get or create user's private AI chat
  app.get('/api/ai/chat', authenticateToken, aiRateLimiter, async (req, res) => {
    try {
      if (!db) {
        return res.status(503).json({ error: 'Database not connected' });
      }
      const userId = req.user.id;
      
      // Get AI bot user ID
      const aiBotId = await aiService.getAIBotUserId(db);
      if (!aiBotId) {
        return res.status(404).json({ 
          error: 'AI bot user not found. Run create-ai-bot.js script first.',
          aiBotExists: false
        });
      }
      
      const aiBotObjectId = new ObjectId(aiBotId);
      const userObjectId = new ObjectId(userId);
      
      // Check if private chat already exists between user and AI bot
      const existingChat = await db.collection('chats').findOne({
        type: 'private',
        members: { 
          $all: [userObjectId, aiBotObjectId],
          $size: 2
        }
      });
      
      if (existingChat) {
        // Return existing chat
        return res.json({
          chatId: existingChat._id.toString(),
          chat: {
            _id: existingChat._id.toString(),
            id: existingChat._id.toString(),
            name: existingChat.name || 'AI Assistant',
            type: existingChat.type,
            members: existingChat.members.map(m => m.toString()),
            createdAt: existingChat.createdAt,
            updatedAt: existingChat.updatedAt
          },
          isNew: false
        });
      }
      
      // Create new private chat between user and AI bot
      const chat = {
        type: 'private',
        name: 'AI Assistant',
        members: [userObjectId, aiBotObjectId],
        createdBy: userObjectId,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastMessageTime: new Date(),
        lastMessage: null,
        unreadCount: {},
        memberRoles: {
          [userId]: 'admin',
          [aiBotId]: 'member'
        }
      };
      
      const result = await db.collection('chats').insertOne(chat);
      const createdChat = await db.collection('chats').findOne({ _id: result.insertedId });
      
      if (!createdChat) {
        return res.status(500).json({ error: 'Failed to create AI chat' });
      }
      
      res.status(201).json({
        chatId: createdChat._id.toString(),
        chat: {
          _id: createdChat._id.toString(),
          id: createdChat._id.toString(),
          name: createdChat.name || 'AI Assistant',
          type: createdChat.type,
          members: createdChat.members.map(m => m.toString()),
          createdAt: createdChat.createdAt,
          updatedAt: createdChat.updatedAt
        },
        isNew: true
      });
    } catch (error) {
      console.error('Error getting/creating AI chat:', error);
      res.status(500).json({ error: 'Failed to get/create AI chat' });
    }
  });

  // Remove AI bot from a chat
  app.post('/api/chats/:chatId/ai/remove', authenticateToken, aiRateLimiter, async (req, res) => {
    try {
      if (!db) {
        return res.status(503).json({ error: 'Database not connected' });
      }
      const chatId = req.params.chatId;
      const userId = req.user.id;
      
      // Verify user is a member of the chat
      const chat = await db.collection('chats').findOne({
        _id: new ObjectId(chatId),
        members: new ObjectId(userId)
      });
      
      if (!chat) {
        return res.status(404).json({ error: 'Chat not found or access denied' });
      }
      
      // Get AI bot user ID
      const aiBotId = await aiService.getAIBotUserId(db);
      if (!aiBotId) {
        return res.status(404).json({ error: 'AI bot user not found' });
      }
      
      const aiBotObjectId = new ObjectId(aiBotId);
      
      // Check if AI bot is in the chat
      const hasAIBot = chat.members.some(m => m.toString() === aiBotId.toString());
      if (!hasAIBot) {
        return res.json({ message: 'AI bot is not in this chat', chatId });
      }
      
      // Remove AI bot from chat
      await db.collection('chats').updateOne(
        { _id: new ObjectId(chatId) },
        { $pull: { members: aiBotObjectId } }
      );
      
      res.json({ 
        message: 'AI bot removed from chat successfully',
        chatId 
      });
    } catch (error) {
      console.error('Error removing AI bot from chat:', error);
      res.status(500).json({ error: 'Failed to remove AI bot from chat' });
    }
  });
}

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

// Reply to a message - MOVED TO routes/messages.js
// This route is now handled by the messageRoutes router
// Keeping this comment for reference - actual route is in routes/messages.js
/*
app.post('/api/messages/:messageId/reply', authenticateToken, async (req, res) => {
  try {
    const { content, messageType, mediaUrl } = req.body;
    const userId = req.user.id;
    const messageId = req.params.messageId;

    if (!content && !mediaUrl) {
      return res.status(400).json({ error: 'Content or mediaUrl is required' });
    }

    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    // Get the original message
    const originalMessage = await db.collection('messages').findOne({
      _id: new ObjectId(messageId)
    });

    if (!originalMessage) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Verify user is a member of the chat
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(originalMessage.chatId),
      members: new ObjectId(userId),
    });

    if (!chat) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get sender's display name
    const sender = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    const senderName = sender?.displayName || sender?.username || 'Someone';

    // Create reply message
    const replyMessage = {
      chatId: originalMessage.chatId,
      senderId: userId,
      content: content || '',
      messageType: messageType || 'text',
      mediaUrl: mediaUrl || null,
      createdAt: new Date(),
      readBy: [],
      status: 'sent',
      replies: [],
      reactions: {},
      replyTo: messageId, // Reference to original message
      replyToContent: originalMessage.content?.substring(0, 100) || '', // Preview of original message
      replyToSenderName: originalMessage.senderName || 'Unknown',
    };

    const result = await db.collection('messages').insertOne(replyMessage);

    // Add reply reference to original message
    await db.collection('messages').updateOne(
      { _id: new ObjectId(messageId) },
      { 
        $push: { 
          replies: {
            replyId: result.insertedId.toString(),
            senderId: userId,
            senderName: senderName,
            content: content || (mediaUrl ? 'Media' : ''),
            createdAt: new Date(),
          }
        },
        $set: { updatedAt: new Date() }
      }
    );

    // Update chat's last message
    const now = new Date();
    await db.collection('chats').updateOne(
      { _id: new ObjectId(originalMessage.chatId) },
      { 
        $set: { 
          updatedAt: now,
          lastMessageTime: now,
          lastMessage: {
            content: content || (mediaUrl ? 'Media reply' : ''),
            senderId: userId,
            senderName: senderName,
            timestamp: now.toISOString(),
            createdAt: now,
          },
        }
      }
    );

    // Emit socket notification
    try {
      const otherMembers = chat.members
        .filter(m => m.toString() !== userId.toString())
        .map(m => m.toString());
      
      for (const memberId of otherMembers) {
        io.to(memberId).emit('new_message', {
          id: result.insertedId.toString(),
          _id: result.insertedId.toString(),
          chatId: originalMessage.chatId.toString(),
          senderId: userId.toString(),
          senderName: senderName,
          content: replyMessage.content,
          messageType: replyMessage.messageType,
          mediaUrl: replyMessage.mediaUrl,
          createdAt: replyMessage.createdAt,
          replyTo: messageId,
          replyToContent: replyMessage.replyToContent,
          replyToSenderName: replyMessage.replyToSenderName,
          readBy: [],
          status: 'sent'
        });
      }
    } catch (socketErr) {
      console.warn('Socket emission failed:', socketErr?.message || socketErr);
    }

    res.status(201).json({
      id: result.insertedId.toString(),
      _id: result.insertedId.toString(),
      chatId: originalMessage.chatId.toString(),
      senderId: userId.toString(),
      content: replyMessage.content,
      messageType: replyMessage.messageType,
      mediaUrl: replyMessage.mediaUrl,
      createdAt: replyMessage.createdAt,
      replyTo: messageId,
      replyToContent: replyMessage.replyToContent,
      replyToSenderName: replyMessage.replyToSenderName,
      readBy: [],
      status: 'sent'
    });
  } catch (err) {
    console.error('Reply error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});
*/

// React to a message (add or remove reaction) - MOVED TO routes/messages.js
// This route is now handled by the messageRoutes router
// Keeping this comment for reference - actual route is in routes/messages.js
/*
app.post('/api/messages/:messageId/react', authenticateToken, async (req, res) => {
  try {
    const { emoji } = req.body;
    const userId = req.user.id;
    const messageId = req.params.messageId;

    if (!emoji) {
      return res.status(400).json({ error: 'Emoji is required' });
    }

    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    // Get the message
    const message = await db.collection('messages').findOne({
      _id: new ObjectId(messageId)
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
    const emojiReactions = reactions[emoji] || [];

    // Toggle reaction (add if not exists, remove if exists)
    const userIdStr = userId.toString();
    const hasReacted = emojiReactions.includes(userIdStr);
    
    if (hasReacted) {
      // Remove reaction
      reactions[emoji] = emojiReactions.filter(id => id !== userIdStr);
      // Remove emoji key if no reactions left
      if (reactions[emoji].length === 0) {
        delete reactions[emoji];
      }
    } else {
      // Add reaction
      reactions[emoji] = [...emojiReactions, userIdStr];
    }

    // Update message
    await db.collection('messages').updateOne(
      { _id: new ObjectId(messageId) },
      { 
        $set: { 
          reactions: reactions,
          updatedAt: new Date()
        }
      }
    );

    // Emit socket notification
    try {
      io.to(message.chatId.toString()).emit('message_reaction', {
        messageId: messageId,
        emoji: emoji,
        userId: userId,
        action: hasReacted ? 'removed' : 'added',
        reactions: reactions
      });
    } catch (socketErr) {
      console.warn('Socket emission failed:', socketErr?.message || socketErr);
    }

    res.status(200).json({
      success: true,
      messageId: messageId,
      emoji: emoji,
      action: hasReacted ? 'removed' : 'added',
      reactions: reactions
    });
  } catch (err) {
    console.error('Reaction error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});
*/

// Get replies for a message - MOVED TO routes/messages.js
// This route is now handled by the messageRoutes router
// Keeping this comment for reference - actual route is in routes/messages.js
/*
app.get('/api/messages/:messageId/replies', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const messageId = req.params.messageId;

    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    // Get the original message
    const message = await db.collection('messages').findOne({
      _id: new ObjectId(messageId)
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

    // Get all reply messages
    const replies = await db.collection('messages')
      .find({ replyTo: messageId })
      .sort({ createdAt: 1 })
      .toArray();

    // Format replies
    const formattedReplies = replies.map(reply => ({
      id: reply._id.toString(),
      _id: reply._id.toString(),
      chatId: reply.chatId.toString(),
      senderId: reply.senderId.toString(),
      senderName: reply.senderName || 'Unknown',
      content: reply.content,
      messageType: reply.messageType || 'text',
      mediaUrl: reply.mediaUrl,
      createdAt: reply.createdAt,
      replyTo: reply.replyTo,
      readBy: reply.readBy || [],
      status: reply.status || 'sent',
      reactions: reply.reactions || {}
    }));

    res.status(200).json({
      messageId: messageId,
      replies: formattedReplies
    });
  } catch (err) {
    console.error('Get replies error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});
*/

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

// Socket.IO authentication middleware with graceful token refresh
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  
  if (!token) {
    return next(new Error('Authentication error: Token required'));
  }
  
  let decoded;
  let refreshedToken = null;
  let tokenExpiredAt = null;
  
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (error) {
    if (error && error.name === 'TokenExpiredError') {
      tokenExpiredAt = error.expiredAt ? new Date(error.expiredAt) : null;
      const decodedForLog = jwt.decode(token);
      console.warn(
        `Socket token expired for user: ${decodedForLog?.id || decodedForLog?.uid || 'unknown'} (expired at ${tokenExpiredAt?.toISOString() || 'unknown'})`
      );
      const expiredAgeMs = tokenExpiredAt ? Date.now() - tokenExpiredAt.getTime() : Number.MAX_SAFE_INTEGER;
      
      if (expiredAgeMs > SOCKET_TOKEN_REFRESH_GRACE_MS) {
        return next(new Error('Authentication error: Token expired'));
      }
      
      try {
        decoded = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true });
      } catch (decodeError) {
        console.error('Failed to decode expired socket token for refresh:', decodeError);
        return next(new Error('Authentication error: Token expired'));
      }
      
      const userIdForRefresh = decoded?.uid || decoded?.id;
      if (!userIdForRefresh) {
        return next(new Error('Authentication error: Token expired'));
      }
      
      if (!db) {
        return next(new Error('Authentication error: Token expired'));
      }
      
      try {
        const userRecord = await db.collection('users').findOne(
          { _id: new ObjectId(userIdForRefresh) },
          { projection: { email: 1, displayName: 1, role: 1 } }
        );
        
        if (!userRecord) {
          return next(new Error('Authentication error: Token expired'));
        }
        
        refreshedToken = jwt.sign(
          {
            id: userRecord._id.toString(),
            email: userRecord.email,
            displayName: userRecord.displayName,
            role: userRecord.role || 'user'
          },
          JWT_SECRET,
          { expiresIn: JWT_EXPIRES_IN }
        );
        
        decoded = {
          ...decoded,
          id: userRecord._id.toString(),
          uid: undefined,
        };
        
      } catch (refreshError) {
        console.error('Socket token refresh failed:', refreshError);
        return next(new Error('Authentication error: Token expired'));
      }
    } else {
      console.error('Socket authentication error:', error);
      return next(new Error('Authentication error: Invalid token'));
    }
  }
  
  const userId = decoded?.uid || decoded?.id;
  socket.userId = userId ? userId.toString() : null;
  socket.user = decoded;
  
  if (!socket.userId) {
    return next(new Error('Authentication error: No user ID in token'));
  }
  
  if (refreshedToken) {
    socket.refreshedAuthToken = refreshedToken;
    socket.tokenRefreshedAt = new Date();
    socket.tokenExpiredAt = tokenExpiredAt;
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
});

// =========================================
// CALL ENDPOINTS
// =========================================

// Track active connections and calls
const activeConnections = new Map(); // Map<socketId, {userId, socket}>
const userSockets = new Map(); // Map<userId, Set<socketId>>
const activeCalls = new Map(); // Map<callId, {callId, type, participants, startedAt, callerId}>
const callTimeouts = new Map(); // Map<callId, NodeJS.Timeout> - for auto-cleanup of unanswered calls
const CALL_INVITATION_TIMEOUT_MS = 60000; // 60 seconds timeout for call invitations

// Helper function to get user's sockets
function getUserSockets(userId) {
  const socketIds = userSockets.get(userId) || new Set();
  return Array.from(socketIds)
    .map(socketId => activeConnections.get(socketId))
    .filter(Boolean)
    .map(conn => conn.socket);
}

// Helper function to cleanup call state
function cleanupCallState(callId, reason = 'unknown') {
  console.log(`🧹 Cleaning up call state for call ${callId} (reason: ${reason})`);
  const call = activeCalls.get(callId);
  if (call) {
    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('call_ended', { callId, reason });
      });
    });
    // Remove from active calls
    activeCalls.delete(callId);
    // Clear timeout if exists
    if (callTimeouts.has(callId)) {
      clearTimeout(callTimeouts.get(callId));
      callTimeouts.delete(callId);
    }
    // Remove from participants' active calls
    call.participants.forEach(participantId => {
      const user = db ? db.collection('users').findOne({ _id: new ObjectId(participantId) }) : null;
      if (user && user.activeCalls) {
        db.collection('users').updateOne(
          { _id: new ObjectId(participantId) },
          { $pull: { activeCalls: callId } }
        );
      }
    });
  }
}

// Start a call
app.post('/api/calls/start', authenticateToken, async (req, res) => {
  try {
    const { callId: clientCallId, chatId, chatName, callType, participantIds, isGroupChat } = req.body;
    const callerId = req.user.id;

    console.log(`📞 [CALL_START] Received call request from ${callerId}`);
    console.log(`   Client callId: ${clientCallId}`);
    console.log(`   ChatId: ${chatId}, ChatName: ${chatName}`);
    console.log(`   CallType: ${callType}, Participants: ${participantIds?.length || 0}`);

    if (!chatId || !callType || !participantIds || !Array.isArray(participantIds)) {
      console.error('❌ [CALL_START] Missing required fields');
      return res.status(400).json({ error: 'chatId, callType, and participantIds array are required' });
    }

    // Accept both 'voice' and 'audio' for callType (normalize 'voice' to 'audio')
    const normalizedCallType = callType === 'voice' ? 'audio' : callType;
    if (!['audio', 'video'].includes(normalizedCallType)) {
      console.error(`❌ [CALL_START] Invalid callType: ${callType}`);
      return res.status(400).json({ error: 'callType must be "voice", "audio", or "video"' });
    }

    // Use client-provided callId if available, otherwise generate one
    const callId = clientCallId || new ObjectId().toString();
    console.log(`📞 [CALL_START] Using callId: ${callId}`);

    // Check if callId already exists in activeCalls (prevent overwriting)
    if (activeCalls.has(callId)) {
      const existingCall = activeCalls.get(callId);
      const timeSinceStart = new Date() - existingCall.startedAt;
      const minutesSinceStart = Math.floor(timeSinceStart / 1000 / 60);
      
      console.warn(`⚠️ [CALL_START] CallId ${callId} already exists in activeCalls`);
      console.warn(`   Started: ${existingCall.startedAt}, ${minutesSinceStart} minutes ago`);
      console.warn(`   Participants: ${existingCall.participants.join(', ')}`);
      
      // If call is older than 5 minutes, clean it up (likely stale)
      if (minutesSinceStart > 5) {
        console.log(`🧹 [CALL_START] Cleaning up stale call ${callId} (${minutesSinceStart} minutes old)`);
        cleanupCallState(callId, 'stale_call_replaced');
      } else {
        // Call is recent - reject new call with same ID to prevent overwrite
        console.error(`❌ [CALL_START] CallId ${callId} is already active (started ${minutesSinceStart} minutes ago)`);
        return res.status(409).json({ 
          error: 'Call ID already in use',
          message: 'A call with this ID is already active. Please use a different call ID or wait for the existing call to end.'
        });
      }
    }

    // Add caller to participants if not already included
    const allParticipants = [...new Set([callerId, ...participantIds])];
    console.log(`📞 [CALL_START] All participants: ${allParticipants.join(', ')}`);

    // Validate participant count (max 10 for mesh topology with 101 TURN ports)
    const MAX_PARTICIPANTS = 10;
    if (allParticipants.length > MAX_PARTICIPANTS) {
      console.error(`❌ [CALL_START] Too many participants: ${allParticipants.length} (max: ${MAX_PARTICIPANTS})`);
      return res.status(400).json({ 
        error: 'Too many participants',
        message: `Maximum ${MAX_PARTICIPANTS} participants allowed per call. You have ${allParticipants.length}.`
      });
    }

    // Validate that all participants exist and are in the chat (if group chat)
    if (isGroupChat && chatId) {
      try {
        const chat = await db.collection('chats').findOne({ _id: new ObjectId(chatId) });
        if (!chat) {
          console.error(`❌ [CALL_START] Chat not found: ${chatId}`);
          return res.status(404).json({ error: 'Chat not found' });
        }

        // Check if all participants are members of the chat
        const chatMemberIds = chat.members.map(m => m.toString());
        const invalidParticipants = allParticipants.filter(p => !chatMemberIds.includes(p));
        
        if (invalidParticipants.length > 0) {
          console.error(`❌ [CALL_START] Invalid participants (not in chat): ${invalidParticipants.join(', ')}`);
          return res.status(403).json({ 
            error: 'Invalid participants',
            message: `Some participants are not members of this chat: ${invalidParticipants.join(', ')}`
          });
        }
      } catch (err) {
        console.error(`❌ [CALL_START] Error validating chat membership:`, err);
        return res.status(500).json({ error: 'Error validating chat membership' });
      }
    }

    // Validate that all participant user IDs exist in database
    try {
      const participantObjectIds = allParticipants.map(id => new ObjectId(id));
      const existingUsers = await db.collection('users').find({
        _id: { $in: participantObjectIds }
      }).toArray();
      
      const existingUserIds = existingUsers.map(u => u._id.toString());
      const invalidUserIds = allParticipants.filter(id => !existingUserIds.includes(id));
      
      if (invalidUserIds.length > 0) {
        console.error(`❌ [CALL_START] Invalid user IDs: ${invalidUserIds.join(', ')}`);
        return res.status(400).json({ 
          error: 'Invalid participants',
          message: `Some user IDs do not exist: ${invalidUserIds.join(', ')}`
        });
      }
    } catch (err) {
      console.error(`❌ [CALL_START] Error validating user IDs:`, err);
      return res.status(500).json({ error: 'Error validating participants' });
    }

    // Store call in active calls
    activeCalls.set(callId, {
      callId,
      type: normalizedCallType,
      participants: allParticipants,
      startedAt: new Date(),
      callerId,
      chatId,
      chatName,
      isGroupChat: isGroupChat || false
    });

    // Send call invitation to all participants
    const invitationData = {
      callId,
      chatId,
      chatName: chatName || 'Unknown Chat',
      callType: normalizedCallType,
      callerId,
      callerName: req.user.name || req.user.email || 'Unknown',
      participantIds: allParticipants,
      isGroupChat: isGroupChat || false,
      timestamp: new Date()
    };

    console.log(`📞 [CALL_START] Sending invitations to ${allParticipants.length - 1} participant(s)`);

    // Send via Socket.IO to online users AND FCM to mobile devices
    // For call invitations, we ALWAYS send FCM to mobile devices (iOS/Android) 
    // regardless of online status, because:
    // 1. App might be closed/terminated, so Socket.IO won't work
    // 2. FCM is more reliable for waking up the app
    // 3. Calls need immediate notification even if socket connection is stale
    let onlineCount = 0;
    let offlineCount = 0;
    let fcmCount = 0;
    
    for (const participantId of allParticipants) {
      if (participantId !== callerId) {
        // Try multiple methods to ensure delivery
        const sockets = getUserSockets(participantId);
        const userRoom = `user:${participantId}`;
        const directRoom = participantId;
        
        console.log(`📞 [CALL_START] Sending to participant ${participantId}`);
        console.log(`   Found ${sockets.length} socket(s)`);
        console.log(`   User rooms: ${directRoom}, ${userRoom}`);
        
        // Get user info to determine FCM sending strategy
        let userPlatform = 'unknown';
        let isMobile = false;
        let hasFcmToken = false;
        try {
          const user = await db.collection('users').findOne({ _id: new ObjectId(participantId) });
          if (user) {
            userPlatform = user.fcmPlatform || 'unknown';
            isMobile = userPlatform === 'ios' || userPlatform === 'android';
            hasFcmToken = !!(user.fcmToken && user.fcmToken.trim());
            console.log(`📱 [CALL_START] User ${participantId} - Platform: ${userPlatform}, Mobile: ${isMobile}, Has FCM Token: ${hasFcmToken}`);
          }
        } catch (err) {
          console.warn(`⚠️ [CALL_START] Error getting user info for ${participantId}:`, err.message);
        }
        
        // Send via Socket.IO if user is online
        if (sockets.length > 0) {
          // Method 1: Emit to user's room (most reliable)
          io.to(directRoom).emit('call_invitation', invitationData);
          io.to(userRoom).emit('call_invitation', invitationData);
          
          // Method 2: Also emit directly to each socket (backup)
          sockets.forEach(socket => {
            if (socket && socket.connected) {
              socket.emit('call_invitation', invitationData);
              console.log(`   ✅ Emitted to socket ${socket.id}`);
            } else {
              console.warn(`   ⚠️ Socket ${socket?.id} is not connected`);
            }
          });
          
          onlineCount++;
          console.log(`✅ [CALL_START] Sent call invitation via Socket.IO to user ${participantId} (online)`);
        } else {
          offlineCount++;
          console.log(`📱 [CALL_START] User ${participantId} is offline (no sockets)`);
        }
        
        // ALWAYS send FCM for mobile devices (iOS/Android) for call invitations
        // This ensures the app wakes up even if closed/terminated
        // Also send if user has FCM token (safety check)
        if (isMobile || hasFcmToken) {
          const reason = isMobile 
            ? (userPlatform === 'ios' 
                ? 'iOS device (always send FCM for call invitations to wake app)'
                : 'Android device (always send FCM for call invitations to wake app)')
            : 'User has FCM token (sending FCM as backup)';
          console.log(`📱 [CALL_START] User ${participantId} - ${reason}, sending FCM notification`);
          sendFCMNotification(
            participantId,
            `Incoming ${normalizedCallType} call`,
            `${invitationData.callerName} is calling you`,
            {
              type: 'call_invitation',
              callId: callId.toString(),
              chatId: chatId.toString(),
              chatName: invitationData.chatName?.toString() || '',
              callType: normalizedCallType.toString(),
              callerId: callerId.toString(),
              callerName: invitationData.callerName?.toString() || '',
              isGroupChat: (invitationData.isGroupChat === true || invitationData.isGroupChat === 'true') ? 'true' : 'false'
            }
          ).then(() => {
            fcmCount++;
            console.log(`✅ [CALL_START] FCM notification sent to ${participantId}`);
          }).catch(err => {
            console.error(`❌ [CALL_START] Error sending FCM call invitation to ${participantId}:`, err);
          });
        } else if (sockets.length === 0) {
          // For non-mobile platforms without FCM token, only send FCM if offline
          console.log(`📱 [CALL_START] User ${participantId} is offline (non-mobile, no FCM token), sending FCM notification anyway`);
          sendFCMNotification(
            participantId,
            `Incoming ${normalizedCallType} call`,
            `${invitationData.callerName} is calling you`,
            {
              type: 'call_invitation',
              callId: callId.toString(),
              chatId: chatId.toString(),
              chatName: invitationData.chatName?.toString() || '',
              callType: normalizedCallType.toString(),
              callerId: callerId.toString(),
              callerName: invitationData.callerName?.toString() || '',
              isGroupChat: (invitationData.isGroupChat === true || invitationData.isGroupChat === 'true') ? 'true' : 'false'
            }
          ).then(() => {
            fcmCount++;
            console.log(`✅ [CALL_START] FCM notification sent to ${participantId}`);
          }).catch(err => {
            console.error(`❌ [CALL_START] Error sending FCM call invitation to ${participantId}:`, err);
          });
        }
      }
    }

    console.log(`📞 [CALL_START] Summary: ${onlineCount} online, ${offlineCount} offline, ${fcmCount} FCM sent`);

    // Set timeout to auto-cleanup if call is not accepted within 60 seconds
    const timeoutId = setTimeout(() => {
      const call = activeCalls.get(callId);
      if (call) {
        // Check if call was accepted (if any participant accepted, don't timeout)
        // For now, we'll timeout if no one accepted after 60 seconds
        console.log(`⏰ [CALL_TIMEOUT] Call ${callId} timed out after ${CALL_INVITATION_TIMEOUT_MS / 1000} seconds`);
        cleanupCallState(callId, 'timeout_no_answer');
      }
    }, CALL_INVITATION_TIMEOUT_MS);
    
    callTimeouts.set(callId, timeoutId);
    console.log(`⏰ [CALL_START] Set timeout for call ${callId} (${CALL_INVITATION_TIMEOUT_MS / 1000}s)`);

    res.status(200).json({
      success: true,
      callId,
      message: 'Call started successfully'
    });
  } catch (error) {
    console.error('❌ [CALL_START] Error starting call:', error);
    res.status(500).json({ error: 'Failed to start call' });
  }
});

// Save call history
app.post('/api/calls/history', authenticateToken, async (req, res) => {
  try {
    const {
      callId,
      chatId,
      callType,
      participants,
      status,
      duration,
      quality,
      networkQuality,
      connectionScore
    } = req.body;

    if (!callId || !chatId || !callType || !participants || !Array.isArray(participants)) {
      return res.status(400).json({ error: 'callId, chatId, callType, and participants array are required' });
    }

    const callHistory = {
      callId,
      chatId,
      callType,
      participants: participants.map(id => new ObjectId(id)),
      status: status || 'completed',
      duration: duration || 0,
      quality: quality || {},
      networkQuality: networkQuality || {},
      connectionScore: connectionScore || 0,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await db.collection('calls').insertOne(callHistory);

    res.status(201).json({
      success: true,
      message: 'Call history saved',
      callId
    });
  } catch (error) {
    console.error('Error saving call history:', error);
    res.status(500).json({ error: 'Failed to save call history' });
  }
});

// Get call history
app.get('/api/calls/history', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 50, status, callType } = req.query;

    const query = {
      participants: new ObjectId(userId)
    };

    if (status) query.status = status;
    if (callType) query.callType = callType;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const calls = await db.collection('calls')
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();

    const total = await db.collection('calls').countDocuments(query);

    res.status(200).json({
      success: true,
      calls: calls.map(call => ({
        ...call,
        _id: call._id.toString(),
        callId: call.callId,
        participants: call.participants.map(id => id.toString())
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error getting call history:', error);
    res.status(500).json({ error: 'Failed to get call history' });
  }
});

// Forward call
app.post('/api/calls/forward', authenticateToken, async (req, res) => {
  try {
    const { callId, targetUserId } = req.body;
    const userId = req.user.id;

    if (!callId || !targetUserId) {
      return res.status(400).json({ error: 'callId and targetUserId are required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    if (!call.participants.includes(userId)) {
      return res.status(403).json({ error: 'You are not a participant in this call' });
    }

    // Add target user to call
    if (!call.participants.includes(targetUserId)) {
      call.participants.push(targetUserId);
    }

    // Notify target user
    const sockets = getUserSockets(targetUserId);
    sockets.forEach(socket => {
      socket.emit('call_forwarded', { callId, forwardedBy: userId });
    });

    res.status(200).json({ success: true, message: 'Call forwarded successfully' });
  } catch (error) {
    console.error('Error forwarding call:', error);
    res.status(500).json({ error: 'Failed to forward call' });
  }
});

// Hold call
app.post('/api/calls/waiting/hold', authenticateToken, async (req, res) => {
  try {
    const { callId } = req.body;
    const userId = req.user.id;

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('call_held', { callId, heldBy: userId });
      });
    });

    res.status(200).json({ success: true, message: 'Call held successfully' });
  } catch (error) {
    console.error('Error holding call:', error);
    res.status(500).json({ error: 'Failed to hold call' });
  }
});

// Resume call
app.post('/api/calls/waiting/resume', authenticateToken, async (req, res) => {
  try {
    const { callId } = req.body;
    const userId = req.user.id;

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('call_resumed', { callId, resumedBy: userId });
      });
    });

    res.status(200).json({ success: true, message: 'Call resumed successfully' });
  } catch (error) {
    console.error('Error resuming call:', error);
    res.status(500).json({ error: 'Failed to resume call' });
  }
});

// Transfer call
app.post('/api/calls/transfer', authenticateToken, async (req, res) => {
  try {
    const { callId, targetUserId, transferType } = req.body;
    const userId = req.user.id;

    if (!callId || !targetUserId) {
      return res.status(400).json({ error: 'callId and targetUserId are required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Remove current user and add target user
    call.participants = call.participants.filter(id => id !== userId);
    if (!call.participants.includes(targetUserId)) {
      call.participants.push(targetUserId);
    }

    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('call_transferred', { callId, transferredBy: userId, transferType });
      });
    });

    res.status(200).json({ success: true, message: 'Call transferred successfully' });
  } catch (error) {
    console.error('Error transferring call:', error);
    res.status(500).json({ error: 'Failed to transfer call' });
  }
});

// Mute participant
app.post('/api/calls/participants/mute', authenticateToken, async (req, res) => {
  try {
    const { callId, participantId, muted } = req.body;
    const userId = req.user.id;

    if (!callId || participantId === undefined || muted === undefined) {
      return res.status(400).json({ error: 'callId, participantId, and muted are required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Notify all participants
    call.participants.forEach(pId => {
      const sockets = getUserSockets(pId);
      sockets.forEach(socket => {
        socket.emit('participant_muted', { callId, participantId, muted, mutedBy: userId });
      });
    });

    res.status(200).json({ success: true, message: 'Participant mute status updated' });
  } catch (error) {
    console.error('Error muting participant:', error);
    res.status(500).json({ error: 'Failed to mute participant' });
  }
});

// Mute all participants
app.post('/api/calls/participants/mute-all', authenticateToken, async (req, res) => {
  try {
    const { callId, muted } = req.body;
    const userId = req.user.id;

    if (!callId || muted === undefined) {
      return res.status(400).json({ error: 'callId and muted are required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('all_participants_muted', { callId, muted, mutedBy: userId });
      });
    });

    res.status(200).json({ success: true, message: 'All participants mute status updated' });
  } catch (error) {
    console.error('Error muting all participants:', error);
    res.status(500).json({ error: 'Failed to mute all participants' });
  }
});

// Start screen sharing
app.post('/api/calls/screen-share/start', authenticateToken, async (req, res) => {
  try {
    const { callId } = req.body;
    const userId = req.user.id;

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('screen_sharing_started', { callId, startedBy: userId });
      });
    });

    res.status(200).json({ success: true, message: 'Screen sharing started' });
  } catch (error) {
    console.error('Error starting screen sharing:', error);
    res.status(500).json({ error: 'Failed to start screen sharing' });
  }
});

// Stop screen sharing
app.post('/api/calls/screen-share/stop', authenticateToken, async (req, res) => {
  try {
    const { callId } = req.body;
    const userId = req.user.id;

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    const call = activeCalls.get(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Notify all participants
    call.participants.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('screen_sharing_stopped', { callId, stoppedBy: userId });
      });
    });

    res.status(200).json({ success: true, message: 'Screen sharing stopped' });
  } catch (error) {
    console.error('Error stopping screen sharing:', error);
    res.status(500).json({ error: 'Failed to stop screen sharing' });
  }
});

// Schedule call
app.post('/api/calls/schedule', authenticateToken, async (req, res) => {
  try {
    const { chatId, callType, participantIds, scheduledAt, reminderMinutes } = req.body;
    const userId = req.user.id;

    if (!chatId || !callType || !participantIds || !Array.isArray(participantIds) || !scheduledAt) {
      return res.status(400).json({ error: 'chatId, callType, participantIds array, and scheduledAt are required' });
    }

    const scheduledCall = {
      chatId,
      callType,
      participantIds: participantIds.map(id => new ObjectId(id)),
      scheduledBy: new ObjectId(userId),
      scheduledAt: new Date(scheduledAt),
      reminderMinutes: reminderMinutes || 15,
      status: 'scheduled',
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('scheduled_calls').insertOne(scheduledCall);

    // Notify participants
    participantIds.forEach(participantId => {
      const sockets = getUserSockets(participantId);
      sockets.forEach(socket => {
        socket.emit('call_scheduled', {
          scheduledCallId: result.insertedId.toString(),
          ...scheduledCall,
          participantIds: scheduledCall.participantIds.map(id => id.toString())
        });
      });
    });

    res.status(201).json({
      success: true,
      scheduledCallId: result.insertedId.toString(),
      message: 'Call scheduled successfully'
    });
  } catch (error) {
    console.error('Error scheduling call:', error);
    res.status(500).json({ error: 'Failed to schedule call' });
  }
});

// Get scheduled calls
app.get('/api/calls/schedule', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;

    const query = {
      participantIds: new ObjectId(userId)
    };

    if (status) query.status = status;

    const scheduledCalls = await db.collection('scheduled_calls')
      .find(query)
      .sort({ scheduledAt: 1 })
      .toArray();
f
    res.status(200).json({
      success: true,
      scheduledCalls: scheduledCalls.map(call => ({
        ...call,
        _id: call._id.toString(),
        scheduledCallId: call._id.toString(),
        participantIds: call.participantIds.map(id => id.toString()),
        scheduledBy: call.scheduledBy.toString()
      }))
    });
  } catch (error) {
    console.error('Error getting scheduled calls:', error);
    res.status(500).json({ error: 'Failed to get scheduled calls' });
  }
});

// Cancel scheduled call
app.delete('/api/calls/schedule/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const scheduledCall = await db.collection('scheduled_calls').findOne({ _id: new ObjectId(id) });
    if (!scheduledCall) {
      return res.status(404).json({ error: 'Scheduled call not found' });
    }

    if (scheduledCall.scheduledBy.toString() !== userId) {
      return res.status(403).json({ error: 'Only the scheduler can cancel this call' });
    }

    await db.collection('scheduled_calls').updateOne(
      { _id: new ObjectId(id) },
      { $set: { status: 'cancelled', updatedAt: new Date() } }
    );

    // Notify participants
    scheduledCall.participantIds.forEach(participantId => {
      const sockets = getUserSockets(participantId.toString());
      sockets.forEach(socket => {
        socket.emit('call_cancelled', { scheduledCallId: id });
      });
    });

    res.status(200).json({ success: true, message: 'Scheduled call cancelled' });
  } catch (error) {
    console.error('Error cancelling scheduled call:', error);
    res.status(500).json({ error: 'Failed to cancel scheduled call' });
  }
});

// Start recording (infrastructure ready)
app.post('/api/calls/recording/start', authenticateToken, async (req, res) => {
  try {
    const { callId } = req.body;
    const userId = req.user.id;

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    // TODO: Implement recording infrastructure
    res.status(200).json({ success: true, message: 'Recording started (infrastructure ready)' });
  } catch (error) {
    console.error('Error starting recording:', error);
    res.status(500).json({ error: 'Failed to start recording' });
  }
});

// Stop recording (infrastructure ready)
app.post('/api/calls/recording/stop', authenticateToken, async (req, res) => {
  try {
    const { callId } = req.body;
    const userId = req.user.id;

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    // TODO: Implement recording infrastructure
    res.status(200).json({ success: true, message: 'Recording stopped (infrastructure ready)' });
  } catch (error) {
    console.error('Error stopping recording:', error);
    res.status(500).json({ error: 'Failed to stop recording' });
  }
});

// =========================================
// RINGTONE ENDPOINTS
// =========================================

// Get ringtone preference
app.get('/api/users/ringtone', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const user = await db.collection('users').findOne(
      { _id: new ObjectId(userId) },
      { projection: { customRingtone: 1, customRingtoneUrl: 1 } }
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.status(200).json({
      success: true,
      ringtoneName: user.customRingtone || null,
      ringtoneUrl: user.customRingtoneUrl || null
    });
  } catch (error) {
    console.error('❌ Error getting ringtone preference:', error);
    return res.status(500).json({ error: 'Failed to get ringtone preference' });
  }
});

// Update ringtone preference
app.put('/api/users/ringtone', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { ringtoneName, ringtoneUrl } = req.body;

    if (!db) {
      return res.status(500).json({ error: 'Database not available' });
    }

    const updateData = {};
    if (ringtoneName !== undefined) {
      updateData.customRingtone = ringtoneName;
    }
    if (ringtoneUrl !== undefined) {
      updateData.customRingtoneUrl = ringtoneUrl;
    }

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ error: 'No ringtone data provided' });
    }

    updateData.updatedAt = new Date();

    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: updateData }
    );

    console.log(`✅ Updated ringtone preference for user ${userId}: ${ringtoneName || 'default'}`);

    return res.status(200).json({
      success: true,
      message: 'Ringtone preference updated',
      ringtoneName: ringtoneName || null,
      ringtoneUrl: ringtoneUrl || null
    });
  } catch (error) {
    console.error('❌ Error updating ringtone preference:', error);
    return res.status(500).json({ error: 'Failed to update ringtone preference' });
  }
});

// =========================================
// SCHEDULED BROADCASTS CRON JOB
// =========================================
const cron = require('node-cron');

// Check for scheduled broadcasts every minute
cron.schedule('* * * * *', async () => {
  try {
    if (!db) return;
    
    const now = new Date();
    const scheduledBroadcasts = await db.collection('scheduled_broadcasts')
      .find({
        status: 'scheduled',
        scheduledAt: { $lte: now }
      })
      .toArray();
    
    if (scheduledBroadcasts.length === 0) return;
    
    console.log(`📢 Processing ${scheduledBroadcasts.length} scheduled broadcast(s)...`);
    
    for (const broadcast of scheduledBroadcasts) {
      try {
        // Get users based on segment filter
        let users;
        if (broadcast.userSegment) {
          const segment = broadcast.userSegment;
          const query = {};
          if (segment.role) query.role = segment.role;
          if (segment.status) query.status = segment.status;
          users = await db.collection('users').find(query).toArray();
        } else {
          users = await db.collection('users').find({}).toArray();
        }
        
        // Send broadcast (reuse existing broadcast logic)
        const adminUser = await db.collection('users').findOne({ _id: new ObjectId(broadcast.createdBy) });
        const senderName = adminUser?.displayName || adminUser?.email || 'Admin';
        
        // Create broadcast messages for storage
        const broadcastMessages = users.map(user => ({
          type: 'broadcast',
          content: broadcast.message,
          senderId: broadcast.createdBy,
          recipientId: user._id,
          createdAt: new Date(),
          read: false
        }));
        
        if (broadcastMessages.length > 0) {
          await db.collection('messages').insertMany(broadcastMessages);
        }
        
        // Emit via Socket.IO
        if (io) {
          const notificationPayload = {
            title: '📢 Broadcast Message',
            body: broadcast.message.length > 50 ? broadcast.message.substring(0, 50) + '...' : broadcast.message,
            data: {
              type: 'broadcast',
              senderId: broadcast.createdBy,
              senderName: senderName,
              message: broadcast.message,
              timestamp: new Date(),
            },
            timestamp: new Date(),
          };
          
          const broadcastPayload = {
            title: '📢 Broadcast',
            body: broadcast.message,
            chatId: null,
            senderId: broadcast.createdBy,
            senderName: senderName,
            messageType: broadcast.type || 'text',
            timestamp: new Date(),
          };
          
          io.emit('broadcast_notification', broadcastPayload);
          io.emit('notification', notificationPayload);
        }
        
        // Send FCM notifications
        const sendFCMNotification = app.locals.sendFCMNotification;
        if (sendFCMNotification) {
          const title = '📢 Broadcast Message';
          const body = broadcast.message.length > 100 ? broadcast.message.substring(0, 100) + '...' : broadcast.message;
          
          for (const user of users) {
            const userId = user._id.toString();
            if (userId === broadcast.createdBy) continue;
            
            sendFCMNotification(
              userId,
              title,
              body,
              {
                type: 'broadcast',
                senderId: broadcast.createdBy,
                senderName: senderName,
                message: broadcast.message,
                timestamp: new Date().toISOString(),
              }
            ).catch(err => {
              console.error(`Error sending FCM to user ${userId}:`, err.message);
            });
          }
        }
        
        // Calculate next scheduled time if recurring
        let nextScheduledAt = null;
        if (broadcast.recurrence === 'daily') {
          nextScheduledAt = new Date(broadcast.scheduledAt);
          nextScheduledAt.setDate(nextScheduledAt.getDate() + 1);
        } else if (broadcast.recurrence === 'weekly') {
          nextScheduledAt = new Date(broadcast.scheduledAt);
          nextScheduledAt.setDate(nextScheduledAt.getDate() + 7);
        } else if (broadcast.recurrence === 'monthly') {
          nextScheduledAt = new Date(broadcast.scheduledAt);
          nextScheduledAt.setMonth(nextScheduledAt.getMonth() + 1);
        }
        
        // Update broadcast status
        if (nextScheduledAt) {
          // Recurring - schedule next occurrence
          await db.collection('scheduled_broadcasts').updateOne(
            { _id: broadcast._id },
            {
              $set: {
                scheduledAt: nextScheduledAt,
                sentAt: new Date(),
                lastSentAt: new Date(),
              }
            }
          );
        } else {
          // One-time - mark as sent
          await db.collection('scheduled_broadcasts').updateOne(
            { _id: broadcast._id },
            {
              $set: {
                status: 'sent',
                sentAt: new Date(),
              }
            }
          );
        }
        
        console.log(`✅ Scheduled broadcast sent: ${broadcast._id}`);
      } catch (error) {
        console.error(`❌ Error processing scheduled broadcast ${broadcast._id}:`, error);
        await db.collection('scheduled_broadcasts').updateOne(
          { _id: broadcast._id },
          {
            $set: {
              status: 'error',
              error: error.message,
            }
          }
        );
      }
    }
  } catch (error) {
    console.error('Error in scheduled broadcasts cron job:', error);
  }
});

console.log('⏰ Scheduled broadcasts cron job started (runs every minute)');

// =========================================
// Socket.IO
// =========================================
io.on('connection', async (socket) => {
  console.log(`🔌 User connected: ${socket.userId}`);
  console.log(`   Socket ID: ${socket.id}`);
  console.log(`   User ID type: ${typeof socket.userId}`);
  console.log(`   User ID value: "${socket.userId}"`);
  
  // Track connection
  activeConnections.set(socket.id, { userId: socket.userId, socket });
  if (!userSockets.has(socket.userId)) {
    userSockets.set(socket.userId, new Set());
  }
  userSockets.get(socket.userId).add(socket.id);
  
  if (socket.refreshedAuthToken) {
    const expiredAtIso = socket.tokenExpiredAt instanceof Date ? socket.tokenExpiredAt.toISOString() : undefined;
    socket.emit(SOCKET_TOKEN_REFRESH_EVENT, {
      token: socket.refreshedAuthToken,
      expiresIn: JWT_EXPIRES_IN,
      refreshedAt: new Date().toISOString(),
      expiredAt: expiredAtIso,
    });
    console.log(`🔁 Issued refreshed auth token for user ${socket.userId} after socket connection`);
  }
  
  // Join user to their personal room using socket.userId
  socket.join(socket.userId);
  socket.join(`user:${socket.userId}`); // Also join user: prefix room for call routing
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
          socket.join(`user:${mongoId}`);
          console.log(`✅ User also joined MongoDB _id room: "${mongoId}"`);
        }
        
        // If user is admin, join admin room for activity feed
        if (user.role === 'admin') {
          socket.join('admin_room');
          console.log(`✅ Admin ${socket.userId} joined admin room for activity feed`);
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
  
  // =========================================
  // CALL SOCKET.IO HANDLERS
  // =========================================

  // Join call room
  socket.on('join_call', (data) => {
    try {
      console.log('\n🔵 [SERVER] ========== JOIN CALL ==========');
      console.log('🔵 [SERVER] Socket.userId:', socket.userId);
      console.log('🔵 [SERVER] Socket ID:', socket.id);
      console.log('🔵 [SERVER] Data received:', JSON.stringify(data, null, 2));
      
      const { callId } = data;
      if (!callId) {
        console.warn('❌ [SERVER] join_call: missing callId');
        console.warn('   Data:', data);
        return;
      }
      const roomName = `call:${callId}`;
      
      // Check current rooms
      const currentRooms = Array.from(socket.rooms);
      console.log('🔵 [SERVER] Current rooms before join:', currentRooms);
      
      socket.join(roomName);
      
      // Verify join
      const roomsAfterJoin = Array.from(socket.rooms);
      console.log('🔵 [SERVER] Rooms after join:', roomsAfterJoin);
      console.log('🔵 [SERVER] Joined room:', roomName);
      
      // Check how many sockets are in this room
      const socketsInRoom = io.sockets.adapter.rooms.get(roomName);
      console.log('🔵 [SERVER] Total sockets in call room:', socketsInRoom ? socketsInRoom.size : 0);
      if (socketsInRoom && socketsInRoom.size > 0) {
        console.log('🔵 [SERVER] Socket IDs in room:', Array.from(socketsInRoom));
      }
      
      console.log(`✅ [SERVER] User ${socket.userId} joined call room: ${roomName}`);
      console.log('🔵 [SERVER] ===========================================\n');
    } catch (error) {
      console.error('❌ [SERVER] Error in join_call handler:', error);
      console.error('❌ [SERVER] Error stack:', error.stack);
      socket.emit('call_error', { error: 'Failed to join call room' });
    }
  });

  // Leave call room
  socket.on('leave_call', (data) => {
    try {
      const { callId } = data;
      if (!callId) {
        console.warn('leave_call: missing callId');
        return;
      }
      const roomName = `call:${callId}`;
      socket.leave(roomName);
      console.log(`✅ User ${socket.userId} left call room: ${roomName}`);
    } catch (error) {
      console.error('Error in leave_call handler:', error);
      socket.emit('call_error', { error: 'Failed to leave call room' });
    }
  });

  // Call accept
  socket.on('call_accept', (data) => {
    try {
      const { callId, targetUserId } = data;
      if (!callId) {
        console.warn('call_accept: missing callId');
        return;
      }

      const call = activeCalls.get(callId);
      if (!call) {
        console.warn(`call_accept: call ${callId} not found`);
        return;
      }

      // Clear timeout since call was accepted
      if (callTimeouts.has(callId)) {
        clearTimeout(callTimeouts.get(callId));
        callTimeouts.delete(callId);
        console.log(`⏰ [CALL_ACCEPT] Cleared timeout for call ${callId} (call was accepted)`);
      }

      console.log(`📞 [CALL_ACCEPT] Call ${callId} accepted by user ${socket.userId}`);
      console.log(`   Participants: ${call.participants.join(', ')}`);

      // Route to call room, target user's room, or all participants
      const roomName = `call:${callId}`;
      const targetRoom = targetUserId ? `user:${targetUserId}` : null;

      const acceptData = {
        callId,
        acceptedBy: socket.userId,
        userId: socket.userId, // Also include userId for compatibility
        timestamp: new Date()
      };

      // Emit to call room (all participants in the call)
      io.to(roomName).emit('call_accepted', acceptData);
      console.log(`✅ [CALL_ACCEPT] Emitted to call room: ${roomName}`);

      // Also emit to target user's personal room if specified
      if (targetRoom) {
        io.to(targetRoom).emit('call_accepted', acceptData);
        console.log(`✅ [CALL_ACCEPT] Emitted to target room: ${targetRoom}`);
      }

      // Fallback: emit to all participants' personal rooms (ensure caller receives it)
      call.participants.forEach(participantId => {
        if (participantId !== socket.userId) {
          const participantRoom = `user:${participantId}`;
          io.to(participantRoom).emit('call_accepted', acceptData);
          console.log(`✅ [CALL_ACCEPT] Emitted to participant room: ${participantRoom}`);
          
          // Also emit directly to sockets as backup
          const participantSockets = getUserSockets(participantId);
          participantSockets.forEach(s => {
            s.emit('call_accepted', acceptData);
            console.log(`✅ [CALL_ACCEPT] Emitted directly to socket: ${s.id}`);
          });
        }
      });

      console.log(`✅ [CALL_ACCEPT] Call ${callId} accepted by user ${socket.userId} - notification sent to all participants`);
    } catch (error) {
      console.error('❌ [CALL_ACCEPT] Error in call_accept handler:', error);
      socket.emit('call_error', { error: 'Failed to accept call' });
    }
  });

  // Call reject
  socket.on('call_reject', (data) => {
    try {
      const { callId, targetUserId } = data;
      if (!callId) {
        console.warn('call_reject: missing callId');
        return;
      }

      const call = activeCalls.get(callId);
      if (!call) {
        console.warn(`call_reject: call ${callId} not found`);
        return;
      }

      const roomName = `call:${callId}`;
      const targetRoom = targetUserId ? `user:${targetUserId}` : null;

      // Emit to call room
      io.to(roomName).emit('call_rejected', {
        callId,
        rejectedBy: socket.userId,
        timestamp: new Date()
      });

      // Also emit to target user's personal room if specified
      if (targetRoom) {
        io.to(targetRoom).emit('call_rejected', {
          callId,
          rejectedBy: socket.userId,
          timestamp: new Date()
        });
      }

      // Fallback: emit to all participants' personal rooms
      call.participants.forEach(participantId => {
        if (participantId !== socket.userId) {
          const participantSockets = getUserSockets(participantId);
          participantSockets.forEach(s => {
            s.emit('call_rejected', {
              callId,
              rejectedBy: socket.userId,
              timestamp: new Date()
            });
          });
        }
      });

      // Cleanup call state
      cleanupCallState(callId, 'rejected');

      console.log(`✅ Call ${callId} rejected by user ${socket.userId}`);
    } catch (error) {
      console.error('Error in call_reject handler:', error);
      socket.emit('call_error', { error: 'Failed to reject call' });
    }
  });

  // Call end
  socket.on('call_end', (data) => {
    try {
      const { callId, targetUserId } = data;
      if (!callId) {
        console.warn('call_end: missing callId');
        return;
      }

      const call = activeCalls.get(callId);
      if (!call) {
        console.warn(`call_end: call ${callId} not found`);
        return;
      }

      // Validate that sender is a participant in the call
      if (!call.participants.includes(socket.userId)) {
        console.warn(`❌ [CALL_END] User ${socket.userId} is not a participant in call ${callId} - ignoring`);
        socket.emit('call_error', { 
          callId, 
          error: 'Not a participant',
          message: 'You are not a participant in this call'
        });
        return;
      }

      console.log(`🔴 [CALL_END] Call ${callId} ended by user ${socket.userId}`);
      console.log(`   Participants: ${call.participants.join(', ')}`);

      const roomName = `call:${callId}`;
      const targetRoom = targetUserId ? `user:${targetUserId}` : null;

      const endData = {
        callId,
        endedBy: socket.userId,
        userId: socket.userId, // Also include userId for compatibility
        timestamp: new Date()
      };

      // Emit to call room (all participants in the call)
      io.to(roomName).emit('call_ended', endData);
      console.log(`✅ [CALL_END] Emitted to call room: ${roomName}`);

      // Also emit to target user's personal room if specified
      if (targetRoom) {
        io.to(targetRoom).emit('call_ended', endData);
        console.log(`✅ [CALL_END] Emitted to target room: ${targetRoom}`);
      }

      // Fallback: emit to all participants' personal rooms (ensure all receive it)
      call.participants.forEach(participantId => {
        if (participantId !== socket.userId) {
          const participantRoom = `user:${participantId}`;
          io.to(participantRoom).emit('call_ended', endData);
          console.log(`✅ [CALL_END] Emitted to participant room: ${participantRoom}`);
          
          // Also emit directly to sockets as backup
          const participantSockets = getUserSockets(participantId);
          participantSockets.forEach(s => {
            s.emit('call_ended', endData);
            console.log(`✅ [CALL_END] Emitted directly to socket: ${s.id}`);
          });
        }
      });

      // Cleanup call state
      cleanupCallState(callId, 'ended');

      console.log(`✅ [CALL_END] Call ${callId} ended by user ${socket.userId} - notification sent to all participants`);
    } catch (error) {
      console.error('❌ [CALL_END] Error in call_end handler:', error);
      socket.emit('call_error', { error: 'Failed to end call' });
    }
  });

  // WebRTC offer
  socket.on('webrtc_offer', (data) => {
    try {
      console.log('\n🔵 [SERVER] ========== WebRTC OFFER RECEIVED ==========');
      console.log('🔵 [SERVER] From socket.userId:', socket.userId);
      console.log('🔵 [SERVER] Socket ID:', socket.id);
      console.log('🔵 [SERVER] Data received:', JSON.stringify(data, null, 2));
      
      const { callId, offer, targetUserId } = data;
      if (!callId || !offer) {
        console.warn('❌ [SERVER] webrtc_offer: missing callId or offer');
        console.warn('   callId:', callId);
        console.warn('   offer:', offer);
        return;
      }

      // Validate that call exists in activeCalls
      if (!activeCalls.has(callId)) {
        console.warn(`❌ [SERVER] webrtc_offer: Call ${callId} does not exist in activeCalls - ignoring`);
        socket.emit('webrtc_error', { 
          callId, 
          error: 'Call not found',
          message: 'The call does not exist or has already ended'
        });
        return;
      }

      const call = activeCalls.get(callId);
      // Validate that sender is a participant in the call
      if (!call.participants.includes(socket.userId)) {
        console.warn(`❌ [SERVER] webrtc_offer: User ${socket.userId} is not a participant in call ${callId} - ignoring`);
        socket.emit('webrtc_error', { 
          callId, 
          error: 'Not a participant',
          message: 'You are not a participant in this call'
        });
        return;
      }

      const roomName = `call:${callId}`;
      const targetRoom = targetUserId ? `user:${targetUserId}` : null;

      console.log('🔵 [SERVER] Room name:', roomName);
      console.log('🔵 [SERVER] Target room:', targetRoom);
      console.log('🔵 [SERVER] Target user ID:', targetUserId);

      // Check if offer contains SDP
      if (offer && offer.sdp) {
        const hasAudio = offer.sdp.includes('m=audio');
        const hasVideo = offer.sdp.includes('m=video');
        console.log('🔵 [SERVER] Offer SDP contains - Audio:', hasAudio, 'Video:', hasVideo);
        if (!hasAudio && !hasVideo) {
          console.warn('⚠️ [SERVER] WARNING: Offer SDP does not contain media!');
        }
      }

      // Check if target user is in the room
      if (targetRoom) {
        const socketsInRoom = io.sockets.adapter.rooms.get(targetRoom);
        console.log('🔵 [SERVER] Sockets in target room:', socketsInRoom ? Array.from(socketsInRoom).length : 0);
        if (socketsInRoom && socketsInRoom.size > 0) {
          console.log('🔵 [SERVER] Socket IDs in room:', Array.from(socketsInRoom));
        } else {
          console.warn('⚠️ [SERVER] WARNING: No sockets found in target room:', targetRoom);
        }
      }

      // Route to call room or target user
      if (targetRoom) {
        io.to(targetRoom).emit('webrtc_offer', {
          callId,
          offer,
          userId: socket.userId, // Client expects 'userId', not 'fromUserId'
          fromUserId: socket.userId // Keep for backward compatibility
        });
        console.log(`✅ [SERVER] WebRTC offer sent to target room: ${targetRoom}`);
      } else {
        // Broadcast to call room except sender
        socket.to(roomName).emit('webrtc_offer', {
          callId,
          offer,
          userId: socket.userId, // Client expects 'userId', not 'fromUserId'
          fromUserId: socket.userId // Keep for backward compatibility
        });
        console.log(`✅ [SERVER] WebRTC offer sent to call room: ${roomName}`);
      }

      console.log(`✅ [SERVER] WebRTC offer sent for call ${callId} from ${socket.userId} to ${targetUserId || 'call room'}`);
      console.log('🔵 [SERVER] ===========================================\n');
    } catch (error) {
      console.error('❌ [SERVER] Error in webrtc_offer handler:', error);
      console.error('❌ [SERVER] Error stack:', error.stack);
      socket.emit('webrtc_error', { error: 'Failed to send WebRTC offer' });
    }
  });

  // WebRTC answer
  socket.on('webrtc_answer', (data) => {
    try {
      console.log('\n🔵 [SERVER] ========== WebRTC ANSWER RECEIVED ==========');
      console.log('🔵 [SERVER] From socket.userId:', socket.userId);
      console.log('🔵 [SERVER] Socket ID:', socket.id);
      console.log('🔵 [SERVER] Data received:', JSON.stringify(data, null, 2));
      
      const { callId, answer, targetUserId } = data;
      if (!callId || !answer) {
        console.warn('❌ [SERVER] webrtc_answer: missing callId or answer');
        console.warn('   callId:', callId);
        console.warn('   answer:', answer);
        return;
      }

      const roomName = `call:${callId}`;
      const targetRoom = targetUserId ? `user:${targetUserId}` : null;

      console.log('🔵 [SERVER] Room name:', roomName);
      console.log('🔵 [SERVER] Target room:', targetRoom);
      console.log('🔵 [SERVER] Target user ID:', targetUserId);

      // Check if answer contains SDP
      if (answer && answer.sdp) {
        const hasAudio = answer.sdp.includes('m=audio');
        const hasVideo = answer.sdp.includes('m=video');
        console.log('🔵 [SERVER] Answer SDP contains - Audio:', hasAudio, 'Video:', hasVideo);
        if (!hasAudio && !hasVideo) {
          console.warn('⚠️ [SERVER] WARNING: Answer SDP does not contain media!');
        }
      }

      // Check if target user is in the room
      if (targetRoom) {
        const socketsInRoom = io.sockets.adapter.rooms.get(targetRoom);
        console.log('🔵 [SERVER] Sockets in target room:', socketsInRoom ? Array.from(socketsInRoom).length : 0);
        if (socketsInRoom && socketsInRoom.size > 0) {
          console.log('🔵 [SERVER] Socket IDs in room:', Array.from(socketsInRoom));
        } else {
          console.warn('⚠️ [SERVER] WARNING: No sockets found in target room:', targetRoom);
        }
      }

      // Route to call room or target user
      if (targetRoom) {
        io.to(targetRoom).emit('webrtc_answer', {
          callId,
          answer,
          userId: socket.userId, // Client expects 'userId', not 'fromUserId'
          fromUserId: socket.userId // Keep for backward compatibility
        });
        console.log(`✅ [SERVER] WebRTC answer sent to target room: ${targetRoom}`);
      } else {
        // Broadcast to call room except sender
        socket.to(roomName).emit('webrtc_answer', {
          callId,
          answer,
          userId: socket.userId, // Client expects 'userId', not 'fromUserId'
          fromUserId: socket.userId // Keep for backward compatibility
        });
        console.log(`✅ [SERVER] WebRTC answer sent to call room: ${roomName}`);
      }

      console.log(`✅ [SERVER] WebRTC answer sent for call ${callId} from ${socket.userId} to ${targetUserId || 'call room'}`);
      console.log('🔵 [SERVER] ===========================================\n');
    } catch (error) {
      console.error('❌ [SERVER] Error in webrtc_answer handler:', error);
      console.error('❌ [SERVER] Error stack:', error.stack);
      socket.emit('webrtc_error', { error: 'Failed to send WebRTC answer' });
    }
  });

  // WebRTC ICE candidate
  socket.on('webrtc_ice_candidate', (data) => {
    try {
      const { callId, candidate, targetUserId } = data;
      if (!callId || !candidate) {
        console.warn('❌ [SERVER] webrtc_ice_candidate: missing callId or candidate');
        console.warn('   callId:', callId);
        console.warn('   candidate:', candidate);
        return;
      }

      // Parse candidate type from candidate string
      let candidateType = 'UNKNOWN';
      let candidateInfo = '';
      const candidateStr = typeof candidate === 'string' ? candidate : (candidate.candidate || JSON.stringify(candidate));
      
      if (candidateStr.includes('typ relay')) {
        candidateType = 'RELAY (TURN)';
        // Extract TURN server info if available
        const raddrMatch = candidateStr.match(/raddr\s+([^\s]+)/);
        const rportMatch = candidateStr.match(/rport\s+(\d+)/);
        if (raddrMatch && rportMatch) {
          const turnIp = raddrMatch[1];
          const turnPort = rportMatch[1];
          candidateInfo = `TURN: ${turnIp}:${turnPort}`;
          
          // Check if it's Twilio TURN
          if (turnIp.includes('twilio.com') || turnIp.includes('turn.twilio.com') || turnIp.includes('global.turn.twilio.com')) {
            candidateInfo += ' (CLOUD - Twilio ✅)';
          } else if (turnIp.includes('ngrok')) {
            candidateInfo += ' (NGROK - ⚠️ may not work for UDP)';
          } else if (turnIp.includes('10.120.4.230') || turnIp.includes('192.168.')) {
            candidateInfo += ' (LOCAL - same network only)';
          } else if (turnIp.includes('41.33.106.54')) {
            candidateInfo += ' (PUBLIC IP - requires router port forwarding)';
          }
        }
      } else if (candidateStr.includes('typ srflx')) {
        candidateType = 'SRFLX (STUN)';
      } else if (candidateStr.includes('typ host')) {
        candidateType = 'HOST (local)';
      }

      const roomName = `call:${callId}`;
      const targetRoom = targetUserId ? `user:${targetUserId}` : null;

      // Route to call room or target user
      if (targetRoom) {
        io.to(targetRoom).emit('webrtc_ice_candidate', {
          callId,
          candidate,
          userId: socket.userId, // Client expects 'userId', not 'fromUserId'
          fromUserId: socket.userId // Keep for backward compatibility
        });
      } else {
        // Broadcast to call room except sender
        socket.to(roomName).emit('webrtc_ice_candidate', {
          callId,
          candidate,
          userId: socket.userId, // Client expects 'userId', not 'fromUserId'
          fromUserId: socket.userId // Keep for backward compatibility
        });
      }

      if (candidateType === 'RELAY (TURN)') {
        console.log(`🔵 [SERVER] ✅✅✅ RELAY ICE candidate (TURN) for call ${callId} from ${socket.userId} to ${targetUserId || 'call room'}`);
        if (candidateInfo) {
          console.log(`   ${candidateInfo}`);
        }
      } else {
        console.log(`🔵 [SERVER] ${candidateType} ICE candidate for call ${callId} from ${socket.userId} to ${targetUserId || 'call room'}`);
      }
    } catch (error) {
      console.error('❌ [SERVER] Error in webrtc_ice_candidate handler:', error);
      console.error('❌ [SERVER] Error stack:', error.stack);
      socket.emit('webrtc_error', { error: 'Failed to send WebRTC ICE candidate' });
    }
  });

  socket.on('disconnect', async () => {
    console.log(`User disconnected: ${socket.userId}`);
    
    // Remove from active connections
    activeConnections.delete(socket.id);
    const userSocketSet = userSockets.get(socket.userId);
    if (userSocketSet) {
      userSocketSet.delete(socket.id);
      if (userSocketSet.size === 0) {
        userSockets.delete(socket.userId);
      }
    }

    // Cleanup any active calls for this user
    activeCalls.forEach((call, callId) => {
      if (call.participants.includes(socket.userId)) {
        cleanupCallState(callId, 'user_disconnected');
      }
    });
    
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
  
  // Start performance monitoring metric storage
  if (db) {
    performanceMonitor.startMetricStorage(db, 60000); // Store metrics every minute
    console.log('Performance monitoring initialized');
  }
  
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
