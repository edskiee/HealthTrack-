const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/notifications',
  method: 'GET',
  headers: {
    'Content-Type': 'application/json'
  }
};

console.log('Checking if notifications endpoint works...');

const req = http.request(options, (res) => {
  console.log(`Status code: ${res.statusCode}`);
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log('Response:', JSON.stringify(jsonData, null, 2));
    } catch (e) {
      console.log('Response body:', data);
    }
  });
});

req.on('error', (e) => {
  console.error('ERROR:', e.message);
});

req.end();