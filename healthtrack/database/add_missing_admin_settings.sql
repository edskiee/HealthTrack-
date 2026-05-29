-- Add missing admin settings that the frontend expects
-- These settings are used in the admin settings view

INSERT IGNORE INTO system_settings (setting_key, setting_value, setting_type, description) 
VALUES 
  ('appointment_reminders', 'true', 'boolean', 'Enable/disable appointment reminder notifications for admin panel'),
  ('system_alerts', 'true', 'boolean', 'Enable/disable system alert notifications'),
  ('data_sharing', 'false', 'boolean', 'Enable/disable data sharing with third parties'),
  ('analytics_tracking', 'false', 'boolean', 'Enable/disable analytics and usage tracking'),
  ('auto_logout', 'false', 'boolean', 'Enable/disable automatic logout after inactivity');

-- Update any existing settings with better descriptions
UPDATE system_settings 
SET description = 'Enable/disable appointment reminders in admin settings' 
WHERE setting_key = 'appointment_reminders';

UPDATE system_settings 
SET description = 'Enable/disable system alerts and notifications' 
WHERE setting_key = 'system_alerts';

UPDATE system_settings 
SET description = 'Enable/disable sharing of anonymized data with third parties' 
WHERE setting_key = 'data_sharing';

UPDATE system_settings 
SET description = 'Enable/disable collection of usage analytics and tracking' 
WHERE setting_key = 'analytics_tracking';

UPDATE system_settings 
SET description = 'Enable/disable automatic logout after period of inactivity' 
WHERE setting_key = 'auto_logout';