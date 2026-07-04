-- ============================================================
-- Migration: Vaccine Schedule Master Table + Child Vaccine Records
-- Run this against your Aiven PostgreSQL database BEFORE deploying
-- the new backend routes. Safe to run multiple times (idempotent).
-- ============================================================

-- ─── 1. Vaccine Schedules Master Table ───────────────────────
-- One row per vaccine + dose combination, with the standard
-- Philippine EPI schedule offset from the child's date of birth.
-- "due_days_from_birth" is the canonical due-date calculation anchor.
-- "due_days_max" is the outer boundary — exceeding it = Overdue.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vaccine_schedules (
  id               SERIAL PRIMARY KEY,
  vaccine_name     VARCHAR(120)  NOT NULL,  -- e.g. "BCG vaccine"
  vaccine_key      VARCHAR(60)   NOT NULL,  -- e.g. "bcg", "hep_b", "pentavalent"
  dose_number      SMALLINT      NOT NULL DEFAULT 1,
  dose_label       VARCHAR(60)   NOT NULL,  -- e.g. "Dose 1 of 3"
  schedule_label   VARCHAR(120)  NOT NULL,  -- e.g. "At birth"
  due_days_from_birth   INT      NOT NULL,  -- lower bound (days after DOB)
  due_days_max          INT      NOT NULL,  -- upper bound — overdue after this many days
  sort_order       SMALLINT      NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Prevent duplicate schedule rows if migration runs twice
CREATE UNIQUE INDEX IF NOT EXISTS ux_vaccine_schedules_key_dose
  ON vaccine_schedules (vaccine_key, dose_number);

-- ─── 2. Seed: Philippine EPI Standard Schedule ───────────────
-- due_days_from_birth / due_days_max sourced from DOH EPI guidelines.
-- Windows: at birth = day 0–3, "1.5 months" = 42 days, etc.
-- ─────────────────────────────────────────────────────────────
INSERT INTO vaccine_schedules
  (vaccine_name, vaccine_key, dose_number, dose_label, schedule_label,
   due_days_from_birth, due_days_max, sort_order)
VALUES
  -- BCG — single dose at birth
  ('BCG vaccine',                    'bcg',          1, 'Dose 1 of 1', 'At birth',      0,   7,  10),

  -- Hepatitis B — single dose at birth
  ('Hepatitis B vaccine',            'hep_b',        1, 'Dose 1 of 1', 'At birth',      0,   7,  20),

  -- Pentavalent (DPT-Hep B-HIB) — 3 doses
  ('Pentavalent vaccine (DPT-Hep B-HIB)', 'pentavalent', 1, 'Dose 1 of 3', '1½ months',  42, 63,  30),
  ('Pentavalent vaccine (DPT-Hep B-HIB)', 'pentavalent', 2, 'Dose 2 of 3', '2½ months',  70, 91,  31),
  ('Pentavalent vaccine (DPT-Hep B-HIB)', 'pentavalent', 3, 'Dose 3 of 3', '3½ months',  98, 119, 32),

  -- OPV — 3 doses
  ('Oral polio vaccine (OPV)',        'opv',          1, 'Dose 1 of 3', '1½ months',     42,  63,  40),
  ('Oral polio vaccine (OPV)',        'opv',          2, 'Dose 2 of 3', '2½ months',     70,  91,  41),
  ('Oral polio vaccine (OPV)',        'opv',          3, 'Dose 3 of 3', '3½ months',     98, 119,  42),

  -- IPV — 1 dose
  ('Inactivated polio vaccine (IPV)', 'ipv',          1, 'Dose 1 of 1', '3½ months',     98, 365, 50),

  -- PCV — 3 doses
  ('Pneumococcal vaccine (PCV)',      'pcv',          1, 'Dose 1 of 3', '1½ months',     42,  63,  60),
  ('Pneumococcal vaccine (PCV)',      'pcv',          2, 'Dose 2 of 3', '2½ months',     70,  91,  61),
  ('Pneumococcal vaccine (PCV)',      'pcv',          3, 'Dose 3 of 3', '3½ months',     98, 119,  62),

  -- MMR — 2 doses (9 months and 12 months)
  ('Measles, mumps, rubella (MMR)',   'mmr',          1, 'Dose 1 of 2', '9 months',     270, 365,  70),
  ('Measles, mumps, rubella (MMR)',   'mmr',          2, 'Dose 2 of 2', '1 year',       365, 548,  71)
ON CONFLICT (vaccine_key, dose_number) DO NOTHING;

-- ─── 3. Child Vaccine Records Table ──────────────────────────
-- One row per child + schedule entry. Status is NOT stored here —
-- it is always computed fresh in the API from age + given_at.
-- Only "given_at" is the ground truth; everything else is derived.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS child_vaccine_records (
  id                  SERIAL PRIMARY KEY,
  patient_id          INT           NOT NULL,  -- FK → patients.id
  vaccine_schedule_id INT           NOT NULL,  -- FK → vaccine_schedules.id
  given_at            TIMESTAMPTZ,             -- NULL = not yet given
  given_by            VARCHAR(120),            -- admin/doctor name who marked it
  notes               TEXT,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT fk_cvr_patient
    FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
  CONSTRAINT fk_cvr_schedule
    FOREIGN KEY (vaccine_schedule_id) REFERENCES vaccine_schedules (id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_child_vaccine_records_patient_schedule
  ON child_vaccine_records (patient_id, vaccine_schedule_id);

CREATE INDEX IF NOT EXISTS idx_child_vaccine_records_patient
  ON child_vaccine_records (patient_id);

-- ─── 4. Auto-update updated_at on row change ─────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cvr_updated_at ON child_vaccine_records;
CREATE TRIGGER trg_cvr_updated_at
  BEFORE UPDATE ON child_vaccine_records
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
