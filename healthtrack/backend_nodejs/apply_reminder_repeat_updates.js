const db = require('./src/config/db');

async function applyReminderRepeatUpdates() {
  try {
    console.log('Applying reminder repeat days table updates...');
    
    // Add repeat_days column
    await db.execute(`
      ALTER TABLE reminders 
      ADD COLUMN repeat_days VARCHAR(255) NULL AFTER repeat_interval
    `);
    console.log('✅ Added repeat_days column to reminders table');
    
    console.log('Reminder table updates applied successfully!');
    
    // Close the pool
    await db.end();
  } catch (error) {
    console.error('Error applying reminder updates:', error.message);
    process.exit(1);
  }
}

applyReminderRepeatUpdates();