// Test script to verify appointment slots API endpoint
const http = require('http');

const API_URL = 'http://localhost:3000';

console.log('🔍 Testing Appointment Slots API at:', API_URL);
console.log('='.repeat(60));

// Test 1: Check if server is reachable
async function testServerReachability() {
  try {
    console.log('\n📡 Test 1: Checking server reachability...');
    const response = await makeRequest('/');
    console.log('✅ Server is reachable!');
    console.log('Response:', response);
    return true;
  } catch (error) {
    console.log('❌ Server is NOT reachable!');
    console.log('Error:', error.message);
    return false;
  }
}

// Test 2: GET /appointment-slots (should work)
async function testGetAppointmentSlots() {
  try {
    console.log('\n📡 Test 2: Testing GET /appointment-slots...');
    const response = await makeRequest('/appointment-slots');
    console.log('✅ GET /appointment-slots works!');
    console.log('Status:', response.success ? 'Success' : 'Failed');
    if (response.data) {
      console.log('Slots found:', response.data.length);
    }
    return true;
  } catch (error) {
    console.log('❌ GET /appointment-slots failed!');
    console.log('Error:', error.message);
    return false;
  }
}

// Test 3: POST /appointment-slots (create slot)
async function testCreateAppointmentSlot() {
  try {
    console.log('\n📡 Test 3: Testing POST /appointment-slots (dry run)...');
    
    const postData = JSON.stringify({
      service_id: 1,
      appointment_date: '2026-03-15',
      start_time: '09:00:00',
      end_time: '10:00:00',
      slot_duration_minutes: 30,
      max_patients: 5,
      generate_slots: false
    });
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointment-slots',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
    const response = await makePostRequest(options, postData);
    console.log('✅ POST /appointment-slots works!');
    console.log('Response:', response);
    return true;
  } catch (error) {
    console.log('❌ POST /appointment-slots failed!');
    console.log('Error:', error.message);
    if (error.code) {
      console.log('Error Code:', error.code);
    }
    return false;
  }
}

// Helper function for GET requests
function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    };
    
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve({ raw: data });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    req.setTimeout(5000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    req.end();
  });
}

// Helper function for POST requests
function makePostRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve({ raw: data, statusCode: res.statusCode });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    req.write(postData);
    req.end();
  });
}

// Run all tests
async function runTests() {
  console.log('\n🚀 Starting API Tests...\n');
  
  const test1 = await testServerReachability();
  
  if (!test1) {
    console.log('\n⚠️  SERVER IS NOT REACHABLE!');
    console.log('\n💡 Troubleshooting steps:');
    console.log('   1. Make sure the backend server is running (node src/server.js)');
    console.log('   2. Check if IP 192.168.137.1 is correct for your machine');
    console.log('   3. Verify firewall is not blocking port 3000');
    console.log('   4. Try pinging 192.168.137.1 from command prompt');
    process.exit(1);
  }
  
  await testGetAppointmentSlots();
  await testCreateAppointmentSlot();
  
  console.log('\n' + '='.repeat(60));
  console.log('✅ All API tests completed!\n');
}

runTests().catch(err => {
  console.error('Test execution error:', err);
  process.exit(1);
});
