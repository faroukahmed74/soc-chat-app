/**
 * Test Ollama Direct Connection
 * This tests if Ollama is actually responding to requests
 */

const http = require('http');

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');

console.log('🔍 Testing Ollama Direct Connection...\n');
console.log(`Host: ${OLLAMA_HOST}:${OLLAMA_PORT}\n`);

// Test 1: Check if Ollama API is accessible
function testOllamaHealth() {
  return new Promise((resolve) => {
    console.log('1. Testing Ollama health endpoint...');
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
            console.log('   ✅ Ollama API is accessible');
            console.log(`   📦 Models: ${models.models?.length || 0}`);
            if (models.models && models.models.length > 0) {
              models.models.forEach(m => {
                console.log(`      - ${m.name}`);
              });
            }
            resolve(true);
          } catch (e) {
            console.log('   ⚠️  Ollama responded but JSON parse failed');
            resolve(false);
          }
        } else {
          console.log(`   ❌ Ollama returned status: ${res.statusCode}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.log(`   ❌ Connection failed: ${error.message}`);
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      console.log('   ❌ Connection timeout');
      resolve(false);
    });

    req.end();
  });
}

// Test 2: Test a simple chat request
function testOllamaChat() {
  return new Promise((resolve) => {
    console.log('\n2. Testing Ollama chat endpoint (simple request)...');
    const requestData = JSON.stringify({
      model: 'llama3.1',
      messages: [{ role: 'user', content: 'Say hello' }],
      stream: false,
      options: {
        num_predict: 50 // Very short response
      }
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
      timeout: 60000 // 60 seconds
    };

    const startTime = Date.now();
    const req = http.request(options, (res) => {
      let data = '';
      console.log(`   Response status: ${res.statusCode}`);

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const elapsed = Date.now() - startTime;
        try {
          if (res.statusCode === 200) {
            const response = JSON.parse(data);
            const content = response.message?.content || '';
            console.log(`   ✅ Chat request succeeded in ${elapsed}ms`);
            console.log(`   Response: "${content.substring(0, 100)}..."`);
            resolve(true);
          } else {
            console.log(`   ❌ Chat request failed: ${res.statusCode}`);
            console.log(`   Response: ${data.substring(0, 200)}`);
            resolve(false);
          }
        } catch (error) {
          console.log(`   ❌ Error parsing response: ${error.message}`);
          console.log(`   Response data: ${data.substring(0, 200)}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      const elapsed = Date.now() - startTime;
      console.log(`   ❌ Request error after ${elapsed}ms: ${error.message}`);
      resolve(false);
    });

    req.on('timeout', () => {
      const elapsed = Date.now() - startTime;
      req.destroy();
      console.log(`   ❌ Request timeout after ${elapsed}ms`);
      console.log('   💡 This means Ollama is not responding. Possible causes:');
      console.log('      - Ollama service is not running');
      console.log('      - Model needs to be loaded (first request can take time)');
      console.log('      - Ollama is overloaded');
      resolve(false);
    });

    req.write(requestData);
    req.end();
  });
}

// Run tests
async function runTests() {
  const healthOk = await testOllamaHealth();
  
  if (healthOk) {
    await testOllamaChat();
  } else {
    console.log('\n❌ Ollama health check failed. Cannot test chat endpoint.');
    console.log('\n💡 Solutions:');
    console.log('   1. Make sure Ollama is running: ollama serve');
    console.log('   2. Check if Ollama service is started');
    console.log('   3. Try restarting Ollama');
  }
}

runTests().catch(console.error);
