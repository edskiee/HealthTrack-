/**
 * Appointment Reminder Notification Service
 * Handles automated reminder notifications for approved appointments
 * Sends reminders 3 days before appointment date at 6:00 AM, 12:00 PM, 6:00 PM
 * Enhanced with timezone support and duplicate prevention
 */

const db = require("../config/db");
const moment = require("moment-timezone");
const { sendToUserDevices } = require("./appointmentPushService");

// Cache for system settings to avoid repeated database queries
let systemSettingsCache = {};
let lastSettingsUpdate = 0;
const SETTINGS_CACHE_DURATION = 300000; // 5 minutes

// Cache for processed reminders to prevent rapid retries
let processedReminderCache = new Set();
const REMINDER_CACHE_DURATION = 120000; // 2 minutes (longer than cron interval to avoid alternating failures)

// Timezone handling
const DEFAULT_TIMEZONE = 'Asia/Manila';
const APPOINTMENT_INPUT_FORMATS = [
  "YYYY-MM-DD HH:mm:ss",
  "YYYY-MM-DD HH:mm",
  "YYYY-MM-DD h:mm A",
  "YYYY-MM-DD hh:mm A",
  moment.ISO_8601,
];

/**
 * Get system settings with caching
 */
async function getSystemSettings() {
  const now = Date.now();
  
  // If cache is fresh, return cached settings
  if (now - lastSettingsUpdate < SETTINGS_CACHE_DURATION && Object.keys(systemSettingsCache).length > 0) {
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
    reminder_days_before: [2, 1, 0], // 2 days, 1 day, and same day
    reminders_per_day: 2,
    notifications_enabled: true,
    reminder_times: ['08:00', '17:00'] // 8 AM and 5 PM
  };
}

/**
 * Get user's timezone preference
 */
async function getUserTimezone(userId) {
  try {
    const [results] = await db.execute(
      'SELECT COALESCE(timezone, ?) as timezone FROM users WHERE id = ?',
      [DEFAULT_TIMEZONE, userId]
    );
    return results.length > 0 ? results[0].timezone : DEFAULT_TIMEZONE;
  } catch (error) {
    console.error('Error getting user timezone:', error);
    return DEFAULT_TIMEZONE;
  }
}

/**
 * Convert datetime to user's timezone
 */
function convertToUserTimezone(dateTime, timezone = DEFAULT_TIMEZONE) {
  try {
    const utcMoment = moment.utc(dateTime, APPOINTMENT_INPUT_FORMATS, true);
    const parsed = utcMoment.isValid() ? utcMoment : moment.utc(dateTime);
    if (!parsed.isValid()) return dateTime;
    return parsed.tz(timezone).format("MMMM DD, YYYY hh:mm A");
  } catch (error) {
    console.error('Error converting timezone:', error);
    return dateTime;
  }
}

function buildAppointmentDateTimeUtc(appointmentDate, appointmentTime) {
  return `${appointmentDate || ""} ${appointmentTime || ""}`.trim();
}

/**
 * Check if reminder was recently processed to prevent duplicates
 */
function isReminderRecentlyProcessed(reminderId) {
  const cacheKey = `reminder_${reminderId}`;
  return processedReminderCache.has(cacheKey);
}

/**
 * Mark reminder as processed
 */
function markReminderAsProcessed(reminderId) {
  const cacheKey = `reminder_${reminderId}`;
  processedReminderCache.add(cacheKey);
  
  // Clean up old cache entries periodically
  setTimeout(() => {
    processedReminderCache.delete(cacheKey);
  }, REMINDER_CACHE_DURATION);
}

/**
 * Create reminder schedule for an approved appointment
 */
async function createAppointmentReminderSchedule(appointmentId, appointmentDate, appointmentTime, userId) {
  try {
    console.log(`📅 Creating reminder schedule for appointment ${appointmentId} on ${appointmentDate} at ${appointmentTime}`);
    
    const settings = await getSystemSettings();
    
    if (!settings.appointment_reminders_enabled) {
      console.log(`🔔 Appointment reminders disabled, skipping schedule creation`);
      return { success: false, message: "Appointment reminders disabled" };
    }
    
    // Parse appointment datetime in configured timezone to avoid UTC/local drift
    const appointmentDateTime = moment.tz(
      `${appointmentDate} ${appointmentTime}`,
      APPOINTMENT_INPUT_FORMATS,
      DEFAULT_TIMEZONE
    );
    const now = moment.tz(DEFAULT_TIMEZONE);
    
    // If appointment is in the past, don't create reminders
    if (!appointmentDateTime.isValid() || appointmentDateTime.isSameOrBefore(now)) {
      console.log(`⚠️ Appointment ${appointmentId} is in the past, skipping reminder creation`);
      return { success: false, message: "Appointment is in the past" };
    }
    
    let reminderDaysBefore = settings.reminder_days_before || [3];
    const remindersPerDay = settings.reminders_per_day || 3;
    let reminderTimes = settings.reminder_times || ['06:00', '12:00', '18:00'];
    
    // Parse JSON strings if needed
    if (typeof reminderDaysBefore === 'string') {
      try {
        reminderDaysBefore = JSON.parse(reminderDaysBefore);
      } catch (e) {
        reminderDaysBefore = [3];
      }
    }
    
    if (typeof reminderTimes === 'string') {
      try {
        reminderTimes = JSON.parse(reminderTimes);
      } catch (e) {
        reminderTimes = ['06:00', '12:00', '18:00'];
      }
    }
    
    const reminderSchedules = [];
    
    // Create reminders for each day before appointment
    for (const daysBefore of reminderDaysBefore) {
      const reminderDate = appointmentDateTime.clone().subtract(daysBefore, "days");
      
      // For same-day reminders (daysBefore=0), allow if reminder time is still in the future
      // For other days, only create if the reminder date is today or future
      const reminderDateStart = reminderDate.clone().startOf('day');
      const todayStart = now.clone().startOf('day');
      
      if (reminderDateStart.isSameOrAfter(todayStart)) {
        for (let i = 0; i < remindersPerDay && i < reminderTimes.length; i++) {
          const reminderTime = reminderTimes[i];
          const scheduledDateTime = moment.tz(
            `${reminderDate.format("YYYY-MM-DD")} ${reminderTime}`,
            "YYYY-MM-DD HH:mm",
            DEFAULT_TIMEZONE
          );
          
          // Only schedule if the reminder time is in the future
          if (scheduledDateTime.isValid() && scheduledDateTime.isAfter(now)) {
            const reminderData = {
              appointment_id: appointmentId,
              user_id: userId,
              reminder_date: reminderDate.format("YYYY-MM-DD"),
              reminder_time: reminderTime,
              scheduled_datetime: scheduledDateTime.format("YYYY-MM-DD HH:mm:ss"),
              days_before: daysBefore,
              reminder_type: `day_${daysBefore}_reminder_${i + 1}`,
              status: 'scheduled',
              created_at: now.format("YYYY-MM-DD HH:mm:ss")
            };
            
            reminderSchedules.push(reminderData);
          }
        }
      }
    }
    
    // Insert reminder schedules into database using parameterized queries
    if (reminderSchedules.length > 0) {
      const sql = `
        INSERT INTO appointment_reminders 
        (appointment_id, user_id, reminder_date, reminder_time, scheduled_datetime, days_before, reminder_type, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      const duplicateCheckSql = `
        SELECT id FROM appointment_reminders
        WHERE appointment_id = ?
          AND reminder_type = ?
          AND scheduled_datetime = ?
          AND status = 'scheduled'
        LIMIT 1
      `;
      
      let insertedCount = 0;
      for (const reminder of reminderSchedules) {
        const [dupes] = await db.execute(duplicateCheckSql, [
          reminder.appointment_id,
          reminder.reminder_type,
          reminder.scheduled_datetime
        ]);
        if (dupes.length > 0) {
          continue;
        }
        await db.execute(sql, [
          reminder.appointment_id,
          reminder.user_id,
          reminder.reminder_date,
          reminder.reminder_time,
          reminder.scheduled_datetime,
          reminder.days_before,
          reminder.reminder_type,
          reminder.status,
          reminder.created_at
        ]);
        insertedCount += 1;
      }
      console.log(`✅ Created ${insertedCount} reminder schedules for appointment ${appointmentId}`);
      
      return { 
        success: true, 
        message: `Created ${insertedCount} reminder schedules`,
        remindersCreated: insertedCount
      };
    } else {
      console.log(`⚠️ No valid reminder schedules created for appointment ${appointmentId} (all in the past)`);
      return { success: false, message: "No valid reminder schedules created" };
    }
    
  } catch (error) {
    // Enhanced error handling for missing table and other database issues
    if (error.code === 'ER_NO_SUCH_TABLE') {
      console.warn("⚠️ appointment_reminders table does not exist. Unable to create reminder schedule.");
      console.log("💡 The table will be automatically created when the server restarts.");
      return { 
        success: false, 
        message: "Database table missing - initialization required",
        requiresInitialization: true,
        error: "appointment_reminders table not found"
      };
    } else if (error.code === 'ER_BAD_DB_ERROR') {
      console.warn("⚠️ Database connection error. Unable to create reminder schedule.");
      return { 
        success: false, 
        message: "Database connection error",
        error: error.message
      };
    } else {
      console.error(`❌ Error creating reminder schedule for appointment ${appointmentId}:`, error);
      return { success: false, message: error.message };
    }
  }
}

/**
 * Send appointment reminder notification
 */
async function sendAppointmentReminder(reminderId) {
  try {
    console.log(`🔔 Sending reminder notification for reminder ID: ${reminderId}`);
    
    // Check if recently processed to prevent rapid-fire retries
    if (isReminderRecentlyProcessed(reminderId)) {
      console.log(`⚠️ Reminder ${reminderId} was recently processed, skipping to prevent duplicate`);
      return { success: false, message: "Reminder recently processed (duplicate prevention)" };
    }
    
    // Get reminder details with appointment and user information
    // Using LEFT JOINs so orphaned reminders (deleted appointment/user) are still found
    // Using COALESCE to safely handle missing timezone column
    const [reminders] = await db.execute(`
      SELECT 
        ar.*,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        u.full_name as user_name,
        'Asia/Manila' as timezone,
        p.child_fullname as patient_name
      FROM appointment_reminders ar
      LEFT JOIN appointments a ON ar.appointment_id = a.id
      LEFT JOIN users u ON ar.user_id = u.id
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE ar.id = ? AND ar.status = 'scheduled'
    `, [reminderId]);
    
    if (reminders.length === 0) {
      console.log(`❌ Reminder ${reminderId} not found or not scheduled`);
      return { success: false, message: "Reminder not found or not scheduled" };
    }
    
    const reminder = reminders[0];

    // Check if appointment or user is missing (orphaned reminder)
    if (!reminder.appointment_date || !reminder.user_name) {
      const reason = !reminder.appointment_date 
        ? `appointment ${reminder.appointment_id} not found` 
        : `user ${reminder.user_id} not found`;
      console.log(`⚠️ Reminder ${reminderId} is orphaned (${reason}), marking as failed`);
      await updateReminderStatus(reminderId, 'failed', `Orphaned: ${reason}`);
      markReminderAsProcessed(reminderId);
      return { success: false, message: `Orphaned reminder: ${reason}` };
    }

    console.log(`// DEBUG reminder trigger fired reminderId=${reminderId} userId=${reminder.user_id}`);

    const appointmentUtcDateTime = buildAppointmentDateTimeUtc(reminder.appointment_date, reminder.appointment_time);
    const appointmentUtcMoment = moment.utc(appointmentUtcDateTime, APPOINTMENT_INPUT_FORMATS, true);
    const appointmentDisplay = convertToUserTimezone(appointmentUtcDateTime, reminder.timezone || DEFAULT_TIMEZONE);
    
    // Create reminder message based on days before
    let title, message;
    if (reminder.days_before === 1) {
      title = "Appointment Tomorrow!";
      message = `Reminder: Your ${reminder.appointment_type} appointment is tomorrow, ${appointmentDisplay}.`;
    } else if (reminder.days_before === 2) {
      title = "Appointment in 2 Days";
      message = `Reminder: Your ${reminder.appointment_type} appointment is in 2 days, on ${appointmentDisplay}.`;
    } else {
      title = "Upcoming Appointment";
      message = `Reminder: Your ${reminder.appointment_type} appointment is on ${appointmentDisplay}.`;
    }
    
    // Add doctor and location info if available
    if (reminder.doctor_name) {
      message += ` Doctor: ${reminder.doctor_name}.`;
    }
    if (reminder.clinic_hospital) {
      message += ` Location: ${reminder.clinic_hospital}.`;
    }
    
    // Always write to the notifications table so the reminder appears in the app's
    // Notifications tab regardless of whether the FCM push succeeds.
    let inboxNotificationId = null;
    try {
      const [insResult] = await db.execute(
        `INSERT INTO notifications (user_id, appointment_id, notification_type, title, message, is_read)
         VALUES (?, ?, 'appointment_reminder', ?, ?, 0)`,
        [reminder.user_id, reminder.appointment_id, title, message]
      );
      inboxNotificationId = insResult.insertId;
      console.log(`✅ Reminder notifications row created id=${inboxNotificationId}`);
    } catch (inboxErr) {
      console.error(`❌ Failed to insert reminder into notifications table:`, inboxErr);
    }

    // Send push notification to all active user devices
    const result = await sendToUserDevices(
      reminder.user_id,
      "appointment_reminder",
      title,
      message,
      {
        reminderId,
        appointmentId: reminder.appointment_id,
        appointmentDate: reminder.appointment_date,
        appointmentTime: reminder.appointment_time,
        appointmentTimestampUtc: appointmentUtcMoment.isValid() ? appointmentUtcMoment.toISOString() : "",
        appointmentTimeDisplay: appointmentDisplay,
        appointmentTimezone: reminder.timezone || DEFAULT_TIMEZONE,
        appointmentType: reminder.appointment_type,
        doctorName: reminder.doctor_name || "",
        clinicHospital: reminder.clinic_hospital || "",
        daysBefore: reminder.days_before,
        reminderType: reminder.reminder_type,
        notificationId: inboxNotificationId ? String(inboxNotificationId) : "",
      },
      `reminder:${reminderId}`
    );
    
    if (result.success || result.skipped) {
      // Update reminder status to sent
      await updateReminderStatus(reminderId, 'sent', null);
      
      // Only cache as processed AFTER successful send to prevent premature blocking
      markReminderAsProcessed(reminderId);
      
      // Save notification to history
      await saveNotificationHistory(reminder.user_id, title, message, 'appointment_reminder', { reminderId }, 'sent');
      
      console.log(`✅ Appointment reminder sent successfully for reminder ${reminderId}`);
      return { success: true, message: "Reminder sent successfully" };
    } else {
      // Update reminder status to failed
      await updateReminderStatus(reminderId, 'failed', result.error || 'Unknown error');
      
      // Cache as processed so we don't retry immediately (will retry after cache expires)
      markReminderAsProcessed(reminderId);
      
      // Save failed notification to history
      await saveNotificationHistory(reminder.user_id, title, message, 'appointment_reminder', { reminderId }, 'failed', result.error);
      
      console.log(`❌ Failed to send appointment reminder for reminder ${reminderId}: ${result.error}`);
      // Still return success if the in-app notification was written
      if (inboxNotificationId) {
        return { success: true, message: "In-app notification created; push failed: " + result.error };
      }
      return { success: false, message: result.error };
    }
    
  } catch (error) {
    console.error(`❌ Error sending appointment reminder ${reminderId}:`, error);
    
    // Cache as processed to prevent infinite retry loop on persistent errors
    markReminderAsProcessed(reminderId);
    
    // Update reminder status to failed
    try {
      await updateReminderStatus(reminderId, 'failed', error.message);
    } catch (updateError) {
      console.error("❌ Error updating reminder status:", updateError);
    }
    
    return { success: false, message: error.message };
  }
}

/**
 * Update reminder status
 */
async function updateReminderStatus(reminderId, status, errorMessage = null) {
  try {
    const sql = `
      UPDATE appointment_reminders 
      SET status = ?, sent_at = CURRENT_TIMESTAMP, error_message = ?
      WHERE id = ?
    `;
    await db.execute(sql, [status, errorMessage, reminderId]);
  } catch (error) {
    console.error(`❌ Error updating reminder status for ${reminderId}:`, error);
  }
}

/**
 * Cancel all scheduled reminders for an appointment.
 * Used when appointments are cancelled/rescheduled/approved again to prevent duplicates.
 */
async function cancelAppointmentReminders(appointmentId, reason = 'Appointment updated') {
  try {
    const sql = `
      UPDATE appointment_reminders
      SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP, error_message = ?
      WHERE appointment_id = ?
      AND status = 'scheduled'
    `;
    const [result] = await db.execute(sql, [reason, appointmentId]);
    console.log(`🗑️ Cancelled ${result.affectedRows} scheduled reminders for appointment ${appointmentId}`);
    return { success: true, cancelledCount: result.affectedRows };
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') {
      console.warn("⚠️ appointment_reminders table does not exist. Unable to cancel reminders.");
      return { success: false, message: "appointment_reminders table not found" };
    }
    console.error(`❌ Error cancelling reminders for appointment ${appointmentId}:`, error);
    return { success: false, message: error.message };
  }
}

/**
 * Save notification to history
 */
async function saveNotificationHistory(userId, title, message, notificationType, payload, status, errorMessage = null) {
  try {
    const sql = `
      INSERT INTO notification_history 
      (user_id, title, message, notification_type, payload, status, error_message, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    `;
    await db.execute(sql, [userId, title, message, notificationType, JSON.stringify(payload), status, errorMessage]);
  } catch (error) {
    console.error("❌ Error saving notification to history:", error);
  }
}

/**
 * Check and send due reminders
 * This function should be called periodically (e.g., every minute)
 */
async function checkAndSendDueReminders() {
  try {
    console.log("⏰ Checking for due appointment reminders...");
    
    const settings = await getSystemSettings();
    
    if (!settings.appointment_reminders_enabled) {
      console.log("🔔 Appointment reminders disabled, skipping check");
      return { success: true, message: "Reminders disabled" };
    }
    
    // First, expire reminders that have been stuck in 'scheduled' for too long
    // (more than 24 hours past their scheduled time). This prevents infinite retries.
    try {
      const [expiredResult] = await db.execute(`
        UPDATE appointment_reminders 
        SET status = 'failed', error_message = 'Expired: exceeded max retry window (24h)', updated_at = CURRENT_TIMESTAMP
        WHERE status = 'scheduled'
        AND scheduled_datetime <= DATE_SUB(NOW(), INTERVAL 24 HOUR)
      `);
      if (expiredResult.affectedRows > 0) {
        console.log(`🕐 Expired ${expiredResult.affectedRows} stuck reminders (>24h past due)`);
      }
    } catch (expireErr) {
      // Non-critical; continue even if expiry update fails
      console.warn('⚠️ Could not expire old reminders:', expireErr.message || expireErr);
    }
    
    // Get reminders that are due to be sent
    const [dueReminders] = await db.execute(`
      SELECT id, appointment_id, user_id, reminder_date, reminder_time, days_before, reminder_type
      FROM appointment_reminders
      WHERE status = 'scheduled'
      AND scheduled_datetime <= NOW()
      ORDER BY scheduled_datetime ASC
      LIMIT 50
    `);
    
    console.log(`📋 Found ${dueReminders.length} due reminders to process`);
    
    const results = [];
    for (const reminder of dueReminders) {
      try {
        console.log(
          `// DEBUG cron reminder batch item id=${reminder.id} userId=${reminder.user_id} appointmentId=${reminder.appointment_id}`
        );
        const result = await sendAppointmentReminder(reminder.id);
        results.push({
          reminderId: reminder.id,
          appointmentId: reminder.appointment_id,
          userId: reminder.user_id,
          ...result
        });
      } catch (error) {
        // Individual reminder failures should not crash the entire process
        console.error(`❌ Failed to process reminder ${reminder.id}:`, error);
        results.push({
          reminderId: reminder.id,
          appointmentId: reminder.appointment_id,
          userId: reminder.user_id,
          success: false,
          message: error.message,
          error: 'Individual reminder processing failed'
        });
        
        // Update reminder status to failed if possible
        try {
          await updateReminderStatus(reminder.id, 'failed', `Processing error: ${error.message}`);
        } catch (updateError) {
          console.error(`❌ Failed to update reminder ${reminder.id} status:`, updateError);
        }
      }
    }
    
    const successfulCount = results.filter(r => r.success).length;
    const failedCount = results.length - successfulCount;
    
    console.log(`✅ Processed ${results.length} reminders: ${successfulCount} successful, ${failedCount} failed`);
    
    return {
      success: true,
      message: `Processed ${results.length} reminders: ${successfulCount} successful, ${failedCount} failed`,
      results: results
    };
    
  } catch (error) {
    // Enhanced error handling for missing table and other database issues
    if (error.code === 'ER_NO_SUCH_TABLE') {
      console.warn("⚠️ appointment_reminders table does not exist. Please ensure the database is properly initialized.");
      console.log("💡 The table will be automatically created when the server restarts.");
      return { 
        success: false, 
        message: "Database table missing - initialization required",
        requiresInitialization: true,
        error: "appointment_reminders table not found"
      };
    } else if (error.code === 'ER_BAD_DB_ERROR') {
      console.warn("⚠️ Database connection error. Unable to access database.");
      return { 
        success: false, 
        message: "Database connection error",
        error: error.message
      };
    } else {
      console.error("❌ Error checking due reminders:", error);
      return { success: false, message: error.message };
    }
  }
}

/**
 * Get upcoming reminders for a user
 */
async function getUserUpcomingReminders(userId) {
  try {
    const sql = `
      SELECT 
        ar.*,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital
      FROM appointment_reminders ar
      JOIN appointments a ON ar.appointment_id = a.id
      WHERE ar.user_id = ?
      AND ar.status = 'scheduled'
      AND ar.scheduled_datetime > NOW()
      ORDER BY ar.scheduled_datetime ASC
      LIMIT 10
    `;
    
    const [reminders] = await db.execute(sql, [userId]);
    return reminders;
  } catch (error) {
    // Enhanced error handling for missing table and other database issues
    if (error.code === 'ER_NO_SUCH_TABLE') {
      console.warn("⚠️ appointment_reminders table does not exist. Unable to retrieve upcoming reminders.");
      console.log("💡 The table will be automatically created when the server restarts.");
      return [];
    } else if (error.code === 'ER_BAD_DB_ERROR') {
      console.warn("⚠️ Database connection error. Unable to retrieve upcoming reminders.");
      return [];
    } else {
      console.error(`❌ Error getting upcoming reminders for user ${userId}:`, error);
      return [];
    }
  }
}

/**
 * Check for upcoming appointments on app launch
 */
async function checkUserUpcomingAppointments(userId) {
  try {
    console.log(`🔍 Checking upcoming appointments for user ${userId}`);
    
    // Get approved appointments in the next 7 days
    const [appointments] = await db.execute(`
      SELECT 
        id,
        appointment_date,
        appointment_time,
        appointment_type,
        doctor_name,
        clinic_hospital,
        status
      FROM appointments
      WHERE user_id = ?
      AND status = 'approved'
      AND appointment_date >= CURDATE()
      AND appointment_date <= DATE_ADD(CURDATE(), INTERVAL 7 DAY)
      ORDER BY appointment_date ASC, appointment_time ASC
    `, [userId]);
    
    if (appointments.length === 0) {
      console.log(`📅 No upcoming appointments found for user ${userId}`);
      return { success: true, hasUpcoming: false, appointments: [] };
    }
    
    console.log(`📅 Found ${appointments.length} upcoming appointments for user ${userId}`);

    const results = [];
    for (const appointment of appointments) {
      const appointmentUtcDateTime = buildAppointmentDateTimeUtc(appointment.appointment_date, appointment.appointment_time);
      const appointmentUtcMoment = moment.utc(appointmentUtcDateTime, APPOINTMENT_INPUT_FORMATS, true);
      const appointmentDisplay = convertToUserTimezone(appointmentUtcDateTime, DEFAULT_TIMEZONE);

      const title = "Upcoming Appointment";
      const message = `You have an upcoming ${appointment.appointment_type} appointment on ${appointmentDisplay}.`;

      const payload = {
        title: title,
        body: message,
        data: {
          type: 'upcoming_appointment_check',
          appointment_id: appointment.id.toString(),
          appointment_date: appointment.appointment_date,
          appointment_time: appointment.appointment_time,
          appointment_timestamp_utc: appointmentUtcMoment.isValid() ? appointmentUtcMoment.toISOString() : '',
          appointment_time_display: appointmentDisplay,
          appointment_timezone: DEFAULT_TIMEZONE,
          appointment_type: appointment.appointment_type,
          doctor_name: appointment.doctor_name || '',
          clinic_hospital: appointment.clinic_hospital || '',
          timestamp: new Date().toISOString(),
          notificationType: 'upcoming_appointment_check'
        }
      };

      console.log(`// DEBUG upcoming appointment check push userId=${userId} appointmentId=${appointment.id}`);
      const result = await sendToUserDevices(
        userId,
        'upcoming_appointment_check',
        title,
        message,
        payload.data,
        `upcoming-check:${userId}:${appointment.id}`
      );

      await saveNotificationHistory(userId, title, message, 'upcoming_appointment_check', payload, result.success ? 'sent' : 'failed', result.success ? null : result.error);
      
      results.push({
        appointmentId: appointment.id,
        success: result.success,
        error: result.error
      });
    }
    
    return {
      success: true,
      hasUpcoming: true,
      appointments: appointments,
      notificationResults: results
    };
    
  } catch (error) {
    console.error(`❌ Error checking upcoming appointments for user ${userId}:`, error);
    return { success: false, message: error.message, hasUpcoming: false };
  }
}

/**
 * Clean up old reminders (older than 30 days)
 */
async function cleanupOldReminders() {
  try {
    const sql = `
      DELETE FROM appointment_reminders 
      WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
      AND status IN ('sent', 'failed')
    `;
    
    const [result] = await db.execute(sql);
    console.log(`🧹 Cleaned up ${result.affectedRows} old reminders`);
    
    return { success: true, deletedCount: result.affectedRows };
  } catch (error) {
    // Enhanced error handling for missing table and other database issues
    if (error.code === 'ER_NO_SUCH_TABLE') {
      console.warn("⚠️ appointment_reminders table does not exist. Unable to clean up old reminders.");
      console.log("💡 The table will be automatically created when the server restarts.");
      return { 
        success: false, 
        message: "Database table missing - initialization required",
        requiresInitialization: true,
        error: "appointment_reminders table not found"
      };
    } else if (error.code === 'ER_BAD_DB_ERROR') {
      console.warn("⚠️ Database connection error. Unable to clean up old reminders.");
      return { 
        success: false, 
        message: "Database connection error",
        error: error.message
      };
    } else {
      console.error("❌ Error cleaning up old reminders:", error);
      return { success: false, message: error.message };
    }
  }
}

module.exports = {
  createAppointmentReminderSchedule,
  sendAppointmentReminder,
  checkAndSendDueReminders,
  getUserUpcomingReminders,
  checkUserUpcomingAppointments,
  cleanupOldReminders,
  getSystemSettings,
  cancelAppointmentReminders,
  getUserTimezone
};
