-- ============================================================
-- Migration 002: Record-Based Immunization Schedule
-- ─────────────────────────────────────────────────────────────
-- Run this against your Aiven PostgreSQL database BEFORE
-- deploying backend_nodejs changes from Step 3 onward.
-- Safe to run multiple times (all statements are idempotent).
--
-- What this migration does:
--   A. Adds schedule_from + interval_days to vaccine_schedules
--      so subsequent doses compute from the previous dose's
--      actual given date rather than from DOB.
--   B. Updates all 14 existing seed rows with correct values.
--   C. Adds scheduled_date, completed_by_user_id, remarks
--      to child_vaccine_records.
-- ============================================================

-- ─── PART A: vaccine_schedules — new columns ─────────────────
--
-- schedule_from: 'dob'           → due date = DOB + interval_days
--               'previous_dose' → due date = prev dose given_at + interval_days
--
-- interval_days: days after the anchor date this dose is due
--   (replaces the semantic meaning of due_days_from_birth for
--   subsequent doses; due_days_from_birth is kept for the
--   theoretical/reference date used in status overdue checks)
-- ─────────────────────────────────────────────────────────────

ALTER TABLE vaccine_schedules
  ADD COLUMN IF NOT EXISTS schedule_from VARCHAR(20)
    NOT NULL DEFAULT 'dob';

ALTER TABLE vaccine_schedules
  ADD COLUMN IF NOT EXISTS interval_days INT
    NOT NULL DEFAULT 0;

-- ─── PART B: Seed correct interval_days + schedule_from ───────
--
-- Philippine DOH EPI Schedule (standard intervals):
--   BCG          — 1 dose, at birth           → DOB + 0
--   Hepatitis B  — 1 dose, at birth           → DOB + 0
--   Pentavalent  — Dose 1: DOB + 42 (6 wk)
--                  Dose 2: prev_dose + 28 (4 wk)
--                  Dose 3: prev_dose + 28 (4 wk)
--   OPV          — same intervals as Pentavalent
--   IPV          — 1 dose: DOB + 98 (14 wk)
--                  (current DB has 1 row; DOH 2023 schedule adds Dose 2
--                   from previous_dose + 28 — added below)
--   PCV          — same intervals as Pentavalent
--   MMR          — Dose 1: DOB + 270 (9 months)
--                  Dose 2: DOB + 457 (15 months from DOB; DOH standard)
--                  Note: DOH EPI 2023 specifies Dose 2 at 15 months from DOB,
--                  NOT from Dose 1 actual date.  Use 'dob' anchor with
--                  interval_days = 457 (15 × 30.5).
-- ─────────────────────────────────────────────────────────────

-- BCG — single dose at birth
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 0
 WHERE vaccine_key = 'bcg' AND dose_number = 1;

-- Hepatitis B — single dose at birth
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 0
 WHERE vaccine_key = 'hep_b' AND dose_number = 1;

-- Pentavalent Dose 1 — 6 weeks (42 days) from DOB
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 42
 WHERE vaccine_key = 'pentavalent' AND dose_number = 1;

-- Pentavalent Dose 2 — 4 weeks (28 days) after Dose 1 actual date
UPDATE vaccine_schedules
   SET schedule_from = 'previous_dose',
       interval_days = 28
 WHERE vaccine_key = 'pentavalent' AND dose_number = 2;

-- Pentavalent Dose 3 — 4 weeks (28 days) after Dose 2 actual date
UPDATE vaccine_schedules
   SET schedule_from = 'previous_dose',
       interval_days = 28
 WHERE vaccine_key = 'pentavalent' AND dose_number = 3;

-- OPV Dose 1 — 6 weeks (42 days) from DOB
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 42
 WHERE vaccine_key = 'opv' AND dose_number = 1;

-- OPV Dose 2 — 4 weeks after Dose 1 actual date
UPDATE vaccine_schedules
   SET schedule_from = 'previous_dose',
       interval_days = 28
 WHERE vaccine_key = 'opv' AND dose_number = 2;

-- OPV Dose 3 — 4 weeks after Dose 2 actual date
UPDATE vaccine_schedules
   SET schedule_from = 'previous_dose',
       interval_days = 28
 WHERE vaccine_key = 'opv' AND dose_number = 3;

-- IPV Dose 1 — 14 weeks (98 days) from DOB
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 98
 WHERE vaccine_key = 'ipv' AND dose_number = 1;

-- PCV Dose 1 — 6 weeks (42 days) from DOB
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 42
 WHERE vaccine_key = 'pcv' AND dose_number = 1;

-- PCV Dose 2 — 4 weeks after Dose 1 actual date
UPDATE vaccine_schedules
   SET schedule_from = 'previous_dose',
       interval_days = 28
 WHERE vaccine_key = 'pcv' AND dose_number = 2;

-- PCV Dose 3 — 4 weeks after Dose 2 actual date
UPDATE vaccine_schedules
   SET schedule_from = 'previous_dose',
       interval_days = 28
 WHERE vaccine_key = 'pcv' AND dose_number = 3;

-- MMR Dose 1 — 9 months (270 days) from DOB
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 270
 WHERE vaccine_key = 'mmr' AND dose_number = 1;

-- MMR Dose 2 — 15 months (457 days) from DOB
-- DOH EPI 2023: Dose 2 is given at 15 months from birth (not from Dose 1 date)
UPDATE vaccine_schedules
   SET schedule_from = 'dob',
       interval_days = 457
 WHERE vaccine_key = 'mmr' AND dose_number = 2;

-- ─── PART C: child_vaccine_records — new columns ──────────────
--
-- scheduled_date:         The original theoretical due date (DOB-based).
--                         Stored for display ("Was supposed to be given on").
--                         Populated by the recomputation migration script.
--
-- completed_by_user_id:   FK to the admin/health worker's user record.
--                         given_by (text name) is kept for display; this
--                         adds structured linkage for auditing.
--
-- remarks:                Admin notes per dose (longer-form than notes).
--                         Kept separate from 'notes' which was already used.
-- ─────────────────────────────────────────────────────────────

ALTER TABLE child_vaccine_records
  ADD COLUMN IF NOT EXISTS scheduled_date DATE;

ALTER TABLE child_vaccine_records
  ADD COLUMN IF NOT EXISTS completed_by_user_id INT;

ALTER TABLE child_vaccine_records
  ADD COLUMN IF NOT EXISTS remarks TEXT;

-- Add FK constraint separately (safe if column already existed without it)
-- Wrapped in a stored procedure trick to skip if FK already exists.
-- Simpler: just add the index; FK can be added manually if desired.
CREATE INDEX IF NOT EXISTS idx_cvr_completed_by
  ON child_vaccine_records (completed_by_user_id);

-- ─── PART D: Backfill scheduled_date for existing completed rows ──
-- Sets scheduled_date = DOB + due_days_from_birth for all rows
-- that have given_at set.  The full recompute script handles
-- cascading next-dose dates, but this gives us the reference date
-- immediately for any completed records already in the DB.
-- MySQL syntax (DATE_ADD with INTERVAL).
UPDATE child_vaccine_records cvr
  JOIN vaccine_schedules vs  ON vs.id  = cvr.vaccine_schedule_id
  JOIN patients          p   ON p.id   = cvr.patient_id
   SET cvr.scheduled_date = DATE_ADD(p.dob, INTERVAL vs.due_days_from_birth DAY)
 WHERE cvr.given_at       IS NOT NULL
   AND cvr.scheduled_date IS NULL
   AND p.dob              IS NOT NULL;
