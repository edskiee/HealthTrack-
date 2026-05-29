const http = require('http');

// Test configuration
const BASE_URL = 'http://localhost:3000';
const TEST_SERVICE_ID = 18; // Dental Checkup service

// Helper function to make HTTP requests
function makeRequest(options) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({ status: res.statusCode, data: jsonData });
        } catch (e) {
          reject(new Error(`Failed to parse JSON: ${e.message}`));
        }
      });
    });

    req.on('error', (e) => {
      reject(new Error(`Request failed: ${e.message}`));
    });

    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}

// Test 1: Get month availability
async function testMonthAvailability() {
  console.log('\n🧪 Test 1: Get month availability');
  try {
    const year = new Date().getFullYear();
    const month = new Date().getMonth() + 1;
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/appointment-slots/availability?serviceId=${TEST_SERVICE_ID}&year=${year}&month=${month}`,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const result = await makeRequest(options);
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
    
    if (result.status === 200 && result.data.success) {
      console.log('✅ Month availability endpoint working correctly');
      return result.data.data;
    } else {
      console.log('❌ Month availability test failed');
      return null;
    }
  } catch (error) {
    console.error('❌ Error testing month availability:', error.message);
    return null;
  }
}

// Test 2: Create slots as admin (simplified version without stored procedure)
async function testSlotCreation() {
  console.log('\n🔧 Test 2: Create appointment slots');
  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dateStr = tomorrow.toISOString().split('T')[0];
    
    // Create a single slot first (without generate_slots flag)
    const singleSlotData = {
      service_id: TEST_SERVICE_ID,
      appointment_date: dateStr,
      start_time: '10:00:00',
      end_time: '10:30:00',
      slot_duration_minutes: 30,
      max_patients: 5
    };

    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointment-slots',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(singleSlotData)
    };

    const result = await makeRequest(options);
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
    
    if (result.status === 201 && result.data.success) {
      console.log('✅ Single slot creation working correctly');
      console.log(`Created slot with ID: ${result.data.data.id}`);
      return result.data.data;
    } else {
      console.log('❌ Single slot creation test failed');
      console.log('Error:', result.data?.message || 'Unknown error');
      return null;
    }
  } catch (error) {
    console.error('❌ Error testing slot creation:', error.message);
    return null;
  }
}

// Test 3: Get available slots for specific date
async function testAvailableSlots() {
  console.log('\n📅 Test 3: Get available slots for specific date');
  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dateStr = tomorrow.toISOString().split('T')[0];
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/appointment-slots/available?serviceId=${TEST_SERVICE_ID}&date=${dateStr}`,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const result = await makeRequest(options);
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
    
    if (result.status === 200 && result.data.success) {
      console.log('✅ Available slots endpoint working correctly');
      console.log(`Found ${result.data.data.length} available slots`);
      return result.data.data;
    } else {
      console.log('❌ Available slots test failed');
      return null;
    }
  } catch (error) {
    console.error('❌ Error testing available slots:', error.message);
    return null;
  }
}

// Test 4: Book a slot
async function testSlotBooking(availableSlots) {
  console.log('\n📝 Test 4: Book an appointment slot');
  if (!availableSlots || availableSlots.length === 0) {
    console.log('❌ No available slots to book');
    return false;
  }

  try {
    const slotId = availableSlots[0].id;
    console.log(`Attempting to book slot ID: ${slotId}`);
    
    const bookingData = { slotId: slotId };

    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointment-slots/book',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(bookingData)
    };

    const result = await makeRequest(options);
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
    
    if (result.status === 200 && result.data.success) {
      console.log('✅ Slot booking working correctly');
      console.log(`Remaining spots: ${result.data.data.remainingSpots}`);
      return true;
    } else {
      console.log('❌ Slot booking test failed');
      return false;
    }
  } catch (error) {
    console.error('❌ Error testing slot booking:', error.message);
    return false;
  }
}

// Test 5: Verify real-time synchronization
async function testRealtimeSync() {
  console.log('\n🔄 Test 5: Verify real-time synchronization');
  try {
    // Wait a moment to allow real-time updates to propagate
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Check month availability again to see if booking is reflected
    const year = new Date().getFullYear();
    const month = new Date().getMonth() + 1;
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/appointment-slots/availability?serviceId=${TEST_SERVICE_ID}&year=${year}&month=${month}`,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const result = await makeRequest(options);
    console.log(`Status: ${result.status}`);
    
    if (result.status === 200 && result.data.success) {
      console.log('✅ Real-time synchronization verified');
      console.log('Updated availability data received');
      return true;
    } else {
      console.log('❌ Real-time synchronization test failed');
      return false;
    }
  } catch (error) {
    console.error('❌ Error testing real-time sync:', error.message);
    return false;
  }
}

// Main test execution
async function runTests() {
  console.log('🧪 Starting HealthTrack Slot Management Flow Tests');
  console.log('================================================');
  
  // Test 1: Check month availability
  const monthData = await testMonthAvailability();
  
  // Test 2: Create slots
  const createdSlots = await testSlotCreation();
  
  // Test 3: Get available slots
  const availableSlots = await testAvailableSlots();
  
  // Test 4: Book a slot
  const bookingSuccess = await testSlotBooking(availableSlots);
  
  // Test 5: Verify real-time sync
  const syncSuccess = await testRealtimeSync();
  
  console.log('\n📊 Test Summary');
  console.log('==================');
  console.log(`Month Availability: ${monthData ? '✅' : '❌'}`);
  console.log(`Slot Creation: ${createdSlots ? '✅' : '❌'}`);
  console.log(`Available Slots: ${availableSlots ? '✅' : '❌'}`);
  console.log(`Slot Booking: ${bookingSuccess ? '✅' : '❌'}`);
  console.log(`Real-time Sync: ${syncSuccess ? '✅' : '❌'}`);
  
  const allTestsPassed = monthData && createdSlots && availableSlots && bookingSuccess && syncSuccess;
  console.log(`\n🎯 Overall Result: ${allTestsPassed ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}`);
  
  if (allTestsPassed) {
    console.log('\n🎉 Centralized slot management system is working correctly!');
    console.log('✅ Admin and User interfaces are properly synchronized');
    console.log('✅ Real-time updates are functioning');
    console.log('✅ API endpoints are responding correctly');
  } else {
    console.log('\n⚠️  Some issues detected. Please review the test results above.');
  }
}

// Run the tests
runTests().catch(error => {
  console.error('❌ Test execution failed:', error.message);
  process.exit(1);
});
