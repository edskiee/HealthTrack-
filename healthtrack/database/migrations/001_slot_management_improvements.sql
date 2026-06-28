-- =============================================================================
-- Migration 001 — Slot Management Improvements
-- Run against: Aiven MySQL (database: railway)
-- Rollback:    See rollback section at the bottom of this file
-- =============================================================================

-- 1. Store slot duration so edit/reschedule logic can reconstruct time ranges
ALTER TABLE appointment_slots
  ADD COLUMN IF NOT EXISTS slot_duration_minutes INT NULL DEFAULT NULL
  AFTER booked_count;

-- 2. Add slot_id FK on appointments so we can reliably find "which appointments
--    belong to a slot" without fuzzy date+time matching
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS slot_id INT NULL DEFAULT NULL
  AFTER patient_id,
  ADD INDEX IF NOT EXISTS idx_slot_id (slot_id);

-- 3. Sync the `notifications` schema to match what the live controllers already
--    insert (appointment_id and read_at were added to the live DB previously but
--    were never reflected in the schema file)
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS appointment_id INT NULL DEFAULT NULL AFTER user_id,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMP NULL DEFAULT NULL AFTER is_read,
  ADD INDEX IF NOT EXISTS idx_appointment_id (appointment_id);

-- =============================================================================
-- ROLLBACK (run in reverse order if you need to undo)
-- =============================================================================
-- ALTER TABLE notifications DROP INDEX idx_appointment_id, DROP COLUMN read_at, DROP COLUMN appointment_id;
-- ALTER TABLE appointments  DROP INDEX idx_slot_id, DROP COLUMN slot_id;
-- ALTER TABLE appointment_slots DROP COLUMN slot_duration_minutes;
