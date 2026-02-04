/**
 * Preload Ollama Model
 * This preloads the model into memory so first requests are faster
 * 
 * Usage: node scripts/preload-ollama-model.js
 */

const http = require('http');

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'llama3.1';

console.log('🔄 Preloading Ollama model...\n');
console.log(`Model: ${OLLAMA_MODEL}`);
console.log(`Host: ${OLLAMA_HOST}:${OLLAMA_PORT}\n`);

function preloadModel() {
  return new Promise((resolve, reject) => {
    const requestData = JSON.stringify({
      model: OLLAMA_MODEL,
      messages: [{ role: 'user', content: 'Hi' }],
      stream: false,
      options: {
        num_predict: 10 // Very short response just to load the model
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
      timeout: 300000 // 5 minutes for first load
    };

    console.log('⏳ Loading model into memory (this may take 1-2 minutes on first run)...\n');
    const startTime = Date.now();
    
    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const elapsed = Date.now() - startTime;
        try {
          if (res.statusCode === 200) {
            const response = JSON.parse(data);
            console.log(`✅ Model loaded successfully in ${(elapsed / 1000).toFixed(1)}s`);
            console.log(`   Response: "${response.message?.content || ''}"`);
            resolve(true);
          } else {
            console.error(`❌ Failed to load model: ${res.statusCode}`);
            console.error(`   Response: ${data.substring(0, 200)}`);
            reject(new Error(`HTTP ${res.statusCode}`));
          }
        } catch (error) {
          console.error(`❌ Error parsing response: ${error.message}`);
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      const elapsed = Date.now() - startTime;
      console.error(`❌ Request error after ${(elapsed / 1000).toFixed(1)}s: ${error.message}`);
      reject(error);
    });

    req.on('timeout', () => {
      const elapsed = Date.now() - startTime;
      console.error(`❌ Request timeout after ${(elapsed / 1000).toFixed(1)}s`);
      console.error('   Model loading is taking too long. This might indicate:');
      console.error('   - Ollama is not running properly');
      console.error('   - Model file is corrupted');
      console.error('   - System is out of memory');
      req.destroy();
      reject(new Error('Timeout'));
    });

    req.write(requestData);
    req.end();
  });
}

preloadModel()
  .then(() => {
    console.log('\n✅ Model preloaded! Future requests should be faster.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Failed to preload model:', error.message);
    process.exit(1);
  });
