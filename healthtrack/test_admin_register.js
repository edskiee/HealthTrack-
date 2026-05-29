const http = require('http');

// Test admin registration endpoint
const options = {
  hostname: '10.243.17.91',
  port: 3000,
  path: '/admin/register',
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
    console.log('Admin registration test completed');
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

// Send test data (empty to trigger validation error)
req.write(JSON.stringify({}));
req.end();