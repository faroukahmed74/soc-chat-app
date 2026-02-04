// Quick test to verify FCM token endpoint is accessible
const http = require('http');

const testUrl = process.env.SERVER_URL || 'http://localhost:3003';
const endpoint = '/api/users/fcm-token';

console.log(`Testing FCM endpoint: ${testUrl}${endpoint}\n`);

// Test 1: Check if server is running
http.get(`${testUrl}/api/health`, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log('✅ Server is running');
    console.log(`   Health check response: ${data}\n`);
    
    // Test 2: Check endpoint exists (should return 401 without auth, not 404)
    const testReq = http.request(`${testUrl}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      }
    }, (testRes) => {
      let testData = '';
      testRes.on('data', (chunk) => { testData += chunk; });
      testRes.on('end', () => {
        if (testRes.statusCode === 401 || testRes.statusCode === 403) {
          console.log(`✅ Endpoint exists (requires authentication - status ${testRes.statusCode})`);
          console.log('   This is expected - endpoint is working correctly');
        } else if (testRes.statusCode === 404) {
          console.log(`❌ Endpoint not found (status ${testRes.statusCode})`);
          console.log('   The endpoint may not be registered');
        } else {
          console.log(`⚠️  Unexpected status: ${testRes.statusCode}`);
          console.log(`   Response: ${testData}`);
        }
      });
    });
    
    testReq.on('error', (err) => {
      console.error(`❌ Error testing endpoint: ${err.message}`);
    });
    
    testReq.write(JSON.stringify({
      userId: 'test',
      fcmToken: 'test'
    }));
    testReq.end();
  });
}).on('error', (err) => {
  console.error(`❌ Server is not running or not accessible: ${err.message}`);
  console.log(`\n💡 Make sure your server is running on ${testUrl}`);
});

