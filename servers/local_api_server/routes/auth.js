const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { MongoClient, ObjectId } = require('mongodb');
const { 
  validateUserRegistration, 
  validateUserLogin, 
  handleValidationErrors,
  sanitizeInput 
} = require('../middleware/validation');

// MongoDB connection
let db;
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/soc_chat_app';
const jwtSecret = process.env.JWT_SECRET || 'your_jwt_secret';

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
router.post('/register', sanitizeInput, validateUserRegistration, handleValidationErrors, async (req, res) => {
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
      displayName: name, // Add displayName for consistency
      role: 'user',
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await usersCollection.insertOne(newUser);
    
    // Create token
    const token = jwt.sign(
      { id: result.insertedId.toString() },
      jwtSecret,
      { expiresIn: '1d' }
    );
    
    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: result.insertedId.toString(),
        email,
        name,
        displayName: name,
        role: 'user',
        status: 'active'
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Login user
router.post('/login', sanitizeInput, validateUserLogin, handleValidationErrors, async (req, res) => {
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
      { id: user._id.toString() },
      jwtSecret,
      { expiresIn: '1d' }
    );
    
    res.status(200).json({
      message: 'Login successful',
      token,
      user: {
        id: user._id.toString(),
        email: user.email,
        name: user.name || user.displayName,
        displayName: user.displayName || user.name,
        role: user.role || 'user',
        status: user.status || 'active'
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
    const decoded = jwt.verify(token, jwtSecret);
    
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
        name: user.name || user.displayName,
        displayName: user.displayName || user.name,
        role: user.role || 'user',
        status: user.status || 'active'
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
    const decoded = jwt.verify(token, jwtSecret);

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

module.exports = router;