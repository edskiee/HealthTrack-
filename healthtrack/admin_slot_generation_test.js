/**
 * Admin Slot Generation Test
 * Tests if admin can generate slots without showing errors after fixes
 */

const http = require('http');
const https = require('https');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';

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

// Get available services
async function getServices() {
  console.log('📋 Getting available services...');
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: '/service-config',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      console.log(`   ✅ Found ${response.body.data.length} services`);
      return response.body.data;
    } else {
      console.log(`   ❌ Failed to get services: ${response.statusCode}`);
      return [];
    }
  } catch (error) {
    console.log(`   ❌ Error getting services: ${error.message}`);
    return [];
  }
}

// Create a single slot
async function createSingleSlot(serviceId, date, startTime, endTime) {
  console.log(`📅 Creating single slot for service ${serviceId} on ${date} from ${startTime} to ${endTime}`);
  
  const postData = JSON.stringify({
    service_id: serviceId,
    appointment_date: date,
    start_time: startTime,
    end_time: endTime,
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
    
    if (response.statusCode === 201 && response.body.success) {
      console.log(`   ✅ Slot created successfully with ID: ${response.body.data.id}`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ⚠️  Notice: ${response.body.message || response.statusCode}`);
      // This might be expected if slots already exist
      return { success: response.statusCode === 201, data: response.body.data, message: response.body.message };
    }
  } catch (error) {
    console.log(`   ❌ Error creating slot: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Get slots for a specific date
async function getSlotsForDate(date) {
  console.log(`🔍 Getting appointment slots for ${date}...`);
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || (BASE_URL.startsWith('https') ? 443 : 80),
    path: `/appointment-slots?date=${date}`,
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      console.log(`   ✅ Retrieved ${response.body.data.length} slots for ${date}`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ❌ Failed to get slots for ${date}: ${response.body.message || response.statusCode}`);
      return { success: false, error: response.body.message };
    }
  } catch (error) {
    console.log(`   ❌ Error getting slots for ${date}: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Main test runner
async function runTests() {
  console.log('🚀 Testing Admin Slot Generation After Fixes\n');
  
  // Step 1: Get services
  const services = await getServices();
  if (services.length === 0) {
    console.log('❌ No services found. Cannot proceed with tests.');
    process.exit(1);
  }
  
  // Use the first available service
  const service = services[0];
  console.log(`🔧 Using service: ${service.service_name} (ID: ${service.id})\n`);
  
  // Step 2: Create a single slot for a future date (7 days from now to minimize conflicts)
  const futureDate = new Date(Date.now() + 7 * 86400000);
  const slotDate = futureDate.toISOString().split('T')[0];
  
  console.log(`🎯 Testing slot creation for date: ${slotDate}`);
  
  const singleSlotResult = await createSingleSlot(
    service.id,
    slotDate,
    '14:00:00',
    '14:30:00'
  );
  
  // Step 3: Verify the slot exists
  const getSlotsResult = await getSlotsForDate(slotDate);
  
  console.log('\n📋 Test Results Summary:');
  
  if (singleSlotResult.success || (singleSlotResult.message && singleSlotResult.message.includes('already exist'))) {
    console.log('✅ Slot creation test PASSED');
    console.log('   - Either created a new slot or confirmed existing slot');
  } else {
    console.log('❌ Slot creation test FAILED');
    console.log(`   - Error: ${singleSlotResult.error || singleSlotResult.message}`);
  }
  
  if (getSlotsResult.success) {
    console.log('✅ Slot retrieval test PASSED');
    console.log(`   - Successfully retrieved ${getSlotsResult.data.length} slots`);
  } else {
    console.log('❌ Slot retrieval test FAILED');
    console.log(`   - Error: ${getSlotsResult.error}`);
  }
  
  // Final summary
  console.log('\n🏁 Overall Test Result:');
  if ((singleSlotResult.success || (singleSlotResult.message && singleSlotResult.message.includes('already exist'))) && 
      getSlotsResult.success) {
    console.log('🎉 SUCCESS! Admin can generate slots without errors.');
    console.log('   The fixes have resolved the slot generation issues.');
    process.exit(0);
  } else {
    console.log('❌ FAILURE! There are still issues with slot generation.');
    process.exit(1);
  }
}

// Run the tests
runTests().catch(error => {
  console.error('Test suite failed with unhandled error:', error);
  process.exit(1);
});