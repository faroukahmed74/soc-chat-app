// Test login script for SOC Chat App
const axios = require('axios');

const API_BASE = 'https://soc-chat-app.ngrok-free.app';

async function testLogin(email, password) {
  try {
    console.log(`Testing login for: ${email}`);
    
    const response = await axios.post(`${API_BASE}/api/auth/login`, {
      email: email,
      password: password
    }, {
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true'
      }
    });
    
    console.log('✅ Login successful!');
    console.log('Token:', response.data.token);
    console.log('User:', response.data.user);
    
    // Test getting users with the token
    const usersResponse = await axios.get(`${API_BASE}/api/users`, {
      headers: {
        'Authorization': `Bearer ${response.data.token}`,
        'ngrok-skip-browser-warning': 'true'
      }
    });
    
    console.log('✅ Users fetched successfully!');
    console.log('Number of users:', usersResponse.data.length);
    console.log('Users:', usersResponse.data.map(u => ({ id: u._id, email: u.email, name: u.name || u.displayName })));
    
  } catch (error) {
    console.log('❌ Login failed:', error.response?.data || error.message);
  }
}

// Test with different credentials
async function runTests() {
  console.log('=== SOC Chat App Login Test ===\n');
  
  // Test with admin user
  await testLogin('admin@soc.com', 'admin123');
  console.log('\n---\n');
  
  // Test with farouk user
  await testLogin('farouk@soc.com', 'password123');
  console.log('\n---\n');
  
  // Test with test1 user
  await testLogin('test1@soc.com', 'password123');
  console.log('\n---\n');
}

runTests();
