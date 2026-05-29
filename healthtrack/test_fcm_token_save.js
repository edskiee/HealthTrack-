const http = require('http');

// Test saving an FCM token to a user
const fakeFcmToken = 'fake_test_token_abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ';

const postData = JSON.stringify({
  userId: '1',
  fcmToken: fakeFcmToken
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/auth/save-fcm-token',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('Testing FCM token save endpoint...');

const req = http.request(options, (res) => {
  console.log(`Status code: ${res.statusCode}`);
  console.log(`Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Response headers:', res.headers);
    console.log('Raw response body:', data);
    
    try {
      const jsonData = JSON.parse(data);
      console.log('Parsed JSON response:', JSON.stringify(jsonData, null, 2));
    } catch (e) {
      console.log('Failed to parse JSON:', e.message);
    }
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
});

req.write(postData);
req.end();