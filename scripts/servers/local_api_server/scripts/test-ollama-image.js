/**
 * Test Ollama with an image to see if it responds
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');
const OLLAMA_VISION_MODEL = process.env.OLLAMA_VISION_MODEL || 'llava';

// Find a test image
const uploadsDir = path.join(__dirname, '..', 'uploads');
const testImagePath = path.join(uploadsDir, 'chat_media', '69676b96c6355ec1eb87e106', '1768400425391_image.jpg');

console.log('Testing Ollama image processing...');
console.log(`Model: ${OLLAMA_VISION_MODEL}`);
console.log(`Image path: ${testImagePath}`);

if (!fs.existsSync(testImagePath)) {
  console.error('❌ Test image not found:', testImagePath);
  process.exit(1);
}

const imageBuffer = fs.readFileSync(testImagePath);
const base64Image = imageBuffer.toString('base64');

console.log(`Image size: ${imageBuffer.length} bytes`);
console.log(`Base64 length: ${base64Image.length} characters`);

const requestData = JSON.stringify({
  model: OLLAMA_VISION_MODEL,
  messages: [
    {
      role: 'user',
      content: 'What is in this image?',
      images: [base64Image]
    }
  ],
  stream: false,
  options: {
    num_predict: 100
  }
});

console.log(`\nSending request to Ollama...`);
console.log(`Request size: ${Buffer.byteLength(requestData)} bytes`);

const options = {
  hostname: OLLAMA_HOST,
  port: OLLAMA_PORT,
  path: '/api/chat',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(requestData)
  },
  timeout: 180000 // 3 minutes
};

const startTime = Date.now();
const req = http.request(options, (res) => {
  let data = '';
  
  console.log(`Response status: ${res.statusCode}`);
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    const elapsed = Date.now() - startTime;
    console.log(`\nResponse received in ${elapsed}ms`);
    console.log(`Response length: ${data.length} bytes`);
    
    if (res.statusCode === 200) {
      try {
        const response = JSON.parse(data);
        console.log('\n✅ Success!');
        console.log(`Response: ${response.message?.content || 'No content'}`);
      } catch (e) {
        console.error('❌ Failed to parse response:', e.message);
        console.log('Response data:', data.substring(0, 500));
      }
    } else {
      console.error(`❌ Error: ${res.statusCode}`);
      console.log('Response:', data);
    }
    process.exit(0);
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error.message);
  process.exit(1);
});

req.on('timeout', () => {
  req.destroy();
  console.error('❌ Request timeout');
  process.exit(1);
});

req.write(requestData);
req.end();
