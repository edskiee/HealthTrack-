/**
 * Service to handle automated, event-driven reminders
 */

const db = require("../config/db");
const { sendPushNotification } = require("./firebaseService");
const { isUserPushEnabled } = require("./pushNotificationPolicy");
const { getUserReminderStatus, getDaysUntilNextReminder } = require("./reminderStatusService");
const { getUserFcmTokens } = require("./appointmentPushService");

// Cache for system settings to avoid repeated database queries
let systemSettingsCache = {};
let lastSettingsUpdate = 0;
const SETTINGS_CACHE_DURATION = 60000; // 1 minute

/**
 * Get system settings with caching
 */
async function getSystemSettings() {
  const now = Date.now();
  
  // If cache is fresh, return cached settings
  if (now - lastSettingsUpdate < SETTINGS_CACHE_DURATION) {
    return systemSettingsCache;
  }
  
  // Otherwise, fetch fresh settings
  try {
    const sql = "SELECT setting_key, setting_value, setting_type FROM system_settings WHERE is_active = 1";
    const [results] = await db.execute(sql);
    
    const settings = {};
    results.forEach(row => {
      let value = row.setting_value;
      
      // Convert based on type
      if (row.setting_type === 'boolean') {
        value = value === 'true' || value === '1';
      } else if (row.setting_type === 'number') {
        value = parseInt(value, 10);
      }
      
      settings[row.setting_key] = value;
    });
    
    // Update cache
    systemSettingsCache = settings;
    lastSettingsUpdate = now;
    
    return settings;
  } catch (error) {
    console.error("❌ Error fetching system settings:", error);
    // Return cached settings if available, otherwise defaults
    return systemSettingsCache || getDefaultSettings();
  }
}

/**
 * Get default system settings
 */
function getDefaultSettings() {
  return {
    appointment_reminders_enabled: true,
    reminder_interval_hours: 24,
    enabled_notification_types: ['appointment', 'reminder', 'cancellation', 'system'],
    notifications_enabled: true
  };
}

/**
 * Check if a notification type is enabled
 */
function isNotificationTypeEnabled(settings, type) {
  if (!settings.enabled_notification_types) return true;
  
  const enabledTypes = Array.isArray(settings.enabled_notification_types) 
    ? settings.enabled_notification_types 
    : settings.enabled_notification_types.split(',');
    
  return enabledTypes.includes(type);
}

/**
 * Send automated notification to user
 */
async function sendAutomatedNotification(userId, notificationType, title, message, data = {}) {
  try {
    // Get system settings
    const settings = await getSystemSettings();
    
    // Check if notifications are enabled globally
    if (!settings.notifications_enabled) {
      console.log(`🔔 Notifications disabled globally, skipping notification for user ${userId}`);
      return { success: false, message: "Notifications disabled globally" };
    }
    
    // Check if this notification type is enabled
    if (!isNotificationTypeEnabled(settings, notificationType)) {
      console.log(`🔔 Notification type ${notificationType} disabled, skipping notification for user ${userId}`);
      return { success: false, message: "Notification type disabled" };
    }

    // Always write to the notifications table so messages appear in the Notifications tab,
    // regardless of whether FCM push is enabled or the user has a token.
    let inboxNotificationId = null;
    try {
      const inboxType = (() => {
        if (notificationType === 'appointment_confirmation' || notificationType === 'appointment') return 'status_update';
        if (notificationType === 'rescheduling') return 'status_update';
        if (notificationType === 'cancellation') return 'status_update';
        if (notificationType === 'reminder') return 'appointment_reminder';
        return notificationType;
      })();
      const [insResult] = await db.execute(
        `INSERT INTO notifications (user_id, appointment_id, notification_type, title, message, is_read)
         VALUES (?, ?, ?, ?, ?, 0)`,
        [userId, data.appointment_id || null, inboxType, title, message]
      );
      inboxNotificationId = insResult.insertId;
    } catch (inboxErr) {
      console.error(`❌ Failed to write automated notification to notifications table for user ${userId}:`, inboxErr.message);
    }

    if (!(await isUserPushEnabled(userId))) {
      console.log(`// DEBUG automated notification skipped: user ${userId} disabled push`);
      return { success: !!inboxNotificationId, message: "Push notifications disabled by user; in-app written" };
    }
    
    // Get all active FCM tokens for this user (multi-device)
    let fcmTokens = [];
    try {
      fcmTokens = await getUserFcmTokens(userId);
    } catch (tokenErr) {
      console.warn(`⚠️ Error fetching FCM tokens for user ${userId}:`, tokenErr.message);
    }

    if (fcmTokens.length === 0) {
      console.log(`❌ No FCM tokens found for user ${userId}`);
      return { success: !!inboxNotificationId, message: "No FCM token found for user; in-app written" };
    }
    
    // Prepare notification payload with string-only data values
    const payload = {
      title: title,
      body: message,
      notificationType: notificationType,
      data: {
        type: String(notificationType),
        timestamp: String(new Date().toISOString()),
        notificationId: inboxNotificationId ? String(inboxNotificationId) : '',
        ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]))
      }
    };
    
    let successCount = 0;
    for (const fcmToken of fcmTokens) {
      console.log(`// DEBUG automatedReminder send userId=${userId} type=${notificationType}`);
      const result = await sendPushNotification(fcmToken, payload, userId);
      if (result.success) {
        successCount++;
      } else {
        console.warn(`⚠️ FCM push failed for user ${userId} token ${fcmToken.substring(0,20)}...: ${result.error}`);
        if (result.code === 'messaging/invalid-registration-token' ||
            result.code === 'messaging/registration-token-not-registered') {
          await db.execute('UPDATE users SET fcm_token = NULL WHERE fcm_token = ?', [fcmToken]);
          await db.execute('UPDATE user_device_tokens SET is_active = 0 WHERE fcm_token = ?', [fcmToken]);
        }
      }
    }
    
    // Save notification to history
    const historyStatus = successCount > 0 ? 'sent' : 'failed';
    await db.execute(
      "INSERT INTO notification_history (user_id, title, message, notification_type, payload, status) VALUES (?, ?, ?, ?, ?, ?)",
      [userId, title, message, notificationType, JSON.stringify(payload), historyStatus]
    );
    
    const overallSuccess = successCount > 0 || !!inboxNotificationId;
    console.log(`✅ Automated ${notificationType} notification processed for user ${userId} (push: ${successCount}/${fcmTokens.length}, inApp: ${!!inboxNotificationId})`);
    return { success: overallSuccess, message: "Notification processed" };
  } catch (error) {
    console.error(`❌ Error sending automated notification to user ${userId}:`, error);
    
    // Save failed notification to history
    try {
      await db.execute(
        "INSERT INTO notification_history (user_id, title, message, notification_type, status, error_message) VALUES (?, ?, ?, ?, ?, ?)",
        [userId, title, message, notificationType, 'failed', error.message]
      );
    } catch (dbError) {
      console.error("❌ Error saving failed notification to history:", dbError);
    }
    
    return { success: false, message: error.message };
  }
}

/**
 * Send appointment approval notification
 */
async function sendAppointmentApprovalNotification(appointmentId) {
  try {
    // Get appointment details
    const [appointments] = await db.execute(`
      SELECT a.*, u.full_name as user_name, u.fcm_token
      FROM appointments a
      JOIN users u ON a.user_id = u.id
      WHERE a.id = ?
    `, [appointmentId]);
    
    if (appointments.length === 0) {
      console.log(`❌ Appointment ${appointmentId} not found`);
      return { success: false, message: "Appointment not found" };
    }
    
    const appointment = appointments[0];
    
    // Send notification
    const title = "Appointment Approved!";
    const message = `Your ${appointment.appointment_type} appointment on ${appointment.appointment_date} at ${appointment.appointment_time} has been approved.`;
    
    return await sendAutomatedNotification(
      appointment.user_id, 
      'appointment', 
      title, 
      message,
      {
        appointment_id: appointmentId,
        appointment_date: appointment.appointment_date,
        appointment_time: appointment.appointment_time,
        appointment_type: appointment.appointment_type
      }
    );
  } catch (error) {
    console.error(`❌ Error sending appointment approval notification for appointment ${appointmentId}:`, error);
    return { success: false, message: error.message };
  }
}

/**
 * Send real-time push notification for appointment confirmation
 */
async function sendAppointmentConfirmationNotification(appointmentId) {
  try {
    // Get appointment details with user information
    const [appointments] = await db.execute(`
      SELECT a.*, u.full_name as user_name, u.fcm_token, s.service_name
      FROM appointments a
      JOIN users u ON a.user_id = u.id
      LEFT JOIN services_config s ON a.appointment_type = s.service_name
      WHERE a.id = ?
    `, [appointmentId]);
    
    if (appointments.length === 0) {
      console.log(`❌ Appointment ${appointmentId} not found`);
      return { success: false, message: "Appointment not found" };
    }
    
    const appointment = appointments[0];
    
    // Format the date and time for display
    const formattedDate = new Date(appointment.appointment_date).toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    
    const formattedTime = appointment.appointment_time;
    
    // Send notification (writes to notifications table + FCM push)
    const title = "Appointment Confirmed!";
    const message = `Your ${appointment.service_name || appointment.appointment_type} appointment on ${formattedDate} at ${formattedTime} has been confirmed.`;
    
    return await sendAutomatedNotification(
      appointment.user_id, 
      'appointment_confirmation', 
      title, 
      message,
      {
        appointment_id: appointmentId,
        appointment_date: appointment.appointment_date,
        appointment_time: appointment.appointment_time,
        appointment_type: appointment.appointment_type,
        service_name: appointment.service_name || appointment.appointment_type,
        notification_category: 'Appointment'
      }
    );
  } catch (error) {
    console.error(`❌ Error sending appointment confirmation notification for appointment ${appointmentId}:`, error);
    return { success: false, message: error.message };
  }
}

/**
 * Send appointment rescheduling notification
 */
async function sendAppointmentReschedulingNotification(appointmentId, newDate, newTime) {
  try {
    // Get appointment details
    const [appointments] = await db.execute(`
      SELECT a.*, u.full_name as user_name, u.fcm_token
      FROM appointments a
      JOIN users u ON a.user_id = u.id
      WHERE a.id = ?
    `, [appointmentId]);
    
    if (appointments.length === 0) {
      console.log(`❌ Appointment ${appointmentId} not found`);
      return { success: false, message: "Appointment not found" };
    }
    
    const appointment = appointments[0];
    
    // Send notification
    const title = "Appointment Rescheduled";
    const message = `Your ${appointment.appointment_type} appointment has been rescheduled to ${newDate} at ${newTime}.`;
    
    return await sendAutomatedNotification(
      appointment.user_id, 
      'rescheduling', 
      title, 
      message,
      {
        appointment_id: appointmentId,
        new_appointment_date: newDate,
        new_appointment_time: newTime,
        appointment_type: appointment.appointment_type
      }
    );
  } catch (error) {
    console.error(`❌ Error sending rescheduling notification for appointment ${appointmentId}:`, error);
    return { success: false, message: error.message };
  }
}

/**
 * Send appointment reminder
 */
async function sendAppointmentReminder(reminderId) {
  try {
    // Get reminder details
    const [reminders] = await db.execute(`
      SELECT r.*, u.full_name as user_name, u.fcm_token
      FROM reminders r
      JOIN users u ON r.user_id = u.id
      WHERE r.id = ?
    `, [reminderId]);
    
    if (reminders.length === 0) {
      console.log(`❌ Reminder ${reminderId} not found`);
      return { success: false, message: "Reminder not found" };
    }
    
    const reminder = reminders[0];
    
    // Send notification
    const title = "Appointment Reminder";
    const message = `Reminder: Your ${reminder.title} is scheduled for ${reminder.reminder_date} at ${reminder.reminder_time}.`;
    
    return await sendAutomatedNotification(
      reminder.user_id, 
      'reminder', 
      title, 
      message,
      {
        reminder_id: reminderId,
        reminder_date: reminder.reminder_date,
        reminder_time: reminder.reminder_time,
        reminder_title: reminder.title
      }
    );
  } catch (error) {
    console.error(`❌ Error sending appointment reminder ${reminderId}:`, error);
    return { success: false, message: error.message };
  }
}

/**
 * Send cancellation alert
 */
async function sendCancellationAlert(appointmentId, reason = "") {
  try {
    // Get appointment details
    const [appointments] = await db.execute(`
      SELECT a.*, u.full_name as user_name, u.fcm_token
      FROM appointments a
      JOIN users u ON a.user_id = u.id
      WHERE a.id = ?
    `, [appointmentId]);
    
    if (appointments.length === 0) {
      console.log(`❌ Appointment ${appointmentId} not found`);
      return { success: false, message: "Appointment not found" };
    }
    
    const appointment = appointments[0];
    
    // Send notification
    const title = "Appointment Cancelled";
    const message = `Your ${appointment.appointment_type} appointment on ${appointment.appointment_date} at ${appointment.appointment_time} has been cancelled.${reason ? ` Reason: ${reason}` : ''}`;
    
    return await sendAutomatedNotification(
      appointment.user_id, 
      'cancellation', 
      title, 
      message,
      {
        appointment_id: appointmentId,
        appointment_date: appointment.appointment_date,
        appointment_time: appointment.appointment_time,
        appointment_type: appointment.appointment_type,
        cancellation_reason: reason
      }
    );
  } catch (error) {
    console.error(`❌ Error sending cancellation alert for appointment ${appointmentId}:`, error);
    return { success: false, message: error.message };
  }
}

/**
 * Check and send upcoming appointment reminders
 */
async function checkUpcomingAppointments() {
  try {
    // Get system settings
    const settings = await getSystemSettings();
    
    // Check if reminders are enabled
    if (!settings.appointment_reminders_enabled) {
      console.log("🔔 Appointment reminders disabled, skipping check");
      return { success: true, message: "Reminders disabled" };
    }
    
    // Calculate the target time for reminders (e.g., 24 hours from now)
    const reminderInterval = settings.reminder_interval_hours || 24;
    const targetTime = new Date(Date.now() + (reminderInterval * 60 * 60 * 1000));
    const targetDate = targetTime.toISOString().split('T')[0];
    const targetHour = targetTime.getHours();
    
    console.log(`🔍 Checking for appointments on ${targetDate} around ${targetHour}:00`);
    
    // Find appointments that match our target time
    const [appointments] = await db.execute(`
      SELECT a.*, u.full_name as user_name, u.fcm_token
      FROM appointments a
      JOIN users u ON a.user_id = u.id
      WHERE a.appointment_date = ? 
      AND a.status = 'approved'
      AND HOUR(a.appointment_time) = ?
    `, [targetDate, targetHour]);
    
    console.log(`🔔 Found ${appointments.length} appointments matching criteria`);
    
    // Send reminders for each matching appointment
    const results = [];
    for (const appointment of appointments) {
      const title = "Upcoming Appointment";
      const message = `Reminder: Your ${appointment.appointment_type} appointment is scheduled for today at ${appointment.appointment_time}.`;
      
      const result = await sendAutomatedNotification(
        appointment.user_id, 
        'reminder', 
        title, 
        message,
        {
          appointment_id: appointment.id,
          appointment_date: appointment.appointment_date,
          appointment_time: appointment.appointment_time,
          appointment_type: appointment.appointment_type
        }
      );
      
      results.push({ appointmentId: appointment.id, ...result });
    }
    
    return { 
      success: true, 
      message: `Processed ${appointments.length} upcoming appointments`,
      results: results
    };
  } catch (error) {
    console.error("❌ Error checking upcoming appointments:", error);
    return { success: false, message: error.message };
  }
}

/**
 * Schedule periodic reminder checks
 */
function scheduleReminderChecks() {
  // Check for upcoming appointments every hour
  setInterval(async () => {
    console.log("⏰ Running scheduled reminder check");
    await checkUpcomingAppointments();
  }, 60 * 60 * 1000); // Every hour
  
  // Also run immediately on startup
  setTimeout(async () => {
    console.log("🚀 Starting initial reminder check");
    await checkUpcomingAppointments();
  }, 5000); // After 5 seconds
}

module.exports = {
  getSystemSettings,
  sendAutomatedNotification,
  sendAppointmentApprovalNotification,
  sendAppointmentConfirmationNotification,
  sendAppointmentReschedulingNotification,
  sendAppointmentReminder,
  sendCancellationAlert,
  checkUpcomingAppointments,
  scheduleReminderChecks
};