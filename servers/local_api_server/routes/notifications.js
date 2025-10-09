const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { MongoClient, ObjectId } = require('mongodb');

// MongoDB connection
let db;
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';
const jwtSecret = process.env.JWT_SECRET || 'your_jwt_secret';

// Connect to MongoDB
async function connectDB() {
  if (db) return db;
  const client = new MongoClient(mongoUri);
  await client.connect();
  db = client.db();
  return db;
}

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) return res.status(401).json({ message: 'Access denied' });
  
  jwt.verify(token, jwtSecret, (err, user) => {
    if (err) return res.status(403).json({ message: 'Invalid token' });
    req.user = user;
    next();
  });
};

// Get all notifications for the authenticated user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 20, unreadOnly = false } = req.query;
    
    const database = await connectDB();
    const notificationsCollection = database.collection('notifications');
    
    // Build query
    const query = { userId: new ObjectId(req.user.id) };
    if (unreadOnly === 'true') {
      query.read = false;
    }
    
    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    // Get notifications
    const notifications = await notificationsCollection
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    // Get total count
    const totalNotifications = await notificationsCollection.countDocuments(query);
    
    // Format the response
    const formattedNotifications = notifications.map(notification => ({
      _id: notification._id.toString(),
      id: notification._id.toString(),
      userId: notification.userId.toString(),
      type: notification.type,
      title: notification.title,
      message: notification.message,
      data: notification.data || {},
      read: notification.read,
      createdAt: notification.createdAt
    }));
    
    res.status(200).json({
      notifications: formattedNotifications,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(totalNotifications / parseInt(limit)),
        totalNotifications,
        hasMore: skip + notifications.length < totalNotifications
      }
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create a new notification
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { userId, type, title, message, data = {} } = req.body;
    
    // Validate input
    if (!userId || !type || !title || !message) {
      return res.status(400).json({ message: 'User ID, type, title, and message are required' });
    }
    
    // Validate ObjectId
    if (!ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user ID' });
    }
    
    const database = await connectDB();
    const notificationsCollection = database.collection('notifications');
    
    // Create notification
    const newNotification = {
      userId: new ObjectId(userId),
      type,
      title,
      message,
      data,
      read: false,
      createdAt: new Date()
    };
    
    const result = await notificationsCollection.insertOne(newNotification);
    
    // Return the created notification
    const createdNotification = await notificationsCollection.findOne({ _id: result.insertedId });
    
    res.status(201).json({
      message: 'Notification created successfully',
      notification: {
        _id: createdNotification._id.toString(),
        id: createdNotification._id.toString(),
        userId: createdNotification.userId.toString(),
        type: createdNotification.type,
        title: createdNotification.title,
        message: createdNotification.message,
        data: createdNotification.data,
        read: createdNotification.read,
        createdAt: createdNotification.createdAt
      }
    });
  } catch (error) {
    console.error('Create notification error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark a notification as read
router.put('/:notificationId/read', authenticateToken, async (req, res) => {
  try {
    const { notificationId } = req.params;
    
    // Validate ObjectId
    if (!ObjectId.isValid(notificationId)) {
      return res.status(400).json({ message: 'Invalid notification ID' });
    }
    
    const database = await connectDB();
    const notificationsCollection = database.collection('notifications');
    
    // Update the notification (only if it belongs to the user)
    const result = await notificationsCollection.updateOne(
      {
        _id: new ObjectId(notificationId),
        userId: new ObjectId(req.user.id)
      },
      {
        $set: { read: true }
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Notification not found or access denied' });
    }
    
    res.status(200).json({ message: 'Notification marked as read' });
  } catch (error) {
    console.error('Mark notification as read error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Mark all notifications as read for the user
router.put('/read-all', authenticateToken, async (req, res) => {
  try {
    const database = await connectDB();
    const notificationsCollection = database.collection('notifications');
    
    // Update all unread notifications for the user
    const result = await notificationsCollection.updateMany(
      {
        userId: new ObjectId(req.user.id),
        read: false
      },
      {
        $set: { read: true }
      }
    );
    
    res.status(200).json({ 
      message: 'All notifications marked as read',
      updatedCount: result.modifiedCount
    });
  } catch (error) {
    console.error('Mark all notifications as read error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete a notification
router.delete('/:notificationId', authenticateToken, async (req, res) => {
  try {
    const { notificationId } = req.params;
    
    // Validate ObjectId
    if (!ObjectId.isValid(notificationId)) {
      return res.status(400).json({ message: 'Invalid notification ID' });
    }
    
    const database = await connectDB();
    const notificationsCollection = database.collection('notifications');
    
    // Delete the notification (only if it belongs to the user)
    const result = await notificationsCollection.deleteOne({
      _id: new ObjectId(notificationId),
      userId: new ObjectId(req.user.id)
    });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({ message: 'Notification not found or access denied' });
    }
    
    res.status(200).json({ message: 'Notification deleted successfully' });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get notification count (total and unread)
router.get('/count', authenticateToken, async (req, res) => {
  try {
    const database = await connectDB();
    const notificationsCollection = database.collection('notifications');
    
    const userId = new ObjectId(req.user.id);
    
    // Get total and unread counts
    const [totalCount, unreadCount] = await Promise.all([
      notificationsCollection.countDocuments({ userId }),
      notificationsCollection.countDocuments({ userId, read: false })
    ]);
    
    res.status(200).json({
      total: totalCount,
      unread: unreadCount
    });
  } catch (error) {
    console.error('Get notification count error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;