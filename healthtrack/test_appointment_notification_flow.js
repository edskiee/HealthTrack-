// Test script for appointment booking notification flow
const axios = require('axios');
const io = require('socket.io-client');

// Configuration
const SERVER_URL = 'http://localhost:3000'; // Adjust to your server URL
const TEST_USER_ID = 1; // Test user ID
const TEST_PATIENT_ID = 1; // Test patient ID
const TEST_APPOINTMENT_ID = 1; // Test appointment ID

// Connect to WebSocket server
const socket = io(SERVER_URL);

socket.on('connect', () => {
  console.log('🟢 Connected to WebSocket server');
});

socket.on('disconnect', () => {
  console.log('🔴 Disconnected from WebSocket server');
});

// Listen for appointment notifications
socket.on('appointmentNotification', (data) => {
  console.log('📬 Received appointment notification:', data);
});

async function testAppointmentNotificationFlow() {
  try {
    console.log('Testing appointment booking notification flow...\n');
    
    // Step 1: Test sending appointment status notification directly
    console.log('Step 1: Sending appointment status notification...');
    const statusResponse = await axios.post(`${SERVER_URL}/admin/notifications/send-status`, {
      userId: TEST_USER_ID.toString(),
      appointmentId: TEST_APPOINTMENT_ID.toString(),
      status: 'confirmed',
      message: 'Your appointment has been successfully booked.'
    });
    
    console.log('Status notification response:', statusResponse.data);
    
    // Step 2: Wait to see if WebSocket notification is received
    console.log('\nStep 2: Waiting for WebSocket notification...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Step 3: Check if notification was saved in database
    console.log('\nStep 3: Checking if notification was saved in database...');
    try {
      const notificationsResponse = await axios.get(`${SERVER_URL}/notifications/user/${TEST_USER_ID}`);
      console.log('User notifications:', notificationsResponse.data);
    } catch (error) {
      console.log('Could not fetch notifications:', error.message);
    }
    
    // Step 4: Test FCM notification sending
    console.log('\nStep 4: Testing FCM notification sending...');
    try {
      // This would typically be triggered by the backend when an appointment is booked
      const fcmResponse = await axios.post(`${SERVER_URL}/fcm-notifications/patient-notification`, {
        patientId: TEST_PATIENT_ID,
        title: 'Appointment Confirmed',
        message: 'Your appointment has been successfully booked.',
        notificationType: 'appointment'
      });
      
      console.log('FCM notification response:', fcmResponse.data);
    } catch (error) {
      console.log('FCM notification test failed:', error.message);
      if (error.response) {
        console.log('FCM response data:', error.response.data);
      }
    }
    
    console.log('\n=== Test Summary ===');
    console.log('Appointment notification flow test completed.');
    console.log('Check console output for notification events and database entries.');
    
  } catch (error) {
    console.error('Test failed with error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  } finally {
    socket.disconnect();
  }
}

// Run the test after a short delay to allow WebSocket connection
setTimeout(testAppointmentNotificationFlow, 1000);