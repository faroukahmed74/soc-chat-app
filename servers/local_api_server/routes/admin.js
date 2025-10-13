// =============================================================================
// SOC Chat App - Admin Routes
// =============================================================================
// This file provides admin-only API endpoints for database management
// Requires admin authentication

const express = require('express');
const router = express.Router();
const { ObjectId } = require('mongodb');
const jwt = require('jsonwebtoken');

// Middleware to verify admin token
const verifyAdminToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret_here');
    
    // Check if user is admin
    if (decoded.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    // Normalize decoded payload for downstream usage
    req.user = { ...decoded, userId: decoded.id };
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Get database statistics
router.get('/stats', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Get database stats
    const dbStats = await db.stats();
    
    // Get collection stats
    const usersCount = await db.collection('users').countDocuments();
    const chatsCount = await db.collection('chats').countDocuments();
    const messagesCount = await db.collection('messages').countDocuments();
    
    // Get recent activity
    const recentUsers = await db.collection('users')
      .find({})
      .sort({ createdAt: -1 })
      .limit(5)
      .toArray();
    
    const recentMessages = await db.collection('messages')
      .find({})
      .sort({ createdAt: -1 })
      .limit(10)
      .toArray();
    
    res.json({
      database: {
        name: dbStats.db,
        collections: dbStats.collections,
        documents: dbStats.objects,
        dataSize: dbStats.dataSize,
        storageSize: dbStats.storageSize,
        indexSize: dbStats.indexSize
      },
      collections: {
        users: usersCount,
        chats: chatsCount,
        messages: messagesCount
      },
      recentActivity: {
        users: recentUsers.map(user => ({
          id: user._id,
          name: user.displayName,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt
        })),
        messages: recentMessages.map(message => ({
          id: message._id,
          chatId: message.chatId,
          senderId: message.senderId,
          type: message.type,
          content: message.content?.substring(0, 100),
          createdAt: message.createdAt
        }))
      }
    });
  } catch (error) {
    console.error('Error getting database stats:', error);
    res.status(500).json({ error: 'Failed to get database statistics' });
  }
});

// Get all users
router.get('/users', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50, search = '' } = req.query;
    
    const skip = (page - 1) * limit;
    const query = {};
    
    if (search) {
      query.$or = [
        { email: { $regex: search, $options: 'i' } },
        { displayName: { $regex: search, $options: 'i' } }
      ];
    }
    
    const users = await db.collection('users')
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const totalUsers = await db.collection('users').countDocuments(query);
    
    res.json({
      users: users.map(user => ({
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        role: user.role,
        status: user.status,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        profilePicture: user.profilePicture
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalUsers,
        pages: Math.ceil(totalUsers / limit)
      }
    });
  } catch (error) {
    console.error('Error getting users:', error);
    res.status(500).json({ error: 'Failed to get users' });
  }
});

// Get all chats
router.get('/chats', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50 } = req.query;
    
    const skip = (page - 1) * limit;
    
    const chats = await db.collection('chats')
      .find({})
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const totalChats = await db.collection('chats').countDocuments();
    
  // Get member details for each chat
  const chatsWithMembers = await Promise.all(
    chats.map(async (chat) => {
        // Support legacy documents and ensure members array is valid ObjectIds
        const rawMembers = Array.isArray(chat.members)
          ? chat.members
          : Array.isArray(chat.memberIds)
            ? chat.memberIds
            : [];

        let memberObjectIds = [];
        try {
          // Convert string IDs to ObjectIds when needed, leave ObjectIds as-is
          const { ObjectId } = require('mongodb');
          memberObjectIds = rawMembers
            .filter((m) => m) // remove null/undefined
            .map((m) => (typeof m === 'string' && ObjectId.isValid(m) ? new ObjectId(m) : m))
            .filter((m) => m); // filter invalid entries
        } catch (e) {
          // Fallback to empty array if conversion fails
          memberObjectIds = [];
        }

        const members = memberObjectIds.length > 0
          ? await db.collection('users')
              .find({ _id: { $in: memberObjectIds } })
              .toArray()
          : [];
        
        return {
          id: chat._id,
          name: chat.name,
          type: chat.type || 'group',
          memberCount: rawMembers?.length || 0,
          members: members.map(member => ({
            id: member._id,
            name: member.displayName,
            email: member.email
          })),
          createdAt: chat.createdAt,
          updatedAt: chat.updatedAt
        };
      })
    );
    
    res.json({
      chats: chatsWithMembers,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalChats,
        pages: Math.ceil(totalChats / limit)
      }
    });
  } catch (error) {
    console.error('Error getting chats:', error);
    res.status(500).json({ error: 'Failed to get chats' });
  }
});

// Get messages
router.get('/messages', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 100, chatId } = req.query;
    
    const skip = (page - 1) * limit;
    const query = {};
    
    if (chatId) {
      query.chatId = new ObjectId(chatId);
    }
    
    const messages = await db.collection('messages')
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const totalMessages = await db.collection('messages').countDocuments(query);
    
    res.json({
      messages: messages.map(message => ({
        id: message._id,
        chatId: message.chatId,
        senderId: message.senderId,
        type: message.type,
        content: message.content,
        mediaUrl: message.mediaUrl,
        createdAt: message.createdAt,
        updatedAt: message.updatedAt
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalMessages,
        pages: Math.ceil(totalMessages / limit)
      }
    });
  } catch (error) {
    console.error('Error getting messages:', error);
    res.status(500).json({ error: 'Failed to get messages' });
  }
});

// Create admin user
router.post('/users/admin', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { email, password, displayName } = req.body;
    
    if (!email || !password || !displayName) {
      return res.status(400).json({ error: 'Email, password, and display name are required' });
    }
    
    // Check if user already exists
    const existingUser = await db.collection('users').findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }
    
    // Hash password
    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Create admin user
    const adminUser = {
      email,
      password: hashedPassword,
      displayName,
      role: 'admin',
      status: 'active',
      createdAt: new Date(),
      lastLoginAt: null
    };
    
    const result = await db.collection('users').insertOne(adminUser);
    
    res.json({
      message: 'Admin user created successfully',
      user: {
        id: result.insertedId,
        email,
        displayName,
        role: 'admin'
      }
    });
  } catch (error) {
    console.error('Error creating admin user:', error);
    res.status(500).json({ error: 'Failed to create admin user' });
  }
});

// Update user role
router.put('/users/:id/role', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { role } = req.body;
    
    if (!role || !['user', 'admin'].includes(role)) {
      return res.status(400).json({ error: 'Valid role is required' });
    }
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { $set: { role, updatedAt: new Date() } }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'User role updated successfully' });
  } catch (error) {
    console.error('Error updating user role:', error);
    res.status(500).json({ error: 'Failed to update user role' });
  }
});

// Delete user
router.delete('/users/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    // Don't allow deleting the current admin
    if (id === req.user.userId) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }
    
    const result = await db.collection('users').deleteOne({ _id: new ObjectId(id) });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// Get system health
router.get('/health', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Database health
    await db.admin().ping();
    
    // Collection health
    const collections = await db.listCollections().toArray();
    const expectedCollections = ['users', 'chats', 'messages'];
    const existingCollections = collections.map(c => c.name);
    
    const collectionHealth = expectedCollections.map(collection => ({
      name: collection,
      exists: existingCollections.includes(collection),
      documentCount: 0
    }));
    
    // Get document counts
    for (const collection of collectionHealth) {
      if (collection.exists) {
        collection.documentCount = await db.collection(collection.name).countDocuments();
      }
    }
    
    // Index health
    const indexHealth = {};
    for (const collection of expectedCollections) {
      if (existingCollections.includes(collection)) {
        const indexes = await db.collection(collection).indexes();
        indexHealth[collection] = {
          count: indexes.length,
          indexes: indexes.map(idx => ({
            name: idx.name,
            keys: idx.key
          }))
        };
      }
    }
    
    res.json({
      status: 'healthy',
      database: {
        connected: true,
        name: db.databaseName
      },
      collections: collectionHealth,
      indexes: indexHealth,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error checking system health:', error);
    res.status(500).json({ 
      status: 'unhealthy',
      error: 'Failed to check system health',
      timestamp: new Date().toISOString()
    });
  }
});

// Broadcast message to all users
router.post('/broadcast', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { message, type = 'text' } = req.body;
    
    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }
    
    // Get all active users
    const users = await db.collection('users')
      .find({ status: 'active' })
      .toArray();
    
    // Create broadcast message for each user
    const broadcastMessages = users.map(user => ({
      type: 'broadcast',
      content: message,
      senderId: req.user.userId,
      recipientId: user._id,
      createdAt: new Date(),
      read: false
    }));
    
    if (broadcastMessages.length > 0) {
      await db.collection('messages').insertMany(broadcastMessages);
    }
    
    res.json({
      message: 'Broadcast sent successfully',
      recipients: users.length
    });
  } catch (error) {
    console.error('Error sending broadcast:', error);
    res.status(500).json({ error: 'Failed to send broadcast' });
  }
});

module.exports = router;
