// test_fcm_notification_with_test_mode.js - Test script to verify FCM notification flow in test mode
process.env.TEST_MODE = 'true';

const http = require('http');

console.log('🏥 HealthTrack FCM Notification Fix Test (TEST MODE)');
console.log('===================================================');

// Test data - using a valid patient ID from the database
const testData = {
  patientId: "72",  // Using the first patient ID from our database check
  title: "Test Appointment Reminder",
  message: "This is a test appointment reminder notification"
};

console.log('\n📋 Test Data:');
console.log('-------------');
console.log(`Patient ID: ${testData.patientId}`);
console.log(`Title: ${testData.title}`);
console.log(`Message: ${testData.message}`);

// Test the FCM notification endpoint
const postData = JSON.stringify(testData);

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/fcm-notifications/appointment-reminder',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('\n📤 Sending test notification...');
console.log('------------------------------');

const req = http.request(options, (res) => {
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log(`📊 Response Status: ${res.statusCode}`);
    console.log(`📊 Response Headers: ${JSON.stringify(res.headers)}`);
    
    try {
      const responseData = JSON.parse(data);
      console.log(`📄 Response Body: ${JSON.stringify(responseData, null, 2)}`);
      
      if (res.statusCode === 200 && responseData.success) {
        console.log('\n✅ FCM notification sent successfully!');
        console.log('🎉 The notification system is working correctly in TEST MODE.');
        console.log('ℹ️  In production, this would send a real FCM notification.');
      } else {
        console.log('\n❌ FCM notification failed!');
        console.log(`📢 Error: ${responseData.message || 'Unknown error'}`);
        
        // Provide specific troubleshooting guidance
        if (responseData.message && responseData.message.includes('Patient not found')) {
          console.log('\n🔧 Troubleshooting Tips:');
          console.log('1. Verify the patient ID exists in the database');
          console.log('2. Check that the patients table has data');
        } else if (responseData.message && responseData.message.includes('FCM token')) {
          console.log('\n🔧 Troubleshooting Tips:');
          console.log('1. The patient does not have a valid FCM token registered');
          console.log('2. Ensure the patient has logged into the mobile app');
          console.log('3. Check that the mobile app has internet connectivity');
          console.log('4. Verify FCM token is being saved to the database');
        } else {
          console.log('\n🔧 General Troubleshooting:');
          console.log('1. Check that the backend server is running');
          console.log('2. Verify database connectivity');
          console.log('3. Check server logs for detailed error information');
        }
      }
    } catch (parseError) {
      console.log(`📄 Raw Response: ${data}`);
      console.log(`❌ Error parsing response: ${parseError.message}`);
    }
  });
});

req.on('error', (error) => {
  console.log(`❌ Request Error: ${error.message}`);
  console.log('\n🔧 Troubleshooting Tips:');
  console.log('1. Ensure the backend server is running on port 3000');
  console.log('2. Check that there are no firewall restrictions');
  console.log('3. Verify the network connection');
});

req.write(postData);
req.end();

console.log('\n🕒 Waiting for response...');