const express = require('express');
const router = express.Router();
const fcmNotificationController = require('../controllers/fcmNotificationController');

// Send appointment reminder notification
router.post('/appointment-reminder', fcmNotificationController.sendAppointmentReminder);

// Send general patient notification
router.post('/patient-notification', fcmNotificationController.sendPatientNotification);

// Check if a patient has a valid FCM token
router.post('/check-patient-token', fcmNotificationController.checkPatientFCMToken);

module.exports = router;