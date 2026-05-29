const db = require('./src/config/db');

async function applyReminderUpdates() {
  try {
    console.log('Applying reminder table updates...');
    
    // Add category column
    await db.execute(`
      ALTER TABLE reminders 
      ADD COLUMN category VARCHAR(50) DEFAULT 'custom_reminder' AFTER title
    `);
    console.log('✅ Added category column to reminders table');
    
    // Add index for category column
    await db.execute(`
      ALTER TABLE reminders 
      ADD INDEX idx_category (category)
    `);
    console.log('✅ Added index for category column');
    
    // Add more specific repeat intervals for weekdays
    // We'll need to modify the repeat_interval ENUM to include weekday options
    console.log('Reminder table updates applied successfully!');
    
    // Close the pool
    await db.end();
  } catch (error) {
    console.error('Error applying reminder updates:', error.message);
    process.exit(1);
  }
}

applyReminderUpdates();