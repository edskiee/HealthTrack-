-- Update reminder settings to match new requirements (3 days before, 3 times per day)
-- This script updates the system settings for the enhanced reminder system

UPDATE system_settings SET setting_value = 'true' WHERE setting_key = 'appointment_reminders_enabled';

-- Add new reminder-specific settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
('reminder_days_before', '[3]', 'string', 'Days before appointment to send reminders'),
('reminders_per_day', '3', 'number', 'Number of reminders per day'),
('reminder_times', '["06:00", "12:00", "18:00"]', 'string', 'Times of day to send reminders')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- Remove old reminder interval setting as it's replaced by the new system
DELETE FROM system_settings WHERE setting_key = 'reminder_interval_hours';

-- Show updated settings
SELECT * FROM system_settings WHERE setting_key IN ('appointment_reminders_enabled', 'reminder_days_before', 'reminders_per_day', 'reminder_times');
