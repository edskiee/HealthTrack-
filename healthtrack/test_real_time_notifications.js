/**
 * Comprehensive test for real-time notification delivery
 * Tests appointment approval, rescheduling, and reminder notifications
 */

const { sendAppointmentApprovalNotification } = require('./backend_nodejs/src/services/automatedReminderService');
const { sendAppointmentConfirmationNotification } = require('./backend_nodejs/src/services/automatedReminderService');
const { sendAppointmentReschedulingNotification } = require('./backend_nodejs/src/services/automatedReminderService');
const { sendCancellationAlert } = require('./backend_nodejs/src/services/automatedReminderService');
const { createAppointmentReminderSchedule } = require('./backend_nodejs/src/services/appointmentReminderService');
const { sendPushNotification } = require('./backend_nodejs/src/services/firebaseService');
const db = require('./backend_nodejs/src/config/db');

async function testRealTimeNotifications() {
  console.log('=== Testing Real-Time Notification Delivery ===');
  
  try {
    // Test 1: Get a test user with valid FCM token
    console.log('\n1. Finding test user with FCM token...');
    const [users] = await db.execute('SELECT id, full_name, fcm_token FROM users WHERE fcm_token IS NOT NULL LIMIT 1');
    
    if (users.length === 0) {
      console.log('No users with FCM tokens found. Creating test notification...');
      // Test with a dummy token
      const testResult = await sendPushNotification('test_token_' + Date.now(), {
        title: 'System Test',
        body: 'Testing notification system',
        notificationType: 'system_test'
      });
      console.log('Test notification result:', testResult);
      return;
    }
    
    const testUser = users[0];
    console.log(`Found test user: ${testUser.full_name} (ID: ${testUser.id})`);
    console.log(`FCM Token: ${testUser.fcm_token.substring(0, 20)}...`);
    
    // Test 2: Appointment Approval Notification
    console.log('\n2. Testing appointment approval notification...');
    const approvalResult = await sendAppointmentApprovalNotification(69);
    console.log('Approval notification result:', approvalResult);
    
    // Test 3: Appointment Confirmation Notification
    console.log('\n3. Testing appointment confirmation notification...');
    const confirmationResult = await sendAppointmentConfirmationNotification(69);
    console.log('Confirmation notification result:', confirmationResult);
    
    // Test 4: Appointment Rescheduling Notification
    console.log('\n4. Testing appointment rescheduling notification...');
    const reschedulingResult = await sendAppointmentReschedulingNotification(69, '2026-04-20', '14:30');
    console.log('Rescheduling notification result:', reschedulingResult);
    
    // Test 5: Cancellation Alert
    console.log('\n5. Testing cancellation alert...');
    const cancellationResult = await sendCancellationAlert(69, 'Doctor unavailable');
    console.log('Cancellation alert result:', cancellationResult);
    
    // Test 6: Create Reminder Schedule
    console.log('\n6. Testing reminder schedule creation...');
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const testDate = tomorrow.toISOString().split('T')[0];
    
    const reminderResult = await createAppointmentReminderSchedule(69, testDate, '10:00', testUser.id);
    console.log('Reminder schedule result:', reminderResult);
    
    // Test 7: Direct FCM Notification
    console.log('\n7. Testing direct FCM notification...');
    const directResult = await sendPushNotification(testUser.fcm_token, {
      title: 'Real-Time Test Notification',
      body: 'This is a test of the real-time notification system with banner alerts and sound.',
      notificationType: 'real_time_test',
      data: {
        testId: String('real_time_' + Date.now()),
        priority: String('high'),
        sound: String('default'),
        vibrate: String('true')
      }
    });
    console.log('Direct FCM notification result:', directResult);
    
    // Test 8: Check notification history
    console.log('\n8. Checking notification history...');
    const [history] = await db.execute(
      'SELECT * FROM notification_history WHERE user_id = ? ORDER BY created_at DESC LIMIT 5',
      [testUser.id]
    );
    console.log('Recent notification history:', history);
    
    console.log('\n=== Real-Time Notification Test Complete ===');
    console.log('Summary:');
    console.log('- Appointment approval notifications:', approvalResult.success ? 'WORKING' : 'FAILED');
    console.log('- Appointment confirmation notifications:', confirmationResult.success ? 'WORKING' : 'FAILED');
    console.log('- Appointment rescheduling notifications:', reschedulingResult.success ? 'WORKING' : 'FAILED');
    console.log('- Cancellation alerts:', cancellationResult.success ? 'WORKING' : 'FAILED');
    console.log('- Reminder scheduling:', reminderResult.success ? 'WORKING' : 'FAILED');
    console.log('- Direct FCM notifications:', directResult.success ? 'WORKING' : 'FAILED');
    
  } catch (error) {
    console.error('Real-time notification test error:', error);
  }
  
  process.exit(0);
}

// Run the test
testRealTimeNotifications();
