-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 003: vaccine_dose_reminders table
-- Run once against Aiven (deployed DB).
--
-- NOTE: The live notifications.notification_type column is VARCHAR(100), not an
-- ENUM. No ALTER TABLE is needed — VARCHAR accepts any string value including
-- 'vaccine_dose_reminder' and 'vaccine_dose_overdue'.
-- ─────────────────────────────────────────────────────────────────────────────

-- Create the vaccine_dose_reminders table.
-- One row per (patient_id, next_vaccine_schedule_id, days_before) combination.
-- The UNIQUE KEY prevents duplicate reminders if admin marks complete twice.
CREATE TABLE IF NOT EXISTS vaccine_dose_reminders (
  id                      INT PRIMARY KEY AUTO_INCREMENT,
  patient_id              INT NOT NULL,
  user_id                 INT NOT NULL,              -- parent/guardian user to notify
  vaccine_schedule_id     INT NOT NULL,              -- the NEXT (upcoming) dose schedule
  vaccine_name            VARCHAR(255) NOT NULL,
  dose_label              VARCHAR(100) NOT NULL,
  due_date                DATE NOT NULL,             -- next_dose_due_date
  reminder_date           DATE NOT NULL,             -- when to fire (due_date - N days)
  scheduled_datetime      DATETIME NOT NULL,         -- full datetime used by cron query
  days_before             TINYINT NOT NULL,          -- 3 or 1
  status                  ENUM('scheduled','sent','failed','cancelled') NOT NULL DEFAULT 'scheduled',
  sent_at                 TIMESTAMP NULL,
  error_message           TEXT NULL,
  created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_patient_id         (patient_id),
  INDEX idx_user_id            (user_id),
  INDEX idx_scheduled_datetime (scheduled_datetime),
  INDEX idx_status             (status),
  INDEX idx_due_date           (due_date),

  -- Prevent duplicates: one reminder per (patient, next dose, days_before)
  UNIQUE KEY uq_vaccine_reminder (patient_id, vaccine_schedule_id, days_before),

  FOREIGN KEY (patient_id)          REFERENCES patients(id)          ON DELETE CASCADE,
  FOREIGN KEY (user_id)             REFERENCES users(id)             ON DELETE CASCADE,
  FOREIGN KEY (vaccine_schedule_id) REFERENCES vaccine_schedules(id) ON DELETE CASCADE
);
