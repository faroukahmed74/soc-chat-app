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
    const { chatId, content } = req.body;
    const type = (req.body.type || req.body.messageType || 'text');
    const mediaUrl = req.body.mediaUrl || req.body.media_url || null;
    
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
      mediaUrl: mediaUrl || '', // Always store mediaUrl, even if empty string
      createdAt: new Date(),
      updatedAt: new Date(),
      edited: false,
      readBy: [], // Initialize empty readBy array
      status: 'sent' // Initialize status as 'sent'
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
    
    // Get sender's display name for notifications
    const usersCollection = database.collection('users');
    const sender = await usersCollection.findOne({ _id: new ObjectId(req.user.id) });
    const senderName = sender?.displayName || sender?.username || 'Someone';
    
    // Get other chat members (not the sender) for FCM notifications
    const otherMembers = chat.members
      .filter(m => m.toString() !== req.user.id.toString())
      .map(m => m.toString());
    
    // Determine if this is a group chat
    const isGroupChat = chat.type === 'group' || chat.type === 'Group';
    const chatName = chat.name || 'Group';
    
    // Send FCM notifications to other members (only if they're offline)
    const sendFCMNotification = req.app.locals.sendFCMNotification;
    const io = req.app.get('io');
    
    if (sendFCMNotification && otherMembers.length > 0) {
      // Get list of online users via Socket.IO
      const onlineUsers = new Set();
      if (io) {
        try {
          const sockets = await io.fetchSockets();
          for (const socket of sockets) {
            if (socket.userId) {
              onlineUsers.add(socket.userId.toString());
            }
          }
        } catch (e) {
          console.warn('Error fetching online users:', e?.message || e);
        }
      }
      
      const title = isGroupChat ? chatName : senderName;
      const body = type === 'text' 
        ? (isGroupChat ? `${senderName}: ${content}` : content)
        : type === 'image' 
          ? (isGroupChat ? `${senderName} sent a photo` : '📷 Photo')
          : type === 'video'
            ? (isGroupChat ? `${senderName} sent a video` : '🎥 Video')
            : type === 'audio'
              ? (isGroupChat ? `${senderName} sent a voice message` : '🎤 Voice message')
              : (isGroupChat ? `${senderName} sent a ${type}` : `📎 ${type}`);
      
      for (const memberId of otherMembers) {
        const isOnline = onlineUsers.has(memberId);
        
        // Only send FCM if user is offline (to avoid duplicates with Socket.IO)
        if (!isOnline) {
          sendFCMNotification(
            memberId,
            title,
            body.length > 100 ? body.substring(0, 100) + '...' : body,
            {
              chatId: chatId.toString(),
              senderId: req.user.id.toString(),
              senderName: senderName,
              messageType: type || 'text',
              messageId: result.insertedId.toString(),
              type: isGroupChat ? 'group_message' : 'chat_message',
            }
          ).catch(err => {
            console.error(`Error sending FCM to user ${memberId}:`, err.message);
          });
        }
      }
    }
    
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
        mediaUrl: rewriteMediaUrlIfNeeded(createdMessage.mediaUrl || null, req),
        createdAt: createdMessage.createdAt,
        updatedAt: createdMessage.updatedAt,
        edited: createdMessage.edited || false,
        readBy: createdMessage.readBy ? createdMessage.readBy.map(id => id.toString()) : [],
        status: createdMessage.status || (createdMessage.readBy && createdMessage.readBy.length > 0 ? 'read' : 'sent')
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
    const cid = (req.params.chatId ?? '').toString().trim();
    const { page = 1, limit = 50 } = req.query;
    console.log('Messages GET debug:', {
      raw: req.params.chatId,
      cid,
      len: cid.length,
      regex24: /^[0-9a-fA-F]{24}$/.test(cid),
      userId: req.user?.id
    });
    
    // Validate and construct ObjectId safely
    let chatObjectId;
    try {
      chatObjectId = new ObjectId(cid);
    } catch (_) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }
    
    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');
    
    // Check if user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: chatObjectId,
      members: new ObjectId(req.user.id)
    });
    
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found or access denied' });
    }
    
    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    // Get messages for the chat
    const messages = await messagesCollection
      .find({ chatId: chatObjectId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    // Get total count for pagination
    const totalMessages = await messagesCollection.countDocuments({ chatId: chatObjectId });
    
    // Format the response - ensure all fields are included
    const formattedMessages = messages.map(msg => {
      const formatted = {
        _id: msg._id.toString(),
        id: msg._id.toString(),
        chatId: msg.chatId.toString(),
        senderId: msg.senderId.toString(),
        content: msg.content,
        type: msg.type || msg.messageType || 'text', // Include both type and messageType
        messageType: msg.messageType || msg.type || 'text', // Keep messageType for backward compatibility
        createdAt: msg.createdAt,
        updatedAt: msg.updatedAt,
        edited: msg.edited || false,
        readBy: msg.readBy ? msg.readBy.map(id => id.toString()) : [],
        status: msg.status || (msg.readBy && msg.readBy.length > 0 ? 'read' : 'sent')
      };
      
      // Ensure mediaUrl is included - check multiple possible field names
      // Always include mediaUrl field, even if empty, so the client can handle it
      if (msg.mediaUrl) {
        formatted.mediaUrl = rewriteMediaUrlIfNeeded(msg.mediaUrl, req);
      } else if (msg.media_url) {
        formatted.mediaUrl = rewriteMediaUrlIfNeeded(msg.media_url, req);
      } else if (msg.url) {
        formatted.mediaUrl = rewriteMediaUrlIfNeeded(msg.url, req);
      } else {
        // Include empty string so client knows mediaUrl field exists but is empty
        formatted.mediaUrl = '';
      }
      
      return formatted;
    });
    
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

// Mark messages as read for a chat
router.patch('/:chatId/read', authenticateToken, async (req, res) => {
  try {
    const cid = (req.params.chatId ?? '').toString().trim();
    const { messageIds } = req.body || {};

    // Validate chatId
    if (!cid || !/^[0-9a-fA-F]{24}$/.test(cid)) {
      return res.status(400).json({ message: 'Invalid chat ID' });
    }

    // Validate messageIds
    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ message: 'messageIds must be a non-empty array' });
    }

    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');

    // Verify user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(cid),
      members: new ObjectId(req.user.id)
    });

    if (!chat) {
      return res.status(404).json({ message: 'Chat not found or access denied' });
    }

    // Convert to ObjectId and filter invalid ids
    const validIds = messageIds
      .filter(id => ObjectId.isValid(id))
      .map(id => new ObjectId(id));

    if (validIds.length === 0) {
      return res.status(400).json({ message: 'No valid messageIds provided' });
    }

    const result = await messagesCollection.updateMany(
      { _id: { $in: validIds }, chatId: new ObjectId(cid) },
      { 
        $addToSet: { readBy: new ObjectId(req.user.id) }, 
        $set: { updatedAt: new Date() } 
      }
    );

    res.status(200).json({
      message: 'Messages marked as read',
      updatedCount: result.modifiedCount
    });
  } catch (error) {
    console.error('Mark messages as read error:', error);
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
        mediaUrl: rewriteMediaUrlIfNeeded(updatedMessage.mediaUrl || null, req),
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

// Reply to a message
// Accessible from both web (local network) and mobile (ngrok)
router.post('/:messageId/reply', authenticateToken, async (req, res) => {
  try {
    const { content, messageType, mediaUrl } = req.body;
    const userId = req.user.id;
    const messageId = req.params.messageId;

    if (!content && !mediaUrl) {
      return res.status(400).json({ error: 'Content or mediaUrl is required' });
    }

    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');
    const usersCollection = database.collection('users');

    // Get the original message
    const originalMessage = await messagesCollection.findOne({
      _id: new ObjectId(messageId)
    });

    if (!originalMessage) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Verify user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(originalMessage.chatId),
      members: new ObjectId(userId),
    });

    if (!chat) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get sender's display name
    const sender = await usersCollection.findOne({ _id: new ObjectId(userId) });
    const senderName = sender?.displayName || sender?.username || 'Someone';

    // Get original message sender name
    const originalSender = await usersCollection.findOne({ 
      _id: new ObjectId(originalMessage.senderId) 
    });
    const originalSenderName = originalSender?.displayName || originalSender?.username || 'Unknown';

    // Create reply message
    const replyMessage = {
      chatId: originalMessage.chatId,
      senderId: new ObjectId(userId),
      content: content || '',
      type: messageType || 'text',
      messageType: messageType || 'text',
      mediaUrl: mediaUrl || null,
      createdAt: new Date(),
      updatedAt: new Date(),
      readBy: [],
      status: 'sent',
      replies: [],
      reactions: {},
      replyTo: messageId,
      replyToContent: originalMessage.content?.substring(0, 100) || '',
      replyToSenderName: originalSenderName,
    };

    const result = await messagesCollection.insertOne(replyMessage);

    // Add reply reference to original message
    await messagesCollection.updateOne(
      { _id: new ObjectId(messageId) },
      { 
        $push: { 
          replies: {
            replyId: result.insertedId.toString(),
            senderId: userId,
            senderName: senderName,
            content: content || (mediaUrl ? 'Media' : ''),
            createdAt: new Date(),
          }
        },
        $set: { updatedAt: new Date() }
      }
    );

    // Update chat's last message
    const now = new Date();
    await chatsCollection.updateOne(
      { _id: new ObjectId(originalMessage.chatId) },
      { 
        $set: { 
          updatedAt: now,
          lastMessageTime: now,
          lastMessage: {
            content: content || (mediaUrl ? 'Media reply' : ''),
            senderId: userId,
            senderName: senderName,
            timestamp: now.toISOString(),
            createdAt: now,
          },
        }
      }
    );

    // Get other chat members (not the sender) for FCM notifications
    const otherMembers = chat.members
      .filter(m => m.toString() !== userId.toString())
      .map(m => m.toString());
    
    // Determine if this is a group chat
    const isGroupChat = chat.type === 'group' || chat.type === 'Group';
    const chatName = chat.name || 'Group';
    
    // Emit socket notification to ALL members (if io is available)
    try {
      const io = req.app.get('io');
      if (io) {
        // Emit to the entire chat room
        io.to(originalMessage.chatId.toString()).emit('new_message', {
          id: result.insertedId.toString(),
          _id: result.insertedId.toString(),
          chatId: originalMessage.chatId.toString(),
          senderId: userId.toString(),
          senderName: senderName,
          content: replyMessage.content,
          messageType: replyMessage.messageType,
          mediaUrl: rewriteMediaUrlIfNeeded(replyMessage.mediaUrl, req),
          createdAt: replyMessage.createdAt,
          replyTo: messageId,
          replyToContent: replyMessage.replyToContent,
          replyToSenderName: replyMessage.replyToSenderName,
          readBy: [],
          status: 'sent'
        });
        // Also emit to individual members to ensure delivery
        const memberIds = chat.members.map(m => m.toString());
        for (const memberId of memberIds) {
          io.to(memberId).emit('new_message', {
            id: result.insertedId.toString(),
            _id: result.insertedId.toString(),
            chatId: originalMessage.chatId.toString(),
            senderId: userId.toString(),
            senderName: senderName,
            content: replyMessage.content,
            messageType: replyMessage.messageType,
            mediaUrl: rewriteMediaUrlIfNeeded(replyMessage.mediaUrl, req),
            createdAt: replyMessage.createdAt,
            replyTo: messageId,
            replyToContent: replyMessage.replyToContent,
            replyToSenderName: replyMessage.replyToSenderName,
            readBy: [],
            status: 'sent'
          });
        }
      }
    } catch (socketErr) {
      console.warn('Socket emission failed:', socketErr?.message || socketErr);
    }
    
    // Send FCM notifications to other members (only if they're offline)
    const sendFCMNotification = req.app.locals.sendFCMNotification;
    const io = req.app.get('io');
    
    if (sendFCMNotification && otherMembers.length > 0) {
      // Get list of online users via Socket.IO
      const onlineUsers = new Set();
      if (io) {
        try {
          const sockets = await io.fetchSockets();
          for (const socket of sockets) {
            if (socket.userId) {
              onlineUsers.add(socket.userId.toString());
            }
          }
        } catch (e) {
          console.warn('Error fetching online users:', e?.message || e);
        }
      }
      
      const title = isGroupChat ? chatName : senderName;
      const replyBody = content || (mediaUrl ? 'Media reply' : 'Reply');
      const body = isGroupChat 
        ? `${senderName}: ${replyBody}`
        : replyBody;
      
      for (const memberId of otherMembers) {
        const isOnline = onlineUsers.has(memberId);
        
        // Only send FCM if user is offline (to avoid duplicates with Socket.IO)
        if (!isOnline) {
          sendFCMNotification(
            memberId,
            title,
            body.length > 100 ? body.substring(0, 100) + '...' : body,
            {
              chatId: originalMessage.chatId.toString(),
              senderId: userId.toString(),
              senderName: senderName,
              messageType: replyMessage.messageType || 'text',
              messageId: result.insertedId.toString(),
              replyTo: messageId,
              type: isGroupChat ? 'group_message' : 'chat_message',
            }
          ).catch(err => {
            console.error(`Error sending FCM to user ${memberId}:`, err.message);
          });
        }
      }
    }

    res.status(201).json({
      id: result.insertedId.toString(),
      _id: result.insertedId.toString(),
      chatId: originalMessage.chatId.toString(),
      senderId: userId.toString(),
      content: replyMessage.content,
      messageType: replyMessage.messageType,
      mediaUrl: rewriteMediaUrlIfNeeded(replyMessage.mediaUrl, req),
      createdAt: replyMessage.createdAt,
      replyTo: messageId,
      replyToContent: replyMessage.replyToContent,
      replyToSenderName: replyMessage.replyToSenderName,
      readBy: [],
      status: 'sent'
    });
  } catch (err) {
    console.error('Reply error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// React to a message (add or remove reaction)
// Accessible from both web (local network) and mobile (ngrok)
router.post('/:messageId/react', authenticateToken, async (req, res) => {
  try {
    const { emoji } = req.body;
    const userId = req.user.id;
    const messageId = req.params.messageId;

    if (!emoji) {
      return res.status(400).json({ error: 'Emoji is required' });
    }

    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');

    // Get the message
    const message = await messagesCollection.findOne({
      _id: new ObjectId(messageId)
    });

    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Verify user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(message.chatId),
      members: new ObjectId(userId),
    });

    if (!chat) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Initialize reactions if not exists
    const reactions = message.reactions || {};
    const emojiReactions = reactions[emoji] || [];

    // Toggle reaction (add if not exists, remove if exists)
    const userIdStr = userId.toString();
    const hasReacted = emojiReactions.includes(userIdStr);
    
    if (hasReacted) {
      // Remove reaction
      reactions[emoji] = emojiReactions.filter(id => id !== userIdStr);
      // Remove emoji key if no reactions left
      if (reactions[emoji].length === 0) {
        delete reactions[emoji];
      }
    } else {
      // Add reaction
      reactions[emoji] = [...emojiReactions, userIdStr];
    }

    // Update message
    await messagesCollection.updateOne(
      { _id: new ObjectId(messageId) },
      { 
        $set: { 
          reactions: reactions,
          updatedAt: new Date()
        }
      }
    );

    // Emit socket notification to ALL members of the chat (if io is available)
    try {
      const io = req.app.get('io');
      if (io) {
        // Emit to the entire chat room so all members receive the reaction update
        io.to(message.chatId.toString()).emit('message_reaction', {
          messageId: messageId,
          emoji: emoji,
          userId: userId.toString(),
          action: hasReacted ? 'removed' : 'added',
          reactions: reactions
        });
        // Also emit to individual members to ensure delivery
        const memberIds = chat.members.map(m => m.toString());
        for (const memberId of memberIds) {
          io.to(memberId).emit('message_reaction', {
            messageId: messageId,
            emoji: emoji,
            userId: userId.toString(),
            action: hasReacted ? 'removed' : 'added',
            reactions: reactions
          });
        }
      }
    } catch (socketErr) {
      console.warn('Socket emission failed:', socketErr?.message || socketErr);
    }

    res.status(200).json({
      success: true,
      messageId: messageId,
      emoji: emoji,
      action: hasReacted ? 'removed' : 'added',
      reactions: reactions
    });
  } catch (err) {
    console.error('Reaction error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get replies for a message
// Accessible from both web (local network) and mobile (ngrok)
router.get('/:messageId/replies', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const messageId = req.params.messageId;

    // Validate ObjectId
    if (!ObjectId.isValid(messageId)) {
      return res.status(400).json({ error: 'Invalid message ID' });
    }

    const database = await connectDB();
    const messagesCollection = database.collection('messages');
    const chatsCollection = database.collection('chats');

    // Get the original message
    const message = await messagesCollection.findOne({
      _id: new ObjectId(messageId)
    });

    if (!message) {
      return res.status(404).json({ error: 'Message not found' });
    }

    // Verify user is a member of the chat
    const chat = await chatsCollection.findOne({
      _id: new ObjectId(message.chatId),
      members: new ObjectId(userId),
    });

    if (!chat) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get all reply messages
    const replies = await messagesCollection
      .find({ replyTo: messageId })
      .sort({ createdAt: 1 })
      .toArray();

    // Format replies
    const formattedReplies = replies.map(reply => ({
      id: reply._id.toString(),
      _id: reply._id.toString(),
      chatId: reply.chatId.toString(),
      senderId: reply.senderId.toString(),
      senderName: reply.senderName || 'Unknown',
      content: reply.content,
      messageType: reply.messageType || reply.type || 'text',
      mediaUrl: rewriteMediaUrlIfNeeded(reply.mediaUrl, req),
      createdAt: reply.createdAt,
      replyTo: reply.replyTo,
      readBy: reply.readBy || [],
      status: reply.status || 'sent',
      reactions: reply.reactions || {}
    }));

    res.status(200).json({
      messageId: messageId,
      replies: formattedReplies
    });
  } catch (err) {
    console.error('Get replies error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;