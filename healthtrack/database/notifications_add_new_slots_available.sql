-- Adds 'new_slots_available' to notifications.notification_type ENUM.
-- Run once against the live Aiven DB.  Safe to re-run if the value is already
-- present (MySQL ALTER TABLE MODIFY is idempotent for ENUM extensions when the
-- full target list is specified; it will error only if existing data contains an
-- unlisted value — which cannot happen here because 'new_slots_available' is
-- new).

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
  'appointment_missed',
  'appointment_rescheduled',
  'new_slots_available'
) NOT NULL;
