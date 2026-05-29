const http = require('http');
const https = require('https');

console.log('Testing Remove Invalid FCM Token Endpoint\n');

// Test: Remove invalid FCM token for user without token
const postData = JSON.stringify({
  userId: 2
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/auth/remove-invalid-fcm-token',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('Test: Remove invalid FCM token for user without token (ID: 2)');
const req = http.request(options, (res) => {
  console.log(`   Status: ${res.statusCode}`);
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log(`   Success: ${jsonData.success}`);
      console.log(`   Message: ${jsonData.message}`);
    } catch (e) {
      console.log(`   Error parsing JSON: ${e.message}`);
      console.log(`   Raw response: ${data}`);
    }
  });
});

req.on('error', (e) => {
  console.log(`   Request error: ${e.message}`);
});

req.write(postData);
req.end();