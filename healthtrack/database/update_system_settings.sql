-- Update system settings table with new settings
-- This script adds new settings that are used in the revamped Admin Settings section

-- Insert FCM Server Key setting if it doesn't exist
INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, description) 
VALUES ('fcm_server_key', '', 'string', 'Firebase Cloud Messaging server key for push notifications');

-- Insert Admin Access During Maintenance setting if it doesn't exist
INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, description) 
VALUES ('admin_access_during_maintenance', 'true', 'boolean', 'Allow admin access during maintenance mode');

-- Update existing settings with better descriptions if needed
UPDATE system_settings 
SET description = 'Enable/disable maintenance mode for the system' 
WHERE setting_key = 'maintenance_mode' AND description IS NULL OR description = '';

UPDATE system_settings 
SET description = 'Enable/disable appointment reminder notifications' 
WHERE setting_key = 'appointment_reminders_enabled' AND description IS NULL OR description = '';

UPDATE system_settings 
SET description = 'Enable/disable all system notifications' 
WHERE setting_key = 'notifications_enabled' AND description IS NULL OR description = '';

-- Ensure all default settings have proper values
INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, description) 
VALUES 
  ('app_name', 'HealthTrack System', 'string', 'Application name displayed in the admin panel'),
  ('maintenance_mode', 'false', 'boolean', 'Enable/disable maintenance mode for the system'),
  ('max_appointments_per_day', '50', 'number', 'Maximum number of appointments allowed per day'),
  ('appointment_reminders_enabled', 'true', 'boolean', 'Enable/disable appointment reminder notifications'),
  ('data_retention_days', '365', 'number', 'Number of days to retain patient data'),
  ('default_service_type', 'immunization', 'string', 'Default service type for new patients'),
  ('notifications_enabled', 'true', 'boolean', 'Enable/disable all system notifications');