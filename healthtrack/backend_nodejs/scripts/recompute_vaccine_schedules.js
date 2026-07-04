#!/usr/bin/env node
/**
 * recompute_vaccine_schedules.js
 * ─────────────────────────────────────────────────────────────────────────────
 * One-time migration script.
 *
 * Purpose:
 *   For every child in the DB, re-run the record-based schedule computation
 *   and update scheduled_date on every child_vaccine_records row to reflect
 *   the actual record-based due date (anchored to real given_at where
 *   available, or to DOB for first doses).
 *
 * Run AFTER migration 002_record_based_schedule.sql has been applied.
 *
 * Usage:
 *   node scripts/recompute_vaccine_schedules.js
 *   node scripts/recompute_vaccine_schedules.js --dry-run   (preview, no writes)
 *   node scripts/recompute_vaccine_schedules.js --patient-id=42  (single patient)
 *
 * Safety:
 *   - Read-only pass first (collects all patients + records).
 *   - Writes scheduled_date only — never touches given_at.
 *   - Flags any result where a computed date is more than 365 days in the
 *     past (potential data anomaly) and logs them for admin review.
 *   - Idempotent: safe to run multiple times.
 * ─────────────────────────────────────────────────────────────────────────────
 */

"use strict";

require("dotenv").config();
const db = require("../src/config/db");

const DRY_RUN    = process.argv.includes("--dry-run");
const targetArg  = process.argv.find(a => a.startsWith("--patient-id="));
const TARGET_PID = targetArg ? parseInt(targetArg.split("=")[1], 10) : null;

// ─── helpers (mirrors vaccines.js) ───────────────────────────────────────────

function addDays(base, days) {
  if (!base) return null;
  try {
    const d = new Date(base);
    if (isNaN(d.getTime())) return null;
    d.setDate(d.getDate() + days);
    return d.toISOString().split("T")[0];
  } catch { return null; }
}

function computeDueDate(sched, dob, prevGivenAt) {
  if (sched.schedule_from === "dob") {
    return addDays(dob, sched.interval_days);
  }
  if (!prevGivenAt) return null;
  return addDays(prevGivenAt, sched.interval_days);
}

// ─── main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log("=== Record-Based Schedule Recomputation ===");
  console.log(DRY_RUN ? "DRY RUN — no writes will be made.\n" : "LIVE RUN — DB will be updated.\n");

  // 1. Load all schedule rows (sorted)
  const [schedules] = await db.execute(
    `SELECT id, vaccine_key, dose_number, dose_label, vaccine_name,
            schedule_from, interval_days, due_days_from_birth
     FROM vaccine_schedules
     ORDER BY sort_order, dose_number`
  );
  console.log(`Loaded ${schedules.length} vaccine schedule rows.`);

  // 2. Load patients (all or single)
  const patientQuery = TARGET_PID
    ? `SELECT id, dob, child_fullname FROM patients WHERE id = ? AND dob IS NOT NULL`
    : `SELECT id, dob, child_fullname FROM patients WHERE dob IS NOT NULL`;
  const patientParams = TARGET_PID ? [TARGET_PID] : [];
  const [patients] = await db.execute(patientQuery, patientParams);
  console.log(`Processing ${patients.length} patient(s).\n`);

  let totalUpdated  = 0;
  let totalSkipped  = 0;
  let totalFlagged  = 0;
  const flaggedRecords = [];

  for (const patient of patients) {
    const dob = patient.dob;

    // 3. Load all existing records for this patient
    const [records] = await db.execute(
      `SELECT id, vaccine_schedule_id, given_at, scheduled_date
       FROM child_vaccine_records
       WHERE patient_id = ?`,
      [patient.id]
    );
    const recMap = {};
    for (const r of records) recMap[r.vaccine_schedule_id] = r;

    // 4. Walk schedule in order, threading lastGivenAt per vaccine_key
    const lastGivenAt = {};
    const updates     = []; // { recordId, newScheduledDate, oldScheduledDate }

    for (const sched of schedules) {
      const rec     = recMap[sched.id] || null;
      const givenAt = rec ? rec.given_at : null;

      const prevGiven = sched.schedule_from === "previous_dose"
        ? (lastGivenAt[sched.vaccine_key] ?? null)
        : null;

      const dueDate = computeDueDate(sched, dob, prevGiven);

      // Advance cursor only when this dose is completed
      if (givenAt) lastGivenAt[sched.vaccine_key] = givenAt;

      if (!rec) continue; // No record row — nothing to update

      // Flag anomalies: computed date is more than 365 days in the past
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      if (dueDate) {
        const dd = new Date(dueDate);
        const daysAgo = Math.floor((today.getTime() - dd.getTime()) / 86_400_000);
        if (daysAgo > 365) {
          flaggedRecords.push({
            patient_id:    patient.id,
            child_name:    patient.child_fullname,
            vaccine:       `${sched.vaccine_name} (${sched.dose_label})`,
            computed_date: dueDate,
            days_past:     daysAgo,
          });
          totalFlagged++;
        }
      }

      // Only write if different from what's already stored
      const oldStored = rec.scheduled_date
        ? new Date(rec.scheduled_date).toISOString().split("T")[0]
        : null;
      const newDate = dueDate ? dueDate.substring(0, 10) : null;

      if (oldStored === newDate) {
        totalSkipped++;
        continue;
      }

      updates.push({
        recordId:         rec.id,
        newScheduledDate: newDate,
        oldScheduledDate: oldStored,
        vaccine:          `${sched.vaccine_name} (${sched.dose_label})`,
      });
    }

    // 5. Apply updates for this patient
    for (const upd of updates) {
      if (!DRY_RUN) {
        await db.execute(
          `UPDATE child_vaccine_records
              SET scheduled_date = ?,
                  updated_at     = CURRENT_TIMESTAMP
            WHERE id = ?`,
          [upd.newScheduledDate, upd.recordId]
        );
      }
      totalUpdated++;
      if (DRY_RUN) {
        console.log(
          `  [DRY] Patient ${patient.id} (${patient.child_fullname}): ` +
          `${upd.vaccine}: ${upd.oldScheduledDate ?? "null"} → ${upd.newScheduledDate ?? "null"}`
        );
      }
    }

    if (!DRY_RUN && updates.length > 0) {
      console.log(
        `  Patient ${patient.id} (${patient.child_fullname ?? "?"}): ` +
        `${updates.length} scheduled_date(s) updated.`
      );
    }
  }

  console.log("\n=== Summary ===");
  console.log(`  Patients processed : ${patients.length}`);
  console.log(`  Records updated    : ${totalUpdated}`);
  console.log(`  Records unchanged  : ${totalSkipped}`);
  console.log(`  Flagged anomalies  : ${totalFlagged}`);

  if (flaggedRecords.length > 0) {
    console.log("\n⚠️  FLAGGED RECORDS (computed date > 1 year in the past — admin review recommended):");
    for (const f of flaggedRecords) {
      console.log(
        `  Patient ${f.patient_id} (${f.child_name}): ${f.vaccine} — ` +
        `computed: ${f.computed_date} (${f.days_past} days ago)`
      );
    }
  }

  console.log(DRY_RUN ? "\nDRY RUN complete. No changes made." : "\nRecomputation complete.");
  process.exit(0);
}

main().catch(err => {
  console.error("Fatal error:", err);
  process.exit(1);
});
