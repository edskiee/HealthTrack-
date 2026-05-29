const http = require('http');

console.log('Testing Admin Profile Fix\n');

// Test 1: Valid admin ID
console.log('Test 1: Valid admin ID (1)');
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

// Test 2: Invalid admin ID ("notifications")
setTimeout(() => {
  console.log('\nTest 2: Invalid admin ID ("notifications")');
  const invalidReq = http.get('http://localhost:3000/admin/notifications', (res) => {
    console.log(`   Status: ${res.statusCode}`);
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const jsonData = JSON.parse(data);
        console.log(`   Success: ${jsonData.success}`);
        console.log(`   Message: ${jsonData.message}`);
      } catch (e) {
        console.log(`   Error parsing JSON: ${e.message}`);
      }
    });
  });

  invalidReq.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 1000);

// Test 3: Admin notifications endpoint
setTimeout(() => {
  console.log('\nTest 3: Admin notifications endpoint');
  const notificationsReq = http.get('http://localhost:3000/admin/notifications', (res) => {
    console.log(`   Status: ${res.statusCode}`);
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const contentType = res.headers['content-type'];
        console.log(`   Content-Type: ${contentType}`);
        
        if (contentType && contentType.includes('application/json')) {
          const jsonData = JSON.parse(data);
          console.log(`   Success: ${jsonData.success}`);
          if (jsonData.data) {
            console.log(`   Notifications count: ${jsonData.data.length}`);
          }
        } else {
          console.log(`   Response (first 200 chars): ${data.substring(0, 200)}`);
        }
      } catch (e) {
        console.log(`   Error parsing JSON: ${e.message}`);
        console.log(`   Raw response: ${data.substring(0, 200)}`);
      }
    });
  });

  notificationsReq.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 2000);