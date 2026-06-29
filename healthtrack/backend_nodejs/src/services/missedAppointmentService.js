/**
 * Missed Appointment Service
 *
 * Automatically marks appointments as `no_show` (missed) when their scheduled
 * date/time has passed and they have not been marked `completed` by an admin.
 *
 * Targeted statuses: 'approved', 'pending', 'scheduled'
 * Condition: CONCAT(appointment_date, ' ', appointment_time) < UTC_TIMESTAMP()
 *
 * Notification flow for each flipped appointment:
 *   1. Insert row into `notifications` table (in-app inbox)
 *   2. Emit Socket.IO event to the patient's user room
 *   3. Send FCM push via sendToUserDevices
 */

"use strict";

const db      = require("../config/db");
const moment  = require("moment-timezone");
const { sendToUserDevices } = require("./appointmentPushService");

const MANILA_TZ = "Asia/Manila";
const APPOINTMENT_INPUT_FORMATS = [
  "YYYY-MM-DD HH:mm:ss",
  "YYYY-MM-DD HH:mm",
  "YYYY-MM-DD h:mm A",
  "YYYY-MM-DD hh:mm A",
  moment.ISO_8601,
];

/** Convert DB date + time strings to a Manila-locale display string */
function formatManilaDisplay(appointmentDate, appointmentTime) {
  const cleanDate = (appointmentDate || "").toString().split("T")[0];
  const cleanTime = (appointmentTime || "").toString()
    .replace(/^\d{4}-\d{2}-\d{2}[T ]/, "")
    .substring(0, 8);
  const raw = `${cleanDate} ${cleanTime}`.trim();

  const m = moment.utc(raw, APPOINTMENT_INPUT_FORMATS, true);
  const parsed = m.isValid() ? m : moment.utc(raw);
  if (parsed.isValid()) {
    return parsed.tz(MANILA_TZ).format("MMM D, YYYY [at] h:mm A");
  }
  return `${cleanDate} ${cleanTime}`.trim();
}

/**
 * Build the notification payload for a missed appointment.
 * Message copy is intentionally short for banner display.
 */
function buildMissedNotification(appt) {
  const typeLabel = (appt.appointment_type || "Appointment").toString();
  const display   = formatManilaDisplay(appt.appointment_date, appt.appointment_time);

  return {
    notificationType: "appointment_missed",
    fcmType:          "appointment_missed",
    title:            "Appointment Missed",
    // Short banner message (≤2 sentences, fits overlay_support banner)
    message:
      `Your ${typeLabel} appointment on ${display} was marked as missed because you did not arrive at the scheduled time. ` +
      `To avoid delays to your baby's vaccine or consultation, please make sure to attend your next appointment.`,
  };
}

/**
 * Core sweep: find all past-due active appointments and flip them to no_show.
 * Returns a summary object { checked, flipped, errors }.
 *
 * @param {object|null} io  - Socket.IO server instance (optional, for real-time push)
 */
async function markMissedAppointments(io = null) {
  const summary = { checked: 0, flipped: 0, errors: 0 };

  // ── 1. Find all past-due appointments that are still active ─────────────────
  //
  // We treat appointment_date + appointment_time as a UTC datetime (matches how
  // the rest of the codebase stores and reads it). The comparison
  //   CONCAT(appointment_date,' ',appointment_time) < UTC_TIMESTAMP()
  // intentionally uses a small grace buffer of 30 minutes so admins have time
  // to mark walk-ins complete before the cron fires.
  //
  const selectSql = `
    SELECT
      a.id,
      a.user_id,
      a.patient_id,
      a.appointment_date,
      a.appointment_time,
      a.appointment_type,
      a.status,
      u.full_name  AS user_name,
      p.child_fullname AS patient_name
    FROM appointments a
    LEFT JOIN users    u ON a.user_id    = u.id
    LEFT JOIN patients p ON a.patient_id = p.id
    WHERE a.status IN ('approved', 'pending', 'scheduled')
      AND CONCAT(
            DATE_FORMAT(a.appointment_date, '%Y-%m-%d'),
            ' ',
            IFNULL(a.appointment_time, '00:00:00')
          ) < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 MINUTE)
  `;

  let overdueRows;
  try {
    const [rows] = await db.execute(selectSql);
    overdueRows = rows;
  } catch (err) {
    console.error("❌ [MissedAppointments] Failed to query overdue appointments:", err.message);
    summary.errors += 1;
    return summary;
  }

  summary.checked = overdueRows.length;

  if (overdueRows.length === 0) {
    return summary; // nothing to do
  }

  console.log(`🔍 [MissedAppointments] Found ${overdueRows.length} overdue appointment(s) to flip.`);

  // ── 2. Process each appointment individually so one failure doesn't abort all ─
  for (const appt of overdueRows) {
    const appointmentId = appt.id;
    const userId        = appt.user_id;

    try {
      // ── 2a. Flip status to no_show ──────────────────────────────────────────
      await db.execute(
        `UPDATE appointments
         SET status     = 'no_show',
             missed_at  = UTC_TIMESTAMP(),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = ? AND status IN ('approved', 'pending', 'scheduled')`,
        [appointmentId]
      );

      summary.flipped += 1;
      console.log(`✅ [MissedAppointments] Appointment ${appointmentId} → no_show (user ${userId})`);

      // ── 2b. Build notification content ─────────────────────────────────────
      const notif = buildMissedNotification(appt);

      // ── 2c. Insert in-app notification row ─────────────────────────────────
      let insertedId = null;
      try {
        const [insResult] = await db.execute(
          `INSERT INTO notifications
             (user_id, appointment_id, notification_type, title, message, is_read)
           VALUES (?, ?, ?, ?, ?, 0)`,
          [userId, appointmentId, notif.notificationType, notif.title, notif.message]
        );
        insertedId = insResult.insertId;
      } catch (notifErr) {
        console.warn(`⚠️ [MissedAppointments] Could not insert notification row for appt ${appointmentId}:`, notifErr.message);
      }

      // ── 2d. Emit real-time Socket.IO event ─────────────────────────────────
      if (io) {
        const now = new Date().toISOString().slice(0, 19).replace("T", " ");
        io.to(`user_${userId}`).emit("appointmentNotification", {
          id:               insertedId,
          appointment_id:   appointmentId,
          user_id:          userId,
          notification_type: notif.notificationType,
          title:            notif.title,
          message:          notif.message,
          is_read:          false,
          created_at:       now,
          status:           "no_show",
          appointment_data: appt,
        });

        io.emit("appointmentUpdated", {
          appointment_id: appointmentId,
          status:         "no_show",
          data:           appt,
        });
      }

      // ── 2e. FCM push notification ───────────────────────────────────────────
      try {
        const display = formatManilaDisplay(appt.appointment_date, appt.appointment_time);
        await sendToUserDevices(
          userId,
          notif.fcmType,
          notif.title,
          notif.message,
          {
            type:                notif.fcmType,
            appointmentId:       String(appointmentId),
            status:              "no_show",
            appointmentDate:     String(appt.appointment_date || ""),
            appointmentTime:     String(appt.appointment_time || ""),
            appointmentTimeDisplay: display,
            appointmentTimezone: MANILA_TZ,
          },
          // Dedupe key: prevents duplicate push if cron fires twice in quick succession
          `auto_missed:${appointmentId}`
        );
      } catch (pushErr) {
        // Push failure is non-fatal — in-app notification already written
        console.warn(`⚠️ [MissedAppointments] FCM push failed for appt ${appointmentId}:`, pushErr.message);
      }

    } catch (rowErr) {
      console.error(`❌ [MissedAppointments] Error processing appointment ${appointmentId}:`, rowErr.message);
      summary.errors += 1;
    }
  }

  if (summary.flipped > 0) {
    console.log(`📊 [MissedAppointments] Sweep complete — flipped: ${summary.flipped}, errors: ${summary.errors}`);
  }

  return summary;
}

module.exports = { markMissedAppointments };
