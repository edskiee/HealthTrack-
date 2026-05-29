const http = require('http');

// Test the exact scenario described by the user:
// Sending a reminder to a specific user who is registered and whose records are fetched successfully

// First, let's test fetching user records to simulate the successful data connection
const fetchUserOptions = {
  hostname: 'localhost',
  port: 3000,
  path: '/patients/data', // This should fetch patient records
  method: 'GET',
  headers: {
    'Content-Type': 'application/json'
  }
};

console.log('Step 1: Testing patient records fetch (should succeed)...');

const fetchUserReq = http.request(fetchUserOptions, (res) => {
  console.log(`Patient records fetch status: ${res.statusCode}`);
  
  let userData = '';
  res.on('data', (chunk) => {
    userData += chunk;
  });
  
  res.on('end', () => {
    if (res.statusCode === 200) {
      console.log('✅ Patient records fetch successful');
      
      // Now test sending a notification to simulate the reminder scenario
      console.log('\nStep 2: Testing notification send to specific user...');
      
      const notificationData = JSON.stringify({
        userId: '1', // Assuming user ID 1 exists
        patientId: '1',
        notificationType: 'custom_message',
        message: 'Test reminder message to verify notification system',
        title: 'Reminder Test'
      });
      
      const sendNotificationOptions = {
        hostname: 'localhost',
        port: 3000,
        path: '/admin/notifications/send',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(notificationData)
        }
      };
      
      const sendNotificationReq = http.request(sendNotificationOptions, (res) => {
        console.log(`Notification send status: ${res.statusCode}`);
        console.log(`Content-Type: ${res.headers['content-type']}`);
        
        let notificationResponse = '';
        res.on('data', (chunk) => {
          notificationResponse += chunk;
        });
        
        res.on('end', () => {
          console.log('Raw notification response:', notificationResponse);
          
          try {
            const jsonData = JSON.parse(notificationResponse);
            console.log('Parsed notification response:', JSON.stringify(jsonData, null, 2));
            
            if (res.statusCode === 200 && jsonData.success) {
              console.log('✅ Notification sent successfully - No endpoint issue found');
            } else if (res.statusCode === 404) {
              console.log('❌ Notification endpoint not found - This matches the user\'s error');
            } else {
              console.log(`⚠️ Other error: ${jsonData.message || 'Unknown error'}`);
            }
          } catch (e) {
            console.log('Failed to parse notification response as JSON');
          }
        });
      });
      
      sendNotificationReq.on('error', (e) => {
        console.error('❌ Notification send error:', e.message);
      });
      
      sendNotificationReq.write(notificationData);
      sendNotificationReq.end();
      
    } else {
      console.log('❌ Patient records fetch failed');
      console.log('Response:', userData);
    }
  });
});

fetchUserReq.on('error', (e) => {
  console.error('❌ Patient records fetch error:', e.message);
});

fetchUserReq.end();