/**
 * Check if Ollama is running and accessible
 */

const http = require('http');

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = parseInt(process.env.OLLAMA_PORT || '11434');

console.log(`Checking Ollama at ${OLLAMA_HOST}:${OLLAMA_PORT}...`);

const options = {
  hostname: OLLAMA_HOST,
  port: OLLAMA_PORT,
  path: '/api/tags',
  method: 'GET',
  timeout: 5000
};

const req = http.request(options, (res) => {
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    if (res.statusCode === 200) {
      try {
        const models = JSON.parse(data);
        console.log('✅ Ollama is running!');
        console.log(`📦 Available models: ${models.models?.map(m => m.name).join(', ') || 'none'}`);
        
        const requiredModel = process.env.OLLAMA_MODEL || 'llama3.1';
        const hasModel = models.models?.some(m => m.name === requiredModel);
        
        if (hasModel) {
          console.log(`✅ Required model "${requiredModel}" is available`);
        } else {
          console.log(`⚠️  Required model "${requiredModel}" is NOT available`);
          console.log(`   Run: ollama pull ${requiredModel}`);
        }
      } catch (e) {
        console.log('✅ Ollama is running (but could not parse response)');
      }
    } else {
      console.log(`⚠️  Ollama responded with status ${res.statusCode}`);
    }
    process.exit(0);
  });
});

req.on('error', (error) => {
  console.error('❌ Cannot connect to Ollama!');
  console.error(`   Error: ${error.message}`);
  console.error(`   Make sure Ollama is running.`);
  console.error(`   On Windows, start it from the Start Menu or run: ollama serve`);
  process.exit(1);
});

req.on('timeout', () => {
  req.destroy();
  console.error('❌ Ollama connection timeout');
  console.error(`   Ollama is not responding at ${OLLAMA_HOST}:${OLLAMA_PORT}`);
  console.error(`   Make sure Ollama is running.`);
  process.exit(1);
});

req.end();
