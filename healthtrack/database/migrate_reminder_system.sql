-- HealthTrack Automated Reminder System Migration Script
-- This script sets up the complete database structure for the enhanced reminder system
-- Run this script to initialize or update your database

USE healthtrack;

-- Create appointment_reminders table if it doesn't exist
CREATE TABLE IF NOT EXISTS appointment_reminders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT NOT NULL,
    user_id INT NOT NULL,
    reminder_date DATE NOT NULL,
    reminder_time TIME NOT NULL,
    scheduled_datetime DATETIME NOT NULL,
    days_before INT NOT NULL,
    reminder_type VARCHAR(50) NOT NULL,
    status ENUM('scheduled', 'sent', 'failed', 'cancelled') DEFAULT 'scheduled',
    sent_at TIMESTAMP NULL,
    error_message TEXT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_appointment_id (appointment_id),
    INDEX idx_user_id (user_id),
    INDEX idx_scheduled_datetime (scheduled_datetime),
    INDEX idx_status (status),
    INDEX idx_reminder_date (reminder_date),
    UNIQUE KEY unique_reminder (appointment_id, reminder_date, reminder_time, reminder_type)
);

-- Create notification_history table if it doesn't exist
CREATE TABLE IF NOT EXISTS notification_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    payload JSON,
    status ENUM('sent', 'failed') NOT NULL,
    error_message TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_notification_type (notification_type),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Add timezone column to users table if it doesn't exist
SET @column_exists = 0;
SELECT COUNT(*) INTO @column_exists 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'healthtrack' 
AND TABLE_NAME = 'users' 
AND COLUMN_NAME = 'timezone';

SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE users ADD COLUMN timezone VARCHAR(50) DEFAULT "UTC" AFTER fcm_token',
    'SELECT "timezone column already exists" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Update system settings for enhanced reminder system
INSERT INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
('appointment_reminders_enabled', 'true', 'boolean', 'Enable/disable appointment reminder notifications'),
('reminder_days_before', '[3]', 'string', 'Days before appointment to send reminders'),
('reminders_per_day', '3', 'number', 'Number of reminders per day'),
('reminder_times', '["06:00", "12:00", "18:00"]', 'string', 'Times of day to send reminders'),
('notification_scheduler_enabled', 'true', 'boolean', 'Enable/disable the notification scheduler'),
('notification_cleanup_days', '30', 'number', 'Days to keep notification history')
ON DUPLICATE KEY UPDATE 
    setting_value = VALUES(setting_value),
    description = VALUES(description);

-- Remove old reminder settings that are no longer needed
DELETE FROM system_settings WHERE setting_key IN ('reminder_interval_hours');

-- Add foreign key constraints if they don't exist
SET @constraint_exists = 0;
SELECT COUNT(*) INTO @constraint_exists 
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'healthtrack' 
AND TABLE_NAME = 'appointment_reminders' 
AND CONSTRAINT_NAME = 'fk_appointment_reminders_appointment_id';

SET @sql = IF(@constraint_exists = 0, 
    'ALTER TABLE appointment_reminders ADD CONSTRAINT fk_appointment_reminders_appointment_id FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE',
    'SELECT "appointment_reminders appointment_id constraint already exists" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @constraint_exists = 0;
SELECT COUNT(*) INTO @constraint_exists 
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'healthtrack' 
AND TABLE_NAME = 'appointment_reminders' 
AND CONSTRAINT_NAME = 'fk_appointment_reminders_user_id';

SET @sql = IF(@constraint_exists = 0, 
    'ALTER TABLE appointment_reminders ADD CONSTRAINT fk_appointment_reminders_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE',
    'SELECT "appointment_reminders user_id constraint already exists" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @constraint_exists = 0;
SELECT COUNT(*) INTO @constraint_exists 
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
WHERE TABLE_SCHEMA = 'healthtrack' 
AND TABLE_NAME = 'notification_history' 
AND CONSTRAINT_NAME = 'fk_notification_history_user_id';

SET @sql = IF(@constraint_exists = 0, 
    'ALTER TABLE notification_history ADD CONSTRAINT fk_notification_history_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE',
    'SELECT "notification_history user_id constraint already exists" as message');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Show migration results
SELECT 'Migration completed successfully!' as status;

-- Show created/updated tables
SHOW TABLES LIKE 'appointment_reminders';
SHOW TABLES LIKE 'notification_history';

-- Show updated system settings
SELECT setting_key, setting_value, setting_type, description 
FROM system_settings 
WHERE setting_key IN (
    'appointment_reminders_enabled', 
    'reminder_days_before', 
    'reminders_per_day', 
    'reminder_times',
    'notification_scheduler_enabled',
    'notification_cleanup_days'
)
ORDER BY setting_key;

-- Show table structures
DESCRIBE appointment_reminders;
DESCRIBE notification_history;
