const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const {
  checkAndSendDueReminders,
  getUserUpcomingReminders,
  checkUserUpcomingAppointments,
  cleanupOldReminders,
  sendAppointmentReminder,
} = require("../services/appointmentReminderService");
const { authenticateAdmin, authenticateUser } = require("../middleware/auth");

// ─── Internal scheduler endpoints (admin-gated so they can't be triggered publicly) ─
router.get("/check-due", authenticateAdmin, async (req, res) => {
  try {
    const result = await checkAndSendDueReminders();
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ check-due reminders:", error);
    res.status(500).json({ success: false, message: "Failed to check due reminders", error: error.message });
  }
});

router.post("/cleanup", authenticateAdmin, async (req, res) => {
  try {
    const result = await cleanupOldReminders();
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ cleanup reminders:", error);
    res.status(500).json({ success: false, message: "Failed to clean up old reminders", error: error.message });
  }
});

/**
 * POST /appointment-reminders/test-send
 * Admin-only: instantly inserts a due reminder for an appointment and fires it.
 * Used to test push + in-app reminder without waiting for the scheduled time.
 * Body: { appointmentId: number }
 */
router.post("/test-send", authenticateAdmin, async (req, res) => {
  try {
    const appointmentId = Number.parseInt(String(req.body.appointmentId), 10);
    if (!Number.isFinite(appointmentId) || appointmentId <= 0) {
      return res.status(400).json({ success: false, message: "Valid appointmentId is required" });
    }

    // Verify appointment exists and get user
    const [apptRows] = await db.execute(
      `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time, a.appointment_type, a.status,
              u.full_name
       FROM appointments a JOIN users u ON a.user_id = u.id
       WHERE a.id = ?`,
      [appointmentId]
    );
    if (apptRows.length === 0) {
      return res.status(404).json({ success: false, message: "Appointment not found" });
    }
    const appt = apptRows[0];

    // Insert a test reminder row with scheduled_datetime = NOW() so it fires immediately
    const now = new Date();
    const pad = n => String(n).padStart(2, '0');
    const nowStr = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    const todayStr = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}`;

    const [insertResult] = await db.execute(
      `INSERT INTO appointment_reminders
         (appointment_id, user_id, reminder_date, reminder_time, scheduled_datetime, days_before, reminder_type, status, created_at)
       VALUES (?, ?, ?, ?, ?, 0, 'test_reminder', 'scheduled', ?)`,
      [appointmentId, appt.user_id, todayStr, '00:00:00', nowStr, nowStr]
    );
    const reminderId = insertResult.insertId;

    // Fire it immediately
    const result = await sendAppointmentReminder(reminderId);

    res.json({
      success: true,
      message: `Test reminder fired for appointment ${appointmentId} (user: ${appt.full_name})`,
      reminderId,
      result,
    });
  } catch (error) {
    console.error("❌ test-send reminder:", error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ─── User-authenticated endpoints ─────────────────────────────────────────────
router.get("/user/:userId/upcoming", authenticateUser, async (req, res) => {
  try {
    const { userId } = req.params;
    const reminders  = await getUserUpcomingReminders(userId);
    res.status(200).json({ success: true, data: reminders });
  } catch (error) {
    console.error("❌ get upcoming reminders:", error);
    res.status(500).json({ success: false, message: "Failed to get upcoming reminders", error: error.message });
  }
});

router.get("/user/:userId/check-upcoming", authenticateUser, async (req, res) => {
  try {
    const { userId } = req.params;
    const result     = await checkUserUpcomingAppointments(userId);
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ check upcoming appointments:", error);
    res.status(500).json({ success: false, message: "Failed to check upcoming appointments", error: error.message });
  }
});

module.exports = router;
