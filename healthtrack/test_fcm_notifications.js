// test_fcm_notifications.js - Test FCM notification delivery
const { sendPushNotification } = require('./backend_nodejs/src/services/firebaseService');

console.log('🧪 Testing FCM Notification Delivery');
console.log('===================================');

// Test notification payload
const testPayload = {
  title: 'Test Notification',
  body: 'This is a test notification to verify banner delivery',
  notificationType: 'system',
  data: {
    test: 'true',
    timestamp: new Date().toISOString()
  }
};

// Test FCM token (this would be a real token from a device)
// NOTE: Replace with an actual FCM token for testing
const testToken = process.argv[2] || 'YOUR_TEST_FCM_TOKEN_HERE';

if (testToken === 'YOUR_TEST_FCM_TOKEN_HERE') {
  console.log('⚠️  Please provide a valid FCM token as a command line argument');
  console.log('   Usage: node test_fcm_notifications.js <FCM_TOKEN>');
  process.exit(1);
}

async function testNotificationDelivery() {
  try {
    console.log('📤 Sending test notification...');
    
    // Send the notification
    const result = await sendPushNotification(testToken, testPayload);
    
    if (result.success) {
      console.log('✅ Notification sent successfully!');
      console.log('   Message ID:', result.messageId);
    } else {
      console.log('❌ Failed to send notification');
      console.log('   Error:', result.error);
      console.log('   Code:', result.code);
    }
  } catch (error) {
    console.log('💥 Error sending notification:', error.message);
  }
}

// Run the test
testNotificationDelivery();