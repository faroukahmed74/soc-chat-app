// Test All API Routes
const axios = require('axios');

const API_BASE_URL = 'http://localhost:3003';

async function testAPIRoutes() {
  console.log('🔍 Testing All API Routes...\n');
  
  try {
    // Test 1: Health Check
    console.log('1️⃣ Testing Health Check...');
    try {
      const healthResponse = await axios.get(`${API_BASE_URL}/health`);
      console.log('✅ Health Check:', healthResponse.status, healthResponse.data);
    } catch (error) {
      console.log('❌ Health Check failed:', error.message);
    }
    
    // Test 2: Register a test user
    console.log('\n2️⃣ Testing User Registration...');
    try {
      const registerResponse = await axios.post(`${API_BASE_URL}/api/auth/register`, {
        email: 'testuser@example.com',
        password: 'test123',
        name: 'Test User'
      });
      console.log('✅ User Registration:', registerResponse.status, registerResponse.data.message);
      
      // Store token for authenticated requests
      const token = registerResponse.data.token;
      
      // Test 3: Login
      console.log('\n3️⃣ Testing User Login...');
      try {
        const loginResponse = await axios.post(`${API_BASE_URL}/api/auth/login`, {
          email: 'testuser@example.com',
          password: 'test123'
        });
        console.log('✅ User Login:', loginResponse.status, loginResponse.data.message);
        
        // Update token
        const loginToken = loginResponse.data.token;
        
        // Test 4: Get Users (requires authentication)
        console.log('\n4️⃣ Testing Get Users (Authenticated)...');
        try {
          const usersResponse = await axios.get(`${API_BASE_URL}/api/users`, {
            headers: { 'Authorization': `Bearer ${loginToken}` }
          });
          console.log('✅ Get Users:', usersResponse.status, `Found ${usersResponse.data.length} users`);
          
          if (usersResponse.data.length > 0) {
            console.log('📝 Sample users:');
            usersResponse.data.slice(0, 3).forEach(user => {
              console.log(`   - ${user.email} (${user.name}) - Role: ${user.role || 'user'}`);
            });
          }
        } catch (error) {
          console.log('❌ Get Users failed:', error.response?.status, error.response?.data?.error || error.message);
        }
        
        // Test 5: Get Chats
        console.log('\n5️⃣ Testing Get Chats...');
        try {
          const chatsResponse = await axios.get(`${API_BASE_URL}/api/chats`, {
            headers: { 'Authorization': `Bearer ${loginToken}` }
          });
          console.log('✅ Get Chats:', chatsResponse.status, `Found ${chatsResponse.data.length} chats`);
        } catch (error) {
          console.log('❌ Get Chats failed:', error.response?.status, error.response?.data?.error || error.message);
        }
        
        // Test 6: Get Messages
        console.log('\n6️⃣ Testing Get Messages...');
        try {
          const messagesResponse = await axios.get(`${API_BASE_URL}/api/messages`, {
            headers: { 'Authorization': `Bearer ${loginToken}` }
          });
          console.log('✅ Get Messages:', messagesResponse.status, `Found ${messagesResponse.data.length} messages`);
        } catch (error) {
          console.log('❌ Get Messages failed:', error.response?.status, error.response?.data?.error || error.message);
        }
        
      } catch (error) {
        console.log('❌ User Login failed:', error.response?.status, error.response?.data?.message || error.message);
      }
      
    } catch (error) {
      console.log('❌ User Registration failed:', error.response?.status, error.response?.data?.message || error.message);
    }
    
    // Test 7: Test without authentication (should fail)
    console.log('\n7️⃣ Testing Unauthenticated Request (should fail)...');
    try {
      const unauthResponse = await axios.get(`${API_BASE_URL}/api/users`);
      console.log('❌ Unauthenticated request should have failed but got:', unauthResponse.status);
    } catch (error) {
      console.log('✅ Unauthenticated request correctly failed:', error.response?.status, error.response?.data?.error);
    }
    
  } catch (error) {
    console.error('❌ API Test failed:', error.message);
  }
}

// Run the test
testAPIRoutes();
