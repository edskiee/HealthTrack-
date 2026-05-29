const http = require('http');

// Test admin login with detailed error handling
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/login',
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
    console.log('Admin login test completed');
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
  console.error(`Error code: ${e.code}`);
  console.error(`Stack trace: ${e.stack}`);
});

req.write(JSON.stringify({
  username: 'admin',
  password: 'test'
}));
req.end();