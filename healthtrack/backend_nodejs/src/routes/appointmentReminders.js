const express = require("express");
const router  = express.Router();
const {
  checkAndSendDueReminders,
  getUserUpcomingReminders,
  checkUserUpcomingAppointments,
  cleanupOldReminders,
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
