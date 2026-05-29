const http = require('http');

// Test admin login with correct credentials to verify our fix
console.log('Testing admin login with username "edwin" and password "admin"...');

const options = {
  hostname: '10.243.17.91',
  port: 3000,
  path: '/admin/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  }
};

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  console.log(`Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`Response Body: ${data}`);
    
    // Try to parse JSON
    try {
      const jsonData = JSON.parse(data);
      console.log('✅ Successfully parsed JSON response:');
      console.log(JSON.stringify(jsonData, null, 2));
    } catch (parseError) {
      console.log('❌ JSON Parse Error:', parseError.message);
    }
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

// Send correct login credentials
req.write(JSON.stringify({
  username: 'edwin',
  password: 'admin'
}));
req.end();