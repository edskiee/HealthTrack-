-- =============================================================================
-- HealthTrack — Railway appointment_slots Schema Fix
-- Run in Railway Dashboard → MySQL → Database → Query
-- =============================================================================
-- The old schema used: slot_date, slot_time, capacity, booked_count
-- The current controller expects:
--   appointment_date, start_time, end_time, slot_duration_minutes,
--   max_patients, booked_patients, is_available, service_id
-- This script migrates the table in-place.
-- IDEMPOTENT — safe to run multiple times.
-- =============================================================================

USE railway;

-- ─── Step 1: Check current structure ─────────────────────────────────────────
DESCRIBE appointment_slots;

-- ─── Step 2: Add new columns if they don't exist ─────────────────────────────

-- appointment_date (replaces slot_date)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='appointment_date');
SET @s = IF(@c=0, 'ALTER TABLE appointment_slots ADD COLUMN appointment_date DATE NOT NULL DEFAULT (CURDATE()) AFTER service_id',
               'SELECT "appointment_date exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- start_time (replaces slot_time)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='start_time');
SET @s = IF(@c=0, 'ALTER TABLE appointment_slots ADD COLUMN start_time TIME NOT NULL DEFAULT "08:00:00" AFTER appointment_date',
               'SELECT "start_time exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- end_time
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='end_time');
SET @s = IF(@c=0, 'ALTER TABLE appointment_slots ADD COLUMN end_time TIME NOT NULL DEFAULT "08:30:00" AFTER start_time',
               'SELECT "end_time exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- slot_duration_minutes
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='slot_duration_minutes');
SET @s = IF(@c=0, 'ALTER TABLE appointment_slots ADD COLUMN slot_duration_minutes INT NOT NULL DEFAULT 30 AFTER end_time',
               'SELECT "slot_duration_minutes exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- max_patients (replaces capacity)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='max_patients');
SET @s = IF(@c=0, 'ALTER TABLE appointment_slots ADD COLUMN max_patients INT NOT NULL DEFAULT 1 AFTER slot_duration_minutes',
               'SELECT "max_patients exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- booked_patients (replaces booked_count)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='booked_patients');
SET @s = IF(@c=0, 'ALTER TABLE appointment_slots ADD COLUMN booked_patients INT NOT NULL DEFAULT 0 AFTER max_patients',
               'SELECT "booked_patients exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- ─── Step 3: Migrate data from old columns into new columns ──────────────────
-- Copy slot_date → appointment_date (if slot_date exists and has data)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='slot_date');
SET @s = IF(@c>0, 'UPDATE appointment_slots SET appointment_date = slot_date WHERE appointment_date = CURDATE() OR appointment_date IS NULL',
               'SELECT "no slot_date to migrate" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- Copy slot_time → start_time (if slot_time exists)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='slot_time');
SET @s = IF(@c>0, 'UPDATE appointment_slots SET start_time = slot_time WHERE start_time = "08:00:00"',
               'SELECT "no slot_time to migrate" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- Copy capacity → max_patients (if capacity exists)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='capacity');
SET @s = IF(@c>0, 'UPDATE appointment_slots SET max_patients = capacity WHERE max_patients = 1',
               'SELECT "no capacity to migrate" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- Copy booked_count → booked_patients (if booked_count exists)
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND COLUMN_NAME='booked_count');
SET @s = IF(@c>0, 'UPDATE appointment_slots SET booked_patients = booked_count WHERE booked_patients = 0',
               'SELECT "no booked_count to migrate" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- ─── Step 4: Add indexes for new columns if missing ──────────────────────────
SET @c = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
          WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='appointment_slots' AND INDEX_NAME='idx_appointment_date');
SET @s = IF(@c=0, 'CREATE INDEX idx_appointment_date ON appointment_slots (appointment_date)',
               'SELECT "idx_appointment_date exists" AS info');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- ─── Step 5: Verify ───────────────────────────────────────────────────────────
DESCRIBE appointment_slots;
SELECT COUNT(*) AS total_slots FROM appointment_slots;
SELECT 'appointment_slots schema fix complete!' AS status;
