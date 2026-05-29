const { sendToUserDevices, getUserFcmTokens } = require("../services/appointmentPushService");
const db = require("../config/db");

/**
 * Send appointment reminder notification to a patient
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.sendAppointmentReminder = async (req, res) => {
  try {
    const { patientId, title, message } = req.body;

    // Validate required fields
    if (!patientId || !title || !message) {
      return res.status(400).json({
        success: false,
        message: "patientId, title, and message are required"
      });
    }

    const getPatientSql = `
      SELECT p.child_fullname, u.id as user_id
      FROM patients p
      LEFT JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `;

    const [patientResults] = await db.execute(getPatientSql, [patientId]);

    if (patientResults.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Patient not found"
      });
    }

    const patient = patientResults[0];
    console.log(`🔍 Patient data for ID ${patientId}:`, patient);

    if (!patient.user_id) {
      return res.status(400).json({
        success: false,
        message: "Patient is not linked to a user account",
        errorCode: "MISSING_USER"
      });
    }

    const userTokens = await getUserFcmTokens(patient.user_id);
    if (userTokens.length === 0) {
      console.warn(`⚠️ Patient ${patientId} has no registered FCM tokens. User ID: ${patient.user_id}`);
      return res.status(400).json({
        success: false,
        message: "Patient's user account does not have a valid FCM token. Please ensure the patient's mobile app is properly registered and has internet connectivity.",
        errorCode: "MISSING_FCM_TOKEN"
      });
    }

    const isTestMode = process.env.TEST_MODE === 'true';

    let result;
    if (isTestMode) {
      console.log('// DEBUG TEST MODE: Simulating successful FCM notification send (appointment reminder)');
      result = { success: true, messageId: 'test_message_id_' + Date.now() };
    } else {
      result = await sendToUserDevices(
        patient.user_id,
        "appointment_reminder",
        title,
        message,
        {
          type: "appointment_reminder",
          patientId: patientId.toString(),
          timestamp: new Date().toISOString()
        },
        null
      );
    }

    if (!isTestMode && result.code === "push-disabled-by-user") {
      return res.status(400).json({
        success: false,
        message: "Patient has disabled push notifications.",
        errorCode: "PUSH_DISABLED"
      });
    }

    if (result.success) {
      // Log the notification in the database
      const insertNotificationSql = `
        INSERT INTO appointment_notifications 
        (appointment_id, user_id, notification_type, message, is_read, created_at)
        VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
      `;

      await db.execute(insertNotificationSql, [
        null, // appointment_id (null for general reminders)
        patient.user_id,
        "reminder", // Changed from "appointment_reminder" to match enum values
        message
      ]);

      return res.status(200).json({
        success: true,
        message: "Appointment reminder sent successfully",
        data: {
          messageId: result.messageId
        }
      });
    } else {
      return res.status(500).json({
        success: false,
        message: "Failed to send appointment reminder",
        error: result.error,
        code: result.code
      });
    }
  } catch (error) {
    console.error("❌ Error sending appointment reminder:", error);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message
    });
  }
};

/**
 * Send general notification to a patient
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.sendPatientNotification = async (req, res) => {
  try {
    const { patientId, title, message, notificationType = "general" } = req.body;

    // Validate required fields
    if (!patientId || !title || !message) {
      return res.status(400).json({
        success: false,
        message: "patientId, title, and message are required"
      });
    }

    const getPatientSql = `
      SELECT p.child_fullname, u.id as user_id
      FROM patients p
      LEFT JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `;

    const [patientResults] = await db.execute(getPatientSql, [patientId]);

    if (patientResults.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Patient not found"
      });
    }

    const patient = patientResults[0];
    console.log(`🔍 Patient data for ID ${patientId}:`, patient);

    if (!patient.user_id) {
      return res.status(400).json({
        success: false,
        message: "Patient is not linked to a user account",
        errorCode: "MISSING_USER"
      });
    }

    const userTokens = await getUserFcmTokens(patient.user_id);
    if (userTokens.length === 0) {
      console.warn(`⚠️ Patient ${patientId} has no registered FCM tokens. User ID: ${patient.user_id}`);
      return res.status(400).json({
        success: false,
        message: "Patient's user account does not have a valid FCM token. Please ensure the patient's mobile app is properly registered and has internet connectivity.",
        errorCode: "MISSING_FCM_TOKEN"
      });
    }

    const isTestMode = process.env.TEST_MODE === 'true';

    let result;
    if (isTestMode) {
      console.log('// DEBUG TEST MODE: Simulating successful FCM notification send (patient notification)');
      result = { success: true, messageId: 'test_message_id_' + Date.now() };
    } else {
      result = await sendToUserDevices(
        patient.user_id,
        notificationType === "appointment_reminder" ? "appointment_reminder" : notificationType,
        title,
        message,
        {
          type: notificationType,
          patientId: patientId.toString(),
          timestamp: new Date().toISOString()
        },
        null
      );
    }

    if (!isTestMode && result.code === "push-disabled-by-user") {
      return res.status(400).json({
        success: false,
        message: "Patient has disabled push notifications.",
        errorCode: "PUSH_DISABLED"
      });
    }

    if (result.success) {
      // Log the notification in the database
      const insertNotificationSql = `
        INSERT INTO appointment_notifications 
        (appointment_id, user_id, notification_type, message, is_read, created_at)
        VALUES (?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
      `;

      await db.execute(insertNotificationSql, [
        null, // appointment_id (null for general notifications)
        patient.user_id,
        notificationType === "appointment_reminder" ? "reminder" : notificationType, // Map to valid enum values
        message
      ]);

      return res.status(200).json({
        success: true,
        message: "Notification sent successfully",
        data: {
          messageId: result.messageId
        }
      });
    } else {
      return res.status(500).json({
        success: false,
        message: "Failed to send notification",
        error: result.error,
        code: result.code
      });
    }
  } catch (error) {
    console.error("❌ Error sending patient notification:", error);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message
    });
  }
};

/**
 * Check if a patient has a valid FCM token registered
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.checkPatientFCMToken = async (req, res) => {
  try {
    const { patientId } = req.body;

    // Validate required fields
    if (!patientId) {
      return res.status(400).json({
        success: false,
        message: "patientId is required"
      });
    }

    const getPatientSql = `
      SELECT p.child_fullname, u.id as user_id
      FROM patients p
      LEFT JOIN users u ON p.user_id = u.id
      WHERE p.id = ?
    `;

    const [patientResults] = await db.execute(getPatientSql, [patientId]);

    if (patientResults.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Patient not found"
      });
    }

    const patient = patientResults[0];

    let tokens = [];
    if (patient.user_id) {
      tokens = await getUserFcmTokens(patient.user_id);
    }
    const hasValidToken = tokens.length > 0;
    const tokenStatus = hasValidToken
      ? `${tokens.length} active device token(s)`
      : "No active FCM tokens";
    
    return res.status(200).json({
      success: true,
      hasValidToken: hasValidToken,
      tokenStatus: tokenStatus,
      message: hasValidToken 
        ? "Patient has a valid FCM token registered" 
        : "Patient does not have a valid FCM token registered",
      data: {
        patientId: patientId,
        childName: patient.child_fullname,
        userId: patient.user_id,
        hasValidToken: hasValidToken
      }
    });
  } catch (error) {
    console.error("❌ Error checking patient FCM token:", error);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message
    });
  }
};
