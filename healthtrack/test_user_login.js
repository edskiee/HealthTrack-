const http = require('http');

// Test user login endpoint with actual credentials
const options = {
  hostname: '10.243.17.91',
  port: 3000,
  path: '/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  }
};

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`Response: ${data}`);
    console.log('User login test completed');
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

// Send test login credentials
req.write(JSON.stringify({
  username: 'testuser',
  password: 'testpass'
}));
req.end();