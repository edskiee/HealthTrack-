// test_smart_reminder_queue.js - Test script to verify Smart Reminder Queue functionality
process.env.TEST_MODE = 'true'; // Enable test mode to bypass FCM validation

const http = require('http');

console.log('🏥 HealthTrack Smart Reminder Queue Test (TEST MODE)');
console.log('====================================================');

// Test data - using a valid user ID from the database
const testData = {
  userId: "1",  // Using the first user ID from our database
  notificationType: "appointment_reminder",
  message: "This is a test reminder from the Smart Reminder Queue",
  title: "Smart Reminder Test"
};

console.log('\n📋 Test Data:');
console.log('-------------');
console.log(`User ID: ${testData.userId}`);
console.log(`Notification Type: ${testData.notificationType}`);
console.log(`Title: ${testData.title}`);
console.log(`Message: ${testData.message}`);

// Test the Smart Reminder Queue endpoint
const postData = JSON.stringify(testData);

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/user-reminders/send-reminder',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('\n📤 Sending test reminder...');
console.log('-------------------------');

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
        console.log('\n✅ Smart Reminder Queue test completed successfully!');
        console.log('🎉 The Smart Reminder Queue system is working correctly in TEST MODE.');
        console.log('ℹ️  In production, this would send a real FCM notification.');
      } else {
        console.log('\n❌ Smart Reminder Queue test failed!');
        console.log(`📢 Error: ${responseData.message || 'Unknown error'}`);
        
        // Provide specific troubleshooting guidance
        if (responseData.message && responseData.message.includes('User not found')) {
          console.log('\n🔧 Troubleshooting Tips:');
          console.log('1. Verify the user ID exists in the database');
          console.log('2. Check that the users table has data');
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