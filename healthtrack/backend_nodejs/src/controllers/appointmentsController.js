const db = require("../config/db");
const moment = require("moment-timezone");
const { sendAppointmentStatusNotification } = require("./adminNotificationController");
const { sendAppointmentConfirmationNotification, sendCancellationAlert } = require("../services/automatedReminderService");
const { createAppointmentReminderSchedule, cancelAppointmentReminders } = require("../services/appointmentReminderService");
const { sendToUserDevices } = require("../services/appointmentPushService");

const MANILA_TZ = "Asia/Manila";
const APPOINTMENT_INPUT_FORMATS = [
  "YYYY-MM-DD HH:mm:ss",
  "YYYY-MM-DD HH:mm",
  "YYYY-MM-DD h:mm A",
  "YYYY-MM-DD hh:mm A",
  moment.ISO_8601,
];

function toManilaAppointmentDateTime(appointmentDate, appointmentTime) {
  // Strip ISO suffix from date if admin panel sends "2026-06-18T00:00:00.000"
  const cleanDate = (appointmentDate || "").toString().split("T")[0];
  // Strip any date prefix from time if it was accidentally included
  const cleanTime = (appointmentTime || "").toString().replace(/^\d{4}-\d{2}-\d{2}[T ]/, "").substring(0, 8);
  const rawDateTime = `${cleanDate} ${cleanTime}`.trim();
  const utcMoment = moment.utc(rawDateTime, APPOINTMENT_INPUT_FORMATS, true);
  const parsedMoment = utcMoment.isValid() ? utcMoment : moment.utc(rawDateTime);
  const manilaMoment = parsedMoment.isValid() ? parsedMoment.tz(MANILA_TZ) : null;

  return {
    utcIso: parsedMoment && parsedMoment.isValid() ? parsedMoment.toISOString() : null,
    display: manilaMoment && manilaMoment.isValid()
      ? manilaMoment.format("MMMM DD, YYYY hh:mm A")
      : `${cleanDate} ${cleanTime}`.trim(),
  };
}

function formatNotificationDateTimeParts(appointmentDate, appointmentTime) {
  const timeStrRaw = (appointmentTime || "").toString();
  const timeShort = timeStrRaw.length >= 5 ? timeStrRaw.substring(0, 8) : timeStrRaw;
  const raw = `${appointmentDate || ""} ${timeShort}`.trim();
  const mManila = moment.tz(raw, APPOINTMENT_INPUT_FORMATS, true, MANILA_TZ);
  if (mManila.isValid()) {
    return { dateStr: mManila.format("MMM D, YYYY"), timeStr: mManila.format("h:mm A") };
  }
  const utc = moment.utc(raw, APPOINTMENT_INPUT_FORMATS, true);
  if (utc.isValid()) {
    const manila = utc.clone().tz(MANILA_TZ);
    return { dateStr: manila.format("MMM D, YYYY"), timeStr: manila.format("h:mm A") };
  }
  return {
    dateStr: String(appointmentDate || ""),
    timeStr: timeStrRaw,
  };
}

/** FCM + in-app row types for Health Tracking admin actions */
function buildTrackingStatusNotification(status, appt) {
  const typeLabel  = (appt.appointment_type || "Appointment").toString();
  const childName  = appt.patient_name || null;
  const childLabel = childName ? ` for ${childName}` : "";
  const { dateStr, timeStr } = formatNotificationDateTimeParts(
    appt.appointment_date,
    appt.appointment_time
  );
  if (status === "approved") {
    return {
      notificationType: "appointment_in_progress",
      fcmType: "appointment_in_progress",
      title: "Appointment In Progress",
      message: `Your ${typeLabel} appointment${childLabel} on ${dateStr} at ${timeStr} is now in progress. Please wait for your consultation.`,
    };
  }
  if (status === "completed") {
    return {
      notificationType: "appointment_completed",
      fcmType: "appointment_completed",
      title: "Appointment Completed",
      message: `Your ${typeLabel} appointment${childLabel} on ${dateStr} at ${timeStr} has been marked as completed. Thank you for attending!`,
    };
  }
  if (status === "no_show") {
    return {
      notificationType: "appointment_missed",
      fcmType: "appointment_missed",
      title: "Appointment Missed",
      message: `Your ${typeLabel} appointment${childLabel} on ${dateStr} at ${timeStr} was marked as missed. Please reschedule if needed.`,
    };
  }
  return null;
}

const fetchUpdatedAppointmentByIdSql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.doctor_name,
        a.clinic_hospital,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.status,
        a.completed_at,
        a.missed_at,
        a.notes,
        a.reminder_set,
        a.created_at,
        a.updated_at,
        a.linked_vaccine_schedule_id,
        a.linked_dose_number,
        a.linked_vaccine_name,
        a.linked_dose_label,
        a.vaccine_context,
        u.full_name as user_name,
        p.child_fullname as patient_name
      FROM appointments a
      LEFT JOIN users u ON a.user_id = u.id
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.id = ?
    `;

// Get all appointments (for admin)
exports.getAllAppointments = async (req, res) => {
  try {
    const sql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        a.status,
        a.completed_at,
        a.missed_at,
        a.notes,
        a.created_at,
        a.updated_at,
        a.linked_vaccine_schedule_id,
        a.linked_dose_number,
        a.linked_vaccine_name,
        a.linked_dose_label,
        a.vaccine_context,
        u.full_name as user_full_name,
        u.email as user_email,
        p.child_fullname as patient_full_name
      FROM appointments a
      LEFT JOIN users u ON a.user_id = u.id
      LEFT JOIN patients p ON a.patient_id = p.id
      ORDER BY a.appointment_date DESC, a.appointment_time DESC
    `;

    const [results] = await db.execute(sql);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch appointments",
    });
  }
};

// Get pending appointments count (for admin notifications)
exports.getPendingAppointmentsCount = async (req, res) => {
  try {
    const sql = `
      SELECT COUNT(*) as count
      FROM appointments
      WHERE status = 'pending'
    `;

    const [results] = await db.execute(sql);
    const count = results[0]?.count || 0;
    
    res.status(200).json({
      success: true,
      count: count,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch pending appointments count",
    });
  }
};

// Delete an appointment
exports.deleteAppointment = async (req, res) => {
  const { id } = req.params;

  if (!id) {
    return res.status(400).json({
      success: false,
      message: "Appointment ID is required",
    });
  }

  const connection = await db.getConnection();
  
  try {
    await connection.beginTransaction();

    // First, get the appointment details for notification (including child name)
    const getAppointmentSql = `
      SELECT a.id, a.user_id, a.doctor_name, a.clinic_hospital,
             a.appointment_date, a.appointment_time, a.appointment_type,
             p.child_fullname AS child_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.id = ?
    `;

    const [appointmentResults] = await connection.execute(getAppointmentSql, [id]);

    if (appointmentResults.length === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: "Appointment not found",
      });
    }

    const appointment = appointmentResults[0];

    // Delete related notifications first (foreign key constraint)
    const deleteNotificationsSql = "DELETE FROM appointment_notifications WHERE appointment_id = ?";
    await connection.execute(deleteNotificationsSql, [id]);

    // Now delete the appointment
    const deleteAppointmentSql = "DELETE FROM appointments WHERE id = ?";
    const [result] = await connection.execute(deleteAppointmentSql, [id]);

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: "Appointment not found",
      });
    }

    // Create notification for user about appointment deletion (includes child name)
    const childLabel = appointment.child_name ? ` for ${appointment.child_name}` : "";
    const notificationMessage = `Your appointment${childLabel} with Dr. ${appointment.doctor_name} at ${appointment.clinic_hospital} on ${appointment.appointment_date} at ${appointment.appointment_time} has been cancelled by the administrator.`;
    
    const createNotificationSql = `
      INSERT INTO appointment_notifications (appointment_id, user_id, notification_type, message, is_read, created_at, updated_at)
      VALUES (?, ?, 'appointment_update', ?, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `;

    try {
      await connection.execute(createNotificationSql, [id, appointment.user_id, notificationMessage]);
      // Also write to `notifications` table
      await connection.execute(
        `INSERT INTO notifications (user_id, appointment_id, notification_type, title, message, is_read)
         VALUES (?, ?, 'status_update', 'Appointment Cancelled', ?, 0)`,
        [appointment.user_id, id, notificationMessage]
      );
    } catch (notificationErr) {
      console.warn("⚠️ Warning: Failed to create notification for appointment deletion:", notificationErr);
      // Continue with commit even if notification fails
    }

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit('appointmentDeleted', { appointment_id: id });
    }

    // Commit the transaction
    await connection.commit();

    res.status(200).json({
      success: true,
      message: "Appointment deleted successfully",
      data: { appointment_id: id },
    });
  } catch (err) {
    await connection.rollback();
    console.error("❌ Database error:", err);
    res.status(500).json({
      success: false,
      message: "Failed to delete appointment",
    });
  } finally {
    connection.release();
  }
};

// Get appointments for a specific user
exports.getUserAppointments = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const sql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        a.status,
        a.completed_at,
        a.missed_at,
        a.notes,
        a.created_at,
        a.updated_at,
        a.linked_vaccine_schedule_id,
        a.linked_dose_number,
        a.linked_vaccine_name,
        a.linked_dose_label,
        a.vaccine_context,
        p.child_fullname as patient_full_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.user_id = ?
      ORDER BY a.appointment_date DESC, a.appointment_time DESC
    `;

    const [results] = await db.execute(sql, [userId]);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch user appointments",
    });
  }
};

// Get appointments for current authenticated user
exports.getCurrentUserAppointments = async (req, res) => {
  try {
    // For now, we'll use a query parameter or return an error
    // In a real implementation, this would use JWT auth middleware
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required as query parameter"
      });
    }

    console.log(`📅 Fetching appointments for current user: ${userId}`);

    const sql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        a.status,
        a.completed_at,
        a.missed_at,
        a.notes,
        a.created_at,
        a.updated_at,
        a.linked_vaccine_schedule_id,
        a.linked_dose_number,
        a.linked_vaccine_name,
        a.linked_dose_label,
        a.vaccine_context,
        p.child_fullname as patient_full_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.user_id = ?
      ORDER BY a.appointment_date ASC, a.appointment_time ASC
    `;

    const [results] = await db.execute(sql, [userId]);
    
    console.log(`✅ Found ${results.length} appointments for user ${userId}`);
    
    res.status(200).json({
      success: true,
      data: results,
      count: results.length
    });
  } catch (err) {
    console.error("❌ Database error fetching current user appointments:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch user appointments"
    });
  }
};

// Get upcoming approved appointments for a specific user (for dashboard)
exports.getUserUpcomingAppointments = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const sql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        a.status,
        a.notes,
        a.created_at,
        a.updated_at,
        p.child_fullname as patient_full_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.user_id = ? AND a.status = 'approved' AND a.appointment_date >= CURDATE()
      ORDER BY a.appointment_date ASC, a.appointment_time ASC
      LIMIT 5
    `;

    const [results] = await db.execute(sql, [userId]);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch user upcoming appointments",
    });
  }
};

// Add new appointment
exports.addAppointment = async (req, res) => {
  try {
    // Handle both camelCase and snake_case field names
    const {
      userId,
      user_id,
      patientId,
      patient_id,
      doctorName,
      doctor_name,
      clinicHospital,
      clinic_hospital,
      appointmentDate,
      appointment_date,
      appointmentTime,
      appointment_time,
      appointmentType,
      appointment_type,
      notes,
      status, // Accept status field but ignore it
      slotId, // New field for slot ID
      // ── Vaccine linkage (from Vaccine Card "Book Appointment") ──────────────
      linkedVaccineScheduleId,
      linked_vaccine_schedule_id,
      linkedDoseNumber,
      linked_dose_number,
      linkedVaccineName,
      linked_vaccine_name,
      linkedDoseLabel,
      linked_dose_label,
      vaccineContext,
      vaccine_context,
    } = req.body;

    // Normalise vaccine linkage (accept either camelCase or snake_case)
    const normalizedLinkedScheduleId  = linkedVaccineScheduleId  || linked_vaccine_schedule_id  || null;
    const normalizedLinkedDoseNumber  = linkedDoseNumber          || linked_dose_number          || null;
    const normalizedLinkedVaccineName = linkedVaccineName         || linked_vaccine_name         || null;
    const normalizedLinkedDoseLabel   = linkedDoseLabel           || linked_dose_label           || null;
    // vaccine_context: accept from frontend, or auto-build from name + label if not supplied
    const normalizedVaccineContext = vaccineContext || vaccine_context ||
      (normalizedLinkedVaccineName
        ? [normalizedLinkedVaccineName, normalizedLinkedDoseLabel].filter(Boolean).join(' · ')
        : null);

    // Normalize field names
    const normalizedUserId = userId || user_id;
    const normalizedPatientId = patientId || patient_id;
    const normalizedDoctorName = doctorName || doctor_name;
    const normalizedClinicHospital = clinicHospital || clinic_hospital || 'General Health Center';
    const normalizedAppointmentDate = appointmentDate || appointment_date;
    let normalizedAppointmentTime = appointmentTime || appointment_time;
    const normalizedAppointmentType = appointmentType || appointment_type;

    // Convert time format from 12-hour (10:00 AM) to 24-hour (10:00:00)
    if (normalizedAppointmentTime && normalizedAppointmentTime.includes(' ')) {
      const [time, period] = normalizedAppointmentTime.split(' ');
      const [hours, minutes] = time.split(':');
      let hour24 = parseInt(hours);
      
      if (period.toUpperCase() === 'PM' && hour24 !== 12) {
        hour24 += 12;
      } else if (period.toUpperCase() === 'AM' && hour24 === 12) {
        hour24 = 0;
      }
      
      normalizedAppointmentTime = `${hour24.toString().padStart(2, '0')}:${minutes}:00`;
    } else if (normalizedAppointmentTime && !normalizedAppointmentTime.includes(':')) {
      // If it's just a number like "10", convert to "10:00:00"
      normalizedAppointmentTime = `${normalizedAppointmentTime}:00:00`;
    } else if (normalizedAppointmentTime && normalizedAppointmentTime.split(':').length === 2) {
      // If it's HH:MM format, add seconds
      normalizedAppointmentTime = `${normalizedAppointmentTime}:00`;
    }

    // Validate required fields with detailed error messages
    const missingFields = [];
    if (!normalizedUserId) missingFields.push('User ID');
    if (!normalizedPatientId) missingFields.push('Patient ID');
    if (!normalizedDoctorName) missingFields.push('Doctor Name');
    if (!normalizedAppointmentDate) missingFields.push('Appointment Date');
    if (!normalizedAppointmentTime) missingFields.push('Appointment Time');
    if (!normalizedAppointmentType) missingFields.push('Appointment Type');

    if (missingFields.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Missing required fields: ${missingFields.join(', ')}`,
      });
    }

    // Validate date format (YYYY-MM-DD)
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(normalizedAppointmentDate)) {
      return res.status(400).json({
        success: false,
        message: "Invalid date format. Please use YYYY-MM-DD format",
      });
    }

    // Validate that the date is not in the past using string comparison
    // Get current date in YYYY-MM-DD format
    const today = new Date();
    const year = today.getFullYear();
    const month = (today.getMonth() + 1).toString().padStart(2, '0');
    const day = today.getDate().toString().padStart(2, '0');
    const todayStr = `${year}-${month}-${day}`;
    
    if (normalizedAppointmentDate < todayStr) {
      return res.status(400).json({
        success: false,
        message: "Appointment date cannot be in the past",
      });
    }

    // Define valid status values that match the database ENUM exactly
    const validStatuses = ['pending', 'scheduled', 'approved', 'completed', 'cancelled', 'rescheduled', 'no_show'];
    
    // ── Validate patient_id belongs to this user ────────────────────────────
    if (normalizedPatientId) {
      const [ownerCheck] = await db.execute(
        `SELECT id, child_fullname FROM patients WHERE id = ? AND user_id = ? LIMIT 1`,
        [normalizedPatientId, normalizedUserId]
      );
      if (ownerCheck.length === 0) {
        return res.status(400).json({
          success: false,
          message: "The selected child does not belong to this account.",
        });
      }
    }

    // ── ONE USER, ONE ACTIVE APPOINTMENT RULE ────────────────────────────────
    // Block the booking if the user already has an approved or rescheduled appointment.
    const [activeAppts] = await db.execute(
      `SELECT id, appointment_date, appointment_time, appointment_type
       FROM appointments
       WHERE user_id = ? AND status IN ('approved', 'rescheduled')
       ORDER BY appointment_date ASC, appointment_time ASC
       LIMIT 1`,
      [normalizedUserId]
    );
    if (activeAppts.length > 0) {
      const existing = activeAppts[0];
      // Format date/time for the error message
      const apptDate = existing.appointment_date
        ? new Date(existing.appointment_date).toLocaleDateString('en-US', {
            month: 'long', day: 'numeric', year: 'numeric'
          })
        : existing.appointment_date;
      const apptTime = existing.appointment_time
        ? existing.appointment_time.substring(0, 5)
        : '';
      return res.status(409).json({
        success: false,
        code: 'ACTIVE_APPOINTMENT_EXISTS',
        message: `Unable to book an appointment at this time because you already have an approved appointment scheduled on ${apptDate} at ${apptTime}. Please wait until your current appointment has been completed before creating a new booking request.`,
        existingAppointment: {
          id: existing.id,
          date: existing.appointment_date,
          time: existing.appointment_time,
          type: existing.appointment_type,
        },
      });
    }
    // ── END RESTRICTION ──────────────────────────────────────────────────────

    // Automatically approve all appointments by default
    let initialStatus = 'approved';
    
    // If slotId is provided, validate the slot
    if (slotId) {
      // Validate the slot using the correct column names
      const slotValidationSql = `
        SELECT s.*, sc.service_name
        FROM appointment_slots s
        LEFT JOIN services_config sc ON s.service_id = sc.id
        WHERE s.id = ? AND s.is_available = 1 AND s.booked_count < s.capacity
        AND s.slot_date = ?
      `;
      
      const [slotResults] = await db.execute(slotValidationSql, [slotId, normalizedAppointmentDate]);
      
      if (slotResults.length === 0) {
        return res.status(409).json({
          success: false,
          code: 'SLOT_UNAVAILABLE',
          message: "This appointment slot is already booked. Please choose another available slot.",
        });
      }
    }
    
    // Validate the status and default to 'approved' if invalid
    if (!validStatuses.includes(initialStatus)) {
      initialStatus = 'approved';
    }
    
    const sql = `
      INSERT INTO appointments (
        user_id, patient_id, doctor_name, clinic_hospital, appointment_date, 
        appointment_time, appointment_type, notes, status,
        linked_vaccine_schedule_id, linked_dose_number,
        linked_vaccine_name, linked_dose_label, vaccine_context
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
      normalizedUserId,
      normalizedPatientId,
      normalizedDoctorName,
      normalizedClinicHospital,
      normalizedAppointmentDate,
      normalizedAppointmentTime,
      normalizedAppointmentType,
      notes || '',
      initialStatus,
      normalizedLinkedScheduleId  || null,
      normalizedLinkedDoseNumber  || null,
      normalizedLinkedVaccineName || null,
      normalizedLinkedDoseLabel   || null,
      normalizedVaccineContext    || null,
    ];

    const [result] = await db.execute(sql, values);
    
    const appointmentId = result.insertId;
    console.log("✅ Appointment added successfully with ID:", appointmentId);

    // If slot was booked and appointment is approved, send confirmation notification
    if (slotId && initialStatus === 'approved') {
      try {
        const bookSlotSql = `
          UPDATE appointment_slots 
          SET booked_patients = booked_patients + 1,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `;
        
        await db.execute(bookSlotSql, [slotId]);
        console.log("✅ Slot booked successfully for appointment ID:", appointmentId);
        
        // Send real-time confirmation notification
        await sendAppointmentConfirmationNotification(appointmentId);
        console.log("✅ Appointment confirmation notification sent for appointment ID:", appointmentId);
      } catch (slotErr) {
        console.warn("⚠️ Warning: Failed to book slot for appointment ID:", appointmentId, slotErr);
        // Continue with appointment creation even if slot booking fails
      }
    }

    // Emit real-time update
    if (req.app.locals.io) {
      req.app.locals.io.emit('appointmentAdded', { appointment_id: appointmentId });
    }

    // Fetch the created appointment data
    const fetchSql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.doctor_name,
        a.clinic_hospital,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.status,
        a.notes,
        a.created_at,
        a.updated_at,
        u.full_name as user_name,
        p.child_fullname as patient_name
      FROM appointments a
      LEFT JOIN users u ON a.user_id = u.id
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.id = ?
    `;

    const [fetchResults] = await db.execute(fetchSql, [appointmentId]);
    
    // If the appointment was automatically approved, send notification
    if (initialStatus === 'approved') {
      // Fetch child name from the already-retrieved appointment data
      const childName = fetchResults[0]?.patient_name || null;
      const childLabel = childName ? ` for ${childName}` : "";

      // Create notification for the user (includes child name)
      const notificationMessage = `Your appointment${childLabel} on ${normalizedAppointmentDate} at ${normalizedAppointmentTime} has been confirmed.`;
      
      const notificationSql = `
        INSERT INTO appointment_notifications (
          appointment_id, user_id, notification_type, message, is_read
        ) VALUES (?, ?, 'status_update', ?, 0)
      `;
      
      try {
        await db.execute(notificationSql, [appointmentId, normalizedUserId, notificationMessage]);
        console.log("✅ Notification created for approved appointment ID:", appointmentId);
      } catch (notifErr) {
        console.warn("⚠️ Warning: Failed to create notification for approved appointment ID:", appointmentId, notifErr);
        // Continue even if notification fails
      }

      // Also write to the `notifications` table (read by the app's Notifications tab)
      try {
        await db.execute(
          `INSERT INTO notifications (user_id, appointment_id, notification_type, title, message, is_read)
           VALUES (?, ?, 'status_update', 'Appointment Confirmed', ?, 0)`,
          [normalizedUserId, appointmentId, notificationMessage]
        );
        console.log("✅ notifications row created for approved appointment ID:", appointmentId);
      } catch (notifErr) {
        console.warn("⚠️ Warning: Failed to create notifications row for appointment ID:", appointmentId, notifErr);
      }
      
      // Emit real-time update with notification data
      if (req.app.locals.io) {
        // Emit to the specific user room
        req.app.locals.io.to(`user_${normalizedUserId}`).emit('appointmentNotification', {
          appointment_id: appointmentId,
          user_id: normalizedUserId,
          notification_type: 'status_update',
          message: notificationMessage,
          is_read: false,
          created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
          status: 'approved',
          appointment_data: fetchResults[0]
        });
        
        // Also emit to the general appointment updates channel
        req.app.locals.io.emit('appointmentUpdated', { 
          appointment_id: appointmentId, 
          status: 'approved',
          data: fetchResults[0] 
        });
      }
      
      // Create reminder schedule for approved appointment
      try {
        const reminderResult = await createAppointmentReminderSchedule(
          appointmentId,
          normalizedAppointmentDate,
          normalizedAppointmentTime,
          normalizedUserId
        );
        if (reminderResult.success) {
          console.log(`✅ Reminder schedule created for appointment ${appointmentId}: ${reminderResult.remindersCreated || 0} reminders`);
        } else {
          console.warn(`⚠️ Failed to create reminder schedule for appointment ${appointmentId}: ${reminderResult.message}`);
        }
      } catch (reminderErr) {
        console.warn("⚠️ Warning: Failed to create reminder schedule for approved appointment ID:", appointmentId, reminderErr);
        // Continue even if reminder scheduling fails
      }
      
      // Send FCM push notification for auto-approved booking (deduped)
      await sendToUserDevices(
        normalizedUserId,
        "appointment_approved",
        "Appointment Approved",
        `Your appointment on ${normalizedAppointmentDate} ${normalizedAppointmentTime} is confirmed`,
        {
          appointmentId,
          status: "approved",
          appointmentDate: normalizedAppointmentDate,
          appointmentTime: normalizedAppointmentTime,
          source: "auto_approved",
        },
        `approval:${appointmentId}:${normalizedAppointmentDate}:${normalizedAppointmentTime}`
      );
    }

    res.status(201).json({
      success: true,
      message: initialStatus === 'approved' ? "Appointment booked and approved successfully" : "Appointment added successfully",
      data: fetchResults[0],
    });
  } catch (err) {
    console.error("❌ Database error adding appointment:", err);
    
    // Handle specific database errors
    let errorMessage = "Failed to add appointment. Please try again.";
    let statusCode = 500;
    
    if (err.code === 'ER_DATA_TOO_LONG' || err.code === 'ER_TRUNCATED_WRONG_VALUE') {
      errorMessage = "Invalid data format. Please check your input values.";
      statusCode = 400;
    } else if (err.code === 'ER_BAD_NULL_ERROR') {
      errorMessage = "Missing required information. Please fill in all required fields.";
      statusCode = 400;
    } else if (err.code === 'ER_DUP_ENTRY') {
      errorMessage = "This appointment already exists. Please choose a different date or time.";
      statusCode = 409;
    } else if (err.code === 'ER_NO_REFERENCED_ROW_2') {
      errorMessage = "Invalid user or patient information. Please check your profile.";
      statusCode = 400;
    } else if (err.sqlMessage && err.sqlMessage.includes("Data truncated for column 'status'")) {
      errorMessage = "Invalid appointment status. Please use one of the following: pending, scheduled, approved, completed, cancelled, rescheduled, or no_show.";
      statusCode = 400;
    } else if (err.sqlMessage) {
      // Include the actual SQL error message for debugging
      errorMessage = `Database error: ${err.sqlMessage}`;
      statusCode = 400;
    }
    
    return res.status(statusCode).json({
      success: false,
      message: errorMessage,
      error_code: err.code,
      error_type: "database_error"
    });
  }
};

// Update appointment status (admin function)
exports.updateAppointmentStatus = async (req, res) => {
  // Generate a unique request ID for logging
  const requestId = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  console.log(`[${requestId}] 🚀 Starting appointment status update request`);

  const { id } = req.params;
  const { status, notes, rescheduleDate, rescheduleTime } = req.body;

  console.log(`[${requestId}] 📥 Request parameters:`, { id, status, notes, rescheduleDate, rescheduleTime });

  // Validate required parameters
  if (!id) {
    console.warn(`[${requestId}] ⚠️ Missing appointment ID`);
    return res.status(400).json({
      success: false,
      message: "Appointment ID is required",
      requestId
    });
  }

  if (!status) {
    console.warn(`[${requestId}] ⚠️ Missing status`);
    return res.status(400).json({
      success: false,
      message: "Status is required",
      requestId
    });
  }

  // Validate status
  const validStatuses = ['scheduled', 'approved', 'completed', 'cancelled', 'rescheduled', 'no_show'];
  if (!validStatuses.includes(status)) {
    console.warn(`[${requestId}] ⚠️ Invalid status: ${status}`);
    return res.status(400).json({
      success: false,
      message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
      requestId
    });
  }

  // Validate reschedule data if applicable
  if (status === 'rescheduled' && (!rescheduleDate || !rescheduleTime)) {
    console.warn(`[${requestId}] ⚠️ Missing reschedule data`);
    return res.status(400).json({
      success: false,
      message: "Reschedule date and time are required for rescheduling",
      requestId
    });
  }

  const connection = await db.getConnection();
  
  try {
    await connection.beginTransaction();
    console.log(`[${requestId}] 📋 Transaction started successfully`);

    // First, get the current appointment data to validate and fetch user info
    const getAppointmentSql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.status as current_status,
        p.child_fullname as patient_name,
        u.full_name as user_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      LEFT JOIN users u ON a.user_id = u.id
      WHERE a.id = ?
      FOR UPDATE
    `;

    const [appointmentResults] = await connection.execute(getAppointmentSql, [id]);

    if (appointmentResults.length === 0) {
      await connection.rollback();
      console.warn(`[${requestId}] ⚠️ Appointment not found: ${id}`);
      return res.status(404).json({
        success: false,
        message: "Appointment not found",
        requestId
      });
    }

    const currentAppointment = appointmentResults[0];
    console.log(`[${requestId}] 📋 Current appointment data:`, {
      id: currentAppointment.id,
      current_status: currentAppointment.current_status,
      user_id: currentAppointment.user_id,
      patient_name: currentAppointment.patient_name
    });

    const requestedStatus = String(status || "").toLowerCase();
    const currentStatus = String(currentAppointment.current_status || "").toLowerCase();
    if (currentStatus === requestedStatus) {
      await connection.rollback();
      console.log(`[${requestId}] ✅ Idempotent: appointment ${id} already ${status}`);
      const [alreadyRows] = await db.execute(fetchUpdatedAppointmentByIdSql, [id]);
      const row = alreadyRows[0] || null;
      return res.status(200).json({
        success: true,
        message: "Status already set",
        data: row,
        requestId
      });
    }

    // Validate reschedule date if applicable
    if (status === 'rescheduled' && rescheduleDate && rescheduleTime) {
      // Get current date in YYYY-MM-DD format for string comparison
      const today = new Date();
      const year = today.getFullYear();
      const month = (today.getMonth() + 1).toString().padStart(2, '0');
      const day = today.getDate().toString().padStart(2, '0');
      const todayStr = `${year}-${month}-${day}`;
      
      if (rescheduleDate < todayStr) {
        await connection.rollback();
        console.warn(`[${requestId}] ⚠️ Reschedule date is in the past: ${rescheduleDate}`);
        return res.status(400).json({
          success: false,
          message: "Reschedule date cannot be in the past",
          requestId
        });
      }
    }

    // Prepare update query (sets UTC timestamps for terminal visit outcomes)
    let updateSql, updateValues;
    
    if (status === 'rescheduled' && rescheduleDate && rescheduleTime) {
      updateSql = `
        UPDATE appointments SET 
          status = ?, 
          appointment_date = ?, 
          appointment_time = ?,
          notes = CONCAT(IFNULL(notes, ''), ?, ?),
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      updateValues = [
        status,
        rescheduleDate,
        rescheduleTime,
        notes ? '\n' : '',
        notes || '',
        id
      ];
    } else if (status === 'completed') {
      updateSql = `
        UPDATE appointments SET 
          status = ?,
          completed_at = UTC_TIMESTAMP(),
          missed_at = NULL,
          notes = CONCAT(IFNULL(notes, ''), ?, ?),
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      updateValues = [
        status,
        notes ? '\n' : '',
        notes || '',
        id
      ];
    } else if (status === 'no_show') {
      updateSql = `
        UPDATE appointments SET 
          status = ?,
          missed_at = UTC_TIMESTAMP(),
          notes = CONCAT(IFNULL(notes, ''), ?, ?),
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      updateValues = [
        status,
        notes ? '\n' : '',
        notes || '',
        id
      ];
    } else {
      updateSql = `
        UPDATE appointments SET 
          status = ?,
          notes = CONCAT(IFNULL(notes, ''), ?, ?),
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      updateValues = [
        status,
        notes ? '\n' : '',
        notes || '',
        id
      ];
    }

    console.log(`[${requestId}] 📝 Executing update query:`, { sql: updateSql, values: updateValues });

    // Execute the update
    const [updateResult] = await connection.execute(updateSql, updateValues);

    if (updateResult.affectedRows === 0) {
      await connection.rollback();
      console.warn(`[${requestId}] ⚠️ No rows affected by update`);
      return res.status(404).json({
        success: false,
        message: "Appointment not found or already updated",
        requestId
      });
    }

    console.log(`[${requestId}] ✅ Appointment updated successfully`);

    const [updatedResults] = await connection.execute(fetchUpdatedAppointmentByIdSql, [id]);

    if (updatedResults.length === 0) {
      await connection.rollback();
      console.warn(`[${requestId}] ⚠️ Updated appointment not found`);
      return res.status(404).json({
        success: false,
        message: "Appointment updated but could not retrieve data",
        requestId
      });
    }

    const updatedAppointment = updatedResults[0];
    console.log(`[${requestId}] 📋 Updated appointment data fetched successfully`);

    const trackingNotif = buildTrackingStatusNotification(status, updatedAppointment);
    let insertedNotificationsId = null;

    // Include child name in all status notification messages
    const childName   = updatedAppointment.patient_name || null;
    const childLabel  = childName ? ` for ${childName}` : "";
    const { dateStr, timeStr } = formatNotificationDateTimeParts(
      updatedAppointment.appointment_date,
      updatedAppointment.appointment_time
    );

    let notificationMessage;
    switch (status) {
      case 'approved':
        notificationMessage = `Your appointment${childLabel} on ${dateStr} at ${timeStr} has been approved.`;
        break;
      case 'cancelled':
        notificationMessage = `Your appointment${childLabel} on ${dateStr} at ${timeStr} has been cancelled.`;
        break;
      case 'rescheduled': {
        const newDate = rescheduleDate || updatedAppointment.appointment_date;
        const newTime = rescheduleTime || updatedAppointment.appointment_time;
        const { dateStr: rdStr, timeStr: rtStr } = formatNotificationDateTimeParts(newDate, newTime);
        notificationMessage = `Your appointment${childLabel} has been rescheduled to ${rdStr} at ${rtStr}.`;
        break;
      }
      case 'completed':
        notificationMessage = `Your appointment${childLabel} on ${dateStr} at ${timeStr} has been completed. Thank you for attending!`;
        break;
      case 'no_show':
        notificationMessage = `Your appointment${childLabel} on ${dateStr} at ${timeStr} was marked as missed. Please contact the health center to reschedule.`;
        break;
      default:
        notificationMessage = `Your appointment${childLabel} status has been updated to ${status}.`;
    }

    if (notes && notes.trim() !== '') {
      notificationMessage += ` Notes: ${notes}`;
    }

    if (trackingNotif) {
      let inboxMessage = trackingNotif.message;
      if (notes && notes.trim() !== '') {
        inboxMessage += ` Notes: ${notes}`;
      }
      try {
        const insertNotifSql = `
          INSERT INTO notifications (
            user_id, appointment_id, notification_type, title, message, is_read
          ) VALUES (?, ?, ?, ?, ?, 0)
        `;
        const [insResult] = await connection.execute(insertNotifSql, [
          updatedAppointment.user_id,
          id,
          trackingNotif.notificationType,
          trackingNotif.title,
          inboxMessage,
        ]);
        insertedNotificationsId = insResult.insertId;
        console.log(`[${requestId}] ✅ notifications row id=${insertedNotificationsId}`);
      } catch (notifErr) {
        console.error(`[${requestId}] ❌ Failed to insert notifications row:`, notifErr);
      }
    } else {
      const notificationSql = `
      INSERT INTO appointment_notifications (
        appointment_id, user_id, notification_type, message, is_read
      ) VALUES (?, ?, 'status_update', ?, 0)
    `;
      const notificationValues = [
        id,
        updatedAppointment.user_id,
        notificationMessage,
      ];
      try {
        await connection.execute(notificationSql, notificationValues);
        console.log(`[${requestId}] ✅ appointment_notifications row created`);
      } catch (notifErr) {
        console.error(`[${requestId}] ❌ Failed to create appointment_notifications:`, notifErr);
      }

      // Also write to `notifications` table (read by the app's Notifications tab)
      try {
        await connection.execute(
          `INSERT INTO notifications (user_id, appointment_id, notification_type, title, message, is_read)
           VALUES (?, ?, 'status_update', 'Appointment Status Update', ?, 0)`,
          [updatedAppointment.user_id, id, notificationMessage]
        );
        console.log(`[${requestId}] ✅ notifications row created`);
      } catch (notifErr) {
        console.error(`[${requestId}] ❌ Failed to insert notifications row:`, notifErr);
      }
    }

    await connection.commit();
    console.log(`[${requestId}] 🎉 Transaction committed successfully`);
    console.log(`[${requestId}] 📊 Final response: success=true, appointment_id=${id}, status=${status}`);

    const manilaSchedule = toManilaAppointmentDateTime(
      updatedAppointment.appointment_date,
      updatedAppointment.appointment_time
    );

    if (req.app.locals.io) {
      if (trackingNotif && insertedNotificationsId) {
        const socketMessage = notes && notes.trim() !== ''
          ? `${trackingNotif.message} Notes: ${notes}`
          : trackingNotif.message;
        req.app.locals.io.to(`user_${updatedAppointment.user_id}`).emit('appointmentNotification', {
          id: insertedNotificationsId,
          appointment_id: id,
          user_id: updatedAppointment.user_id,
          notification_type: trackingNotif.notificationType,
          title: trackingNotif.title,
          message: socketMessage,
          is_read: false,
          created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
          status: status,
          appointment_data: updatedAppointment,
        });
      } else {
        req.app.locals.io.to(`user_${updatedAppointment.user_id}`).emit('appointmentNotification', {
          appointment_id: id,
          user_id: updatedAppointment.user_id,
          notification_type: 'status_update',
          message: notificationMessage,
          is_read: false,
          created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
          status: status,
          appointment_data: updatedAppointment,
        });
      }

      req.app.locals.io.emit('appointmentUpdated', {
        appointment_id: id,
        status: status,
        data: updatedAppointment,
      });

      console.log(`[${requestId}] 📡 Real-time notification emitted to user ${updatedAppointment.user_id}`);
    }

    try {
      if (status === 'approved') {
        try {
          const appointmentDate = rescheduleDate || updatedAppointment.appointment_date;
          const appointmentTime = rescheduleTime || updatedAppointment.appointment_time;
          await cancelAppointmentReminders(id, 'Appointment approved - rescheduling reminders');
          const reminderResult = await createAppointmentReminderSchedule(
            id,
            appointmentDate,
            appointmentTime,
            updatedAppointment.user_id
          );
          console.log(`[${requestId}] 📅 Reminder schedule result for appointment ID: ${id}`, reminderResult);
        } catch (reminderErr) {
          console.warn(`[${requestId}] ⚠️ Warning: Failed to create reminder schedule for appointment ID: ${id}`, reminderErr);
        }
      }

      if (status === 'completed' || status === 'no_show') {
        try {
          await cancelAppointmentReminders(
            id,
            status === 'completed' ? 'Appointment completed' : 'Appointment marked missed'
          );
        } catch (cancelErr) {
          console.warn(`[${requestId}] ⚠️ Warning: Failed to cancel reminders for appointment ID: ${id}`, cancelErr);
        }
      }

      if (trackingNotif) {
        let pushBody = trackingNotif.message;
        if (notes && notes.trim() !== '') {
          pushBody += ` Notes: ${notes}`;
        }
        await sendToUserDevices(
          updatedAppointment.user_id,
          trackingNotif.fcmType,
          trackingNotif.title,
          pushBody,
          {
            type: trackingNotif.fcmType,
            appointmentId: id,
            status: status,
            appointmentDate: updatedAppointment.appointment_date,
            appointmentTime: updatedAppointment.appointment_time,
            appointmentTimestampUtc: manilaSchedule.utcIso || '',
            appointmentTimeDisplay: manilaSchedule.display,
            appointmentTimezone: MANILA_TZ,
          },
          `${trackingNotif.fcmType}:${id}`
        );
      } else {
        switch (status) {
          case 'cancelled':
            await sendCancellationAlert(id, notes || '');
            try {
              await cancelAppointmentReminders(id, 'Appointment cancelled');
            } catch (cancelErr) {
              console.warn(`[${requestId}] ⚠️ Warning: Failed to cancel reminders for appointment ID: ${id}`, cancelErr);
            }
            break;
          case 'rescheduled':
            if (rescheduleDate && rescheduleTime) {
              const rs = toManilaAppointmentDateTime(rescheduleDate, rescheduleTime);
              await sendToUserDevices(
                updatedAppointment.user_id,
                'appointment_rescheduled',
                'Appointment Rescheduled',
                `Your appointment has been moved to ${rs.display}.`,
                {
                  appointmentId: id,
                  status: 'rescheduled',
                  appointmentDate: rescheduleDate,
                  appointmentTime: rescheduleTime,
                  appointmentTimestampUtc: rs.utcIso || '',
                  appointmentTimeDisplay: rs.display,
                  appointmentTimezone: MANILA_TZ,
                },
                `reschedule:${id}:${rescheduleDate}:${rescheduleTime}`
              );
              try {
                await cancelAppointmentReminders(id, 'Appointment rescheduled - rescheduling reminders');
                const reminderResult = await createAppointmentReminderSchedule(
                  id,
                  rescheduleDate,
                  rescheduleTime,
                  updatedAppointment.user_id
                );
                console.log(`[${requestId}] 📅 Reminder schedule result for rescheduled appointment ID: ${id}`, reminderResult);
              } catch (reminderErr) {
                console.warn(`[${requestId}] ⚠️ Warning: Failed to reschedule reminders for appointment ID: ${id}`, reminderErr);
              }
            } else {
              await sendAppointmentStatusNotification(
                updatedAppointment.user_id,
                id,
                status,
                notificationMessage
              );
            }
            break;
          default:
            await sendAppointmentStatusNotification(
              updatedAppointment.user_id,
              id,
              status,
              notificationMessage
            );
        }
      }
    } catch (postErr) {
      console.warn(`[${requestId}] ⚠️ Post-commit notifications/FCM:`, postErr.message || postErr);
    }

    // Send success response
    res.status(200).json({
      success: true,
      message: `Appointment ${status} successfully`,
      data: updatedAppointment,
      requestId
    });
  } catch (err) {
    await connection.rollback();
    console.error(`[${requestId}] ❌ Transaction failed:`, err);
    res.status(500).json({
      success: false,
      message: "Failed to update appointment",
      requestId
    });
  } finally {
    connection.release();
  }
};

// Get appointment notifications for a user
exports.getUserNotifications = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const sql = `
      SELECT 
        id,
        appointment_id,
        user_id,
        notification_type,
        message,
        is_read,
        created_at
      FROM appointment_notifications
      WHERE user_id = ?
      ORDER BY created_at DESC
    `;

    const [results] = await db.execute(sql, [userId]);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch notifications",
    });
  }
};

// Get consultation types
exports.getConsultationTypes = async (req, res) => {
  try {
    const sql = `
      SELECT id, type_name, description
      FROM consultation_types
      WHERE is_active = 1
      ORDER BY type_name ASC
    `;

    const [results] = await db.execute(sql);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch consultation types",
    });
  }
};

// Mark notification as read
exports.markNotificationAsRead = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Notification ID is required",
      });
    }

    const sql = `
      UPDATE appointment_notifications SET 
        is_read = 1,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `;

    const [result] = await db.execute(sql, [id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Notification not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Notification marked as read",
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to update notification",
    });
  }
};

// Get unread notifications count for a user
exports.getUnreadNotificationsCount = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const sql = `
      SELECT COUNT(*) as count
      FROM appointment_notifications
      WHERE user_id = ? AND is_read = 0
    `;

    const [results] = await db.execute(sql, [userId]);
    const count = results[0]?.count || 0;
    
    res.status(200).json({
      success: true,
      count: count,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch unread notifications count",
    });
  }
};

// Get next appointment for a patient
exports.getNextAppointment = async (req, res) => {
  try {
    const { patientId } = req.params;

    if (!patientId) {
      return res.status(400).json({
        success: false,
        message: "Patient ID is required",
      });
    }

    const sql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        a.status,
        a.notes,
        a.created_at,
        a.updated_at,
        p.child_fullname as patient_full_name,
        p.service_type as patient_service_type
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.patient_id = ? AND a.appointment_date >= CURDATE()
      ORDER BY a.appointment_date ASC, a.appointment_time ASC
      LIMIT 1
    `;

    const [results] = await db.execute(sql, [patientId]);
    
    if (results.length === 0) {
      return res.status(200).json({
        success: true,
        data: null,
      });
    }
    
    res.status(200).json({
      success: true,
      data: results[0],
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch next appointment",
    });
  }
};

// Get all upcoming appointments (for admin dashboard)
exports.getUpcomingAppointments = async (req, res) => {
  try {
    const sql = `
      SELECT 
        a.id,
        a.user_id,
        a.patient_id,
        a.appointment_date,
        a.appointment_time,
        a.appointment_type,
        a.doctor_name,
        a.clinic_hospital,
        a.status,
        a.notes,
        a.created_at,
        a.updated_at,
        p.child_fullname as patient_full_name,
        p.service_type as patient_service_type
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.appointment_date >= CURDATE()
      ORDER BY a.appointment_date ASC, a.appointment_time ASC
      LIMIT 10
    `;

    const [results] = await db.execute(sql);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch upcoming appointments",
    });
  }
};

// ─── PUT /appointments/complete-with-dose/:id ─────────────────────────────────
/**
 * Atomically:
 *   1. Sets appointments.status = 'completed', completed_at = NOW()
 *   2. Inserts / upserts a child_vaccine_records row (marks the dose as given)
 *   3. Recomputes the NEXT dose scheduled_date (same logic as POST /vaccines/record)
 *   4. Releases the slot (decrements booked_count) if a slot_id exists
 *   5. Emits vaccineRecordUpdated + appointmentUpdated WebSocket events
 *   6. Cancels reminders and sends FCM push notification
 *
 * Body: {
 *   patient_id           : number   (required)
 *   vaccine_schedule_id  : number   (required)
 *   given_by?            : string
 *   notes?               : string
 *   given_at_override?   : string   "YYYY-MM-DD" — defaults to appointment_date
 * }
 */
exports.completeAppointmentWithDose = async (req, res) => {
  const { id } = req.params;
  const {
    patient_id,
    vaccine_schedule_id,
    given_by,
    notes,
    given_at_override,
  } = req.body;

  if (!id) {
    return res.status(400).json({ success: false, message: "Appointment ID is required" });
  }
  if (!patient_id || !vaccine_schedule_id) {
    return res.status(400).json({
      success: false,
      message: "patient_id and vaccine_schedule_id are required",
    });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // ── 1. Lock + fetch appointment ───────────────────────────────────────────
    const [apptRows] = await connection.execute(
      `SELECT a.id, a.user_id, a.patient_id, a.appointment_date, a.appointment_time,
              a.appointment_type, a.status, a.slot_id,
              p.child_fullname AS patient_name
       FROM appointments a
       LEFT JOIN patients p ON p.id = a.patient_id
       WHERE a.id = ? FOR UPDATE`,
      [id]
    );
    if (!apptRows.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: "Appointment not found" });
    }
    const appt = apptRows[0];

    if (appt.status === "completed") {
      await connection.rollback();
      return res.status(200).json({
        success: true,
        message: "Appointment already completed",
        data: appt,
      });
    }

    // ── 2. Mark appointment completed ─────────────────────────────────────────
    await connection.execute(
      `UPDATE appointments
          SET status       = 'completed',
              completed_at = UTC_TIMESTAMP(),
              updated_at   = CURRENT_TIMESTAMP
        WHERE id = ?`,
      [id]
    );

    // ── 3. Fetch vaccine schedule ─────────────────────────────────────────────
    const [scheds] = await connection.execute(
      `SELECT id, vaccine_key, dose_number, vaccine_name, dose_label,
              schedule_from, interval_days, due_days_from_birth
       FROM vaccine_schedules WHERE id = ? LIMIT 1`,
      [vaccine_schedule_id]
    );
    if (!scheds.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: "Vaccine schedule not found" });
    }
    const sched = scheds[0];

    // ── 4. Resolve given_at date ──────────────────────────────────────────────
    let givenAtValue;
    if (given_at_override) {
      const parsed = new Date(given_at_override);
      givenAtValue = isNaN(parsed.getTime()) ? new Date(appt.appointment_date) : parsed;
    } else {
      // Default to appointment date
      givenAtValue = appt.appointment_date
        ? new Date(appt.appointment_date)
        : new Date();
    }
    const givenAtISO  = givenAtValue.toISOString();   // kept for internal use only
    const givenAtDate = givenAtISO.split("T")[0];     // "YYYY-MM-DD" — used for DB inserts

    // ── 5. Fetch patient DOB for theoretical date ─────────────────────────────
    const [pts] = await connection.execute(
      "SELECT dob FROM patients WHERE id = ? LIMIT 1",
      [patient_id]
    );
    const dob = pts.length ? pts[0].dob : null;

    function addDays(base, days) {
      if (!base) return null;
      try {
        const d = new Date(base);
        if (isNaN(d.getTime())) return null;
        d.setDate(d.getDate() + days);
        return d.toISOString().split("T")[0];
      } catch { return null; }
    }
    const theorDate = addDays(dob, sched.due_days_from_birth);

    // ── 6. Upsert child_vaccine_records ──────────────────────────────────────
    await connection.execute(
      `INSERT INTO child_vaccine_records
         (patient_id, vaccine_schedule_id, given_at, given_by, notes,
          scheduled_date)
       VALUES (?, ?, ?, ?, ?, ?) AS new_row
       ON DUPLICATE KEY UPDATE
         given_at       = COALESCE(child_vaccine_records.given_at, new_row.given_at),
         given_by       = COALESCE(new_row.given_by, child_vaccine_records.given_by),
         notes          = COALESCE(new_row.notes, child_vaccine_records.notes),
         scheduled_date = COALESCE(new_row.scheduled_date, child_vaccine_records.scheduled_date),
         updated_at     = CURRENT_TIMESTAMP`,
      [
        patient_id,
        vaccine_schedule_id,
        givenAtDate,     // "YYYY-MM-DD" — matches the DATE column type
        given_by || null,
        notes    || null,
        theorDate || null,
      ]
    );

    // Fetch back the saved record for the response
    const [saved] = await connection.execute(
      `SELECT id AS record_id, given_at, given_by, scheduled_date
       FROM child_vaccine_records
       WHERE patient_id = ? AND vaccine_schedule_id = ? LIMIT 1`,
      [patient_id, vaccine_schedule_id]
    );
    const record = saved[0] || null;

    // ── 7. Recompute next dose scheduled_date ────────────────────────────────
    const [nextScheds] = await connection.execute(
      `SELECT id, interval_days, schedule_from, due_days_from_birth
       FROM vaccine_schedules
       WHERE vaccine_key = ? AND dose_number = ? LIMIT 1`,
      [sched.vaccine_key, sched.dose_number + 1]
    );
    let nextDueDateComputed = null;
    if (nextScheds.length) {
      const ns = nextScheds[0];
      nextDueDateComputed = ns.schedule_from === "previous_dose"
        ? addDays(givenAtDate, ns.interval_days)
        : addDays(dob, ns.interval_days);

      if (nextDueDateComputed) {
        await connection.execute(
          `INSERT INTO child_vaccine_records (patient_id, vaccine_schedule_id, scheduled_date)
           VALUES (?, ?, ?) AS new_row
           ON DUPLICATE KEY UPDATE
             scheduled_date = new_row.scheduled_date,
             updated_at     = CURRENT_TIMESTAMP`,
          [patient_id, ns.id, nextDueDateComputed]
        );
      }
    }

    // ── 8. Release slot (decrement booked_count) ─────────────────────────────
    if (appt.slot_id) {
      try {
        await connection.execute(
          `UPDATE appointment_slots
              SET booked_patients = GREATEST(0, booked_patients - 1),
                  updated_at      = CURRENT_TIMESTAMP
            WHERE id = ?`,
          [appt.slot_id]
        );
      } catch (slotErr) {
        console.warn("⚠️ completeWithDose: slot release failed (non-fatal):", slotErr.message);
      }
    }

    // ── 9. Write completion notification row ─────────────────────────────────
    const childLabel = appt.patient_name ? ` for ${appt.patient_name}` : "";
    const { dateStr, timeStr } = formatNotificationDateTimeParts(
      appt.appointment_date,
      appt.appointment_time
    );
    const completionMsg =
      `Your ${appt.appointment_type || "Immunization"} appointment${childLabel} ` +
      `on ${dateStr} at ${timeStr} has been completed. ` +
      `${sched.vaccine_name} (${sched.dose_label}) has been recorded.`;

    try {
      await connection.execute(
        `INSERT INTO notifications
           (user_id, appointment_id, notification_type, title, message, is_read)
         VALUES (?, ?, 'appointment_completed', 'Appointment Completed', ?, 0)`,
        [appt.user_id, id, completionMsg]
      );
    } catch (notifErr) {
      console.warn("⚠️ completeWithDose: notification insert failed:", notifErr.message);
    }

    await connection.commit();

    // ── 10. Post-commit: WebSocket + FCM + reminders ─────────────────────────
    const io = req.app.locals.io;
    if (io) {
      // Tell the patient their vaccine card has changed
      io.to(`user_${appt.user_id}`).emit("vaccineRecordUpdated", {
        type:                "vaccine_record_updated",
        patient_id:          patient_id,
        vaccine_schedule_id: vaccine_schedule_id,
        vaccine_name:        sched.vaccine_name,
        dose_label:          sched.dose_label,
        given_at:            record ? record.given_at : givenAtDate,
        given_by:            given_by || null,
        next_dose_due_date:  nextDueDateComputed,
        message: `${sched.vaccine_name} (${sched.dose_label}) has been marked as completed.`,
      });

      // Tell the admin appointment list to refresh
      io.emit("appointmentUpdated", {
        appointment_id: id,
        status: "completed",
      });

      // Send in-app notification to user
      io.to(`user_${appt.user_id}`).emit("appointmentNotification", {
        appointment_id:    id,
        user_id:           appt.user_id,
        notification_type: "appointment_completed",
        title:             "Appointment Completed",
        message:           completionMsg,
        is_read:           false,
        created_at:        new Date().toISOString().slice(0, 19).replace("T", " "),
        status:            "completed",
      });
    }

    // Cancel pending reminders (non-fatal)
    try {
      await cancelAppointmentReminders(id, "Appointment completed");
    } catch (_) {}

    // FCM push notification (non-fatal)
    try {
      const manilaSchedule = toManilaAppointmentDateTime(
        appt.appointment_date,
        appt.appointment_time
      );
      await sendToUserDevices(
        appt.user_id,
        "appointment_completed",
        "Appointment Completed",
        completionMsg,
        {
          type:                  "appointment_completed",
          appointmentId:         id,
          status:                "completed",
          appointmentDate:       appt.appointment_date,
          appointmentTime:       appt.appointment_time,
          appointmentTimestampUtc: manilaSchedule.utcIso || "",
          appointmentTimeDisplay:  manilaSchedule.display,
          appointmentTimezone:     MANILA_TZ,
          vaccineScheduleId:     String(vaccine_schedule_id),
          vaccineName:           sched.vaccine_name,
          doseLabel:             sched.dose_label,
          nextDoseDueDate:       nextDueDateComputed || "",
        },
        `appointment_completed:${id}`
      );
    } catch (fcmErr) {
      console.warn("⚠️ completeWithDose: FCM push failed (non-fatal):", fcmErr.message);
    }

    // Fetch final appointment row for response
    const [finalRows] = await db.execute(fetchUpdatedAppointmentByIdSql, [id]);

    const childName       = appt.patient_name || null;
    const vaccineContext  = `${sched.vaccine_name} (${sched.dose_label})`;
    const nextDueDateFmt  = nextDueDateComputed
      ? (() => {
          try {
            const d = new Date(nextDueDateComputed);
            return d.toLocaleDateString("en-PH", { month: "long", day: "numeric", year: "numeric" });
          } catch { return nextDueDateComputed; }
        })()
      : null;

    // Build a human-readable admin toast message
    const adminToastMsg = childName
      ? `✅ ${vaccineContext} marked as given for ${childName}.${nextDueDateFmt ? ` Next dose due ${nextDueDateFmt}.` : ""}`
      : `✅ ${vaccineContext} recorded and appointment completed.${nextDueDateFmt ? ` Next dose due ${nextDueDateFmt}.` : ""}`;

    return res.status(200).json({
      success: true,
      message: adminToastMsg,
      data: {
        appointment:      finalRows[0] || null,
        childName,
        vaccineContext,
        vaccineRecord: {
          record_id:           record ? record.record_id : null,
          vaccine_schedule_id: vaccine_schedule_id,
          vaccine_name:        sched.vaccine_name,
          dose_label:          sched.dose_label,
          given_at:            record ? record.given_at : givenAtDate,
          given_by:            given_by || null,
          scheduled_date:      record ? record.scheduled_date : theorDate,
          next_dose_due_date:  nextDueDateComputed,
          next_dose_due_date_formatted: nextDueDateFmt,
        },
      },
    });
  } catch (err) {
    await connection.rollback();
    console.error("❌ completeAppointmentWithDose error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to complete appointment with dose: " + (err.message || err),
    });
  } finally {
    connection.release();
  }
};
