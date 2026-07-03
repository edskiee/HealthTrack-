"use strict";

/**
 * migrateChildSortOrder.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Adds the `child_sort_order` INT column to `patients` if it is missing.
 * Existing rows get child_sort_order = 0 (they are all first/primary children).
 *
 * Safe to run on every server restart — fully idempotent.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db = require("../config/db");

async function migrateChildSortOrder() {
  try {
    const [cols] = await db.execute(`SHOW COLUMNS FROM patients`);
    const existing = new Set(cols.map((c) => c.Field));

    if (!existing.has("child_sort_order")) {
      await db.execute(
        `ALTER TABLE patients
         ADD COLUMN child_sort_order INT NOT NULL DEFAULT 0
         AFTER user_id`
      );
      // All existing rows are first children
      await db.execute(
        `UPDATE patients SET child_sort_order = 0 WHERE child_sort_order IS NULL`
      );
      console.log("✅ patients.child_sort_order column added");
    } else {
      console.log("✅ patients.child_sort_order column already exists");
    }

    // Ensure composite index exists for fast child-list queries
    const [idxRows] = await db.execute(`SHOW INDEX FROM patients WHERE Key_name = 'idx_patients_user_child_order'`);
    if (idxRows.length === 0) {
      await db.execute(
        `CREATE INDEX idx_patients_user_child_order ON patients (user_id, child_sort_order)`
      );
      console.log("✅ Index idx_patients_user_child_order created");
    }
  } catch (err) {
    console.error("❌ migrateChildSortOrder error (non-fatal):", err.message);
  }
}

module.exports = { migrateChildSortOrder };
