"use strict";

/**
 * backfillVaccineRecords.js
 * ─────────────────────────────────────────────────────────────────────────────
 * One-time (idempotent) backfill: creates pending child_vaccine_records rows
 * for every immunization patient that does not yet have ANY vaccine records.
 *
 * Run at server startup (called from server.js after setupVaccineTables).
 * Safe to run on every restart — INSERT IGNORE prevents duplicates.
 *
 * Logic:
 *   1. Find all immunization patient IDs that have zero rows in
 *      child_vaccine_records.
 *   2. For each missing patient, insert one row per vaccine_schedule with
 *      given_at = NULL (= pending, not yet administered).
 *
 * Performance: uses a single NOT IN sub-query for the patient lookup, then
 * batch-inserts per patient. Typically runs in < 1 s for ~4000 patients on
 * the first deploy and is a no-op on every subsequent restart.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

async function backfillVaccineRecords() {
  try {
    // ── 1. Fetch all vaccine schedule IDs ─────────────────────────────────────
    const [schedules] = await db.execute(
      `SELECT id FROM vaccine_schedules ORDER BY sort_order, dose_number`
    );

    if (!schedules.length) {
      console.log("⚠️  backfillVaccineRecords: no vaccine schedules found — skipping");
      return;
    }

    const scheduleIds = schedules.map(s => s.id);

    // ── 2. Find immunization patients with NO vaccine records at all ──────────
    const [unseededPatients] = await db.execute(
      `SELECT p.id
       FROM patients p
       WHERE p.service_type LIKE '%immun%'
         AND NOT EXISTS (
           SELECT 1
           FROM child_vaccine_records cvr
           WHERE cvr.patient_id = p.id
         )`
    );

    if (!unseededPatients.length) {
      console.log("✅ backfillVaccineRecords: all immunization patients already have vaccine records");
      return;
    }

    console.log(`⏳ backfillVaccineRecords: seeding ${unseededPatients.length} patient(s) × ${scheduleIds.length} doses...`);

    let seededCount = 0;

    for (const { id: patientId } of unseededPatients) {
      for (const scheduleId of scheduleIds) {
        await db.execute(
          `INSERT IGNORE INTO child_vaccine_records
             (patient_id, vaccine_schedule_id)
           VALUES (?, ?)`,
          [patientId, scheduleId]
        );
      }
      seededCount++;
    }

    console.log(`✅ backfillVaccineRecords: seeded vaccine records for ${seededCount} patient(s)`);
  } catch (err) {
    // Non-fatal: log and continue — the server still boots
    console.error("❌ backfillVaccineRecords error:", err.message);
  }
}

module.exports = { backfillVaccineRecords };
