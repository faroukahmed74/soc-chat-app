/**
 * Detailed test of text model with longer timeout
 */

const http = require('http');

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');
const TEXT_MODEL = process.env.OLLAMA_MODEL || 'llama3.1';

console.log('🧪 Testing Text Model with Extended Timeout...\n');
console.log(`Host: ${OLLAMA_HOST}:${OLLAMA_PORT}`);
console.log(`Model: ${TEXT_MODEL}\n`);

function testTextModel() {
  return new Promise((resolve) => {
    console.log(`💬 Testing text model (${TEXT_MODEL})...`);
    console.log(`   Timeout: 120 seconds (2 minutes)`);
    console.log(`   This may take time if model needs to load...\n`);
    
    const requestData = JSON.stringify({
      model: TEXT_MODEL,
      messages: [{ role: 'user', content: 'Say "Hello" in one word.' }],
      stream: false,
      keep_alive: '2m',
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
      timeout: 120000 // 2 minutes
    };

    const startTime = Date.now();
    console.log(`⏱️  Starting request at ${new Date().toLocaleTimeString()}...`);
    
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { 
        data += chunk;
        const elapsed = Math.floor((Date.now() - startTime) / 1000);
        if (elapsed % 10 === 0 && elapsed > 0) {
          process.stdout.write(`\r⏳ Waiting... ${elapsed}s elapsed`);
        }
      });
      res.on('end', () => {
        const elapsed = Date.now() - startTime;
        console.log(`\n`);
        if (res.statusCode === 200) {
          try {
            const response = JSON.parse(data);
            const content = response.message?.content || '';
            console.log(`✅ Text model responded in ${(elapsed / 1000).toFixed(1)}s`);
            console.log(`   Response: "${content.trim()}"`);
            console.log(`   Total tokens: ${response.eval_count || 'N/A'}`);
            resolve(true);
          } catch (e) {
            console.error(`❌ Failed to parse response: ${e.message}`);
            console.log(`   Raw response: ${data.substring(0, 500)}`);
            resolve(false);
          }
        } else {
          console.error(`❌ Text model error: ${res.statusCode}`);
          console.log(`   Response: ${data.substring(0, 500)}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      const elapsed = (Date.now() - startTime) / 1000;
      console.error(`\n❌ Text model request error after ${elapsed.toFixed(1)}s: ${error.message}`);
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      const elapsed = (Date.now() - startTime) / 1000;
      console.error(`\n❌ Text model timeout after ${elapsed.toFixed(1)}s`);
      console.error(`   Model may be very slow or not responding`);
      console.error(`   Try: ollama run ${TEXT_MODEL} "test"`);
      resolve(false);
    });

    req.write(requestData);
    req.end();
  });
}

// Also check if Ollama is responding
function checkOllamaHealth() {
  return new Promise((resolve) => {
    console.log('🏥 Checking Ollama health...');
    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: '/api/tags',
      method: 'GET',
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      if (res.statusCode === 200) {
        console.log('✅ Ollama is running and responding\n');
        resolve(true);
      } else {
        console.log(`⚠️  Ollama returned status ${res.statusCode}\n`);
        resolve(false);
      }
    });

    req.on('error', (error) => {
      console.error(`❌ Cannot connect to Ollama: ${error.message}`);
      console.error(`   Make sure Ollama is running on ${OLLAMA_HOST}:${OLLAMA_PORT}\n`);
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      console.error(`❌ Ollama health check timeout\n`);
      resolve(false);
    });

    req.end();
  });
}

async function runTest() {
  const isHealthy = await checkOllamaHealth();
  if (!isHealthy) {
    process.exit(1);
  }
  
  const success = await testTextModel();
  if (success) {
    console.log('\n✅ Text model is working!\n');
  } else {
    console.log('\n❌ Text model test failed\n');
    process.exit(1);
  }
}

runTest();
