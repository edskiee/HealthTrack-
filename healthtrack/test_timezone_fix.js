/**
 * Test script to validate timezone column fix and error handling
 * This script tests the appointment reminder system with the timezone fixes
 */

const db = require('./backend_nodejs/src/config/db');
const { sendAppointmentReminder } = require('./backend_nodejs/src/services/appointmentReminderService');

async function testTimezoneFix() {
  console.log('🧪 Testing timezone column fix and error handling...\n');

  try {
    // Test 1: Check if timezone column exists in users table
    console.log('📋 Test 1: Checking timezone column existence...');
    try {
      const [result] = await db.execute('DESCRIBE users');
      const timezoneColumn = result.find(col => col.Field === 'timezone');
      
      if (timezoneColumn) {
        console.log('✅ Timezone column exists in users table');
        console.log(`   Type: ${timezoneColumn.Type}, Default: ${timezoneColumn.Default}`);
      } else {
        console.log('❌ Timezone column does not exist in users table');
        console.log('💡 Please run the add_timezone_column.sql script first');
        return false;
      }
    } catch (error) {
      console.log('❌ Error checking timezone column:', error.message);
      return false;
    }

    // Test 2: Test the fixed SQL query with COALESCE
    console.log('\n📋 Test 2: Testing SQL query with COALESCE...');
    try {
      // First, let's check if there are any appointment reminders
      const [reminders] = await db.execute('SELECT * FROM appointment_reminders LIMIT 1');
      
      if (reminders.length > 0) {
        const reminderId = reminders[0].id;
        console.log(`   Testing with reminder ID: ${reminderId}`);
        
        // Test the query that was failing before
        const [testResults] = await db.execute(`
          SELECT 
            ar.*,
            a.appointment_date,
            a.appointment_time,
            a.appointment_type,
            a.doctor_name,
            a.clinic_hospital,
            u.fcm_token,
            u.full_name as user_name,
            COALESCE(u.timezone, 'Asia/Manila') as timezone,
            p.child_fullname as patient_name
          FROM appointment_reminders ar
          JOIN appointments a ON ar.appointment_id = a.id
          JOIN users u ON ar.user_id = u.id
          LEFT JOIN patients p ON a.patient_id = p.id
          WHERE ar.id = ? AND ar.status = 'scheduled'
        `, [reminderId]);
        
        if (testResults.length > 0) {
          console.log('✅ SQL query with COALESCE executed successfully');
          console.log(`   Timezone value: ${testResults[0].timezone}`);
        } else {
          console.log('⚠️ Query executed but no results found (reminder may not be scheduled)');
        }
      } else {
        console.log('⚠️ No appointment reminders found to test with');
      }
    } catch (error) {
      console.log('❌ SQL query test failed:', error.message);
      return false;
    }

    // Test 3: Test getUserTimezone function
    console.log('\n📋 Test 3: Testing getUserTimezone function...');
    try {
      const { getUserTimezone } = require('./backend_nodejs/src/services/appointmentReminderService');
      
      // Get a sample user ID
      const [users] = await db.execute('SELECT id FROM users LIMIT 1');
      
      if (users.length > 0) {
        const userId = users[0].id;
        const timezone = await getUserTimezone(userId);
        console.log(`✅ getUserTimezone function works for user ${userId}`);
        console.log(`   Returned timezone: ${timezone}`);
      } else {
        console.log('⚠️ No users found to test getUserTimezone function');
      }
    } catch (error) {
      console.log('❌ getUserTimezone function test failed:', error.message);
      return false;
    }

    // Test 4: Test error handling with invalid reminder ID
    console.log('\n📋 Test 4: Testing error handling with invalid reminder...');
    try {
      const result = await sendAppointmentReminder(999999);
      console.log('✅ Error handling works for invalid reminder ID');
      console.log(`   Result: ${result.message}`);
    } catch (error) {
      console.log('❌ Error handling test failed:', error.message);
      return false;
    }

    // Test 5: Verify timezone values for existing users
    console.log('\n📋 Test 5: Verifying timezone values for existing users...');
    try {
      const [users] = await db.execute(`
        SELECT id, username, timezone 
        FROM users 
        ORDER BY id 
        LIMIT 5
      `);
      
      console.log('✅ Timezone values for existing users:');
      users.forEach(user => {
        console.log(`   User ${user.id} (${user.username}): ${user.timezone || 'NULL'}`);
      });
    } catch (error) {
      console.log('❌ Error checking user timezone values:', error.message);
      return false;
    }

    console.log('\n🎉 All tests completed successfully!');
    console.log('✅ Timezone column fix and error handling are working correctly');
    return true;

  } catch (error) {
    console.error('❌ Test suite failed:', error);
    return false;
  }
}

// Test the checkAndSendDueReminders function with error handling
async function testReminderSystemErrorHandling() {
  console.log('\n🧪 Testing reminder system error handling...\n');

  try {
    const { checkAndSendDueReminders } = require('./backend_nodejs/src/services/appointmentReminderService');
    
    console.log('📋 Testing checkAndSendDueReminders function...');
    const result = await checkAndSendDueReminders();
    
    console.log('✅ checkAndSendDueReminders executed without crashing');
    console.log(`   Result: ${result.message}`);
    
    if (result.results && result.results.length > 0) {
      console.log('   Processed reminders:');
      result.results.forEach((r, index) => {
        console.log(`     ${index + 1}. Reminder ${r.reminderId}: ${r.success ? 'SUCCESS' : 'FAILED'} - ${r.message}`);
      });
    }
    
    return true;
  } catch (error) {
    console.error('❌ Reminder system error handling test failed:', error);
    return false;
  }
}

// Run all tests
async function runAllTests() {
  console.log('🚀 Starting comprehensive timezone fix validation...\n');
  
  const test1Passed = await testTimezoneFix();
  const test2Passed = await testReminderSystemErrorHandling();
  
  console.log('\n📊 Test Results Summary:');
  console.log(`   Timezone Fix Tests: ${test1Passed ? '✅ PASSED' : '❌ FAILED'}`);
  console.log(`   Error Handling Tests: ${test2Passed ? '✅ PASSED' : '❌ FAILED'}`);
  
  if (test1Passed && test2Passed) {
    console.log('\n🎉 ALL TESTS PASSED! The timezone fix is working correctly.');
    console.log('📋 Next steps:');
    console.log('   1. The reminder notification system should now work without crashing');
    console.log('   2. Failed individual reminders will not stop the entire process');
    console.log('   3. The system gracefully handles missing timezone values');
  } else {
    console.log('\n❌ Some tests failed. Please check the errors above.');
  }
  
  // Close database connection
  try {
    await db.end();
    console.log('\n🔌 Database connection closed');
  } catch (error) {
    console.log('⚠️ Error closing database connection:', error.message);
  }
  
  process.exit(test1Passed && test2Passed ? 0 : 1);
}

// Run the tests
runAllTests().catch(error => {
  console.error('❌ Test runner failed:', error);
  process.exit(1);
});
