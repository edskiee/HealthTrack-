// test_fcm_flow.js - Test the complete FCM token flow
const mysql = require('mysql2/promise');
const http = require('http');

console.log('🏥 HealthTrack FCM Token Flow Test');
console.log('===================================');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

// Test the complete FCM token flow
async function testFcmFlow() {
  let connection;
  
  try {
    // Create database connection
    connection = await mysql.createConnection(dbConfig);
    
    // 1. Check current state of user tokens
    console.log('\n📋 Checking current FCM token status...');
    const [users] = await connection.execute(
      'SELECT id, username, full_name, fcm_token FROM users WHERE id = 1'
    );
    
    if (users.length === 0) {
      console.log('❌ User ID 1 not found');
      return;
    }
    
    const user = users[0];
    console.log(`✅ User: ${user.full_name} (${user.username || 'N/A'})`);
    
    if (user.fcm_token) {
      const isFakeToken = user.fcm_token.includes('fake') || user.fcm_token.includes('test');
      console.log(`   Current FCM Token: ${isFakeToken ? 'FAKE/TEST' : 'REAL'} [${user.fcm_token.substring(0, 30)}...]`);
    } else {
      console.log('   Current FCM Token: ❌ NO TOKEN');
    }
    
    // 2. Simulate sending a real FCM token to the server
    console.log('\n📤 Testing FCM token save to server...');
    
    // Generate a realistic FCM token for testing (this would normally come from a real device)
    const testFcmToken = 'dZ:APA91bHqJf4jN2kFzJrY8vX9wQ6sT5uE4rR7yU8iI9oO0pP1qQ2wE3rT4yU5iO6pP7qQ8wE9rT0yU1iO2pP3qQ4wE5rT6yU7iO8pP9qQ0wE1rT2yU3iO4pP5qQ6wE7rT8yU9iO0pP1qQ2wE3rT4yU5';
    
    const postData = JSON.stringify({
      userId: user.id,
      fcmToken: testFcmToken
    });
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/auth/save-fcm-token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
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
            console.log('\n✅ FCM token saved successfully!');
            
            // Reconnect to database to verify the token was saved
            mysql.createConnection(dbConfig).then(async (newConnection) => {
              try {
                // 3. Verify the token was saved in the database
                console.log('\n🔍 Verifying token was saved in database...');
                const [updatedUsers] = await newConnection.execute(
                  'SELECT fcm_token FROM users WHERE id = ?', [user.id]
                );
                
                if (updatedUsers.length > 0 && updatedUsers[0].fcm_token === testFcmToken) {
                  console.log('✅ Token correctly saved in database');
                  
                  // 4. Test sending a notification to this user
                  console.log('\n📤 Testing notification send...');
                  const notificationData = JSON.stringify({
                    userId: user.id.toString(),
                    notificationType: 'custom_message',
                    message: 'Test notification to verify complete FCM flow',
                    title: 'FCM Flow Test'
                  });
                  
                  const notificationOptions = {
                    hostname: 'localhost',
                    port: 3000,
                    path: '/admin/notifications/send',
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'Content-Length': Buffer.byteLength(notificationData)
                    }
                  };
                  
                  const notificationReq = http.request(notificationOptions, (notificationRes) => {
                    console.log(`📊 Notification response status: ${notificationRes.statusCode}`);
                    
                    let notificationData = '';
                    
                    notificationRes.on('data', (chunk) => {
                      notificationData += chunk;
                    });
                    
                    notificationRes.on('end', () => {
                      try {
                        const notificationJson = JSON.parse(notificationData);
                        console.log('📄 Notification response:', JSON.stringify(notificationJson, null, 2));
                        
                        if (notificationRes.statusCode === 200 && notificationJson.success) {
                          console.log('\n🎉 COMPLETE FCM FLOW SUCCESSFUL!');
                          console.log('   1. Token generated and sent to server ✅');
                          console.log('   2. Token saved in database ✅');
                          console.log('   3. Notification sent successfully ✅');
                          console.log('\n💡 In a real scenario, the notification would now appear on the user\'s device');
                        } else {
                          console.log('\n❌ Notification send failed');
                          console.log(`   Error: ${notificationJson.message || 'Unknown error'}`);
                        }
                      } catch (e) {
                        console.log(`❌ Failed to parse notification response: ${e.message}`);
                      }
                    });
                  });
                  
                  notificationReq.on('error', (e) => {
                    console.error(`❌ Notification request error: ${e.message}`);
                  });
                  
                  notificationReq.write(notificationData);
                  notificationReq.end();
                  
                } else {
                  console.log('❌ Token not found or incorrect in database');
                }
              } catch (dbError) {
                console.log('❌ Database verification error:', dbError.message);
              } finally {
                await newConnection.end();
              }
            }).catch(err => {
              console.log('❌ Failed to reconnect to database:', err.message);
            });
          } else {
            console.log('\n❌ Failed to save FCM token');
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
testFcmFlow();