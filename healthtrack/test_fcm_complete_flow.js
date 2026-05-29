const mysql = require('mysql2/promise');
const { sendPushNotification, isValidFcmToken } = require('./backend_nodejs/src/services/firebaseService');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

async function testCompleteFcmFlow() {
  let pool;
  let connection;
  
  try {
    console.log('🧪 Testing complete FCM notification flow...\n');
    
    // 1. Check database connection and users table
    pool = mysql.createPool(dbConfig);
    connection = await pool.getConnection();
    console.log('✅ Database connection established');
    
    // 2. Check if we have users with FCM tokens
    console.log('\n📋 Checking users with FCM tokens...');
    const [users] = await connection.execute(
      'SELECT id, full_name, fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != "" LIMIT 5'
    );
    
    if (users.length === 0) {
      console.log('⚠️ No users found with FCM tokens. Need to register a user and save their token first.');
      return;
    }
    
    console.log(`✅ Found ${users.length} users with FCM tokens:`);
    users.forEach((user, index) => {
      console.log(`  ${index + 1}. ${user.full_name} (ID: ${user.id})`);
      console.log(`     Token: ${user.fcm_token ? user.fcm_token.substring(0, 50) + '...' : 'None'}`);
      
      // Validate token format
      const isValid = isValidFcmToken(user.fcm_token);
      console.log(`     Valid format: ${isValid ? '✅' : '❌'}`);
    });
    
    // 3. Test sending notification to the first user with a valid token
    const validUser = users.find(user => isValidFcmToken(user.fcm_token));
    if (!validUser) {
      console.log('\n⚠️ No users with valid FCM token format found.');
      return;
    }
    
    console.log(`\n📤 Sending test notification to user: ${validUser.full_name} (ID: ${validUser.id})`);
    
    // 4. Send FCM notification
    const payload = {
      title: 'FCM Test Notification',
      body: 'This is a test notification to verify the complete FCM flow is working',
      data: {
        test: 'true',
        userId: validUser.id.toString(),
        timestamp: new Date().toISOString()
      }
    };
    
    console.log('📨 Payload:', JSON.stringify(payload, null, 2));
    
    const result = await sendPushNotification(validUser.fcm_token, payload);
    
    console.log('\n📊 FCM Send Result:');
    console.log(`   Success: ${result.success ? '✅' : '❌'}`);
    if (result.success) {
      console.log(`   Message ID: ${result.messageId}`);
    } else {
      console.log(`   Error: ${result.error}`);
      console.log(`   Code: ${result.code}`);
      
      // If token is invalid, clear it from database
      if (result.code === 'messaging/invalid-registration-token' || 
          result.code === 'messaging/registration-token-not-registered') {
        console.log(`\n🗑️ Clearing invalid token for user ${validUser.id}`);
        await connection.execute(
          'UPDATE users SET fcm_token = NULL WHERE id = ?',
          [validUser.id]
        );
      }
    }
    
    // 5. Test database notification creation
    console.log('\n💾 Creating notification record in database...');
    const insertQuery = `
      INSERT INTO notifications (
        user_id, 
        notification_type, 
        title,
        message, 
        is_read
      ) VALUES (?, ?, ?, ?, 0)
    `;
    
    const insertValues = [
      validUser.id, 
      'custom_message', 
      'FCM Test Notification',
      'This is a test notification to verify the complete FCM flow is working'
    ];
    
    const [insertResult] = await connection.execute(insertQuery, insertValues);
    console.log(`✅ Notification record created with ID: ${insertResult.insertId}`);
    
  } catch (error) {
    console.error('❌ Error in FCM flow test:', error.message);
  } finally {
    if (connection) {
      connection.release();
    }
    if (pool) {
      await pool.end();
    }
  }
}

testCompleteFcmFlow();