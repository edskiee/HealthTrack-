const http = require('http');

// Test the exact endpoint and data structure used by the frontend
const postData = JSON.stringify({
  userId: '1',
  patientId: '1',
  notificationType: 'custom_message',
  message: 'Test message from notification form',
  title: 'Custom Message'
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/notifications/send',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('Testing notification endpoint with exact frontend parameters...');
console.log('POST Data:', postData);

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