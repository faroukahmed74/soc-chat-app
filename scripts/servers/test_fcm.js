const axios = require('axios');

const BASE_URL = 'http://localhost:3000';

// Test data
const testNotification = {
  token: 'YOUR_FCM_TOKEN_HERE', // Replace with actual FCM token from your Flutter app
  title: '🧪 Test Notification',
  body: 'This is a test notification from your FCM server!',
  data: {
    type: 'test',
    timestamp: new Date().toISOString(),
    chatId: 'test-chat-123'
  }
};

const testTopicNotification = {
  topic: 'all_users',
  title: '📢 Broadcast Message',
  body: 'This is a broadcast notification to all users!',
  data: {
    type: 'broadcast',
    timestamp: new Date().toISOString()
  }
};

const testMulticastData = {
  tokens: [
    'TOKEN_1_HERE', // Replace with actual FCM tokens
    'TOKEN_2_HERE'
  ],
  title: '📤 Multicast Test',
  body: 'This notification is sent to multiple users!',
  data: {
    type: 'multicast',
    timestamp: new Date().toISOString()
  }
};

// Test functions
async function testHealth() {
  try {
    console.log('🏥 Testing health endpoint...');
    const response = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Health check passed:', response.data);
  } catch (error) {
    console.error('❌ Health check failed:', error.message);
  }
}

async function testSendNotification() {
  try {
    console.log('\n📨 Testing send notification...');
    const response = await axios.post(`${BASE_URL}/send-notification`, testNotification);
    console.log('✅ Notification sent:', response.data);
  } catch (error) {
    console.error('❌ Send notification failed:', error.response?.data || error.message);
  }
}

async function testSendTopicNotification() {
  try {
    console.log('\n📢 Testing topic notification...');
    const response = await axios.post(`${BASE_URL}/send-topic-notification`, testTopicNotification);
    console.log('✅ Topic notification sent:', response.data);
  } catch (error) {
    console.error('❌ Topic notification failed:', error.response?.data || error.message);
  }
}

async function testMulticast() {
  try {
    console.log('\n📤 Testing multicast...');
    const response = await axios.post(`${BASE_URL}/send-multicast`, testMulticastData);
    console.log('✅ Multicast sent:', response.data);
  } catch (error) {
    console.error('❌ Multicast failed:', error.response?.data || error.message);
  }
}

async function testSubscribeTopic() {
  try {
    console.log('\n➕ Testing topic subscription...');
    const response = await axios.post(`${BASE_URL}/subscribe-topic`, {
      tokens: ['TOKEN_1_HERE'], // Replace with actual token
      topic: 'test_topic'
    });
    console.log('✅ Topic subscription:', response.data);
  } catch (error) {
    console.error('❌ Topic subscription failed:', error.response?.data || error.message);
  }
}

// Run all tests
async function runAllTests() {
  console.log('🚀 Starting FCM Server Tests...\n');
  
  await testHealth();
  await testSendNotification();
  await testSendTopicNotification();
  await testMulticast();
  await testSubscribeTopic();
  
  console.log('\n✨ All tests completed!');
  console.log('\n📝 To get FCM tokens from your Flutter app:');
  console.log('1. Run your Flutter app');
  console.log('2. Check the console for FCM token logs');
  console.log('3. Replace "YOUR_FCM_TOKEN_HERE" in this file');
  console.log('4. Run the tests again');
}

// Run tests if this file is executed directly
if (require.main === module) {
  runAllTests().catch(console.error);
}

module.exports = {
  testHealth,
  testSendNotification,
  testSendTopicNotification,
  testMulticast,
  testSubscribeTopic
};
