/**
 * Script to create AI Bot user in the database
 * Run this once to set up the AI bot user
 * 
 * Usage: node scripts/create-ai-bot.js
 */

require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017';
const DB_NAME = process.env.DB_NAME || 'soc_chat_app'; // Must match server.js database name

const AI_BOT_EMAIL = 'ai-assistant@local';
const AI_BOT_PASSWORD = 'ai-bot-secure-password-' + Date.now(); // Unique password
const AI_BOT_DISPLAY_NAME = 'AI Assistant';
const AI_BOT_ROLE = 'ai_bot';

async function createAIBot() {
  let client;
  
  try {
    console.log('🤖 Creating AI Bot user...');
    console.log(`   MongoDB URI: ${MONGODB_URI}`);
    console.log(`   Database: ${DB_NAME}`);
    
    // Connect to MongoDB
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    console.log('✅ Connected to MongoDB');
    
    const db = client.db(DB_NAME);
    const usersCollection = db.collection('users');
    
    // Check if AI bot already exists
    const existingBot = await usersCollection.findOne({ role: AI_BOT_ROLE });
    if (existingBot) {
      console.log('⚠️  AI Bot user already exists!');
      console.log(`   User ID: ${existingBot._id}`);
      console.log(`   Display Name: ${existingBot.displayName || existingBot.username}`);
      console.log('\n   To recreate, delete the existing user first.');
      return;
    }
    
    // Create AI bot user
    const now = new Date();
    const aiBot = {
      email: AI_BOT_EMAIL,
      password: AI_BOT_PASSWORD, // Note: In production, hash this
      displayName: AI_BOT_DISPLAY_NAME,
      username: 'ai-assistant',
      role: AI_BOT_ROLE,
      status: 'active',
      isOnline: false,
      createdAt: now,
      updatedAt: now,
      lastSeen: now,
      phoneNumber: '',
      avatarUrl: null,
      // Mark as AI bot
      isAIBot: true,
      aiBotVersion: '1.0.0'
    };
    
    const result = await usersCollection.insertOne(aiBot);
    
    console.log('\n✅ AI Bot user created successfully!');
    console.log(`   User ID: ${result.insertedId}`);
    console.log(`   Display Name: ${aiBot.displayName}`);
    console.log(`   Email: ${aiBot.email}`);
    console.log(`   Role: ${aiBot.role}`);
    console.log('\n📝 Next steps:');
    console.log('   1. Add this user to chats where you want AI assistance');
    console.log('   2. Install and start Ollama: https://ollama.ai');
    console.log('   3. Pull a model: ollama pull llama3.2');
    console.log('   4. The AI will automatically respond to messages in chats where it is a member');
    console.log('\n⚠️  Note: The AI bot password is stored in plain text for this script.');
    console.log('   In production, ensure proper password hashing is used.');
    
  } catch (error) {
    console.error('❌ Error creating AI Bot:', error);
    process.exit(1);
  } finally {
    if (client) {
      await client.close();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the script
createAIBot().catch(console.error);
