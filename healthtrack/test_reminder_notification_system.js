/**
 * Comprehensive test for reminder and notification system
 */

const { createAppointmentReminderSchedule } = require('./backend_nodejs/src/services/appointmentReminderService');
const { checkAndSendDueReminders } = require('./backend_nodejs/src/services/appointmentReminderService');
const { sendDueNotifications } = require('./backend_nodejs/src/services/scheduledNotificationService');
const { sendAutomatedNotification } = require('./backend_nodejs/src/services/automatedReminderService');

async function testReminderSystem() {
  console.log('=== Testing Reminder and Notification System ===');
  
  try {
    // Test 1: Create a test reminder schedule
    console.log('\n1. Testing reminder schedule creation...');
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const testDate = tomorrow.toISOString().split('T')[0];
    const testTime = '10:00';
    
    const result = await createAppointmentReminderSchedule(999, testDate, testTime, 1);
    console.log('Reminder schedule result:', result);
    
    // Test 2: Check for due reminders
    console.log('\n2. Testing due reminder check...');
    const dueResult = await checkAndSendDueReminders();
    console.log('Due reminders result:', dueResult);
    
    // Test 3: Check scheduled notifications
    console.log('\n3. Testing scheduled notifications...');
    const scheduledResult = await sendDueNotifications();
    console.log('Scheduled notifications result:', scheduledResult);
    
    // Test 4: Test automated notification
    console.log('\n4. Testing automated notification...');
    const notificationResult = await sendAutomatedNotification(
      1, 
      'test_reminder', 
      'Test Reminder', 
      'This is a test reminder notification',
      { testId: '123' }
    );
    console.log('Automated notification result:', notificationResult);
    
  } catch (error) {
    console.error('Test error:', error);
  }
}

// Run the test
testReminderSystem();
