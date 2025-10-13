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

// Initialize Express app
const app = express();
const server = http.createServer(app);
// CORS allowed origins (comma-separated). Example: https://api.example.com,http://localhost:8080
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:8080,http://localhost:8082,http://192.168.0.117:8080,http://192.168.0.117:8082,http://10.120.4.230:8080,http://10.120.4.230:8082')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

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
    
    // Allow local network IPs on common ports
    if (origin.match(/^http:\/\/192\.168\.\d{1,3}\.\d{1,3}:(8080|8082|3000|3001|3002|3003|3004)$/)) {
      return callback(null, true);
    }
    
    if (origin.match(/^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}:(8080|8082|3000|3001|3002|3003|3004)$/)) {
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

// JSON parsing
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

// Basic rate limiting - more lenient for development
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Increased limit for development
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many requests from this IP',
    message: 'Please try again later'
  }
});
app.use(limiter);

// More lenient rate limiting for user search endpoints
const userSearchLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 50, // 50 requests per minute for user search
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many user search requests',
    message: 'Please wait a moment before searching again'
  }
});

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
const mongoURI = process.env.MONGO_URI || 'mongodb://admin:SecurePassword123!@localhost:27017/soc_chat_app?authSource=admin';
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
    
    // Test the connection
    await db.admin().ping();
    console.log('✅ MongoDB ping successful');
    
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
  
  if (!token) return res.status(401).json({ error: 'Access denied' });
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token' });
    req.user = user;
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

// Legacy User Authentication - keeping for backward compatibility
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;
    
    // Check if user exists
    const existingUser = await db.collection('users').findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }
    
    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    
    // Create user
    const user = {
      email,
      password: hashedPassword,
      displayName,
      role: 'user',
      createdAt: new Date(),
      status: 'online'
    };
    
    const result = await db.collection('users').insertOne(user);
    
    // Generate token
    const token = jwt.sign(
      { id: result.insertedId, email, displayName, role: 'user' },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    res.status(201).json({
      token,
      user: {
        id: result.insertedId,
        email,
        displayName,
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
    
    // Update status
    await db.collection('users').updateOne(
      { _id: user._id },
      { $set: { status: 'online' } }
    );
    
    // Generate token
    const token = jwt.sign(
      { id: user._id, email: user.email, displayName: user.displayName, role: user.role || 'user' },
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

// =========================================
// Media Upload Route
// =========================================
app.post('/api/media/upload', authenticateToken, (req, res) => {
  // Expect fields: chatId, type (image|video|audio|document), optional caption
  upload.single('file')(req, res, (err) => {
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

    // Build public URL to the uploaded file
    const relativePath = path.join('chat_media', chatId, req.file.filename).replace(/\\/g, '/');
    const computedHost = req.get('host');
    const baseUrl = process.env.PUBLIC_BASE_URL || `${req.protocol}://${computedHost}`;
    const mediaUrl = `${baseUrl}/uploads/${relativePath}`;

    return res.status(201).json({
      mediaUrl,
      type,
      caption,
      fileName: req.file.filename,
      size: req.file.size,
      mimeType: req.file.mimetype,
    });
  });
});

// User Routes
// Get all users (for user search functionality)
app.get('/api/users', userSearchLimiter, authenticateToken, async (req, res) => {
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
      status: user.status || 'offline',
      role: user.role || 'user',
      createdAt: user.createdAt,
      profilePicture: user.profilePicture
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
    
    res.json(user);
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

// Chat Routes
app.get('/api/chats', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const chats = await db.collection('chats')
      .find({ memberIds: userId })
      .toArray();
    
    res.json(chats);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/chats', authenticateToken, async (req, res) => {
  try {
    const { type, name, memberIds } = req.body;
    
    const chat = {
      type,
      name,
      memberIds,
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await db.collection('chats').insertOne(chat);
    
    res.status(201).json({
      id: result.insertedId,
      ...chat
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.put('/api/chats/:chatId/members', authenticateToken, async (req, res) => {
  try {
    const { userId, action } = req.body;
    
    if (action === 'add') {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(req.params.chatId) },
        { $addToSet: { memberIds: userId } }
      );
    } else if (action === 'remove') {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(req.params.chatId) },
        { $pull: { memberIds: userId } }
      );
    }
    
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Message Routes
app.get('/api/chats/:chatId/messages', authenticateToken, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    
    const messages = await db.collection('messages')
      .find({ chatId: req.params.chatId })
      .sort({ createdAt: -1 })
      .skip(offset)
      .limit(limit)
      .toArray();
    
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
    
    const message = {
      chatId: req.params.chatId,
      senderId: userId,
      content,
      messageType: messageType || 'text',
      mediaUrl,
      createdAt: new Date()
    };
    
    const result = await db.collection('messages').insertOne(message);
    
    // Update chat's updatedAt
    await db.collection('chats').updateOne(
      { _id: new ObjectId(req.params.chatId) },
      { $set: { updatedAt: new Date() } }
    );
    
    // Emit to socket
    io.to(req.params.chatId).emit('new_message', {
      id: result.insertedId,
      ...message
    });
    
    res.status(201).json({
      id: result.insertedId,
      ...message
    });
  } catch (err) {
    console.error(err);
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
      memberIds: userId,
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

// Socket.IO
io.on('connection', (socket) => {
  console.log('New client connected');
  
  socket.on('join_chat', (chatId) => {
    socket.join(chatId);
    console.log(`Client joined chat: ${chatId}`);
  });
  
  socket.on('leave_chat', (chatId) => {
    socket.leave(chatId);
    console.log(`Client left chat: ${chatId}`);
  });
  
  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
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