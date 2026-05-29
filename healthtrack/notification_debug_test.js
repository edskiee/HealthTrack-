// notification_debug_test.js - Comprehensive test for notification system debugging
const mysql = require('mysql2/promise');
const http = require('http');

console.log('🏥 HealthTrack Notification System Debug Test');
console.log('==========================================');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

// Test sending a notification to user with a real FCM token
async function testNotificationFlow() {
  let connection;
  
  try {
    // Create database connection
    connection = await mysql.createConnection(dbConfig);
    
    // 1. Check all users with FCM tokens
    console.log('\n📋 Checking all users with FCM tokens...');
    const [allRows] = await connection.execute(
      'SELECT id, username, full_name, fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != ""'
    );
    
    console.log(`✅ Found ${allRows.length} users with FCM tokens:`);
    allRows.forEach(user => {
      const isFakeToken = user.fcm_token.includes('fake') || user.fcm_token.includes('test');
      console.log(`   - ${user.full_name} (${user.username || 'N/A'}) - Token: ${isFakeToken ? 'FAKE/TEST' : 'REAL'} [${user.fcm_token.substring(0, 30)}...]`);
    });
    
    // 2. Find a user with a real FCM token (not fake/test)
    const realTokenUser = allRows.find(user => 
      !user.fcm_token.includes('fake') && 
      !user.fcm_token.includes('test') &&
      user.fcm_token.length > 50
    );
    
    if (!realTokenUser) {
      console.log('\n❌ No users with real FCM tokens found!');
      console.log('💡 Solution: Login to the app to generate a real FCM token');
      return;
    }
    
    console.log(`\n🎯 Testing notification send to user with real token:`);
    console.log(`   User: ${realTokenUser.full_name} (ID: ${realTokenUser.id})`);
    console.log(`   Token preview: ${realTokenUser.fcm_token.substring(0, 50)}...`);
    
    // 3. Test sending notification to this user
    const postData = JSON.stringify({
      userId: realTokenUser.id.toString(),
      notificationType: 'debug_test',
      message: 'Debug test notification to verify FCM delivery',
      title: 'FCM Debug Test'
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
    
    console.log('\n📤 Sending notification...');
    
    const req = http.request(options, (res) => {
      console.log(`📊 Response status: ${res.statusCode}`);
      console.log(`📊 Content-Type: ${res.headers['content-type']}`);
      
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          console.log('📄 Response:', JSON.stringify(jsonData, null, 2));
          
          if (res.statusCode === 200 && jsonData.success) {
            console.log('\n✅ Notification sent successfully!');
            console.log(`   Notification ID: ${jsonData.data.notificationId}`);
            console.log(`   User: ${jsonData.data.userName}`);
            
            // Check if there were any FCM errors
            if (jsonData.data.fcmResponse) {
              console.log(`   FCM Response: ${JSON.stringify(jsonData.data.fcmResponse)}`);
              
              if (jsonData.data.fcmResponse.success === false) {
                console.log('\n⚠️  FCM delivery failed:');
                console.log(`   Error: ${jsonData.data.fcmResponse.error}`);
                console.log(`   Code: ${jsonData.data.fcmResponse.code}`);
                
                // Provide specific troubleshooting advice
                if (jsonData.data.fcmResponse.code === 'messaging/invalid-registration-token') {
                  console.log('\n💡 Troubleshooting tip: The FCM token is invalid or expired.');
                  console.log('   Solution: Have the user log out and log back in to generate a new token.');
                } else if (jsonData.data.fcmResponse.code === 'messaging/registration-token-not-registered') {
                  console.log('\n💡 Troubleshooting tip: The FCM token is not registered with FCM.');
                  console.log('   Solution: Have the user log out and log back in to generate a new token.');
                }
              } else {
                console.log('\n🎉 FCM delivery successful!');
                console.log('   The notification should appear on the user\'s device shortly.');
              }
            } else {
              console.log('\n⚠️  No FCM response received (notification saved to database only)');
            }
          } else {
            console.log('\n❌ Notification send failed');
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
    
  } catch (error) {
    console.error('❌ Database error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the test
testNotificationFlow();