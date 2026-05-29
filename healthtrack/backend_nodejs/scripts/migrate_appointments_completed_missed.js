/**
 * Idempotent migration: appointments.completed_at, appointments.missed_at
 * Uses the same mysql2 pool as the app (src/config/db.js).
 *
 * Usage (from backend_nodejs):  node scripts/migrate_appointments_completed_missed.js
 */
const db = require("../src/config/db");

async function columnExists(columnName) {
  const [rows] = await db.execute(
    `SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'appointments'
       AND COLUMN_NAME = ?`,
    [columnName]
  );
  return Number(rows[0].c) > 0;
}

async function run() {
  try {
    if (!(await columnExists("completed_at"))) {
      await db.execute(
        "ALTER TABLE appointments ADD COLUMN completed_at DATETIME NULL DEFAULT NULL"
      );
      console.log("Added column completed_at");
    } else {
      console.log("Column completed_at already exists — skipped");
    }

    if (!(await columnExists("missed_at"))) {
      await db.execute(
        "ALTER TABLE appointments ADD COLUMN missed_at DATETIME NULL DEFAULT NULL"
      );
      console.log("Added column missed_at");
    } else {
      console.log("Column missed_at already exists — skipped");
    }

    const [cols] = await db.execute(
      `SHOW COLUMNS FROM appointments WHERE Field IN ('completed_at', 'missed_at')`
    );
    console.log("Verify:", cols);
    process.exit(0);
  } catch (err) {
    console.error("Migration failed:", err.message);
    process.exit(1);
  }
}

run();
