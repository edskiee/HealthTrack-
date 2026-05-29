const http = require('http');

// Test the connection using the same URLs that the Flutter app would use
const testUrls = [
  'http://localhost:3000/admin/login',
  'http://127.0.0.1:3000/admin/login',
  'http://192.168.254.102:3000/admin/login', // The IP we configured in api_config.dart
  'http://10.243.17.91:3000/admin/login'     // ZeroTier IP
];

async function testUrl(url) {
  return new Promise((resolve) => {
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        console.log(`✅ SUCCESS - ${url}`);
        console.log(`   Status: ${res.statusCode}`);
        console.log(`   Response: ${data.substring(0, 100)}${data.length > 100 ? '...' : ''}`);
        resolve(true);
      });
    });

    req.on('error', (e) => {
      console.log(`❌ FAILED - ${url}`);
      console.log(`   Error: ${e.message}`);
      resolve(false);
    });

    req.write(JSON.stringify({
      username: 'edwin',
      password: 'admin'
    }));

    req.end();
  });
}

async function runTests() {
  console.log('Testing admin login connectivity from frontend...\n');
  
  for (const url of testUrls) {
    await testUrl(url);
    console.log(''); // Empty line for readability
  }
  
  console.log('Test completed.');
}

runTests();