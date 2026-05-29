/**
 * Improved Slot Creation Test Script
 * Tests the appointment slot creation functionality with different dates
 */

const http = require('http');
const https = require('https');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const TEST_SERVICE_ID = 16; // Using Immunization service ID from database

// Utility function to make HTTP requests
function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const lib = BASE_URL.startsWith('https') ? https : http;
    
    const req = lib.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data
          });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

// Test functions
async function testSingleSlotCreation() {
  console.log('🧪 Test: Single slot creation with valid parameters');
  
  const tomorrow = new Date(Date.now() + 86400000);
  const dateString = tomorrow.toISOString().split('T')[0];
  
  const postData = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: '09:00:00',
    end_time: '09:30:00',
    slot_duration_minutes: 30,
    max_patients: 10
  });
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };
  
  try {
    const response = await makeRequest(options, postData);
    
    if (response.statusCode === 201) {
      console.log('   ✅ PASS: Single slot created successfully');
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ❌ FAIL: Expected status 201, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false };
  }
}

async function testBulkSlotGeneration() {
  console.log('🧪 Test: Bulk slot generation with valid parameters');
  
  // Use a date 2 days from now to avoid conflicts
  const twoDaysFromNow = new Date(Date.now() + 2 * 86400000);
  const dateString = twoDaysFromNow.toISOString().split('T')[0];
  
  const postData = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: '09:00:00',
    end_time: '17:00:00',
    slot_duration_minutes: 30,
    max_patients: 10,
    generate_slots: true
  });
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };
  
  try {
    const response = await makeRequest(options, postData);
    
    if (response.statusCode === 201) {
      if (Array.isArray(response.body.data) && response.body.data.length > 0) {
        console.log(`   ✅ PASS: Bulk slots created successfully (${response.body.data.length} slots)`);
        console.log(`   Response: ${JSON.stringify(response.body)}`);
        return { success: true, data: response.body.data };
      } else {
        console.log('   ❌ FAIL: Expected array of slots in response data');
        return { success: false };
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 201, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false };
  }
}

async function testGetAllSlots() {
  console.log('🧪 Test: Get all slots');
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200) {
      if (Array.isArray(response.body.data)) {
        console.log(`   ✅ PASS: Successfully retrieved ${response.body.data.length} slots`);
        console.log(`   Response: ${JSON.stringify(response.body)}`);
        return { success: true, data: response.body.data };
      } else {
        console.log('   ❌ FAIL: Expected array of slots in response data');
        return { success: false };
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 200, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false };
  }
}

// Main test runner
async function runTests() {
  console.log('🚀 Starting Improved Slot Creation Tests\n');
  
  let passedTests = 0;
  const totalTests = 3;
  
  // Run all tests
  const singleSlotResult = await testSingleSlotCreation();
  if (singleSlotResult.success) passedTests++;
  console.log('');
  
  const bulkSlotResult = await testBulkSlotGeneration();
  if (bulkSlotResult.success) passedTests++;
  console.log('');
  
  const getAllSlotsResult = await testGetAllSlots();
  if (getAllSlotsResult.success) passedTests++;
  console.log('');
  
  // Summary
  console.log(`\n🏁 Test Results: ${passedTests}/${totalTests} tests passed`);
  
  if (passedTests === totalTests) {
    console.log('🎉 All tests passed!');
    process.exit(0);
  } else {
    console.log('❌ Some tests failed.');
    process.exit(1);
  }
}

// Run the tests
runTests().catch(error => {
  console.error('Test suite failed with unhandled error:', error);
  process.exit(1);
});