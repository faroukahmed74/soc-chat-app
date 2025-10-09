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

// Send a new message
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { chatId, content, type = 'text' } = req.body;
    
    // Validate input
    if (!chatId || !content) {
      return res.status(400).json({ message: 'Chat ID and content are required' });
    }
    
    // Validate ObjectId
    if (!ObjectId.isValid(chatId)) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }
    
    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');
    
    // Check if user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(req.user.id)
    });
    
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found or access denied' });
    }
    
    // Create message
    const newMessage = {
      chatId: new ObjectId(chatId),
      senderId: new ObjectId(req.user.id),
      content,
      type,
      createdAt: new Date(),
      updatedAt: new Date(),
      edited: false
    };
    
    const result = await messagesCollection.insertOne(newMessage);
    
    // Update chat's last message
    await chatsCollection.updateOne(
      { _id: new ObjectId(chatId) },
      {
        $set: {
          lastMessage: {
            content,
            senderId: new ObjectId(req.user.id),
            createdAt: new Date()
          },
          updatedAt: new Date()
        }
      }
    );
    
    // Return the created message
    const createdMessage = await messagesCollection.findOne({ _id: result.insertedId });
    
    res.status(201).json({
      message: 'Message sent successfully',
      messageData: {
        _id: createdMessage._id.toString(),
        id: createdMessage._id.toString(),
        chatId: createdMessage.chatId.toString(),
        senderId: createdMessage.senderId.toString(),
        content: createdMessage.content,
        type: createdMessage.type,
        createdAt: createdMessage.createdAt,
        updatedAt: createdMessage.updatedAt,
        edited: createdMessage.edited
      }
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get messages for a specific chat
router.get('/:chatId', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    
    // Validate ObjectId
    if (!ObjectId.isValid(chatId)) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }
    
    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');
    
    // Check if user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(req.user.id)
    });
    
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found or access denied' });
    }
    
    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    // Get messages for the chat
    const messages = await messagesCollection
      .find({ chatId: new ObjectId(chatId) })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    // Get total count for pagination
    const totalMessages = await messagesCollection.countDocuments({ chatId: new ObjectId(chatId) });
    
    // Format the response
    const formattedMessages = messages.map(msg => ({
      _id: msg._id.toString(),
      id: msg._id.toString(),
      chatId: msg.chatId.toString(),
      senderId: msg.senderId.toString(),
      content: msg.content,
      type: msg.type,
      createdAt: msg.createdAt,
      updatedAt: msg.updatedAt,
      edited: msg.edited
    }));
    
    res.status(200).json({
      messages: formattedMessages.reverse(), // Reverse to show oldest first
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(totalMessages / parseInt(limit)),
        totalMessages,
        hasMore: skip + messages.length < totalMessages
      }
    });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update a message
router.put('/:messageId', authenticateToken, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { content } = req.body;
    
    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ message: 'Invalid message ID' });
    }
    
    if (!content) {
      return res.status(400).json({ message: 'Content is required' });
    }
    
    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    
    // Update the message (only if user is the sender)
    const result = await messagesCollection.updateOne(
      {
        _id: new ObjectId(messageId),
        senderId: new ObjectId(req.user.id)
      },
      {
        $set: {
          content,
          updatedAt: new Date(),
          edited: true
        }
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Message not found or you are not authorized to edit it' });
    }
    
    // Get the updated message
    const updatedMessage = await messagesCollection.findOne({ _id: new ObjectId(messageId) });
    
    res.status(200).json({
      message: 'Message updated successfully',
      messageData: {
        _id: updatedMessage._id.toString(),
        id: updatedMessage._id.toString(),
        chatId: updatedMessage.chatId.toString(),
        senderId: updatedMessage.senderId.toString(),
        content: updatedMessage.content,
        type: updatedMessage.type,
        createdAt: updatedMessage.createdAt,
        updatedAt: updatedMessage.updatedAt,
        edited: updatedMessage.edited
      }
    });
  } catch (error) {
    console.error('Update message error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete a message
router.delete('/:messageId', authenticateToken, async (req, res) => {
  try {
    const { messageId } = req.params;
    
    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ message: 'Invalid message ID' });
    }
    
    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    
    // Delete the message (only if user is the sender)
    const result = await messagesCollection.deleteOne({
      _id: new ObjectId(messageId),
      senderId: new ObjectId(req.user.id)
    });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({ message: 'Message not found or you are not authorized to delete it' });
    }
    
    res.status(200).json({ message: 'Message deleted successfully' });
  } catch (error) {
    console.error('Delete message error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;