"use strict";

/**
 * migrateVaccineAppointmentLink.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Adds the four vaccine-linkage columns to the `appointments` table so that
 * bookings made from the Vaccine Card "Book Appointment" button carry the
 * vaccine/dose context through to admin completion.
 *
 * Columns added (all nullable — backward-compatible):
 *   linked_vaccine_schedule_id  INT NULL  — vaccine_schedules.id
 *   linked_dose_number          INT NULL  — dose number (1, 2, 3 …)
 *   linked_vaccine_name         VARCHAR(120) NULL
 *   linked_dose_label           VARCHAR(60)  NULL
 *   vaccine_context             VARCHAR(200) NULL — human-readable e.g. "BCG · Dose 1 of 1"
 *
 * Safe to run on every server restart — each ALTER is skipped when the column
 * already exists. Each DDL is raced against an 8-second timeout so a locked
 * table under high DB load never blocks server.listen().
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

// ── DDL timeout helper ────────────────────────────────────────────────────────
// Races a DDL promise against a timeout. On timeout the DDL is abandoned
// (MySQL will eventually roll it back) and we log a warning and move on.
// The column will simply be added on the next server restart when DB is healthy.
const DDL_TIMEOUT_MS = 8_000;

function withDdlTimeout(promise, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(
        () => reject(new Error(`DDL timeout after ${DDL_TIMEOUT_MS}ms: ${label}`)),
        DDL_TIMEOUT_MS
      )
    ),
  ]);
}

async function migrateVaccineAppointmentLink() {
  const columns = [
    {
      name: "linked_vaccine_schedule_id",
      ddl:  "ALTER TABLE appointments ADD COLUMN linked_vaccine_schedule_id INT NULL DEFAULT NULL",
    },
    {
      name: "linked_dose_number",
      ddl:  "ALTER TABLE appointments ADD COLUMN linked_dose_number INT NULL DEFAULT NULL",
    },
    {
      name: "linked_vaccine_name",
      ddl:  "ALTER TABLE appointments ADD COLUMN linked_vaccine_name VARCHAR(120) NULL DEFAULT NULL",
    },
    {
      name: "linked_dose_label",
      ddl:  "ALTER TABLE appointments ADD COLUMN linked_dose_label VARCHAR(60) NULL DEFAULT NULL",
    },
    {
      // Human-readable combined string e.g. "BCG · Dose 1 of 1"
      // Stored at booking time so admin sees it without joining vaccine_schedules.
      name: "vaccine_context",
      ddl:  "ALTER TABLE appointments ADD COLUMN vaccine_context VARCHAR(200) NULL DEFAULT NULL",
    },
  ];

  // Pre-fetch existing columns once — avoids N+1 SHOW COLUMNS calls
  let existing;
  try {
    const [cols] = await db.execute("SHOW COLUMNS FROM appointments");
    existing = new Set(cols.map((c) => c.Field));
  } catch (err) {
    console.error("❌ migrateVaccineAppointmentLink: could not read appointments schema:", err.message);
    return; // nothing we can do without schema info
  }

  for (const col of columns) {
    if (existing.has(col.name)) {
      console.log(`ℹ️  appointments.${col.name} already exists — skipping`);
      continue;
    }

    try {
      await withDdlTimeout(db.execute(col.ddl), col.ddl);
      console.log(`✅ appointments.${col.name} column added`);
    } catch (err) {
      if (err.errno === 1060 || err.code === "ER_DUP_FIELDNAME") {
        // Race condition: added by another process between SHOW and ALTER
        console.log(`ℹ️  appointments.${col.name} already exists — skipping`);
      } else if (err.message.startsWith("DDL timeout")) {
        // DB is under heavy load — skip and retry on next boot
        console.warn(`⚠️  appointments.${col.name}: ${err.message} — will retry on next restart`);
      } else {
        // Unexpected error — log but don't crash the server
        console.error(`❌ Failed to add appointments.${col.name}:`, err.message);
      }
    }
  }
}

module.exports = { migrateVaccineAppointmentLink };
