-- Extends notifications.notification_type for Health Tracking status alerts.
-- Safe to run once; re-running may error if ENUM already includes these values.

ALTER TABLE notifications MODIFY COLUMN notification_type ENUM(
  'admin_appointment_notification',
  'appointment_reminder',
  'medication_reminder',
  'follow_up_reminder',
  'custom_message',
  'system',
  'status_update',
  'appointment_in_progress',
  'appointment_completed',
  'appointment_missed'
) NOT NULL;
