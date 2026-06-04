const express = require("express");
const router  = express.Router();
const fcmNotificationController = require("../controllers/fcmNotificationController");
const { authenticateAdmin } = require("../middleware/auth");

// FCM notification dispatch is an admin-only action
router.use(authenticateAdmin);

router.post("/appointment-reminder", fcmNotificationController.sendAppointmentReminder);
router.post("/patient-notification",  fcmNotificationController.sendPatientNotification);
router.post("/check-patient-token",   fcmNotificationController.checkPatientFCMToken);

module.exports = router;
