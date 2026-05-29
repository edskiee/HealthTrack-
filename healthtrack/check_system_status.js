/**
 * Check system status for reminders and notifications
 */

const db = require('./backend_nodejs/src/config/db');

async function checkSystemStatus() {
  try {
    console.log('=== Checking System Status ===');
    
    // Check if appointment_reminders table exists
    const [tables] = await db.execute('SHOW TABLES LIKE "appointment_reminders"');
    console.log('appointment_reminders table exists:', tables.length > 0);
    
    // Check if scheduled_notifications table exists
    const [scheduledTables] = await db.execute('SHOW TABLES LIKE "scheduled_notifications"');
    console.log('scheduled_notifications table exists:', scheduledTables.length > 0);
    
    // Check if notification_history table exists
    const [historyTables] = await db.execute('SHOW TABLES LIKE "notification_history"');
    console.log('notification_history table exists:', historyTables.length > 0);
    
    // Check system settings
    const [settings] = await db.execute('SELECT * FROM system_settings WHERE setting_key LIKE "%reminder%" OR setting_key LIKE "%notification%"');
    console.log('System settings:', settings);
    
    // Check recent reminders
    if (tables.length > 0) {
      const [reminders] = await db.execute('SELECT * FROM appointment_reminders ORDER BY created_at DESC LIMIT 5');
      console.log('Recent reminders:', reminders);
    }
    
    // Check recent scheduled notifications
    if (scheduledTables.length > 0) {
      const [scheduled] = await db.execute('SELECT * FROM scheduled_notifications ORDER BY created_at DESC LIMIT 5');
      console.log('Recent scheduled notifications:', scheduled);
    }
    
    // Check notification history
    if (historyTables.length > 0) {
      const [history] = await db.execute('SELECT * FROM notification_history ORDER BY created_at DESC LIMIT 5');
      console.log('Recent notification history:', history);
    }
    
  } catch (error) {
    console.error('System status check error:', error);
  }
  
  process.exit(0);
}

checkSystemStatus();
