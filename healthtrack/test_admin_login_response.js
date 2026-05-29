const http = require('http');

// Test admin login with correct credentials
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
    console.log(`Response Length: ${data.length}`);
    
    // Try to parse JSON
    try {
      const jsonData = JSON.parse(data);
      console.log('Parsed JSON:', jsonData);
    } catch (parseError) {
      console.log('JSON Parse Error:', parseError.message);
    }
    
    console.log('Admin login test completed');
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