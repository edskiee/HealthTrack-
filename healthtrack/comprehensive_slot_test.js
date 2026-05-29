/**
 * Comprehensive Slot Creation and Display Test
 * Tests the end-to-end functionality of slot creation and display
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
      console.log(`   ❌ Failed to create slot: ${response.body.message || response.statusCode}`);
      return { success: false, error: response.body.message };
    }
  } catch (error) {
    console.log(`   ❌ Error creating slot: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Create bulk slots
async function createBulkSlots(serviceId, date, startTime, endTime) {
  console.log(`📅 Creating bulk slots for service ${serviceId} on ${date} from ${startTime} to ${endTime}`);
  
  const postData = JSON.stringify({
    service_id: serviceId,
    appointment_date: date,
    start_time: startTime,
    end_time: endTime,
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
    
    if (response.statusCode === 201 && response.body.success) {
      console.log(`   ✅ Bulk slots created successfully (${response.body.data.length} slots)`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ❌ Failed to create bulk slots: ${response.body.message || response.statusCode}`);
      return { success: false, error: response.body.message };
    }
  } catch (error) {
    console.log(`   ❌ Error creating bulk slots: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Get all slots
async function getAllSlots() {
  console.log('🔍 Getting all appointment slots...');
  
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
    
    if (response.statusCode === 200 && response.body.success) {
      console.log(`   ✅ Retrieved ${response.body.data.length} slots`);
      return { success: true, data: response.body.data };
    } else {
      console.log(`   ❌ Failed to get slots: ${response.body.message || response.statusCode}`);
      return { success: false, error: response.body.message };
    }
  } catch (error) {
    console.log(`   ❌ Error getting slots: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Main test runner
async function runTests() {
  console.log('🚀 Starting Comprehensive Slot Creation and Display Tests\n');
  
  // Step 1: Get services
  const services = await getServices();
  if (services.length === 0) {
    console.log('❌ No services found. Cannot proceed with tests.');
    process.exit(1);
  }
  
  // Use the first available service
  const service = services[0];
  console.log(`🔧 Using service: ${service.service_name} (ID: ${service.id})\n`);
  
  // Step 2: Create a single slot
  const tomorrow = new Date(Date.now() + 86400000);
  const dateString = tomorrow.toISOString().split('T')[0];
  
  const singleSlotResult = await createSingleSlot(
    service.id,
    dateString,
    '09:00:00',
    '09:30:00'
  );
  
  if (!singleSlotResult.success) {
    console.log('❌ Failed to create single slot.');
    process.exit(1);
  }
  
  console.log('');
  
  // Step 3: Create bulk slots (using a different date to avoid conflicts)
  const twoDaysFromNow = new Date(Date.now() + 2 * 86400000);
  const bulkDateString = twoDaysFromNow.toISOString().split('T')[0];
  
  const bulkSlotResult = await createBulkSlots(
    service.id,
    bulkDateString,
    '10:00:00',
    '16:00:00'
  );
  
  if (!bulkSlotResult.success) {
    console.log('❌ Failed to create bulk slots.');
    process.exit(1);
  }
  
  console.log('');
  
  // Step 4: Get all slots to verify they were created and are visible
  const getAllSlotsResult = await getAllSlots();
  if (!getAllSlotsResult.success) {
    console.log('❌ Failed to retrieve slots.');
    process.exit(1);
  }
  
  // Verify that our created slots are in the list
  const allSlots = getAllSlotsResult.data;
  const singleSlotId = singleSlotResult.data.id;
  const bulkSlotCount = bulkSlotResult.data.length;
  
  const foundSingleSlot = allSlots.some(slot => slot.id === singleSlotId);
  const foundBulkSlots = allSlots.filter(slot => 
    slot.appointment_date.includes(bulkDateString)
  ).length;
  
  console.log('');
  console.log('📊 Verification Results:');
  console.log(`   Single slot (ID: ${singleSlotId}) found: ${foundSingleSlot ? '✅ YES' : '❌ NO'}`);
  console.log(`   Bulk slots for ${bulkDateString} found: ${foundBulkSlots === bulkSlotCount ? `✅ YES (${bulkSlotCount})` : `❌ NO (${foundBulkSlots}/${bulkSlotCount})`}`);
  
  // Final summary
  console.log('\n🏁 Test Summary:');
  if (foundSingleSlot && foundBulkSlots === bulkSlotCount) {
    console.log('🎉 All tests passed! Slots are being created and displayed correctly.');
    process.exit(0);
  } else {
    console.log('❌ Some tests failed. There may still be issues with slot creation or display.');
    process.exit(1);
  }
}

// Run the tests
runTests().catch(error => {
  console.error('Test suite failed with unhandled error:', error);
  process.exit(1);
});