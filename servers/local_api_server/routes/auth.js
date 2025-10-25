const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { MongoClient, ObjectId } = require('mongodb');

// MongoDB connection
let db;
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';
// Ensure we use the same JWT secret as the main server
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_here';

// Connect to MongoDB
async function connectDB() {
  if (db) return db;
  try {
    const client = new MongoClient(mongoUri);
    await client.connect();
    db = client.db();
    return db;
  } catch (error) {
    // Fallback: if auth fails, try connecting without credentials to localhost
    if (error?.codeName === 'AuthenticationFailed' || error?.code === 18) {
      console.warn('Auth routes: Mongo auth failed, falling back to no-auth localhost connection');
      const fallbackUri = 'mongodb://localhost:27017/soc_chat_app';
      const client = new MongoClient(fallbackUri);
      await client.connect();
      db = client.db();
      return db;
    }
    throw error;
  }
}

// Register a new user
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    // Validate input
    if (!email || !password || !name) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    const database = await connectDB();
    const usersCollection = database.collection('users');
    
    // Check if user already exists
    const existingUser = await usersCollection.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }
    
    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    
    // Create user
    const newUser = {
      email,
      password: hashedPassword,
      name,
      role: 'user',
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await usersCollection.insertOne(newUser);
    
    // Create token
    const token = jwt.sign(
      { id: result.insertedId.toString(), role: 'user', email },
      JWT_SECRET,
      { expiresIn: '1d' }
    );
    
    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: result.insertedId.toString(),
        email,
        name,
        role: 'user'
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Login user
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Validate input
    if (!email || !password) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    const database = await connectDB();
    const usersCollection = database.collection('users');
    
    // Check if user exists
    const user = await usersCollection.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }
    
    // Check password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }
    
    // Create token
    const token = jwt.sign(
      { id: user._id.toString(), role: user.role || 'user', email: user.email },
      JWT_SECRET,
      { expiresIn: '1d' }
    );
    
    res.status(200).json({
      message: 'Login successful',
      token,
      user: {
        id: user._id.toString(),
        email: user.email,
        name: user.name,
        role: user.role || 'user'
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Get current user
router.get('/user', async (req, res) => {
  try {
    // Get token from header
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }
    
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    const database = await connectDB();
    const usersCollection = database.collection('users');
    
    // Get user
    const user = await usersCollection.findOne({ _id: new ObjectId(decoded.id) });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.status(200).json({
      user: {
        id: user._id.toString(),
        email: user.email,
        name: user.name,
        role: user.role || 'user'
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ message: 'Invalid token' });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

// Verify token validity
router.get('/verify', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }

    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);

    // Optionally check user existence
    const database = await connectDB();
    const usersCollection = database.collection('users');
    const user = await usersCollection.findOne({ _id: new ObjectId(decoded.id) });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json({ valid: true });
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ message: 'Invalid token' });
    }
    console.error('Verify token error:', error);
    return res.status(500).json({ message: 'Server error' });
  }
});

// Get user profile
router.get('/profile', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const database = await connectDB();
    const usersCollection = database.collection('users');
    
    const user = await usersCollection.findOne({ _id: new ObjectId(decoded.id) });
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Return user data without password
    const { password, ...userData } = user;
    res.json(userData);
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Update user profile
router.put('/profile', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ message: 'No token provided' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    const database = await connectDB();
    const usersCollection = database.collection('users');
    
    const { displayName, email, phone, bio, password } = req.body;
    
    // Validate required fields
    if (!displayName || !email) {
      return res.status(400).json({ message: 'Display name and email are required' });
    }

    // Check if email is already taken by another user
    const existingUser = await usersCollection.findOne({ 
      email: email,
      _id: { $ne: new ObjectId(decoded.id) }
    });
    
    if (existingUser) {
      return res.status(400).json({ message: 'Email is already taken' });
    }

    const updateData = {
      displayName: displayName.trim(),
      email: email.trim(),
      phone: phone?.trim() || '',
      bio: bio?.trim() || '',
      updatedAt: new Date()
    };

    // Hash password if provided
    if (password && password.trim() !== '') {
      const saltRounds = 10;
      updateData.password = await bcrypt.hash(password, saltRounds);
    }

    const result = await usersCollection.updateOne(
      { _id: new ObjectId(decoded.id) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Return updated user data
    const updatedUser = await usersCollection.findOne({ _id: new ObjectId(decoded.id) });
    const { password: _, ...userData } = updatedUser;
    
    res.json({
      message: 'Profile updated successfully',
      user: userData
    });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;