// simple_notification_test.js - Simple test for notification system
const http = require('http');

console.log('🏥 HealthTrack Simple Notification Test');
console.log('===================================');

// Test sending a notification to user 1
const postData = JSON.stringify({
  userId: '1',
  notificationType: 'custom_message',
  message: 'Test notification to verify FCM delivery',
  title: 'FCM Delivery Test'
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/notifications/send',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('Testing notification send to user with FCM token...');

const req = http.request(options, (res) => {
  console.log(`Status code: ${res.statusCode}`);
  console.log(`Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Response headers:', res.headers);
    console.log('Raw response body:', data);
    
    try {
      const jsonData = JSON.parse(data);
      console.log('Parsed JSON response:', JSON.stringify(jsonData, null, 2));
      
      if (res.statusCode === 200 && jsonData.success) {
        console.log('✅ Notification sent successfully!');
        console.log(`   Notification ID: ${jsonData.data.notificationId}`);
        console.log(`   User: ${jsonData.data.userName}`);
        
        // Check if there were any FCM errors
        if (jsonData.data.fcmResponse) {
          if (jsonData.data.fcmResponse.success === false) {
            console.log('\n⚠️  FCM delivery failed:');
            console.log(`   Error: ${jsonData.data.fcmResponse.error}`);
            console.log(`   Code: ${jsonData.data.fcmResponse.code}`);
          } else {
            console.log('\n🎉 FCM delivery successful!');
          }
        } else {
          console.log('\n⚠️  No FCM response received (notification saved to database only)');
        }
      } else {
        console.log('❌ Notification send failed');
        console.log(`   Error: ${jsonData.message || 'Unknown error'}`);
      }
    } catch (e) {
      console.log(`❌ Failed to parse response: ${e.message}`);
      console.log('Raw response:', data);
    }
  });
});

req.on('error', (e) => {
  console.error(`❌ Request error: ${e.message}`);
});

req.write(postData);
req.end();