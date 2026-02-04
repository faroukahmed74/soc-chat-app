// Test the new streamlined system
const axios = require('axios');
const { MongoClient } = require('mongodb');

const API_BASE_URL = 'http://localhost:3003';
const NGROK_URL = 'https://soc-chat-app.ngrok-free.app';
const WEB_URL = 'http://localhost:8082';
const MONGO_URI = 'mongodb://localhost:27017/soc_chat_app';

async function testNewSystem() {
  console.log('🔍 Testing New Streamlined System...\n');
  
  const results = [];
  
  // Test 1: MongoDB Connection
  try {
    const client = new MongoClient(MONGO_URI);
    await client.connect();
    const db = client.db('soc_chat_app');
    const collections = await db.listCollections().toArray();
    results.push({ test: 'MongoDB Connection', status: 'PASS', message: `Connected - ${collections.length} collections found` });
    await client.close();
  } catch (error) {
    results.push({ test: 'MongoDB Connection', status: 'FAIL', message: error.message });
  }
  
  // Test 2: API Server
  try {
    const healthResponse = await axios.get(`${API_BASE_URL}/health`, { timeout: 5000 });
    results.push({ test: 'API Server', status: 'PASS', message: `Health check passed (${healthResponse.status})` });
  } catch (error) {
    results.push({ test: 'API Server', status: 'FAIL', message: `Cannot reach API server: ${error.message}` });
  }
  
  // Test 3: Web Server
  try {
    const webResponse = await axios.get(WEB_URL, { timeout: 5000 });
    results.push({ test: 'Web Server', status: 'PASS', message: `Web server responding (${webResponse.status})` });
  } catch (error) {
    results.push({ test: 'Web Server', status: 'FAIL', message: `Cannot reach web server: ${error.message}` });
  }
  
  // Test 4: ngrok Tunnel
  try {
    const ngrokResponse = await axios.get(`${NGROK_URL}/health`, { 
      timeout: 10000,
      headers: { 'ngrok-skip-browser-warning': 'true' }
    });
    results.push({ test: 'ngrok Tunnel', status: 'PASS', message: 'ngrok tunnel accessible' });
  } catch (error) {
    results.push({ test: 'ngrok Tunnel', status: 'FAIL', message: `ngrok tunnel issue: ${error.message}` });
  }
  
  // Test 5: Authentication Flow
  try {
    const registerResponse = await axios.post(`${API_BASE_URL}/api/auth/register`, {
      email: `testuser_${Date.now()}@example.com`,
      password: 'test123',
      name: 'Test User'
    });
    const token = registerResponse.data.token;
    
    const usersResponse = await axios.get(`${API_BASE_URL}/api/users`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    results.push({ test: 'Authentication Flow', status: 'PASS', message: `Auth working - ${usersResponse.data.length} users found` });
  } catch (error) {
    results.push({ test: 'Authentication Flow', status: 'FAIL', message: `Auth failed: ${error.message}` });
  }
  
  // Generate Report
  console.log('\n' + '='.repeat(60));
  console.log('📊 NEW SYSTEM TEST REPORT');
  console.log('='.repeat(60));
  
  const passed = results.filter(r => r.status === 'PASS').length;
  const failed = results.filter(r => r.status === 'FAIL').length;
  const total = results.length;
  
  console.log(`\n📈 SUMMARY: ${passed}/${total} tests passed (${Math.round((passed/total)*100)}%)`);
  
  results.forEach(result => {
    const icon = result.status === 'PASS' ? '✅' : '❌';
    console.log(`${icon} ${result.test}: ${result.message}`);
  });
  
  if (passed === total) {
    console.log('\n🎉 All systems operational! New streamlined system is working perfectly!');
  } else {
    console.log(`\n⚠️  ${failed} test(s) failed. Please check the services.`);
  }
  
  console.log('\n' + '='.repeat(60));
}

// Run the test
testNewSystem().catch(console.error);
