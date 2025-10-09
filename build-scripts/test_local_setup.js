// Local Database Setup Test Script
const axios = require('axios');
const { MongoClient } = require('mongodb');
const readline = require('readline');

// Configuration
const config = {
  apiUrl: 'http://localhost:3000', // Update with your actual server URL
  mongoUri: 'mongodb://localhost:27017/soc_chat_app',
  testUser: {
    email: 'test@example.com',
    password: 'Test123!',
    name: 'Test User'
  }
};

// MongoDB client
let mongoClient;
let db;

// Test results
const testResults = {
  mongodb: false,
  apiServer: false,
  authentication: false,
  userOperations: false,
  chatOperations: false,
  messageOperations: false,
  notificationServer: false
};

// Connect to MongoDB
async function testMongoConnection() {
  try {
    console.log('Testing MongoDB connection...');
    mongoClient = new MongoClient(config.mongoUri);
    await mongoClient.connect();
    db = mongoClient.db();
    
    // Check if we can query the database
    const collections = await db.listCollections().toArray();
    console.log(`✅ MongoDB connection successful. Found ${collections.length} collections.`);
    testResults.mongodb = true;
    return true;
  } catch (error) {
    console.error('❌ MongoDB connection failed:', error.message);
    return false;
  }
}

// Disconnect from MongoDB
async function disconnectFromMongo() {
  if (mongoClient) {
    await mongoClient.close();
    console.log('Disconnected from MongoDB');
  }
}

// Test API server connection
async function testApiServer() {
  try {
    console.log('\nTesting API server connection...');
    const response = await axios.get(`${config.apiUrl}/health`);
    if (response.status === 200) {
      console.log('✅ API server is running and responding');
      testResults.apiServer = true;
      return true;
    } else {
      console.error(`❌ API server responded with status: ${response.status}`);
      return false;
    }
  } catch (error) {
    console.error('❌ API server connection failed:', error.message);
    return false;
  }
}

// Test user registration
async function testUserRegistration() {
  try {
    console.log('\nTesting user registration...');
    
    // Check if test user already exists in the database
    const existingUser = await db.collection('users').findOne({ email: config.testUser.email });
    if (existingUser) {
      console.log('Test user already exists, skipping registration test');
      return true;
    }
    
    const response = await axios.post(`${config.apiUrl}/auth/register`, config.testUser);
    if (response.status === 201 || response.status === 200) {
      console.log('✅ User registration successful');
      return true;
    } else {
      console.error(`❌ User registration failed with status: ${response.status}`);
      return false;
    }
  } catch (error) {
    console.error('❌ User registration failed:', error.response?.data?.message || error.message);
    return false;
  }
}

// Test user login
async function testUserLogin() {
  try {
    console.log('\nTesting user login...');
    const response = await axios.post(`${config.apiUrl}/auth/login`, {
      email: config.testUser.email,
      password: config.testUser.password
    });
    
    if (response.status === 200 && response.data.token) {
      console.log('✅ User login successful');
      testResults.authentication = true;
      return response.data.token;
    } else {
      console.error(`❌ User login failed with status: ${response.status}`);
      return null;
    }
  } catch (error) {
    console.error('❌ User login failed:', error.response?.data?.message || error.message);
    return null;
  }
}

// Test user operations
async function testUserOperations(token) {
  try {
    console.log('\nTesting user operations...');
    const response = await axios.get(`${config.apiUrl}/auth/user`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    if (response.status === 200 && response.data.user) {
      console.log('✅ User fetch successful');
      console.log(`User details: ${response.data.user.name} (${response.data.user.email})`);
      testResults.userOperations = true;
      return response.data.user;
    } else {
      console.error(`❌ User fetch failed with status: ${response.status}`);
      return null;
    }
  } catch (error) {
    console.error('❌ User operations failed:', error.response?.data?.message || error.message);
    return null;
  }
}

// Test chat operations
async function testChatOperations(token, userId) {
  try {
    console.log('\nTesting chat operations...');
    
    // Create a test chat
    const createResponse = await axios.post(
      `${config.apiUrl}/chats`,
      { name: 'Test Chat', members: [userId] },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    if (createResponse.status !== 201 && createResponse.status !== 200) {
      console.error(`❌ Chat creation failed with status: ${createResponse.status}`);
      return null;
    }
    
    const chatId = createResponse.data.chat._id || createResponse.data.chat.id;
    console.log(`✅ Chat creation successful. Chat ID: ${chatId}`);
    
    // Get chat list
    const listResponse = await axios.get(
      `${config.apiUrl}/chats`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    if (listResponse.status === 200 && listResponse.data.chats) {
      console.log(`✅ Chat list fetch successful. Found ${listResponse.data.chats.length} chats.`);
      testResults.chatOperations = true;
      return chatId;
    } else {
      console.error(`❌ Chat list fetch failed with status: ${listResponse.status}`);
      return chatId; // Still return chatId for message testing
    }
  } catch (error) {
    console.error('❌ Chat operations failed:', error.response?.data?.message || error.message);
    return null;
  }
}

// Test message operations
async function testMessageOperations(token, chatId) {
  if (!chatId) {
    console.error('❌ Cannot test messages without a valid chat ID');
    return false;
  }
  
  try {
    console.log('\nTesting message operations...');
    
    // Send a test message
    const sendResponse = await axios.post(
      `${config.apiUrl}/messages`,
      { chatId, content: 'This is a test message', type: 'text' },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    if (sendResponse.status !== 201 && sendResponse.status !== 200) {
      console.error(`❌ Message sending failed with status: ${sendResponse.status}`);
      return false;
    }
    
    console.log('✅ Message sending successful');
    
    // Get messages for the chat
    const getResponse = await axios.get(
      `${config.apiUrl}/messages/${chatId}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    if (getResponse.status === 200 && getResponse.data.messages) {
      console.log(`✅ Message fetch successful. Found ${getResponse.data.messages.length} messages.`);
      testResults.messageOperations = true;
      return true;
    } else {
      console.error(`❌ Message fetch failed with status: ${getResponse.status}`);
      return false;
    }
  } catch (error) {
    console.error('❌ Message operations failed:', error.response?.data?.message || error.message);
    return false;
  }
}

// Test notification server
async function testNotificationServer(token) {
  try {
    console.log('\nTesting notification server...');
    
    // Check if notification endpoint exists
    const response = await axios.get(
      `${config.apiUrl}/notifications`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    if (response.status === 200) {
      console.log('✅ Notification server is accessible');
      testResults.notificationServer = true;
      return true;
    } else {
      console.error(`❌ Notification server check failed with status: ${response.status}`);
      return false;
    }
  } catch (error) {
    console.error('❌ Notification server check failed:', error.response?.data?.message || error.message);
    return false;
  }
}

// Print summary of test results
function printTestSummary() {
  console.log('\n=== TEST SUMMARY ===');
  console.log(`MongoDB Connection: ${testResults.mongodb ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`API Server: ${testResults.apiServer ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`Authentication: ${testResults.authentication ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`User Operations: ${testResults.userOperations ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`Chat Operations: ${testResults.chatOperations ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`Message Operations: ${testResults.messageOperations ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`Notification Server: ${testResults.notificationServer ? '✅ PASSED' : '❌ FAILED'}`);
  
  const passedTests = Object.values(testResults).filter(result => result).length;
  const totalTests = Object.keys(testResults).length;
  
  console.log(`\nOverall Result: ${passedTests}/${totalTests} tests passed`);
  
  if (passedTests === totalTests) {
    console.log('\n🎉 All tests passed! The local database setup is working correctly.');
  } else {
    console.log('\n⚠️ Some tests failed. Please check the logs above for details.');
  }
}

// Ask for server URL
async function promptForServerUrl() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  return new Promise(resolve => {
    rl.question(`Enter the API server URL [default: ${config.apiUrl}]: `, (answer) => {
      rl.close();
      if (answer.trim()) {
        config.apiUrl = answer.trim();
      }
      console.log(`Using API server URL: ${config.apiUrl}`);
      resolve();
    });
  });
}

// Main test function
async function runTests() {
  console.log('=== LOCAL DATABASE SETUP TEST ===');
  
  // Ask for server URL
  await promptForServerUrl();
  
  // Test MongoDB connection
  const mongoConnected = await testMongoConnection();
  if (!mongoConnected) {
    console.error('\n❌ Cannot proceed with tests without MongoDB connection');
    return;
  }
  
  // Test API server
  const apiServerRunning = await testApiServer();
  if (!apiServerRunning) {
    console.error('\n❌ Cannot proceed with tests without API server');
    await disconnectFromMongo();
    return;
  }
  
  // Test user registration
  await testUserRegistration();
  
  // Test user login
  const token = await testUserLogin();
  if (!token) {
    console.error('\n❌ Cannot proceed with tests without authentication');
    await disconnectFromMongo();
    return;
  }
  
  // Test user operations
  const user = await testUserOperations(token);
  if (!user) {
    console.error('\n❌ Cannot proceed with tests without user data');
    await disconnectFromMongo();
    return;
  }
  
  // Test chat operations
  const chatId = await testChatOperations(token, user._id || user.id);
  
  // Test message operations
  await testMessageOperations(token, chatId);
  
  // Test notification server
  await testNotificationServer(token);
  
  // Print test summary
  printTestSummary();
  
  // Disconnect from MongoDB
  await disconnectFromMongo();
}

// Run the tests
runTests().catch(error => {
  console.error('Test execution failed:', error);
  disconnectFromMongo().then(() => process.exit(1));
});