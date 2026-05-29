const db = require('./backend_nodejs/src/config/db');

async function testReminderFunctionality() {
  try {
    console.log('Testing reminder functionality...');
    
    // Test 1: Check if category column exists
    console.log('\n1. Testing category column...');
    const [categoryResult] = await db.execute(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = 'healthtrack' 
      AND TABLE_NAME = 'reminders' 
      AND COLUMN_NAME = 'category'
    `);
    
    if (categoryResult.length > 0) {
      console.log('✅ Category column exists');
    } else {
      console.log('❌ Category column does not exist');
    }
    
    // Test 2: Check if repeat_days column exists
    console.log('\n2. Testing repeat_days column...');
    const [repeatDaysResult] = await db.execute(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = 'healthtrack' 
      AND TABLE_NAME = 'reminders' 
      AND COLUMN_NAME = 'repeat_days'
    `);
    
    if (repeatDaysResult.length > 0) {
      console.log('✅ Repeat_days column exists');
    } else {
      console.log('❌ Repeat_days column does not exist');
    }
    
    // Test 3: Insert a test reminder with all new fields
    console.log('\n3. Testing reminder insertion with new fields...');
    const [insertResult] = await db.execute(`
      INSERT INTO reminders 
      (user_id, title, category, reminder_date, reminder_time, is_repeating, repeat_interval, repeat_days, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      1, 
      'Test Reminder', 
      'appointment_reminder',
      '2025-10-22', 
      '10:00:00', 
      1, 
      'daily', 
      '["Monday","Wednesday","Friday"]',
      'This is a test reminder'
    ]);
    
    if (insertResult.insertId) {
      console.log('✅ Reminder inserted successfully with ID:', insertResult.insertId);
      
      // Test 4: Retrieve the test reminder
      console.log('\n4. Testing reminder retrieval...');
      const [selectResult] = await db.execute(`
        SELECT * FROM reminders WHERE id = ?
      `, [insertResult.insertId]);
      
      if (selectResult.length > 0) {
        console.log('✅ Reminder retrieved successfully');
        console.log('   Title:', selectResult[0].title);
        console.log('   Category:', selectResult[0].category);
        console.log('   Repeat Days:', selectResult[0].repeat_days);
      } else {
        console.log('❌ Failed to retrieve reminder');
      }
      
      // Test 5: Clean up test reminder
      console.log('\n5. Cleaning up test reminder...');
      await db.execute(`
        DELETE FROM reminders WHERE id = ?
      `, [insertResult.insertId]);
      
      console.log('✅ Test reminder cleaned up');
    } else {
      console.log('❌ Failed to insert reminder');
    }
    
    console.log('\n🎉 All tests completed!');
    
    // Close the pool
    await db.end();
  } catch (error) {
    console.error('❌ Error testing reminder functionality:', error.message);
    process.exit(1);
  }
}

testReminderFunctionality();