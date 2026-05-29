/**
 * Test script to verify appointment status notification functionality
 * This script tests the end-to-end flow of appointment status updates with notifications
 */

// Import required modules
const http = require('http');
const https = require('https');

// Configuration
const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3000';
const TEST_USER_ID = process.env.TEST_USER_ID || '1';
const TEST_APPOINTMENT_ID = process.env.TEST_APPOINTMENT_ID || '1';

// Test data
const testCases = [
  {
    name: 'Approved Appointment',
    status: 'approved',
    expectedMessage: 'Your appointment has been approved.'
  },
  {
    name: 'Cancelled Appointment',
    status: 'cancelled',
    expectedMessage: 'Your appointment has been cancelled.'
  },
  {
    name: 'Rescheduled Appointment',
    status: 'rescheduled',
    expectedMessage: 'Your appointment has been rescheduled.'
  }
];

/**
 * Make HTTP request
 */
function makeRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const protocol = options.protocol === 'https:' ? https : http;
    
    const req = protocol.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: data
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

/**
 * Test appointment status update
 */
async function testAppointmentStatusUpdate(testCase) {
  console.log(`\n🧪 Testing: ${testCase.name}`);
  
  try {
    // Prepare request options
    const url = new URL(`${BASE_URL}/api/appointments/status/${TEST_APPOINTMENT_ID}`);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      }
    };
    
    // Prepare request body
    const postData = JSON.stringify({
      status: testCase.status,
      notes: `Test notes for ${testCase.status} status`
    });
    
    // Make request
    console.log(`   📡 Sending request to ${url.href}`);
    const response = await makeRequest(options, postData);
    
    // Check response
    console.log(`   📋 Status Code: ${response.statusCode}`);
    
    if (response.statusCode === 200 && response.data.success) {
      console.log(`   ✅ Success: ${response.data.message}`);
      console.log(`   📦 Response Data:`, JSON.stringify(response.data.data, null, 2));
      return true;
    } else {
      console.log(`   ❌ Failed: ${response.data.message || 'Unknown error'}`);
      console.log(`   📦 Response Data:`, JSON.stringify(response.data, null, 2));
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    return false;
  }
}

/**
 * Main test function
 */
async function runTests() {
  console.log('🚀 Starting Appointment Status Notification Tests');
  console.log(`🔗 Base URL: ${BASE_URL}`);
  console.log(`👤 Test User ID: ${TEST_USER_ID}`);
  console.log(`📅 Test Appointment ID: ${TEST_APPOINTMENT_ID}`);
  
  let passedTests = 0;
  let totalTests = testCases.length;
  
  // Run each test case
  for (const testCase of testCases) {
    const passed = await testAppointmentStatusUpdate(testCase);
    if (passed) {
      passedTests++;
    }
  }
  
  // Print summary
  console.log('\n📋 Test Summary:');
  console.log(`   ✅ Passed: ${passedTests}/${totalTests}`);
  console.log(`   ❌ Failed: ${totalTests - passedTests}/${totalTests}`);
  
  if (passedTests === totalTests) {
    console.log('\n🎉 All tests passed!');
    process.exit(0);
  } else {
    console.log('\n💥 Some tests failed!');
    process.exit(1);
  }
}

// Run tests
if (require.main === module) {
  runTests().catch(error => {
    console.error('Unhandled error:', error);
    process.exit(1);
  });
}

module.exports = {
  testAppointmentStatusUpdate,
  runTests
};