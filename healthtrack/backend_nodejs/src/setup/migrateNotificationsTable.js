"use strict";

/**
 * Migration: ensure the notifications table has all required columns.
 * Safe to run multiple times — uses ADD COLUMN IF NOT EXISTS pattern.
 */

const db = require("../config/db");

async function migrateNotificationsTable() {
  try {
    // Create the table with full schema if it doesn't exist at all
    await db.execute(`
      CREATE TABLE IF NOT EXISTS notifications (
        id               INT PRIMARY KEY AUTO_INCREMENT,
        user_id          INT NOT NULL,
        appointment_id   INT NULL,
        notification_type VARCHAR(100) NOT NULL DEFAULT 'system',
        title            VARCHAR(255) NOT NULL DEFAULT 'Notification',
        message          TEXT NOT NULL,
        is_read          TINYINT(1) NOT NULL DEFAULT 0,
        read_at          DATETIME NULL,
        created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_created_at (created_at)
      )
    `);
    console.log("✅ notifications table exists");

    // Get current columns
    const [cols] = await db.execute(`SHOW COLUMNS FROM notifications`);
    const existing = new Set(cols.map(c => c.Field));

    const migrations = [];

    if (!existing.has("appointment_id")) {
      migrations.push(db.execute(
        `ALTER TABLE notifications ADD COLUMN appointment_id INT NULL AFTER user_id`
      ));
    }
    if (!existing.has("title")) {
      migrations.push(db.execute(
        `ALTER TABLE notifications ADD COLUMN title VARCHAR(255) NOT NULL DEFAULT 'Notification' AFTER notification_type`
      ));
    }
    if (!existing.has("read_at")) {
      migrations.push(db.execute(
        `ALTER TABLE notifications ADD COLUMN read_at DATETIME NULL AFTER is_read`
      ));
    }
    if (!existing.has("updated_at")) {
      migrations.push(db.execute(
        `ALTER TABLE notifications ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`
      ));
    }

    // Fix notification_type column length if it's too short (enum or varchar<100)
    const typeCol = cols.find(c => c.Field === "notification_type");
    if (typeCol && !typeCol.Type.includes("100") && !typeCol.Type.includes("text")) {
      migrations.push(db.execute(
        `ALTER TABLE notifications MODIFY COLUMN notification_type VARCHAR(100) NOT NULL DEFAULT 'system'`
      ));
    }

    if (migrations.length === 0) {
      console.log("✅ notifications table schema is up to date");
      return;
    }

    await Promise.all(migrations);
    console.log(`✅ notifications table migrated — added ${migrations.length} missing column(s)`);
  } catch (err) {
    console.error("❌ migrateNotificationsTable error:", err.message);
  }
}

module.exports = { migrateNotificationsTable };
