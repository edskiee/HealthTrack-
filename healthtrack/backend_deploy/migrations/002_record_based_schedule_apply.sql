-- ============================================================
-- Migration 002 (apply version — plain MySQL 8, no IF NOT EXISTS)
-- Run once against Aiven MySQL after verifying columns don't exist.
-- ============================================================

-- PART A: Add new columns to vaccine_schedules
ALTER TABLE vaccine_schedules
  ADD COLUMN schedule_from VARCHAR(20) NOT NULL DEFAULT 'dob';

ALTER TABLE vaccine_schedules
  ADD COLUMN interval_days INT NOT NULL DEFAULT 0;

-- PART B: Seed schedule_from + interval_days per DOH EPI schedule

-- BCG
UPDATE vaccine_schedules SET schedule_from='dob', interval_days=0 WHERE vaccine_key='bcg' AND dose_number=1;

-- Hepatitis B
UPDATE vaccine_schedules SET schedule_from='dob', interval_days=0 WHERE vaccine_key='hep_b' AND dose_number=1;

-- Pentavalent
UPDATE vaccine_schedules SET schedule_from='dob',           interval_days=42 WHERE vaccine_key='pentavalent' AND dose_number=1;
UPDATE vaccine_schedules SET schedule_from='previous_dose', interval_days=28 WHERE vaccine_key='pentavalent' AND dose_number=2;
UPDATE vaccine_schedules SET schedule_from='previous_dose', interval_days=28 WHERE vaccine_key='pentavalent' AND dose_number=3;

-- OPV
UPDATE vaccine_schedules SET schedule_from='dob',           interval_days=42 WHERE vaccine_key='opv' AND dose_number=1;
UPDATE vaccine_schedules SET schedule_from='previous_dose', interval_days=28 WHERE vaccine_key='opv' AND dose_number=2;
UPDATE vaccine_schedules SET schedule_from='previous_dose', interval_days=28 WHERE vaccine_key='opv' AND dose_number=3;

-- IPV
UPDATE vaccine_schedules SET schedule_from='dob', interval_days=98 WHERE vaccine_key='ipv' AND dose_number=1;

-- PCV
UPDATE vaccine_schedules SET schedule_from='dob',           interval_days=42 WHERE vaccine_key='pcv' AND dose_number=1;
UPDATE vaccine_schedules SET schedule_from='previous_dose', interval_days=28 WHERE vaccine_key='pcv' AND dose_number=2;
UPDATE vaccine_schedules SET schedule_from='previous_dose', interval_days=28 WHERE vaccine_key='pcv' AND dose_number=3;

-- MMR
UPDATE vaccine_schedules SET schedule_from='dob', interval_days=270 WHERE vaccine_key='mmr' AND dose_number=1;
UPDATE vaccine_schedules SET schedule_from='dob', interval_days=457 WHERE vaccine_key='mmr' AND dose_number=2;

-- PART C: Add new columns to child_vaccine_records
ALTER TABLE child_vaccine_records
  ADD COLUMN scheduled_date DATE;

ALTER TABLE child_vaccine_records
  ADD COLUMN completed_by_user_id INT;

ALTER TABLE child_vaccine_records
  ADD COLUMN remarks TEXT;

CREATE INDEX idx_cvr_completed_by
  ON child_vaccine_records (completed_by_user_id);

-- PART D: Backfill scheduled_date for existing completed records
UPDATE child_vaccine_records cvr
  JOIN vaccine_schedules vs ON vs.id = cvr.vaccine_schedule_id
  JOIN patients p ON p.id = cvr.patient_id
   SET cvr.scheduled_date = DATE_ADD(p.dob, INTERVAL vs.due_days_from_birth DAY)
 WHERE cvr.given_at IS NOT NULL
   AND cvr.scheduled_date IS NULL
   AND p.dob IS NOT NULL;
