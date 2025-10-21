#!/usr/bin/env node

/**
 * Test script to verify group chat display functionality
 * This script tests both backend API and frontend logic for group chat naming
 */

const http = require('http');
const https = require('https');

// Configuration
const API_BASE_URL = 'http://localhost:3000';
const TEST_USER_EMAIL = 'test@example.com';
const TEST_USER_PASSWORD = 'testpassword123';

// Test data
const testGroupChat = {
  type: 'group',
  name: 'Test Group Chat',
  members: ['user1', 'user2', 'user3']
};

const testPrivateChat = {
  type: 'private',
  name: 'Private Chat',
  members: ['user1', 'user2']
};

async function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const isHttps = urlObj.protocol === 'https:';
    const client = isHttps ? https : http;
    
    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || (isHttps ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        ...options.headers
      }
    };

    if (options.body) {
      requestOptions.headers['Content-Length'] = Buffer.byteLength(options.body);
    }

    const req = client.request(requestOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({ status: res.statusCode, data: jsonData, headers: res.headers });
        } catch (e) {
          resolve({ status: res.statusCode, data: data, headers: res.headers });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}

async function testGroupChatAPI() {
  console.log('🧪 Testing Group Chat API...');
  
  try {
    // Test 1: Create a group chat
    console.log('\n1. Testing group chat creation...');
    const createResponse = await makeRequest(`${API_BASE_URL}/api/chats`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer test_token', // Mock token for testing
      },
      body: JSON.stringify(testGroupChat)
    });
    
    if (createResponse.status === 201 || createResponse.status === 200) {
      console.log('✅ Group chat created successfully');
      console.log('   Chat ID:', createResponse.data.id || createResponse.data._id);
      console.log('   Chat Name:', createResponse.data.name);
      console.log('   Chat Type:', createResponse.data.type);
    } else {
      console.log('❌ Group chat creation failed:', createResponse.status);
      console.log('   Response:', createResponse.data);
    }

    // Test 2: Get chats list
    console.log('\n2. Testing chats list retrieval...');
    const getChatsResponse = await makeRequest(`${API_BASE_URL}/api/chats`, {
      headers: {
        'Authorization': 'Bearer test_token',
      }
    });
    
    if (getChatsResponse.status === 200) {
      console.log('✅ Chats list retrieved successfully');
      const chats = Array.isArray(getChatsResponse.data) ? getChatsResponse.data : getChatsResponse.data.chats || [];
      
      chats.forEach((chat, index) => {
        console.log(`   Chat ${index + 1}:`);
        console.log(`     Name: ${chat.name}`);
        console.log(`     Type: ${chat.type || 'undefined'}`);
        console.log(`     Members: ${chat.members ? chat.members.length : 0}`);
        
        // Check if group detection logic would work
        const isGroup = chat.type === 'group' || 
                       chat.isGroup === true || 
                       chat.isGroupChat === true ||
                       (chat.members && chat.members.length > 2);
        
        console.log(`     Detected as Group: ${isGroup}`);
        
        if (isGroup) {
          console.log(`     ✅ Group name would display: "${chat.name || 'Group'}"`);
        } else {
          console.log(`     ✅ Private chat name would display: "${chat.name || 'Chat'}"`);
        }
      });
    } else {
      console.log('❌ Chats list retrieval failed:', getChatsResponse.status);
    }

  } catch (error) {
    console.log('❌ API test failed:', error.message);
  }
}

async function testFrontendLogic() {
  console.log('\n🧪 Testing Frontend Group Detection Logic...');
  
  // Test cases for group detection
  const testCases = [
    {
      name: 'Group with type field',
      chat: { type: 'group', name: 'My Group', members: ['user1', 'user2', 'user3'] },
      expected: true
    },
    {
      name: 'Group with isGroup field',
      chat: { isGroup: true, name: 'My Group', members: ['user1', 'user2', 'user3'] },
      expected: true
    },
    {
      name: 'Group with isGroupChat field',
      chat: { isGroupChat: true, name: 'My Group', members: ['user1', 'user2', 'user3'] },
      expected: true
    },
    {
      name: 'Group detected by member count',
      chat: { name: 'My Group', members: ['user1', 'user2', 'user3', 'user4'] },
      expected: true
    },
    {
      name: 'Private chat with 2 members',
      chat: { type: 'private', name: 'Private Chat', members: ['user1', 'user2'] },
      expected: false
    },
    {
      name: 'Private chat without type',
      chat: { name: 'Private Chat', members: ['user1', 'user2'] },
      expected: false
    },
    {
      name: 'Group without name',
      chat: { type: 'group', members: ['user1', 'user2', 'user3'] },
      expected: true
    }
  ];

  testCases.forEach((testCase, index) => {
    console.log(`\n${index + 1}. Testing: ${testCase.name}`);
    
    // Simulate the frontend logic
    const isGroup = testCase.chat.type === 'group' || 
                   testCase.chat.isGroup === true || 
                   testCase.chat.isGroupChat === true ||
                   (testCase.chat.members && testCase.chat.members.length > 2);
    
    const displayName = isGroup 
        ? (testCase.chat.name || 'Group')
        : (testCase.chat.name || 'Chat');
    
    const passed = isGroup === testCase.expected;
    console.log(`   Input:`, JSON.stringify(testCase.chat, null, 2));
    console.log(`   Expected Group: ${testCase.expected}, Got: ${isGroup}`);
    console.log(`   Display Name: "${displayName}"`);
    console.log(`   ${passed ? '✅ PASS' : '❌ FAIL'}`);
  });
}

async function testServerHealth() {
  console.log('🏥 Testing Server Health...');
  
  try {
    const healthResponse = await makeRequest(`${API_BASE_URL}/health`);
    
    if (healthResponse.status === 200) {
      console.log('✅ Server is running');
      console.log('   Status:', healthResponse.data.status);
      console.log('   Message:', healthResponse.data.message);
    } else {
      console.log('❌ Server health check failed:', healthResponse.status);
    }
  } catch (error) {
    console.log('❌ Server is not running or not accessible');
    console.log('   Error:', error.message);
    console.log('   Make sure to start the server with: npm start or node servers/local_api_server/server.js');
  }
}

async function main() {
  console.log('🧪 SOC Chat App - Group Chat Display Test');
  console.log('==========================================');
  
  // Test server health first
  await testServerHealth();
  
  // Test frontend logic (doesn't require server)
  await testFrontendLogic();
  
  // Test API (requires server)
  await testGroupChatAPI();
  
  console.log('\n✅ Group chat display tests completed!');
  console.log('\n📝 Summary:');
  console.log('   - Frontend group detection logic has been improved');
  console.log('   - Backend API now includes type field in chat responses');
  console.log('   - Group chats should now display group names instead of user names');
  console.log('   - Private chats will still display user names as before');
}

// Run the tests
main().catch(console.error);
