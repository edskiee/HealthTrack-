/**
 * End-to-End Slot Generation Functionality Test
 * This script tests the complete slot generation workflow in the HealthTrack system
 */

const http = require('http');
const https = require('https');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const TEST_SERVICE_ID = 16; // Using service ID from available services
const MAX_PATIENTS = 10;

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
    max_patients: MAX_PATIENTS
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
    
    if (response.statusCode === 201 && response.body.success) {
      console.log(`   ✅ Slot created successfully with ID: ${response.body.data.id}`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ❌ FAIL: Expected status 201, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false, message: response.body.message || response.statusCode };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function testBulkSlotGeneration() {
  console.log('🧪 Test: Bulk slot generation with valid parameters');
  
  const dayAfterTomorrow = new Date(Date.now() + 2 * 86400000);
  const dateString = dayAfterTomorrow.toISOString().split('T')[0];
  
  const postData = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: '10:00:00',
    end_time: '12:00:00',
    slot_duration_minutes: 30,
    max_patients: MAX_PATIENTS,
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
    
    if (response.statusCode === 201 && response.body.success) {
      console.log(`   ✅ Bulk slots created successfully: ${response.body.data.length} slots`);
      console.log(`   Slot IDs: ${response.body.data.map(slot => slot.id).join(', ')}`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ❌ FAIL: Expected status 201, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false, message: response.body.message || response.statusCode };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function testSlotRetrieval() {
  console.log('🧪 Test: Retrieving created appointment slots');
  
  const tomorrow = new Date(Date.now() + 86400000);
  const dateString = tomorrow.toISOString().split('T')[0];
  
  // Also test retrieval for the day after tomorrow
  const dayAfterTomorrow = new Date(Date.now() + 2 * 86400000);
  const dayAfterTomorrowString = dayAfterTomorrow.toISOString().split('T')[0];
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: `/appointment-slots?date=${dateString}`,
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      console.log(`   ✅ Retrieved ${response.body.data.length} slots for date ${dateString}`);
      if (response.body.data.length > 0) {
        console.log(`   Sample slot: ID ${response.body.data[0].id}, ${response.body.data[0].start_time} - ${response.body.data[0].end_time}`);
      }
          
      // Also test retrieval for day after tomorrow
      const options2 = {
        hostname: new URL(BASE_URL).hostname,
        port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
        path: `/appointment-slots?date=${dayAfterTomorrowString}`,
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      };
          
      const response2 = await makeRequest(options2);
          
      if (response2.statusCode === 200 && response2.body.success) {
        console.log(`   ✅ Retrieved ${response2.body.data.length} slots for date ${dayAfterTomorrowString}`);
        if (response2.body.data.length > 0) {
          console.log(`   Sample slot: ID ${response2.body.data[0].id}, ${response2.body.data[0].start_time} - ${response2.body.data[0].end_time}`);
        }
            
        // Combine both results
        return { 
          success: true, 
          data: [...response.body.data, ...response2.body.data],
          message: `Retrieved ${response.body.data.length} from first date and ${response2.body.data.length} from second date`
        };
      } else {
        return { success: true, data: response.body.data, message: `First date: ${response.body.data.length} slots` };
      }
    } else {
      console.log(`   ❌ FAIL: Expected status 200, got ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false, message: response.body.message || response.statusCode };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function testSlotValidation() {
  console.log('🧪 Test: Slot validation with insufficient time range');
  
  const thirdDay = new Date(Date.now() + 3 * 86400000);
  const dateString = thirdDay.toISOString().split('T')[0];
  
  const postData = JSON.stringify({
    service_id: TEST_SERVICE_ID,
    appointment_date: dateString,
    start_time: '14:00:00',
    end_time: '14:10:00', // Too short for even 1 slot
    slot_duration_minutes: 30,
    max_patients: MAX_PATIENTS,
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
    
    if (response.statusCode === 400 && !response.body.success) {
      console.log(`   ✅ Validation correctly rejected insufficient time range: ${response.body.message}`);
      return { success: true, message: response.body.message };
    } else {
      console.log(`   ⚠️  Expected validation error, got status ${response.statusCode}`);
      console.log(`   Response: ${JSON.stringify(response.body)}`);
      return { success: false, message: response.body.message || response.statusCode };
    }
  } catch (error) {
    console.log(`   ❌ FAIL: Request failed with error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Run the tests
async function runTests() {
  console.log('🚀 Starting End-to-End Slot Generation Functionality Tests...\n');
  
  const results = {
    singleSlot: await testSingleSlotCreation(),
    bulkSlots: await testBulkSlotGeneration(),
    retrieval: await testSlotRetrieval(),
    validation: await testSlotValidation()
  };
  
  console.log('\n📊 Test Results Summary:');
  console.log(`   Single Slot Creation: ${results.singleSlot.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Bulk Slot Generation: ${results.bulkSlots.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Slot Retrieval: ${results.retrieval.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Slot Validation: ${results.validation.success ? '✅ PASS' : '❌ FAIL'}`);
  
  const passedTests = Object.values(results).filter(result => result.success).length;
  const totalTests = Object.keys(results).length;
  
  console.log(`\n📈 Overall: ${passedTests}/${totalTests} tests passed`);
  
  if (passedTests === totalTests) {
    console.log('🎉 All tests passed! Slot generation functionality is working correctly.');
    process.exit(0);
  } else {
    console.log('❌ Some tests failed. Please check the implementation.');
    process.exit(1);
  }
}

// Run the tests
runTests().catch(error => {
  console.error('Test suite failed with unhandled error:', error);
  process.exit(1);
});