"use strict";

/**
 * vaccineTableSetup.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Creates the vaccine_schedules and child_vaccine_records tables if they do not
 * already exist, then seeds the vaccine_schedules master data.
 *
 * Called once at server startup from server.js (like other setup functions).
 * Safe to run on every restart — all statements are idempotent.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

async function createVaccineTables() {
  // ── vaccine_schedules — master EPI schedule ───────────────────────────────
  await db.execute(`
    CREATE TABLE IF NOT EXISTS vaccine_schedules (
      id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      vaccine_name          VARCHAR(120)  NOT NULL,
      vaccine_key           VARCHAR(60)   NOT NULL,
      dose_number           TINYINT       NOT NULL DEFAULT 1,
      dose_label            VARCHAR(60)   NOT NULL,
      schedule_label        VARCHAR(120)  NOT NULL,
      due_days_from_birth   INT           NOT NULL,
      due_days_max          INT           NOT NULL,
      sort_order            SMALLINT      NOT NULL DEFAULT 0,
      created_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY ux_vaccine_key_dose (vaccine_key, dose_number)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);

  // ── child_vaccine_records — per-child completions ─────────────────────────
  await db.execute(`
    CREATE TABLE IF NOT EXISTS child_vaccine_records (
      id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      patient_id            INT UNSIGNED  NOT NULL,
      vaccine_schedule_id   INT UNSIGNED  NOT NULL,
      given_at              DATETIME,
      given_by              VARCHAR(120),
      notes                 TEXT,
      created_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY ux_cvr_patient_schedule (patient_id, vaccine_schedule_id),
      KEY idx_cvr_patient (patient_id),
      CONSTRAINT fk_cvr_schedule
        FOREIGN KEY (vaccine_schedule_id) REFERENCES vaccine_schedules (id)
        ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);

  console.log("✅ Vaccine tables ready");
}

async function seedVaccineSchedules() {
  // Philippine EPI standard schedule — 14 dose rows
  // Only inserts rows that are not already present (INSERT IGNORE)
  const doses = [
    // vaccine_name,                                vaccine_key,    dose_number, dose_label,    schedule_label,   due_days_from_birth, due_days_max, sort_order
    ["BCG vaccine",                                  "bcg",          1, "Dose 1 of 1", "At birth",         0,   7,  10],
    ["Hepatitis B vaccine",                          "hep_b",        1, "Dose 1 of 1", "At birth",         0,   7,  20],
    ["Pentavalent vaccine (DPT-Hep B-HIB)",         "pentavalent",  1, "Dose 1 of 3", "1½ months",       42,  63,  30],
    ["Pentavalent vaccine (DPT-Hep B-HIB)",         "pentavalent",  2, "Dose 2 of 3", "2½ months",       70,  91,  31],
    ["Pentavalent vaccine (DPT-Hep B-HIB)",         "pentavalent",  3, "Dose 3 of 3", "3½ months",       98, 119,  32],
    ["Oral polio vaccine (OPV)",                     "opv",          1, "Dose 1 of 3", "1½ months",       42,  63,  40],
    ["Oral polio vaccine (OPV)",                     "opv",          2, "Dose 2 of 3", "2½ months",       70,  91,  41],
    ["Oral polio vaccine (OPV)",                     "opv",          3, "Dose 3 of 3", "3½ months",       98, 119,  42],
    ["Inactivated polio vaccine (IPV)",              "ipv",          1, "Dose 1 of 1", "3½ months",       98, 365,  50],
    ["Pneumococcal vaccine (PCV)",                   "pcv",          1, "Dose 1 of 3", "1½ months",       42,  63,  60],
    ["Pneumococcal vaccine (PCV)",                   "pcv",          2, "Dose 2 of 3", "2½ months",       70,  91,  61],
    ["Pneumococcal vaccine (PCV)",                   "pcv",          3, "Dose 3 of 3", "3½ months",       98, 119,  62],
    ["Measles, mumps, rubella (MMR)",                "mmr",          1, "Dose 1 of 2", "9 months",       270, 365,  70],
    ["Measles, mumps, rubella (MMR)",                "mmr",          2, "Dose 2 of 2", "1 year",         365, 548,  71],
  ];

  for (const [vaccineName, vaccineKey, doseNumber, doseLabel, scheduleLabel,
              dueDays, dueMax, sortOrder] of doses) {
    await db.execute(
      `INSERT IGNORE INTO vaccine_schedules
         (vaccine_name, vaccine_key, dose_number, dose_label, schedule_label,
          due_days_from_birth, due_days_max, sort_order)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [vaccineName, vaccineKey, doseNumber, doseLabel, scheduleLabel,
       dueDays, dueMax, sortOrder]
    );
  }

  console.log("✅ Vaccine schedule seed complete");
}

/**
 * Main entry point — call this from server.js startup.
 */
async function setupVaccineTables() {
  try {
    await createVaccineTables();
    await seedVaccineSchedules();
  } catch (err) {
    console.error("❌ setupVaccineTables error:", err.message);
    // Non-fatal: the server continues, but vaccine endpoints may fail gracefully
  }
}

module.exports = { setupVaccineTables };
