const http = require('http');

// Test the notifications endpoint
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/notifications',
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
};

console.log('Testing notifications endpoint: http://localhost:3000/admin/notifications');

const req = http.request(options, (res) => {
  console.log('Status code:', res.statusCode);
  console.log('Content-Type:', res.headers['content-type']);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    if (res.headers['content-type'] && res.headers['content-type'].includes('text/html')) {
      console.log('ERROR: Server returned HTML instead of JSON');
      console.log('Response body:', data);
    } else {
      console.log('SUCCESS: Server returned JSON');
      try {
        const jsonData = JSON.parse(data);
        console.log('Response data:', JSON.stringify(jsonData, null, 2));
      } catch (e) {
        console.log('Response body:', data);
      }
    }
  });
});

req.on('error', (e) => {
  console.error('ERROR: Failed to connect to server:', e.message);
});

req.end();