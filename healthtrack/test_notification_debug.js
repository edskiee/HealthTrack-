// test_notification_debug.js - Debug script to test notification flow
const http = require('http');

console.log('🏥 HealthTrack Notification Debug Test');
console.log('====================================');

// Test 1: Check if we can connect to the server
console.log('\n📋 Test 1: Server Connectivity');
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/',
  method: 'GET'
};

const req = http.request(options, (res) => {
  console.log(`✅ Server response: ${res.statusCode}`);
  console.log(`   Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log(`   Server message: ${jsonData.message}`);
      
      // Test 2: Check if we can get a user's FCM token
      console.log('\n📋 Test 2: Check User FCM Token');
      const userOptions = {
        hostname: 'localhost',
        port: 3000,
        path: '/auth/check-fcm-token/1', // Check user ID 1
        method: 'GET'
      };
      
      const userReq = http.request(userOptions, (userRes) => {
        console.log(`   User token check response: ${userRes.statusCode}`);
        
        let userData = '';
        userRes.on('data', (chunk) => {
          userData += chunk;
        });
        
        userRes.on('end', () => {
          try {
            const userJsonData = JSON.parse(userData);
            console.log(`   User token data: ${JSON.stringify(userJsonData, null, 2)}`);
            
            // Test 3: Try to send a test notification
            console.log('\n📋 Test 3: Send Test Notification');
            const postData = JSON.stringify({
              userId: '1',
              notificationType: 'custom_message',
              message: 'Test notification for debugging',
              title: 'Debug Test'
            });
            
            const notificationOptions = {
              hostname: 'localhost',
              port: 3000,
              path: '/admin/notifications/send',
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
              }
            };
            
            const notificationReq = http.request(notificationOptions, (notificationRes) => {
              console.log(`   Notification send response: ${notificationRes.statusCode}`);
              
              let notificationData = '';
              notificationRes.on('data', (chunk) => {
                notificationData += chunk;
              });
              
              notificationRes.on('end', () => {
                console.log(`   Notification response data: ${notificationData}`);
                try {
                  const notificationJsonData = JSON.parse(notificationData);
                  console.log(`   Notification result: ${JSON.stringify(notificationJsonData, null, 2)}`);
                } catch (e) {
                  console.log(`   Could not parse notification response: ${e.message}`);
                }
                
                console.log('\n📋 Debug Test Complete');
              });
            });
            
            notificationReq.on('error', (e) => {
              console.error(`❌ Notification send error: ${e.message}`);
            });
            
            notificationReq.write(postData);
            notificationReq.end();
            
          } catch (e) {
            console.log(`   Could not parse user data: ${e.message}`);
          }
        });
      });
      
      userReq.on('error', (e) => {
        console.error(`❌ User token check error: ${e.message}`);
      });
      
      userReq.end();
      
    } catch (e) {
      console.log(`   Could not parse server response: ${e.message}`);
    }
  });
});

req.on('error', (e) => {
  console.error(`❌ Server connection error: ${e.message}`);
});

req.end();