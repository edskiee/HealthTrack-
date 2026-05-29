const http = require('http');

// Test 1: Check if patient has FCM token
console.log('Test 1: Checking patient FCM token status...');
const checkTokenOptions = {
  hostname: 'localhost',
  port: 3000,
  path: '/fcm-notifications/check-patient-token',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  }
};

const checkTokenData = JSON.stringify({
  patientId: '78'
});

const checkTokenReq = http.request(checkTokenOptions, (res) => {
  console.log(`Check token status: ${res.statusCode}`);
  
  res.on('data', (chunk) => {
    const result = JSON.parse(chunk);
    console.log('Check token result:', result);
    
    // Test 2: Try to send reminder (should fail because no FCM token)
    console.log('\nTest 2: Trying to send appointment reminder...');
    const sendReminderOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/fcm-notifications/appointment-reminder',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const sendReminderData = JSON.stringify({
      patientId: '78',
      title: 'Test Appointment Reminder',
      message: 'This is a test reminder for your appointment'
    });

    const sendReminderReq = http.request(sendReminderOptions, (res) => {
      console.log(`Send reminder status: ${res.statusCode}`);
      
      res.on('data', (chunk) => {
        console.log('Send reminder result:', chunk.toString());
        console.log('\nAll tests completed.');
      });
    });

    sendReminderReq.on('error', (error) => {
      console.error('Error sending reminder:', error);
    });

    sendReminderReq.write(sendReminderData);
    sendReminderReq.end();
  });
});

checkTokenReq.on('error', (error) => {
  console.error('Error checking token:', error);
});

checkTokenReq.write(checkTokenData);
checkTokenReq.end();