"use strict";

/**
 * migrateDobVerification.js
 * ─────────────────────────────────────────────────────────────────────────────
 * 1. Adds `dob_needs_verification` TINYINT(1) column to `patients` if missing.
 * 2. Bulk-flags every immunization patient whose stored DOB gives an age > 5
 *    years as needing verification (clearly impossible for a newborn/infant EPI
 *    patient — almost certainly the mother's DOB was saved by the old bug).
 *
 * Safe to run on every server restart — fully idempotent.
 * The ALTER is raced against an 8-second timeout so a locked table never
 * blocks server.listen().
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

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

async function migrateDobVerification() {
  try {
    // ── 1. Add column if it doesn't already exist ─────────────────────────────
    const [cols] = await db.execute(`SHOW COLUMNS FROM patients`);
    const existing = new Set(cols.map((c) => c.Field));

    if (!existing.has("dob_needs_verification")) {
      try {
        await withDdlTimeout(
          db.execute(
            `ALTER TABLE patients
             ADD COLUMN dob_needs_verification TINYINT(1) NOT NULL DEFAULT 0
             AFTER dob`
          ),
          "ALTER TABLE patients ADD COLUMN dob_needs_verification"
        );
        console.log("✅ patients.dob_needs_verification column added");
      } catch (err) {
        if (err.errno === 1060 || err.code === "ER_DUP_FIELDNAME") {
          console.log("ℹ️  patients.dob_needs_verification already exists — skipping");
        } else if (err.message.startsWith("DDL timeout")) {
          console.warn(`⚠️  ${err.message} — will retry on next restart`);
          return; // skip the UPDATE below — column may not exist yet
        } else {
          console.error("❌ migrateDobVerification ADD COLUMN error:", err.message);
          return;
        }
      }
    } else {
      console.log("✅ patients.dob_needs_verification column already exists");
    }

    // ── 2. Flag corrupted immunization records ────────────────────────────────
    // Criteria: immunization patient + dob is non-null + dob results in age > 5 yrs
    const [flagResult] = await db.execute(
      `UPDATE patients
       SET    dob_needs_verification = 1
       WHERE  service_type           = 'immunization'
         AND  dob                    IS NOT NULL
         AND  dob                    < DATE_SUB(CURDATE(), INTERVAL 5 YEAR)
         AND  dob_needs_verification  = 0`
    );

    if (flagResult.affectedRows > 0) {
      console.log(
        `⚠️  Flagged ${flagResult.affectedRows} immunization patient(s) with suspicious DOB (age > 5 years) for admin verification`
      );
    } else {
      console.log("✅ No new suspicious immunization DOB records found");
    }
  } catch (err) {
    // Non-fatal: log and continue — the server still boots
    console.error("❌ migrateDobVerification error:", err.message);
  }
}

module.exports = { migrateDobVerification };
