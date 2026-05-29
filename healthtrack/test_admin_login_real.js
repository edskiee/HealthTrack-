const http = require('http');
const crypto = require('crypto');

// Test admin login with real credentials
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
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`Response: ${data}`);
    console.log('Admin login test completed');
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

// Send admin login credentials (admin with password 'admin')
// The backend hashes the password with MD5
const hashedPassword = crypto.createHash("md5").update("admin").digest("hex");
console.log(`Hashed password: ${hashedPassword}`);

req.write(JSON.stringify({
  username: 'admin',
  password: 'admin'
}));
req.end();