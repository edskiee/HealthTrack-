// check_user_token.js - Check if user has a valid FCM token
const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

async function checkUserToken() {
  console.log('🏥 HealthTrack User FCM Token Check');
  console.log('==================================');
  
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    
    // Check user ID 1
    console.log('\n📋 Checking user ID 1...');
    const [rows] = await connection.execute(
      'SELECT id, username, full_name, fcm_token FROM users WHERE id = ?', 
      [1]
    );
    
    if (rows.length > 0) {
      const user = rows[0];
      console.log(`✅ User found:`);
      console.log(`   ID: ${user.id}`);
      console.log(`   Username: ${user.username}`);
      console.log(`   Full Name: ${user.full_name}`);
      
      if (user.fcm_token) {
        console.log(`   FCM Token: ${user.fcm_token.substring(0, 50)}...`);
        console.log(`   ✅ User has a valid FCM token`);
      } else {
        console.log(`   ❌ User does not have an FCM token`);
      }
    } else {
      console.log('❌ User ID 1 not found');
    }
    
    // Check all users with FCM tokens
    console.log('\n📋 Checking all users with FCM tokens...');
    const [allRows] = await connection.execute(
      'SELECT id, username, full_name, fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != ""'
    );
    
    console.log(`✅ Found ${allRows.length} users with FCM tokens:`);
    allRows.forEach(user => {
      console.log(`   - ${user.full_name} (${user.username}) - Token: ${user.fcm_token.substring(0, 30)}...`);
    });
    
  } catch (error) {
    console.error('❌ Database error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the check
checkUserToken();