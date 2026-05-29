const http = require('http');

console.log('Testing Invalid Admin ID Validation\n');

// Test 1: Invalid admin ID ("notifications")
console.log('Test 1: Invalid admin ID ("notifications")');
const invalidReq = http.get('http://localhost:3000/admin/notifications', (res) => {
  console.log(`   Status: ${res.statusCode}`);
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log(`   Success: ${jsonData.success}`);
      console.log(`   Message: ${jsonData.message || 'No message'}`);
    } catch (e) {
      console.log(`   Error parsing JSON: ${e.message}`);
      console.log(`   Raw response: ${data.substring(0, 200)}`);
    }
  });
});

invalidReq.on('error', (e) => {
  console.log(`   Request error: ${e.message}`);
});

// Test 2: Another invalid admin ID ("abc")
setTimeout(() => {
  console.log('\nTest 2: Invalid admin ID ("abc")');
  const invalidReq2 = http.get('http://localhost:3000/admin/abc', (res) => {
    console.log(`   Status: ${res.statusCode}`);
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const jsonData = JSON.parse(data);
        console.log(`   Success: ${jsonData.success}`);
        console.log(`   Message: ${jsonData.message || 'No message'}`);
      } catch (e) {
        console.log(`   Error parsing JSON: ${e.message}`);
        console.log(`   Raw response: ${data.substring(0, 200)}`);
      }
    });
  });

  invalidReq2.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 1000);

// Test 3: Valid admin ID (should still work)
setTimeout(() => {
  console.log('\nTest 3: Valid admin ID (1)');
  const validReq = http.get('http://localhost:3000/admin/1', (res) => {
    console.log(`   Status: ${res.statusCode}`);
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const jsonData = JSON.parse(data);
        console.log(`   Success: ${jsonData.success}`);
        if (jsonData.admin) {
          console.log(`   Admin: ${jsonData.admin.username}`);
        }
      } catch (e) {
        console.log(`   Error parsing JSON: ${e.message}`);
      }
    });
  });

  validReq.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 2000);