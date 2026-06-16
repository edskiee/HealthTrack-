/**
 * Create appointment_reminders table if it doesn't exist
 */

const db = require("../config/db");

async function createAppointmentRemindersTable() {
  try {
    const createTableSQL = `
      CREATE TABLE IF NOT EXISTS appointment_reminders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        appointment_id INT NOT NULL,
        user_id INT NOT NULL,
        reminder_date DATE NOT NULL,
        reminder_time TIME NOT NULL,
        scheduled_datetime DATETIME NOT NULL,
        days_before INT NOT NULL COMMENT 'Number of days before appointment',
        reminder_type VARCHAR(50) NOT NULL COMMENT 'Type of reminder (e.g., day_2_reminder_1, day_1_reminder_2)',
        status ENUM('scheduled', 'sent', 'failed', 'cancelled') DEFAULT 'scheduled',
        sent_at DATETIME NULL,
        error_message TEXT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        
        INDEX idx_appointment_id (appointment_id),
        INDEX idx_user_id (user_id),
        INDEX idx_scheduled_datetime (scheduled_datetime),
        INDEX idx_status (status),
        INDEX idx_reminder_date_time (reminder_date, reminder_time),
        
        FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Appointment reminder notifications schedule';
    `;

    await db.execute(createTableSQL);
    console.log("✅ appointment_reminders table created successfully");

    // Check if notification_history table exists, create if not
    const createHistoryTableSQL = `
      CREATE TABLE IF NOT EXISTS notification_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        notification_type VARCHAR(50) NOT NULL,
        payload JSON NULL,
        status ENUM('sent', 'failed', 'pending') NOT NULL,
        error_message TEXT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        
        INDEX idx_user_id (user_id),
        INDEX idx_notification_type (notification_type),
        INDEX idx_status (status),
        INDEX idx_created_at (created_at),
        
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='History of all notifications sent to users';
    `;

    await db.execute(createHistoryTableSQL);
    console.log("✅ notification_history table created successfully");

    // Add system settings for appointment reminders if they don't exist
    const settings = [
      {
        setting_key: 'appointment_reminders_enabled',
        setting_value: 'true',
        setting_type: 'boolean',
        description: 'Enable automated appointment reminders'
      },
      {
        setting_key: 'reminder_days_before',
        setting_value: '[2, 1, 0]',
        setting_type: 'json',
        description: 'Days before appointment to send reminders (0 = same day)'
      },
      {
        setting_key: 'reminders_per_day',
        setting_value: '2',
        setting_type: 'number',
        description: 'Number of reminders to send per day'
      },
      {
        setting_key: 'reminder_times',
        setting_value: '["08:00", "17:00"]',
        setting_type: 'json',
        description: 'Times of day to send reminders'
      }
    ];

    for (const setting of settings) {
      const checkSQL = "SELECT id FROM system_settings WHERE setting_key = ?";
      const [existing] = await db.execute(checkSQL, [setting.setting_key]);
      
      if (existing.length === 0) {
        const insertSQL = `
          INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_active, created_at, updated_at)
          VALUES (?, ?, ?, ?, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        `;
        await db.execute(insertSQL, [setting.setting_key, setting.setting_value, setting.setting_type, setting.description]);
        console.log(`✅ Added system setting: ${setting.setting_key}`);
      }
    }

    console.log("✅ Appointment reminder system setup completed successfully");
    return { success: true, message: "Appointment reminder system setup completed" };

  } catch (error) {
    console.error("❌ Error setting up appointment reminder system:", error);
    return { success: false, message: error.message };
  }
}

module.exports = { createAppointmentRemindersTable };
