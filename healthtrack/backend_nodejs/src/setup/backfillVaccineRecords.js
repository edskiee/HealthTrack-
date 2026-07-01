"use strict";

/**
 * backfillVaccineRecords.js
 * ─────────────────────────────────────────────────────────────────────────────
 * One-time (idempotent) backfill: creates pending child_vaccine_records rows
 * for every immunization patient that does not yet have ANY vaccine records.
 *
 * IMPORTANT: This function is called AFTER server.listen() so it never blocks
 * Render's port-binding timeout. It runs as a background task.
 *
 * Performance improvements over the naive approach:
 *   - One bulk INSERT per patient (14 value tuples in a single query) instead
 *     of 14 separate round-trips per patient.
 *   - Patients are processed in batches of 100 at a time to avoid overwhelming
 *     the DB connection pool.
 *   - INSERT IGNORE makes it fully idempotent — safe to re-run on every restart.
 *
 * For 4462 patients × 14 doses: ~45 bulk INSERT queries (100 patients/batch)
 * instead of 62,468 individual INSERT queries. Runs in ~2–5 seconds instead
 * of timing out Render's 60-second port-scan window.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

const BATCH_SIZE = 100; // patients per batch

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
         )
       ORDER BY p.id`
    );

    if (!unseededPatients.length) {
      console.log("✅ backfillVaccineRecords: all immunization patients already have vaccine records");
      return;
    }

    const total = unseededPatients.length;
    console.log(`⏳ backfillVaccineRecords: seeding ${total} patient(s) × ${scheduleIds.length} doses (batch size: ${BATCH_SIZE})...`);

    let seededCount = 0;

    // ── 3. Process in batches ─────────────────────────────────────────────────
    for (let i = 0; i < unseededPatients.length; i += BATCH_SIZE) {
      const batch = unseededPatients.slice(i, i + BATCH_SIZE);

      // Build one multi-value INSERT per batch:
      //   INSERT IGNORE INTO child_vaccine_records (patient_id, vaccine_schedule_id)
      //   VALUES (p1, s1), (p1, s2), ..., (pN, s14)
      const valueTuples = [];
      const params      = [];

      for (const { id: patientId } of batch) {
        for (const scheduleId of scheduleIds) {
          valueTuples.push("(?, ?)");
          params.push(patientId, scheduleId);
        }
      }

      await db.execute(
        `INSERT IGNORE INTO child_vaccine_records (patient_id, vaccine_schedule_id)
         VALUES ${valueTuples.join(", ")}`,
        params
      );

      seededCount += batch.length;

      // Log progress every 500 patients so the Render log shows life
      if (seededCount % 500 === 0 || seededCount === total) {
        console.log(`  ↳ backfill progress: ${seededCount}/${total} patients seeded`);
      }
    }

    console.log(`✅ backfillVaccineRecords: seeded vaccine records for ${seededCount} patient(s)`);
  } catch (err) {
    // Non-fatal: log and continue — the server keeps running
    console.error("❌ backfillVaccineRecords error:", err.message);
  }
}

module.exports = { backfillVaccineRecords };
