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

// JSON parsing
app.use(express.json({ limit: '2mb' }));
app.use(morgan('dev'));

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
    const { displayName, email, phone, password } = req.body;
    
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
      email: email.trim(),
      phone: phone?.trim() || '',
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
    
    // Always use ngrok URL for media files to ensure cross-platform access
    // This ensures media sent from web can be viewed on mobile and vice versa
    const baseUrl = process.env.MOBILE_BASE_URL || 'https://soc-chat-app.ngrok-free.app';
    const mediaUrl = `${baseUrl}/uploads/${relativePath}`;
    
    console.log('Media URL generated (always using public URL):', {
      baseUrl,
      relativePath,
      mediaUrl
    });
    
    console.log('Media upload successful:', {
      fileName: req.file.filename,
      chatId,
      type,
      mediaUrl,
      fileSize: req.file.size
    });

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

// Create a new chat
app.post('/api/chats', authenticateToken, async (req, res) => {
  try {
    const { type, name, members } = req.body;
    
    if (!name || !members || !Array.isArray(members)) {
      return res.status(400).json({ error: 'Chat name and members array are required' });
    }
    
    // For private chats, check if chat already exists between the two users
    if (type === 'private' && members.length === 2) {
      const existingChat = await db.collection('chats').findOne({
        type: 'private',
        members: { 
          $all: [new ObjectId(members[0]), new ObjectId(members[1])],
          $size: 2
        }
      });
      
      if (existingChat) {
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
      }
    }
    
    // Create new chat
    const chat = {
      type: type || 'group',
      name,
      members: members.map(id => new ObjectId(id)),
      createdBy: new ObjectId(req.user.id),
      createdAt: new Date(),
      updatedAt: new Date(),
      lastMessage: null,
      lastMessageTime: null
    };
    
    const result = await db.collection('chats').insertOne(chat);
    const createdChat = await db.collection('chats').findOne({ _id: result.insertedId });
    
    res.status(201).json({
      _id: createdChat._id.toString(),
      id: createdChat._id.toString(),
      name: createdChat.name,
      type: createdChat.type,
      members: createdChat.members.map(id => id.toString()),
      createdBy: createdChat.createdBy.toString(),
      createdAt: createdChat.createdAt,
      updatedAt: createdChat.updatedAt,
      lastMessage: createdChat.lastMessage,
      lastMessageTime: createdChat.lastMessageTime
    });
  } catch (err) {
    console.error('Create chat error:', err);
    res.status(500).json({ error: 'Server error' });
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
    
    if (action === 'add') {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(req.params.chatId) },
        { $addToSet: { members: new ObjectId(userId) } }
      );
    } else if (action === 'remove') {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(req.params.chatId) },
        { $pull: { members: new ObjectId(userId) } }
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
    const chatId = req.params.chatId;
    
    // Verify user is a member of the chat using `members`
    const chat = await db.collection('chats').findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(req.user.id),
    });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found or access denied' });
    }
    
    const messages = await db.collection('messages')
      .find({ chatId })
      .sort({ createdAt: 1 })
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
      createdAt: new Date()
    };
    
    const result = await db.collection('messages').insertOne(message);
    
    // Update chat's updatedAt
    await db.collection('chats').updateOne(
      { _id: new ObjectId(chatId) },
      { 
        $set: { 
          updatedAt: new Date(),
          lastMessage: {
            content,
            senderId: new ObjectId(userId),
            createdAt: new Date(),
          },
        }
      }
    );
    
    // Get other chat members (not the sender)
    const otherMembers = chat.members
      .filter(m => m.toString() !== userId.toString())
      .map(m => m.toString());
    
    // Emit to socket for all chat members
    io.to(chatId).emit('new_message', {
      id: result.insertedId,
      senderName: senderName,
      ...message
    });
    
    // Send notifications to other chat members
    for (const memberId of otherMembers) {
      const title = chat.isGroupChat ? chat.name : senderName;
      const body = messageType === 'text' ? content : messageType === 'image' ? '📷 Image' : '📎 ' + messageType;
      
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
    }
    
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

// Socket.IO authentication middleware
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  
  if (!token) {
    return next(new Error('Authentication error: Token required'));
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    // Handle both uid and id for compatibility
    socket.userId = decoded.uid || decoded.id;
    socket.user = decoded;
    
    console.log(`Socket authenticated for user: ${socket.userId}`);
    
    // Update user's online status
    if (db) {
      await db.collection('users').updateOne(
        { _id: new ObjectId(decoded.uid) },
        { $set: { isOnline: true, lastSeen: new Date() } }
      );
    }
    
    next();
  } catch (error) {
    return next(new Error('Authentication error: Invalid token'));
  }
});

// Socket.IO
io.on('connection', async (socket) => {
  console.log(`User connected: ${socket.userId}`);
  
  // Join user to their personal room
  socket.join(socket.userId);
  
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
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    
    // Send test notification to the user
    io.to(decoded.uid).emit('notification', {
      title: 'Test Notification',
      body: 'This is a test notification from the server',
      data: { type: 'test', timestamp: new Date() },
      timestamp: new Date(),
      senderId: decoded.uid
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
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    
    if (!userId || !title || !body) {
      return res.status(400).json({ error: 'userId, title, and body are required' });
    }
    
    // Send notification to user via socket
    io.to(userId).emit('notification', {
      title,
      body,
      data: data || {},
      timestamp: new Date(),
      senderId: decoded.uid
    });
    
    // Store notification in database
    if (db) {
      await db.collection('notifications').insertOne({
        userId,
        title,
        body,
        data: data || {},
        timestamp: new Date(),
        senderId: decoded.uid,
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
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    
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
      senderId: decoded.uid
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
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    
    if (!db) {
      return res.status(500).json({ error: 'Database connection not available' });
    }
    
    // Get user's notifications
    const notifications = await db.collection('notifications')
      .find({ userId: decoded.uid })
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
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production');
    
    if (!db) {
      return res.status(500).json({ error: 'Database connection not available' });
    }
    
    // Mark notification as read
    const result = await db.collection('notifications').updateOne(
      { _id: new ObjectId(id), userId: decoded.uid },
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