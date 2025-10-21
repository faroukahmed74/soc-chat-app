// Create test users for SOC Chat App
const axios = require('axios');

const API_BASE = 'https://soc-chat-app.ngrok-free.app';

async function createUser(email, password, name, role = 'user') {
  try {
    console.log(`Creating user: ${email}`);
    
    const response = await axios.post(`${API_BASE}/api/auth/register`, {
      email: email,
      password: password,
      name: name,
      role: role
    }, {
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true'
      }
    });
    
    console.log('✅ User created successfully!');
    console.log('Token:', response.data.token);
    console.log('User:', response.data.user);
    return response.data;
    
  } catch (error) {
    if (error.response?.status === 400 && error.response?.data?.message === 'User already exists') {
      console.log('⚠️ User already exists:', email);
      return null;
    } else {
      console.log('❌ Failed to create user:', error.response?.data || error.message);
      return null;
    }
  }
}

async function createTestUsers() {
  console.log('=== Creating Test Users for SOC Chat App ===\n');
  
  // Create test users with known passwords
  const testUsers = [
    { email: 'admin@soc.com', password: 'admin123', name: 'Admin User', role: 'admin' },
    { email: 'farouk@soc.com', password: 'farouk123', name: 'Farouk Admin', role: 'admin' },
    { email: 'test1@soc.com', password: 'test123', name: 'Test User 1', role: 'user' },
    { email: 'test2@soc.com', password: 'test123', name: 'Test User 2', role: 'user' },
    { email: 'test3@soc.com', password: 'test123', name: 'Test User 3', role: 'user' },
    { email: 'john@soc.com', password: 'john123', name: 'John Doe', role: 'user' },
    { email: 'jane@soc.com', password: 'jane123', name: 'Jane Smith', role: 'user' }
  ];
  
  for (const user of testUsers) {
    await createUser(user.email, user.password, user.name, user.role);
    console.log('---\n');
  }
  
  console.log('=== Test Users Created ===');
  console.log('You can now login with these credentials:');
  console.log('Admin: admin@soc.com / admin123');
  console.log('Admin: farouk@soc.com / farouk123');
  console.log('Users: test1@soc.com / test123');
  console.log('Users: test2@soc.com / test123');
  console.log('Users: test3@soc.com / test123');
  console.log('Users: john@soc.com / john123');
  console.log('Users: jane@soc.com / jane123');
}

createTestUsers();
