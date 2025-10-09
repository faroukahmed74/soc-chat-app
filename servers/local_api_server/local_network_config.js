// =============================================================================
// SOC Chat App - Local Network Server Configuration
// =============================================================================
// Configuration for running the API server on local network
// Uses the same MongoDB database as the main server

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { MongoClient } = require('mongodb');

// Load environment variables
require('dotenv').config();

// =============================================================================
// CONFIGURATION
// =============================================================================

const config = {
  // Server configuration
  port: process.env.LOCAL_NETWORK_PORT || 3004,
  host: process.env.LOCAL_NETWORK_HOST || '0.0.0.0',
  
  // Database configuration (same as main server)
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app',
  fallbackUri: 'mongodb://localhost:27017/soc_chat_app',
  dbName: 'soc_chat_app',
  
  // JWT configuration (same as main server)
  jwtSecret: process.env.JWT_SECRET || 'your_jwt_secret',
  
  // CORS configuration for local network
  corsOptions: {
    origin: [
      'http://localhost:3004',
      'http://localhost:8080',
      'http://localhost:8082',
      'http://127.0.0.1:3004',
      'http://127.0.0.1:8080',
      'http://127.0.0.1:8082',
      // Allow all local network IPs (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
      /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}:(3004|8080|8082)$/,
      /^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}:(3004|8080|8082)$/,
      /^http:\/\/172\.(1[6-9]|2[0-9]|3[01])\.\d{1,3}\.\d{1,3}:(3004|8080|8082)$/
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'ngrok-skip-browser-warning']
  },
  
  // Rate limiting
  rateLimitOptions: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 1000, // Higher limit for local network
    message: {
      error: 'Too many requests from this IP',
      message: 'Please try again later'
    }
  }
};

// =============================================================================
// DATABASE CONNECTION
// =============================================================================

let db;
let client;

async function connectToDatabase() {
  try {
    console.log('🔗 Connecting to MongoDB for local network server...');
    
    // Try primary connection first
    client = new MongoClient(config.mongoUri);
    await client.connect();
    db = client.db(config.dbName);
    
    console.log('✅ Connected to MongoDB successfully!');
    return db;
  } catch (error) {
    console.warn('⚠️ Primary connection failed, trying fallback...');
    
    try {
      // Try fallback connection
      client = new MongoClient(config.fallbackUri);
      await client.connect();
      db = client.db(config.dbName);
      
      console.log('✅ Connected to MongoDB (fallback) successfully!');
      return db;
    } catch (fallbackError) {
      console.error('❌ Failed to connect to MongoDB:', fallbackError.message);
      throw fallbackError;
    }
  }
}

// =============================================================================
// SERVER SETUP
// =============================================================================

async function createLocalNetworkServer() {
  const app = express();
  
  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'", "ws:", "wss:"]
      }
    }
  }));
  
  // CORS for local network
  app.use(cors(config.corsOptions));
  
  // Compression
  app.use(compression());
  
  // Rate limiting
  const limiter = rateLimit(config.rateLimitOptions);
  app.use(limiter);
  
  // Body parsing
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ extended: true, limit: '50mb' }));
  
  // Add ngrok-skip-browser-warning header
  app.use((req, res, next) => {
    res.setHeader('ngrok-skip-browser-warning', 'true');
    next();
  });
  
  // Health check endpoint
  app.get('/health', async (req, res) => {
    try {
      // Test database connection
      await db.admin().ping();
      
      res.json({
        status: 'healthy',
        server: 'local-network-server',
        port: config.port,
        host: config.host,
        database: 'connected',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      res.status(500).json({
        status: 'unhealthy',
        server: 'local-network-server',
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  });
  
  // Import and use the same routes as main server
  const authRoutes = require('./routes/auth');
  const chatRoutes = require('./routes/chats');
  const messageRoutes = require('./routes/messages');
  const mediaRoutes = require('./routes/media');
  const adminRoutes = require('./routes/admin');
  
  app.use('/api/auth', authRoutes);
  app.use('/api/chats', chatRoutes);
  app.use('/api/messages', messageRoutes);
  app.use('/api/media', mediaRoutes);
  app.use('/api/admin', adminRoutes);
  
  // Error handling
  app.use((err, req, res, next) => {
    console.error('Local Network Server Error:', err);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Something went wrong on the local network server'
    });
  });
  
  return app;
}

// =============================================================================
// START SERVER
// =============================================================================

async function startLocalNetworkServer() {
  try {
    // Connect to database
    await connectToDatabase();
    
    // Create server
    const app = await createLocalNetworkServer();
    
    // Start server
    const server = app.listen(config.port, config.host, () => {
      console.log('🚀 Local Network Server Started!');
      console.log(`📡 Server running on: http://${config.host}:${config.port}`);
      console.log(`🌐 Local access: http://localhost:${config.port}`);
      console.log(`🔗 Network access: http://[YOUR_IP]:${config.port}`);
      console.log(`💾 Database: ${config.dbName} (shared with main server)`);
      console.log('✅ Ready to accept connections from local network!');
    });
    
    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('🛑 Shutting down local network server...');
      server.close(() => {
        console.log('✅ Local network server stopped');
        if (client) {
          client.close();
        }
        process.exit(0);
      });
    });
    
  } catch (error) {
    console.error('❌ Failed to start local network server:', error);
    process.exit(1);
  }
}

// Start server if this file is run directly
if (require.main === module) {
  startLocalNetworkServer();
}

module.exports = { startLocalNetworkServer, config };


