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
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

async function migrateDobVerification() {
  try {
    // ── 1. Add column if it doesn't already exist ─────────────────────────────
    const [cols] = await db.execute(`SHOW COLUMNS FROM patients`);
    const existing = new Set(cols.map((c) => c.Field));

    if (!existing.has("dob_needs_verification")) {
      await db.execute(
        `ALTER TABLE patients
         ADD COLUMN dob_needs_verification TINYINT(1) NOT NULL DEFAULT 0
         AFTER dob`
      );
      console.log("✅ patients.dob_needs_verification column added");
    } else {
      console.log("✅ patients.dob_needs_verification column already exists");
    }

    // ── 2. Flag corrupted immunization records ────────────────────────────────
    // Criteria: immunization patient + dob is non-null + dob results in age > 5 yrs
    // We use DATE_SUB(CURDATE(), INTERVAL 5 YEAR) so the comparison is always
    // relative to the current server date — no hard-coded years.
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
