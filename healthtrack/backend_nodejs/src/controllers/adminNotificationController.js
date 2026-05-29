const db = require("../config/db");
const { sendPushNotification, isValidFcmToken } = require("../services/firebaseService");

// Send appointment status update notification - used by automated system
const sendAppointmentStatusNotification = async (userId, appointmentId, status, message) => {
  try {
    // Get user details
    const [userResult] = await db.execute('SELECT id, full_name, email, fcm_token FROM users WHERE id = ?', [userId]);

    if (userResult.length === 0) {
      console.error(`❌ User not found: ${userId}`);
      return;
    }

    const user = userResult[0];
    let userFcmToken = user.fcm_token;

    // Validate the FCM token if we have one
    if (userFcmToken && userFcmToken.trim() !== '' && !isValidFcmToken(userFcmToken)) {
      console.warn(`⚠️ Invalid FCM token format for user ${userId}, clearing from database`);
      // Clear invalid token from database
      await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [userId]);
      userFcmToken = null;
    } else if (userFcmToken && userFcmToken.trim() !== '') {
      console.log(`✅ Valid FCM token found for user ${userId}`);
    }

    // Create notification in database
    const insertQuery = `
      INSERT INTO notifications (
        user_id, 
        appointment_id,
        notification_type, 
        title,
        message, 
        is_read
      ) VALUES (?, ?, ?, ?, ?, 0)
    `;
    
    const notificationType = 'status_update';
    const title = getNotificationTitle(notificationType);
    const insertValues = [userId, appointmentId, notificationType, title, message];

    const [insertResult] = await db.execute(insertQuery, insertValues);

    // Send FCM push notification if token is available and valid
    if (userFcmToken) {
      try {
        const payload = {
          title: title,
          body: message,
          notificationType: notificationType,
          data: {
            notificationId: insertResult.insertId.toString(),
            userId: userId.toString(),
            appointmentId: appointmentId.toString(),
            type: notificationType,
            status: status,
            timestamp: new Date().toISOString()
          }
        };

        const fcmResult = await sendPushNotification(userFcmToken, payload, userId);
        if (fcmResult.success) {
          console.log(`// DEBUG FCM admin status notification OK appointment=${appointmentId} user=${userId}`);
        } else {
          console.warn(`// DEBUG FCM admin status notification FAIL appointment=${appointmentId}:`, fcmResult.error, fcmResult.code);
          if (fcmResult.code === 'messaging/invalid-registration-token' || 
              fcmResult.code === 'messaging/registration-token-not-registered' ||
              fcmResult.code === 'invalid-argument') {
            console.log(`🗑️ Clearing invalid FCM token for user ${userId}`);
            await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [userId]);
            await db.execute(
              'UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?',
              [userFcmToken]
            );
          }
        }
      } catch (fcmError) {
        console.error(`❌ Error sending FCM push notification for appointment ${appointmentId}:`, fcmError);
      }
    } else {
      console.log(`⚠️ No valid FCM token found for user ${userId}, skipping push notification`);
    }

    console.log(`✅ Appointment status notification sent to user ${userId} for appointment ${appointmentId}`);
  } catch (error) {
    console.error("Error sending appointment status notification:", error);
  }
};

// New endpoint for sending appointment status notifications - used by automated system
const sendAppointmentStatusNotificationEndpoint = async (req, res) => {
  try {
    const { userId, appointmentId, notificationType, message, title, fcmToken } = req.body;
    
    // Validate required fields
    if (!userId || !appointmentId || !message) {
      return res.status(400).json({
        success: false,
        message: "userId, appointmentId, and message are required"
      });
    }

    // Get user details to verify user exists
    const [userResult] = await db.execute('SELECT id, full_name, email, fcm_token FROM users WHERE id = ?', [userId]);

    if (userResult.length === 0) {
      return res.status(404).json({
        success: false,
        message: "User not found"
      });
    }

    const user = userResult[0];

    // Get user's FCM token if not provided in request
    let userFcmToken = fcmToken;
    if (!userFcmToken || userFcmToken.trim() === '') {
      userFcmToken = user.fcm_token;
      console.log(`🔄 Retrieved FCM token from database for user ${userId}: ${userFcmToken ? userFcmToken.substring(0, 20) + '...' : 'None'}`);
    } else {
      console.log(`📥 Using FCM token provided in request for user ${userId}: ${userFcmToken ? userFcmToken.substring(0, 20) + '...' : 'None'}`);
    }

    // Validate the FCM token if we have one
    if (userFcmToken && userFcmToken.trim() !== '' && !isValidFcmToken(userFcmToken)) {
      console.warn(`⚠️ Invalid FCM token format for user ${userId}, clearing from database`);
      // Clear invalid token from database
      await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [userId]);
      userFcmToken = null;
    } else if (userFcmToken && userFcmToken.trim() !== '') {
      console.log(`✅ Valid FCM token found for user ${userId}`);
    }

    // Create notification in database
    const insertQuery = `
      INSERT INTO notifications (
        user_id, 
        appointment_id,
        notification_type, 
        title,
        message, 
        is_read
      ) VALUES (?, ?, ?, ?, ?, 0)
    `;
    
    const finalNotificationType = notificationType || 'status_update';
    const notificationTitle = title || getNotificationTitle(finalNotificationType);
    const insertValues = [userId, appointmentId, finalNotificationType, notificationTitle, message];

    const [insertResult] = await db.execute(insertQuery, insertValues);

    // Initialize fcmResult to null
    let fcmResult = null;
    
    // Send FCM push notification if token is available and valid
    if (userFcmToken) {
      try {
        const payload = {
          title: notificationTitle,
          body: message,
          notificationType: finalNotificationType,
          data: {
            notificationId: insertResult.insertId.toString(),
            userId: userId.toString(),
            appointmentId: appointmentId.toString(),
            type: finalNotificationType,
            timestamp: new Date().toISOString()
          }
        };

        fcmResult = await sendPushNotification(userFcmToken, payload, userId);
        if (fcmResult.success) {
          console.log(`// DEBUG FCM endpoint status OK user=${userId} appointment=${appointmentId}`);
        } else {
          console.warn(`// DEBUG FCM endpoint status FAIL user=${userId}:`, fcmResult.error, fcmResult.code);
          if (fcmResult.code === 'messaging/invalid-registration-token' || 
              fcmResult.code === 'messaging/registration-token-not-registered' ||
              fcmResult.code === 'invalid-argument') {
            console.log(`🗑️ Clearing invalid FCM token for user ${userId}`);
            await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [userId]);
            await db.execute(
              'UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?',
              [userFcmToken]
            );
          }
        }
      } catch (fcmError) {
        console.error(`❌ Error sending FCM push notification to user ${userId}:`, fcmError);
      }
    } else {
      console.log(`⚠️ No valid FCM token found for user ${userId}, skipping push notification`);
    }

    console.log(`✅ Appointment status notification sent to user ${userId} for appointment ${appointmentId}`);

    res.json({
      success: true,
      message: "Status notification sent successfully",
      data: {
        notificationId: insertResult.insertId,
        userId: userId,
        userName: user.full_name,
        message: message,
        type: finalNotificationType,
        fcmResponse: fcmResult
      }
    });

  } catch (error) {
    console.error("Error sending appointment status notification:", error);
    // Handle case where notifications table doesn't exist
    if (error.code === 'ER_NO_SUCH_TABLE' || error.message.includes('notifications')) {
      res.status(500).json({
        success: false,
        message: "Notification endpoint not found. Please check the server configuration.",
        error: error.message
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to send status notification",
        error: error.message
      });
    }
  }
};

// Helper function to get notification title based on type
function getNotificationTitle(notificationType) {
  const titles = {
    'appointment_reminder': 'Appointment Reminder',
    'medication_reminder': 'Medication Reminder', 
    'follow_up_reminder': 'Follow-up Reminder',
    'custom_message': 'Custom Message',
    'system': 'System Notification',
    'status_update': 'Appointment Status Update'
  };
  return titles[notificationType] || 'Notification';
}

module.exports = {
  sendAppointmentStatusNotification,
  sendAppointmentStatusNotificationEndpoint
};