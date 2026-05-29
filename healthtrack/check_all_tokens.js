// check_all_tokens.js - Check all users and their FCM tokens
const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack'
};

async function checkAllTokens() {
  console.log('🏥 HealthTrack All Users FCM Token Check');
  console.log('=======================================');
  
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    
    // Check all users
    console.log('\n📋 Checking all users...');
    const [rows] = await connection.execute(
      'SELECT id, username, full_name, fcm_token FROM users ORDER BY id'
    );
    
    console.log(`✅ Found ${rows.length} users:`);
    rows.forEach(user => {
      console.log(`\nUser ID: ${user.id}`);
      console.log(`   Username: ${user.username || 'N/A'}`);
      console.log(`   Full Name: ${user.full_name || 'N/A'}`);
      
      if (user.fcm_token) {
        // Check if it's a fake/test token
        const isFakeToken = user.fcm_token.includes('fake') || user.fcm_token.includes('test');
        console.log(`   FCM Token: ${user.fcm_token.substring(0, 50)}${user.fcm_token.length > 50 ? '...' : ''}`);
        console.log(`   Token Status: ${isFakeToken ? '❌ FAKE/TEST TOKEN' : '✅ REAL TOKEN'}`);
      } else {
        console.log(`   FCM Token: ❌ NO TOKEN`);
      }
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
checkAllTokens();