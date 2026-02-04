// Local Notification Server
// Replaces Firebase Cloud Messaging for the SOC Chat App

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { MongoClient, ObjectId } = require('mongodb');

// Environment variables
const PORT = process.env.NOTIFICATION_PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'your_secure_jwt_secret_key_change_this_in_production';
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';

// Allow graceful MongoDB connection failure (for development)
const ALLOW_MONGO_FAILURE = process.env.ALLOW_MONGO_FAILURE === 'true';

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB connection
let db;
async function connectToMongo() {
  try {
    const client = new MongoClient(MONGO_URI);
    await client.connect();
    db = client.db();
    console.log('Connected to MongoDB');
  } catch (error) {
    console.error('MongoDB connection error:', error);
    if (ALLOW_MONGO_FAILURE) {
      console.warn('Continuing without MongoDB connection (ALLOW_MONGO_FAILURE=true)');
      db = null;
    } else {
      console.error('MongoDB connection failed. Set ALLOW_MONGO_FAILURE=true to continue without DB.');
      process.exit(1);
    }
  }
}

// Socket.io authentication middleware
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  
  if (!token) {
    return next(new Error('Authentication error: Token required'));
  }
  
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    socket.userId = decoded.uid;
    socket.user = decoded;
    
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

// Socket.io connection handler
io.on('connection', async (socket) => {
  console.log(`User connected: ${socket.userId}`);
  
  // Join user to their personal room
  socket.join(socket.userId);
  
  // Join user to all their chat rooms
  if (db) {
    try {
      const chats = await db.collection('chats').find({
        members: socket.userId
      }).toArray();
      
      chats.forEach(chat => {
        socket.join(`chat:${chat._id}`);
      });
      
      console.log(`User ${socket.userId} joined ${chats.length} chat rooms`);
    } catch (error) {
      console.error('Error joining chat rooms:', error);
    }
  }
  
  // Handle disconnect
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

// API Routes

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'notification-server' });
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
    
    // Send notification to user
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
    const decoded = jwt.verify(token, JWT_SECRET);
    
    if (!chatId || !title || !body) {
      return res.status(400).json({ error: 'chatId, title, and body are required' });
    }
    
    // Send notification to chat room
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
    const decoded = jwt.verify(token, JWT_SECRET);
    
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
    const decoded = jwt.verify(token, JWT_SECRET);
    
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
async function startServer() {
  await connectToMongo();
  
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Notification server running on port ${PORT}`);
    console.log(`Server accessible at http://localhost:${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
  });
}

startServer().catch(console.error);

module.exports = { app, server, io };