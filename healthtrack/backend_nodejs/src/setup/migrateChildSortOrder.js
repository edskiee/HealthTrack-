"use strict";

/**
 * migrateChildSortOrder.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Adds the `child_sort_order` INT column to `patients` if it is missing.
 * Existing rows get child_sort_order = 0 (they are all first/primary children).
 *
 * Safe to run on every server restart — fully idempotent.
 * Each DDL is raced against an 8-second timeout so a locked table under high
 * DB load never blocks server.listen().
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

async function migrateChildSortOrder() {
  try {
    const [cols] = await db.execute(`SHOW COLUMNS FROM patients`);
    const existing = new Set(cols.map((c) => c.Field));

    if (!existing.has("child_sort_order")) {
      try {
        await withDdlTimeout(
          db.execute(
            `ALTER TABLE patients ADD COLUMN child_sort_order INT NOT NULL DEFAULT 0 AFTER user_id`
          ),
          "ALTER TABLE patients ADD COLUMN child_sort_order"
        );
        // Back-fill: existing rows are all first/primary children
        await db.execute(
          `UPDATE patients SET child_sort_order = 0 WHERE child_sort_order IS NULL`
        );
        console.log("✅ patients.child_sort_order column added");
      } catch (err) {
        if (err.errno === 1060 || err.code === "ER_DUP_FIELDNAME") {
          console.log("ℹ️  patients.child_sort_order already exists — skipping");
        } else if (err.message.startsWith("DDL timeout")) {
          console.warn(`⚠️  ${err.message} — will retry on next restart`);
        } else {
          console.error("❌ migrateChildSortOrder ADD COLUMN error:", err.message);
        }
      }
    } else {
      console.log("✅ patients.child_sort_order column already exists");
    }

    // Ensure composite index exists for fast child-list queries
    const [idxRows] = await db.execute(
      `SHOW INDEX FROM patients WHERE Key_name = 'idx_patients_user_child_order'`
    );
    if (idxRows.length === 0) {
      try {
        await withDdlTimeout(
          db.execute(
            `CREATE INDEX idx_patients_user_child_order ON patients (user_id, child_sort_order)`
          ),
          "CREATE INDEX idx_patients_user_child_order"
        );
        console.log("✅ Index idx_patients_user_child_order created");
      } catch (err) {
        if (err.errno === 1061 || err.code === "ER_DUP_KEYNAME") {
          console.log("ℹ️  Index idx_patients_user_child_order already exists — skipping");
        } else if (err.message.startsWith("DDL timeout")) {
          console.warn(`⚠️  ${err.message} — will retry on next restart`);
        } else {
          console.error("❌ migrateChildSortOrder CREATE INDEX error:", err.message);
        }
      }
    }
  } catch (err) {
    console.error("❌ migrateChildSortOrder error (non-fatal):", err.message);
  }
}

module.exports = { migrateChildSortOrder };
