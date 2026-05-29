/**
 * Update notification settings to enable all notification types
 */

const db = require('./backend_nodejs/src/config/db');

async function updateNotificationSettings() {
  try {
    console.log('=== Updating Notification Settings ===');
    
    // Update enabled_notification_types to include all types
    const allNotificationTypes = 'appointment,appointment_confirmation,rescheduling,reminder,cancellation,system';
    
    const [result] = await db.execute(`
      UPDATE system_settings 
      SET setting_value = ?, updated_at = CURRENT_TIMESTAMP
      WHERE setting_key = 'enabled_notification_types'
    `, [allNotificationTypes]);
    
    console.log(`Updated ${result.affectedRows} row(s) for enabled_notification_types`);
    
    // Verify the update
    const [settings] = await db.execute(`
      SELECT setting_key, setting_value FROM system_settings 
      WHERE setting_key = 'enabled_notification_types'
    `);
    
    if (settings.length > 0) {
      console.log('New enabled_notification_types:', settings[0].setting_value);
    }
    
    console.log('=== Notification Settings Updated Successfully ===');
    
  } catch (error) {
    console.error('Error updating notification settings:', error);
  }
  
  process.exit(0);
}

updateNotificationSettings();
