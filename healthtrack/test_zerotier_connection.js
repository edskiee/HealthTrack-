/**
 * ZeroTier Connection Test Script
 * 
 * This script helps verify that your backend server is accessible 
 * through ZeroTier from your mobile device.
 */

const http = require('http');

// Configuration
const ZEROTIER_IP = '10.243.17.91'; // Replace with your actual ZeroTier IP
const PORT = 3000;

// Test endpoints that should be accessible
const testEndpoints = [
  '/',
  '/auth/check-username?username=test',
  '/auth/check-email?email=test@example.com'
];

console.log('🧪 ZeroTier Connection Test');
console.log('============================');
console.log(`Testing connection to: http://${ZEROTIER_IP}:${PORT}`);
console.log('');

// Function to test a single endpoint
function testEndpoint(endpoint) {
  return new Promise((resolve) => {
    const options = {
      hostname: ZEROTIER_IP,
      port: PORT,
      path: endpoint,
      method: 'GET',
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      console.log(`✅ ${endpoint} - Status: ${res.statusCode}`);
      resolve({ endpoint, success: true, status: res.statusCode });
    });

    req.on('error', (e) => {
      console.log(`❌ ${endpoint} - Error: ${e.message}`);
      resolve({ endpoint, success: false, error: e.message });
    });

    req.on('timeout', () => {
      console.log(`⏰ ${endpoint} - Timeout`);
      req.destroy();
      resolve({ endpoint, success: false, error: 'Timeout' });
    });

    req.end();
  });
}

// Run all tests
async function runTests() {
  console.log('Running connection tests...\n');
  
  const results = [];
  for (const endpoint of testEndpoints) {
    const result = await testEndpoint(endpoint);
    results.push(result);
    // Small delay between requests
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.log('\n📋 Test Results Summary:');
  console.log('======================');
  
  const successful = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  
  console.log(`Successful: ${successful}`);
  console.log(`Failed: ${failed}`);
  console.log(`Total: ${results.length}`);
  
  if (successful > 0) {
    console.log('\n🎉 Connection test passed! Your ZeroTier setup is working correctly.');
    console.log('You can now use your mobile app with the ZeroTier IP address.');
  } else {
    console.log('\n❌ Connection test failed. Please check:');
    console.log('1. Both devices are connected to the same ZeroTier network');
    console.log('2. Both devices are authorized on the network');
    console.log('3. Your backend server is running');
    console.log('4. Windows Firewall allows connections on port 3000');
    console.log('5. Your ZeroTier IP address is correct');
  }
}

// Run the tests
runTests();