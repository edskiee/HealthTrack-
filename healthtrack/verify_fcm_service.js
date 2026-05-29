const { isValidFcmToken } = require('./backend_nodejs/src/services/firebaseService');

console.log('🧪 Verifying FCM Service Functions');
console.log('===================================');

// Test valid FCM token
const validToken = 'dXGJz2vKQcOzVKzXJ:APA91bGvKz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJ';
console.log(`Valid token test: ${isValidFcmToken(validToken) ? '✅ PASSED' : '❌ FAILED'}`);

// Test invalid FCM tokens
const invalidTokens = [
  '',  // Empty string
  'abc123',  // Too short
  'dXGJz2vKQcOzVKzXJ:APA91bGvKz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJ ',  // Contains space
  'dXGJz2vKQcOzVKzXJ:APA91bGvKz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJdXGJz2vKQcOzVKzXJ!',  // Contains invalid character
  null,  // Null value
  undefined  // Undefined value
];

let allInvalidTestsPassed = true;
invalidTokens.forEach((token, index) => {
  const result = isValidFcmToken(token);
  if (result === false) {
    console.log(`Invalid token test ${index + 1}: ✅ PASSED`);
  } else {
    console.log(`Invalid token test ${index + 1}: ❌ FAILED (returned ${result})`);
    allInvalidTestsPassed = false;
  }
});

console.log('\n📋 FCM Token Validation Summary:');
console.log('===============================');
console.log(`Valid token validation: ${isValidFcmToken(validToken) ? '✅ WORKING' : '❌ BROKEN'}`);
console.log(`Invalid token validation: ${allInvalidTestsPassed ? '✅ WORKING' : '❌ BROKEN'}`);

console.log('\n🎉 FCM Service Validation: COMPLETE');