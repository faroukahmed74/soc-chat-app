// Test login with newly created users
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
    console.log('Token:', response.data.token.substring(0, 50) + '...');
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
    
    return response.data.token;
    
  } catch (error) {
    console.log('❌ Login failed:', error.response?.data || error.message);
    return null;
  }
}

async function runTests() {
  console.log('=== Testing New Users ===\n');
  
  // Test with newly created users
  await testLogin('test2@soc.com', 'test123');
  console.log('\n---\n');
  
  await testLogin('john@soc.com', 'john123');
  console.log('\n---\n');
  
  await testLogin('jane@soc.com', 'jane123');
  console.log('\n---\n');
}

runTests();
