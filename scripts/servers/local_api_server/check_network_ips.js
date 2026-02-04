// Check what IPs are available on this machine
const os = require('os');

console.log('\n========================================');
console.log('  SOC Chat App - Network IP Checker');
console.log('========================================\n');

const networks = os.networkInterfaces();

const addresses = {
  ipv4: [],
  ipv6: []
};

for (const name of Object.keys(networks)) {
  for (const net of networks[name]) {
    // Skip internal and non-IPv4 addresses
    if (net.family === 'IPv4' && !net.internal) {
      addresses.ipv4.push(net.address);
    }
  }
}

console.log('🌐 Available Network IPs:\n');
addresses.ipv4.forEach((ip, i) => {
  console.log(`   ${i + 1}. ${ip}`);
});

console.log('\n📝 Use these IPs to access the app from other devices:\n');
addresses.ipv4.forEach(ip => {
  console.log(`   - Web App: http://${ip}:8082`);
});

console.log('\n⚠️  Important:');
console.log('   - Make sure API server is running on port 3003');
console.log('   - Make sure Web server is running on port 8082');
console.log('   - Both servers should listen on 0.0.0.0 (not just 127.0.0.1)');
console.log('   - Check Windows Firewall is not blocking ports 3003 and 8082\n');

