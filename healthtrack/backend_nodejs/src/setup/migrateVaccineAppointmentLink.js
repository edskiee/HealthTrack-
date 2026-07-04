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
 *
 * Safe to run on every server restart — each ALTER is skipped when the
 * column already exists (catches ER_DUP_FIELDNAME / DUPLICATE COLUMN).
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

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

  for (const col of columns) {
    try {
      await db.execute(col.ddl);
      console.log(`✅ appointments.${col.name} column added`);
    } catch (err) {
      // MySQL error 1060 = ER_DUP_FIELDNAME — column already exists, skip
      if (err.errno === 1060 || err.code === "ER_DUP_FIELDNAME") {
        console.log(`ℹ️  appointments.${col.name} already exists — skipping`);
      } else {
        console.error(`❌ Failed to add appointments.${col.name}:`, err.message);
        throw err; // re-throw unexpected errors so bootstrap logs them
      }
    }
  }
}

module.exports = { migrateVaccineAppointmentLink };
