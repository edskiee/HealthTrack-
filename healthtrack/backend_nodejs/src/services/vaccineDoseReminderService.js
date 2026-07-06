"use strict";

/**
 * vaccineDoseReminderService.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Handles vaccine-dose reminders end-to-end:
 *
 *   createVaccineDoseReminders(ctx)
 *     Called from POST /vaccines/record right after nextDueDateComputed is set.
 *     Inserts 0-2 rows into vaccine_dose_reminders (3-day and 1-day before).
 *     Also handles the edge case where the next due date is already overdue
 *     by writing an immediate notification directly to the notifications table.
 *
 *   checkAndSendDueVaccineReminders()
 *     Called by the cron every minute (alongside checkAndSendDueReminders).
 *     Finds scheduled rows whose scheduled_datetime <= NOW(), writes a
 *     notifications row, fires FCM push, marks status → sent / failed.
 *
 * Notification types used (both added to the notifications ENUM via migration 003):
 *   vaccine_dose_reminder  — in-app + push for 3-day / 1-day reminders
 *   vaccine_dose_overdue   — immediate notification when next dose is already past due
 * ─────────────────────────────────────────────────────────────────────────────
 */

const db                 = require("../config/db");
const { sendToUserDevices } = require("./appointmentPushService");

// ─── helpers ──────────────────────────────────────────────────────────────────

/** Format a JS Date or ISO string as "Month D, YYYY" (e.g. "July 8, 2026"). */
function formatDisplayDate(dateStr) {
  if (!dateStr) return "Unknown date";
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return String(dateStr);
    return d.toLocaleDateString("en-US", {
      year:  "numeric",
      month: "long",
      day:   "numeric",
      timeZone: "Asia/Manila",
    });
  } catch { return String(dateStr); }
}

/**
 * Add whole days to a "YYYY-MM-DD" string; return "YYYY-MM-DD" or null.
 * Negative days subtract (used to compute reminder date = due_date - N).
 */
function addDays(dateStr, days) {
  if (!dateStr) return null;
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return null;
    d.setDate(d.getDate() + days);
    return d.toISOString().split("T")[0];
  } catch { return null; }
}

/** Return "YYYY-MM-DD HH:mm:ss" at 08:00 Manila time for the given date string. */
function reminderDatetime(dateStr) {
  if (!dateStr) return null;
  // Firing at 08:00 Asia/Manila = 00:00 UTC (UTC+8). We store in UTC to match NOW().
  // But since the DB server is likely already in UTC, use the local date at 00:00 UTC.
  // Using 08:00 local Manila means roughly midnight UTC — safe for "morning of that day".
  return `${dateStr} 00:00:00`;
}

/**
 * Build the 3-day and 1-day reminder records for a given context.
 *
 * @param {object} ctx
 *   patient_id         — INT
 *   user_id            — INT (parent's user ID from patients.user_id)
 *   vaccine_schedule_id — INT (next dose's schedule ID)
 *   vaccine_name       — string
 *   dose_label         — string
 *   due_date           — "YYYY-MM-DD" (nextDueDateComputed)
 *   child_name         — string (for log messages)
 * @returns {Promise<{created:number, skipped:number, overdue:boolean}>}
 */
async function createVaccineDoseReminders(ctx) {
  const {
    patient_id,
    user_id,
    vaccine_schedule_id,
    vaccine_name,
    dose_label,
    due_date,
    child_name,
  } = ctx;

  const result = { created: 0, skipped: 0, overdue: false };

  if (!due_date || !user_id) {
    console.log(`⚠️ [VaccineReminder] Skipped — missing due_date or user_id for patient ${patient_id}`);
    return result;
  }

  const today    = new Date();
  today.setHours(0, 0, 0, 0);
  const dueDate  = new Date(due_date);
  dueDate.setHours(0, 0, 0, 0);

  // ── Edge case: next due date is already in the past → overdue notification ──
  if (dueDate < today) {
    console.log(`⚠️ [VaccineReminder] Next dose due ${due_date} is already past — sending overdue notification`);
    result.overdue = true;
    await sendOverdueNotification({ patient_id, user_id, vaccine_name, dose_label, due_date, child_name });
    return result;
  }

  // ── Ensure the auto-create table exists ───────────────────────────────────
  await ensureVaccineDoseRemindersTable();

  // ── Build the two candidate rows ──────────────────────────────────────────
  const candidates = [
    { days_before: 3, reminder_date: addDays(due_date, -3) },
    { days_before: 1, reminder_date: addDays(due_date, -1) },
  ];

  for (const c of candidates) {
    if (!c.reminder_date) continue;

    const reminderDay = new Date(c.reminder_date);
    reminderDay.setHours(0, 0, 0, 0);

    // Skip if reminder date is in the past (e.g. due in 2 days → no 3-day reminder)
    if (reminderDay < today) {
      console.log(`⚠️ [VaccineReminder] ${c.days_before}-day reminder for ${due_date} is in the past — skipping`);
      result.skipped++;
      continue;
    }

    const scheduledDt = reminderDatetime(c.reminder_date);

    try {
      await db.execute(
        `INSERT INTO vaccine_dose_reminders
           (patient_id, user_id, vaccine_schedule_id, vaccine_name, dose_label,
            due_date, reminder_date, scheduled_datetime, days_before, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'scheduled')
         ON DUPLICATE KEY UPDATE
           status            = IF(status = 'sent', 'sent', 'scheduled'),
           due_date          = VALUES(due_date),
           scheduled_datetime= VALUES(scheduled_datetime),
           updated_at        = CURRENT_TIMESTAMP`,
        [
          patient_id,
          user_id,
          vaccine_schedule_id,
          vaccine_name,
          dose_label,
          due_date,
          c.reminder_date,
          scheduledDt,
          c.days_before,
        ]
      );
      result.created++;
      console.log(
        `✅ [VaccineReminder] Created ${c.days_before}-day reminder for ` +
        `${vaccine_name} (${dose_label}) due ${due_date} → fires ${c.reminder_date}`
      );
    } catch (err) {
      if (err.code === "ER_DUP_ENTRY") {
        // UNIQUE KEY fired — reminder already exists (idempotent)
        result.skipped++;
        console.log(`⚠️ [VaccineReminder] Duplicate ${c.days_before}-day reminder for patient ${patient_id} — skipped`);
      } else {
        console.error(`❌ [VaccineReminder] Failed to insert ${c.days_before}-day reminder:`, err);
      }
    }
  }

  return result;
}

/**
 * Send an immediate "overdue" notification to the notifications table.
 * Used when admin marks a dose complete but the next due date has already passed.
 */
async function sendOverdueNotification({ patient_id, user_id, vaccine_name, dose_label, due_date, child_name }) {
  const displayDate = formatDisplayDate(due_date);
  const name        = child_name || `Patient #${patient_id}`;
  const title       = "Overdue Vaccine";
  const message     =
    `${name}'s ${vaccine_name} (${dose_label}) was due on ${displayDate}. ` +
    `Please visit the clinic as soon as possible.`;

  try {
    const [ins] = await db.execute(
      `INSERT INTO notifications (user_id, notification_type, title, message, is_read)
       VALUES (?, 'vaccine_dose_overdue', ?, ?, 0)`,
      [user_id, title, message]
    );
    const notifId = ins.insertId;
    console.log(`✅ [VaccineReminder] Overdue notification created id=${notifId} for user ${user_id}`);

    // Fire FCM push — non-fatal if it fails
    await sendToUserDevices(
      user_id,
      "vaccine_dose_overdue",
      title,
      message,
      {
        type:       "vaccine_dose_overdue",
        patient_id: String(patient_id),
        vaccine_name,
        dose_label,
        due_date,
        notificationId: String(notifId),
      },
      `vaccine-overdue:${patient_id}:${due_date}`
    );
  } catch (err) {
    console.error(`❌ [VaccineReminder] Failed to send overdue notification for patient ${patient_id}:`, err);
  }
}

// ─── Cron-facing check function ───────────────────────────────────────────────

/**
 * Called every minute by the scheduler alongside checkAndSendDueReminders.
 * Finds vaccine_dose_reminders where scheduled_datetime <= NOW() and status=scheduled,
 * writes a notification row, fires FCM push, then marks status→sent/failed.
 */
async function checkAndSendDueVaccineReminders() {
  console.log("💉 Checking for due vaccine dose reminders...");

  try {
    await ensureVaccineDoseRemindersTable();

    // Expire reminders stuck for >24 h
    try {
      const [expired] = await db.execute(`
        UPDATE vaccine_dose_reminders
           SET status = 'failed',
               error_message = 'Expired: exceeded 24h retry window',
               updated_at    = CURRENT_TIMESTAMP
         WHERE status = 'scheduled'
           AND scheduled_datetime <= DATE_SUB(NOW(), INTERVAL 24 HOUR)
      `);
      if (expired.affectedRows > 0) {
        console.log(`🕐 [VaccineReminder] Expired ${expired.affectedRows} stuck vaccine reminders`);
      }
    } catch { /* non-critical */ }

    // Fetch due rows
    const [dueRows] = await db.execute(`
      SELECT vdr.*,
             p.child_fullname AS child_name
        FROM vaccine_dose_reminders vdr
        JOIN patients p ON vdr.patient_id = p.id
       WHERE vdr.status = 'scheduled'
         AND vdr.scheduled_datetime <= NOW()
       ORDER BY vdr.scheduled_datetime ASC
       LIMIT 50
    `);

    console.log(`📋 Found ${dueRows.length} due vaccine dose reminders to process`);

    let successCount = 0;
    let failCount    = 0;

    for (const row of dueRows) {
      try {
        await sendVaccineDoseReminder(row);
        successCount++;
      } catch (err) {
        failCount++;
        console.error(`❌ [VaccineReminder] Failed to process reminder id=${row.id}:`, err);
        try {
          await db.execute(
            `UPDATE vaccine_dose_reminders
                SET status = 'failed', error_message = ?, updated_at = CURRENT_TIMESTAMP
              WHERE id = ?`,
            [err.message, row.id]
          );
        } catch { /* best-effort */ }
      }
    }

    console.log(
      `✅ [VaccineReminder] Processed ${dueRows.length} vaccine reminders: ` +
      `${successCount} successful, ${failCount} failed`
    );

    return { success: true, processed: dueRows.length, successCount, failCount };
  } catch (err) {
    if (err.code === "ER_NO_SUCH_TABLE") {
      console.warn("⚠️ [VaccineReminder] vaccine_dose_reminders table missing — run migration 003");
      return { success: false, message: "table missing" };
    }
    console.error("❌ [VaccineReminder] checkAndSendDueVaccineReminders error:", err);
    return { success: false, message: err.message };
  }
}

/**
 * Process a single due vaccine reminder row.
 * Writes to notifications, fires FCM push, marks row as sent/failed.
 */
async function sendVaccineDoseReminder(row) {
  const {
    id,
    user_id,
    patient_id,
    vaccine_name,
    dose_label,
    due_date,
    days_before,
    child_name,
  } = row;

  const displayDate = formatDisplayDate(due_date);
  const name        = child_name || `Patient #${patient_id}`;
  let   title, message, ctaAction;

  if (days_before >= 3) {
    title     = "Upcoming Vaccine — 3 Days";
    message   = `${name}'s ${vaccine_name} (${dose_label}) is due in 3 days on ${displayDate}. ` +
                `Please book an appointment at the clinic to keep your baby's immunization on track.`;
    ctaAction = "book_appointment";
  } else {
    title     = "Vaccine Due Tomorrow!";
    message   = `Reminder: ${name}'s ${vaccine_name} (${dose_label}) is due tomorrow, ${displayDate}. ` +
                `Make sure you have a scheduled appointment. Don't miss it to avoid delays in your baby's immunization.`;
    ctaAction = "view_vaccine_card";
  }

  // Write to in-app notifications table (always — even if push fails)
  let notifId = null;
  const [ins] = await db.execute(
    `INSERT INTO notifications (user_id, notification_type, title, message, is_read)
     VALUES (?, 'vaccine_dose_reminder', ?, ?, 0)`,
    [user_id, title, message]
  );
  notifId = ins.insertId;
  console.log(`✅ [VaccineReminder] Notification row created id=${notifId} for user ${user_id}`);

  // Fire FCM push
  const pushResult = await sendToUserDevices(
    user_id,
    "vaccine_dose_reminder",
    title,
    message,
    {
      type:           "vaccine_dose_reminder",
      patient_id:     String(patient_id),
      vaccine_name,
      dose_label,
      due_date,
      days_before:    String(days_before),
      cta_action:     ctaAction,
      notificationId: String(notifId),
    },
    `vaccine-reminder:${id}`
  );

  const pushOk = pushResult.success || pushResult.skipped;

  // Mark reminder row as sent (in-app notification exists even if push failed)
  await db.execute(
    `UPDATE vaccine_dose_reminders
        SET status = 'sent', sent_at = CURRENT_TIMESTAMP, error_message = NULL,
            updated_at = CURRENT_TIMESTAMP
      WHERE id = ?`,
    [id]
  );

  console.log(
    `✅ [VaccineReminder] Sent vaccine reminder to user ${user_id} ` +
    `for ${vaccine_name} (${dose_label}) due ${due_date} ` +
    `[push: ${pushOk ? "ok" : "failed — in-app only"}]`
  );
}

// ─── All-doses-completed congratulations ─────────────────────────────────────

/**
 * Optionally call this after marking a dose complete if the child has no
 * remaining pending doses. Sends a congratulations notification.
 *
 * @param {object} ctx  { patient_id, user_id, child_name }
 */
async function sendAllDosesCompletedNotification({ patient_id, user_id, child_name }) {
  const name    = child_name || `Patient #${patient_id}`;
  const title   = "All Vaccines Completed! 🎉";
  const message =
    `${name} has completed all required vaccines for their age! ` +
    `Well done — keep up the great work on your baby's health.`;

  try {
    const [ins] = await db.execute(
      `INSERT INTO notifications (user_id, notification_type, title, message, is_read)
       VALUES (?, 'system', ?, ?, 0)`,
      [user_id, title, message]
    );
    const notifId = ins.insertId;
    console.log(`🎉 [VaccineReminder] All-doses-completed notification id=${notifId} for user ${user_id}`);

    await sendToUserDevices(
      user_id,
      "system",
      title,
      message,
      { type: "vaccine_all_completed", patient_id: String(patient_id), notificationId: String(notifId) },
      `vaccine-completed:${patient_id}`
    );
  } catch (err) {
    console.error(`❌ [VaccineReminder] Failed to send completion notification:`, err);
  }
}

// ─── Table auto-create (graceful startup) ─────────────────────────────────────

/**
 * Create vaccine_dose_reminders if it doesn't exist yet.
 * This is the same safety net pattern used in appointmentPushService.js.
 * For production the proper way is running migration 003.
 */
async function ensureVaccineDoseRemindersTable() {
  try {
    await db.execute(`
      CREATE TABLE IF NOT EXISTS vaccine_dose_reminders (
        id                      INT PRIMARY KEY AUTO_INCREMENT,
        patient_id              INT NOT NULL,
        user_id                 INT NOT NULL,
        vaccine_schedule_id     INT NOT NULL,
        vaccine_name            VARCHAR(255) NOT NULL,
        dose_label              VARCHAR(100) NOT NULL,
        due_date                DATE NOT NULL,
        reminder_date           DATE NOT NULL,
        scheduled_datetime      DATETIME NOT NULL,
        days_before             TINYINT NOT NULL,
        status                  ENUM('scheduled','sent','failed','cancelled') NOT NULL DEFAULT 'scheduled',
        sent_at                 TIMESTAMP NULL,
        error_message           TEXT NULL,
        created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_patient_id         (patient_id),
        INDEX idx_user_id            (user_id),
        INDEX idx_scheduled_datetime (scheduled_datetime),
        INDEX idx_status             (status),
        UNIQUE KEY uq_vaccine_reminder (patient_id, vaccine_schedule_id, days_before)
      )
    `);
  } catch (err) {
    // Non-fatal — table likely already exists
    if (err.code !== "ER_TABLE_EXISTS_ERROR") {
      console.warn("⚠️ [VaccineReminder] ensureTable warning:", err.message);
    }
  }
}

module.exports = {
  createVaccineDoseReminders,
  checkAndSendDueVaccineReminders,
  sendAllDosesCompletedNotification,
};
