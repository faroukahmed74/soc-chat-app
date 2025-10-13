const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { MongoClient, ObjectId } = require('mongodb');

// MongoDB connection
let db;
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';
const jwtSecret = process.env.JWT_SECRET || 'your_jwt_secret_here';

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

// Create a new chat
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { name, members } = req.body;
    
    // Validate input
    if (!name || !members || !Array.isArray(members)) {
      return res.status(400).json({ message: 'Chat name and members array are required' });
    }
    
    const database = await connectDB();
    const chatsCollection = database.collection('chats');
    
    // Create chat
    const newChat = {
      name,
      members: members.map(id => new ObjectId(id)),
      createdBy: new ObjectId(req.user.id),
      createdAt: new Date(),
      updatedAt: new Date(),
      lastMessage: null
    };
    
    const result = await chatsCollection.insertOne(newChat);
    
    // Return the created chat
    const createdChat = await chatsCollection.findOne({ _id: result.insertedId });
    
    res.status(201).json({
      message: 'Chat created successfully',
      chat: {
        _id: createdChat._id.toString(),
        id: createdChat._id.toString(),
        name: createdChat.name,
        members: createdChat.members.map(id => id.toString()),
        createdBy: createdChat.createdBy.toString(),
        createdAt: createdChat.createdAt,
        updatedAt: createdChat.updatedAt,
        lastMessage: createdChat.lastMessage
      }
    });
  } catch (error) {
    console.error('Create chat error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get all chats for the authenticated user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const database = await connectDB();
    const chatsCollection = database.collection('chats');
    
    // Find chats where the user is a member
    const chats = await chatsCollection.find({
      members: new ObjectId(req.user.id)
    }).toArray();
    
    // Format the response
    const formattedChats = chats.map(chat => ({
      _id: chat._id.toString(),
      id: chat._id.toString(),
      name: chat.name,
      members: chat.members.map(id => id.toString()),
      createdBy: chat.createdBy.toString(),
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      lastMessage: chat.lastMessage
    }));
    
    res.status(200).json({
      chats: formattedChats
    });
  } catch (error) {
    console.error('Get chats error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get a specific chat by ID
router.get('/:chatId', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;
    
    // Validate ObjectId
    if (!ObjectId.isValid(chatId)) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }
    
    const database = await connectDB();
    const chatsCollection = database.collection('chats');
    
    // Find the chat and check if user is a member
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(chatId),
      members: new ObjectId(req.user.id)
    });
    
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found or access denied' });
    }
    
    res.status(200).json({
      chat: {
        _id: chat._id.toString(),
        id: chat._id.toString(),
        name: chat.name,
        members: chat.members.map(id => id.toString()),
        createdBy: chat.createdBy.toString(),
        createdAt: chat.createdAt,
        updatedAt: chat.updatedAt,
        lastMessage: chat.lastMessage
      }
    });
  } catch (error) {
    console.error('Get chat error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update a chat
router.put('/:chatId', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;
    const { name } = req.body;
    
    // Validate ObjectId
    if (!ObjectId.isValid(chatId)) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }
    
    if (!name) {
      return res.status(400).json({ message: 'Chat name is required' });
    }
    
    const database = await connectDB();
    const chatsCollection = database.collection('chats');
    
    // Update the chat (only if user is a member)
    const result = await chatsCollection.updateOne(
      {
        _id: new ObjectId(chatId),
        members: new ObjectId(req.user.id)
      },
      {
        $set: {
          name,
          updatedAt: new Date()
        }
      }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Chat not found or access denied' });
    }
    
    // Get the updated chat
    const updatedChat = await chatsCollection.findOne({ _id: new ObjectId(chatId) });
    
    res.status(200).json({
      message: 'Chat updated successfully',
      chat: {
        _id: updatedChat._id.toString(),
        id: updatedChat._id.toString(),
        name: updatedChat.name,
        members: updatedChat.members.map(id => id.toString()),
        createdBy: updatedChat.createdBy.toString(),
        createdAt: updatedChat.createdAt,
        updatedAt: updatedChat.updatedAt,
        lastMessage: updatedChat.lastMessage
      }
    });
  } catch (error) {
    console.error('Update chat error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Delete a chat
router.delete('/:chatId', authenticateToken, async (req, res) => {
  try {
    const { chatId } = req.params;
    
    // Validate ObjectId
    if (!ObjectId.isValid(chatId)) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }
    
    const database = await connectDB();
    const chatsCollection = database.collection('chats');
    const messagesCollection = database.collection('messages');
    
    // Check if user is the creator of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(chatId),
      createdBy: new ObjectId(req.user.id)
    });
    
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found or you are not authorized to delete it' });
    }
    
    // Delete all messages in the chat
    await messagesCollection.deleteMany({ chatId: new ObjectId(chatId) });
    
    // Delete the chat
    await chatsCollection.deleteOne({ _id: new ObjectId(chatId) });
    
    res.status(200).json({ message: 'Chat deleted successfully' });
  } catch (error) {
    console.error('Delete chat error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;