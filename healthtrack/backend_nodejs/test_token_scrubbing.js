const db = require('./src/config/db');
const { sendPushNotification } = require('./src/services/firebaseService');

async function runTest() {
  const testToken = 'invalid_test_token_1234567890_1234567890_1234567890_xyz';
  
  try {
    // 1. Manually add an invalid token into DB for a test user
    console.log('Inserting mock token for test user...');
    await db.execute('UPDATE users SET fcm_token = ? WHERE id = 1', [testToken]);
    
    // 2. Fetch it to confirm
    const [users] = await db.execute('SELECT fcm_token FROM users WHERE id = 1');
    console.log('User 1 Token Before:', users[0]?.fcm_token);
    
    // 3. Attempt pushing to this invalid token (requires bypassing TEST_MODE to invoke Firebase API)
    process.env.TEST_MODE = 'false';
    const payload = {
      title: 'Validation Test',
      body: 'This should trigger an invalid FCM token scrub'
    };
    
    console.log('Pushing notification...');
    const result = await sendPushNotification(testToken, payload);
    console.log('Push Result:', result);
    
    // 4. Check if token was scrubbed by the new updated service
    const [usersAfter] = await db.execute('SELECT fcm_token FROM users WHERE id = 1');
    console.log('User 1 Token After:', usersAfter[0]?.fcm_token);
    
    if (!usersAfter[0]?.fcm_token) {
      console.log('✅ TEST PASSED: Invalid token successfully scrubbed from database.');
    } else {
      console.error('❌ TEST FAILED: Token was not scrubbed.');
    }
  } catch (err) {
    console.error('Unexpected setup error:', err);
  } finally {
    process.exit(0);
  }
}

runTest();
