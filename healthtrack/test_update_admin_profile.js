const http = require('http');

// Test updating admin profile endpoint
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/1',
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json'
  }
};

const postData = JSON.stringify({
  full_name: 'System Administrator',
  email: 'admin@healthtrack.com'
});

console.log('Testing admin profile update endpoint...');
console.log('Connecting to:', `http://${options.hostname}:${options.port}${options.path}`);
console.log('Sending data:', postData);

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  console.log(`Headers: ${JSON.stringify(res.headers)}`);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Response Body:');
    console.log(data);
    
    try {
      const jsonData = JSON.parse(data);
      console.log('Parsed JSON:');
      console.log(JSON.stringify(jsonData, null, 2));
    } catch (error) {
      console.log('Error parsing JSON:', error.message);
    }
  });
});

req.on('error', (error) => {
  console.error('Request Error:', error.message);
  console.error('Make sure the server is running on port 3000');
});

// Set a timeout for the request
req.setTimeout(5000, () => {
  console.error('Request timed out after 5 seconds');
  req.destroy();
});

req.write(postData);
req.end();