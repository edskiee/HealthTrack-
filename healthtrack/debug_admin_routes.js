const http = require('http');

console.log('Debugging Admin Routes\n');

// Test the problematic route directly
console.log('Test: GET /admin/notifications');
const req = http.get('http://localhost:3000/admin/notifications', (res) => {
  console.log(`   Status: ${res.statusCode}`);
  console.log(`   Headers:`, res.headers);
  
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log(`   Response body (first 500 chars):`, data.substring(0, 500));
    
    try {
      const jsonData = JSON.parse(data);
      console.log(`   Parsed JSON:`, JSON.stringify(jsonData, null, 2));
    } catch (e) {
      console.log(`   Not valid JSON. Error: ${e.message}`);
    }
  });
});

req.on('error', (e) => {
  console.log(`   Request error: ${e.message}`);
});