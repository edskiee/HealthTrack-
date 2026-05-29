const http = require('http');

console.log('Detailed Route Testing\n');

// Test 1: /admin/notifications
console.log('Test 1: GET /admin/notifications');
const test1 = http.get('http://localhost:3000/admin/notifications', (res) => {
  console.log(`   Status: ${res.statusCode}`);
  console.log(`   Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log(`   Response length: ${data.length} characters`);
    if (data.length < 500) {
      console.log(`   Full response: ${data}`);
    } else {
      console.log(`   First 200 chars: ${data.substring(0, 200)}`);
      console.log(`   Last 200 chars: ${data.substring(data.length - 200)}`);
    }
  });
});

test1.on('error', (e) => {
  console.log(`   Request error: ${e.message}`);
});

// Test 2: /admin/1 (valid admin ID)
setTimeout(() => {
  console.log('\nTest 2: GET /admin/1');
  const test2 = http.get('http://localhost:3000/admin/1', (res) => {
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

  test2.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 1500);

// Test 3: /admin/abc (invalid admin ID)
setTimeout(() => {
  console.log('\nTest 3: GET /admin/abc');
  const test3 = http.get('http://localhost:3000/admin/abc', (res) => {
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
      }
    });
  });

  test3.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 3000);