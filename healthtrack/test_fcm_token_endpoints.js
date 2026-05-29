const http = require('http');

console.log('Testing FCM Token Endpoints\n');

// Test 1: Check FCM token for user with token
console.log('Test 1: Check FCM token for user with token (ID: 1)');
const req1 = http.get('http://localhost:3000/auth/check-fcm-token/1', (res) => {
  console.log(`   Status: ${res.statusCode}`);
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log(`   Success: ${jsonData.success}`);
      console.log(`   Has Valid Token: ${jsonData.hasValidToken}`);
      console.log(`   Message: ${jsonData.message}`);
      if (jsonData.tokenLength) {
        console.log(`   Token Length: ${jsonData.tokenLength}`);
      }
    } catch (e) {
      console.log(`   Error parsing JSON: ${e.message}`);
    }
  });
});

req1.on('error', (e) => {
  console.log(`   Request error: ${e.message}`);
});

// Test 2: Check FCM token for user without token
setTimeout(() => {
  console.log('\nTest 2: Check FCM token for user without token (ID: 2)');
  const req2 = http.get('http://localhost:3000/auth/check-fcm-token/2', (res) => {
    console.log(`   Status: ${res.statusCode}`);
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const jsonData = JSON.parse(data);
        console.log(`   Success: ${jsonData.success}`);
        console.log(`   Has Valid Token: ${jsonData.hasValidToken}`);
        console.log(`   Message: ${jsonData.message}`);
      } catch (e) {
        console.log(`   Error parsing JSON: ${e.message}`);
      }
    });
  });

  req2.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 1000);

// Test 3: Check FCM token for non-existent user
setTimeout(() => {
  console.log('\nTest 3: Check FCM token for non-existent user (ID: 99999)');
  const req3 = http.get('http://localhost:3000/auth/check-fcm-token/99999', (res) => {
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

  req3.on('error', (e) => {
    console.log(`   Request error: ${e.message}`);
  });
}, 2000);