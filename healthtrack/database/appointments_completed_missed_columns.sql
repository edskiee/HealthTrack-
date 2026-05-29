-- Add completion / missed timestamps for health tracking and admin workflow.
-- Safe to re-run on MariaDB 10.3.3+ and MySQL variants that support IF NOT EXISTS on ADD COLUMN.
-- If your MySQL server rejects this syntax, run:  node backend_nodejs/scripts/migrate_appointments_completed_missed.js

ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS completed_at DATETIME NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS missed_at    DATETIME NULL DEFAULT NULL;

-- Verify:
-- SHOW COLUMNS FROM appointments WHERE Field IN ('completed_at', 'missed_at');
