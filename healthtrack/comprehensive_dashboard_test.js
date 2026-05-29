const http = require('http');

// Test all dashboard and admin endpoints to verify they return proper JSON
const tests = [
  {
    name: 'Dashboard Stats',
    path: '/dashboard/stats',
    expectedKeys: ['success', 'data']
  },
  {
    name: 'Recent Activities',
    path: '/dashboard/activities',
    expectedKeys: ['success', 'data', 'count']
  },
  {
    name: 'Today\'s Appointments',
    path: '/dashboard/appointments',
    expectedKeys: ['success', 'data', 'count']
  },
  {
    name: 'Admin Notifications',
    path: '/admin/notifications',
    expectedKeys: ['success', 'data', 'count']
  },
  {
    name: 'Pending Appointments Count',
    path: '/admin/appointments/pending-count',
    expectedKeys: ['success', 'count']
  }
];

console.log('🧪 Starting comprehensive dashboard test...\n');

let passedTests = 0;
let totalTests = tests.length;

tests.forEach(test => {
  const options = {
    hostname: 'localhost',
    port: 3000,
    path: test.path,
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  };

  const req = http.request(options, (res) => {
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log(`📋 ${test.name}:`);
      console.log(`   Status: ${res.statusCode}`);
      console.log(`   Content-Type: ${res.headers['content-type']}`);
      
      // Check if it's returning JSON
      const isJson = res.headers['content-type'] && res.headers['content-type'].includes('application/json');
      
      if (!isJson) {
        console.log(`   ❌ FAILED: Not returning JSON (Content-Type: ${res.headers['content-type']})`);
        console.log(`   Preview: ${data.substring(0, 100)}...`);
        console.log('');
        return;
      }
      
      try {
        const jsonData = JSON.parse(data);
        const hasExpectedKeys = test.expectedKeys.every(key => key in jsonData);
        
        if (hasExpectedKeys) {
          console.log(`   ✅ PASSED: Returns proper JSON with expected keys`);
          passedTests++;
        } else {
          console.log(`   ❌ FAILED: Missing expected keys. Expected: ${test.expectedKeys.join(', ')}`);
          console.log(`   Actual keys: ${Object.keys(jsonData).join(', ')}`);
        }
        
        // Show some data details
        if (jsonData.data) {
          if (Array.isArray(jsonData.data)) {
            console.log(`   Data items: ${jsonData.data.length}`);
          } else if (typeof jsonData.data === 'object') {
            console.log(`   Data keys: ${Object.keys(jsonData.data).join(', ')}`);
          }
        }
        
        if (jsonData.count !== undefined) {
          console.log(`   Count: ${jsonData.count}`);
        }
      } catch (e) {
        console.log(`   ❌ FAILED: Invalid JSON - ${e.message}`);
      }
      
      console.log('');
      
      // Check if all tests are done
      if (passedTests + (totalTests - tests.indexOf(test) - 1) === totalTests) {
        console.log(`🏁 Test Summary: ${passedTests}/${totalTests} tests passed`);
        if (passedTests === totalTests) {
          console.log('🎉 All dashboard endpoints are working correctly!');
        } else {
          console.log('⚠️  Some endpoints have issues that need attention.');
        }
      }
    });
  });

  req.on('error', (e) => {
    console.log(`📋 ${test.name}:`);
    console.log(`   ❌ FAILED: Connection error - ${e.message}`);
    console.log('');
  });

  req.end();
});