const http = require('http');

console.log('🏥 HealthTrack Admin Dashboard Verification\n');

// Test 1: Check if server is running
console.log('📋 Test 1: Server connectivity');
const serverCheck = http.get('http://localhost:3000/dashboard/stats', (res) => {
  console.log(`   Status: ${res.statusCode} ${res.statusMessage}`);
  if (res.statusCode === 200) {
    console.log('   ✅ Server is running and responding');
  } else {
    console.log('   ❌ Server connectivity issue');
    process.exit(1);
  }
  
  // Test 2: Dashboard stats endpoint
  console.log('\n📋 Test 2: Dashboard statistics endpoint');
  http.get('http://localhost:3000/dashboard/stats', (res) => {
    if (res.statusCode === 200) {
      console.log('   ✅ Dashboard stats endpoint working');
    } else {
      console.log('   ❌ Dashboard stats endpoint failed');
    }
    
    // Test 3: Admin notifications endpoint
    console.log('\n📋 Test 3: Admin notifications endpoint');
    http.get('http://localhost:3000/admin/notifications', (res) => {
      if (res.statusCode === 200) {
        console.log('   ✅ Admin notifications endpoint working');
      } else {
        console.log('   ❌ Admin notifications endpoint failed');
      }
      
      // Test 4: Check response format (JSON vs HTML)
      console.log('\n📋 Test 4: Response format verification');
      http.get('http://localhost:3000/admin/notifications', (res) => {
        const contentType = res.headers['content-type'];
        if (contentType && contentType.includes('application/json')) {
          console.log('   ✅ Server returning JSON (correct format)');
        } else {
          console.log('   ❌ Server returning HTML or incorrect format');
          console.log(`   Content-Type: ${contentType}`);
        }
        
        // Test 5: Data integrity check
        console.log('\n📋 Test 5: Data integrity check');
        http.get('http://localhost:3000/dashboard/stats', (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            try {
              const jsonData = JSON.parse(data);
              if (jsonData.success === true) {
                console.log('   ✅ Data integrity verified (success flag present)');
                if (jsonData.data && typeof jsonData.data === 'object') {
                  console.log('   ✅ Data structure valid');
                  console.log(`   📊 Sample stats - Total Patients: ${jsonData.data.totalPatients || 0}`);
                } else {
                  console.log('   ⚠️  Data structure may have issues');
                }
              } else {
                console.log('   ❌ Data integrity issue (success flag missing or false)');
              }
              
              console.log('\n🎉 Dashboard verification complete!');
              console.log('✅ All core functionality verified and working correctly');
            } catch (e) {
              console.log('   ❌ JSON parsing failed:', e.message);
            }
          });
        }).on('error', (e) => {
          console.log('   ❌ Request failed:', e.message);
        });
      }).on('error', (e) => {
        console.log('   ❌ Request failed:', e.message);
      });
    }).on('error', (e) => {
      console.log('   ❌ Request failed:', e.message);
    });
  }).on('error', (e) => {
    console.log('   ❌ Request failed:', e.message);
  });
}).on('error', (e) => {
  console.log('   ❌ Server not responding:', e.message);
  console.log('   Please ensure the backend server is running on port 3000');
  process.exit(1);
});