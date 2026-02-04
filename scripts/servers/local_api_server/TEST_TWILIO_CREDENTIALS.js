// Test Twilio Credentials
// This script tests if the Twilio credentials in .env are valid

require('dotenv').config();
const https = require('https');

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;

console.log('\n🔍 Testing Twilio Credentials...\n');

if (!accountSid || !authToken) {
  console.error('❌ ERROR: TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN not found in .env file!');
  console.error('   Make sure you have run SET_TWILIO_CREDENTIALS.ps1 or SET_TWILIO_CREDENTIALS.sh');
  process.exit(1);
}

console.log('✅ Credentials found in .env:');
console.log(`   Account SID: ${accountSid}`);
console.log(`   Auth Token: ${authToken.substring(0, 8)}...\n`);

console.log('🔵 Testing Twilio Token API...\n');

const auth = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
const options = {
  hostname: 'api.twilio.com',
  path: `/2010-04-01/Accounts/${accountSid}/Tokens.json`,
  method: 'POST',
  headers: {
    'Authorization': `Basic ${auth}`,
    'Content-Type': 'application/x-www-form-urlencoded',
  },
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
      if (res.statusCode === 200 || res.statusCode === 201) {
        const response = JSON.parse(data);
        if (response.ice_servers && response.ice_servers.length > 0) {
          console.log('✅ SUCCESS: Twilio Token API is working!');
          console.log(`   Generated ${response.ice_servers.length} TURN server(s)\n`);
          console.log('📋 TURN Servers:');
          response.ice_servers.forEach((server, index) => {
            console.log(`   ${index + 1}. ${server.url || server.urls}`);
            console.log(`      Username: ${server.username ? '✅ Present' : '❌ Missing'}`);
            console.log(`      Credential: ${server.credential ? '✅ Present' : '❌ Missing'}`);
          });
          console.log('\n✅ Credentials are valid and working!\n');
          process.exit(0);
        } else {
          console.error('❌ ERROR: Twilio API returned no ice_servers');
          console.error('   Response:', JSON.stringify(response, null, 2));
          process.exit(1);
        }
      } else {
        console.error(`❌ ERROR: Twilio API returned status ${res.statusCode}`);
        console.error('   Response:', data);
        if (res.statusCode === 401) {
          console.error('\n⚠️  This usually means:');
          console.error('   - Account SID is incorrect');
          console.error('   - Auth Token is incorrect');
          console.error('   - Account is suspended or inactive');
        }
        process.exit(1);
      }
    } catch (e) {
      console.error('❌ ERROR parsing response:', e.message);
      console.error('   Raw response:', data);
      process.exit(1);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ ERROR: Request failed:', e.message);
  console.error('   Check your internet connection');
  process.exit(1);
});

req.end();

