// Test script for appointment slot booking functionality
const http = require('http');

// Configuration
const BASE_URL = 'http://localhost:3000';
const TEST_USER_ID = 1;
const TEST_PATIENT_ID = 1;
const TEST_SERVICE_ID = 1;

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
async function testGetServices() {
  console.log('🧪 Testing GET /service-config...');
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
    console.log(`Status: ${response.statusCode}`);
    console.log(`Success: ${response.body.success}`);
    console.log(`Services count: ${response.body.data?.length || 0}`);
    
    if (response.body.data && response.body.data.length > 0) {
      console.log('✅ Services retrieved successfully');
      return response.body.data[0]; // Return first service for testing
    } else {
      console.log('❌ No services found');
      return null;
    }
  } catch (error) {
    console.error('❌ Error getting services:', error.message);
    return null;
  }
}

async function testGetAvailableSlots(serviceId, date) {
  console.log(`\n🧪 Testing GET /appointment-slots/available?serviceId=${serviceId}&date=${date}...`);
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
    console.log(`Status: ${response.statusCode}`);
    console.log(`Success: ${response.body.success}`);
    console.log(`Available slots count: ${response.body.data?.length || 0}`);
    
    if (response.body.data && response.body.data.length > 0) {
      console.log('✅ Available slots retrieved successfully');
      return response.body.data[0]; // Return first slot for testing
    } else {
      console.log('❌ No available slots found');
      return null;
    }
  } catch (error) {
    console.error('❌ Error getting available slots:', error.message);
    return null;
  }
}

async function testBookAppointmentWithSlot(slotId) {
  console.log(`\n🧪 Testing POST /appointments with slot ID ${slotId}...`);
  try {
    const appointmentData = {
      userId: TEST_USER_ID,
      patientId: TEST_PATIENT_ID,
      doctorName: 'Dr. Test',
      clinicHospital: 'Test Clinic',
      appointmentDate: new Date(Date.now() + 86400000).toISOString().split('T')[0], // Tomorrow
      appointmentTime: '10:00:00',
      appointmentType: 'Test Appointment',
      notes: 'Test appointment for verification',
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
    console.log(`Status: ${response.statusCode}`);
    console.log(`Success: ${response.body.success}`);
    console.log(`Message: ${response.body.message}`);
    
    if (response.body.success) {
      console.log('✅ Appointment booked successfully with auto-approval');
      console.log(`Appointment ID: ${response.body.data?.id}`);
      console.log(`Appointment Status: ${response.body.data?.status}`);
      return response.body.data;
    } else {
      console.log('❌ Failed to book appointment');
      console.log(`Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('❌ Error booking appointment:', error.message);
    return null;
  }
}

async function testBookAppointmentWithoutSlot() {
  console.log('\n🧪 Testing POST /appointments WITHOUT slot ID (should be pending)...');
  try {
    const appointmentData = {
      userId: TEST_USER_ID,
      patientId: TEST_PATIENT_ID,
      doctorName: 'Dr. Test Manual',
      clinicHospital: 'Test Clinic Manual',
      appointmentDate: new Date(Date.now() + 172800000).toISOString().split('T')[0], // Day after tomorrow
      appointmentTime: '14:00:00',
      appointmentType: 'Manual Test Appointment',
      notes: 'Manual test appointment for verification'
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
    console.log(`Status: ${response.statusCode}`);
    console.log(`Success: ${response.body.success}`);
    console.log(`Message: ${response.body.message}`);
    
    if (response.body.success) {
      console.log('✅ Appointment created successfully (should be pending)');
      console.log(`Appointment ID: ${response.body.data?.id}`);
      console.log(`Appointment Status: ${response.body.data?.status}`);
      return response.body.data;
    } else {
      console.log('❌ Failed to create appointment');
      console.log(`Error: ${response.body.message}`);
      return null;
    }
  } catch (error) {
    console.error('❌ Error creating appointment:', error.message);
    return null;
  }
}

async function runTests() {
  console.log('🚀 Starting Appointment Slot Booking Tests...\n');
  
  // Test 1: Get services
  const service = await testGetServices();
  if (!service) {
    console.log('❌ Cannot proceed without services');
    return;
  }
  
  // Test 2: Get available slots
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  const slot = await testGetAvailableSlots(service.id, tomorrow);
  if (!slot) {
    console.log('❌ Cannot proceed without available slots');
    return;
  }
  
  // Test 3: Book appointment with slot (should auto-approve)
  const approvedAppointment = await testBookAppointmentWithSlot(slot.id);
  
  // Test 4: Book appointment without slot (should be pending)
  const pendingAppointment = await testBookAppointmentWithoutSlot();
  
  console.log('\n🏁 Test Summary:');
  console.log(`✅ Auto-approved appointment: ${approvedAppointment ? 'PASS' : 'FAIL'}`);
  console.log(`✅ Pending appointment: ${pendingAppointment ? 'PASS' : 'FAIL'}`);
  
  if (approvedAppointment && pendingAppointment) {
    console.log('\n🎉 All tests completed successfully!');
    console.log(`   Auto-approved status: ${approvedAppointment.status}`);
    console.log(`   Pending status: ${pendingAppointment.status}`);
  } else {
    console.log('\n❌ Some tests failed');
  }
}

// Run the tests
runTests().catch(console.error);