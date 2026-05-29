const http = require('http');

// Test admin registration with detailed error handling
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/register',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  }
};

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  console.log(`Headers: ${JSON.stringify(res.headers)}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`Response Body: ${data}`);
    console.log('Admin registration test completed');
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
  console.error(`Error code: ${e.code}`);
  console.error(`Stack trace: ${e.stack}`);
});

req.write(JSON.stringify({
  username: 'testuser' + Date.now(),
  password: 'testpass123'
}));
req.end();