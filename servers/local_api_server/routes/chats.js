const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { MongoClient, ObjectId } = require('mongodb');

// MongoDB connection - use the shared database connection from server.js
let db;

// JWT secret - should match server.js
const jwtSecret = process.env.JWT_SECRET || 'your_jwt_secret_here';

// Initialize database connection from app context
function setDatabase(database) {
  db = database;
}

// Connect to MongoDB (fallback if not set)
async function connectDB(req) {
  // Try to get database from app.locals (set by server.js)
  if (req && req.app && req.app.locals && req.app.locals.db) {
    return req.app.locals.db;
  }
  
  // Use cached db if set by setDatabase()
  if (db) return db;
  
  // Final fallback: create own connection
  const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';
  const { MongoClient } = require('mongodb');
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
    const { type, name, members } = req.body;
    
    console.log('[routes/chats.js] POST /api/chats handler called');
    console.log('[routes/chats.js] Request body:', JSON.stringify(req.body, null, 2));
    
    // Validate members array
    if (!members || !Array.isArray(members)) {
      console.error('[routes/chats.js] Validation failed: invalid members array');
      return res.status(400).json({ error: 'Members array is required' });
    }
    
    // Handle empty name - generate default for private chats
    let chatName = name && typeof name === 'string' ? name.trim() : '';
    
    // If name is empty and this is a private chat, generate default name
    if (chatName.length === 0 && type === 'private' && members.length >= 1) {
      console.log('[routes/chats.js] Empty name detected, generating default for private chat');
      
      const database = await connectDB(req);
      const usersCollection = database.collection('users');
      
      // Get the other user (not the current user)
      const currentUserId = req.user.id;
      const otherUserId = members.find(id => id.toString() !== currentUserId.toString());
      
      if (otherUserId) {
        try {
          const otherUser = await usersCollection.findOne(
            { _id: new ObjectId(otherUserId) },
            { projection: { username: 1, displayName: 1, email: 1, name: 1 } }
          );
          
          if (otherUser) {
            const otherUserName = otherUser.displayName || 
                               otherUser.username || 
                               otherUser.name || 
                               (otherUser.email ? otherUser.email.split('@')[0] : null) || 
                               'User';
            chatName = `Chat with ${otherUserName}`;
            console.log('[routes/chats.js] Generated default name:', chatName);
          } else {
            chatName = 'Chat with User';
          }
        } catch (err) {
          console.error('[routes/chats.js] Error fetching user for default name:', err);
          chatName = 'Chat with User';
        }
      } else {
        chatName = 'Chat with User';
      }
    }
    
    // Final validation - ensure name is not empty
    if (!chatName || chatName.trim().length === 0) {
      chatName = type === 'private' ? 'Chat with User' : 'Group Chat';
    }
    
    const database = await connectDB(req);
    const chatsCollection = database.collection('chats');
    
    // For private chats, check if chat already exists
    if (type === 'private' && members.length === 2) {
      const memberIds = members.map(id => new ObjectId(id));
      const existingChat = await chatsCollection.findOne({
        type: 'private',
        members: { 
          $all: memberIds,
          $size: 2
        }
      });
      
      if (existingChat) {
        console.log('[routes/chats.js] Found existing private chat:', existingChat._id.toString());
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
    
    // Create chat
    const newChat = {
      type: type || 'group',
      name: chatName.trim(),
      members: members.map(id => new ObjectId(id)),
      createdBy: new ObjectId(req.user.id),
      createdAt: new Date(),
      updatedAt: new Date(),
      lastMessage: null,
      lastMessageTime: null
    };
    
    console.log('[routes/chats.js] Creating chat:', JSON.stringify({
      type: newChat.type,
      name: newChat.name,
      members: newChat.members.map(id => id.toString()),
      createdBy: newChat.createdBy.toString()
    }, null, 2));
    
    const result = await chatsCollection.insertOne(newChat);
    
    // Return the created chat
    const createdChat = await chatsCollection.findOne({ _id: result.insertedId });
    
    console.log('[routes/chats.js] Chat created successfully:', createdChat._id.toString());
    
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
  } catch (error) {
    console.error('[routes/chats.js] Create chat error:', error);
    console.error('[routes/chats.js] Error stack:', error.stack);
    res.status(500).json({ error: 'Server error: ' + error.message });
  }
});

// Get all chats for the authenticated user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const database = await connectDB(req);
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
      type: chat.type || 'group', // Default to 'group' for existing chats
      members: chat.members.map(id => id.toString()),
      createdBy: chat.createdBy.toString(),
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      lastMessage: chat.lastMessage,
      lastMessageTime: chat.lastMessageTime
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
    
    const database = await connectDB(req);
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
        type: chat.type || 'group',
        members: chat.members.map(id => id.toString()),
        memberRoles: chat.memberRoles || {},
        createdBy: chat.createdBy.toString(),
        createdAt: chat.createdAt,
        updatedAt: chat.updatedAt,
        lastMessage: chat.lastMessage,
        lastMessageTime: chat.lastMessageTime
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
    
    const database = await connectDB(req);
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
    
    const database = await connectDB(req);
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

// Export setDatabase function to allow server.js to inject database connection
router.setDatabase = setDatabase;