const http = require('http');

// Test admin registration with actual credentials
console.log('Testing Admin Registration...');

const registerOptions = {
  hostname: '10.243.17.91',
  port: 3000,
  path: '/admin/register',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  }
};

const registerReq = http.request(registerOptions, (res) => {
  console.log(`Registration Status Code: ${res.statusCode}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`Registration Response: ${data}`);
    
    // Now test admin login
    console.log('\nTesting Admin Login...');
    
    const loginOptions = {
      hostname: '10.243.17.91',
      port: 3000,
      path: '/admin/login',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const loginReq = http.request(loginOptions, (res) => {
      console.log(`Login Status Code: ${res.statusCode}`);
      
      let loginData = '';
      res.on('data', (chunk) => {
        loginData += chunk;
      });
      
      res.on('end', () => {
        console.log(`Login Response: ${loginData}`);
        console.log('Full admin test completed');
      });
    });

    loginReq.on('error', (e) => {
      console.error(`Problem with login request: ${e.message}`);
    });

    // Send login credentials
    loginReq.write(JSON.stringify({
      username: 'testadmin',
      password: 'testpass123'
    }));
    loginReq.end();
  });
});

registerReq.on('error', (e) => {
  console.error(`Problem with registration request: ${e.message}`);
});

// Send registration credentials
registerReq.write(JSON.stringify({
  username: 'testadmin',
  password: 'testpass123'
}));
registerReq.end();