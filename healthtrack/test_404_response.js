const http = require('http');

// Test what happens when we get a 404 response
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/notifications/send/nonexistent', // This should return 404
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  }
};

console.log('Testing 404 response scenario...');

const req = http.request(options, (res) => {
  console.log(`Status code: ${res.statusCode}`);
  console.log(`Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Raw response body:', data);
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
});

req.end();