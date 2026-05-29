// test_welcome_notification.js - Test script to verify welcome notification functionality
process.env.TEST_MODE = 'true'; // Enable test mode to bypass FCM validation

const { sendWelcomeNotification } = require('./backend_nodejs/src/controllers/authController');

console.log('🏥 HealthTrack Welcome Notification Test (TEST MODE)');
console.log('================================================');

// Test the welcome notification function
async function testWelcomeNotification() {
  try {
    console.log('\n📧 Testing welcome notification...');
    
    // Test with a valid user ID (you may need to adjust this based on your database)
    const userId = 1; // Replace with an actual user ID from your database
    const serviceType = 'maternal';
    const userName = 'Test User';
    
    console.log(`\n👤 User ID: ${userId}`);
    console.log(`サービスタイプ: ${serviceType}`);
    console.log(`ユーザー名: ${userName}`);
    
    // Call the welcome notification function
    const result = await sendWelcomeNotification(userId, serviceType, userName);
    
    console.log('\n📊 Result:');
    console.log(JSON.stringify(result, null, 2));
    
    if (result.success) {
      console.log('\n✅ Welcome notification test completed successfully!');
      console.log('🎉 The welcome notification system is working correctly in TEST MODE.');
      console.log('ℹ️  In production, this would send a real FCM notification.');
    } else {
      console.log('\n❌ Welcome notification test failed!');
      console.log(`📢 Error: ${result.message}`);
      
      // Provide specific troubleshooting guidance
      if (result.message && result.message.includes('FCM token')) {
        console.log('\n🔧 Troubleshooting Tips:');
        console.log('1. The user does not have a valid FCM token registered');
        console.log('2. Ensure the user has logged into the mobile app');
        console.log('3. Check that the mobile app has internet connectivity');
        console.log('4. Verify FCM token is being saved to the database');
      } else {
        console.log('\n🔧 General Troubleshooting:');
        console.log('1. Check that the backend server is running');
        console.log('2. Verify database connectivity');
        console.log('3. Check server logs for detailed error information');
      }
    }
  } catch (error) {
    console.log('\n❌ Welcome notification test failed with exception!');
    console.log(`📢 Error: ${error.message}`);
    console.log('\n🔧 Troubleshooting Tips:');
    console.log('1. Ensure the backend server is running');
    console.log('2. Check that there are no syntax errors in the code');
    console.log('3. Verify all required modules are installed');
  }
}

// Run the test
testWelcomeNotification();