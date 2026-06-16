const db = require('../config/db');

// ─── Column mapping (real DB schema):
//   slot_date        → the date of the slot        (was: appointment_date)
//   slot_time        → the start time of the slot  (was: start_time)
//   capacity         → max patients per slot        (was: max_patients)
//   booked_count     → how many booked             (was: booked_patients)
//   is_available     → 0/1 availability flag
// ─────────────────────────────────────────────────────────────────────────────

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
              `INSERT INTO appointment_slots (service_id, slot_date, slot_time, capacity, booked_count, is_available, created_at, updated_at)
               VALUES (?, ?, ?, ?, 0, 1, NOW(), NOW())`,
              [serviceId, appointment_date, slotTime, capacity]
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
          `INSERT INTO appointment_slots (service_id, slot_date, slot_time, capacity, booked_count, is_available, created_at, updated_at)
           VALUES (?, ?, ?, ?, 0, 1, NOW(), NOW())`,
          [serviceId, appointment_date, slotTime, capacity]
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

// ─── Delete single appointment slot (admin) ───────────────────────────────────
exports.deleteSlot = async (req, res) => {
  try {
    const { id } = req.params;

    const [slots] = await db.execute(
      'SELECT service_id, slot_date FROM appointment_slots WHERE id = ?',
      [id]
    );
    if (slots.length === 0)
      return res.status(404).json({ success: false, message: 'Appointment slot not found' });

    const slot = slots[0];
    await db.execute('DELETE FROM appointment_slots WHERE id = ?', [id]);

    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', { action: 'deleted', slotId: id, serviceId: slot.service_id, date: slot.slot_date });
    }

    res.status(200).json({ success: true, message: 'Appointment slot deleted successfully' });
  } catch (err) {
    console.error('❌ deleteSlot error:', err);
    return res.status(500).json({ success: false, message: 'Failed to delete appointment slot' });
  }
};

// ─── Update appointment slot (admin) ─────────────────────────────────────────
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
        return res.status(409).json({ success: false, message: 'This slot is no longer available' });
      }

      // Atomic increment
      const [upd] = await connection.execute(
        'UPDATE appointment_slots SET booked_count = booked_count + 1 WHERE id = ? AND booked_count < capacity',
        [slotId]
      );
      if (upd.affectedRows === 0) {
        await connection.rollback();
        return res.status(409).json({ success: false, message: 'Slot was just fully booked by another user' });
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

// ─── Delete all / filtered slots (admin) ─────────────────────────────────────
exports.deleteAllSlots = async (req, res) => {
  let connection;
  try {
    const { serviceId, date } = req.query;

    connection = await db.getConnection();
    await connection.beginTransaction();

    let whereClause = 'WHERE 1=1';
    const params = [];

    if (serviceId) { whereClause += ' AND service_id = ?';  params.push(serviceId); }
    if (date)      { whereClause += ' AND slot_date = ?';   params.push(date); }

    const [slotsToDelete] = await connection.execute(
      `SELECT id, service_id, slot_date FROM appointment_slots ${whereClause}`,
      params
    );

    if (slotsToDelete.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'No appointment slots found matching the criteria' });
    }

    const [result] = await connection.execute(
      `DELETE FROM appointment_slots ${whereClause}`,
      params
    );

    await connection.commit();

    if (req.app.locals.io && slotsToDelete.length > 0) {
      const slotsByService = {};
      slotsToDelete.forEach(s => {
        if (!slotsByService[s.service_id]) slotsByService[s.service_id] = [];
        slotsByService[s.service_id].push(s);
      });
      Object.keys(slotsByService).forEach(sid => {
        const ss = slotsByService[sid];
        req.app.locals.io.emit('slotsUpdated', {
          action: 'bulk_deleted',
          serviceId: parseInt(sid),
          slotIds: ss.map(s => s.id),
          dates: [...new Set(ss.map(s => s.slot_date))],
          count: ss.length,
          timestamp: new Date().toISOString(),
        });
      });
    }

    res.status(200).json({
      success: true,
      message: `${result.affectedRows} appointment slot(s) deleted successfully`,
      data: { deletedCount: result.affectedRows, serviceId: serviceId || null, date: date || null },
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('❌ deleteAllSlots error:', err);
    return res.status(500).json({ success: false, message: 'Failed to delete appointment slots', error: err.message });
  } finally {
    if (connection) connection.release();
  }
};
