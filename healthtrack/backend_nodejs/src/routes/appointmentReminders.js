const express = require("express");
const router = express.Router();
const { 
  checkAndSendDueReminders, 
  getUserUpcomingReminders, 
  checkUserUpcomingAppointments,
  cleanupOldReminders 
} = require("../services/appointmentReminderService");

// Check and send due reminders (system endpoint)
router.get("/check-due", async (req, res) => {
  try {
    const result = await checkAndSendDueReminders();
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ Error checking due reminders:", error);
    res.status(500).json({
      success: false,
      message: "Failed to check due reminders",
      error: error.message
    });
  }
});

// Get upcoming reminders for a user
router.get("/user/:userId/upcoming", async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const reminders = await getUserUpcomingReminders(userId);
    
    res.status(200).json({
      success: true,
      data: reminders,
    });
  } catch (error) {
    console.error("❌ Error getting upcoming reminders:", error);
    res.status(500).json({
      success: false,
      message: "Failed to get upcoming reminders",
      error: error.message
    });
  }
});

// Check for upcoming appointments on app launch
router.get("/user/:userId/check-upcoming", async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const result = await checkUserUpcomingAppointments(userId);
    
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ Error checking upcoming appointments:", error);
    res.status(500).json({
      success: false,
      message: "Failed to check upcoming appointments",
      error: error.message
    });
  }
});

// Clean up old reminders (system maintenance endpoint)
router.post("/cleanup", async (req, res) => {
  try {
    const result = await cleanupOldReminders();
    res.status(200).json(result);
  } catch (error) {
    console.error("❌ Error cleaning up old reminders:", error);
    res.status(500).json({
      success: false,
      message: "Failed to clean up old reminders",
      error: error.message
    });
  }
});

module.exports = router;
