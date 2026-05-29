/**
 * Comprehensive test script for appointment reminder notification system
 * Tests the complete workflow from appointment approval to reminder delivery
 */

const axios = require('axios');

// Configuration
const API_BASE_URL = 'http://localhost:3000';

// Test data
const testUser = {
  username: 'testuser_reminder',
  email: 'testreminder@example.com',
  password: 'password123',
  full_name: 'Test Reminder User',
  phone: '1234567890'
};

const testPatient = {
  child_fullname: 'Test Child Reminder',
  mother_fullname: 'Test Mother',
  father_fullname: 'Test Father',
  date_of_birth: '2022-01-01',
  place_of_birth: 'Test Hospital',
  sex: 'Male',
  address: 'Test Address'
};

let testUserId = null;
let testPatientId = null;
let testAppointmentId = null;
let testFcmToken = 'test_fcm_token_' + Date.now() + '_long_enough_for_validation';

// Utility functions
function log(message, type = 'info') {
  const timestamp = new Date().toISOString();
  const prefix = type === 'error' ? '❌' : type === 'success' ? '✅' : type === 'warning' ? '⚠️' : 'ℹ️';
  console.log(`${timestamp} ${prefix} ${message}`);
}

async function makeRequest(method, endpoint, data = null, headers = {}) {
  try {
    const config = {
      method,
      url: `${API_BASE_URL}${endpoint}`,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };
    
    if (data) {
      config.data = data;
    }
    
    const response = await axios(config);
    return { success: true, data: response.data, status: response.status };
  } catch (error) {
    return { 
      success: false, 
      error: error.response?.data || error.message, 
      status: error.response?.status 
    };
  }
}

// Test functions
async function testUserRegistration() {
  log('Testing user registration...');
  
  const result = await makeRequest('POST', '/auth/register', testUser);
  
  if (result.success) {
    testUserId = result.data.user?.id || result.data.id;
    log(`User registered successfully with ID: ${testUserId}`, 'success');
    return true;
  } else {
    log(`User registration failed: ${result.error}`, 'error');
    return false;
  }
}

async function testPatientRegistration() {
  if (!testUserId) {
    log('Skipping patient registration - no user ID', 'warning');
    return false;
  }
  
  log('Testing patient registration...');
  
  const patientData = { ...testPatient, user_id: testUserId };
  const result = await makeRequest('POST', '/patients/register', patientData);
  
  if (result.success) {
    testPatientId = result.data.patient?.id || result.data.id;
    log(`Patient registered successfully with ID: ${testPatientId}`, 'success');
    return true;
  } else {
    log(`Patient registration failed: ${result.error}`, 'error');
    return false;
  }
}

async function testFcmTokenSave() {
  if (!testUserId) {
    log('Skipping FCM token save - no user ID', 'warning');
    return false;
  }
  
  log('Testing FCM token save...');
  
  const tokenData = {
    userId: testUserId,
    fcmToken: testFcmToken
  };
  
  const result = await makeRequest('POST', '/auth/save-fcm-token', tokenData);
  
  if (result.success) {
    log('FCM token saved successfully', 'success');
    return true;
  } else {
    log(`FCM token save failed: ${result.error}`, 'error');
    return false;
  }
}

async function testAppointmentCreation() {
  if (!testUserId || !testPatientId) {
    log('Skipping appointment creation - missing user or patient ID', 'warning');
    return false;
  }
  
  log('Testing appointment creation...');
  
  // Create appointment for tomorrow to ensure reminders will be scheduled
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const appointmentDate = tomorrow.toISOString().split('T')[0];
  
  const appointmentData = {
    userId: testUserId,
    patientId: testPatientId,
    doctorName: 'Dr. Test Doctor',
    clinicHospital: 'Test Clinic',
    appointmentDate: appointmentDate,
    appointmentTime: '10:00:00',
    appointmentType: 'General Checkup',
    notes: 'Test appointment for reminder system'
  };
  
  const result = await makeRequest('POST', '/appointments/add', appointmentData);
  
  if (result.success) {
    testAppointmentId = result.data.data?.id || result.data.appointmentId;
    log(`Appointment created successfully with ID: ${testAppointmentId}`, 'success');
    return true;
  } else {
    log(`Appointment creation failed: ${result.error}`, 'error');
    return false;
  }
}

async function testReminderScheduleCreation() {
  if (!testAppointmentId) {
    log('Skipping reminder schedule test - no appointment ID', 'warning');
    return false;
  }
  
  log('Testing reminder schedule creation...');
  
  // Wait a moment for the reminder schedule to be created
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Check if reminders were created for the appointment
  const result = await makeRequest('GET', `/appointment-reminders/user/${testUserId}/upcoming`);
  
  if (result.success && result.data && result.data.length > 0) {
    const appointmentReminders = result.data.filter(r => r.appointment_id == testAppointmentId);
    log(`Found ${appointmentReminders.length} reminder schedules for appointment ${testAppointmentId}`, 'success');
    
    appointmentReminders.forEach((reminder, index) => {
      log(`  Reminder ${index + 1}: ${reminder.reminder_type} on ${reminder.reminder_date} at ${reminder.reminder_time} (${reminder.days_before} days before)`);
    });
    
    return true;
  } else {
    log(`No reminder schedules found for appointment ${testAppointmentId}`, 'error');
    return false;
  }
}

async function testUpcomingAppointmentsCheck() {
  if (!testUserId) {
    log('Skipping upcoming appointments check - no user ID', 'warning');
    return false;
  }
  
  log('Testing upcoming appointments check...');
  
  const result = await makeRequest('GET', `/appointment-reminders/user/${testUserId}/check-upcoming`);
  
  if (result.success) {
    log(`Upcoming appointments check successful`, 'success');
    log(`  Has upcoming: ${result.hasUpcoming}`);
    log(`  Appointments found: ${result.appointments ? result.appointments.length : 0}`);
    
    if (result.appointments && result.appointments.length > 0) {
      result.appointments.forEach((appointment, index) => {
        log(`  Appointment ${index + 1}: ${appointment.appointment_type} on ${appointment.appointment_date} at ${appointment.appointment_time}`);
      });
    }
    
    return true;
  } else {
    log(`Upcoming appointments check failed: ${result.error}`, 'error');
    return false;
  }
}

async function testDueRemindersCheck() {
  log('Testing due reminders check...');
  
  const result = await makeRequest('GET', '/appointment-reminders/check-due');
  
  if (result.success) {
    log(`Due reminders check successful`, 'success');
    log(`  Processed reminders: ${result.results ? result.results.length : 0}`);
    
    if (result.results && result.results.length > 0) {
      const successful = result.results.filter(r => r.success).length;
      const failed = result.results.length - successful;
      log(`  Successful: ${successful}, Failed: ${failed}`);
    }
    
    return true;
  } else {
    log(`Due reminders check failed: ${result.error}`, 'error');
    return false;
  }
}

async function testNotificationHistory() {
  if (!testUserId) {
    log('Skipping notification history test - no user ID', 'warning');
    return false;
  }
  
  log('Testing notification history...');
  
  // This would typically be a separate endpoint, but for now we'll check if notifications were created
  // by checking the notification_history table directly through the reminders endpoint
  const result = await makeRequest('GET', `/notifications/user/${testUserId}`);
  
  if (result.success) {
    log(`Notification history check successful`, 'success');
    log(`  Notifications found: ${result.data ? result.data.length : 0}`);
    
    return true;
  } else {
    log(`Notification history check failed: ${result.error}`, 'error');
    return false;
  }
}

async function cleanupTestData() {
  log('Cleaning up test data...');
  
  try {
    // Delete appointment if created
    if (testAppointmentId) {
      await makeRequest('DELETE', `/appointments/${testAppointmentId}`);
      log(`Deleted test appointment ${testAppointmentId}`);
    }
    
    // Delete patient if created
    if (testPatientId) {
      await makeRequest('DELETE', `/patients/${testPatientId}`);
      log(`Deleted test patient ${testPatientId}`);
    }
    
    // Note: We're not deleting the user to avoid conflicts with other tests
    log('Test data cleanup completed', 'success');
  } catch (error) {
    log(`Cleanup failed: ${error.message}`, 'error');
  }
}

// Main test execution
async function runTests() {
  log('🚀 Starting Appointment Reminder System Test');
  log('=====================================');
  
  const testResults = [];
  
  // Test 1: User Registration
  testResults.push(await testUserRegistration());
  
  // Test 2: Patient Registration
  testResults.push(await testPatientRegistration());
  
  // Test 3: FCM Token Save
  testResults.push(await testFcmTokenSave());
  
  // Test 4: Appointment Creation
  testResults.push(await testAppointmentCreation());
  
  // Test 5: Reminder Schedule Creation
  testResults.push(await testReminderScheduleCreation());
  
  // Test 6: Upcoming Appointments Check
  testResults.push(await testUpcomingAppointmentsCheck());
  
  // Test 7: Due Reminders Check
  testResults.push(await testDueRemindersCheck());
  
  // Test 8: Notification History
  testResults.push(await testNotificationHistory());
  
  // Summary
  log('=====================================');
  log('🏁 Test Results Summary');
  log('=====================================');
  
  const passed = testResults.filter(r => r).length;
  const failed = testResults.filter(r => !r).length;
  
  log(`Total tests: ${testResults.length}`);
  log(`Passed: ${passed}`, 'success');
  log(`Failed: ${failed}`, failed > 0 ? 'error' : 'info');
  log(`Success rate: ${((passed / testResults.length) * 100).toFixed(1)}%`);
  
  if (failed === 0) {
    log('🎉 All tests passed! Appointment reminder system is working correctly.', 'success');
  } else {
    log('⚠️ Some tests failed. Please check the errors above.', 'warning');
  }
  
  // Cleanup
  await cleanupTestData();
  
  log('=====================================');
  log('🏁 Test completed');
  log('=====================================');
  
  process.exit(failed > 0 ? 1 : 0);
}

// Handle uncaught errors
process.on('unhandledRejection', (reason, promise) => {
  log(`Unhandled Rejection at: ${promise}, reason: ${reason}`, 'error');
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  log(`Uncaught Exception: ${error}`, 'error');
  process.exit(1);
});

// Run the tests
runTests();
