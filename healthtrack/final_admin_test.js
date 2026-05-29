const http = require('http');

// Final test for admin login
console.log('Testing admin login with username "edwin" and password "admin"...');

const postData = JSON.stringify({
  username: 'edwin',
  password: 'admin'
});

const options = {
  hostname: '10.243.17.91',
  port: 3000,
  path: '/admin/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
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
    console.log(`Response Body: "${data}"`);
    console.log(`Response Length: ${data.length}`);
    
    if (data.length > 0) {
      try {
        const jsonData = JSON.parse(data);
        console.log('✅ Successfully parsed JSON:');
        console.log(JSON.stringify(jsonData, null, 2));
      } catch (error) {
        console.log('❌ Failed to parse JSON:', error.message);
      }
    } else {
      console.log('❌ Empty response body');
    }
  });
});

req.on('error', (e) => {
  console.error(`Request error: ${e.message}`);
});

req.write(postData);
req.end();