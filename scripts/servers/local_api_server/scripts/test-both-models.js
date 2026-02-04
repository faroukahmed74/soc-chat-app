/**
 * Test both text and vision models to verify they're working
 */

const http = require('http');

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');
const TEXT_MODEL = process.env.OLLAMA_MODEL || 'llama3.1';
const VISION_MODEL = process.env.OLLAMA_VISION_MODEL || 'llava';

console.log('🧪 Testing Ollama Models...\n');
console.log(`Host: ${OLLAMA_HOST}:${OLLAMA_PORT}`);
console.log(`Text Model: ${TEXT_MODEL}`);
console.log(`Vision Model: ${VISION_MODEL}\n`);

// Test 1: Check available models
function checkAvailableModels() {
  return new Promise((resolve, reject) => {
    console.log('📋 Step 1: Checking available models...');
    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: '/api/tags',
      method: 'GET',
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const models = JSON.parse(data);
            const modelNames = models.models?.map(m => m.name) || [];
            console.log(`✅ Available models: ${modelNames.join(', ')}`);
            
            const hasTextModel = modelNames.some(name => name.includes(TEXT_MODEL.split(':')[0]));
            const hasVisionModel = modelNames.some(name => name.includes(VISION_MODEL.split(':')[0]));
            
            console.log(`   Text model (${TEXT_MODEL}): ${hasTextModel ? '✅ Available' : '❌ Not found'}`);
            console.log(`   Vision model (${VISION_MODEL}): ${hasVisionModel ? '✅ Available' : '❌ Not found'}`);
            
            resolve({ hasTextModel, hasVisionModel, modelNames });
          } catch (e) {
            console.error('❌ Failed to parse models:', e.message);
            reject(e);
          }
        } else {
          console.error(`❌ Error: ${res.statusCode}`);
          reject(new Error(`Status ${res.statusCode}`));
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Connection error:', error.message);
      reject(error);
    });

    req.on('timeout', () => {
      req.destroy();
      console.error('❌ Timeout');
      reject(new Error('Timeout'));
    });

    req.end();
  });
}

// Test 2: Test text model
function testTextModel() {
  return new Promise((resolve) => {
    console.log(`\n💬 Step 2: Testing text model (${TEXT_MODEL})...`);
    const requestData = JSON.stringify({
      model: TEXT_MODEL,
      messages: [{ role: 'user', content: 'Say "Hello" in one word.' }],
      stream: false,
      options: { num_predict: 10 }
    });

    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: '/api/chat',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestData)
      },
      timeout: 60000 // 1 minute
    };

    const startTime = Date.now();
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        const elapsed = Date.now() - startTime;
        if (res.statusCode === 200) {
          try {
            const response = JSON.parse(data);
            const content = response.message?.content || '';
            console.log(`✅ Text model responded in ${elapsed}ms`);
            console.log(`   Response: "${content.trim()}"`);
            resolve(true);
          } catch (e) {
            console.error(`❌ Failed to parse response: ${e.message}`);
            resolve(false);
          }
        } else {
          console.error(`❌ Text model error: ${res.statusCode}`);
          console.log(`   Response: ${data.substring(0, 200)}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.error(`❌ Text model request error: ${error.message}`);
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      console.error(`❌ Text model timeout (60s)`);
      resolve(false);
    });

    req.write(requestData);
    req.end();
  });
}

// Test 3: Test vision model (with empty image array to test if model loads)
function testVisionModel() {
  return new Promise((resolve) => {
    console.log(`\n👁️  Step 3: Testing vision model (${VISION_MODEL})...`);
    console.log(`   (Testing with empty image to verify model loads)`);
    
    const requestData = JSON.stringify({
      model: VISION_MODEL,
      messages: [{ role: 'user', content: 'Say "test"', images: [] }],
      stream: false,
      keep_alive: '1m',
      options: { num_predict: 5 }
    });

    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: '/api/chat',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(requestData)
      },
      timeout: 120000 // 2 minutes for vision model
    };

    const startTime = Date.now();
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        const elapsed = Date.now() - startTime;
        if (res.statusCode === 200) {
          try {
            const response = JSON.parse(data);
            const content = response.message?.content || '';
            console.log(`✅ Vision model responded in ${elapsed}ms`);
            console.log(`   Response: "${content.trim()}"`);
            resolve(true);
          } catch (e) {
            console.error(`❌ Failed to parse response: ${e.message}`);
            resolve(false);
          }
        } else {
          console.error(`❌ Vision model error: ${res.statusCode}`);
          console.log(`   Response: ${data.substring(0, 200)}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.error(`❌ Vision model request error: ${error.message}`);
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      console.error(`❌ Vision model timeout (120s) - Model may be very slow or not responding`);
      resolve(false);
    });

    req.write(requestData);
    req.end();
  });
}

// Run all tests
async function runTests() {
  try {
    const models = await checkAvailableModels();
    
    if (!models.hasTextModel) {
      console.log(`\n⚠️  Text model (${TEXT_MODEL}) not found. Run: ollama pull ${TEXT_MODEL}`);
    }
    if (!models.hasVisionModel) {
      console.log(`\n⚠️  Vision model (${VISION_MODEL}) not found. Run: ollama pull ${VISION_MODEL}`);
    }

    if (models.hasTextModel) {
      await testTextModel();
    }

    if (models.hasVisionModel) {
      await testVisionModel();
    }

    console.log('\n✅ Model testing complete!\n');
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    process.exit(1);
  }
}

runTests();
