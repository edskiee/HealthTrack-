// Comprehensive test for the complete appointment workflow
const http = require('http');
const fs = require('fs');

// Configuration
const BASE_URL = 'http://localhost:3000';
const TEST_USER_ID = 1;
const TEST_PATIENT_ID = 1;

// Helper function to make HTTP requests
function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data)
          });
        } catch (e) {
          reject(e);
        }
      });
    });
    
    req.on('error', reject);
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

// Test functions
async function test1_GetServices() {
  console.log('🧪 Test 1: Get all services...');
  try {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/service-config',
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const response = await makeRequest(options);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    console.log(`   Services count: ${response.body.data?.length || 0}`);
    
    if (response.body.success && response.body.data && response.body.data.length > 0) {
      console.log('   ✅ PASS: Services retrieved successfully');
      return response.body.data;
    } else {
      console.log('   ❌ FAIL: No services found');
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function test2_CreateServiceSlot() {
  console.log('\n🧪 Test 2: Create appointment slot...');
  try {
    // First get services to use an existing service ID
    const services = await test1_GetServices();
    if (!services || services.length === 0) {
      console.log('   ❌ FAIL: Cannot create slot without services');
      return null;
    }
    
    const serviceId = services[0].id;
    const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
    
    const slotData = {
      service_id: serviceId,
      appointment_date: tomorrow,
      start_time: '10:00:00',
      end_time: '12:00:00',
      slot_duration_minutes: 30,
      max_patients: 5
    };
    
    const postData = JSON.stringify(slotData);
    
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
    
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    
    if (response.body.success) {
      console.log('   ✅ PASS: Appointment slot created successfully');
      console.log(`   Slot ID: ${response.body.data?.id}`);
      return response.body.data;
    } else {
      console.log('   ❌ FAIL: Failed to create appointment slot');
      console.log(`   Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function test3_GetAvailableSlots(serviceId, date) {
  console.log('\n🧪 Test 3: Get available slots...');
  try {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/appointment-slots/available?serviceId=${serviceId}&date=${date}`,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const response = await makeRequest(options);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    console.log(`   Available slots count: ${response.body.data?.length || 0}`);
    
    if (response.body.success && response.body.data && response.body.data.length > 0) {
      console.log('   ✅ PASS: Available slots retrieved successfully');
      return response.body.data[0]; // Return first slot
    } else {
      console.log('   ❌ FAIL: No available slots found');
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function test4_BookAppointmentWithSlot(slotId, serviceId) {
  console.log('\n🧪 Test 4: Book appointment with slot (auto-approval)...');
  try {
    const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
    
    const appointmentData = {
      userId: TEST_USER_ID,
      patientId: TEST_PATIENT_ID,
      doctorName: 'Dr. Automated Test',
      clinicHospital: 'Automated Test Clinic',
      appointmentDate: tomorrow,
      appointmentTime: '10:00:00',
      appointmentType: `Service ${serviceId}`,
      notes: 'Automated test appointment for workflow validation',
      slotId: slotId
    };
    
    const postData = JSON.stringify(appointmentData);
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointments',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    console.log(`   Message: ${response.body.message}`);
    
    if (response.body.success) {
      console.log('   ✅ PASS: Appointment booked with auto-approval');
      console.log(`   Appointment ID: ${response.body.data?.id}`);
      console.log(`   Appointment Status: ${response.body.data?.status}`);
      
      // Verify it's approved
      if (response.body.data?.status === 'approved') {
        console.log('   ✅ PASS: Appointment correctly auto-approved');
        return response.body.data;
      } else {
        console.log('   ❌ FAIL: Appointment not auto-approved as expected');
        return null;
      }
    } else {
      console.log('   ❌ FAIL: Failed to book appointment');
      console.log(`   Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function test5_BookAppointmentWithoutSlot(serviceId) {
  console.log('\n🧪 Test 5: Book appointment without slot (pending status)...');
  try {
    const dayAfterTomorrow = new Date(Date.now() + 172800000).toISOString().split('T')[0];
    
    const appointmentData = {
      userId: TEST_USER_ID,
      patientId: TEST_PATIENT_ID,
      doctorName: 'Dr. Manual Test',
      clinicHospital: 'Manual Test Clinic',
      appointmentDate: dayAfterTomorrow,
      appointmentTime: '14:00:00',
      appointmentType: `Service ${serviceId}`,
      notes: 'Manual test appointment for workflow validation'
      // Note: No slotId provided
    };
    
    const postData = JSON.stringify(appointmentData);
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointments',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    console.log(`   Message: ${response.body.message}`);
    
    if (response.body.success) {
      console.log('   ✅ PASS: Appointment created successfully');
      console.log(`   Appointment ID: ${response.body.data?.id}`);
      console.log(`   Appointment Status: ${response.body.data?.status}`);
      
      // Verify it's pending
      if (response.body.data?.status === 'pending') {
        console.log('   ✅ PASS: Appointment correctly set to pending');
        return response.body.data;
      } else {
        console.log('   ❌ FAIL: Appointment not set to pending as expected');
        return null;
      }
    } else {
      console.log('   ❌ FAIL: Failed to create appointment');
      console.log(`   Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function test6_AdminApproveAppointment(appointmentId) {
  console.log('\n🧪 Test 6: Admin approves pending appointment...');
  try {
    const updateData = {
      status: 'approved',
      notes: 'Approved by automated test'
    };
    
    const postData = JSON.stringify(updateData);
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/appointments/status/${appointmentId}`,
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    console.log(`   Message: ${response.body.message}`);
    
    if (response.body.success) {
      console.log('   ✅ PASS: Appointment approved successfully');
      console.log(`   Appointment Status: ${response.body.data?.status}`);
      
      // Verify it's approved
      if (response.body.data?.status === 'approved') {
        console.log('   ✅ PASS: Appointment correctly approved');
        return response.body.data;
      } else {
        console.log('   ❌ FAIL: Appointment not approved as expected');
        return null;
      }
    } else {
      console.log('   ❌ FAIL: Failed to approve appointment');
      console.log(`   Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function test7_GetUserNotifications(userId) {
  console.log('\n🧪 Test 7: Get user notifications...');
  try {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: `/appointments/notifications/${userId}`,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const response = await makeRequest(options);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Success: ${response.body.success}`);
    console.log(`   Notifications count: ${response.body.data?.length || 0}`);
    
    if (response.body.success) {
      console.log('   ✅ PASS: User notifications retrieved successfully');
      return response.body.data;
    } else {
      console.log('   ❌ FAIL: Failed to retrieve user notifications');
      console.log(`   Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

async function runComprehensiveTest() {
  console.log('🚀 Starting Comprehensive Appointment Workflow Test...\n');
  
  let testResults = {
    total: 7,
    passed: 0,
    failed: 0
  };
  
  // Test 1: Get services
  const services = await test1_GetServices();
  if (services) testResults.passed++; else testResults.failed++;
  
  if (!services || services.length === 0) {
    console.log('\n❌ Cannot proceed with tests without services');
    return testResults;
  }
  
  const serviceId = services[0].id;
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  
  // Test 2: Create appointment slot
  const slot = await test2_CreateServiceSlot();
  if (slot) testResults.passed++; else testResults.failed++;
  
  if (!slot) {
    console.log('\n❌ Cannot proceed with tests without appointment slot');
    return testResults;
  }
  
  // Test 3: Get available slots
  const availableSlot = await test3_GetAvailableSlots(serviceId, tomorrow);
  if (availableSlot) testResults.passed++; else testResults.failed++;
  
  // Test 4: Book appointment with slot (auto-approval)
  const autoApprovedAppointment = await test4_BookAppointmentWithSlot(slot.id, serviceId);
  if (autoApprovedAppointment) testResults.passed++; else testResults.failed++;
  
  // Test 5: Book appointment without slot (pending)
  const pendingAppointment = await test5_BookAppointmentWithoutSlot(serviceId);
  if (pendingAppointment) testResults.passed++; else testResults.failed++;
  
  // Test 6: Admin approve pending appointment
  let approvedAppointment = null;
  if (pendingAppointment) {
    approvedAppointment = await test6_AdminApproveAppointment(pendingAppointment.id);
    if (approvedAppointment) testResults.passed++; else testResults.failed++;
  } else {
    testResults.failed++;
  }
  
  // Test 7: Get user notifications
  const notifications = await test7_GetUserNotifications(TEST_USER_ID);
  if (notifications) testResults.passed++; else testResults.failed++;
  
  console.log('\n📊 Test Summary:');
  console.log(`   Total Tests: ${testResults.total}`);
  console.log(`   Passed: ${testResults.passed}`);
  console.log(`   Failed: ${testResults.failed}`);
  
  if (testResults.passed === testResults.total) {
    console.log('\n🎉 All tests passed! The appointment workflow is functioning correctly.');
  } else {
    console.log(`\n⚠️  ${testResults.failed} test(s) failed. Please review the implementation.`);
  }
  
  return testResults;
}

// Run the comprehensive test
runComprehensiveTest()
  .then(results => {
    console.log('\n🏁 Test execution completed');
    process.exit(results.failed > 0 ? 1 : 0);
  })
  .catch(error => {
    console.error('💥 Unexpected error during test execution:', error);
    process.exit(1);
  });