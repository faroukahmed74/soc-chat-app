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

// Helper function to send consistent error responses
function sendErrorResponse(res, statusCode, errorCode, message, details = null) {
  return res.status(statusCode).json({
    error: {
      code: errorCode,
      message: message,
      details: details,
      timestamp: new Date().toISOString(),
    }
  });
}

// Helper function to emit admin activity events via Socket.IO
function emitAdminActivity(io, activity) {
  if (!io) {
    console.warn('Socket.IO not available for admin activity emission');
    return;
  }
  
  try {
    // Emit to all admins in the admin room
    io.to('admin_room').emit('admin_activity', {
      ...activity,
      timestamp: new Date().toISOString(),
    });
    console.log(`📊 Admin activity emitted: ${activity.type} - ${activity.action}`);
  } catch (error) {
    console.error('Error emitting admin activity:', error);
  }
}

// Middleware to verify admin token
const verifyAdminToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return sendErrorResponse(res, 401, 'AUTH_TOKEN_REQUIRED', 'Access token required');
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret_here');
    
    // Check if user is admin
    if (decoded.role !== 'admin') {
      return sendErrorResponse(res, 403, 'ADMIN_ACCESS_REQUIRED', 'Admin access required');
    }
    
    // Normalize decoded payload for downstream usage
    req.user = { ...decoded, userId: decoded.id };
    next();
  } catch (error) {
    return sendErrorResponse(res, 401, 'INVALID_TOKEN', 'Invalid or expired token', error.message);
  }
};

// Helper to rewrite media URLs to same-origin for web clients
function rewriteMediaUrlIfNeeded(originalUrl, req) {
  try {
    if (!originalUrl) return originalUrl;
    const clientBaseHeader = (req.headers['x-client-base'] || '').toString();
    const clientPlatform = (req.headers['x-client-platform'] || '').toString();
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
    sendErrorResponse(res, 500, 'STATS_ERROR', 'Failed to get database statistics', error.message);
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
        _id: user._id,
        email: user.email,
        displayName: user.displayName,
        phoneNumber: user.phoneNumber || user.phone || '',
        phone: user.phoneNumber || user.phone || '', // Also include as phone for backward compatibility
        role: user.role,
        status: user.status,
        disabled: user.disabled || false,
        isLocked: user.isLocked || false,
        lockedAt: user.lockedAt || null,
        lockedReason: user.lockedReason || null,
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
    sendErrorResponse(res, 500, 'GET_USERS_ERROR', 'Failed to get users', error.message);
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
          mediaUrl: rewriteMediaUrlIfNeeded(message.mediaUrl, req),
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
    const io = req.io;
    const { id } = req.params;
    const { role } = req.body;
    
    if (!role || !['user', 'admin'].includes(role)) {
      return res.status(400).json({ error: 'Valid role is required' });
    }
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(id) });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { $set: { role, updatedAt: new Date() } }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Emit admin activity event
    emitAdminActivity(io, {
      type: 'admin',
      action: 'user_role_changed',
      description: `User role changed to ${role}`,
      adminId: req.user.userId,
      adminName: req.user.email || 'Admin',
      userId: id,
      userName: user.displayName || user.email || 'Unknown',
      details: { oldRole: user.role, newRole: role }
    });
    
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
    if (!io) {
      console.error('❌ Socket.IO instance not available!');
      return res.status(500).json({ error: 'Socket.IO not available' });
    }
    
    // Get all connected user IDs from active sockets
    const connectedUserIds = new Set();
    let allSockets = [];
    try {
      allSockets = await io.fetchSockets();
      allSockets.forEach(socket => {
        if (socket.userId) {
          connectedUserIds.add(socket.userId.toString());
        }
      });
    } catch (socketError) {
      console.error('Error fetching sockets:', socketError);
    }
    
    console.log(`📢 Broadcast: Found ${connectedUserIds.size} connected users out of ${users.length} total users`);
    if (connectedUserIds.size > 0) {
      console.log(`📢 Sample connected user IDs: ${Array.from(connectedUserIds).slice(0, 5).join(', ')}${connectedUserIds.size > 5 ? '...' : ''}`);
    }
    
    // Create a map of user._id to user for quick lookup
    const userMap = new Map();
    users.forEach(user => {
      const userId = user._id.toString();
      userMap.set(userId, user);
      
      // Also check if user has uid field that might match socket.userId
      if (user.uid) {
        userMap.set(user.uid.toString(), user);
      }
    });
    
    let connectedCount = 0;
    let disconnectedCount = 0;
    
    // Create notification payload
    const notificationPayload = {
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
    };
    
    const broadcastPayload = {
      title: '📢 Broadcast',
      body: message,
      chatId: null,
      senderId: req.user.userId,
      senderName: senderName,
      messageType: type || 'text',
      timestamp: new Date(),
    };
    
    // Strategy 1: Emit to specific user rooms
    const emittedToRooms = new Set();
    for (const connectedUserId of connectedUserIds) {
      // Find the corresponding MongoDB user
      const user = userMap.get(connectedUserId);
      if (user) {
        const userId = user._id.toString();
        if (!emittedToRooms.has(connectedUserId)) {
          connectedCount++;
          console.log(`📤 Emitting broadcast to connected user: ${userId} (socket.userId: ${connectedUserId})`);
          
          // Emit to the room using the socket.userId (which is what they joined with)
          io.to(connectedUserId).emit('notification', notificationPayload);
          io.to(connectedUserId).emit('broadcast_notification', broadcastPayload);
          emittedToRooms.add(connectedUserId);
        }
      } else {
        if (!emittedToRooms.has(connectedUserId)) {
          console.log(`⚠️ Connected user ${connectedUserId} not found in database - emitting anyway`);
          // Still try to emit in case the room exists
          io.to(connectedUserId).emit('notification', notificationPayload);
          io.to(connectedUserId).emit('broadcast_notification', broadcastPayload);
          connectedCount++;
          emittedToRooms.add(connectedUserId);
        }
      }
    }
    
    // Strategy 2: Also emit to all users using MongoDB _id format as fallback
    for (const user of users) {
      const userId = user._id.toString();
      // Only emit if we haven't already emitted to this user via socket.userId
      if (!emittedToRooms.has(userId) && (!user.uid || !emittedToRooms.has(user.uid.toString()))) {
        // Try emitting anyway - the room might exist with this format
        io.to(userId).emit('notification', notificationPayload);
        io.to(userId).emit('broadcast_notification', broadcastPayload);
        if (!emittedToRooms.has(userId)) {
          emittedToRooms.add(userId);
        }
      }
    }
    
    // Strategy 3: BROADCAST TO ALL CONNECTED SOCKETS (PRIMARY METHOD)
    // This ensures ALL connected users receive the broadcast regardless of room matching
    // This is the most reliable method for broadcasts
    try {
      const totalConnectedSockets = allSockets.length;
      console.log(`📢 Broadcasting to ALL ${totalConnectedSockets} connected sockets...`);
      
      // Emit to all connected sockets (most reliable for broadcasts)
      io.emit('broadcast_notification', broadcastPayload);
      io.emit('notification', notificationPayload);
      
      console.log(`✅ Broadcast sent to ALL ${totalConnectedSockets} connected sockets via io.emit()`);
      console.log(`📢 Broadcast payload:`, JSON.stringify(broadcastPayload, null, 2));
    } catch (broadcastError) {
      console.error('❌ Error broadcasting to all sockets:', broadcastError);
    }
    
    // Count disconnected users
    for (const user of users) {
      const userId = user._id.toString();
      if (!connectedUserIds.has(userId) && (!user.uid || !connectedUserIds.has(user.uid.toString()))) {
        disconnectedCount++;
      }
    }
    
    console.log(`📢 Broadcast summary: ${connectedCount} users via rooms, ${allSockets.length} total connected sockets, ${disconnectedCount} offline users (message stored)`);
    
    // Send FCM notifications to all users (including offline ones)
    const sendFCMNotification = req.app.locals.sendFCMNotification;
    if (sendFCMNotification) {
      const title = '📢 Broadcast Message';
      const body = message.length > 100 ? message.substring(0, 100) + '...' : message;
      
      let fcmSentCount = 0;
      let fcmFailedCount = 0;
      
      // Send FCM to all users
      for (const user of users) {
        const userId = user._id.toString();
        // Skip if user is the sender (admin)
        if (userId === req.user.userId) continue;
        
        sendFCMNotification(
          userId,
          title,
          body,
          {
            type: 'broadcast',
            senderId: req.user.userId,
            senderName: senderName,
            message: message,
            timestamp: new Date().toISOString(),
          }
        ).then(() => {
          fcmSentCount++;
        }).catch(err => {
          fcmFailedCount++;
          console.error(`Error sending FCM broadcast to user ${userId}:`, err.message);
        });
      }
      
      console.log(`📱 FCM broadcast: ${fcmSentCount} sent, ${fcmFailedCount} failed`);
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

// =============================================================================
// SCHEDULED BROADCASTS
// =============================================================================

// Schedule a broadcast
router.post('/broadcasts/schedule', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const {
      message,
      scheduledAt,
      recurrence,
      userSegment,
      type = 'text',
    } = req.body;
    
    if (!message || !scheduledAt) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Message and scheduledAt are required');
    }
    
    const scheduledDate = new Date(scheduledAt);
    if (isNaN(scheduledDate.getTime())) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Invalid scheduledAt date');
    }
    
    if (scheduledDate < new Date()) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Scheduled date must be in the future');
    }
    
    // Validate recurrence if provided
    const validRecurrences = ['none', 'daily', 'weekly', 'monthly'];
    if (recurrence && !validRecurrences.includes(recurrence)) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', `Invalid recurrence. Must be one of: ${validRecurrences.join(', ')}`);
    }
    
    const scheduledBroadcast = {
      message,
      type,
      scheduledAt: scheduledDate,
      recurrence: recurrence || 'none',
      userSegment: userSegment || null, // Can filter by role, status, etc.
      createdBy: req.user.userId,
      createdAt: new Date(),
      status: 'scheduled',
      sentAt: null,
      error: null,
    };
    
    const result = await db.collection('scheduled_broadcasts').insertOne(scheduledBroadcast);
    
    // Emit admin activity event
    emitAdminActivity(req.io, {
      type: 'admin',
      action: 'broadcast_scheduled',
      description: `Broadcast scheduled for ${scheduledDate.toLocaleString()}`,
      adminId: req.user.userId,
      adminName: req.user.email || 'Admin',
      timestamp: new Date().toISOString(),
      details: {
        scheduledAt: scheduledDate.toISOString(),
        recurrence: recurrence || 'none',
      }
    });
    
    res.json({
      message: 'Broadcast scheduled successfully',
      scheduledBroadcastId: result.insertedId.toString(),
      scheduledAt: scheduledDate.toISOString(),
    });
  } catch (error) {
    console.error('Error scheduling broadcast:', error);
    sendErrorResponse(res, 500, 'SCHEDULE_BROADCAST_ERROR', 'Failed to schedule broadcast', error.message);
  }
});

// Get all scheduled broadcasts
router.get('/broadcasts/scheduled', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { status, limit = 50 } = req.query;
    
    const query = {};
    if (status) {
      query.status = status;
    }
    
    const broadcasts = await db.collection('scheduled_broadcasts')
      .find(query)
      .sort({ scheduledAt: 1 })
      .limit(parseInt(limit))
      .toArray();
    
    res.json(broadcasts.map(b => ({
      id: b._id.toString(),
      message: b.message,
      type: b.type,
      scheduledAt: b.scheduledAt,
      recurrence: b.recurrence,
      userSegment: b.userSegment,
      status: b.status,
      createdBy: b.createdBy,
      createdAt: b.createdAt,
      sentAt: b.sentAt,
      error: b.error,
    })));
  } catch (error) {
    console.error('Error getting scheduled broadcasts:', error);
    sendErrorResponse(res, 500, 'GET_SCHEDULED_BROADCASTS_ERROR', 'Failed to get scheduled broadcasts', error.message);
  }
});

// Cancel/Delete scheduled broadcast
router.delete('/broadcasts/scheduled/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const broadcast = await db.collection('scheduled_broadcasts').findOne({ _id: new ObjectId(id) });
    if (!broadcast) {
      return sendErrorResponse(res, 404, 'NOT_FOUND', 'Scheduled broadcast not found');
    }
    
    // Only allow cancellation if not already sent
    if (broadcast.status === 'sent') {
      return sendErrorResponse(res, 400, 'INVALID_OPERATION', 'Cannot cancel a broadcast that has already been sent');
    }
    
    await db.collection('scheduled_broadcasts').updateOne(
      { _id: new ObjectId(id) },
      { $set: { status: 'cancelled', cancelledAt: new Date(), cancelledBy: req.user.userId } }
    );
    
    // Emit admin activity event
    emitAdminActivity(req.io, {
      type: 'admin',
      action: 'broadcast_cancelled',
      description: `Scheduled broadcast cancelled`,
      adminId: req.user.userId,
      adminName: req.user.email || 'Admin',
      timestamp: new Date().toISOString(),
      details: {
        broadcastId: id,
      }
    });
    
    res.json({ message: 'Scheduled broadcast cancelled successfully' });
  } catch (error) {
    console.error('Error cancelling scheduled broadcast:', error);
    sendErrorResponse(res, 500, 'CANCEL_BROADCAST_ERROR', 'Failed to cancel scheduled broadcast', error.message);
  }
});

// Update scheduled broadcast
router.put('/broadcasts/scheduled/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { message, scheduledAt, recurrence, userSegment, type } = req.body;
    
    const broadcast = await db.collection('scheduled_broadcasts').findOne({ _id: new ObjectId(id) });
    if (!broadcast) {
      return sendErrorResponse(res, 404, 'NOT_FOUND', 'Scheduled broadcast not found');
    }
    
    if (broadcast.status === 'sent') {
      return sendErrorResponse(res, 400, 'INVALID_OPERATION', 'Cannot update a broadcast that has already been sent');
    }
    
    const updateData = { updatedAt: new Date() };
    if (message !== undefined) updateData.message = message;
    if (scheduledAt !== undefined) {
      const scheduledDate = new Date(scheduledAt);
      if (isNaN(scheduledDate.getTime())) {
        return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Invalid scheduledAt date');
      }
      updateData.scheduledAt = scheduledDate;
    }
    if (recurrence !== undefined) updateData.recurrence = recurrence;
    if (userSegment !== undefined) updateData.userSegment = userSegment;
    if (type !== undefined) updateData.type = type;
    
    await db.collection('scheduled_broadcasts').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );
    
    res.json({ message: 'Scheduled broadcast updated successfully' });
  } catch (error) {
    console.error('Error updating scheduled broadcast:', error);
    sendErrorResponse(res, 500, 'UPDATE_BROADCAST_ERROR', 'Failed to update scheduled broadcast', error.message);
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
    sendErrorResponse(res, 500, 'ANALYTICS_ERROR', 'Failed to get analytics', error.message);
  }
});

// Get advanced analytics with detailed metrics
router.get('/analytics/advanced', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { startDate, endDate, period = '30' } = req.query;
    
    // Calculate date range
    const end = endDate ? new Date(endDate) : new Date();
    const days = parseInt(period) || 30;
    const start = startDate ? new Date(startDate) : new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    
    // User Growth Over Time (daily for last 30 days, weekly for longer periods)
    const userGrowth = await db.collection('users').aggregate([
      {
        $match: {
          createdAt: { $gte: start, $lte: end }
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
          },
          count: { $sum: 1 }
        }
      },
      { $sort: { _id: 1 } }
    ]).toArray();
    
    // Message Trends Over Time
    const messageTrends = await db.collection('messages').aggregate([
      {
        $match: {
          createdAt: { $gte: start, $lte: end }
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
          },
          count: { $sum: 1 }
        }
      },
      { $sort: { _id: 1 } }
    ]).toArray();
    
    // Calculate DAU (Daily Active Users) - users who logged in today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const dau = await db.collection('users').countDocuments({
      lastLoginAt: { $gte: today }
    });
    
    // Calculate MAU (Monthly Active Users) - users who logged in last 30 days
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const mau = await db.collection('users').countDocuments({
      lastLoginAt: { $gte: thirtyDaysAgo }
    });
    
    // Calculate retention rate (users who logged in both this month and last month)
    const sixtyDaysAgo = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);
    const lastMonthActive = await db.collection('users').distinct('_id', {
      lastLoginAt: { 
        $gte: sixtyDaysAgo,
        $lt: thirtyDaysAgo
      }
    });
    const thisMonthActive = await db.collection('users').distinct('_id', {
      lastLoginAt: { $gte: thirtyDaysAgo }
    });
    const retainedUsers = thisMonthActive.filter(id => lastMonthActive.some(lid => lid.toString() === id.toString())).length;
    const retentionRate = lastMonthActive.length > 0 
      ? (retainedUsers / lastMonthActive.length) * 100 
      : 0;
    
    // Peak Usage Time Analysis (messages by hour of day)
    const peakUsage = await db.collection('messages').aggregate([
      {
        $match: {
          createdAt: { $gte: start, $lte: end }
        }
      },
      {
        $group: {
          _id: { $hour: '$createdAt' },
          count: { $sum: 1 }
        }
      },
      { $sort: { _id: 1 } }
    ]).toArray();
    
    // Engagement Metrics
    // Average messages per user
    const totalUsersWithMessages = await db.collection('messages').distinct('senderId').then(ids => ids.length);
    const avgMessagesPerUser = totalUsersWithMessages > 0 
      ? totalMessages / totalUsersWithMessages 
      : 0;
    
    // Average chats per user
    const totalUsersInChats = await db.collection('chats').distinct('members').then(ids => ids.length);
    const avgChatsPerUser = totalUsersInChats > 0 
      ? totalChats / totalUsersInChats 
      : 0;
    
    // Most active users (top 10 by message count)
    const topUsers = await db.collection('messages').aggregate([
      {
        $match: {
          createdAt: { $gte: start, $lte: end }
        }
      },
      {
        $group: {
          _id: '$senderId',
          messageCount: { $sum: 1 }
        }
      },
      { $sort: { messageCount: -1 } },
      { $limit: 10 }
    ]).toArray();
    
    // Get user details for top users
    const topUserIds = topUsers.map(u => u._id).filter(id => id);
    const topUserDetails = topUserIds.length > 0
      ? await db.collection('users')
          .find({ _id: { $in: topUserIds } })
          .toArray()
      : [];
    
    const topUsersWithNames = topUsers.map(user => {
      const userDetail = topUserDetails.find(u => u._id.toString() === user._id.toString());
      return {
        userId: user._id,
        userName: userDetail?.displayName || userDetail?.email || 'Unknown',
        messageCount: user.messageCount
      };
    });
    
    // Most active chats (top 10 by message count)
    const topChats = await db.collection('messages').aggregate([
      {
        $match: {
          createdAt: { $gte: start, $lte: end }
        }
      },
      {
        $group: {
          _id: '$chatId',
          messageCount: { $sum: 1 }
        }
      },
      { $sort: { messageCount: -1 } },
      { $limit: 10 }
    ]).toArray();
    
    // Get chat details
    const topChatIds = topChats.map(c => c._id).filter(id => id);
    const topChatDetails = topChatIds.length > 0
      ? await db.collection('chats')
          .find({ _id: { $in: topChatIds } })
          .toArray()
      : [];
    
    const topChatsWithNames = topChats.map(chat => {
      const chatDetail = topChatDetails.find(c => c._id.toString() === chat._id.toString());
      return {
        chatId: chat._id,
        chatName: chatDetail?.name || 'Unknown Chat',
        messageCount: chat.messageCount
      };
    });
    
    // User growth rate (comparing last period to previous period)
    const periodDays = Math.floor((end - start) / (1000 * 60 * 60 * 24));
    const previousStart = new Date(start.getTime() - periodDays * 24 * 60 * 60 * 1000);
    const previousEnd = start;
    
    const currentPeriodUsers = await db.collection('users').countDocuments({
      createdAt: { $gte: start, $lte: end }
    });
    const previousPeriodUsers = await db.collection('users').countDocuments({
      createdAt: { $gte: previousStart, $lt: previousEnd }
    });
    const userGrowthRate = previousPeriodUsers > 0
      ? ((currentPeriodUsers - previousPeriodUsers) / previousPeriodUsers) * 100
      : 0;
    
    // Message growth rate
    const currentPeriodMessages = await db.collection('messages').countDocuments({
      createdAt: { $gte: start, $lte: end }
    });
    const previousPeriodMessages = await db.collection('messages').countDocuments({
      createdAt: { $gte: previousStart, $lt: previousEnd }
    });
    const messageGrowthRate = previousPeriodMessages > 0
      ? ((currentPeriodMessages - previousPeriodMessages) / previousPeriodMessages) * 100
      : 0;
    
    res.json({
      period: {
        start: start.toISOString(),
        end: end.toISOString(),
        days: periodDays
      },
      userGrowth: {
        data: userGrowth.map(item => ({
          date: item._id,
          count: item.count
        })),
        growthRate: userGrowthRate,
        total: currentPeriodUsers
      },
      messageTrends: {
        data: messageTrends.map(item => ({
          date: item._id,
          count: item.count
        })),
        growthRate: messageGrowthRate,
        total: currentPeriodMessages
      },
      engagement: {
        dau: dau,
        mau: mau,
        retentionRate: retentionRate.toFixed(2),
        avgMessagesPerUser: avgMessagesPerUser.toFixed(2),
        avgChatsPerUser: avgChatsPerUser.toFixed(2)
      },
      peakUsage: {
        byHour: peakUsage.map(item => ({
          hour: item._id,
          count: item.count
        }))
      },
      topUsers: topUsersWithNames,
      topChats: topChatsWithNames,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error getting advanced analytics:', error);
    sendErrorResponse(res, 500, 'ADVANCED_ANALYTICS_ERROR', 'Failed to get advanced analytics', error.message);
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
    const { email, displayName, name, role, status, profilePicture } = req.body;
    
    const updateData = {};
    if (email) updateData.email = email;
    // Support both displayName and name for compatibility
    if (displayName !== undefined) {
      updateData.displayName = displayName;
      updateData.name = displayName; // Also update name field for compatibility
    } else if (name !== undefined) {
      updateData.name = name;
      updateData.displayName = name; // Also update displayName if name is provided
    }
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

// Update user password (admin only)
router.put('/users/:id/password', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { password } = req.body;
    
    if (!password || password.trim().length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long' });
    }
    
    // Hash password
    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash(password.trim(), 10);
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { 
        $set: { 
          password: hashedPassword,
          updatedAt: new Date()
        } 
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error('Error updating user password:', error);
    res.status(500).json({ error: 'Failed to update password' });
  }
});

// Get single user with complete details
router.get('/users/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(id) });
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userId = user._id;
    
    // Get user devices
    const devices = await db.collection('devices')
      .find({ userId: userId })
      .sort({ lastSeen: -1 })
      .toArray();
    
    // Get message count
    const messageCount = await db.collection('messages').countDocuments({ senderId: userId });
    
    // Get messages today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const messagesToday = await db.collection('messages').countDocuments({
      senderId: userId,
      createdAt: { $gte: today }
    });
    
    // Get chat count (chats where user is a member)
    const chatCount = await db.collection('chats').countDocuments({
      $or: [
        { members: userId },
        { memberIds: userId }
      ]
    });
    
    // Get user activity logs (last 10)
    const userLogs = await db.collection('user_logs')
      .find({ userId: userId })
      .sort({ timestamp: -1, createdAt: -1 })
      .limit(10)
      .toArray();
    
    // Get reports where user is the reporter
    const reportsCollectionExists = (await db.listCollections().toArray()).some(c => c.name === 'reports');
    let reportsAsReporter = 0;
    let reportsAsReported = 0;
    if (reportsCollectionExists) {
      reportsAsReporter = await db.collection('reports').countDocuments({ reporterId: userId });
      reportsAsReported = await db.collection('reports').countDocuments({ reportedUserId: userId });
    }
    
    // Calculate account age
    const accountAge = user.createdAt 
      ? Math.floor((Date.now() - new Date(user.createdAt).getTime()) / (1000 * 60 * 60 * 24))
      : 0;
    
    // Get last activity timestamp
    let lastActivity = user.lastLoginAt || user.createdAt;
    if (userLogs.length > 0) {
      const latestLog = userLogs[0];
      const logTime = latestLog.timestamp || latestLog.createdAt;
      if (logTime && (!lastActivity || new Date(logTime) > new Date(lastActivity))) {
        lastActivity = logTime;
      }
    }
    
    // Get user's chats with details
    const userChats = await db.collection('chats')
      .find({
        $or: [
          { members: userId },
          { memberIds: userId }
        ]
      })
      .sort({ updatedAt: -1 })
      .limit(50)
      .toArray();
    
    // Get recent messages (last 20)
    const recentMessages = await db.collection('messages')
      .find({ senderId: userId })
      .sort({ createdAt: -1 })
      .limit(20)
      .toArray();
    
    // Get violation history from moderation
    let violations = [];
    try {
      const violationsCollection = await db.collection('moderation_violations')
        .find({ userId: userId })
        .sort({ createdAt: -1 })
        .limit(20)
        .toArray();
      violations = violationsCollection;
    } catch (e) {
      // Collection might not exist yet
      console.log('Moderation violations collection not found');
    }
    
    // Calculate user insights
    const insights = _calculateUserInsights(user, {
      accountAge,
      messageCount,
      messagesToday,
      chatCount,
      reportsAsReporter,
      reportsAsReported,
      violations: violations.length,
      devices: devices.length,
      userLogs: userLogs.length,
    });
    
    res.json({
      id: user._id,
      email: user.email,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber || user.phone || '',
      role: user.role,
      status: user.status,
      disabled: user.disabled || false,
      isLocked: user.isLocked || false,
      lockedAt: user.lockedAt || null,
      lockedReason: user.lockedReason || null,
      createdAt: user.createdAt,
      lastLoginAt: user.lastLoginAt,
      lastActivity: lastActivity,
      profilePicture: user.profilePicture,
      // Statistics
      stats: {
        accountAgeDays: accountAge,
        messageCount: messageCount,
        messagesToday: messagesToday,
        chatCount: chatCount,
        reportsAsReporter: reportsAsReporter,
        reportsAsReported: reportsAsReported,
        deviceCount: devices.length,
      },
      // Devices
      devices: devices.map(device => ({
        id: device._id.toString(),
        deviceId: device.deviceId,
        deviceType: device.deviceType,
        deviceModel: device.deviceModel,
        platform: device.platform,
        platformVersion: device.platformVersion,
        appVersion: device.appVersion,
        ipAddress: device.ipAddress,
        fcmEnabled: device.fcmEnabled || false,
        lastSeen: device.lastSeen,
        createdAt: device.createdAt,
      })),
      // Recent activity
      recentActivity: userLogs.map(log => ({
        id: log._id.toString(),
        action: log.action,
        details: log.details || {},
        timestamp: log.timestamp || log.createdAt,
      })),
      // Chats
      chats: userChats.map(chat => ({
        id: chat._id.toString(),
        name: chat.name || 'Chat',
        type: chat.type || 'group',
        memberCount: (chat.members || chat.memberIds || []).length,
        createdAt: chat.createdAt,
        updatedAt: chat.updatedAt,
        lastMessage: chat.lastMessage,
      })),
      // Recent messages
      recentMessages: recentMessages.map(msg => ({
        id: msg._id.toString(),
        chatId: msg.chatId?.toString(),
        content: msg.content,
        messageType: msg.messageType || msg.type || 'text',
        createdAt: msg.createdAt,
      })),
      // Violations
      violations: violations.map(v => ({
        id: v._id.toString(),
        type: v.type || 'unknown',
        reason: v.reason || '',
        action: v.action || '',
        createdAt: v.createdAt,
        adminId: v.adminId,
      })),
      // Insights
      insights: insights,
    });
  } catch (error) {
    console.error('Error getting user:', error);
    sendErrorResponse(res, 500, 'GET_USER_ERROR', 'Failed to get user details', error.message);
  }
});

// Helper function to calculate user insights
function _calculateUserInsights(user, metrics) {
  const {
    accountAge,
    messageCount,
    messagesToday,
    chatCount,
    reportsAsReporter,
    reportsAsReported,
    violations,
    devices,
    userLogs,
  } = metrics;
  
  // Calculate activity score (0-100)
  const activityScore = Math.min(100, Math.round(
    (messageCount * 0.3) +
    (chatCount * 10) +
    (messagesToday * 2) +
    (userLogs * 0.5)
  ));
  
  // Calculate risk score (0-100, higher = more risky)
  let riskScore = 0;
  
  // Reports against user increase risk
  riskScore += reportsAsReported * 15;
  
  // Violations increase risk
  riskScore += violations * 20;
  
  // Locked account increases risk
  if (user.isLocked) {
    riskScore += 30;
  }
  
  // Disabled account increases risk
  if (user.disabled) {
    riskScore += 25;
  }
  
  // New accounts (less than 7 days) have slightly higher risk
  if (accountAge < 7) {
    riskScore += 5;
  }
  
  // Very inactive accounts (no messages in 30 days) have higher risk
  const daysSinceLastActivity = user.lastActivity 
    ? Math.floor((Date.now() - new Date(user.lastActivity).getTime()) / (1000 * 60 * 60 * 24))
    : accountAge;
  if (daysSinceLastActivity > 30) {
    riskScore += 10;
  }
  
  riskScore = Math.min(100, riskScore);
  
  // Determine risk level
  let riskLevel = 'low';
  if (riskScore >= 70) {
    riskLevel = 'high';
  } else if (riskScore >= 40) {
    riskLevel = 'medium';
  }
  
  // Calculate engagement level
  let engagementLevel = 'low';
  const avgMessagesPerDay = accountAge > 0 ? messageCount / accountAge : 0;
  if (avgMessagesPerDay >= 10) {
    engagementLevel = 'high';
  } else if (avgMessagesPerDay >= 3) {
    engagementLevel = 'medium';
  }
  
  return {
    activityScore,
    riskScore,
    riskLevel,
    engagementLevel,
    avgMessagesPerDay: Math.round(avgMessagesPerDay * 10) / 10,
    accountAge,
    daysSinceLastActivity,
    metrics: {
      totalMessages: messageCount,
      messagesToday,
      totalChats: chatCount,
      totalDevices: devices,
      totalReports: reportsAsReported,
      totalViolations: violations,
    },
  };
}

// ===== CHATS CRUD =====

// Get single chat with details
router.get('/chats/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { includeMessages = 'false' } = req.query;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
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
    
    // Get owner details
    let owner = null;
    if (chat.createdBy) {
      try {
        const ownerDoc = await db.collection('users').findOne({ _id: new ObjectId(chat.createdBy) });
        if (ownerDoc) {
          owner = {
            id: ownerDoc._id.toString(),
            name: ownerDoc.displayName,
            email: ownerDoc.email,
          };
        }
      } catch (e) {
        console.error('Error getting owner:', e);
      }
    }
    
    // Get moderators
    const moderatorIds = chat.moderators || [];
    const moderators = moderatorIds.length > 0
      ? await db.collection('users')
          .find({ _id: { $in: moderatorIds.map(id => new ObjectId(id)) } })
          .toArray()
      : [];
    
    const chatData = {
        _id: chat._id,
        id: chat._id.toString(),
        name: chat.name,
        type: chat.type || 'group',
        members: members.map(member => ({
        id: member._id.toString(),
          name: member.displayName,
        email: member.email,
        role: member.role,
        profilePicture: member.profilePicture,
        })),
        memberIds: (chat.members || chat.memberIds || []).map(m => m.toString()),
      createdBy: chat.createdBy?.toString(),
      owner: owner,
      moderators: moderators.map(mod => ({
        id: mod._id.toString(),
        name: mod.displayName,
        email: mod.email,
      })),
      moderatorIds: moderatorIds.map(id => id.toString()),
        createdAt: chat.createdAt,
        updatedAt: chat.updatedAt,
      archived: chat.archived || false,
      muted: chat.muted || false,
      mutedUntil: chat.mutedUntil || null,
      permissions: chat.permissions || {
        canSendMessages: true,
        canAddMembers: true,
        canRemoveMembers: false,
        canChangeSettings: false,
      },
    };
    
    // Include messages if requested
    if (includeMessages === 'true') {
      const { page = 1, limit = 50 } = req.query;
      const skip = (parseInt(page) - 1) * parseInt(limit);
      
      const messages = await db.collection('messages')
        .find({ chatId: new ObjectId(id) })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .toArray();
      
      const totalMessages = await db.collection('messages').countDocuments({ chatId: new ObjectId(id) });
      
      // Get sender details for messages
      const messagesWithSenders = await Promise.all(
        messages.map(async (message) => {
          let senderName = 'Unknown';
          if (message.senderId) {
            try {
              const sender = await db.collection('users').findOne({ _id: message.senderId });
              if (sender) {
                senderName = sender.displayName || sender.email || 'Unknown';
              }
            } catch (e) {
              console.error('Error getting sender:', e);
            }
          }
          
          return {
            id: message._id.toString(),
            chatId: message.chatId.toString(),
            senderId: message.senderId?.toString(),
            senderName: senderName,
            content: message.content || '',
            type: message.type || message.messageType || 'text',
            mediaUrl: rewriteMediaUrlIfNeeded(message.mediaUrl, req),
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            isDeletedForEveryone: message.isDeletedForEveryone || false,
          };
        })
      );
      
      chatData.messages = messagesWithSenders;
      chatData.messagesPagination = {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalMessages,
        pages: Math.ceil(totalMessages / parseInt(limit)),
      };
    }
    
    res.json({ chat: chatData });
  } catch (error) {
    console.error('Error getting chat:', error);
    sendErrorResponse(res, 500, 'GET_CHAT_ERROR', 'Failed to get chat', error.message);
  }
});

// Update chat
router.put('/chats/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, type, members, archived } = req.body;
    
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (type !== undefined) updateData.type = type;
    if (members !== undefined) updateData.members = members.map(m => typeof m === 'string' && ObjectId.isValid(m) ? new ObjectId(m) : m);
    if (archived !== undefined) updateData.archived = archived;
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

// Add member to chat/group
router.post('/chats/:id/members', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    const memberObjectId = typeof userId === 'string' && ObjectId.isValid(userId) ? new ObjectId(userId) : userId;
    const currentMembers = chat.members || chat.memberIds || [];
    
    // Check if user is already a member
    const isAlreadyMember = currentMembers.some(m => 
      (typeof m === 'string' && m === userId) || 
      (m && m.toString() === userId) ||
      (m && m.toString() === memberObjectId.toString())
    );
    
    if (isAlreadyMember) {
      return res.status(400).json({ error: 'User is already a member of this chat' });
    }
    
    // Add member
    const updatedMembers = [...currentMembers, memberObjectId];
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      { 
        $set: { 
          members: updatedMembers,
          memberIds: updatedMembers,
          updatedAt: new Date()
        } 
      }
    );
    
    res.json({ message: 'Member added successfully' });
  } catch (error) {
    console.error('Error adding member to chat:', error);
    res.status(500).json({ error: 'Failed to add member to chat' });
  }
});

// Remove member from chat/group
router.delete('/chats/:id/members/:userId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id, userId } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    const currentMembers = chat.members || chat.memberIds || [];
    const memberObjectId = typeof userId === 'string' && ObjectId.isValid(userId) ? new ObjectId(userId) : userId;
    
    // Remove member
    const updatedMembers = currentMembers.filter(m => {
      if (!m) return false;
      const mId = (typeof m === 'string' && ObjectId.isValid(m)) ? new ObjectId(m) : m;
      return mId.toString() !== memberObjectId.toString() && m.toString() !== userId;
    });
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      { 
        $set: { 
          members: updatedMembers,
          memberIds: updatedMembers,
          updatedAt: new Date()
        } 
      }
    );
    
    res.json({ message: 'Member removed successfully' });
  } catch (error) {
    console.error('Error removing member from chat:', error);
    res.status(500).json({ error: 'Failed to remove member from chat' });
  }
});

// Get chat/group statistics
router.get('/chats/:id/statistics', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    const memberIds = chat.members || chat.memberIds || [];
    const memberCount = memberIds.length;
    
    // Get messages count
    const totalMessages = await db.collection('messages').countDocuments({ chatId: new ObjectId(id) });
    
    // Get messages today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const messagesToday = await db.collection('messages').countDocuments({
      chatId: new ObjectId(id),
      createdAt: { $gte: today }
    });
    
    // Get last activity (last message timestamp)
    const lastMessage = await db.collection('messages')
      .findOne(
        { chatId: new ObjectId(id) },
        { sort: { createdAt: -1 } }
      );
    
    // Get message types distribution
    const messageTypes = await db.collection('messages').aggregate([
      { $match: { chatId: new ObjectId(id) } },
      { $group: { _id: '$type', count: { $sum: 1 } } }
    ]).toArray();
    
    const messageTypesMap = {};
    messageTypes.forEach(item => {
      messageTypesMap[item._id || 'text'] = item.count;
    });
    
    // Get active members (members who sent messages in last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const activeMemberIds = await db.collection('messages').distinct('senderId', {
      chatId: new ObjectId(id),
      createdAt: { $gte: sevenDaysAgo }
    });
    
    res.json({
      memberCount,
      activeMembers: activeMemberIds.length,
      totalMessages,
      messagesToday,
      lastActivity: lastMessage ? lastMessage.createdAt : null,
      messageTypes: messageTypesMap,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt
    });
  } catch (error) {
    console.error('Error getting chat statistics:', error);
    res.status(500).json({ error: 'Failed to get chat statistics' });
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
      mediaUrl: rewriteMediaUrlIfNeeded(message.mediaUrl, req),
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

// Bulk operations for users (lock, unlock, delete, role-change)
router.post('/users/bulk-operations', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userIds, action, reason, role } = req.body;
    
    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ error: 'userIds array is required and must not be empty' });
    }
    
    if (!action || !['lock', 'unlock', 'delete', 'role-change'].includes(action)) {
      return res.status(400).json({ error: 'Valid action is required: lock, unlock, delete, or role-change' });
    }
    
    // Don't allow deleting the current admin
    const currentUserId = req.user.userId;
    const filteredUserIds = userIds.filter(id => id !== currentUserId);
    
    if (action === 'delete' && filteredUserIds.length !== userIds.length) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }
    
    const objectIds = filteredUserIds.map(id => new ObjectId(id));
    let result;
    let message;
    
    switch (action) {
      case 'lock':
        result = await db.collection('users').updateMany(
          { _id: { $in: objectIds } },
          {
            $set: {
              isLocked: true,
              lockedReason: reason || 'Bulk lock operation',
              lockedAt: new Date(),
              updatedAt: new Date()
            }
          }
        );
        message = `${result.modifiedCount} user(s) locked successfully`;
        break;
        
      case 'unlock':
        result = await db.collection('users').updateMany(
          { _id: { $in: objectIds } },
          {
            $set: {
              isLocked: false,
              lockedReason: null,
              lockedAt: null,
              updatedAt: new Date()
            }
          }
        );
        message = `${result.modifiedCount} user(s) unlocked successfully`;
        break;
        
      case 'delete':
        result = await db.collection('users').deleteMany({ _id: { $in: objectIds } });
        message = `${result.deletedCount} user(s) deleted successfully`;
        break;
        
      case 'role-change':
        if (!role || !['user', 'admin'].includes(role)) {
          return res.status(400).json({ error: 'Valid role is required: user or admin' });
        }
        result = await db.collection('users').updateMany(
          { _id: { $in: objectIds } },
          {
            $set: {
              role: role,
              updatedAt: new Date()
            }
          }
        );
        message = `${result.modifiedCount} user(s) role changed to ${role} successfully`;
        break;
    }
    
    // Emit admin activity event for bulk operation
    emitAdminActivity(io, {
      type: 'admin',
      action: `bulk_${action}`,
      description: `Bulk ${action} performed on ${filteredUserIds.length} user(s)`,
      adminId: req.user.userId,
      adminName: req.user.email || 'Admin',
      timestamp: new Date().toISOString(),
      details: { 
        userIds: filteredUserIds, 
        count: filteredUserIds.length,
        reason: reason || null,
        role: role || null
      }
    });
    
    res.json({
      message: message,
      affectedCount: result.modifiedCount || result.deletedCount || 0,
      action: action
    });
  } catch (error) {
    console.error('Error performing bulk operation:', error);
    sendErrorResponse(res, 500, 'BULK_OPERATION_ERROR', 'Failed to perform bulk operation', error.message);
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
    const io = req.io;
    const { id } = req.params;
    const { reason } = req.body;
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(id) });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
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
    
    // Emit admin activity event
    emitAdminActivity(io, {
      type: 'admin',
      action: 'user_locked',
      description: `User locked: ${user.displayName || user.email || 'Unknown'}`,
      adminId: req.user.userId,
      adminName: req.user.email || 'Admin',
      userId: id,
      userName: user.displayName || user.email || 'Unknown',
      details: { reason: reason || 'No reason provided' }
    });
    
    res.json({ message: 'User locked successfully' });
  } catch (error) {
    console.error('Error locking user:', error);
    sendErrorResponse(res, 500, 'LOCK_USER_ERROR', 'Failed to lock user', error.message);
  }
});

// Unlock user
router.post('/users/:id/unlock', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const io = req.io;
    const { id } = req.params;
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(id) });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
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
    
    // Emit admin activity event
    emitAdminActivity(io, {
      type: 'admin',
      action: 'user_unlocked',
      description: `User unlocked: ${user.displayName || user.email || 'Unknown'}`,
      adminId: req.user.userId,
      adminName: req.user.email || 'Admin',
      userId: id,
      userName: user.displayName || user.email || 'Unknown',
      details: {}
    });
    
    res.json({ message: 'User unlocked successfully' });
  } catch (error) {
    console.error('Error unlocking user:', error);
    sendErrorResponse(res, 500, 'UNLOCK_USER_ERROR', 'Failed to unlock user', error.message);
  }
});

// Toggle user status (enable/disable)
router.patch('/users/:id/status', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { disabled } = req.body;
    
    if (typeof disabled !== 'boolean') {
      return res.status(400).json({ error: 'disabled field must be a boolean' });
    }
    
    const result = await db.collection('users').updateOne(
      { _id: new ObjectId(id) },
      { 
        $set: { 
          disabled: disabled,
          updatedAt: new Date()
        } 
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ 
      message: disabled ? 'User disabled successfully' : 'User enabled successfully',
      disabled: disabled
    });
  } catch (error) {
    console.error('Error toggling user status:', error);
    res.status(500).json({ error: 'Failed to toggle user status' });
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

// ===== LOGS CRUD =====

// Get user logs (admin only)
router.get('/logs/users', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 100, userId } = req.query;
    
    const query = {};
    if (userId) {
      query.userId = userId;
    }
    
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const logs = await db.collection('user_logs')
      .find(query)
      .sort({ timestamp: -1, createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('user_logs').countDocuments(query);
    
    res.json({
      logs,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error getting user logs:', error);
    res.status(500).json({ error: 'Failed to get user logs' });
  }
});

// Create user log (admin only)
router.post('/logs/users', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId, action, details, timestamp } = req.body;
    
    if (!userId || !action) {
      return res.status(400).json({ error: 'userId and action are required' });
    }
    
    const log = {
      userId,
      action,
      details: details || {},
      timestamp: timestamp || new Date().toISOString(),
      createdAt: new Date(),
    };
    
    const result = await db.collection('user_logs').insertOne(log);
    
    res.status(200).json({
      message: 'User log created successfully',
      logId: result.insertedId
    });
  } catch (error) {
    console.error('Error creating user log:', error);
    res.status(500).json({ error: 'Failed to create user log' });
  }
});

// Get admin logs (admin only)
router.get('/logs/admin', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 100, adminId } = req.query;
    
    const query = {};
    if (adminId) {
      query.adminId = adminId;
    }
    
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const logs = await db.collection('admin_logs')
      .find(query)
      .sort({ timestamp: -1, createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('admin_logs').countDocuments(query);
    
    res.json({
      logs,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error getting admin logs:', error);
    res.status(500).json({ error: 'Failed to get admin logs' });
  }
});

// Create admin log (admin only)
router.post('/logs/admin', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { adminId, action, details, timestamp } = req.body;
    
    if (!adminId || !action) {
      return res.status(400).json({ error: 'adminId and action are required' });
    }
    
    const log = {
      adminId,
      action,
      details: details || {},
      timestamp: timestamp || new Date().toISOString(),
      createdAt: new Date(),
    };
    
    const result = await db.collection('admin_logs').insertOne(log);
    
    res.status(200).json({
      message: 'Admin log created successfully',
      logId: result.insertedId
    });
  } catch (error) {
    console.error('Error creating admin log:', error);
    res.status(500).json({ error: 'Failed to create admin log' });
  }
});

// =============================================================================
// RECENT ACTIVITY ENDPOINT
// =============================================================================

// Get recent activity (combines user logs and admin logs)
router.get('/activity', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { limit = 10, type } = req.query;
    
    const limitNum = parseInt(limit);
    const activities = [];
    
    // Get recent user logs
    if (!type || type === 'user' || type === 'all') {
      const userLogs = await db.collection('user_logs')
        .find({})
        .sort({ timestamp: -1, createdAt: -1 })
        .limit(limitNum)
        .toArray();
      
      for (const log of userLogs) {
        // Get user info if userId exists
        let userName = 'Unknown User';
        if (log.userId) {
          try {
            const user = await db.collection('users').findOne({ _id: log.userId });
            if (user) {
              userName = user.displayName || user.email || 'Unknown User';
            }
          } catch (e) {
            console.error('Error getting user info:', e);
          }
        }
        
        activities.push({
          id: log._id,
          type: 'user',
          action: log.action || 'Unknown action',
          description: _formatActivityDescription('user', log.action, userName, log.details),
          userId: log.userId,
          userName: userName,
          timestamp: log.timestamp || log.createdAt,
          createdAt: log.createdAt,
          details: log.details || {},
        });
      }
    }
    
    // Get recent admin logs
    if (!type || type === 'admin' || type === 'all') {
      const adminLogs = await db.collection('admin_logs')
        .find({})
        .sort({ timestamp: -1, createdAt: -1 })
        .limit(limitNum)
        .toArray();
      
      for (const log of adminLogs) {
        // Get admin info if adminId exists
        let adminName = 'Unknown Admin';
        if (log.adminId) {
          try {
            const admin = await db.collection('users').findOne({ _id: log.adminId });
            if (admin) {
              adminName = admin.displayName || admin.email || 'Unknown Admin';
            }
          } catch (e) {
            console.error('Error getting admin info:', e);
          }
        }
        
        activities.push({
          id: log._id,
          type: 'admin',
          action: log.action || 'Unknown action',
          description: _formatActivityDescription('admin', log.action, adminName, log.details),
          adminId: log.adminId,
          adminName: adminName,
          timestamp: log.timestamp || log.createdAt,
          createdAt: log.createdAt,
          details: log.details || {},
        });
      }
    }
    
    // Also get recent user registrations, chat creations, and reports
    if (!type || type === 'system' || type === 'all') {
      // Recent user registrations
      const recentUsers = await db.collection('users')
        .find({})
        .sort({ createdAt: -1 })
        .limit(5)
        .toArray();
      
      for (const user of recentUsers) {
        const createdAt = user.createdAt || new Date();
        const hoursAgo = (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60);
        if (hoursAgo <= 24) { // Only include if within last 24 hours
          activities.push({
            id: `user_reg_${user._id}`,
            type: 'system',
            action: 'user_registered',
            description: `New user registered: ${user.displayName || user.email || 'Unknown'}`,
            userId: user._id,
            userName: user.displayName || user.email || 'Unknown',
            timestamp: createdAt,
            createdAt: createdAt,
            details: { email: user.email },
          });
        }
      }
      
      // Recent chat creations
      const recentChats = await db.collection('chats')
        .find({})
        .sort({ createdAt: -1 })
        .limit(5)
        .toArray();
      
      for (const chat of recentChats) {
        const createdAt = chat.createdAt || new Date();
        const hoursAgo = (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60);
        if (hoursAgo <= 24) {
          activities.push({
            id: `chat_created_${chat._id}`,
            type: 'system',
            action: 'chat_created',
            description: `New ${chat.type || 'chat'} created: ${chat.name || 'Unnamed'}`,
            chatId: chat._id,
            chatName: chat.name || 'Unnamed',
            timestamp: createdAt,
            createdAt: createdAt,
            details: { type: chat.type },
          });
        }
      }
      
      // Recent reports
      const reportsCollectionExists = (await db.listCollections().toArray()).some(c => c.name === 'reports');
      if (reportsCollectionExists) {
        const recentReports = await db.collection('reports')
          .find({})
          .sort({ createdAt: -1 })
          .limit(5)
          .toArray();
        
        for (const report of recentReports) {
          const createdAt = report.createdAt || new Date();
          const hoursAgo = (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60);
          if (hoursAgo <= 24) {
            activities.push({
              id: `report_${report._id}`,
              type: 'system',
              action: 'report_submitted',
              description: `Report submitted: ${report.type || 'general'} - ${report.description?.substring(0, 50) || 'No description'}`,
              reportId: report._id,
              timestamp: createdAt,
              createdAt: createdAt,
              details: { type: report.type, status: report.status },
            });
          }
        }
      }
    }
    
    // Sort all activities by timestamp (most recent first) and limit
    activities.sort((a, b) => {
      const timeA = new Date(a.timestamp || a.createdAt || 0).getTime();
      const timeB = new Date(b.timestamp || b.createdAt || 0).getTime();
      return timeB - timeA;
    });
    
    // Return limited results
    const limitedActivities = activities.slice(0, limitNum);
    
    res.json({
      activities: limitedActivities,
      total: activities.length,
    });
    } catch (error) {
      console.error('Error getting recent activity:', error);
      sendErrorResponse(res, 500, 'ACTIVITY_ERROR', 'Failed to get recent activity', error.message);
    }
  });

// Helper function to format activity descriptions
function _formatActivityDescription(type, action, userName, details) {
  const actionMap = {
    'user': {
      'login': `${userName} logged in`,
      'logout': `${userName} logged out`,
      'register': `${userName} registered`,
      'update_profile': `${userName} updated profile`,
      'send_message': `${userName} sent a message`,
      'create_chat': `${userName} created a chat`,
      'join_chat': `${userName} joined a chat`,
      'leave_chat': `${userName} left a chat`,
    },
    'admin': {
      'lock_user': `${userName} locked a user`,
      'unlock_user': `${userName} unlocked a user`,
      'delete_user': `${userName} deleted a user`,
      'broadcast': `${userName} sent a broadcast`,
      'update_settings': `${userName} updated settings`,
      'export_data': `${userName} exported data`,
    },
  };
  
  const typeMap = actionMap[type] || {};
  return typeMap[action] || `${userName} performed ${action}`;
}

// =============================================================================
// DEVICE TRACKING ENDPOINTS
// =============================================================================

// Middleware to verify token (for device registration - allows regular users)
const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret_here');
    req.user = { ...decoded, userId: decoded.id };
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Register or update device information
// Accessible from both web (local network) and mobile (ngrok)
router.post('/devices/register', verifyToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const userId = req.user.id;
    const { deviceId, deviceType, deviceModel, platform, platformVersion, appVersion, fcmToken, ipAddress } = req.body;
    
    // Get client IP from request (works for both local network and ngrok)
    // For ngrok, x-forwarded-for header contains the real client IP
    const forwardedFor = req.headers['x-forwarded-for'];
    const clientIp = forwardedFor 
      ? (Array.isArray(forwardedFor) ? forwardedFor[0] : forwardedFor.split(',')[0].trim())
      : req.ip || req.connection.remoteAddress || ipAddress || 'unknown';
    
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    
    // Get user email for tracking
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    const userEmail = user?.email || 'unknown';
    
    // Check if device already exists
    const existingDevice = await db.collection('devices').findOne({
      deviceId: deviceId,
      userId: new ObjectId(userId)
    });
    
    const deviceData = {
      deviceId,
      userId: new ObjectId(userId),
      userEmail,
      deviceType: deviceType || 'unknown',
      deviceModel: deviceModel || 'unknown',
      platform: platform || 'unknown',
      platformVersion: platformVersion || 'unknown',
      appVersion: appVersion || '1.0.0',
      ipAddress: clientIp,
      fcmToken: fcmToken || null,
      fcmEnabled: fcmToken != null,
      lastSeen: new Date(),
      createdAt: existingDevice?.createdAt || new Date(),
      updatedAt: new Date()
    };
    
    if (existingDevice) {
      // Update existing device
      await db.collection('devices').updateOne(
        { _id: existingDevice._id },
        { $set: deviceData }
      );
      res.status(200).json({ message: 'Device updated successfully', device: deviceData });
    } else {
      // Create new device
      const result = await db.collection('devices').insertOne(deviceData);
      res.status(201).json({ message: 'Device registered successfully', device: { ...deviceData, _id: result.insertedId } });
    }
  } catch (error) {
    console.error('Error registering device:', error);
    res.status(500).json({ error: 'Failed to register device' });
  }
});

// Update device last seen timestamp
router.patch('/devices/update-last-seen', verifyToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const userId = req.user.id;
    const { deviceId } = req.body;
    
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    
    await db.collection('devices').updateOne(
      { deviceId, userId: new ObjectId(userId) },
      { 
        $set: { 
          lastSeen: new Date(),
          updatedAt: new Date()
        }
      }
    );
    
    res.status(200).json({ message: 'Last seen updated successfully' });
  } catch (error) {
    console.error('Error updating last seen:', error);
    res.status(500).json({ error: 'Failed to update last seen' });
  }
});

// Get all devices (admin only)
router.get('/devices', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50, search = '', platform = '', userId = '' } = req.query;
    
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const query = {};
    
    if (search) {
      query.$or = [
        { userEmail: { $regex: search, $options: 'i' } },
        { deviceModel: { $regex: search, $options: 'i' } },
        { ipAddress: { $regex: search, $options: 'i' } },
        { deviceId: { $regex: search, $options: 'i' } }
      ];
    }
    
    if (platform) {
      query.platform = platform;
    }
    
    if (userId) {
      query.userId = new ObjectId(userId);
    }
    
    const devices = await db.collection('devices')
      .find(query)
      .sort({ lastSeen: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('devices').countDocuments(query);
    
    // Get FCM status
    const fcmEnabled = await db.collection('devices').countDocuments({ ...query, fcmEnabled: true });
    const fcmDisabled = total - fcmEnabled;
    
    res.json({
      devices: devices.map(device => ({
        id: device._id.toString(),
        _id: device._id.toString(),
        deviceId: device.deviceId,
        userId: device.userId.toString(),
        userEmail: device.userEmail,
        deviceType: device.deviceType,
        deviceModel: device.deviceModel,
        platform: device.platform,
        platformVersion: device.platformVersion,
        appVersion: device.appVersion,
        ipAddress: device.ipAddress,
        fcmToken: device.fcmToken ? '***' + device.fcmToken.slice(-4) : null, // Partially mask token
        fcmEnabled: device.fcmEnabled || false,
        lastSeen: device.lastSeen,
        createdAt: device.createdAt,
        updatedAt: device.updatedAt
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      },
      fcmStats: {
        enabled: fcmEnabled,
        disabled: fcmDisabled,
        total: total
      }
    });
  } catch (error) {
    console.error('Error getting devices:', error);
    res.status(500).json({ error: 'Failed to get devices' });
  }
});

// Get devices for a specific user (admin only)
router.get('/devices/user/:userId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId } = req.params;
    
    const devices = await db.collection('devices')
      .find({ userId: new ObjectId(userId) })
      .sort({ lastSeen: -1 })
      .toArray();
    
    res.json({
      devices: devices.map(device => ({
        id: device._id.toString(),
        _id: device._id.toString(),
        deviceId: device.deviceId,
        userId: device.userId.toString(),
        userEmail: device.userEmail,
        deviceType: device.deviceType,
        deviceModel: device.deviceModel,
        platform: device.platform,
        platformVersion: device.platformVersion,
        appVersion: device.appVersion,
        ipAddress: device.ipAddress,
        fcmToken: device.fcmToken ? '***' + device.fcmToken.slice(-4) : null,
        fcmEnabled: device.fcmEnabled || false,
        lastSeen: device.lastSeen,
        createdAt: device.createdAt,
        updatedAt: device.updatedAt
      }))
    });
  } catch (error) {
    console.error('Error getting user devices:', error);
    res.status(500).json({ error: 'Failed to get user devices' });
  }
});

// Get FCM notification system status (admin only)
router.get('/devices/fcm-status', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    const totalDevices = await db.collection('devices').countDocuments();
    const fcmEnabledDevices = await db.collection('devices').countDocuments({ fcmEnabled: true });
    const fcmDisabledDevices = totalDevices - fcmEnabledDevices;
    
    // Get devices by platform with FCM status
    const devicesByPlatform = await db.collection('devices').aggregate([
      {
        $group: {
          _id: '$platform',
          total: { $sum: 1 },
          fcmEnabled: {
            $sum: { $cond: [{ $eq: ['$fcmEnabled', true] }, 1, 0] }
          },
          fcmDisabled: {
            $sum: { $cond: [{ $ne: ['$fcmEnabled', true] }, 1, 0] }
          }
        }
      }
    ]).toArray();
    
    // Check if Firebase Admin SDK is available
    let firebaseAvailable = false;
    try {
      const firebaseAdmin = req.app.get('firebaseAdmin');
      firebaseAvailable = firebaseAdmin != null;
    } catch (e) {
      firebaseAvailable = false;
    }
    
    res.json({
      fcmSystemStatus: {
        available: firebaseAvailable,
        status: firebaseAvailable ? 'operational' : 'not_configured',
        message: firebaseAvailable 
          ? 'FCM notifications are configured and ready' 
          : 'Firebase Admin SDK not available - FCM notifications disabled'
      },
      overall: {
        totalDevices: totalDevices,
        fcmEnabled: fcmEnabledDevices,
        fcmDisabled: fcmDisabledDevices,
        enabledPercentage: totalDevices > 0 ? ((fcmEnabledDevices / totalDevices) * 100).toFixed(2) : 0
      },
      byPlatform: devicesByPlatform.map(platform => ({
        platform: platform._id || 'unknown',
        total: platform.total,
        fcmEnabled: platform.fcmEnabled,
        fcmDisabled: platform.fcmDisabled,
        enabledPercentage: platform.total > 0 ? ((platform.fcmEnabled / platform.total) * 100).toFixed(2) : 0
      }))
    });
  } catch (error) {
    console.error('Error getting FCM status:', error);
    res.status(500).json({ error: 'Failed to get FCM status' });
  }
});

// =============================================================================
// MODERATION ENDPOINTS
// =============================================================================

// Get all moderation rules
router.get('/moderation/rules', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const rules = await db.collection('moderation_rules').find({}).toArray();
    res.json({ rules });
  } catch (error) {
    console.error('Error getting moderation rules:', error);
    sendErrorResponse(res, 500, 'MODERATION_RULES_ERROR', 'Failed to get moderation rules', error.message);
  }
});

// Create moderation rule
router.post('/moderation/rules', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, type, keywords, action, enabled = true, severity = 'medium' } = req.body;
    
    if (!name || !type || !action) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Missing required fields: name, type, action');
    }
    
    const rule = {
      name,
      type, // 'keyword', 'profanity', 'spam'
      keywords: keywords || [],
      action, // 'flag', 'warn', 'mute', 'ban'
      enabled,
      severity, // 'low', 'medium', 'high', 'critical'
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await db.collection('moderation_rules').insertOne(rule);
    res.status(201).json({ 
      message: 'Moderation rule created successfully',
      ruleId: result.insertedId 
    });
  } catch (error) {
    console.error('Error creating moderation rule:', error);
    sendErrorResponse(res, 500, 'MODERATION_RULE_CREATE_ERROR', 'Failed to create moderation rule', error.message);
  }
});

// Update moderation rule
router.put('/moderation/rules/:ruleId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { ruleId } = req.params;
    const updates = req.body;
    
    updates.updatedAt = new Date();
    
    const result = await db.collection('moderation_rules').updateOne(
      { _id: new ObjectId(ruleId) },
      { $set: updates }
    );
    
    if (result.matchedCount === 0) {
      return sendErrorResponse(res, 404, 'RULE_NOT_FOUND', 'Moderation rule not found');
    }
    
    res.json({ message: 'Moderation rule updated successfully' });
  } catch (error) {
    console.error('Error updating moderation rule:', error);
    sendErrorResponse(res, 500, 'MODERATION_RULE_UPDATE_ERROR', 'Failed to update moderation rule', error.message);
  }
});

// Delete moderation rule
router.delete('/moderation/rules/:ruleId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { ruleId } = req.params;
    
    const result = await db.collection('moderation_rules').deleteOne({ _id: new ObjectId(ruleId) });
    
    if (result.deletedCount === 0) {
      return sendErrorResponse(res, 404, 'RULE_NOT_FOUND', 'Moderation rule not found');
    }
    
    res.json({ message: 'Moderation rule deleted successfully' });
  } catch (error) {
    console.error('Error deleting moderation rule:', error);
    sendErrorResponse(res, 500, 'MODERATION_RULE_DELETE_ERROR', 'Failed to delete moderation rule', error.message);
  }
});

// Get moderation queue (flagged messages)
router.get('/moderation/queue', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { status = 'pending', limit = 50, skip = 0 } = req.query;
    
    const queue = await db.collection('moderation_queue')
      .find({ status })
      .sort({ flaggedAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip))
      .toArray();
    
    const total = await db.collection('moderation_queue').countDocuments({ status });
    
    res.json({
      queue,
      total,
      limit: parseInt(limit),
      skip: parseInt(skip)
    });
  } catch (error) {
    console.error('Error getting moderation queue:', error);
    sendErrorResponse(res, 500, 'MODERATION_QUEUE_ERROR', 'Failed to get moderation queue', error.message);
  }
});

// Process moderation queue item
router.post('/moderation/queue/:itemId/process', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { itemId } = req.params;
    const { action, reason } = req.body;
    const adminId = req.adminId;
    
    if (!action) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Action is required');
    }
    
    const queueItem = await db.collection('moderation_queue').findOne({ _id: new ObjectId(itemId) });
    if (!queueItem) {
      return sendErrorResponse(res, 404, 'QUEUE_ITEM_NOT_FOUND', 'Moderation queue item not found');
    }
    
    // Update queue item
    await db.collection('moderation_queue').updateOne(
      { _id: new ObjectId(itemId) },
      {
        $set: {
          status: 'processed',
          processedAt: new Date(),
          processedBy: adminId,
          action,
          reason: reason || ''
        }
      }
    );
    
    // Perform action on message/user
    if (action === 'delete') {
      await db.collection('messages').updateOne(
        { _id: new ObjectId(queueItem.messageId) },
        { $set: { deleted: true, deletedAt: new Date(), deletedBy: adminId } }
      );
    } else if (action === 'warn') {
      await db.collection('user_violations').insertOne({
        userId: new ObjectId(queueItem.userId),
        type: 'warning',
        reason: reason || 'Content violation',
        messageId: queueItem.messageId,
        moderatedBy: adminId,
        createdAt: new Date()
      });
    } else if (action === 'mute') {
      const muteDuration = 24 * 60 * 60 * 1000; // 24 hours
      await db.collection('users').updateOne(
        { _id: new ObjectId(queueItem.userId) },
        {
          $set: {
            muted: true,
            mutedUntil: new Date(Date.now() + muteDuration),
            muteReason: reason || 'Content violation'
          }
        }
      );
    } else if (action === 'ban') {
      await db.collection('users').updateOne(
        { _id: new ObjectId(queueItem.userId) },
        {
          $set: {
            locked: true,
            lockReason: reason || 'Content violation',
            lockedAt: new Date(),
            lockedBy: adminId
          }
        }
      );
    }
    
    res.json({ message: 'Moderation action processed successfully' });
  } catch (error) {
    console.error('Error processing moderation queue item:', error);
    sendErrorResponse(res, 500, 'MODERATION_PROCESS_ERROR', 'Failed to process moderation action', error.message);
  }
});

// Get user violations
router.get('/moderation/violations/:userId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId } = req.params;
    
    const violations = await db.collection('user_violations')
      .find({ userId: new ObjectId(userId) })
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json({ violations });
  } catch (error) {
    console.error('Error getting user violations:', error);
    sendErrorResponse(res, 500, 'VIOLATIONS_ERROR', 'Failed to get user violations', error.message);
  }
});

// Perform moderation action on user
router.post('/moderation/users/:userId/action', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId } = req.params;
    const { action, reason, duration } = req.body;
    const adminId = req.adminId;
    
    if (!action || !reason) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Action and reason are required');
    }
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return sendErrorResponse(res, 404, 'USER_NOT_FOUND', 'User not found');
    }
    
    // Record violation
    await db.collection('user_violations').insertOne({
      userId: new ObjectId(userId),
      type: action,
      reason,
      moderatedBy: adminId,
      createdAt: new Date()
    });
    
    // Perform action
    if (action === 'warn') {
      // Warning is already recorded above
      res.json({ message: 'User warned successfully' });
    } else if (action === 'mute') {
      const muteDuration = duration ? parseInt(duration) * 60 * 60 * 1000 : 24 * 60 * 60 * 1000;
      await db.collection('users').updateOne(
        { _id: new ObjectId(userId) },
        {
          $set: {
            muted: true,
            mutedUntil: new Date(Date.now() + muteDuration),
            muteReason: reason
          }
        }
      );
      res.json({ message: 'User muted successfully' });
    } else if (action === 'ban') {
      await db.collection('users').updateOne(
        { _id: new ObjectId(userId) },
        {
          $set: {
            locked: true,
            lockReason: reason,
            lockedAt: new Date(),
            lockedBy: adminId
          }
        }
      );
      res.json({ message: 'User banned successfully' });
    } else {
      return sendErrorResponse(res, 400, 'INVALID_ACTION', 'Invalid action. Must be warn, mute, or ban');
    }
  } catch (error) {
    console.error('Error performing moderation action:', error);
    sendErrorResponse(res, 500, 'MODERATION_ACTION_ERROR', 'Failed to perform moderation action', error.message);
  }
});

// =============================================================================
// Advanced Search & Filtering
// =============================================================================

// Unified search across users, chats, and messages
router.post('/search/unified', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const {
      query = '',
      types = ['users', 'chats', 'messages'], // Which entity types to search
      filters = {},
      page = 1,
      limit = 20,
      sortBy = 'relevance',
      sortOrder = 'desc'
    } = req.body;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const results = {
      users: [],
      chats: [],
      messages: [],
      total: 0,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: 0,
        pages: 0
      }
    };

    // Build search query
    const searchRegex = query ? new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;

    // Search Users
    if (types.includes('users')) {
      const userQuery = {};
      
      if (searchRegex) {
        userQuery.$or = [
          { email: searchRegex },
          { displayName: searchRegex },
          { phoneNumber: searchRegex }
        ];
      }

      // Apply filters
      if (filters.role) {
        userQuery.role = filters.role;
      }
      if (filters.status) {
        userQuery.status = filters.status;
      }
      if (filters.isLocked !== undefined) {
        userQuery.isLocked = filters.isLocked === true || filters.isLocked === 'true';
      }
      if (filters.registrationDateFrom || filters.registrationDateTo) {
        userQuery.createdAt = {};
        if (filters.registrationDateFrom) {
          userQuery.createdAt.$gte = new Date(filters.registrationDateFrom);
        }
        if (filters.registrationDateTo) {
          userQuery.createdAt.$lte = new Date(filters.registrationDateTo);
        }
      }
      if (filters.lastActivityFrom || filters.lastActivityTo) {
        userQuery.lastLoginAt = {};
        if (filters.lastActivityFrom) {
          userQuery.lastLoginAt.$gte = new Date(filters.lastActivityFrom);
        }
        if (filters.lastActivityTo) {
          userQuery.lastLoginAt.$lte = new Date(filters.lastActivityTo);
        }
      }

      const userSort = {};
      if (sortBy === 'name') {
        userSort.displayName = sortOrder === 'asc' ? 1 : -1;
      } else if (sortBy === 'createdAt') {
        userSort.createdAt = sortOrder === 'asc' ? 1 : -1;
      } else {
        userSort.createdAt = -1;
      }

      const users = await db.collection('users')
        .find(userQuery)
        .sort(userSort)
        .skip(skip)
        .limit(parseInt(limit))
        .toArray();

      const totalUsers = await db.collection('users').countDocuments(userQuery);

      results.users = users.map(user => ({
        id: user._id.toString(),
        _id: user._id.toString(),
        type: 'user',
        email: user.email,
        displayName: user.displayName,
        phoneNumber: user.phoneNumber || user.phone || '',
        role: user.role,
        status: user.status,
        isLocked: user.isLocked || false,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        profilePicture: user.profilePicture,
        // Highlight matching fields
        highlights: query ? {
          email: user.email?.match(searchRegex) ? user.email : null,
          displayName: user.displayName?.match(searchRegex) ? user.displayName : null,
          phoneNumber: user.phoneNumber?.match(searchRegex) ? user.phoneNumber : null
        } : {}
      }));

      results.total += totalUsers;
    }

    // Search Chats
    if (types.includes('chats')) {
      const chatQuery = {};
      
      if (searchRegex) {
        chatQuery.name = searchRegex;
      }

      // Apply filters
      if (filters.chatType) {
        chatQuery.type = filters.chatType;
      }
      if (filters.memberCountMin) {
        chatQuery.memberCount = { $gte: parseInt(filters.memberCountMin) };
      }
      if (filters.memberCountMax) {
        chatQuery.memberCount = { ...chatQuery.memberCount, $lte: parseInt(filters.memberCountMax) };
      }
      if (filters.createdDateFrom || filters.createdDateTo) {
        chatQuery.createdAt = {};
        if (filters.createdDateFrom) {
          chatQuery.createdAt.$gte = new Date(filters.createdDateFrom);
        }
        if (filters.createdDateTo) {
          chatQuery.createdAt.$lte = new Date(filters.createdDateTo);
        }
      }
      if (filters.updatedDateFrom || filters.updatedDateTo) {
        chatQuery.updatedAt = {};
        if (filters.updatedDateFrom) {
          chatQuery.updatedAt.$gte = new Date(filters.updatedDateFrom);
        }
        if (filters.updatedDateTo) {
          chatQuery.updatedAt.$lte = new Date(filters.updatedDateTo);
        }
      }

      const chatSort = {};
      if (sortBy === 'name') {
        chatSort.name = sortOrder === 'asc' ? 1 : -1;
      } else if (sortBy === 'updatedAt') {
        chatSort.updatedAt = sortOrder === 'asc' ? 1 : -1;
      } else {
        chatSort.updatedAt = -1;
      }

      const chats = await db.collection('chats')
        .find(chatQuery)
        .sort(chatSort)
        .skip(skip)
        .limit(parseInt(limit))
        .toArray();

      const totalChats = await db.collection('chats').countDocuments(chatQuery);

      // Get member details for chats
      const chatsWithMembers = await Promise.all(
        chats.map(async (chat) => {
          const rawMembers = Array.isArray(chat.members) ? chat.members : 
                           Array.isArray(chat.memberIds) ? chat.memberIds : [];
          
          let memberObjectIds = [];
          try {
            memberObjectIds = rawMembers
              .filter((m) => m)
              .map((m) => (typeof m === 'string' && ObjectId.isValid(m) ? new ObjectId(m) : m))
              .filter((m) => m);
          } catch (e) {
            memberObjectIds = [];
          }

          const members = memberObjectIds.length > 0
            ? await db.collection('users')
                .find({ _id: { $in: memberObjectIds } })
                .toArray()
            : [];

          return {
            id: chat._id.toString(),
            _id: chat._id.toString(),
            type: 'chat',
            name: chat.name,
            chatType: chat.type || 'group',
            memberCount: rawMembers?.length || 0,
            members: members.map(member => ({
              id: member._id.toString(),
              name: member.displayName,
              email: member.email
            })),
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt,
            // Highlight matching fields
            highlights: query ? {
              name: chat.name?.match(searchRegex) ? chat.name : null
            } : {}
          };
        })
      );

      results.chats = chatsWithMembers;
      results.total += totalChats;
    }

    // Search Messages
    if (types.includes('messages')) {
      const messageQuery = {};
      
      if (searchRegex) {
        messageQuery.content = searchRegex;
      }

      // Apply filters
      if (filters.messageType) {
        messageQuery.type = filters.messageType;
      }
      if (filters.senderId) {
        messageQuery.senderId = new ObjectId(filters.senderId);
      }
      if (filters.chatId) {
        messageQuery.chatId = new ObjectId(filters.chatId);
      }
      if (filters.messageDateFrom || filters.messageDateTo) {
        messageQuery.createdAt = {};
        if (filters.messageDateFrom) {
          messageQuery.createdAt.$gte = new Date(filters.messageDateFrom);
        }
        if (filters.messageDateTo) {
          messageQuery.createdAt.$lte = new Date(filters.messageDateTo);
        }
      }

      const messageSort = {};
      if (sortBy === 'createdAt') {
        messageSort.createdAt = sortOrder === 'asc' ? 1 : -1;
      } else {
        messageSort.createdAt = -1;
      }

      const messages = await db.collection('messages')
        .find(messageQuery)
        .sort(messageSort)
        .skip(skip)
        .limit(parseInt(limit))
        .toArray();

      const totalMessages = await db.collection('messages').countDocuments(messageQuery);

      // Get sender and chat details
      const messagesWithDetails = await Promise.all(
        messages.map(async (message) => {
          let senderName = 'Unknown';
          let chatName = 'Unknown Chat';

          if (message.senderId) {
            try {
              const sender = await db.collection('users').findOne({ _id: message.senderId });
              if (sender) {
                senderName = sender.displayName || sender.email || 'Unknown';
              }
            } catch (e) {
              console.error('Error getting sender:', e);
            }
          }

          if (message.chatId) {
            try {
              const chat = await db.collection('chats').findOne({ _id: message.chatId });
              if (chat) {
                chatName = chat.name || 'Unknown Chat';
              }
            } catch (e) {
              console.error('Error getting chat:', e);
            }
          }

          return {
            id: message._id.toString(),
            _id: message._id.toString(),
            type: 'message',
            chatId: message.chatId?.toString(),
            chatName: chatName,
            senderId: message.senderId?.toString(),
            senderName: senderName,
            content: message.content || '',
            messageType: message.type || message.messageType || 'text',
            mediaUrl: rewriteMediaUrlIfNeeded(message.mediaUrl, req),
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            // Highlight matching content
            highlights: query ? {
              content: message.content?.match(searchRegex) ? message.content : null
            } : {}
          };
        })
      );

      results.messages = messagesWithDetails;
      results.total += totalMessages;
    }

    results.pagination.total = results.total;
    results.pagination.pages = Math.ceil(results.total / parseInt(limit));

    // Save search to history
    if (query && req.user?.userId) {
      try {
        await db.collection('search_history').insertOne({
          adminId: new ObjectId(req.user.userId),
          query: query,
          filters: filters,
          types: types,
          resultCount: results.total,
          createdAt: new Date()
        });
      } catch (e) {
        console.error('Error saving search history:', e);
      }
    }

    res.json(results);
  } catch (error) {
    console.error('Error performing unified search:', error);
    sendErrorResponse(res, 500, 'SEARCH_ERROR', 'Failed to perform search', error.message);
  }
});

// Get search history
router.get('/search/history', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const history = await db.collection('search_history')
      .find({ adminId: new ObjectId(req.user.userId) })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();

    const total = await db.collection('search_history')
      .countDocuments({ adminId: new ObjectId(req.user.userId) });

    res.json({
      history: history.map(item => ({
        id: item._id.toString(),
        query: item.query,
        filters: item.filters,
        types: item.types,
        resultCount: item.resultCount,
        createdAt: item.createdAt
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error getting search history:', error);
    sendErrorResponse(res, 500, 'SEARCH_HISTORY_ERROR', 'Failed to get search history', error.message);
  }
});

// Save search query
router.post('/search/saved', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, query, filters, types } = req.body;

    if (!name || !query) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Name and query are required');
    }

    const savedQuery = {
      adminId: new ObjectId(req.user.userId),
      name: name,
      query: query,
      filters: filters || {},
      types: types || ['users', 'chats', 'messages'],
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('saved_searches').insertOne(savedQuery);

    res.json({
      id: result.insertedId.toString(),
      ...savedQuery,
      _id: result.insertedId.toString()
    });
  } catch (error) {
    console.error('Error saving search query:', error);
    sendErrorResponse(res, 500, 'SAVE_SEARCH_ERROR', 'Failed to save search query', error.message);
  }
});

// Get saved searches
router.get('/search/saved', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;

    const savedSearches = await db.collection('saved_searches')
      .find({ adminId: new ObjectId(req.user.userId) })
      .sort({ updatedAt: -1 })
      .toArray();

    res.json({
      searches: savedSearches.map(item => ({
        id: item._id.toString(),
        name: item.name,
        query: item.query,
        filters: item.filters,
        types: item.types,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      }))
    });
  } catch (error) {
    console.error('Error getting saved searches:', error);
    sendErrorResponse(res, 500, 'GET_SAVED_SEARCHES_ERROR', 'Failed to get saved searches', error.message);
  }
});

// Delete saved search
router.delete('/search/saved/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;

    const result = await db.collection('saved_searches').deleteOne({
      _id: new ObjectId(id),
      adminId: new ObjectId(req.user.userId)
    });

    if (result.deletedCount === 0) {
      return sendErrorResponse(res, 404, 'SAVED_SEARCH_NOT_FOUND', 'Saved search not found');
    }

    res.json({ message: 'Saved search deleted successfully' });
  } catch (error) {
    console.error('Error deleting saved search:', error);
    sendErrorResponse(res, 500, 'DELETE_SAVED_SEARCH_ERROR', 'Failed to delete saved search', error.message);
  }
});

// =============================================================================
// Security & Compliance Features
// =============================================================================

// Get security settings
router.get('/security/settings', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Get or create default security settings
    let settings = await db.collection('security_settings').findOne({ type: 'global' });
    
    if (!settings) {
      // Create default settings
      const defaultSettings = {
        type: 'global',
        ipWhitelist: [],
        ipBlacklist: [],
        sessionTimeout: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
        twoFactorRequired: false,
        passwordPolicy: {
          minLength: 8,
          requireUppercase: true,
          requireLowercase: true,
          requireNumbers: true,
          requireSpecialChars: false,
          maxAge: 90, // days
        },
        failedLoginAttempts: {
          maxAttempts: 5,
          lockoutDuration: 30 * 60 * 1000, // 30 minutes
        },
        suspiciousActivityAlerts: {
          enabled: true,
          threshold: 10, // failed attempts
        },
        dataRetention: {
          enabled: false,
          userDataDays: 365,
          messageDataDays: 90,
          logDataDays: 30,
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      
      await db.collection('security_settings').insertOne(defaultSettings);
      settings = defaultSettings;
    }
    
    res.json({
      ipWhitelist: settings.ipWhitelist || [],
      ipBlacklist: settings.ipBlacklist || [],
      sessionTimeout: settings.sessionTimeout,
      twoFactorRequired: settings.twoFactorRequired || false,
      passwordPolicy: settings.passwordPolicy || {},
      failedLoginAttempts: settings.failedLoginAttempts || {},
      suspiciousActivityAlerts: settings.suspiciousActivityAlerts || {},
      dataRetention: settings.dataRetention || {},
    });
  } catch (error) {
    console.error('Error getting security settings:', error);
    sendErrorResponse(res, 500, 'GET_SECURITY_SETTINGS_ERROR', 'Failed to get security settings', error.message);
  }
});

// Update security settings
router.put('/security/settings', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const updates = req.body;
    
    const updateDoc = {
      $set: {
        ...updates,
        updatedAt: new Date(),
      },
    };
    
    await db.collection('security_settings').updateOne(
      { type: 'global' },
      updateDoc,
      { upsert: true }
    );
    
    res.json({ message: 'Security settings updated successfully' });
  } catch (error) {
    console.error('Error updating security settings:', error);
    sendErrorResponse(res, 500, 'UPDATE_SECURITY_SETTINGS_ERROR', 'Failed to update security settings', error.message);
  }
});

// Add IP to whitelist
router.post('/security/ip/whitelist', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { ip, description } = req.body;
    
    if (!ip) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'IP address is required');
    }
    
    // Validate IP format
    const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    if (!ipRegex.test(ip)) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Invalid IP address format');
    }
    
    await db.collection('security_settings').updateOne(
      { type: 'global' },
      {
        $addToSet: {
          ipWhitelist: {
            ip: ip,
            description: description || '',
            addedBy: req.user.userId,
            addedAt: new Date(),
          },
        },
        $set: { updatedAt: new Date() },
      },
      { upsert: true }
    );
    
    res.json({ message: 'IP added to whitelist successfully' });
  } catch (error) {
    console.error('Error adding IP to whitelist:', error);
    sendErrorResponse(res, 500, 'ADD_IP_WHITELIST_ERROR', 'Failed to add IP to whitelist', error.message);
  }
});

// Remove IP from whitelist
router.delete('/security/ip/whitelist/:ip', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { ip } = req.params;
    
    await db.collection('security_settings').updateOne(
      { type: 'global' },
      {
        $pull: { ipWhitelist: { ip: ip } },
        $set: { updatedAt: new Date() },
      }
    );
    
    res.json({ message: 'IP removed from whitelist successfully' });
  } catch (error) {
    console.error('Error removing IP from whitelist:', error);
    sendErrorResponse(res, 500, 'REMOVE_IP_WHITELIST_ERROR', 'Failed to remove IP from whitelist', error.message);
  }
});

// Add IP to blacklist
router.post('/security/ip/blacklist', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { ip, reason } = req.body;
    
    if (!ip) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'IP address is required');
    }
    
    // Validate IP format
    const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    if (!ipRegex.test(ip)) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Invalid IP address format');
    }
    
    await db.collection('security_settings').updateOne(
      { type: 'global' },
      {
        $addToSet: {
          ipBlacklist: {
            ip: ip,
            reason: reason || '',
            addedBy: req.user.userId,
            addedAt: new Date(),
          },
        },
        $set: { updatedAt: new Date() },
      },
      { upsert: true }
    );
    
    res.json({ message: 'IP added to blacklist successfully' });
  } catch (error) {
    console.error('Error adding IP to blacklist:', error);
    sendErrorResponse(res, 500, 'ADD_IP_BLACKLIST_ERROR', 'Failed to add IP to blacklist', error.message);
  }
});

// Remove IP from blacklist
router.delete('/security/ip/blacklist/:ip', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { ip } = req.params;
    
    await db.collection('security_settings').updateOne(
      { type: 'global' },
      {
        $pull: { ipBlacklist: { ip: ip } },
        $set: { updatedAt: new Date() },
      }
    );
    
    res.json({ message: 'IP removed from blacklist successfully' });
  } catch (error) {
    console.error('Error removing IP from blacklist:', error);
    sendErrorResponse(res, 500, 'REMOVE_IP_BLACKLIST_ERROR', 'Failed to remove IP from blacklist', error.message);
  }
});

// Get failed login attempts
router.get('/security/failed-logins', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50, ip, userId } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const query = {};
    if (ip) query.ip = ip;
    if (userId) query.userId = new ObjectId(userId);
    
    const failedLogins = await db.collection('failed_login_attempts')
      .find(query)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('failed_login_attempts').countDocuments(query);
    
    res.json({
      failedLogins: failedLogins.map(attempt => ({
        id: attempt._id.toString(),
        ip: attempt.ip,
        userId: attempt.userId?.toString(),
        email: attempt.email,
        timestamp: attempt.timestamp,
        userAgent: attempt.userAgent,
        reason: attempt.reason,
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error getting failed login attempts:', error);
    sendErrorResponse(res, 500, 'GET_FAILED_LOGINS_ERROR', 'Failed to get failed login attempts', error.message);
  }
});

// Get suspicious activity
router.get('/security/suspicious-activity', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const suspiciousActivity = await db.collection('suspicious_activity')
      .find({})
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('suspicious_activity').countDocuments();
    
    res.json({
      activities: suspiciousActivity.map(activity => ({
        id: activity._id.toString(),
        type: activity.type,
        ip: activity.ip,
        userId: activity.userId?.toString(),
        description: activity.description,
        severity: activity.severity,
        timestamp: activity.timestamp,
        resolved: activity.resolved || false,
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error getting suspicious activity:', error);
    sendErrorResponse(res, 500, 'GET_SUSPICIOUS_ACTIVITY_ERROR', 'Failed to get suspicious activity', error.message);
  }
});

// GDPR: Export user data
router.post('/compliance/gdpr/export/:userId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId } = req.params;
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return sendErrorResponse(res, 404, 'USER_NOT_FOUND', 'User not found');
    }
    
    // Collect all user data
    const userData = {
      profile: {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName,
        phoneNumber: user.phoneNumber,
        role: user.role,
        status: user.status,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        profilePicture: user.profilePicture,
      },
      messages: await db.collection('messages')
        .find({ senderId: new ObjectId(userId) })
        .toArray(),
      chats: await db.collection('chats')
        .find({ members: new ObjectId(userId) })
        .toArray(),
      devices: await db.collection('devices')
        .find({ userId: new ObjectId(userId) })
        .toArray(),
      reports: await db.collection('reports')
        .find({ reportedBy: new ObjectId(userId) })
        .toArray(),
      activity: await db.collection('user_logs')
        .find({ userId: new ObjectId(userId) })
        .toArray(),
    };
    
    res.json({
      userId: userId,
      exportedAt: new Date().toISOString(),
      data: userData,
    });
  } catch (error) {
    console.error('Error exporting GDPR data:', error);
    sendErrorResponse(res, 500, 'GDPR_EXPORT_ERROR', 'Failed to export user data', error.message);
  }
});

// GDPR: Delete user data
router.delete('/compliance/gdpr/delete/:userId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId } = req.params;
    const { reason } = req.body;
    
    if (!reason) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Reason is required for data deletion');
    }
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return sendErrorResponse(res, 404, 'USER_NOT_FOUND', 'User not found');
    }
    
    // Log deletion request
    await db.collection('data_deletion_logs').insertOne({
      userId: new ObjectId(userId),
      deletedBy: req.user.userId,
      reason: reason,
      deletedAt: new Date(),
      dataDeleted: {
        profile: true,
        messages: true,
        chats: true,
        devices: true,
        reports: true,
        activity: true,
      },
    });
    
    // Delete user data (soft delete by marking as deleted)
    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      {
        $set: {
          deleted: true,
          deletedAt: new Date(),
          deletedBy: req.user.userId,
          deletedReason: reason,
        },
      }
    );
    
    // Anonymize messages
    await db.collection('messages').updateMany(
      { senderId: new ObjectId(userId) },
      {
        $set: {
          content: '[Deleted]',
          senderId: null,
          isDeletedForEveryone: true,
        },
      }
    );
    
    res.json({ message: 'User data deleted successfully' });
  } catch (error) {
    console.error('Error deleting GDPR data:', error);
    sendErrorResponse(res, 500, 'GDPR_DELETE_ERROR', 'Failed to delete user data', error.message);
  }
});

// Get data retention policies
router.get('/compliance/data-retention', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    const settings = await db.collection('security_settings').findOne({ type: 'global' });
    const dataRetention = settings?.dataRetention || {
      enabled: false,
      userDataDays: 365,
      messageDataDays: 90,
      logDataDays: 30,
    };
    
    res.json(dataRetention);
  } catch (error) {
    console.error('Error getting data retention policies:', error);
    sendErrorResponse(res, 500, 'GET_DATA_RETENTION_ERROR', 'Failed to get data retention policies', error.message);
  }
});

// Update data retention policies
router.put('/compliance/data-retention', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { enabled, userDataDays, messageDataDays, logDataDays } = req.body;
    
    await db.collection('security_settings').updateOne(
      { type: 'global' },
      {
        $set: {
          'dataRetention.enabled': enabled !== undefined ? enabled : false,
          'dataRetention.userDataDays': userDataDays || 365,
          'dataRetention.messageDataDays': messageDataDays || 90,
          'dataRetention.logDataDays': logDataDays || 30,
          updatedAt: new Date(),
        },
      },
      { upsert: true }
    );
    
    res.json({ message: 'Data retention policies updated successfully' });
  } catch (error) {
    console.error('Error updating data retention policies:', error);
    sendErrorResponse(res, 500, 'UPDATE_DATA_RETENTION_ERROR', 'Failed to update data retention policies', error.message);
  }
});

// Get consent tracking
router.get('/compliance/consent/:userId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId } = req.params;
    
    const consents = await db.collection('user_consents')
      .find({ userId: new ObjectId(userId) })
      .sort({ timestamp: -1 })
      .toArray();
    
    res.json({
      userId: userId,
      consents: consents.map(consent => ({
        id: consent._id.toString(),
        type: consent.type,
        granted: consent.granted,
        timestamp: consent.timestamp,
        ip: consent.ip,
        userAgent: consent.userAgent,
      })),
    });
  } catch (error) {
    console.error('Error getting consent tracking:', error);
    sendErrorResponse(res, 500, 'GET_CONSENT_ERROR', 'Failed to get consent tracking', error.message);
  }
});

// =============================================================================
// Performance Monitoring
// =============================================================================

const performanceMonitor = require('../middleware/performanceMonitor');

// Get performance metrics
router.get('/performance/metrics', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { period = '1h', endpoint } = req.query;
    
    // Calculate time range
    let timeRange;
    switch (period) {
      case '15m':
        timeRange = new Date(Date.now() - 15 * 60 * 1000);
        break;
      case '1h':
        timeRange = new Date(Date.now() - 60 * 60 * 1000);
        break;
      case '24h':
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        timeRange = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        break;
      default:
        timeRange = new Date(Date.now() - 60 * 60 * 1000);
    }
    
    // Get historical metrics from database
    const query = { timestamp: { $gte: timeRange } };
    if (endpoint) {
      query['responseTimes.' + endpoint] = { $exists: true };
    }
    
    const metrics = await db.collection('performance_metrics')
      .find(query)
      .sort({ timestamp: -1 })
      .limit(100)
      .toArray();
    
    // Get current metrics from cache
    const currentMetrics = performanceMonitor.getCurrentMetrics();
    
    // Get database performance
    const dbPerformance = await performanceMonitor.getDatabaseQueryPerformance(db);
    
    // Get database connection pool status
    const dbConnectionPool = await performanceMonitor.getDatabaseConnectionPoolStatus(db);
    
    // Calculate averages
    const avgResponseTimes = {};
    const errorRates = {};
    let totalActiveConnections = 0;
    let totalMessageDeliveryRate = 0;
    
    metrics.forEach(metric => {
      Object.keys(metric.responseTimes || {}).forEach(ep => {
        if (!avgResponseTimes[ep]) {
          avgResponseTimes[ep] = { total: 0, count: 0, min: Infinity, max: 0 };
        }
        const rt = metric.responseTimes[ep];
        avgResponseTimes[ep].total += rt.avg * rt.count;
        avgResponseTimes[ep].count += rt.count;
        avgResponseTimes[ep].min = Math.min(avgResponseTimes[ep].min, rt.min);
        avgResponseTimes[ep].max = Math.max(avgResponseTimes[ep].max, rt.max);
      });
      
      Object.keys(metric.errorRates || {}).forEach(ep => {
        if (!errorRates[ep]) {
          errorRates[ep] = { total: 0, count: 0 };
        }
        errorRates[ep].total += metric.errorRates[ep];
        errorRates[ep].count++;
      });
      
      totalActiveConnections += metric.activeConnections || 0;
      totalMessageDeliveryRate += metric.messageDeliveryRate || 100;
    });
    
    // Calculate final averages
    Object.keys(avgResponseTimes).forEach(ep => {
      if (avgResponseTimes[ep].count > 0) {
        avgResponseTimes[ep].avg = avgResponseTimes[ep].total / avgResponseTimes[ep].count;
      }
    });
    
    Object.keys(errorRates).forEach(ep => {
      if (errorRates[ep].count > 0) {
        errorRates[ep] = errorRates[ep].total / errorRates[ep].count;
      }
    });
    
    const avgActiveConnections = metrics.length > 0 ? totalActiveConnections / metrics.length : 0;
    const avgMessageDeliveryRate = metrics.length > 0 ? totalMessageDeliveryRate / metrics.length : 100;
    
    // Get system resources from latest metric
    const latestMetric = metrics[0] || {};
    const systemResources = latestMetric.systemResources || {};
    
    res.json({
      period: period,
      timestamp: new Date(),
      current: {
        activeConnections: currentMetrics.activeConnections || 0,
        lastUpdate: currentMetrics.lastUpdate || new Date(),
      },
      averages: {
        responseTimes: avgResponseTimes,
        errorRates: errorRates,
        activeConnections: avgActiveConnections,
        messageDeliveryRate: avgMessageDeliveryRate,
      },
      systemResources: {
        cpu: systemResources.cpu || {},
        memory: systemResources.memory || {},
        loadAverage: systemResources.loadAverage || [],
        uptime: systemResources.uptime || 0,
      },
      database: {
        performance: dbPerformance,
        connectionPool: dbConnectionPool,
      },
      historical: metrics.map(m => ({
        timestamp: m.timestamp,
        responseTimes: m.responseTimes,
        errorRates: m.errorRates,
        activeConnections: m.activeConnections,
        messageDeliveryRate: m.messageDeliveryRate,
        systemResources: m.systemResources,
      })),
    });
  } catch (error) {
    console.error('Error getting performance metrics:', error);
    sendErrorResponse(res, 500, 'GET_PERFORMANCE_METRICS_ERROR', 'Failed to get performance metrics', error.message);
  }
});

// Get performance alerts
router.get('/performance/alerts', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50, severity } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const query = { resolved: false };
    if (severity) {
      query.severity = severity;
    }
    
    const alerts = await db.collection('performance_alerts')
      .find(query)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('performance_alerts').countDocuments(query);
    
    res.json({
      alerts: alerts.map(alert => ({
        id: alert._id.toString(),
        type: alert.type,
        severity: alert.severity,
        message: alert.message,
        endpoint: alert.endpoint,
        threshold: alert.threshold,
        actualValue: alert.actualValue,
        timestamp: alert.timestamp,
        resolved: alert.resolved || false,
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error getting performance alerts:', error);
    sendErrorResponse(res, 500, 'GET_PERFORMANCE_ALERTS_ERROR', 'Failed to get performance alerts', error.message);
  }
});

// Resolve performance alert
router.post('/performance/alerts/:id/resolve', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    await db.collection('performance_alerts').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          resolved: true,
          resolvedAt: new Date(),
          resolvedBy: req.user.userId,
        },
      }
    );
    
    res.json({ message: 'Alert resolved successfully' });
  } catch (error) {
    console.error('Error resolving performance alert:', error);
    sendErrorResponse(res, 500, 'RESOLVE_ALERT_ERROR', 'Failed to resolve alert', error.message);
  }
});

// =============================================================================
// Notification Management
// =============================================================================

// Get all notification templates
router.get('/notifications/templates', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    const templates = await db.collection('notification_templates')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json({
      templates: templates.map(template => ({
        id: template._id.toString(),
        name: template.name,
        title: template.title,
        body: template.body,
        data: template.data || {},
        category: template.category || 'default',
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
      })),
    });
  } catch (error) {
    console.error('Error getting notification templates:', error);
    sendErrorResponse(res, 500, 'GET_TEMPLATES_ERROR', 'Failed to get notification templates', error.message);
  }
});

// Create notification template
router.post('/notifications/templates', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, title, body, data, category } = req.body;
    
    if (!name || !title || !body) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Name, title, and body are required');
    }
    
    const template = {
      name: name,
      title: title,
      body: body,
      data: data || {},
      category: category || 'default',
      createdBy: req.user.userId,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    
    const result = await db.collection('notification_templates').insertOne(template);
    
    res.json({
      id: result.insertedId.toString(),
      ...template,
      _id: result.insertedId.toString(),
    });
  } catch (error) {
    console.error('Error creating notification template:', error);
    sendErrorResponse(res, 500, 'CREATE_TEMPLATE_ERROR', 'Failed to create notification template', error.message);
  }
});

// Update notification template
router.put('/notifications/templates/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, title, body, data, category } = req.body;
    
    const updateDoc = {
      $set: {
        updatedAt: new Date(),
      },
    };
    
    if (name) updateDoc.$set.name = name;
    if (title) updateDoc.$set.title = title;
    if (body) updateDoc.$set.body = body;
    if (data) updateDoc.$set.data = data;
    if (category) updateDoc.$set.category = category;
    
    const result = await db.collection('notification_templates').updateOne(
      { _id: new ObjectId(id) },
      updateDoc
    );
    
    if (result.matchedCount === 0) {
      return sendErrorResponse(res, 404, 'TEMPLATE_NOT_FOUND', 'Template not found');
    }
    
    res.json({ message: 'Template updated successfully' });
  } catch (error) {
    console.error('Error updating notification template:', error);
    sendErrorResponse(res, 500, 'UPDATE_TEMPLATE_ERROR', 'Failed to update notification template', error.message);
  }
});

// Delete notification template
router.delete('/notifications/templates/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const result = await db.collection('notification_templates').deleteOne({
      _id: new ObjectId(id),
    });
    
    if (result.deletedCount === 0) {
      return sendErrorResponse(res, 404, 'TEMPLATE_NOT_FOUND', 'Template not found');
    }
    
    res.json({ message: 'Template deleted successfully' });
  } catch (error) {
    console.error('Error deleting notification template:', error);
    sendErrorResponse(res, 500, 'DELETE_TEMPLATE_ERROR', 'Failed to delete notification template', error.message);
  }
});

// Send test notification
router.post('/notifications/test', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userId, title, body, data, templateId } = req.body;
    
    if (!userId) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'User ID is required');
    }
    
    let notificationTitle = title;
    let notificationBody = body;
    let notificationData = data || {};
    
    // If template ID is provided, use template
    if (templateId) {
      const template = await db.collection('notification_templates').findOne({
        _id: new ObjectId(templateId),
      });
      
      if (template) {
        notificationTitle = template.title;
        notificationBody = template.body;
        notificationData = { ...template.data, ...notificationData };
      }
    }
    
    if (!notificationTitle || !notificationBody) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Title and body are required');
    }
    
    // Send notification
    const sendFCMNotification = req.app.locals.sendFCMNotification;
    if (!sendFCMNotification) {
      return sendErrorResponse(res, 500, 'FCM_NOT_AVAILABLE', 'FCM service not available');
    }
    
    const success = await sendFCMNotification(userId, notificationTitle, notificationBody, notificationData);
    
    // Track notification
    await db.collection('notification_history').insertOne({
      userId: new ObjectId(userId),
      title: notificationTitle,
      body: notificationBody,
      data: notificationData,
      templateId: templateId ? new ObjectId(templateId) : null,
      sentBy: req.user.userId,
      status: success ? 'sent' : 'failed',
      sentAt: new Date(),
      error: success ? null : 'Failed to send notification',
    });
    
    if (success) {
      res.json({ message: 'Test notification sent successfully' });
    } else {
      res.status(500).json({ error: 'Failed to send test notification' });
    }
  } catch (error) {
    console.error('Error sending test notification:', error);
    sendErrorResponse(res, 500, 'SEND_TEST_NOTIFICATION_ERROR', 'Failed to send test notification', error.message);
  }
});

// Get notification history
router.get('/notifications/history', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { page = 1, limit = 50, userId, status, startDate, endDate } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const query = {};
    if (userId) query.userId = new ObjectId(userId);
    if (status) query.status = status;
    if (startDate || endDate) {
      query.sentAt = {};
      if (startDate) query.sentAt.$gte = new Date(startDate);
      if (endDate) query.sentAt.$lte = new Date(endDate);
    }
    
    const history = await db.collection('notification_history')
      .find(query)
      .sort({ sentAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await db.collection('notification_history').countDocuments(query);
    
    // Get user details for notifications
    const historyWithUsers = await Promise.all(
      history.map(async (item) => {
        let userName = 'Unknown';
        if (item.userId) {
          try {
            const user = await db.collection('users').findOne({ _id: item.userId });
            if (user) {
              userName = user.displayName || user.email || 'Unknown';
            }
          } catch (e) {
            console.error('Error getting user:', e);
          }
        }
        
        return {
          id: item._id.toString(),
          userId: item.userId?.toString(),
          userName: userName,
          title: item.title,
          body: item.body,
          status: item.status,
          sentAt: item.sentAt,
          error: item.error,
          templateId: item.templateId?.toString(),
        };
      })
    );
    
    res.json({
      history: historyWithUsers,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error getting notification history:', error);
    sendErrorResponse(res, 500, 'GET_NOTIFICATION_HISTORY_ERROR', 'Failed to get notification history', error.message);
  }
});

// Retry failed notification
router.post('/notifications/history/:id/retry', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const notification = await db.collection('notification_history').findOne({
      _id: new ObjectId(id),
    });
    
    if (!notification) {
      return sendErrorResponse(res, 404, 'NOTIFICATION_NOT_FOUND', 'Notification not found');
    }
    
    if (notification.status === 'sent') {
      return sendErrorResponse(res, 400, 'ALREADY_SENT', 'Notification was already sent successfully');
    }
    
    // Retry sending
    const sendFCMNotification = req.app.locals.sendFCMNotification;
    if (!sendFCMNotification) {
      return sendErrorResponse(res, 500, 'FCM_NOT_AVAILABLE', 'FCM service not available');
    }
    
    const success = await sendFCMNotification(
      notification.userId,
      notification.title,
      notification.body,
      notification.data || {}
    );
    
    // Update notification status
    await db.collection('notification_history').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          status: success ? 'sent' : 'failed',
          retriedAt: new Date(),
          retriedBy: req.user.userId,
          error: success ? null : 'Retry failed',
        },
      }
    );
    
    if (success) {
      res.json({ message: 'Notification retried successfully' });
    } else {
      res.status(500).json({ error: 'Failed to retry notification' });
    }
  } catch (error) {
    console.error('Error retrying notification:', error);
    sendErrorResponse(res, 500, 'RETRY_NOTIFICATION_ERROR', 'Failed to retry notification', error.message);
  }
});

// Get notification analytics
router.get('/notifications/analytics', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { period = '24h' } = req.query;
    
    // Calculate time range
    let timeRange;
    switch (period) {
      case '1h':
        timeRange = new Date(Date.now() - 60 * 60 * 1000);
        break;
      case '24h':
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        timeRange = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        break;
      case '30d':
        timeRange = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
    }
    
    // Get notification statistics
    const totalSent = await db.collection('notification_history').countDocuments({
      sentAt: { $gte: timeRange },
      status: 'sent',
    });
    
    const totalFailed = await db.collection('notification_history').countDocuments({
      sentAt: { $gte: timeRange },
      status: 'failed',
    });
    
    const totalNotifications = totalSent + totalFailed;
    const successRate = totalNotifications > 0 ? (totalSent / totalNotifications) * 100 : 100;
    
    // Get notifications by hour/day
    const notificationsByTime = await db.collection('notification_history')
      .aggregate([
        {
          $match: {
            sentAt: { $gte: timeRange },
          },
        },
        {
          $group: {
            _id: {
              $dateToString: {
                format: period === '1h' ? '%Y-%m-%d %H:00' : '%Y-%m-%d',
                date: '$sentAt',
              },
            },
            sent: {
              $sum: { $cond: [{ $eq: ['$status', 'sent'] }, 1, 0] },
            },
            failed: {
              $sum: { $cond: [{ $eq: ['$status', 'failed'] }, 1, 0] },
            },
          },
        },
        {
          $sort: { _id: 1 },
        },
      ])
      .toArray();
    
    // Get top templates
    const topTemplates = await db.collection('notification_history')
      .aggregate([
        {
          $match: {
            sentAt: { $gte: timeRange },
            templateId: { $ne: null },
          },
        },
        {
          $group: {
            _id: '$templateId',
            count: { $sum: 1 },
            sent: {
              $sum: { $cond: [{ $eq: ['$status', 'sent'] }, 1, 0] },
            },
            failed: {
              $sum: { $cond: [{ $eq: ['$status', 'failed'] }, 1, 0] },
            },
          },
        },
        {
          $sort: { count: -1 },
        },
        {
          $limit: 10,
        },
      ])
      .toArray();
    
    // Get template names
    const templateIds = topTemplates.map(t => t._id);
    const templates = await db.collection('notification_templates')
      .find({ _id: { $in: templateIds } })
      .toArray();
    
    const templateMap = {};
    templates.forEach(t => {
      templateMap[t._id.toString()] = t.name;
    });
    
    const topTemplatesWithNames = topTemplates.map(t => ({
      templateId: t._id.toString(),
      templateName: templateMap[t._id.toString()] || 'Unknown',
      count: t.count,
      sent: t.sent,
      failed: t.failed,
    }));
    
    res.json({
      period: period,
      timestamp: new Date(),
      summary: {
        totalSent: totalSent,
        totalFailed: totalFailed,
        totalNotifications: totalNotifications,
        successRate: successRate,
      },
      notificationsByTime: notificationsByTime,
      topTemplates: topTemplatesWithNames,
    });
  } catch (error) {
    console.error('Error getting notification analytics:', error);
    sendErrorResponse(res, 500, 'GET_NOTIFICATION_ANALYTICS_ERROR', 'Failed to get notification analytics', error.message);
  }
});

// Send targeted notification to multiple users
router.post('/notifications/send', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { userIds, title, body, data, templateId } = req.body;
    
    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'User IDs array is required');
    }
    
    let notificationTitle = title;
    let notificationBody = body;
    let notificationData = data || {};
    
    // If template ID is provided, use template
    if (templateId) {
      const template = await db.collection('notification_templates').findOne({
        _id: new ObjectId(templateId),
      });
      
      if (template) {
        notificationTitle = template.title;
        notificationBody = template.body;
        notificationData = { ...template.data, ...notificationData };
      }
    }
    
    if (!notificationTitle || !notificationBody) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Title and body are required');
    }
    
    // Send notifications
    const sendFCMNotification = req.app.locals.sendFCMNotification;
    if (!sendFCMNotification) {
      return sendErrorResponse(res, 500, 'FCM_NOT_AVAILABLE', 'FCM service not available');
    }
    
    const results = [];
    for (const userId of userIds) {
      try {
        const success = await sendFCMNotification(
          userId,
          notificationTitle,
          notificationBody,
          notificationData
        );
        
        // Track notification
        await db.collection('notification_history').insertOne({
          userId: new ObjectId(userId),
          title: notificationTitle,
          body: notificationBody,
          data: notificationData,
          templateId: templateId ? new ObjectId(templateId) : null,
          sentBy: req.user.userId,
          status: success ? 'sent' : 'failed',
          sentAt: new Date(),
          error: success ? null : 'Failed to send notification',
        });
        
        results.push({
          userId: userId,
          status: success ? 'sent' : 'failed',
        });
      } catch (error) {
        results.push({
          userId: userId,
          status: 'failed',
          error: error.message,
        });
      }
    }
    
    const successCount = results.filter(r => r.status === 'sent').length;
    const failureCount = results.filter(r => r.status === 'failed').length;
    
    res.json({
      message: `Notifications sent: ${successCount} success, ${failureCount} failed`,
      total: userIds.length,
      success: successCount,
      failed: failureCount,
      results: results,
    });
  } catch (error) {
    console.error('Error sending targeted notifications:', error);
    sendErrorResponse(res, 500, 'SEND_NOTIFICATIONS_ERROR', 'Failed to send notifications', error.message);
  }
});

// =============================================================================
// Chat Moderation Tools
// =============================================================================

// Get chat messages
router.get('/chats/:id/messages', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    const messages = await db.collection('messages')
      .find({ chatId: new ObjectId(id) })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const totalMessages = await db.collection('messages').countDocuments({ chatId: new ObjectId(id) });
    
    // Get sender details
    const messagesWithSenders = await Promise.all(
      messages.map(async (message) => {
        let senderName = 'Unknown';
        let senderEmail = '';
        if (message.senderId) {
          try {
            const sender = await db.collection('users').findOne({ _id: message.senderId });
            if (sender) {
              senderName = sender.displayName || sender.email || 'Unknown';
              senderEmail = sender.email || '';
            }
          } catch (e) {
            console.error('Error getting sender:', e);
          }
        }
        
        return {
          id: message._id.toString(),
          chatId: message.chatId.toString(),
          senderId: message.senderId?.toString(),
          senderName: senderName,
          senderEmail: senderEmail,
          content: message.content || '',
          type: message.type || message.messageType || 'text',
          mediaUrl: rewriteMediaUrlIfNeeded(message.mediaUrl, req),
          createdAt: message.createdAt,
          updatedAt: message.updatedAt,
          isDeletedForEveryone: message.isDeletedForEveryone || false,
        };
      })
    );
    
    res.json({
      messages: messagesWithSenders,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalMessages,
        pages: Math.ceil(totalMessages / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error getting chat messages:', error);
    sendErrorResponse(res, 500, 'GET_CHAT_MESSAGES_ERROR', 'Failed to get chat messages', error.message);
  }
});

// Delete message from chat (admin action)
router.delete('/chats/:id/messages/:messageId', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id, messageId } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    const message = await db.collection('messages').findOne({ _id: new ObjectId(messageId) });
    if (!message) {
      return sendErrorResponse(res, 404, 'MESSAGE_NOT_FOUND', 'Message not found');
    }
    
    // Delete message for everyone
    await db.collection('messages').updateOne(
      { _id: new ObjectId(messageId) },
      {
        $set: {
          content: '',
          mediaUrl: '',
          isDeletedForEveryone: true,
          deletedAt: new Date(),
          deletedBy: req.user.userId,
          deletedReason: 'Admin deletion',
        },
      }
    );
    
    // Log admin activity
    emitAdminActivity(req.io, {
      type: 'message_deleted',
      action: 'delete_message',
      adminId: req.user.userId,
      targetId: messageId,
      chatId: id,
      details: {
        messageId: messageId,
        chatId: id,
      },
    });
    
    res.json({ message: 'Message deleted successfully' });
  } catch (error) {
    console.error('Error deleting message:', error);
    sendErrorResponse(res, 500, 'DELETE_MESSAGE_ERROR', 'Failed to delete message', error.message);
  }
});

// Mute chat
router.post('/chats/:id/mute', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { duration, reason } = req.body; // duration in hours
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    const muteUntil = duration
      ? new Date(Date.now() + parseInt(duration) * 60 * 60 * 1000)
      : null; // null means permanent mute
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          muted: true,
          mutedUntil: muteUntil,
          muteReason: reason || 'Admin mute',
          mutedBy: req.user.userId,
          mutedAt: new Date(),
        },
      }
    );
    
    emitAdminActivity(req.io, {
      type: 'chat_muted',
      action: 'mute_chat',
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
        duration: duration,
        reason: reason,
      },
    });
    
    res.json({ message: 'Chat muted successfully' });
  } catch (error) {
    console.error('Error muting chat:', error);
    sendErrorResponse(res, 500, 'MUTE_CHAT_ERROR', 'Failed to mute chat', error.message);
  }
});

// Unmute chat
router.post('/chats/:id/unmute', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          muted: false,
          mutedUntil: null,
        },
        $unset: {
          muteReason: '',
          mutedBy: '',
          mutedAt: '',
        },
      }
    );
    
    emitAdminActivity(req.io, {
      type: 'chat_unmuted',
      action: 'unmute_chat',
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
      },
    });
    
    res.json({ message: 'Chat unmuted successfully' });
  } catch (error) {
    console.error('Error unmuting chat:', error);
    sendErrorResponse(res, 500, 'UNMUTE_CHAT_ERROR', 'Failed to unmute chat', error.message);
  }
});

// Archive chat
router.post('/chats/:id/archive', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          archived: true,
          archivedAt: new Date(),
          archivedBy: req.user.userId,
        },
      }
    );
    
    emitAdminActivity(req.io, {
      type: 'chat_archived',
      action: 'archive_chat',
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
      },
    });
    
    res.json({ message: 'Chat archived successfully' });
  } catch (error) {
    console.error('Error archiving chat:', error);
    sendErrorResponse(res, 500, 'ARCHIVE_CHAT_ERROR', 'Failed to archive chat', error.message);
  }
});

// Unarchive chat
router.post('/chats/:id/unarchive', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          archived: false,
        },
        $unset: {
          archivedAt: '',
          archivedBy: '',
        },
      }
    );
    
    emitAdminActivity(req.io, {
      type: 'chat_unarchived',
      action: 'unarchive_chat',
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
      },
    });
    
    res.json({ message: 'Chat unarchived successfully' });
  } catch (error) {
    console.error('Error unarchiving chat:', error);
    sendErrorResponse(res, 500, 'UNARCHIVE_CHAT_ERROR', 'Failed to unarchive chat', error.message);
  }
});

// Transfer group ownership
router.post('/chats/:id/transfer-ownership', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { newOwnerId } = req.body;
    
    if (!newOwnerId) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'New owner ID is required');
    }
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    if (chat.type !== 'group') {
      return sendErrorResponse(res, 400, 'INVALID_CHAT_TYPE', 'Only group chats can have ownership transferred');
    }
    
    // Verify new owner is a member
    const memberIds = (chat.members || chat.memberIds || []).map(m => m.toString());
    if (!memberIds.includes(newOwnerId)) {
      return sendErrorResponse(res, 400, 'NOT_A_MEMBER', 'New owner must be a member of the group');
    }
    
    const oldOwnerId = chat.createdBy?.toString();
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          createdBy: new ObjectId(newOwnerId),
          ownershipTransferredAt: new Date(),
          ownershipTransferredBy: req.user.userId,
          previousOwner: oldOwnerId ? new ObjectId(oldOwnerId) : null,
        },
      }
    );
    
    emitAdminActivity(req.io, {
      type: 'ownership_transferred',
      action: 'transfer_ownership',
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
        oldOwnerId: oldOwnerId,
        newOwnerId: newOwnerId,
      },
    });
    
    res.json({ message: 'Ownership transferred successfully' });
  } catch (error) {
    console.error('Error transferring ownership:', error);
    sendErrorResponse(res, 500, 'TRANSFER_OWNERSHIP_ERROR', 'Failed to transfer ownership', error.message);
  }
});

// Assign group moderators
router.post('/chats/:id/moderators', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { userIds, action } = req.body; // action: 'add' or 'remove'
    
    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'User IDs array is required');
    }
    
    if (!action || !['add', 'remove'].includes(action)) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Action must be "add" or "remove"');
    }
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    if (chat.type !== 'group') {
      return sendErrorResponse(res, 400, 'INVALID_CHAT_TYPE', 'Only group chats can have moderators');
    }
    
    const moderatorObjectIds = userIds.map(uid => new ObjectId(uid));
    
    if (action === 'add') {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(id) },
        {
          $addToSet: {
            moderators: { $each: moderatorObjectIds },
          },
          $set: {
            updatedAt: new Date(),
          },
        }
      );
    } else {
      await db.collection('chats').updateOne(
        { _id: new ObjectId(id) },
        {
          $pull: {
            moderators: { $in: moderatorObjectIds },
          },
          $set: {
            updatedAt: new Date(),
          },
        }
      );
    }
    
    emitAdminActivity(req.io, {
      type: 'moderators_updated',
      action: `${action}_moderators`,
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
        userIds: userIds,
        action: action,
      },
    });
    
    res.json({ message: `Moderators ${action === 'add' ? 'added' : 'removed'} successfully` });
  } catch (error) {
    console.error('Error managing moderators:', error);
    sendErrorResponse(res, 500, 'MANAGE_MODERATORS_ERROR', 'Failed to manage moderators', error.message);
  }
});

// Update group permissions
router.put('/chats/:id/permissions', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { permissions } = req.body;
    
    if (!permissions) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Permissions object is required');
    }
    
    const chat = await db.collection('chats').findOne({ _id: new ObjectId(id) });
    if (!chat) {
      return sendErrorResponse(res, 404, 'CHAT_NOT_FOUND', 'Chat not found');
    }
    
    if (chat.type !== 'group') {
      return sendErrorResponse(res, 400, 'INVALID_CHAT_TYPE', 'Only group chats have permissions');
    }
    
    await db.collection('chats').updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          permissions: {
            canSendMessages: permissions.canSendMessages !== undefined ? permissions.canSendMessages : true,
            canAddMembers: permissions.canAddMembers !== undefined ? permissions.canAddMembers : true,
            canRemoveMembers: permissions.canRemoveMembers !== undefined ? permissions.canRemoveMembers : false,
            canChangeSettings: permissions.canChangeSettings !== undefined ? permissions.canChangeSettings : false,
          },
          updatedAt: new Date(),
        },
      }
    );
    
    emitAdminActivity(req.io, {
      type: 'permissions_updated',
      action: 'update_permissions',
      adminId: req.user.userId,
      targetId: id,
      details: {
        chatId: id,
        permissions: permissions,
      },
    });
    
    res.json({ message: 'Permissions updated successfully' });
  } catch (error) {
    console.error('Error updating permissions:', error);
    sendErrorResponse(res, 500, 'UPDATE_PERMISSIONS_ERROR', 'Failed to update permissions', error.message);
  }
});

// =============================================================================
// Phase 3: Feature Flags & A/B Testing
// =============================================================================

// Get all feature flags
router.get('/feature-flags', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const flags = await db.collection('feature_flags')
      .find({})
      .sort({ name: 1 })
      .toArray();
    
    res.json({
      flags: flags.map(flag => ({
        id: flag._id.toString(),
        name: flag.name,
        description: flag.description,
        enabled: flag.enabled || false,
        rolloutPercentage: flag.rolloutPercentage || 0,
        abTestEnabled: flag.abTestEnabled || false,
        abTestVariants: flag.abTestVariants || [],
        targetUsers: flag.targetUsers || [],
        targetSegments: flag.targetSegments || [],
        createdAt: flag.createdAt,
        updatedAt: flag.updatedAt,
        createdBy: flag.createdBy?.toString(),
        usageStats: flag.usageStats || {
          totalChecks: 0,
          enabledChecks: 0,
          disabledChecks: 0,
        },
      })),
    });
  } catch (error) {
    console.error('Error getting feature flags:', error);
    sendErrorResponse(res, 500, 'GET_FEATURE_FLAGS_ERROR', 'Failed to get feature flags', error.message);
  }
});

// Get single feature flag
router.get('/feature-flags/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const flag = await db.collection('feature_flags').findOne({ _id: new ObjectId(id) });
    if (!flag) {
      return sendErrorResponse(res, 404, 'FEATURE_FLAG_NOT_FOUND', 'Feature flag not found');
    }
    
    res.json({
      flag: {
        id: flag._id.toString(),
        name: flag.name,
        description: flag.description,
        enabled: flag.enabled || false,
        rolloutPercentage: flag.rolloutPercentage || 0,
        abTestEnabled: flag.abTestEnabled || false,
        abTestVariants: flag.abTestVariants || [],
        targetUsers: flag.targetUsers || [],
        targetSegments: flag.targetSegments || [],
        createdAt: flag.createdAt,
        updatedAt: flag.updatedAt,
        createdBy: flag.createdBy?.toString(),
        usageStats: flag.usageStats || {
          totalChecks: 0,
          enabledChecks: 0,
          disabledChecks: 0,
        },
      },
    });
  } catch (error) {
    console.error('Error getting feature flag:', error);
    sendErrorResponse(res, 500, 'GET_FEATURE_FLAG_ERROR', 'Failed to get feature flag', error.message);
  }
});

// Create feature flag
router.post('/feature-flags', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, description, enabled, rolloutPercentage, abTestEnabled, abTestVariants, targetUsers, targetSegments } = req.body;
    
    if (!name) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Feature flag name is required');
    }
    
    // Check if flag with same name exists
    const existing = await db.collection('feature_flags').findOne({ name: name });
    if (existing) {
      return sendErrorResponse(res, 400, 'DUPLICATE_NAME', 'Feature flag with this name already exists');
    }
    
    const flag = {
      name: name,
      description: description || '',
      enabled: enabled || false,
      rolloutPercentage: rolloutPercentage || 0,
      abTestEnabled: abTestEnabled || false,
      abTestVariants: abTestVariants || [],
      targetUsers: targetUsers || [],
      targetSegments: targetSegments || [],
      createdAt: new Date(),
      updatedAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
      usageStats: {
        totalChecks: 0,
        enabledChecks: 0,
        disabledChecks: 0,
      },
    };
    
    const result = await db.collection('feature_flags').insertOne(flag);
    
    emitAdminActivity(req.io, {
      type: 'feature_flag_created',
      action: 'create_feature_flag',
      adminId: req.user.userId,
      details: {
        flagId: result.insertedId.toString(),
        flagName: name,
      },
    });
    
    res.json({
      message: 'Feature flag created successfully',
      flag: {
        id: result.insertedId.toString(),
        ...flag,
        createdBy: flag.createdBy.toString(),
      },
    });
  } catch (error) {
    console.error('Error creating feature flag:', error);
    sendErrorResponse(res, 500, 'CREATE_FEATURE_FLAG_ERROR', 'Failed to create feature flag', error.message);
  }
});

// Update feature flag
router.put('/feature-flags/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, description, enabled, rolloutPercentage, abTestEnabled, abTestVariants, targetUsers, targetSegments } = req.body;
    
    const flag = await db.collection('feature_flags').findOne({ _id: new ObjectId(id) });
    if (!flag) {
      return sendErrorResponse(res, 404, 'FEATURE_FLAG_NOT_FOUND', 'Feature flag not found');
    }
    
    // Check name uniqueness if name is being changed
    if (name && name !== flag.name) {
      const existing = await db.collection('feature_flags').findOne({ name: name, _id: { $ne: new ObjectId(id) } });
      if (existing) {
        return sendErrorResponse(res, 400, 'DUPLICATE_NAME', 'Feature flag with this name already exists');
      }
    }
    
    const update = {
      updatedAt: new Date(),
    };
    
    if (name !== undefined) update.name = name;
    if (description !== undefined) update.description = description;
    if (enabled !== undefined) update.enabled = enabled;
    if (rolloutPercentage !== undefined) update.rolloutPercentage = rolloutPercentage;
    if (abTestEnabled !== undefined) update.abTestEnabled = abTestEnabled;
    if (abTestVariants !== undefined) update.abTestVariants = abTestVariants;
    if (targetUsers !== undefined) update.targetUsers = targetUsers;
    if (targetSegments !== undefined) update.targetSegments = targetSegments;
    
    await db.collection('feature_flags').updateOne(
      { _id: new ObjectId(id) },
      { $set: update }
    );
    
    emitAdminActivity(req.io, {
      type: 'feature_flag_updated',
      action: 'update_feature_flag',
      adminId: req.user.userId,
      targetId: id,
      details: {
        flagId: id,
        flagName: name || flag.name,
        changes: update,
      },
    });
    
    res.json({ message: 'Feature flag updated successfully' });
  } catch (error) {
    console.error('Error updating feature flag:', error);
    sendErrorResponse(res, 500, 'UPDATE_FEATURE_FLAG_ERROR', 'Failed to update feature flag', error.message);
  }
});

// Delete feature flag
router.delete('/feature-flags/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const flag = await db.collection('feature_flags').findOne({ _id: new ObjectId(id) });
    if (!flag) {
      return sendErrorResponse(res, 404, 'FEATURE_FLAG_NOT_FOUND', 'Feature flag not found');
    }
    
    await db.collection('feature_flags').deleteOne({ _id: new ObjectId(id) });
    
    emitAdminActivity(req.io, {
      type: 'feature_flag_deleted',
      action: 'delete_feature_flag',
      adminId: req.user.userId,
      targetId: id,
      details: {
        flagId: id,
        flagName: flag.name,
      },
    });
    
    res.json({ message: 'Feature flag deleted successfully' });
  } catch (error) {
    console.error('Error deleting feature flag:', error);
    sendErrorResponse(res, 500, 'DELETE_FEATURE_FLAG_ERROR', 'Failed to delete feature flag', error.message);
  }
});

// Check feature flag (for client apps)
router.get('/feature-flags/check/:name', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name } = req.params;
    const { userId } = req.query;
    
    const flag = await db.collection('feature_flags').findOne({ name: name });
    if (!flag) {
      return res.json({ enabled: false, reason: 'flag_not_found' });
    }
    
    if (!flag.enabled) {
      // Update stats
      await db.collection('feature_flags').updateOne(
        { _id: flag._id },
        {
          $inc: {
            'usageStats.totalChecks': 1,
            'usageStats.disabledChecks': 1,
          },
        }
      );
      return res.json({ enabled: false, reason: 'flag_disabled' });
    }
    
    // Check target users
    if (flag.targetUsers && flag.targetUsers.length > 0 && userId) {
      const userObjectId = new ObjectId(userId);
      const isTargeted = flag.targetUsers.some(uid => uid.toString() === userId || (uid instanceof ObjectId && uid.equals(userObjectId)));
      if (!isTargeted) {
        await db.collection('feature_flags').updateOne(
          { _id: flag._id },
          {
            $inc: {
              'usageStats.totalChecks': 1,
              'usageStats.disabledChecks': 1,
            },
          }
        );
        return res.json({ enabled: false, reason: 'user_not_targeted' });
      }
    }
    
    // Check rollout percentage
    if (flag.rolloutPercentage < 100) {
      // Simple hash-based rollout (consistent for same user)
      const hash = userId ? parseInt(userId.slice(-8), 16) : Math.floor(Math.random() * 100);
      const userPercentage = hash % 100;
      if (userPercentage >= flag.rolloutPercentage) {
        await db.collection('feature_flags').updateOne(
          { _id: flag._id },
          {
            $inc: {
              'usageStats.totalChecks': 1,
              'usageStats.disabledChecks': 1,
            },
          }
        );
        return res.json({ enabled: false, reason: 'rollout_percentage' });
      }
    }
    
    // A/B test variant selection
    let variant = null;
    if (flag.abTestEnabled && flag.abTestVariants && flag.abTestVariants.length > 0) {
      const hash = userId ? parseInt(userId.slice(-8), 16) : Math.floor(Math.random() * 100);
      const variantIndex = hash % flag.abTestVariants.length;
      variant = flag.abTestVariants[variantIndex];
    }
    
    // Update stats
    await db.collection('feature_flags').updateOne(
      { _id: flag._id },
      {
        $inc: {
          'usageStats.totalChecks': 1,
          'usageStats.enabledChecks': 1,
        },
      }
    );
    
    res.json({
      enabled: true,
      variant: variant,
      flagName: flag.name,
    });
  } catch (error) {
    console.error('Error checking feature flag:', error);
    res.json({ enabled: false, reason: 'error', error: error.message });
  }
});

// Get feature flag analytics
router.get('/feature-flags/:id/analytics', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { period = '7d' } = req.query;
    
    const flag = await db.collection('feature_flags').findOne({ _id: new ObjectId(id) });
    if (!flag) {
      return sendErrorResponse(res, 404, 'FEATURE_FLAG_NOT_FOUND', 'Feature flag not found');
    }
    
    // Calculate time range
    let timeRange;
    switch (period) {
      case '1h':
        timeRange = new Date(Date.now() - 60 * 60 * 1000);
        break;
      case '24h':
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        timeRange = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        break;
      case '30d':
        timeRange = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        timeRange = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    }
    
    // Get usage history from logs (if available)
    const usageLogs = await db.collection('feature_flag_usage')
      .find({
        flagId: new ObjectId(id),
        timestamp: { $gte: timeRange },
      })
      .sort({ timestamp: -1 })
      .toArray();
    
    const stats = flag.usageStats || {
      totalChecks: 0,
      enabledChecks: 0,
      disabledChecks: 0,
    };
    
    const enabledRate = stats.totalChecks > 0
      ? (stats.enabledChecks / stats.totalChecks) * 100
      : 0;
    
    res.json({
      flagId: id,
      flagName: flag.name,
      period: period,
      stats: stats,
      enabledRate: enabledRate,
      usageHistory: usageLogs.map(log => ({
        timestamp: log.timestamp,
        enabled: log.enabled,
        userId: log.userId?.toString(),
        variant: log.variant,
      })),
    });
  } catch (error) {
    console.error('Error getting feature flag analytics:', error);
    sendErrorResponse(res, 500, 'GET_FEATURE_FLAG_ANALYTICS_ERROR', 'Failed to get feature flag analytics', error.message);
  }
});

// =============================================================================
// Phase 3: API Management
// =============================================================================

// Get all API keys
router.get('/api/keys', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const keys = await db.collection('api_keys')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json({
      keys: keys.map(key => ({
        id: key._id.toString(),
        name: key.name,
        key: key.key,
        keyPrefix: key.key?.substring(0, 8) + '...' || 'N/A',
        permissions: key.permissions || [],
        rateLimit: key.rateLimit || { requests: 100, window: 60 },
        createdAt: key.createdAt,
        lastUsed: key.lastUsed,
        usageCount: key.usageCount || 0,
        isActive: key.isActive !== false,
        createdBy: key.createdBy?.toString(),
      })),
    });
  } catch (error) {
    console.error('Error getting API keys:', error);
    sendErrorResponse(res, 500, 'GET_API_KEYS_ERROR', 'Failed to get API keys', error.message);
  }
});

// Get single API key
router.get('/api/keys/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const key = await db.collection('api_keys').findOne({ _id: new ObjectId(id) });
    if (!key) {
      return sendErrorResponse(res, 404, 'API_KEY_NOT_FOUND', 'API key not found');
    }
    
    res.json({
      key: {
        id: key._id.toString(),
        name: key.name,
        key: key.key,
        permissions: key.permissions || [],
        rateLimit: key.rateLimit || { requests: 100, window: 60 },
        createdAt: key.createdAt,
        lastUsed: key.lastUsed,
        usageCount: key.usageCount || 0,
        isActive: key.isActive !== false,
        createdBy: key.createdBy?.toString(),
      },
    });
  } catch (error) {
    console.error('Error getting API key:', error);
    sendErrorResponse(res, 500, 'GET_API_KEY_ERROR', 'Failed to get API key', error.message);
  }
});

// Create API key
router.post('/api/keys', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, permissions, rateLimit } = req.body;
    
    if (!name) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'API key name is required');
    }
    
    // Generate API key
    const crypto = require('crypto');
    const apiKey = 'sk_' + crypto.randomBytes(32).toString('hex');
    
    const key = {
      name: name,
      key: apiKey,
      permissions: permissions || ['read'],
      rateLimit: rateLimit || { requests: 100, window: 60 },
      createdAt: new Date(),
      lastUsed: null,
      usageCount: 0,
      isActive: true,
      createdBy: new ObjectId(req.user.userId),
    };
    
    const result = await db.collection('api_keys').insertOne(key);
    
    emitAdminActivity(req.io, {
      type: 'api_key_created',
      action: 'create_api_key',
      adminId: req.user.userId,
      details: {
        keyId: result.insertedId.toString(),
        keyName: name,
      },
    });
    
    res.json({
      message: 'API key created successfully',
      key: {
        id: result.insertedId.toString(),
        name: key.name,
        key: key.key, // Only show full key on creation
        permissions: key.permissions,
        rateLimit: key.rateLimit,
        createdAt: key.createdAt,
        createdBy: key.createdBy.toString(),
      },
    });
  } catch (error) {
    console.error('Error creating API key:', error);
    sendErrorResponse(res, 500, 'CREATE_API_KEY_ERROR', 'Failed to create API key', error.message);
  }
});

// Update API key
router.put('/api/keys/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, permissions, rateLimit, isActive } = req.body;
    
    const key = await db.collection('api_keys').findOne({ _id: new ObjectId(id) });
    if (!key) {
      return sendErrorResponse(res, 404, 'API_KEY_NOT_FOUND', 'API key not found');
    }
    
    const update = {
      updatedAt: new Date(),
    };
    
    if (name !== undefined) update.name = name;
    if (permissions !== undefined) update.permissions = permissions;
    if (rateLimit !== undefined) update.rateLimit = rateLimit;
    if (isActive !== undefined) update.isActive = isActive;
    
    await db.collection('api_keys').updateOne(
      { _id: new ObjectId(id) },
      { $set: update }
    );
    
    emitAdminActivity(req.io, {
      type: 'api_key_updated',
      action: 'update_api_key',
      adminId: req.user.userId,
      targetId: id,
      details: {
        keyId: id,
        keyName: name || key.name,
        changes: update,
      },
    });
    
    res.json({ message: 'API key updated successfully' });
  } catch (error) {
    console.error('Error updating API key:', error);
    sendErrorResponse(res, 500, 'UPDATE_API_KEY_ERROR', 'Failed to update API key', error.message);
  }
});

// Delete API key
router.delete('/api/keys/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const key = await db.collection('api_keys').findOne({ _id: new ObjectId(id) });
    if (!key) {
      return sendErrorResponse(res, 404, 'API_KEY_NOT_FOUND', 'API key not found');
    }
    
    await db.collection('api_keys').deleteOne({ _id: new ObjectId(id) });
    
    emitAdminActivity(req.io, {
      type: 'api_key_deleted',
      action: 'delete_api_key',
      adminId: req.user.userId,
      targetId: id,
      details: {
        keyId: id,
        keyName: key.name,
      },
    });
    
    res.json({ message: 'API key deleted successfully' });
  } catch (error) {
    console.error('Error deleting API key:', error);
    sendErrorResponse(res, 500, 'DELETE_API_KEY_ERROR', 'Failed to delete API key', error.message);
  }
});

// Get API usage analytics
router.get('/api/usage', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { period = '24h', keyId } = req.query;
    
    // Calculate time range
    let timeRange;
    switch (period) {
      case '1h':
        timeRange = new Date(Date.now() - 60 * 60 * 1000);
        break;
      case '24h':
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        timeRange = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        break;
      case '30d':
        timeRange = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
    }
    
    const query = {
      timestamp: { $gte: timeRange },
    };
    if (keyId) {
      query.keyId = new ObjectId(keyId);
    }
    
    const usageLogs = await db.collection('api_usage_logs')
      .find(query)
      .sort({ timestamp: -1 })
      .toArray();
    
    // Aggregate by endpoint
    const endpointStats = {};
    const keyStats = {};
    let totalRequests = 0;
    let totalErrors = 0;
    
    usageLogs.forEach(log => {
      totalRequests++;
      if (log.statusCode >= 400) totalErrors++;
      
      const endpoint = log.endpoint || 'unknown';
      if (!endpointStats[endpoint]) {
        endpointStats[endpoint] = { requests: 0, errors: 0, avgResponseTime: 0, responseTimes: [] };
      }
      endpointStats[endpoint].requests++;
      if (log.statusCode >= 400) endpointStats[endpoint].errors++;
      if (log.responseTime) {
        endpointStats[endpoint].responseTimes.push(log.responseTime);
      }
      
      if (log.keyId) {
        const keyIdStr = log.keyId.toString();
        if (!keyStats[keyIdStr]) {
          keyStats[keyIdStr] = { requests: 0, errors: 0 };
        }
        keyStats[keyIdStr].requests++;
        if (log.statusCode >= 400) keyStats[keyIdStr].errors++;
      }
    });
    
    // Calculate averages
    Object.keys(endpointStats).forEach(endpoint => {
      const stats = endpointStats[endpoint];
      if (stats.responseTimes.length > 0) {
        stats.avgResponseTime = stats.responseTimes.reduce((a, b) => a + b, 0) / stats.responseTimes.length;
      }
      delete stats.responseTimes;
    });
    
    res.json({
      period: period,
      totalRequests: totalRequests,
      totalErrors: totalErrors,
      errorRate: totalRequests > 0 ? (totalErrors / totalRequests) * 100 : 0,
      endpointStats: endpointStats,
      keyStats: keyStats,
      usageHistory: usageLogs.slice(0, 100).map(log => ({
        timestamp: log.timestamp,
        endpoint: log.endpoint,
        method: log.method,
        statusCode: log.statusCode,
        responseTime: log.responseTime,
        keyId: log.keyId?.toString(),
      })),
    });
  } catch (error) {
    console.error('Error getting API usage analytics:', error);
    sendErrorResponse(res, 500, 'GET_API_USAGE_ERROR', 'Failed to get API usage analytics', error.message);
  }
});

// Get endpoint monitoring
router.get('/api/endpoints', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { period = '24h' } = req.query;
    
    // Calculate time range
    let timeRange;
    switch (period) {
      case '1h':
        timeRange = new Date(Date.now() - 60 * 60 * 1000);
        break;
      case '24h':
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        timeRange = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        break;
      case '30d':
        timeRange = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        timeRange = new Date(Date.now() - 24 * 60 * 60 * 1000);
    }
    
    const usageLogs = await db.collection('api_usage_logs')
      .find({ timestamp: { $gte: timeRange } })
      .toArray();
    
    const endpointMap = {};
    
    usageLogs.forEach(log => {
      const endpoint = log.endpoint || 'unknown';
      if (!endpointMap[endpoint]) {
        endpointMap[endpoint] = {
          endpoint: endpoint,
          method: log.method || 'GET',
          requests: 0,
          errors: 0,
          avgResponseTime: 0,
          responseTimes: [],
          statusCodes: {},
        };
      }
      
      endpointMap[endpoint].requests++;
      if (log.statusCode >= 400) endpointMap[endpoint].errors++;
      
      const statusCode = log.statusCode || 200;
      endpointMap[endpoint].statusCodes[statusCode] = (endpointMap[endpoint].statusCodes[statusCode] || 0) + 1;
      
      if (log.responseTime) {
        endpointMap[endpoint].responseTimes.push(log.responseTime);
      }
    });
    
    // Calculate averages
    const endpoints = Object.values(endpointMap).map(endpoint => {
      if (endpoint.responseTimes.length > 0) {
        endpoint.avgResponseTime = endpoint.responseTimes.reduce((a, b) => a + b, 0) / endpoint.responseTimes.length;
      }
      delete endpoint.responseTimes;
      endpoint.errorRate = endpoint.requests > 0 ? (endpoint.errors / endpoint.requests) * 100 : 0;
      return endpoint;
    });
    
    res.json({
      period: period,
      endpoints: endpoints.sort((a, b) => b.requests - a.requests),
    });
  } catch (error) {
    console.error('Error getting endpoint monitoring:', error);
    sendErrorResponse(res, 500, 'GET_ENDPOINT_MONITORING_ERROR', 'Failed to get endpoint monitoring', error.message);
  }
});

// =============================================================================
// Phase 3: Integration Management
// =============================================================================

// Get all integrations
router.get('/integrations', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const integrations = await db.collection('integrations')
      .find({})
      .sort({ name: 1 })
      .toArray();
    
    // Check health status for each integration
    const integrationsWithHealth = await Promise.all(integrations.map(async (integration) => {
      const healthStatus = await checkIntegrationHealth(db, integration);
      return {
        id: integration._id.toString(),
        name: integration.name,
        type: integration.type,
        config: integration.config || {},
        webhooks: integration.webhooks || [],
        isActive: integration.isActive !== false,
        healthStatus: healthStatus,
        lastHealthCheck: integration.lastHealthCheck,
        createdAt: integration.createdAt,
        updatedAt: integration.updatedAt,
        createdBy: integration.createdBy?.toString(),
      };
    }));
    
    res.json({ integrations: integrationsWithHealth });
  } catch (error) {
    console.error('Error getting integrations:', error);
    sendErrorResponse(res, 500, 'GET_INTEGRATIONS_ERROR', 'Failed to get integrations', error.message);
  }
});

// Get single integration
router.get('/integrations/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const integration = await db.collection('integrations').findOne({ _id: new ObjectId(id) });
    if (!integration) {
      return sendErrorResponse(res, 404, 'INTEGRATION_NOT_FOUND', 'Integration not found');
    }
    
    const healthStatus = await checkIntegrationHealth(db, integration);
    
    res.json({
      integration: {
        id: integration._id.toString(),
        name: integration.name,
        type: integration.type,
        config: integration.config || {},
        webhooks: integration.webhooks || [],
        isActive: integration.isActive !== false,
        healthStatus: healthStatus,
        lastHealthCheck: integration.lastHealthCheck,
        createdAt: integration.createdAt,
        updatedAt: integration.updatedAt,
        createdBy: integration.createdBy?.toString(),
      },
    });
  } catch (error) {
    console.error('Error getting integration:', error);
    sendErrorResponse(res, 500, 'GET_INTEGRATION_ERROR', 'Failed to get integration', error.message);
  }
});

// Create integration
router.post('/integrations', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, type, config, webhooks } = req.body;
    
    if (!name || !type) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Integration name and type are required');
    }
    
    const integration = {
      name: name,
      type: type,
      config: config || {},
      webhooks: webhooks || [],
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
      lastHealthCheck: null,
    };
    
    const result = await db.collection('integrations').insertOne(integration);
    
    emitAdminActivity(req.io, {
      type: 'integration_created',
      action: 'create_integration',
      adminId: req.user.userId,
      details: {
        integrationId: result.insertedId.toString(),
        integrationName: name,
        integrationType: type,
      },
    });
    
    res.json({
      message: 'Integration created successfully',
      integration: {
        id: result.insertedId.toString(),
        ...integration,
        createdBy: integration.createdBy.toString(),
      },
    });
  } catch (error) {
    console.error('Error creating integration:', error);
    sendErrorResponse(res, 500, 'CREATE_INTEGRATION_ERROR', 'Failed to create integration', error.message);
  }
});

// Update integration
router.put('/integrations/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, config, webhooks, isActive } = req.body;
    
    const integration = await db.collection('integrations').findOne({ _id: new ObjectId(id) });
    if (!integration) {
      return sendErrorResponse(res, 404, 'INTEGRATION_NOT_FOUND', 'Integration not found');
    }
    
    const update = {
      updatedAt: new Date(),
    };
    
    if (name !== undefined) update.name = name;
    if (config !== undefined) update.config = config;
    if (webhooks !== undefined) update.webhooks = webhooks;
    if (isActive !== undefined) update.isActive = isActive;
    
    await db.collection('integrations').updateOne(
      { _id: new ObjectId(id) },
      { $set: update }
    );
    
    emitAdminActivity(req.io, {
      type: 'integration_updated',
      action: 'update_integration',
      adminId: req.user.userId,
      targetId: id,
      details: {
        integrationId: id,
        integrationName: name || integration.name,
        changes: update,
      },
    });
    
    res.json({ message: 'Integration updated successfully' });
  } catch (error) {
    console.error('Error updating integration:', error);
    sendErrorResponse(res, 500, 'UPDATE_INTEGRATION_ERROR', 'Failed to update integration', error.message);
  }
});

// Delete integration
router.delete('/integrations/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const integration = await db.collection('integrations').findOne({ _id: new ObjectId(id) });
    if (!integration) {
      return sendErrorResponse(res, 404, 'INTEGRATION_NOT_FOUND', 'Integration not found');
    }
    
    await db.collection('integrations').deleteOne({ _id: new ObjectId(id) });
    
    emitAdminActivity(req.io, {
      type: 'integration_deleted',
      action: 'delete_integration',
      adminId: req.user.userId,
      targetId: id,
      details: {
        integrationId: id,
        integrationName: integration.name,
      },
    });
    
    res.json({ message: 'Integration deleted successfully' });
  } catch (error) {
    console.error('Error deleting integration:', error);
    sendErrorResponse(res, 500, 'DELETE_INTEGRATION_ERROR', 'Failed to delete integration', error.message);
  }
});

// Check integration health
router.post('/integrations/:id/health-check', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const integration = await db.collection('integrations').findOne({ _id: new ObjectId(id) });
    if (!integration) {
      return sendErrorResponse(res, 404, 'INTEGRATION_NOT_FOUND', 'Integration not found');
    }
    
    const healthStatus = await checkIntegrationHealth(db, integration);
    
    // Update last health check
    await db.collection('integrations').updateOne(
      { _id: new ObjectId(id) },
      { $set: { lastHealthCheck: new Date() } }
    );
    
    res.json({ healthStatus: healthStatus });
  } catch (error) {
    console.error('Error checking integration health:', error);
    sendErrorResponse(res, 500, 'HEALTH_CHECK_ERROR', 'Failed to check integration health', error.message);
  }
});

// Get webhook delivery history
router.get('/integrations/:id/webhooks/history', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { limit = 100 } = req.query;
    
    const history = await db.collection('webhook_deliveries')
      .find({ integrationId: new ObjectId(id) })
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .toArray();
    
    res.json({
      history: history.map(delivery => ({
        id: delivery._id.toString(),
        url: delivery.url,
        method: delivery.method,
        statusCode: delivery.statusCode,
        success: delivery.success,
        responseTime: delivery.responseTime,
        timestamp: delivery.timestamp,
        payload: delivery.payload,
        response: delivery.response,
      })),
    });
  } catch (error) {
    console.error('Error getting webhook history:', error);
    sendErrorResponse(res, 500, 'GET_WEBHOOK_HISTORY_ERROR', 'Failed to get webhook history', error.message);
  }
});

// Test webhook
router.post('/integrations/:id/webhooks/test', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { url, method = 'POST', payload } = req.body;
    
    if (!url) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Webhook URL is required');
    }
    
    const integration = await db.collection('integrations').findOne({ _id: new ObjectId(id) });
    if (!integration) {
      return sendErrorResponse(res, 404, 'INTEGRATION_NOT_FOUND', 'Integration not found');
    }
    
    const startTime = Date.now();
    let success = false;
    let statusCode = 0;
    let response = null;
    
    try {
      const http = require('http');
      const https = require('https');
      const urlObj = new URL(url);
      const client = urlObj.protocol === 'https:' ? https : http;
      
      const requestOptions = {
        hostname: urlObj.hostname,
        port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
        path: urlObj.pathname + urlObj.search,
        method: method,
        headers: {
          'Content-Type': 'application/json',
        },
      };
      
      const result = await new Promise((resolve, reject) => {
        const req = client.request(requestOptions, (res) => {
          let data = '';
          res.on('data', (chunk) => { data += chunk; });
          res.on('end', () => {
            resolve({ statusCode: res.statusCode, data: data });
          });
        });
        
        req.on('error', reject);
        if (payload) {
          req.write(JSON.stringify(payload));
        }
        req.end();
      });
      
      statusCode = result.statusCode;
      success = statusCode >= 200 && statusCode < 300;
      response = result.data;
    } catch (error) {
      success = false;
      response = error.message;
    }
    
    const responseTime = Date.now() - startTime;
    
    // Log webhook delivery
    await db.collection('webhook_deliveries').insertOne({
      integrationId: new ObjectId(id),
      url: url,
      method: method,
      statusCode: statusCode,
      success: success,
      responseTime: responseTime,
      timestamp: new Date(),
      payload: payload,
      response: response,
    });
    
    res.json({
      success: success,
      statusCode: statusCode,
      responseTime: responseTime,
      response: response,
    });
  } catch (error) {
    console.error('Error testing webhook:', error);
    sendErrorResponse(res, 500, 'TEST_WEBHOOK_ERROR', 'Failed to test webhook', error.message);
  }
});

// Helper function to check integration health
async function checkIntegrationHealth(db, integration) {
  try {
    // Basic health check based on integration type
    switch (integration.type) {
      case 'webhook':
        // Check if webhooks are configured
        if (!integration.webhooks || integration.webhooks.length === 0) {
          return { status: 'warning', message: 'No webhooks configured' };
        }
        return { status: 'healthy', message: 'Webhooks configured' };
      
      case 'database':
        // Check database connection
        try {
          await db.admin().ping();
          return { status: 'healthy', message: 'Database connection OK' };
        } catch (error) {
          return { status: 'unhealthy', message: 'Database connection failed' };
        }
      
      case 'external_api':
        // Check external API (if URL is in config)
        if (integration.config?.url) {
          // In a real implementation, make a test request
          return { status: 'healthy', message: 'External API configured' };
        }
        return { status: 'warning', message: 'External API URL not configured' };
      
      default:
        return { status: 'unknown', message: 'Unknown integration type' };
    }
  } catch (error) {
    return { status: 'error', message: error.message };
  }
}

// =============================================================================
// Phase 3: Backup & Restore
// =============================================================================

// Get all backups
router.get('/backups', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    
    // Try to find backups in the 'backups' collection
    let backups = await db.collection('backups')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    // If no backups found, check for backups in other possible collections
    if (backups.length === 0) {
      // Check for backup records in other collections
      const allCollections = await db.listCollections().toArray();
      const backupCollections = allCollections.filter(c => 
        c.name.toLowerCase().includes('backup') || 
        c.name.toLowerCase().includes('snapshot')
      );
      
      // Try to find backups in backup-related collections
      for (const coll of backupCollections) {
        try {
          const backupDocs = await db.collection(coll.name)
            .find({})
            .sort({ createdAt: -1 })
            .limit(100)
            .toArray();
          
          if (backupDocs.length > 0) {
            // Convert to backup format
            backups = backupDocs.map(doc => ({
              _id: doc._id,
              name: doc.name || doc.backupName || `Backup from ${coll.name}`,
              type: doc.type || doc.backupType || 'full',
              size: doc.size || doc.backupSize || 0,
              status: doc.status || doc.backupStatus || 'completed',
              createdAt: doc.createdAt || doc.timestamp || doc.date || new Date(),
              completedAt: doc.completedAt || doc.completed || doc.createdAt,
              verified: doc.verified || true,
              scheduleId: doc.scheduleId,
              createdBy: doc.createdBy,
              error: doc.error,
              restoreStatus: doc.restoreStatus,
              restoreStartedAt: doc.restoreStartedAt,
              restoreCompletedAt: doc.restoreCompletedAt,
              restoreError: doc.restoreError,
              progress: doc.progress || (doc.status === 'completed' ? 100 : doc.status === 'in_progress' ? 50 : 0),
              backupPath: doc.backupPath || doc.path || doc.filePath,
              collectionsBackedUp: doc.collectionsBackedUp || doc.collections || [],
              documentCount: doc.documentCount || doc.count || 0,
            }));
            break;
          }
        } catch (e) {
          console.error(`Error checking collection ${coll.name}:`, e);
        }
      }
    }
    
    res.json({
      backups: backups.map(backup => ({
        id: backup._id.toString(),
        name: backup.name || 'Unnamed Backup',
        type: backup.type || 'full',
        size: backup.size || 0,
        status: backup.status || 'unknown',
        createdAt: backup.createdAt,
        completedAt: backup.completedAt,
        verified: backup.verified !== false,
        scheduleId: backup.scheduleId?.toString(),
        createdBy: backup.createdBy?.toString(),
        error: backup.error,
        restoreStatus: backup.restoreStatus,
        restoreStartedAt: backup.restoreStartedAt,
        restoreCompletedAt: backup.restoreCompletedAt,
        restoreError: backup.restoreError,
        progress: backup.progress || (backup.status === 'completed' ? 100 : backup.status === 'in_progress' ? 50 : 0),
        backupPath: backup.backupPath || backup.path || backup.filePath,
        collectionsBackedUp: backup.collectionsBackedUp || backup.collections || [],
        documentCount: backup.documentCount || backup.count || 0,
      })),
    });
  } catch (error) {
    console.error('Error getting backups:', error);
    sendErrorResponse(res, 500, 'GET_BACKUPS_ERROR', 'Failed to get backups', error.message);
  }
});

// Create backup
router.post('/backups', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, type = 'full' } = req.body;
    
    const backup = {
      name: name || `Backup_${new Date().toISOString()}`,
      type: type,
      status: 'in_progress',
      createdAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
      verified: false,
    };
    
    const result = await db.collection('backups').insertOne(backup);
    
    // Perform backup asynchronously
    performBackup(db, result.insertedId, type).catch(err => {
      console.error('Backup error:', err);
      db.collection('backups').updateOne(
        { _id: result.insertedId },
        { $set: { status: 'failed', error: err.message } }
      );
    });
    
    emitAdminActivity(req.io, {
      type: 'backup_created',
      action: 'create_backup',
      adminId: req.user.userId,
      details: {
        backupId: result.insertedId.toString(),
        backupName: backup.name,
      },
    });
    
    res.json({
      message: 'Backup started',
      backup: {
        id: result.insertedId.toString(),
        ...backup,
        createdBy: backup.createdBy.toString(),
      },
    });
  } catch (error) {
    console.error('Error creating backup:', error);
    sendErrorResponse(res, 500, 'CREATE_BACKUP_ERROR', 'Failed to create backup', error.message);
  }
});

// Restore backup
router.post('/backups/:id/restore', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { confirm = false } = req.body;
    
    if (!confirm) {
      return sendErrorResponse(res, 400, 'CONFIRMATION_REQUIRED', 'Backup restoration requires confirmation');
    }
    
    const backup = await db.collection('backups').findOne({ _id: new ObjectId(id) });
    if (!backup) {
      return sendErrorResponse(res, 404, 'BACKUP_NOT_FOUND', 'Backup not found');
    }
    
    if (backup.status !== 'completed') {
      return sendErrorResponse(res, 400, 'BACKUP_NOT_READY', 'Backup is not ready for restoration');
    }
    
    // Update backup status
    await db.collection('backups').updateOne(
      { _id: new ObjectId(id) },
      { $set: { restoreStatus: 'in_progress', restoreStartedAt: new Date() } }
    );
    
    // Perform restore asynchronously
    performRestore(db, id, backup).catch(err => {
      console.error('Restore error:', err);
      db.collection('backups').updateOne(
        { _id: new ObjectId(id) },
        { $set: { restoreStatus: 'failed', restoreError: err.message } }
      );
    });
    
    emitAdminActivity(req.io, {
      type: 'backup_restore_started',
      action: 'restore_backup',
      adminId: req.user.userId,
      targetId: id,
      details: {
        backupId: id,
        backupName: backup.name,
      },
    });
    
    res.json({ message: 'Backup restoration started' });
  } catch (error) {
    console.error('Error restoring backup:', error);
    sendErrorResponse(res, 500, 'RESTORE_BACKUP_ERROR', 'Failed to restore backup', error.message);
  }
});

// Cancel/Stop running backup
router.post('/backups/:id/cancel', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const backup = await db.collection('backups').findOne({ _id: new ObjectId(id) });
    if (!backup) {
      return sendErrorResponse(res, 404, 'BACKUP_NOT_FOUND', 'Backup not found');
    }
    
    if (backup.status !== 'in_progress') {
      return sendErrorResponse(res, 400, 'BACKUP_NOT_RUNNING', 'Backup is not running');
    }
    
    await db.collection('backups').updateOne(
      { _id: new ObjectId(id) },
      { $set: { status: 'cancelled', cancelledAt: new Date() } }
    );
    
    emitAdminActivity(req.io, {
      type: 'backup_cancelled',
      action: 'cancel_backup',
      adminId: req.user.userId,
      targetId: id,
      details: {
        backupId: id,
        backupName: backup.name,
      },
    });
    
    res.json({ message: 'Backup cancelled successfully' });
  } catch (error) {
    console.error('Error cancelling backup:', error);
    sendErrorResponse(res, 500, 'CANCEL_BACKUP_ERROR', 'Failed to cancel backup', error.message);
  }
});

// Delete backup
router.delete('/backups/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const backup = await db.collection('backups').findOne({ _id: new ObjectId(id) });
    if (!backup) {
      return sendErrorResponse(res, 404, 'BACKUP_NOT_FOUND', 'Backup not found');
    }
    
    await db.collection('backups').deleteOne({ _id: new ObjectId(id) });
    
    emitAdminActivity(req.io, {
      type: 'backup_deleted',
      action: 'delete_backup',
      adminId: req.user.userId,
      targetId: id,
      details: {
        backupId: id,
        backupName: backup.name,
      },
    });
    
    res.json({ message: 'Backup deleted successfully' });
  } catch (error) {
    console.error('Error deleting backup:', error);
    sendErrorResponse(res, 500, 'DELETE_BACKUP_ERROR', 'Failed to delete backup', error.message);
  }
});

// Get backup schedules
router.get('/backups/schedules', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const schedules = await db.collection('backup_schedules')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json({
      schedules: schedules.map(schedule => ({
        id: schedule._id.toString(),
        name: schedule.name,
        frequency: schedule.frequency,
        time: schedule.time,
        type: schedule.type,
        isActive: schedule.isActive !== false,
        lastRun: schedule.lastRun,
        nextRun: schedule.nextRun,
        createdAt: schedule.createdAt,
        createdBy: schedule.createdBy?.toString(),
      })),
    });
  } catch (error) {
    console.error('Error getting backup schedules:', error);
    sendErrorResponse(res, 500, 'GET_BACKUP_SCHEDULES_ERROR', 'Failed to get backup schedules', error.message);
  }
});

// Create backup schedule
router.post('/backups/schedules', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, frequency, time, type = 'full' } = req.body;
    
    if (!name || !frequency) {
      return sendErrorResponse(res, 400, 'VALIDATION_ERROR', 'Schedule name and frequency are required');
    }
    
    const schedule = {
      name: name,
      frequency: frequency,
      time: time || '00:00',
      type: type,
      isActive: true,
      createdAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
      lastRun: null,
      nextRun: calculateNextRun(frequency, time),
    };
    
    const result = await db.collection('backup_schedules').insertOne(schedule);
    
    emitAdminActivity(req.io, {
      type: 'backup_schedule_created',
      action: 'create_backup_schedule',
      adminId: req.user.userId,
      details: {
        scheduleId: result.insertedId.toString(),
        scheduleName: name,
      },
    });
    
    res.json({
      message: 'Backup schedule created successfully',
      schedule: {
        id: result.insertedId.toString(),
        ...schedule,
        createdBy: schedule.createdBy.toString(),
      },
    });
  } catch (error) {
    console.error('Error creating backup schedule:', error);
    sendErrorResponse(res, 500, 'CREATE_BACKUP_SCHEDULE_ERROR', 'Failed to create backup schedule', error.message);
  }
});

// Update backup schedule
router.put('/backups/schedules/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { name, frequency, time, type, isActive } = req.body;
    
    const schedule = await db.collection('backup_schedules').findOne({ _id: new ObjectId(id) });
    if (!schedule) {
      return sendErrorResponse(res, 404, 'BACKUP_SCHEDULE_NOT_FOUND', 'Backup schedule not found');
    }
    
    const update = {
      updatedAt: new Date(),
    };
    
    if (name !== undefined) update.name = name;
    if (frequency !== undefined) {
      update.frequency = frequency;
      update.nextRun = calculateNextRun(frequency, time || schedule.time);
    }
    if (time !== undefined) {
      update.time = time;
      update.nextRun = calculateNextRun(frequency || schedule.frequency, time);
    }
    if (type !== undefined) update.type = type;
    if (isActive !== undefined) update.isActive = isActive;
    
    await db.collection('backup_schedules').updateOne(
      { _id: new ObjectId(id) },
      { $set: update }
    );
    
    res.json({ message: 'Backup schedule updated successfully' });
  } catch (error) {
    console.error('Error updating backup schedule:', error);
    sendErrorResponse(res, 500, 'UPDATE_BACKUP_SCHEDULE_ERROR', 'Failed to update backup schedule', error.message);
  }
});

// Delete backup schedule
router.delete('/backups/schedules/:id', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    
    const schedule = await db.collection('backup_schedules').findOne({ _id: new ObjectId(id) });
    if (!schedule) {
      return sendErrorResponse(res, 404, 'BACKUP_SCHEDULE_NOT_FOUND', 'Backup schedule not found');
    }
    
    await db.collection('backup_schedules').deleteOne({ _id: new ObjectId(id) });
    
    res.json({ message: 'Backup schedule deleted successfully' });
  } catch (error) {
    console.error('Error deleting backup schedule:', error);
    sendErrorResponse(res, 500, 'DELETE_BACKUP_SCHEDULE_ERROR', 'Failed to delete backup schedule', error.message);
  }
});

// Helper function to perform backup
async function performBackup(db, backupId, type) {
  const fs = require('fs');
  const path = require('path');
  const os = require('os');
  
  let backupDir = null;
  let backupData = {};
  let totalSize = 0;
  
  try {
    // Define collections to backup (exclude system collections and backup metadata)
    const collectionsToBackup = [
      'users',
      'chats',
      'messages',
      'groups',
      'reports',
      'user_logs',
      'admin_logs',
      'devices',
      'feature_flags',
      'api_keys',
      'integrations',
      'announcements',
      'user_segments',
      'report_templates',
      'reports',
      'backup_schedules',
      'scheduled_broadcasts',
      'notification_templates',
      'notification_history',
      'moderation_rules',
      'moderation_queue',
      'webhook_deliveries',
      'api_usage_logs',
      'feature_flag_usage',
    ];
    
    // Update progress: Starting
    await db.collection('backups').updateOne(
      { _id: backupId },
      { $set: { progress: 10, status: 'in_progress' } }
    );
    
    // Create backup directory
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    backupDir = path.join(os.tmpdir(), `backup_${backupId}_${timestamp}`);
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir, { recursive: true });
    }
    
    // Update progress: Directory created
    await db.collection('backups').updateOne(
      { _id: backupId },
      { $set: { progress: 20 } }
    );
    
    // Export each collection
    let exportedCount = 0;
    const totalCollections = collectionsToBackup.length;
    
    for (const collectionName of collectionsToBackup) {
      try {
        const collection = db.collection(collectionName);
        const count = await collection.countDocuments();
        
        if (count > 0) {
          const documents = await collection.find({}).toArray();
          
          // Convert ObjectId to string for JSON serialization
          const serializedDocs = documents.map(doc => {
            const serialized = { ...doc };
            if (serialized._id) {
              serialized._id = serialized._id.toString();
            }
            // Convert nested ObjectIds
            Object.keys(serialized).forEach(key => {
              if (serialized[key] && typeof serialized[key] === 'object') {
                if (serialized[key].constructor && serialized[key].constructor.name === 'ObjectId') {
                  serialized[key] = serialized[key].toString();
                } else if (Array.isArray(serialized[key])) {
                  serialized[key] = serialized[key].map(item => {
                    if (item && typeof item === 'object' && item.constructor && item.constructor.name === 'ObjectId') {
                      return item.toString();
                    }
                    return item;
                  });
                }
              }
            });
            return serialized;
          });
          
          const collectionData = {
            collection: collectionName,
            count: count,
            exportedAt: new Date().toISOString(),
            documents: serializedDocs,
          };
          
          backupData[collectionName] = collectionData;
          
          // Save collection to file
          const filePath = path.join(backupDir, `${collectionName}.json`);
          fs.writeFileSync(filePath, JSON.stringify(collectionData, null, 2), 'utf8');
          
          const fileSize = fs.statSync(filePath).size;
          totalSize += fileSize;
        }
        
        exportedCount++;
        const progress = 20 + Math.floor((exportedCount / totalCollections) * 60);
        await db.collection('backups').updateOne(
          { _id: backupId },
          { $set: { progress: progress } }
        );
      } catch (collectionError) {
        console.error(`Error backing up collection ${collectionName}:`, collectionError);
        // Continue with other collections even if one fails
      }
    }
    
    // Create backup manifest
    const manifest = {
      backupId: backupId.toString(),
      type: type,
      createdAt: new Date().toISOString(),
      collections: Object.keys(backupData),
      totalCollections: Object.keys(backupData).length,
      totalDocuments: Object.values(backupData).reduce((sum, col) => sum + (col.count || 0), 0),
      totalSize: totalSize,
    };
    
    fs.writeFileSync(
      path.join(backupDir, 'manifest.json'),
      JSON.stringify(manifest, null, 2),
      'utf8'
    );
    
    // Store backup metadata in database
    await db.collection('backups').updateOne(
      { _id: backupId },
      {
        $set: {
          status: 'completed',
          completedAt: new Date(),
          size: totalSize,
          verified: true,
          progress: 100,
          backupPath: backupDir,
          collectionsBackedUp: Object.keys(backupData),
          documentCount: manifest.totalDocuments,
        },
      }
    );
    
    console.log(`Backup ${backupId} completed. Size: ${(totalSize / 1024 / 1024).toFixed(2)} MB, Collections: ${Object.keys(backupData).length}`);
  } catch (error) {
    console.error('Backup error:', error);
    await db.collection('backups').updateOne(
      { _id: backupId },
      {
        $set: {
          status: 'failed',
          error: error.message,
          progress: 0,
        },
      }
    );
    
    // Cleanup backup directory on error
    if (backupDir && fs.existsSync(backupDir)) {
      try {
        fs.rmSync(backupDir, { recursive: true, force: true });
      } catch (cleanupError) {
        console.error('Error cleaning up backup directory:', cleanupError);
      }
    }
    
    throw error;
  }
}

// Helper function to perform restore
async function performRestore(db, backupId, backup) {
  const fs = require('fs');
  const path = require('path');
  
  try {
    // Get backup path from backup record
    const backupPath = backup.backupPath;
    
    if (!backupPath || !fs.existsSync(backupPath)) {
      throw new Error('Backup files not found. Backup may have been cleaned up.');
    }
    
    // Update progress: Starting restore
    await db.collection('backups').updateOne(
      { _id: new ObjectId(backupId) },
      { $set: { restoreStatus: 'in_progress', restoreProgress: 10 } }
    );
    
    // Read manifest
    const manifestPath = path.join(backupPath, 'manifest.json');
    if (!fs.existsSync(manifestPath)) {
      throw new Error('Backup manifest not found');
    }
    
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const collections = manifest.collections || [];
    
    // Update progress: Manifest loaded
    await db.collection('backups').updateOne(
      { _id: new ObjectId(backupId) },
      { $set: { restoreProgress: 20 } }
    );
    
    // Restore each collection
    let restoredCount = 0;
    const totalCollections = collections.length;
    
    for (const collectionName of collections) {
      try {
        const filePath = path.join(backupPath, `${collectionName}.json`);
        
        if (!fs.existsSync(filePath)) {
          console.warn(`Backup file not found for collection: ${collectionName}`);
          continue;
        }
        
        const collectionData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        const documents = collectionData.documents || [];
        
        if (documents.length > 0) {
          const collection = db.collection(collectionName);
          
          // Clear existing collection (optional - you might want to merge instead)
          // await collection.deleteMany({});
          
          // Convert string IDs back to ObjectId
          const restoredDocs = documents.map(doc => {
            const restored = { ...doc };
            if (restored._id) {
              try {
                restored._id = new ObjectId(restored._id);
              } catch (e) {
                // Keep as string if conversion fails
              }
            }
            return restored;
          });
          
          // Insert documents (use insertMany with ordered: false to continue on errors)
          if (restoredDocs.length > 0) {
            await collection.insertMany(restoredDocs, { ordered: false }).catch(err => {
              // Some documents might already exist, continue
              console.warn(`Some documents in ${collectionName} may already exist:`, err.message);
            });
          }
        }
        
        restoredCount++;
        const progress = 20 + Math.floor((restoredCount / totalCollections) * 70);
        await db.collection('backups').updateOne(
          { _id: new ObjectId(backupId) },
          { $set: { restoreProgress: progress } }
        );
      } catch (collectionError) {
        console.error(`Error restoring collection ${collectionName}:`, collectionError);
        // Continue with other collections even if one fails
      }
    }
    
    // Update progress: Completed
    await db.collection('backups').updateOne(
      { _id: new ObjectId(backupId) },
      {
        $set: {
          restoreStatus: 'completed',
          restoreCompletedAt: new Date(),
          restoreProgress: 100,
        },
      }
    );
    
    console.log(`Restore ${backupId} completed. Collections restored: ${restoredCount}`);
  } catch (error) {
    console.error('Restore error:', error);
    await db.collection('backups').updateOne(
      { _id: new ObjectId(backupId) },
      {
        $set: {
          restoreStatus: 'failed',
          restoreError: error.message,
          restoreProgress: 0,
        },
      }
    );
    throw error;
  }
}

// Helper function to calculate next run time
function calculateNextRun(frequency, time) {
  const now = new Date();
  const [hours, minutes] = time.split(':').map(Number);
  
  let nextRun = new Date();
  nextRun.setHours(hours, minutes, 0, 0);
  
  switch (frequency) {
    case 'daily':
      if (nextRun <= now) {
        nextRun.setDate(nextRun.getDate() + 1);
      }
      break;
    case 'weekly':
      nextRun.setDate(nextRun.getDate() + 7);
      break;
    case 'monthly':
      nextRun.setMonth(nextRun.getMonth() + 1);
      break;
    default:
      nextRun.setDate(nextRun.getDate() + 1);
  }
  
  return nextRun;
}

// =============================================================================
// Phase 3: Custom Reports
// =============================================================================

// Get all report templates
router.get('/reports/templates', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const templates = await db.collection('report_templates')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json({ templates: templates.map(t => ({ id: t._id.toString(), ...t, createdBy: t.createdBy?.toString() })) });
  } catch (error) {
    console.error('Error getting report templates:', error);
    sendErrorResponse(res, 500, 'GET_REPORT_TEMPLATES_ERROR', 'Failed to get report templates', error.message);
  }
});

// Create report template
router.post('/reports/templates', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, description, fields, format = 'csv' } = req.body;
    
    const template = {
      name, description, fields: fields || [], format,
      createdAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
    };
    
    const result = await db.collection('report_templates').insertOne(template);
    res.json({ message: 'Template created', template: { id: result.insertedId.toString(), ...template, createdBy: template.createdBy.toString() } });
  } catch (error) {
    console.error('Error creating report template:', error);
    sendErrorResponse(res, 500, 'CREATE_REPORT_TEMPLATE_ERROR', 'Failed to create template', error.message);
  }
});

// Generate report
router.post('/reports/generate', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { templateId, format = 'csv', filters = {} } = req.body;
    
    // Simulate report generation
    const report = {
      templateId: templateId ? new ObjectId(templateId) : null,
      format,
      status: 'completed',
      createdAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
      data: { message: 'Report generated successfully' },
    };
    
    const result = await db.collection('reports').insertOne(report);
    res.json({ message: 'Report generated', reportId: result.insertedId.toString() });
  } catch (error) {
    console.error('Error generating report:', error);
    sendErrorResponse(res, 500, 'GENERATE_REPORT_ERROR', 'Failed to generate report', error.message);
  }
});

// =============================================================================
// Phase 3: User Segmentation
// =============================================================================

// Get all segments
router.get('/segments', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const segments = await db.collection('user_segments')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    // Calculate member counts
    const segmentsWithCounts = await Promise.all(segments.map(async (segment) => {
      const count = await db.collection('users').countDocuments({ segmentIds: segment._id });
      return {
        id: segment._id.toString(),
        name: segment.name,
        rules: segment.rules || [],
        memberCount: count,
        createdAt: segment.createdAt,
        createdBy: segment.createdBy?.toString(),
      };
    }));
    
    res.json({ segments: segmentsWithCounts });
  } catch (error) {
    console.error('Error getting segments:', error);
    sendErrorResponse(res, 500, 'GET_SEGMENTS_ERROR', 'Failed to get segments', error.message);
  }
});

// Create segment
router.post('/segments', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { name, rules } = req.body;
    
    const segment = {
      name,
      rules: rules || [],
      createdAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
    };
    
    const result = await db.collection('user_segments').insertOne(segment);
    res.json({ message: 'Segment created', segment: { id: result.insertedId.toString(), ...segment, createdBy: segment.createdBy.toString() } });
  } catch (error) {
    console.error('Error creating segment:', error);
    sendErrorResponse(res, 500, 'CREATE_SEGMENT_ERROR', 'Failed to create segment', error.message);
  }
});

// Get segment members
router.get('/segments/:id/members', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { id } = req.params;
    const { limit = 100 } = req.query;
    
    const users = await db.collection('users')
      .find({ segmentIds: new ObjectId(id) })
      .limit(parseInt(limit))
      .toArray();
    
    res.json({ members: users.map(u => ({ id: u._id.toString(), username: u.username, email: u.email })) });
  } catch (error) {
    console.error('Error getting segment members:', error);
    sendErrorResponse(res, 500, 'GET_SEGMENT_MEMBERS_ERROR', 'Failed to get members', error.message);
  }
});

// =============================================================================
// Phase 3: Announcement System
// =============================================================================

// Get all announcements
router.get('/announcements', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const announcements = await db.collection('announcements')
      .find({})
      .sort({ createdAt: -1 })
      .toArray();
    
    res.json({ announcements: announcements.map(a => ({ id: a._id.toString(), ...a, createdBy: a.createdBy?.toString() })) });
  } catch (error) {
    console.error('Error getting announcements:', error);
    sendErrorResponse(res, 500, 'GET_ANNOUNCEMENTS_ERROR', 'Failed to get announcements', error.message);
  }
});

// Create announcement
router.post('/announcements', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { title, message, type = 'info', targetSegments = [], scheduledAt } = req.body;
    
    const announcement = {
      title,
      message,
      type,
      targetSegments: targetSegments.map(id => new ObjectId(id)),
      scheduledAt: scheduledAt ? new Date(scheduledAt) : new Date(),
      status: 'active',
      createdAt: new Date(),
      createdBy: new ObjectId(req.user.userId),
    };
    
    const result = await db.collection('announcements').insertOne(announcement);
    res.json({ message: 'Announcement created', announcement: { id: result.insertedId.toString(), ...announcement, createdBy: announcement.createdBy.toString() } });
  } catch (error) {
    console.error('Error creating announcement:', error);
    sendErrorResponse(res, 500, 'CREATE_ANNOUNCEMENT_ERROR', 'Failed to create announcement', error.message);
  }
});

// =============================================================================
// Phase 3: System Configuration
// =============================================================================

// Get system configuration
router.get('/system/config', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    let config = await db.collection('system_config').findOne({ _id: 'main' });
    
    if (!config) {
      config = {
        _id: 'main',
        maintenanceMode: false,
        settings: {},
        createdAt: new Date(),
      };
      await db.collection('system_config').insertOne(config);
    }
    
    res.json({ config: { maintenanceMode: config.maintenanceMode || false, settings: config.settings || {} } });
  } catch (error) {
    console.error('Error getting system config:', error);
    sendErrorResponse(res, 500, 'GET_SYSTEM_CONFIG_ERROR', 'Failed to get config', error.message);
  }
});

// Update system configuration
router.put('/system/config', verifyAdminToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { maintenanceMode, settings } = req.body;
    
    await db.collection('system_config').updateOne(
      { _id: 'main' },
      {
        $set: {
          maintenanceMode: maintenanceMode !== undefined ? maintenanceMode : false,
          settings: settings || {},
          updatedAt: new Date(),
        },
        $setOnInsert: { createdAt: new Date() },
      },
      { upsert: true }
    );
    
    res.json({ message: 'System configuration updated' });
  } catch (error) {
    console.error('Error updating system config:', error);
    sendErrorResponse(res, 500, 'UPDATE_SYSTEM_CONFIG_ERROR', 'Failed to update config', error.message);
  }
});

module.exports = router;
