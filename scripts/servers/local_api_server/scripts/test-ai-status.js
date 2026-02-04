/**
 * Test AI Configuration Script
 * Run this to diagnose AI setup issues
 * 
 * Usage: node scripts/test-ai-status.js
 */

require('dotenv').config();
const http = require('http');
const { MongoClient, ObjectId } = require('mongodb');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017';
const DB_NAME = process.env.DB_NAME || 'soc_chat_app'; // Must match server.js database name
const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');

console.log('🔍 Testing AI Configuration...\n');

// Test 1: Check Ollama
async function testOllama() {
  return new Promise((resolve) => {
    console.log('1. Testing Ollama connection...');
    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: '/api/tags',
      method: 'GET',
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const models = JSON.parse(data);
            console.log('   ✅ Ollama is running');
            console.log(`   📦 Models available: ${models.models?.length || 0}`);
            if (models.models && models.models.length > 0) {
              models.models.forEach(m => {
                console.log(`      - ${m.name} (${(m.size / 1024 / 1024 / 1024).toFixed(2)} GB)`);
              });
            }
            resolve(true);
          } catch (e) {
            console.log('   ⚠️  Ollama responded but JSON parse failed');
            resolve(false);
          }
        } else {
          console.log(`   ❌ Ollama returned status: ${res.statusCode}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.log(`   ❌ Ollama connection failed: ${error.message}`);
      console.log(`   💡 Make sure Ollama is running: ollama serve`);
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      console.log('   ❌ Ollama connection timeout');
      resolve(false);
    });

    req.end();
  });
}

// Test 2: Check AI Bot User
async function testAIBotUser(client) {
  try {
    console.log('\n2. Testing AI Bot user...');
    const db = client.db(DB_NAME);
    const aiBot = await db.collection('users').findOne({ role: 'ai_bot' });
    
    if (aiBot) {
      console.log('   ✅ AI Bot user exists');
      console.log(`   📝 User ID: ${aiBot._id}`);
      console.log(`   📝 Display Name: ${aiBot.displayName || aiBot.username}`);
      console.log(`   📝 Email: ${aiBot.email}`);
      return true;
    } else {
      console.log('   ❌ AI Bot user not found');
      console.log('   💡 Run: node scripts/create-ai-bot.js');
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error checking AI Bot: ${error.message}`);
    return false;
  }
}

// Test 3: Check Environment Variables
function testEnvVars() {
  console.log('\n3. Testing environment variables...');
  const required = {
    'OLLAMA_HOST': process.env.OLLAMA_HOST || 'localhost (default)',
    'OLLAMA_PORT': process.env.OLLAMA_PORT || '11434 (default)',
    'OLLAMA_MODEL': process.env.OLLAMA_MODEL || 'llama3.2 (default)',
    'OLLAMA_VISION_MODEL': process.env.OLLAMA_VISION_MODEL || 'llava (default)',
  };
  
  let allOk = true;
  for (const [key, value] of Object.entries(required)) {
    if (value.includes('(default)')) {
      console.log(`   ⚠️  ${key}: ${value} (using default)`);
    } else {
      console.log(`   ✅ ${key}: ${value}`);
    }
  }
  
  // Check if model matches installed models
  const model = process.env.OLLAMA_MODEL || 'llama3.2';
  if (model === 'llama3.1') {
    console.log('   ✅ Model configured: llama3.1 (matches installed model)');
  } else if (model === 'llama3.2') {
    console.log('   ⚠️  Model configured: llama3.2 (but llama3.1 is installed)');
    console.log('   💡 Update .env: OLLAMA_MODEL=llama3.1');
  }
  
  return allOk;
}

// Main test
async function runTests() {
  let client;
  
  try {
    // Test Ollama
    const ollamaOk = await testOllama();
    
    // Test Environment
    testEnvVars();
    
    // Test Database
    console.log('\n4. Testing database connection...');
    client = new MongoClient(MONGODB_URI);
    await client.connect();
    console.log('   ✅ Database connected');
    
    const aiBotOk = await testAIBotUser(client);
    
    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 SUMMARY');
    console.log('='.repeat(50));
    console.log(`Ollama:        ${ollamaOk ? '✅ OK' : '❌ FAILED'}`);
    console.log(`AI Bot User:   ${aiBotOk ? '✅ OK' : '❌ FAILED'}`);
    console.log(`Database:      ✅ OK`);
    
    if (ollamaOk && aiBotOk) {
      console.log('\n✅ All checks passed! AI should be available.');
      console.log('💡 If still not working, check:');
      console.log('   1. Server is running on correct port (default: 3003)');
      console.log('   2. Client app is connecting to correct server URL');
      console.log('   3. Authentication token is valid');
    } else {
      console.log('\n❌ Some checks failed. Fix the issues above.');
    }
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
  } finally {
    if (client) {
      await client.close();
    }
  }
}

runTests().catch(console.error);
