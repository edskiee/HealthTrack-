const db = require('../config/db');

// ─── Column mapping (real DB schema):
//   slot_date             → the date of the slot        (was: appointment_date)
//   slot_time             → the start time of the slot  (was: start_time)
//   capacity              → max patients per slot        (was: max_patients)
//   booked_count          → how many booked             (was: booked_patients)
//   is_available          → 0/1 availability flag
//   slot_duration_minutes → minutes per slot (added in migration 001)
// ─────────────────────────────────────────────────────────────────────────────

// ─── Shared helper: format HH:MM:SS from total minutes ──────────────────────
function minutesToTimeStr(totalMinutes) {
  const h = Math.floor(totalMinutes / 60);
  const m = totalMinutes % 60;
  return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:00`;
}

// ─── Shared helper: write in-app notification rows + emit socket event ───────
// Returns the list of inserted notification ids.
async function dispatchBulkRescheduleNotifications(connection, {
  affectedAppointments,   // array of { id, user_id, appointment_type, old_date, old_time, new_date, new_time }
  serviceName,
  adminId,
  io,
}) {
  const notifIds = [];
  for (const appt of affectedAppointments) {
    const oldDateFmt = appt.old_date;
    const newDateFmt = appt.new_date;
    const oldTimeFmt = appt.old_time ? appt.old_time.substring(0,5) : '';
    const newTimeFmt = appt.new_time ? appt.new_time.substring(0,5) : '';

    const title   = 'Appointment Rescheduled';
    const message =
      `Your ${appt.appointment_type || serviceName} appointment has been rescheduled by the admin. ` +
      `Old date/time: ${oldDateFmt} at ${oldTimeFmt}. ` +
      `New date/time: ${newDateFmt} at ${newTimeFmt}. ` +
      `Please confirm or contact us if you need a different time.`;

    try {
      const [ins] = await connection.execute(
        `INSERT INTO notifications
           (user_id, appointment_id, notification_type, title, message, is_read, created_at, updated_at)
         VALUES (?, ?, 'appointment_rescheduled', ?, ?, 0, NOW(), NOW())`,
        [appt.user_id, appt.id, title, message]
      );
      notifIds.push(ins.insertId);

      // Also insert into legacy appointment_notifications for backward compat
      await connection.execute(
        `INSERT INTO appointment_notifications
           (appointment_id, user_id, notification_type, message, is_read, created_at, updated_at)
         VALUES (?, ?, 'appointment_rescheduled', ?, 0, NOW(), NOW())`,
        [appt.id, appt.user_id, message]
      );
    } catch (notifErr) {
      console.warn(`⚠️ dispatchBulkRescheduleNotifications: failed for appointment ${appt.id}:`, notifErr.message);
    }
  }

  // Write audit log entry
  if (adminId) {
    try {
      await connection.execute(
        `INSERT INTO audit_logs (admin_id, action, description, metadata, created_at)
         VALUES (?, 'bulk_slot_reschedule', ?, ?, NOW())`,
        [
          adminId,
          `Bulk rescheduled ${affectedAppointments.length} appointment(s) for service: ${serviceName}`,
          JSON.stringify({
            affected_count:  affectedAppointments.length,
            appointment_ids: affectedAppointments.map(a => a.id),
            service_name:    serviceName,
          }),
        ]
      );
    } catch (auditErr) {
      console.warn('⚠️ dispatchBulkRescheduleNotifications: audit log failed:', auditErr.message);
    }
  }

  // Emit per-user socket events (after transaction commits, called by caller)
  if (io) {
    for (const appt of affectedAppointments) {
      io.to(`user_${appt.user_id}`).emit('appointmentNotification', {
        appointment_id:    appt.id,
        user_id:           appt.user_id,
        notification_type: 'appointment_rescheduled',
        title: 'Appointment Rescheduled',
        message: `Your appointment has been rescheduled to ${appt.new_date} at ${appt.new_time ? appt.new_time.substring(0,5) : ''}. Please confirm or request a different time.`,
        is_read: false,
        created_at: new Date().toISOString(),
      });
    }
    // Broadcast slot change so all open admin calendars refresh
    io.emit('slotsUpdated', {
      action: 'date_rescheduled',
      timestamp: new Date().toISOString(),
    });
  }

  return notifIds;
}

// Helper: normalise a raw DB row to a consistent API shape
function normaliseSlot(row) {
  if (!row) return row;
  return {
    id:                    row.id,
    service_id:            row.service_id,
    service_name:          row.service_name,          // from JOIN (may be undefined)
    // expose under both names so the Flutter app keeps working regardless of which it reads
    appointment_date:      row.slot_date   ?? row.appointment_date,
    slot_date:             row.slot_date   ?? row.appointment_date,
    start_time:            row.slot_time   ?? row.start_time,
    slot_time:             row.slot_time   ?? row.start_time,
    end_time:              row.end_time    ?? null,    // not stored – kept for compatibility
    slot_duration_minutes: row.slot_duration_minutes ?? null,
    max_patients:          row.capacity    ?? row.max_patients,
    capacity:              row.capacity    ?? row.max_patients,
    booked_patients:       row.booked_count ?? row.booked_patients ?? 0,
    booked_count:          row.booked_count ?? row.booked_patients ?? 0,
    is_available:          row.is_available,
    is_user_available:     row.is_user_available ?? (row.is_available === 1 && (row.booked_count ?? row.booked_patients ?? 0) < (row.capacity ?? row.max_patients ?? 1) ? 1 : 0),
    available_spots:       row.available_spots   ?? Math.max(0, (row.capacity ?? row.max_patients ?? 1) - (row.booked_count ?? row.booked_patients ?? 0)),
    created_by:            row.created_by  ?? null,
    created_at:            row.created_at,
    updated_at:            row.updated_at,
  };
}

// ─── Get all appointment slots (admin) ───────────────────────────────────────
exports.getAllSlots = async (req, res) => {
  try {
    const { serviceId, date } = req.query;

    let sql = `
      SELECT
        s.id,
        s.service_id,
        sc.service_name,
        s.slot_date,
        s.slot_time,
        s.slot_duration_minutes,
        s.capacity,
        s.booked_count,
        s.is_available,
        s.created_by,
        s.created_at,
        s.updated_at
      FROM appointment_slots s
      LEFT JOIN services_config sc ON s.service_id = sc.id
      WHERE 1=1
    `;

    const params = [];

    if (serviceId) {
      sql += ' AND s.service_id = ?';
      params.push(serviceId);
    }

    if (date) {
      sql += ' AND s.slot_date = ?';
      params.push(date);
    }

    sql += ' ORDER BY s.slot_date ASC, s.slot_time ASC';

    const [results] = await db.execute(sql, params);

    res.status(200).json({
      success: true,
      data: results.map(normaliseSlot),
    });
  } catch (err) {
    console.error('❌ getAllSlots error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch appointment slots' });
  }
};

// ─── Get available slots for users ───────────────────────────────────────────
exports.getAvailableSlots = async (req, res) => {
  try {
    const { serviceId, date } = req.query;

    if (!serviceId || !date) {
      return res.status(400).json({ success: false, message: 'Service ID and date are required' });
    }

    const sql = `
      SELECT
        s.id,
        s.service_id,
        s.slot_date,
        s.slot_time,
        s.capacity,
        s.booked_count,
        s.is_available,
        (s.capacity - s.booked_count) AS available_spots
      FROM appointment_slots s
      WHERE s.service_id = ?
        AND s.slot_date = ?
        AND s.is_available = 1
        AND s.booked_count < s.capacity
      ORDER BY s.slot_time ASC
    `;

    const [results] = await db.execute(sql, [serviceId, date]);

    res.status(200).json({ success: true, data: results.map(normaliseSlot) });
  } catch (err) {
    console.error('❌ getAvailableSlots error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch available slots' });
  }
};

// ─── Get user-viewable slots (all slots with status) ─────────────────────────
exports.getUserViewableSlots = async (req, res) => {
  try {
    const { serviceId, date } = req.query;

    let sql = `
      SELECT
        s.id,
        s.service_id,
        s.slot_date,
        s.slot_time,
        s.capacity,
        s.booked_count,
        s.is_available,
        CASE
          WHEN s.is_available = 1 AND s.booked_count < s.capacity THEN 1
          ELSE 0
        END AS is_user_available,
        (s.capacity - s.booked_count) AS available_spots
      FROM appointment_slots s
      WHERE 1=1
    `;

    const params = [];

    if (serviceId) {
      sql += ' AND s.service_id = ?';
      params.push(serviceId);
    }

    if (date) {
      sql += ' AND s.slot_date = ?';
      params.push(date);
    }

    sql += ' ORDER BY s.slot_date ASC, s.slot_time ASC';

    const [results] = await db.execute(sql, params);

    res.status(200).json({ success: true, data: results.map(normaliseSlot) });
  } catch (err) {
    console.error('❌ getUserViewableSlots error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch slots' });
  }
};

// ─── Create / Generate appointment slots (admin) ──────────────────────────────
exports.createSlot = async (req, res) => {
  let connection;
  try {
    const {
      service_id,
      appointment_date,   // Flutter sends this name
      start_time,         // Flutter sends this name
      end_time,           // used only for bulk generation
      slot_duration_minutes = 30,
      max_patients = 1,
      generate_slots = false,
    } = req.body;

    // ── Basic validation ──────────────────────────────────────────────────────
    if (!service_id)       return res.status(400).json({ success: false, message: 'Service ID is required' });
    if (!appointment_date) return res.status(400).json({ success: false, message: 'Appointment date is required' });
    if (!start_time)       return res.status(400).json({ success: false, message: 'Start time is required' });

    const serviceId  = parseInt(service_id);
    const capacity   = parseInt(max_patients);
    const duration   = parseInt(slot_duration_minutes);

    if (isNaN(serviceId) || serviceId <= 0)
      return res.status(400).json({ success: false, message: 'Invalid service ID' });

    if (!/^\d{4}-\d{2}-\d{2}$/.test(appointment_date))
      return res.status(400).json({ success: false, message: 'Invalid date format. Expected YYYY-MM-DD' });

    if (!/^\d{2}:\d{2}(:\d{2})?$/.test(start_time))
      return res.status(400).json({ success: false, message: 'Invalid start time format. Expected HH:MM or HH:MM:SS' });

    if (isNaN(duration) || duration <= 0 || duration > 480)
      return res.status(400).json({ success: false, message: 'Slot duration must be 1–480 minutes' });

    if (isNaN(capacity) || capacity <= 0 || capacity > 100)
      return res.status(400).json({ success: false, message: 'Max patients must be 1–100' });

    // ── Service must exist and be enabled ────────────────────────────────────
    const [svcRows] = await db.execute(
      'SELECT id FROM services_config WHERE id = ? AND is_active = 1 AND is_enabled = 1',
      [serviceId]
    );
    if (svcRows.length === 0)
      return res.status(400).json({ success: false, message: `Service ${serviceId} not found or not enabled` });

    // ── Date must be today or future ─────────────────────────────────────────
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
    if (appointment_date < todayStr)
      return res.status(400).json({ success: false, message: 'Cannot create slots for past dates' });

    // ── Parse start time ─────────────────────────────────────────────────────
    const [startHours, startMinutes] = start_time.split(':').map(Number);
    const startTotalMinutes = startHours * 60 + startMinutes;

    if (startTotalMinutes < 8 * 60)
      return res.status(400).json({ success: false, message: 'Start time cannot be earlier than 8:00 AM' });

    // ── BULK GENERATION (generate_slots = true) ───────────────────────────────
    if (generate_slots) {
      if (!end_time)
        return res.status(400).json({ success: false, message: 'End time is required when generating slots' });

      if (!/^\d{2}:\d{2}(:\d{2})?$/.test(end_time))
        return res.status(400).json({ success: false, message: 'Invalid end time format. Expected HH:MM or HH:MM:SS' });

      const [endHours, endMinutes] = end_time.split(':').map(Number);
      const endTotalMinutes = endHours * 60 + endMinutes;

      if (startTotalMinutes >= endTotalMinutes)
        return res.status(400).json({ success: false, message: 'End time must be later than start time' });

      if (endTotalMinutes > 18 * 60)
        return res.status(400).json({ success: false, message: 'End time cannot be later than 6:00 PM' });

      const totalSlots = Math.floor((endTotalMinutes - startTotalMinutes) / duration);
      if (totalSlots <= 0)
        return res.status(400).json({ success: false, message: 'Time range is too short to generate any slots with the given duration' });

      connection = await db.getConnection();
      await connection.beginTransaction();

      try {
        // Check existing slot count for daily limit
        const [existingRows] = await connection.execute(
          'SELECT COUNT(*) AS count FROM appointment_slots WHERE service_id = ? AND slot_date = ?',
          [serviceId, appointment_date]
        );
        const existingCount = existingRows[0].count;

        if (existingCount + totalSlots > 100)
          return res.status(400).json({
            success: false,
            message: `Cannot generate: would exceed the daily limit of 100 slots (${existingCount} already exist)`,
          });

        let generatedCount = 0;
        let currentMin = startTotalMinutes;

        while (currentMin < endTotalMinutes) {
          const slotEndMin = currentMin + duration;
          if (slotEndMin > endTotalMinutes) break;

          const slotTime = `${String(Math.floor(currentMin / 60)).padStart(2,'0')}:${String(currentMin % 60).padStart(2,'0')}:00`;

          // Skip if a slot at this exact time already exists for this service/date
          const [dupRows] = await connection.execute(
            'SELECT COUNT(*) AS cnt FROM appointment_slots WHERE service_id = ? AND slot_date = ? AND slot_time = ?',
            [serviceId, appointment_date, slotTime]
          );

          if (dupRows[0].cnt === 0) {
            await connection.execute(
              `INSERT INTO appointment_slots (service_id, slot_date, slot_time, slot_duration_minutes, capacity, booked_count, is_available, created_at, updated_at)
               VALUES (?, ?, ?, ?, 1, 0, 1, NOW(), NOW())`,
              [serviceId, appointment_date, slotTime, duration]
            );
            generatedCount++;
          }

          currentMin = slotEndMin;
        }

        await connection.commit();

        // Return the freshly created slots
        const [createdSlots] = await db.execute(
          'SELECT * FROM appointment_slots WHERE service_id = ? AND slot_date = ? ORDER BY slot_time',
          [serviceId, appointment_date]
        );

        if (req.app.locals.io) {
          req.app.locals.io.emit('slotsUpdated', {
            action: 'bulk_created',
            slotIds: createdSlots.map(s => s.id),
            serviceId,
            date: appointment_date,
            count: generatedCount,
          });
        }

        return res.status(201).json({
          success: true,
          message: `${generatedCount} appointment slot(s) generated successfully`,
          data: createdSlots.map(normaliseSlot),
        });
      } catch (genError) {
        await connection.rollback();
        throw genError;
      }

    // ── SINGLE SLOT ───────────────────────────────────────────────────────────
    } else {
      const slotTime = `${String(startHours).padStart(2,'0')}:${String(startMinutes).padStart(2,'0')}:00`;

      connection = await db.getConnection();
      await connection.beginTransaction();

      try {
        // No duplicate at same service/date/time
        const [dupRows] = await connection.execute(
          'SELECT id FROM appointment_slots WHERE service_id = ? AND slot_date = ? AND slot_time = ?',
          [serviceId, appointment_date, slotTime]
        );
        if (dupRows.length > 0) {
          await connection.rollback();
          return res.status(409).json({ success: false, message: 'A slot at this time already exists' });
        }

        // Daily limit
        const [dailyRows] = await connection.execute(
          'SELECT COUNT(*) AS count FROM appointment_slots WHERE service_id = ? AND slot_date = ?',
          [serviceId, appointment_date]
        );
        if (dailyRows[0].count >= 100) {
          await connection.rollback();
          return res.status(429).json({ success: false, message: 'Daily slot limit (100) exceeded' });
        }

        const [result] = await connection.execute(
          `INSERT INTO appointment_slots (service_id, slot_date, slot_time, slot_duration_minutes, capacity, booked_count, is_available, created_at, updated_at)
           VALUES (?, ?, ?, ?, 1, 0, 1, NOW(), NOW())`,
          [serviceId, appointment_date, slotTime, duration]
        );

        const newSlotId = result.insertId;
        const [createdSlot] = await connection.execute(
          'SELECT * FROM appointment_slots WHERE id = ?',
          [newSlotId]
        );

        await connection.commit();

        if (req.app.locals.io) {
          req.app.locals.io.emit('slotsUpdated', { action: 'created', slotId: newSlotId, serviceId, date: appointment_date });
        }

        return res.status(201).json({
          success: true,
          message: 'Appointment slot created successfully',
          data: normaliseSlot(createdSlot[0]),
        });
      } catch (slotError) {
        await connection.rollback();
        throw slotError;
      }
    }
  } catch (err) {
    console.error('❌ createSlot error:', err);
    return res.status(500).json({ success: false, message: 'Failed to create appointment slot', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};

// ─── Delete single appointment slot (admin) — with cascade + notification ─────
exports.deleteSlot = async (req, res) => {
  let connection;
  try {
    const { id } = req.params;
    // admin_id may be passed as query param for audit logging
    const adminId = req.query.adminId || req.body?.adminId || null;

    connection = await db.getConnection();
    await connection.beginTransaction();

    // 1. Lock and fetch the slot
    const [slots] = await connection.execute(
      `SELECT id, service_id, slot_date, slot_time, slot_duration_minutes,
              capacity, booked_count
       FROM appointment_slots WHERE id = ? FOR UPDATE`,
      [id]
    );
    if (slots.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Appointment slot not found' });
    }
    const slot = slots[0];

    // 2. Find active appointments linked to this slot
    //    Try slot_id FK first; fall back to date+time match.
    let linkedAppointments = [];
    try {
      const [bySlotId] = await connection.execute(
        `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time,
                a.appointment_type, a.status,
                u.full_name AS user_name
         FROM appointments a
         LEFT JOIN users u ON a.user_id = u.id
         WHERE a.slot_id = ?
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        [id]
      );
      linkedAppointments = bySlotId;
    } catch (_) {}

    if (linkedAppointments.length === 0) {
      // Fall back: match by slot_date + slot_time
      const [byDateTime] = await connection.execute(
        `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time,
                a.appointment_type, a.status,
                u.full_name AS user_name
         FROM appointments a
         LEFT JOIN users u ON a.user_id = u.id
         WHERE a.appointment_date = ?
           AND TIME(a.appointment_time) = TIME(?)
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        [slot.slot_date, slot.slot_time]
      );
      linkedAppointments = byDateTime;
    }

    // 3. Cascade-cancel every linked appointment + send in-app notification
    const cancelledApptIds = [];
    for (const appt of linkedAppointments) {
      // Cancel the appointment
      await connection.execute(
        `UPDATE appointments
         SET status = 'cancelled', updated_at = NOW()
         WHERE id = ?`,
        [appt.id]
      );
      cancelledApptIds.push(appt.id);

      const slotDateStr = String(slot.slot_date).substring(0, 10);
      const slotTimeStr = String(slot.slot_time).substring(0, 5);
      const title   = 'Appointment Slot Cancelled';
      const message =
        `Your ${appt.appointment_type || 'appointment'} appointment slot on ` +
        `${slotDateStr} at ${slotTimeStr} has been removed by the admin. ` +
        `Your booking has been cancelled. Please contact us to reschedule.`;

      // Write to notifications table
      try {
        await connection.execute(
          `INSERT INTO notifications
             (user_id, appointment_id, notification_type, title, message, is_read, created_at, updated_at)
           VALUES (?, ?, 'appointment_cancelled', ?, ?, 0, NOW(), NOW())`,
          [appt.user_id, appt.id, title, message]
        );
      } catch (notifErr) {
        console.warn(`⚠️ deleteSlot: notification insert failed for appt ${appt.id}:`, notifErr.message);
      }

      // Write to legacy appointment_notifications table
      try {
        await connection.execute(
          `INSERT INTO appointment_notifications
             (appointment_id, user_id, notification_type, message, is_read, created_at, updated_at)
           VALUES (?, ?, 'appointment_cancellation', ?, 0, NOW(), NOW())`,
          [appt.id, appt.user_id, message]
        );
      } catch (_) {}
    }

    // 4. Hard-delete the slot
    await connection.execute('DELETE FROM appointment_slots WHERE id = ?', [id]);

    // 5. Write audit log
    try {
      await connection.execute(
        `INSERT INTO audit_logs (admin_id, action, description, metadata, created_at)
         VALUES (?, 'delete_slot', ?, ?, NOW())`,
        [
          adminId,
          `Deleted slot id=${id} (${String(slot.slot_date).substring(0,10)} ${String(slot.slot_time).substring(0,5)}) ` +
          `for service_id=${slot.service_id}. Cancelled ${cancelledApptIds.length} appointment(s).`,
          JSON.stringify({
            slot_id:           parseInt(id),
            service_id:        slot.service_id,
            slot_date:         String(slot.slot_date).substring(0, 10),
            slot_time:         String(slot.slot_time).substring(0, 5),
            cancelled_appt_ids: cancelledApptIds,
          }),
        ]
      );
    } catch (auditErr) {
      console.warn('⚠️ deleteSlot: audit log failed:', auditErr.message);
    }

    await connection.commit();

    // 6. Emit real-time events after commit
    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', {
        action:    'deleted',
        slotId:    id,
        serviceId: slot.service_id,
        date:      String(slot.slot_date).substring(0, 10),
        cancelledAppointments: cancelledApptIds.length,
        timestamp: new Date().toISOString(),
      });

      // Notify each affected patient via their personal room
      for (const appt of linkedAppointments) {
        const slotDateStr = String(slot.slot_date).substring(0, 10);
        const slotTimeStr = String(slot.slot_time).substring(0, 5);
        req.app.locals.io.to(`user_${appt.user_id}`).emit('appointmentNotification', {
          appointment_id:    appt.id,
          user_id:           appt.user_id,
          notification_type: 'appointment_cancelled',
          title:  'Appointment Slot Cancelled',
          message: `Your appointment on ${slotDateStr} at ${slotTimeStr} has been cancelled. Please contact us to reschedule.`,
          is_read:    false,
          created_at: new Date().toISOString(),
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: cancelledApptIds.length > 0
        ? `Slot deleted. ${cancelledApptIds.length} linked appointment(s) cancelled and patient(s) notified.`
        : 'Appointment slot deleted successfully.',
      data: {
        slotId:              parseInt(id),
        cancelledApptIds,
        appointmentsCancelled: cancelledApptIds.length,
      },
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('❌ deleteSlot error:', err);
    return res.status(500).json({ success: false, message: 'Failed to delete appointment slot', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};

// ─── Check bookings for a slot (admin — pre-delete preview) ──────────────────
// GET /appointment-slots/:id/bookings
exports.getSlotBookings = async (req, res) => {
  try {
    const { id } = req.params;

    const [slots] = await db.execute(
      'SELECT id, service_id, slot_date, slot_time, booked_count FROM appointment_slots WHERE id = ?',
      [id]
    );
    if (slots.length === 0)
      return res.status(404).json({ success: false, message: 'Slot not found' });

    const slot = slots[0];

    // Try slot_id FK first, then date+time fallback
    let appointments = [];
    try {
      const [bySlotId] = await db.execute(
        `SELECT a.id, a.user_id, a.appointment_type, a.status,
                u.full_name AS patient_name
         FROM appointments a
         LEFT JOIN users u ON a.user_id = u.id
         WHERE a.slot_id = ? AND a.status NOT IN ('cancelled','completed','no_show')`,
        [id]
      );
      appointments = bySlotId;
    } catch (_) {}

    if (appointments.length === 0) {
      const [byDT] = await db.execute(
        `SELECT a.id, a.user_id, a.appointment_type, a.status,
                u.full_name AS patient_name
         FROM appointments a
         LEFT JOIN users u ON a.user_id = u.id
         WHERE a.appointment_date = ? AND TIME(a.appointment_time) = TIME(?)
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        [slot.slot_date, slot.slot_time]
      );
      appointments = byDT;
    }

    return res.status(200).json({
      success: true,
      data: {
        slot_id:      parseInt(id),
        slot_date:    String(slot.slot_date).substring(0, 10),
        slot_time:    String(slot.slot_time).substring(0, 5),
        booked_count: slot.booked_count,
        appointments: appointments.map(a => ({
          id:               a.id,
          patient_name:     a.patient_name || 'Unknown',
          appointment_type: a.appointment_type,
          status:           a.status,
        })),
      },
    });
  } catch (err) {
    console.error('❌ getSlotBookings error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch slot bookings' });
  }
};
exports.updateSlot = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      service_id,
      appointment_date, slot_date,  // accept both names
      start_time, slot_time,         // accept both names
      max_patients, capacity,        // accept both names
      is_available,
    } = req.body;

    const resolvedDate     = slot_date     ?? appointment_date;
    const resolvedTime     = slot_time     ?? start_time;
    const resolvedCapacity = capacity      ?? max_patients;

    const updates = [];
    const params  = [];

    if (service_id      !== undefined) { updates.push('service_id = ?');  params.push(service_id); }
    if (resolvedDate    !== undefined) { updates.push('slot_date = ?');   params.push(resolvedDate); }
    if (resolvedTime    !== undefined) { updates.push('slot_time = ?');   params.push(resolvedTime); }
    if (resolvedCapacity !== undefined){ updates.push('capacity = ?');    params.push(resolvedCapacity); }
    if (is_available    !== undefined) { updates.push('is_available = ?');params.push(is_available); }

    if (updates.length === 0)
      return res.status(400).json({ success: false, message: 'No valid fields provided for update' });

    params.push(id);
    const [result] = await db.execute(
      `UPDATE appointment_slots SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      params
    );

    if (result.affectedRows === 0)
      return res.status(404).json({ success: false, message: 'Appointment slot not found' });

    const [updatedSlot] = await db.execute('SELECT * FROM appointment_slots WHERE id = ?', [id]);

    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', {
        action: 'updated',
        slotId: id,
        serviceId: updatedSlot[0].service_id,
        date: updatedSlot[0].slot_date,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Appointment slot updated successfully',
      data: normaliseSlot(updatedSlot[0]),
    });
  } catch (err) {
    console.error('❌ updateSlot error:', err);
    return res.status(500).json({ success: false, message: 'Failed to update appointment slot' });
  }
};

// ─── Book a slot (user) ───────────────────────────────────────────────────────
exports.bookSlot = async (req, res) => {
  let connection;
  try {
    const { slotId } = req.body;
    if (!slotId) return res.status(400).json({ success: false, message: 'Slot ID is required' });

    connection = await db.getConnection();
    await connection.beginTransaction();

    try {
      // Lock the row
      const [slots] = await connection.execute(
        'SELECT * FROM appointment_slots WHERE id = ? FOR UPDATE',
        [slotId]
      );
      if (slots.length === 0) {
        await connection.rollback();
        return res.status(404).json({ success: false, message: 'Appointment slot not found' });
      }

      const slot = slots[0];
      const isAvailable = slot.is_available === 1 && slot.booked_count < slot.capacity;

      if (!isAvailable) {
        await connection.rollback();
        return res.status(409).json({ success: false, message: 'This appointment slot is already booked. Please choose another available slot.' });
      }

      // Atomic increment
      const [upd] = await connection.execute(
        'UPDATE appointment_slots SET booked_count = booked_count + 1 WHERE id = ? AND booked_count < capacity',
        [slotId]
      );
      if (upd.affectedRows === 0) {
        await connection.rollback();
        return res.status(409).json({ success: false, message: 'This appointment slot is already booked. Please choose another available slot.' });
      }

      // Mark unavailable if now full
      const newBooked = slot.booked_count + 1;
      if (newBooked >= slot.capacity) {
        await connection.execute('UPDATE appointment_slots SET is_available = 0 WHERE id = ?', [slotId]);
      }

      await connection.commit();

      const remainingSpots = slot.capacity - newBooked;

      if (req.app.locals.io) {
        req.app.locals.io.emit('slotsUpdated', {
          action: 'booked',
          slotId,
          serviceId: slot.service_id,
          date: slot.slot_date,
          remainingSpots,
          isFullyBooked: newBooked >= slot.capacity,
          timestamp: new Date().toISOString(),
        });
      }

      res.status(200).json({
        success: true,
        message: 'Slot booked successfully',
        data: { slotId, remainingSpots, isFullyBooked: newBooked >= slot.capacity },
      });
    } catch (err) {
      await connection.rollback();
      throw err;
    }
  } catch (err) {
    console.error('❌ bookSlot error:', err);
    return res.status(500).json({ success: false, message: 'Failed to book appointment slot', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};

// ─── Monthly availability (user calendar) ────────────────────────────────────
exports.getSlotsAvailabilityForMonth = async (req, res) => {
  try {
    const { serviceId, year, month } = req.query;

    if (!serviceId || !year || !month)
      return res.status(400).json({ success: false, message: 'Service ID, year, and month are required' });

    const yearNum  = parseInt(year);
    const monthNum = parseInt(month);

    if (isNaN(yearNum) || isNaN(monthNum) || monthNum < 1 || monthNum > 12)
      return res.status(400).json({ success: false, message: 'Invalid year or month' });

    const firstDay = `${yearNum}-${String(monthNum).padStart(2,'0')}-01`;
    const lastDay  = `${yearNum}-${String(monthNum).padStart(2,'0')}-31`;

    const sql = `
      SELECT
        slot_date AS appointment_date,
        COUNT(*) AS total_slots,
        SUM(CASE WHEN is_available = 1 AND booked_count < capacity THEN 1 ELSE 0 END) AS available_slots,
        SUM(CASE WHEN is_available = 1 AND booked_count >= capacity THEN 1 ELSE 0 END) AS fully_booked_slots,
        SUM(CASE WHEN is_available = 0 THEN 1 ELSE 0 END) AS unavailable_slots,
        SUM(booked_count) AS total_booked_patients,
        SUM(capacity)     AS total_max_patients,
        CASE
          WHEN SUM(CASE WHEN is_available = 1 AND booked_count < capacity THEN 1 ELSE 0 END) > 0 THEN 'available'
          WHEN SUM(CASE WHEN is_available = 1 AND booked_count >= capacity THEN 1 ELSE 0 END) > 0 THEN 'fully_booked'
          ELSE 'unavailable'
        END AS day_status
      FROM appointment_slots
      WHERE service_id = ?
        AND slot_date >= ?
        AND slot_date <= ?
      GROUP BY slot_date
      ORDER BY slot_date ASC
    `;

    const [results] = await db.execute(sql, [serviceId, firstDay, lastDay]);

    res.status(200).json({
      success: true,
      data: results,
      summary: {
        total_days_with_slots:  results.length,
        available_days:         results.filter(r => r.day_status === 'available').length,
        fully_booked_days:      results.filter(r => r.day_status === 'fully_booked').length,
        unavailable_days:       results.filter(r => r.day_status === 'unavailable').length,
      },
    });
  } catch (err) {
    console.error('❌ getSlotsAvailabilityForMonth error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch monthly availability' });
  }
};

// ─── Delete all / filtered slots (admin) — with cascade + notifications ───────
// DELETE /appointment-slots?serviceId=&date=&adminId=
//
// Mirrors the quality of deleteSlot() but applied to every slot matching the
// filter in a single DB transaction:
//   1. Lock + fetch all matching slots
//   2. Find every active appointment across those slots (slot_id FK + date/time fallback)
//   3. Cancel each appointment + write in-app notification (notifications + legacy table)
//   4. Hard-delete all slot rows
//   5. Write a single bulk audit log entry
//   6. Commit — then emit socket events per-patient + broadcast slotsUpdated
exports.deleteAllSlots = async (req, res) => {
  let connection;
  try {
    // adminId may be passed as query param for audit logging
    const { serviceId, date, adminId } = req.query;

    connection = await db.getConnection();
    await connection.beginTransaction();

    // ── 1. Lock + fetch all matching slots ─────────────────────────────────
    let whereClause = 'WHERE 1=1';
    const filterParams = [];
    if (serviceId) { whereClause += ' AND service_id = ?'; filterParams.push(serviceId); }
    if (date)      { whereClause += ' AND slot_date = ?';  filterParams.push(date); }

    const [slotsToDelete] = await connection.execute(
      `SELECT id, service_id, slot_date, slot_time, capacity, booked_count
       FROM appointment_slots ${whereClause} FOR UPDATE`,
      filterParams
    );

    if (slotsToDelete.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'No appointment slots found matching the criteria' });
    }

    const slotIds        = slotsToDelete.map(s => s.id);
    const placeholders   = slotIds.map(() => '?').join(',');

    // ── 2. Find all active appointments across these slots ──────────────────
    // Try slot_id FK first; fall back to date+time match per-slot.
    let linkedAppointments = [];

    try {
      const [bySlotId] = await connection.execute(
        `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time,
                a.appointment_type, a.status,
                u.full_name AS user_name
         FROM appointments a
         LEFT JOIN users u ON a.user_id = u.id
         WHERE a.slot_id IN (${placeholders})
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        slotIds
      );
      linkedAppointments = bySlotId;
    } catch (_) {
      // slot_id column not present — use date/time fallback below
    }

    if (linkedAppointments.length === 0 && slotsToDelete.some(s => s.booked_count > 0)) {
      // Build a date+time OR clause to catch all booked slots in one query
      const dtPairs = slotsToDelete
        .filter(s => s.booked_count > 0)
        .map(s => `(a.appointment_date = ? AND TIME(a.appointment_time) = TIME(?))`)
        .join(' OR ');

      if (dtPairs) {
        const dtParams = [];
        slotsToDelete
          .filter(s => s.booked_count > 0)
          .forEach(s => {
            dtParams.push(String(s.slot_date).substring(0, 10));
            dtParams.push(String(s.slot_time).substring(0, 8));
          });

        try {
          const [byDateTime] = await connection.execute(
            `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time,
                    a.appointment_type, a.status,
                    u.full_name AS user_name
             FROM appointments a
             LEFT JOIN users u ON a.user_id = u.id
             WHERE (${dtPairs})
               AND a.status NOT IN ('cancelled','completed','no_show')`,
            dtParams
          );
          linkedAppointments = byDateTime;
        } catch (dtErr) {
          console.warn('⚠️ deleteAllSlots: date/time fallback query failed:', dtErr.message);
        }
      }
    }

    // Resolve service name for notification messages
    let serviceName = `Service ${serviceId || '?'}`;
    if (serviceId) {
      try {
        const [svcRows] = await connection.execute(
          'SELECT service_name FROM services_config WHERE id = ?', [serviceId]
        );
        if (svcRows.length > 0) serviceName = svcRows[0].service_name;
      } catch (_) {}
    }

    // ── 3. Cancel each linked appointment + write in-app notifications ──────
    const cancelledApptIds = [];
    const notifiedUserIds  = []; // track for socket emit after commit

    for (const appt of linkedAppointments) {
      // Cancel the appointment
      await connection.execute(
        'UPDATE appointments SET status = \'cancelled\', updated_at = NOW() WHERE id = ?',
        [appt.id]
      );
      cancelledApptIds.push(appt.id);

      const slotDateStr = String(appt.appointment_date).substring(0, 10);
      const slotTimeStr = String(appt.appointment_time).substring(0, 5);
      const title   = 'Appointment Slot Cancelled';
      const message =
        `Your ${appt.appointment_type || serviceName} appointment on ` +
        `${slotDateStr} at ${slotTimeStr} has been removed by the admin as part of a bulk ` +
        `date cancellation. Your booking has been cancelled. Please contact us to reschedule.`;

      // Write to notifications table
      try {
        await connection.execute(
          `INSERT INTO notifications
             (user_id, appointment_id, notification_type, title, message, is_read, created_at, updated_at)
           VALUES (?, ?, 'appointment_cancelled', ?, ?, 0, NOW(), NOW())`,
          [appt.user_id, appt.id, title, message]
        );
      } catch (notifErr) {
        console.warn(`⚠️ deleteAllSlots: notification insert failed for appt ${appt.id}:`, notifErr.message);
      }

      // Write to legacy appointment_notifications table
      try {
        await connection.execute(
          `INSERT INTO appointment_notifications
             (appointment_id, user_id, notification_type, message, is_read, created_at, updated_at)
           VALUES (?, ?, 'appointment_cancellation', ?, 0, NOW(), NOW())`,
          [appt.id, appt.user_id, message]
        );
      } catch (_) {}

      notifiedUserIds.push({ userId: appt.user_id, apptId: appt.id, slotDateStr, slotTimeStr });
    }

    // ── 4. Hard-delete all matching slot rows ──────────────────────────────
    await connection.execute(
      `DELETE FROM appointment_slots ${whereClause}`,
      filterParams
    );

    // ── 5. Write a single bulk audit log entry ─────────────────────────────
    const uniqueDates = [...new Set(slotsToDelete.map(s => String(s.slot_date).substring(0, 10)))];
    try {
      await connection.execute(
        `INSERT INTO audit_logs (admin_id, action, description, metadata, created_at)
         VALUES (?, 'bulk_delete_all_slots', ?, ?, NOW())`,
        [
          adminId || null,
          `Bulk deleted ${slotsToDelete.length} slot(s) for service_id=${serviceId || 'all'}, ` +
          `date(s)=${uniqueDates.join(', ')}. Cancelled ${cancelledApptIds.length} appointment(s).`,
          JSON.stringify({
            service_id:          serviceId ? parseInt(serviceId) : null,
            dates:               uniqueDates,
            total_slots_deleted: slotsToDelete.length,
            slot_ids:            slotIds,
            cancelled_appt_ids:  cancelledApptIds,
            bookings_cancelled:  cancelledApptIds.length,
          }),
        ]
      );
    } catch (auditErr) {
      console.warn('⚠️ deleteAllSlots: audit log failed:', auditErr.message);
    }

    // ── 6. Commit ──────────────────────────────────────────────────────────
    await connection.commit();

    // ── 7. Emit real-time events (after commit — DB is consistent now) ──────
    if (req.app.locals.io) {
      // Broadcast slot change so all open admin calendars refresh
      const slotsByService = {};
      slotsToDelete.forEach(s => {
        if (!slotsByService[s.service_id]) slotsByService[s.service_id] = [];
        slotsByService[s.service_id].push(s);
      });
      Object.keys(slotsByService).forEach(sid => {
        const ss = slotsByService[sid];
        req.app.locals.io.emit('slotsUpdated', {
          action:    'bulk_deleted',
          serviceId: parseInt(sid),
          slotIds:   ss.map(s => s.id),
          dates:     [...new Set(ss.map(s => String(s.slot_date).substring(0, 10)))],
          count:     ss.length,
          cancelledAppointments: cancelledApptIds.length,
          timestamp: new Date().toISOString(),
        });
      });

      // Notify each affected patient via their personal socket room
      for (const { userId, apptId, slotDateStr, slotTimeStr } of notifiedUserIds) {
        req.app.locals.io.to(`user_${userId}`).emit('appointmentNotification', {
          appointment_id:    apptId,
          user_id:           userId,
          notification_type: 'appointment_cancelled',
          title:  'Appointment Slot Cancelled',
          message: `Your appointment on ${slotDateStr} at ${slotTimeStr} has been cancelled. Please contact us to reschedule.`,
          is_read:    false,
          created_at: new Date().toISOString(),
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: cancelledApptIds.length > 0
        ? `${slotsToDelete.length} slot(s) deleted. ${cancelledApptIds.length} appointment(s) cancelled and patient(s) notified.`
        : `${slotsToDelete.length} appointment slot(s) deleted successfully.`,
      data: {
        deletedCount:          slotsToDelete.length,
        cancelledApptIds,
        appointmentsCancelled: cancelledApptIds.length,
        serviceId:             serviceId || null,
        date:                  date      || null,
      },
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('❌ deleteAllSlots error:', err);
    return res.status(500).json({ success: false, message: 'Failed to delete appointment slots', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};

// ─── Step 2: Get per-date slot detail with linked patient/appointment info ────
// GET /appointment-slots/date-detail?serviceId=&date=
exports.getDateDetail = async (req, res) => {
  try {
    const { serviceId, date } = req.query;
    if (!serviceId || !date)
      return res.status(400).json({ success: false, message: 'serviceId and date are required' });

    // 1. Fetch all slots for this service+date
    const [slots] = await db.execute(
      `SELECT
         s.id,
         s.service_id,
         sc.service_name,
         s.slot_date,
         s.slot_time,
         s.slot_duration_minutes,
         s.capacity,
         s.booked_count,
         s.is_available
       FROM appointment_slots s
       LEFT JOIN services_config sc ON s.service_id = sc.id
       WHERE s.service_id = ? AND s.slot_date = ?
       ORDER BY s.slot_time ASC`,
      [serviceId, date]
    );

    if (slots.length === 0)
      return res.status(200).json({ success: true, data: { slots: [], summary: { total: 0, available: 0, booked: 0, fully_booked: 0 } } });

    // 2. For each slot that has bookings, find the linked appointments.
    //    Match on appointment_date + appointment_time.  Also try slot_id if the
    //    column already exists (migration 001).
    const slotIds = slots.map(s => s.id);
    const placeholders = slotIds.map(() => '?').join(',');

    // Try slot_id FK first, fall back to date+time match
    let appointmentRows = [];
    try {
      const [bySlotId] = await db.execute(
        `SELECT
           a.id           AS appointment_id,
           a.user_id,
           a.patient_id,
           a.slot_id,
           a.appointment_date,
           a.appointment_time,
           a.appointment_type,
           a.status,
           u.full_name    AS user_full_name,
           p.child_fullname AS patient_name
         FROM appointments a
         LEFT JOIN users    u ON a.user_id    = u.id
         LEFT JOIN patients p ON a.patient_id = p.id
         WHERE a.slot_id IN (${placeholders})
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        slotIds
      );
      appointmentRows = bySlotId;
    } catch (_) {
      // slot_id column doesn't exist yet — fall back to date+time match
    }

    if (appointmentRows.length === 0) {
      // Fall back: match by date + time + service (via appointment_type / service_name)
      const [byDateTime] = await db.execute(
        `SELECT
           a.id           AS appointment_id,
           a.user_id,
           a.patient_id,
           a.appointment_date,
           a.appointment_time,
           a.appointment_type,
           a.status,
           u.full_name    AS user_full_name,
           p.child_fullname AS patient_name
         FROM appointments a
         LEFT JOIN users    u ON a.user_id    = u.id
         LEFT JOIN patients p ON a.patient_id = p.id
         WHERE a.appointment_date = ?
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        [date]
      );
      appointmentRows = byDateTime;
    }

    // 3. Build a time→appointments index for fast join
    const apptByTime = {};
    for (const appt of appointmentRows) {
      const t = (appt.appointment_time || '').substring(0, 8);
      if (!apptByTime[t]) apptByTime[t] = [];
      apptByTime[t].push(appt);
    }

    // 4. Enrich each slot with its appointments
    let totalAvailable = 0, totalBooked = 0, totalFullyBooked = 0;
    const enrichedSlots = slots.map(s => {
      const timeKey  = (s.slot_time || '').substring(0, 8);
      const appts    = apptByTime[timeKey] || [];
      const isAvail  = s.is_available === 1;
      const isFull   = s.booked_count >= s.capacity;

      if (isAvail && !isFull) totalAvailable++;
      if (s.booked_count > 0) totalBooked++;
      if (isFull)             totalFullyBooked++;

      return {
        ...normaliseSlot(s),
        appointments: appts.map(a => ({
          appointment_id:   a.appointment_id,
          user_id:          a.user_id,
          patient_id:       a.patient_id,
          patient_name:     a.patient_name || a.user_full_name || 'Unknown',
          appointment_type: a.appointment_type,
          status:           a.status,
          appointment_date: a.appointment_date,
          appointment_time: a.appointment_time,
        })),
      };
    });

    return res.status(200).json({
      success: true,
      data: {
        slots: enrichedSlots,
        summary: {
          total:        slots.length,
          available:    totalAvailable,
          booked:       totalBooked,
          fully_booked: totalFullyBooked,
        },
      },
    });
  } catch (err) {
    console.error('❌ getDateDetail error:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch slot detail', error: err.message });
  }
};

// ─── Step 3: Reschedule entire date (bulk move all slots to a new date) ───────
// POST /appointment-slots/reschedule-date
// Body: { service_id, from_date, to_date, admin_id }
exports.rescheduleDate = async (req, res) => {
  let connection;
  try {
    const { service_id, from_date, to_date, admin_id } = req.body;

    // ── Validation ────────────────────────────────────────────────────────────
    if (!service_id || !from_date || !to_date)
      return res.status(400).json({ success: false, message: 'service_id, from_date, and to_date are required' });

    if (!/^\d{4}-\d{2}-\d{2}$/.test(from_date) || !/^\d{4}-\d{2}-\d{2}$/.test(to_date))
      return res.status(400).json({ success: false, message: 'Dates must be in YYYY-MM-DD format' });

    if (from_date === to_date)
      return res.status(400).json({ success: false, message: 'from_date and to_date must be different' });

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
    if (to_date < todayStr)
      return res.status(400).json({ success: false, message: 'Cannot reschedule to a past date' });

    const serviceId = parseInt(service_id);

    connection = await db.getConnection();
    await connection.beginTransaction();

    // ── Check source slots exist ──────────────────────────────────────────────
    const [sourceSlots] = await connection.execute(
      `SELECT id, slot_time, slot_duration_minutes, capacity, booked_count, is_available
       FROM appointment_slots
       WHERE service_id = ? AND slot_date = ?
       ORDER BY slot_time ASC`,
      [serviceId, from_date]
    );

    if (sourceSlots.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: `No slots found for service ${serviceId} on ${from_date}` });
    }

    // ── Conflict check: does to_date already have overlapping slots? ──────────
    const [existingTarget] = await connection.execute(
      `SELECT id, slot_time FROM appointment_slots
       WHERE service_id = ? AND slot_date = ?
       ORDER BY slot_time ASC`,
      [serviceId, to_date]
    );

    if (existingTarget.length > 0) {
      const sourceTimes  = new Set(sourceSlots.map(s => (s.slot_time || '').substring(0,8)));
      const conflicting  = existingTarget.filter(t => sourceTimes.has((t.slot_time || '').substring(0,8)));
      if (conflicting.length > 0) {
        await connection.rollback();
        return res.status(409).json({
          success: false,
          message: `The target date ${to_date} already has ${existingTarget.length} slot(s) that overlap with the source date. Please choose a different date or delete the existing slots first.`,
          conflict: {
            existing_slots:    existingTarget.length,
            conflicting_times: conflicting.map(t => t.slot_time),
          },
        });
      }
    }

    // ── Find affected appointments (active bookings on source date) ───────────
    let affectedAppointments = [];
    // Try slot_id FK first
    const sourceSlotIds = sourceSlots.map(s => s.id);
    const slotPlaceholders = sourceSlotIds.map(() => '?').join(',');
    try {
      const [bySlotId] = await connection.execute(
        `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time, a.appointment_type, a.slot_id
         FROM appointments a
         WHERE a.slot_id IN (${slotPlaceholders})
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        sourceSlotIds
      );
      affectedAppointments = bySlotId;
    } catch (_) {}

    if (affectedAppointments.length === 0) {
      // Fall back to date match
      const [byDate] = await connection.execute(
        `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time, a.appointment_type
         FROM appointments a
         WHERE a.appointment_date = ?
           AND a.status NOT IN ('cancelled','completed','no_show')`,
        [from_date]
      );
      affectedAppointments = byDate;
    }

    // ── Move each source slot to to_date (update slot_date in place) ──────────
    const sourceSlotIdList = sourceSlots.map(s => s.id);
    await connection.execute(
      `UPDATE appointment_slots SET slot_date = ?, updated_at = NOW()
       WHERE id IN (${sourceSlotIdList.map(() => '?').join(',')})`,
      [to_date, ...sourceSlotIdList]
    );

    // ── Update each affected appointment date ─────────────────────────────────
    const appointmentsWithNewTime = [];
    for (const appt of affectedAppointments) {
      // Keep same time, just change date
      const newDate = to_date;
      const newTime = appt.appointment_time;

      await connection.execute(
        `UPDATE appointments
         SET appointment_date = ?,
             status = 'rescheduled',
             updated_at = NOW()
         WHERE id = ?`,
        [newDate, appt.id]
      );

      appointmentsWithNewTime.push({
        id:               appt.id,
        user_id:          appt.user_id,
        appointment_type: appt.appointment_type,
        old_date:         appt.appointment_date,
        old_time:         appt.appointment_time,
        new_date:         newDate,
        new_time:         newTime,
      });
    }

    // ── Dispatch notifications + audit log ────────────────────────────────────
    const [svcRow] = await connection.execute(
      'SELECT service_name FROM services_config WHERE id = ?',
      [serviceId]
    );
    const serviceName = svcRow[0]?.service_name || `Service ${serviceId}`;

    await dispatchBulkRescheduleNotifications(connection, {
      affectedAppointments: appointmentsWithNewTime,
      serviceName,
      adminId: admin_id || null,
      io: null, // emitted after commit below
    });

    await connection.commit();

    // Emit after commit so clients get correct DB state
    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', {
        action: 'date_rescheduled',
        serviceId,
        from_date,
        to_date,
        slotCount:       sourceSlots.length,
        appointmentCount: appointmentsWithNewTime.length,
        timestamp:       new Date().toISOString(),
      });
      for (const appt of appointmentsWithNewTime) {
        req.app.locals.io.to(`user_${appt.user_id}`).emit('appointmentNotification', {
          appointment_id:    appt.id,
          user_id:           appt.user_id,
          notification_type: 'appointment_rescheduled',
          title:  'Appointment Rescheduled',
          message: `Your appointment has been rescheduled from ${appt.old_date} to ${appt.new_date} at ${appt.new_time ? appt.new_time.substring(0,5) : ''}. Please confirm or request a different time.`,
          is_read:    false,
          created_at: new Date().toISOString(),
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: `${sourceSlots.length} slot(s) rescheduled from ${from_date} to ${to_date}. ${appointmentsWithNewTime.length} patient appointment(s) updated and notified.`,
      data: {
        from_date,
        to_date,
        slots_moved:          sourceSlots.length,
        appointments_updated: appointmentsWithNewTime.length,
        affected_appointment_ids: appointmentsWithNewTime.map(a => a.id),
      },
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('❌ rescheduleDate error:', err);
    return res.status(500).json({ success: false, message: 'Failed to reschedule date', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};

// ─── Step 4: Edit existing generated slots for a date ────────────────────────
// PUT /appointment-slots/edit-date
// Body: { service_id, date, start_time, end_time, slot_duration_minutes, admin_id }
//
// Strategy:
//   1. Identify all CURRENTLY BOOKED appointments on this date+service.
//   2. Generate the new slot time grid.
//   3. If a booked appointment's time slot no longer exists in the new grid →
//      it is "displaced": we must keep those appointment records alive and
//      notify patients — we do NOT delete them silently.
//   4. Delete old UNBOOKED slots, insert new slots for the full new grid.
//   5. For displaced bookings: keep the appointment as-is (date unchanged, time
//      unchanged) but mark status 'rescheduled' and send a notification telling
//      the patient to contact for a new time (since we can't auto-assign a slot).
//   6. Emit slotsUpdated so all open calendars refresh.
exports.editDateSlots = async (req, res) => {
  let connection;
  try {
    const {
      service_id,
      date,
      start_time,
      end_time,
      slot_duration_minutes,
      admin_id,
    } = req.body;

    // ── Validation ────────────────────────────────────────────────────────────
    if (!service_id || !date || !start_time || !end_time || !slot_duration_minutes)
      return res.status(400).json({ success: false, message: 'service_id, date, start_time, end_time, and slot_duration_minutes are required' });

    if (!/^\d{4}-\d{2}-\d{2}$/.test(date))
      return res.status(400).json({ success: false, message: 'date must be YYYY-MM-DD' });

    if (!/^\d{2}:\d{2}(:\d{2})?$/.test(start_time) || !/^\d{2}:\d{2}(:\d{2})?$/.test(end_time))
      return res.status(400).json({ success: false, message: 'Times must be HH:MM or HH:MM:SS' });

    const serviceId = parseInt(service_id);
    const duration  = parseInt(slot_duration_minutes);

    if (isNaN(duration) || duration <= 0 || duration > 480)
      return res.status(400).json({ success: false, message: 'slot_duration_minutes must be 1–480' });

    const [startH, startM] = start_time.split(':').map(Number);
    const [endH,   endM  ] = end_time.split(':').map(Number);
    const startMin = startH * 60 + startM;
    const endMin   = endH   * 60 + endM;

    if (startMin >= endMin)
      return res.status(400).json({ success: false, message: 'end_time must be after start_time' });
    if (startMin < 8 * 60)
      return res.status(400).json({ success: false, message: 'Start time cannot be before 8:00 AM' });
    if (endMin > 18 * 60)
      return res.status(400).json({ success: false, message: 'End time cannot be after 6:00 PM' });

    // ── Build the new slot time grid ──────────────────────────────────────────
    const newSlotTimes = [];
    let cur = startMin;
    while (cur + duration <= endMin) {
      newSlotTimes.push(minutesToTimeStr(cur));
      cur += duration;
    }

    if (newSlotTimes.length === 0)
      return res.status(400).json({ success: false, message: 'Time range too short to generate any slots with that duration' });

    if (newSlotTimes.length > 100)
      return res.status(400).json({ success: false, message: 'Configuration would generate more than 100 slots — reduce the range or increase the duration' });

    connection = await db.getConnection();
    await connection.beginTransaction();

    // ── Fetch existing slots on this date ─────────────────────────────────────
    const [existingSlots] = await connection.execute(
      `SELECT id, slot_time, booked_count FROM appointment_slots
       WHERE service_id = ? AND slot_date = ?
       ORDER BY slot_time ASC`,
      [serviceId, date]
    );

    if (existingSlots.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: `No existing slots found for service ${serviceId} on ${date}. Use Generate Slots to create new ones.` });
    }

    const existingByTime = {};
    for (const s of existingSlots) {
      existingByTime[(s.slot_time || '').substring(0,8)] = s;
    }
    const newTimeSet = new Set(newSlotTimes.map(t => t.substring(0,8)));

    // ── Identify displaced appointments (booked slots not in new grid) ─────────
    const bookedSlots        = existingSlots.filter(s => s.booked_count > 0);
    const displacedSlotTimes = bookedSlots
      .filter(s => !newTimeSet.has((s.slot_time || '').substring(0,8)))
      .map(s => s.slot_time);

    let displacedAppointments = [];
    if (displacedSlotTimes.length > 0) {
      // Find appointments at these times on this date
      const tPlaceholders = displacedSlotTimes.map(() => '?').join(',');

      // Try slot_id first
      const displacedSlotIds = bookedSlots
        .filter(s => !newTimeSet.has((s.slot_time || '').substring(0,8)))
        .map(s => s.id);
      try {
        const [bySlotId] = await connection.execute(
          `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time, a.appointment_type
           FROM appointments a
           WHERE a.slot_id IN (${displacedSlotIds.map(() => '?').join(',')})
             AND a.status NOT IN ('cancelled','completed','no_show')`,
          displacedSlotIds
        );
        displacedAppointments = bySlotId;
      } catch (_) {}

      if (displacedAppointments.length === 0) {
        const [byDateTime] = await connection.execute(
          `SELECT a.id, a.user_id, a.appointment_date, a.appointment_time, a.appointment_type
           FROM appointments a
           WHERE a.appointment_date = ?
             AND TIME(a.appointment_time) IN (${tPlaceholders})
             AND a.status NOT IN ('cancelled','completed','no_show')`,
          [date, ...displacedSlotTimes]
        );
        displacedAppointments = byDateTime;
      }
    }

    // ── Delete all existing slots for this date (we fully replace the grid) ───
    const existingIds = existingSlots.map(s => s.id);
    await connection.execute(
      `DELETE FROM appointment_slots
       WHERE id IN (${existingIds.map(() => '?').join(',')})`,
      existingIds
    );

    // ── Insert the new slot grid ───────────────────────────────────────────────
    for (const slotTime of newSlotTimes) {
      // Carry over booked_count if this time existed before (in-place slot)
      const existing = existingByTime[slotTime.substring(0,8)];
      const bookedCount = existing ? existing.booked_count : 0;
      const isAvail     = bookedCount < 1 ? 1 : 0;

      await connection.execute(
        `INSERT INTO appointment_slots
           (service_id, slot_date, slot_time, slot_duration_minutes, capacity, booked_count, is_available, created_at, updated_at)
         VALUES (?, ?, ?, ?, 1, ?, ?, NOW(), NOW())`,
        [serviceId, date, slotTime, duration, bookedCount, isAvail]
      );
    }

    // ── Handle displaced appointments: mark rescheduled + notify ─────────────
    const [svcRow] = await connection.execute(
      'SELECT service_name FROM services_config WHERE id = ?', [serviceId]
    );
    const serviceName = svcRow[0]?.service_name || `Service ${serviceId}`;

    const displacedWithTimes = displacedAppointments.map(a => ({
      id:               a.id,
      user_id:          a.user_id,
      appointment_type: a.appointment_type,
      old_date:         a.appointment_date,
      old_time:         a.appointment_time,
      new_date:         date,   // same date, but slot no longer exists — patient must contact
      new_time:         null,
    }));

    for (const appt of displacedWithTimes) {
      await connection.execute(
        `UPDATE appointments SET status = 'rescheduled', updated_at = NOW() WHERE id = ?`,
        [appt.id]
      );

      const oldTimeFmt = (appt.old_time || '').substring(0,5);
      const title   = 'Appointment Slot Changed';
      const message =
        `Your ${appt.appointment_type || serviceName} appointment at ${oldTimeFmt} on ${date} ` +
        `has been affected by a schedule change. Your original time slot no longer exists. ` +
        `Please contact us to confirm a new appointment time.`;

      try {
        await connection.execute(
          `INSERT INTO notifications
             (user_id, appointment_id, notification_type, title, message, is_read, created_at, updated_at)
           VALUES (?, ?, 'appointment_rescheduled', ?, ?, 0, NOW(), NOW())`,
          [appt.user_id, appt.id, title, message]
        );
        await connection.execute(
          `INSERT INTO appointment_notifications
             (appointment_id, user_id, notification_type, message, is_read, created_at, updated_at)
           VALUES (?, ?, 'appointment_rescheduled', ?, 0, NOW(), NOW())`,
          [appt.id, appt.user_id, message]
        );
      } catch (notifErr) {
        console.warn(`⚠️ editDateSlots: notification for appointment ${appt.id} failed:`, notifErr.message);
      }
    }

    // Write audit log
    if (admin_id) {
      try {
        await connection.execute(
          `INSERT INTO audit_logs (admin_id, action, description, metadata, created_at)
           VALUES (?, 'edit_date_slots', ?, ?, NOW())`,
          [
            admin_id,
            `Edited slot configuration for service ${serviceId} on ${date}: ${newSlotTimes.length} new slots, ${displacedWithTimes.length} displaced booking(s)`,
            JSON.stringify({
              service_id:        serviceId,
              date,
              new_slot_count:    newSlotTimes.length,
              start_time,
              end_time,
              slot_duration_minutes: duration,
              displaced_appointments: displacedWithTimes.map(a => a.id),
            }),
          ]
        );
      } catch (auditErr) {
        console.warn('⚠️ editDateSlots: audit log failed:', auditErr.message);
      }
    }

    await connection.commit();

    // Emit after commit
    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', {
        action:     'date_edited',
        serviceId,
        date,
        newSlotCount: newSlotTimes.length,
        timestamp:  new Date().toISOString(),
      });
      for (const appt of displacedWithTimes) {
        req.app.locals.io.to(`user_${appt.user_id}`).emit('appointmentNotification', {
          appointment_id:    appt.id,
          user_id:           appt.user_id,
          notification_type: 'appointment_rescheduled',
          title:  'Appointment Slot Changed',
          message: `Your appointment slot on ${date} has been modified. Please contact us to confirm your new time.`,
          is_read:    false,
          created_at: new Date().toISOString(),
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: `Slot configuration updated. ${newSlotTimes.length} new slot(s) created for ${date}. ${displacedWithTimes.length} displaced booking(s) notified.`,
      data: {
        date,
        new_slot_count:          newSlotTimes.length,
        new_slot_times:          newSlotTimes,
        displaced_appointments:  displacedWithTimes.length,
        displaced_appointment_ids: displacedWithTimes.map(a => a.id),
        requires_admin_followup:   displacedWithTimes.length > 0,
      },
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('❌ editDateSlots error:', err);
    return res.status(500).json({ success: false, message: 'Failed to edit date slots', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};
