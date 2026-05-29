const http = require('http');

// Test connection to the auth endpoint
const options = {
  hostname: '10.243.17.91',
  port: 3000,
  path: '/auth/login',
  method: 'POST',
  timeout: 5000,
  headers: {
    'Content-Type': 'application/json'
  }
};

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  console.log(`Headers: ${JSON.stringify(res.headers, null, 2)}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`Response Body: ${data}`);
    console.log('Request completed successfully');
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.on('timeout', () => {
  console.error('Request timeout');
  req.destroy();
});

// Send empty body to test endpoint
req.write(JSON.stringify({}));
req.end();