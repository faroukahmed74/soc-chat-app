// =============================================================================
// SOC Chat App - Admin Routes
// =============================================================================
// This file provides admin-only API endpoints for database management
// Requires admin authentication

const express = require('express');
const router = express.Router();
const { ObjectId } = require('mongodb');
const jwt = require('jsonwebtoken');

// Middleware to inject Socket.IO into requests
const injectIO = (req, res, next) => {
  const io = req.app.get('io');
  req.io = io;
  next();
};

// Apply Socket.IO to all routes
router.use(injectIO);

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
    
    // Get collection stats
    const usersCount = await db.collection('users').countDocuments();
    const chatsCount = await db.collection('chats').countDocuments();
    const messagesCount = await db.collection('messages').countDocuments();
    
    // Get active users (users who logged in within last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const activeUsersCount = await db.collection('users').countDocuments({
      lastLoginAt: { $gte: sevenDaysAgo }
    });
    
    // Get active chats (chats with messages in last 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const activeChatsCount = await db.collection('chats').countDocuments({
      updatedAt: { $gte: oneDayAgo }
    });
    
    // Get messages today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const messagesTodayCount = await db.collection('messages').countDocuments({
      createdAt: { $gte: today }
    });
    
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
      totalUsers: usersCount,
      totalChats: chatsCount,
      totalMessages: messagesCount,
      activeUsers: activeUsersCount,
      activeChats: activeChatsCount,
      messagesToday: messagesTodayCount,
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
    
    // Get sender names for messages
    const messagesWithSenders = await Promise.all(
      messages.map(async (message) => {
        let senderName = 'Unknown';
        let content = message.content || '';
        
        // Try to get sender name
        if (message.senderId) {
          try {
            const sender = await db.collection('users').findOne({ _id: message.senderId });
            if (sender) {
              senderName = sender.displayName || sender.email || 'Unknown';
            }
          } catch (e) {
            console.error('Error getting sender name:', e);
          }
        }
        
        // Handle media messages
        if (message.mediaUrl && !content) {
          content = `[${message.type || 'media'}]`;
        }
        
        return {
          id: message._id,
          chatId: message.chatId,
          senderId: message.senderId,
          senderName: senderName,
          type: message.type,
          content: content,
          mediaUrl: message.mediaUrl,
          createdAt: message.createdAt,
          updatedAt: message.updatedAt
        };
      })
    );
    
    res.json({
      messages: messagesWithSenders,
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
    const io = req.io; // Get Socket.IO from middleware
    const { message, type = 'text' } = req.body;
    
    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }
    
    // Get all users (not just active)
    const users = await db.collection('users').find({}).toArray();
    
    // Get admin's display name
    const adminUser = await db.collection('users').findOne({ _id: new ObjectId(req.user.userId) });
    const senderName = adminUser?.displayName || adminUser?.email || 'Admin';
    
    // Create broadcast messages for storage
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
    
    // 🔥 EMIT REAL-TIME NOTIFICATIONS TO ALL USERS
    for (const user of users) {
      const userId = user._id.toString();
      
      // Emit notification event
      io.to(userId).emit('notification', {
        title: '📢 Broadcast Message',
        body: message.length > 50 ? message.substring(0, 50) + '...' : message,
        data: {
          type: 'broadcast',
          senderId: req.user.userId,
          senderName: senderName,
          message: message,
          timestamp: new Date(),
        },
        timestamp: new Date(),
      });
      
      // Also send broadcast_notification event
      io.to(userId).emit('broadcast_notification', {
        title: '📢 Broadcast',
        body: message,
        chatId: null,
        senderId: req.user.userId,
        senderName: senderName,
        messageType: type || 'text',
        timestamp: new Date(),
      });
    }
    
    console.log(`📢 Broadcast sent to ${users.length} users via Socket.IO`);
    
    res.json({
      message: 'Broadcast sent successfully',
      recipients: users.length
    });
  } catch (error) {
    console.error('Error sending broadcast:', error);
    res.status(500).json({ error: 'Failed to send broadcast' });
  }
});

// Clear all chats and all messages (admin only)
router.post('/chats/clear', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;

    // Delete all messages first to avoid orphaned data
    const messagesResult = await db.collection('messages').deleteMany({});

    // Delete all chats
    const chatsResult = await db.collection('chats').deleteMany({});

    res.json({
      message: 'All chats and messages cleared',
      deleted: {
        chats: chatsResult?.deletedCount || 0,
        messages: messagesResult?.deletedCount || 0,
      },
    });
  } catch (error) {
    console.error('Error clearing all chats:', error);
    res.status(500).json({ error: 'Failed to clear chats and messages' });
  }
});

// Delete a single chat by ID (admin only)
router.delete('/chats/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;

    if (!ObjectId.isValid(id)) {
      return res.status(400).json({ error: 'Invalid chat ID' });
    }

    const chatObjectId = new ObjectId(id);

    // Delete messages for this chat
    const messagesResult = await db.collection('messages').deleteMany({ chatId: chatObjectId });

    // Delete the chat document
    const chatResult = await db.collection('chats').deleteOne({ _id: chatObjectId });

    if (chatResult.deletedCount === 0) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    res.json({
      message: 'Chat deleted successfully',
      deleted: {
        chat: chatResult.deletedCount,
        messages: messagesResult?.deletedCount || 0,
      },
    });
  } catch (error) {
    console.error('Error deleting chat:', error);
    res.status(500).json({ error: 'Failed to delete chat' });
  }
});

// Get all reports
router.get('/reports', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Check if reports collection exists, if not return empty array
    const collections = await db.listCollections().toArray();
    const reportsCollectionExists = collections.some(c => c.name === 'reports');
    
    if (!reportsCollectionExists) {
      return res.json([]);
    }
    
    const reports = await db.collection('reports')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json(reports.map(report => ({
      id: report._id,
      type: report.type || 'general',
      description: report.description || '',
      reporterId: report.reporterId,
      reporterName: report.reporterName || 'Unknown',
      reportedUserId: report.reportedUserId,
      reportedUserName: report.reportedUserName || 'Unknown',
      chatId: report.chatId,
      messageId: report.messageId,
      status: report.status || 'pending',
      createdAt: report.createdAt,
      resolvedAt: report.resolvedAt,
      resolvedBy: report.resolvedBy
    })));
  } catch (error) {
    console.error('Error getting reports:', error);
    res.status(500).json({ error: 'Failed to get reports' });
  }
});

// Get analytics data
router.get('/analytics', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Get user analytics
    const totalUsers = await db.collection('users').countDocuments();
    const activeUsers = await db.collection('users').countDocuments({ 
      lastLoginAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } 
    });
    const newUsersToday = await db.collection('users').countDocuments({
      createdAt: { $gte: new Date(new Date().setHours(0, 0, 0, 0)) }
    });
    
    // Get chat analytics
    const totalChats = await db.collection('chats').countDocuments();
    const groupChats = await db.collection('chats').countDocuments({ type: 'group' });
    const privateChats = await db.collection('chats').countDocuments({ type: 'private' });
    
    // Get message analytics
    const totalMessages = await db.collection('messages').countDocuments();
    const messagesToday = await db.collection('messages').countDocuments({
      createdAt: { $gte: new Date(new Date().setHours(0, 0, 0, 0)) }
    });
    
    // Get message types
    const messageTypes = await db.collection('messages').aggregate([
      { $group: { _id: '$type', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]).toArray();
    
    // Get user activity by day (last 7 days)
    const userActivity = await db.collection('users').aggregate([
      {
        $match: {
          lastLoginAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$lastLoginAt' }
          },
          count: { $sum: 1 }
        }
      },
      { $sort: { _id: 1 } }
    ]).toArray();
    
    res.json({
      users: {
        total: totalUsers,
        active: activeUsers,
        newToday: newUsersToday,
        activityByDay: userActivity
      },
      chats: {
        total: totalChats,
        group: groupChats,
        private: privateChats
      },
      messages: {
        total: totalMessages,
        today: messagesToday,
        types: messageTypes
      },
      generatedAt: new Date()
    });
  } catch (error) {
    console.error('Error getting analytics:', error);
    res.status(500).json({ error: 'Failed to get analytics' });
  }
});

// =============================================================================
// COMPREHENSIVE CRUD OPERATIONS FOR ALL COLLECTIONS
// =============================================================================

// ===== USERS CRUD =====

// Update user
router.put('/users/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { email, displayName, role, status, profilePicture } = req.body;
    
    const updateData = {};
    if (email) updateData.email = email;
    if (displayName) updateData.displayName = displayName;
    if (role) updateData.role = role;
    if (status) updateData.status = status;
    if (profilePicture) updateData.profilePicture = profilePicture;
    updateData.updatedAt = new Date();
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'User updated successfully' });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// Get single user
router.get('/users/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(id) });
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({
      id: user._id,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      status: user.status,
      createdAt: user.createdAt,
      lastLoginAt: user.lastLoginAt,
      profilePicture: user.profilePicture
    });
  } catch (error) {
    console.error('Error getting user:', error);
    res.status(500).json({ error: 'Failed to get user' });
  }
});

// ===== CHATS CRUD =====

// Get single chat
router.get('/chats/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    // Get member details
    const memberObjectIds = (chat.members || chat.memberIds || [])
      .filter(m => m)
      .map(m => typeof m === 'string' && ObjectId.isValid(m) ? new ObjectId(m) : m)
      .filter(m => m);
    
    const members = memberObjectIds.length > 0
      ? await db.collection('users')
          .find({ _id: { $in: memberObjectIds } })
          .toArray()
      : [];
    
    res.json({
      id: chat._id,
      name: chat.name,
      type: chat.type || 'group',
      members: members.map(member => ({
        id: member._id,
        name: member.displayName,
        email: member.email
      })),
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt
    });
  } catch (error) {
    console.error('Error getting chat:', error);
    res.status(500).json({ error: 'Failed to get chat' });
  }
});

// Update chat
router.put('/chats/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, type, members } = req.body;
    
    const updateData = {};
    if (name) updateData.name = name;
    if (type) updateData.type = type;
    if (members) updateData.members = members;
    updateData.updatedAt = new Date();
    
    const result = await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    res.json({ message: 'Chat updated successfully' });
  } catch (error) {
    console.error('Error updating chat:', error);
    res.status(500).json({ error: 'Failed to update chat' });
  }
});

// Create chat
router.post('/chats', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, type = 'group', members = [] } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Chat name is required' });
    }
    
    const chat = {
      name,
      type,
      members: members.map(m => typeof m === 'string' && ObjectId.isValid(m) ? new ObjectId(m) : m),
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await db.collection('chats').insertOne(chat);
    
    res.json({
      message: 'Chat created successfully',
      chat: {
        id: result.insertedId,
        name,
        type,
        members: chat.members
      }
    });
  } catch (error) {
    console.error('Error creating chat:', error);
    res.status(500).json({ error: 'Failed to create chat' });
  }
});

// ===== MESSAGES CRUD =====

// Get single message
router.get('/messages/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const message = await db.collection('messages').findOne({ _id: new ObjectId(id) });
    
    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    // Get sender name
    let senderName = 'Unknown';
    if (message.senderId) {
      try {
        const sender = await db.collection('users').findOne({ _id: message.senderId });
        if (sender) {
          senderName = sender.displayName || sender.email || 'Unknown';
        }
      } catch (e) {
        console.error('Error getting sender name:', e);
      }
    }
    
    res.json({
      id: message._id,
      chatId: message.chatId,
      senderId: message.senderId,
      senderName: senderName,
      type: message.type,
      content: message.content,
      mediaUrl: message.mediaUrl,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt
    });
  } catch (error) {
    console.error('Error getting message:', error);
    res.status(500).json({ error: 'Failed to get message' });
  }
});

// Update message
router.put('/messages/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { content, type, mediaUrl } = req.body;
    
    const updateData = {};
    if (content !== undefined) updateData.content = content;
    if (type !== undefined) updateData.type = type;
    if (mediaUrl !== undefined) updateData.mediaUrl = mediaUrl;
    updateData.updatedAt = new Date();
    
    const result = await db.collection('messages').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    res.json({ message: 'Message updated successfully' });
  } catch (error) {
    console.error('Error updating message:', error);
    res.status(500).json({ error: 'Failed to update message' });
  }
});

// Delete message
router.delete('/messages/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const result = await db.collection('messages').deleteOne({ _id: new ObjectId(id) });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    res.json({ message: 'Message deleted successfully' });
  } catch (error) {
    console.error('Error deleting message:', error);
    res.status(500).json({ error: 'Failed to delete message' });
  }
});

// Create message
router.post('/messages', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { chatId, senderId, content, type = 'text', mediaUrl } = req.body;
    
    if (!chatId || !senderId || !content) {
      return res.status(400).json({ error: 'chatId, senderId, and content are required' });
    }
    
    const message = {
      chatId: new ObjectId(chatId),
      senderId: new ObjectId(senderId),
      content,
      type,
      mediaUrl: mediaUrl || null,
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await db.collection('messages').insertOne(message);
    
    res.json({
      message: 'Message created successfully',
      messageId: result.insertedId
    });
  } catch (error) {
    console.error('Error creating message:', error);
    res.status(500).json({ error: 'Failed to create message' });
  }
});

// ===== REPORTS CRUD =====

// Get single report
router.get('/reports/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const report = await db.collection('reports').findOne({ _id: new ObjectId(id) });
    
    if (!report) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    res.json({
      id: report._id,
      type: report.type || 'general',
      description: report.description || '',
      reporterId: report.reporterId,
      reporterName: report.reporterName || 'Unknown',
      reportedUserId: report.reportedUserId,
      reportedUserName: report.reportedUserName || 'Unknown',
      chatId: report.chatId,
      messageId: report.messageId,
      status: report.status || 'pending',
      createdAt: report.createdAt,
      resolvedAt: report.resolvedAt,
      resolvedBy: report.resolvedBy
    });
  } catch (error) {
    console.error('Error getting report:', error);
    res.status(500).json({ error: 'Failed to get report' });
  }
});

// Update report
router.put('/reports/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { status, resolvedBy, description } = req.body;
    
    const updateData = {};
    if (status) updateData.status = status;
    if (resolvedBy) updateData.resolvedBy = resolvedBy;
    if (description) updateData.description = description;
    
    if (status === 'resolved') {
      updateData.resolvedAt = new Date();
    }
    
    const result = await db.collection('reports').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    res.json({ message: 'Report updated successfully' });
  } catch (error) {
    console.error('Error updating report:', error);
    res.status(500).json({ error: 'Failed to update report' });
  }
});

// Delete report
router.delete('/reports/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const result = await db.collection('reports').deleteOne({ _id: new ObjectId(id) });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    res.json({ message: 'Report deleted successfully' });
  } catch (error) {
    console.error('Error deleting report:', error);
    res.status(500).json({ error: 'Failed to delete report' });
  }
});

// ===== BULK OPERATIONS =====

// Bulk delete users
router.post('/users/bulk-delete', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userIds } = req.body;
    
    if (!userIds || !Array.isArray(userIds)) {
      return res.status(400).json({ error: 'userIds array is required' });
    }
    
    const objectIds = userIds.map(id => new ObjectId(id));
    const result = await db.collection('users').deleteMany({ _id: { $in: objectIds } });
    
    res.json({
      message: 'Users deleted successfully',
      deletedCount: result.deletedCount
    });
  } catch (error) {
    console.error('Error bulk deleting users:', error);
    res.status(500).json({ error: 'Failed to delete users' });
  }
});

// Bulk delete messages
router.post('/messages/bulk-delete', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { messageIds } = req.body;
    
    if (!messageIds || !Array.isArray(messageIds)) {
      return res.status(400).json({ error: 'messageIds array is required' });
    }
    
    const objectIds = messageIds.map(id => new ObjectId(id));
    const result = await db.collection('messages').deleteMany({ _id: { $in: objectIds } });
    
    res.json({
      message: 'Messages deleted successfully',
      deletedCount: result.deletedCount
    });
  } catch (error) {
    console.error('Error bulk deleting messages:', error);
    res.status(500).json({ error: 'Failed to delete messages' });
  }
});

// ===== USER MANAGEMENT =====

// Lock user
router.post('/users/:id/lock', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { reason } = req.body;
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { 
        $set: { 
          isLocked: true,
          lockedReason: reason || 'No reason provided',
          lockedAt: new Date(),
          updatedAt: new Date()
        } 
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'User locked successfully' });
  } catch (error) {
    console.error('Error locking user:', error);
    res.status(500).json({ error: 'Failed to lock user' });
  }
});

// Unlock user
router.post('/users/:id/unlock', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { 
        $set: { 
          isLocked: false,
          lockedReason: null,
          lockedAt: null,
          updatedAt: new Date()
        } 
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'User unlocked successfully' });
  } catch (error) {
    console.error('Error unlocking user:', error);
    res.status(500).json({ error: 'Failed to unlock user' });
  }
});

// Add new user
router.post('/users', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { email, password, displayName, role = 'user' } = req.body;
    
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
    
    // Create user
    const newUser = {
      email,
      password: hashedPassword,
      displayName,
      role,
      status: 'active',
      isLocked: false,
      createdAt: new Date(),
      lastLoginAt: null
    };
    
    const result = await db.collection('users').insertOne(newUser);
    
    res.json({
      message: 'User created successfully',
      user: {
        id: result.insertedId,
        email,
        displayName,
        role
      }
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

// Remove all data from database
router.post('/database/clear', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Delete all data from collections
    const messagesResult = await db.collection('messages').deleteMany({});
    const chatsResult = await db.collection('chats').deleteMany({});
    const reportsResult = await db.collection('reports').deleteMany({});
    
    res.json({
      message: 'All data cleared successfully',
      deleted: {
        messages: messagesResult?.deletedCount || 0,
        chats: chatsResult?.deletedCount || 0,
        reports: reportsResult?.deletedCount || 0
      }
    });
  } catch (error) {
    console.error('Error clearing database:', error);
    res.status(500).json({ error: 'Failed to clear database' });
  }
});

// ===== DATABASE OPERATIONS =====

// Get all collections
router.get('/collections', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const collections = await db.listCollections().toArray();
    
    const collectionsWithCounts = await Promise.all(
      collections.map(async (collection) => {
        const count = await db.collection(collection.name).countDocuments();
        return {
          name: collection.name,
          count: count,
          type: collection.type
        };
      })
    );
    
    res.json({ collections: collectionsWithCounts });
  } catch (error) {
    console.error('Error getting collections:', error);
    res.status(500).json({ error: 'Failed to get collections' });
  }
});

// Get collection documents
router.get('/collections/:name', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name } = req.params;
    const { page = 1, limit = 50 } = req.query;
    
    const skip = (page - 1) * limit;
    
    const documents = await db.collection(name)
      .find({})
      .sort({ _id: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection(name).countDocuments();
    
    res.json({
      documents,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Error getting collection documents:', error);
    res.status(500).json({ error: 'Failed to get collection documents' });
  }
});

module.exports = router;
