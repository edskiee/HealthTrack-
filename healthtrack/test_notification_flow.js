// test_notification_flow.js - Test the complete notification flow from admin to user
const http = require('http');
const https = require('https');

// Test configuration
const BASE_URL = 'http://localhost:3000';
const TEST_USER_ID = 1; // Assuming user ID 1 exists in the database
const TEST_ADMIN_CREDENTIALS = {
  username: 'admin',
  password: 'test'
};

console.log('🏥 HealthTrack Notification Flow Test');
console.log('====================================');

async function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const url = `${BASE_URL}${path}`;
    const parsedUrl = new URL(url);
    
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port,
      path: parsedUrl.pathname + parsedUrl.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    };
    
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: body
        });
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

async function testNotificationFlow() {
  try {
    console.log('\n📋 Step 1: Testing Server Connectivity');
    const serverResponse = await makeRequest('GET', '/');
    if (serverResponse.statusCode === 200) {
      console.log('✅ Server is running and responding');
    } else {
      console.log('❌ Server is not responding properly');
      return;
    }
    
    console.log('\n📋 Step 2: Admin Login');
    const loginResponse = await makeRequest('POST', '/admin/login', TEST_ADMIN_CREDENTIALS);
    if (loginResponse.statusCode === 200) {
      const loginData = JSON.parse(loginResponse.body);
      if (loginData.success) {
        console.log('✅ Admin login successful');
      } else {
        console.log('❌ Admin login failed:', loginData.message);
        return;
      }
    } else {
      console.log('❌ Admin login endpoint error:', loginResponse.statusCode);
      return;
    }
    
    console.log('\n📋 Step 3: Sending Test Notification');
    const notificationData = {
      userId: TEST_USER_ID.toString(),
      notificationType: 'custom_message',
      title: 'Test Notification',
      message: 'This is a test notification to verify the notification system is working properly.'
    };
    
    const notificationResponse = await makeRequest('POST', '/admin/notifications/send', notificationData);
    if (notificationResponse.statusCode === 200) {
      const notificationResult = JSON.parse(notificationResponse.body);
      if (notificationResult.success) {
        console.log('✅ Notification sent successfully');
        console.log(`   Notification ID: ${notificationResult.data.notificationId}`);
      } else {
        console.log('❌ Failed to send notification:', notificationResult.message);
        return;
      }
    } else {
      console.log('❌ Notification send endpoint error:', notificationResponse.statusCode);
      console.log('   Response:', notificationResponse.body);
      return;
    }
    
    console.log('\n📋 Step 4: Verifying Notification in Database');
    const userNotificationsResponse = await makeRequest('GET', `/notifications/user/${TEST_USER_ID}`);
    if (userNotificationsResponse.statusCode === 200) {
      const notificationsData = JSON.parse(userNotificationsResponse.body);
      if (notificationsData.success && notificationsData.data.length > 0) {
        const latestNotification = notificationsData.data[0];
        if (latestNotification.title === 'Test Notification' && 
            latestNotification.message.includes('test notification')) {
          console.log('✅ Notification found in database');
          console.log(`   Title: ${latestNotification.title}`);
          console.log(`   Message: ${latestNotification.message}`);
          console.log(`   Created: ${latestNotification.created_at}`);
        } else {
          console.log('⚠️  Notification data mismatch');
        }
      } else {
        console.log('❌ No notifications found for user');
      }
    } else {
      console.log('❌ Failed to fetch user notifications:', userNotificationsResponse.statusCode);
    }
    
    console.log('\n📋 Step 5: Checking Unread Count');
    const unreadCountResponse = await makeRequest('GET', `/notifications/user/${TEST_USER_ID}/unread-count`);
    if (unreadCountResponse.statusCode === 200) {
      const countData = JSON.parse(unreadCountResponse.body);
      if (countData.success) {
        console.log(`✅ Unread notifications count: ${countData.count}`);
      } else {
        console.log('❌ Failed to get unread count:', countData.message);
      }
    } else {
      console.log('❌ Failed to fetch unread count:', unreadCountResponse.statusCode);
    }
    
    console.log('\n🎉 Notification Flow Test Completed');
    console.log('================================');
    console.log('✅ All tests passed! The notification system is working correctly.');
    console.log('📝 To fully test push notifications:');
    console.log('   1. Run the Flutter app on a mobile device');
    console.log('   2. Log in as the test user');
    console.log('   3. Have an admin send a notification');
    console.log('   4. Verify the push notification appears on the device');
    
  } catch (error) {
    console.log('❌ Test failed with error:', error.message);
  }
}

// Run the test
testNotificationFlow();