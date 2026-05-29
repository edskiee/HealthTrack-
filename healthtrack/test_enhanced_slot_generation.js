/**
 * Enhanced Slot Generation Test Script
 * Tests the enhanced appointment slot generation functionality
 */

const http = require('http');
const https = require('https');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const TEST_SERVICE_ID = 1; // Adjust based on your test database

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
      return true;
    } else {
      console.log(`   ❌ FAIL: Expected status 201, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return false;
  }
}

async function testBulkSlotGeneration() {
  console.log('🧪 Test: Bulk slot generation with valid parameters');
  
  const tomorrow = new Date(Date.now() + 86400000);
  const dateString = tomorrow.toISOString().split('T')[0];
  
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
        return true;
      } else {
        console.log('   ❌ FAIL: Expected array of slots in response data');
        return false;
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 201, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return false;
  }
}

async function testDuplicateSlotPrevention() {
  console.log('🧪 Test: Duplicate slot prevention');
  
  const tomorrow = new Date(Date.now() + 86400000);
  const dateString = tomorrow.toISOString().split('T')[0];
  
  // First, create a slot
  const postData1 = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: '10:00:00',
    end_time: '10:30:00',
    slot_duration_minutes: 30,
    max_patients: 10
  });
  
  const options1 = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/appointment-slots',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData1)
    }
  };
  
  try {
    // Create first slot
    await makeRequest(options1, postData1);
    
    // Try to create duplicate slot
    const response = await makeRequest(options1, postData1);
    
    if (response.statusCode === 400) {
      if (response.body.message && response.body.message.includes('already exist')) {
        console.log('   ✅ PASS: Duplicate slot properly rejected');
        return true;
      } else {
        console.log('   ❌ FAIL: Expected duplicate slot error message');
        return false;
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 400, got ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return false;
  }
}

async function testPastDateRejection() {
  console.log('🧪 Test: Past date rejection');
  
  const yesterday = new Date(Date.now() - 86400000);
  const dateString = yesterday.toISOString().split('T')[0];
  
  const postData = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: '09:00:00',
    end_time: '09:30:00'
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
    
    if (response.statusCode === 400) {
      if (response.body.message && response.body.message.includes('past dates')) {
        console.log('   ✅ PASS: Past date properly rejected');
        return true;
      } else {
        console.log('   ❌ FAIL: Expected past date error message');
        return false;
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 400, got ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return false;
  }
}

async function testInvalidTimeFormatRejection() {
  console.log('🧪 Test: Invalid time format rejection');
  
  const tomorrow = new Date(Date.now() + 86400000);
  const dateString = tomorrow.toISOString().split('T')[0];
  
  const postData = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: 'invalid_format',
    end_time: 'also_invalid'
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
    
    if (response.statusCode === 400) {
      if (response.body.message && response.body.message.includes('Invalid time format')) {
        console.log('   ✅ PASS: Invalid time format properly rejected');
        return true;
      } else {
        console.log('   ❌ FAIL: Expected invalid time format error message');
        return false;
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 400, got ${response.statusCode}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return false;
  }
}

// Main test runner
async function runTests() {
  console.log('🚀 Starting Enhanced Slot Generation Tests\n');
  
  let passedTests = 0;
  const totalTests = 5;
  
  // Run all tests
  if (await testSingleSlotCreation()) passedTests++;
  console.log('');
  
  if (await testBulkSlotGeneration()) passedTests++;
  console.log('');
  
  if (await testDuplicateSlotPrevention()) passedTests++;
  console.log('');
  
  if (await testPastDateRejection()) passedTests++;
  console.log('');
  
  if (await testInvalidTimeFormatRejection()) passedTests++;
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