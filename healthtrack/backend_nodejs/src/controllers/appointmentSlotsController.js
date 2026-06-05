const db = require('../config/db');

// Get all appointment slots (admin)
exports.getAllSlots = async (req, res) => {
  try {
    const { serviceId, date } = req.query;
    
    let sql = `
      SELECT 
        s.id,
        s.service_id,
        sc.service_name,
        s.appointment_date,
        s.start_time,
        s.end_time,
        s.slot_duration_minutes,
        s.max_patients,
        s.booked_patients,
        s.is_available,
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
      sql += ' AND s.appointment_date = ?';
      params.push(date);
    }
    
    sql += ' ORDER BY s.appointment_date ASC, s.start_time ASC';
    
    const [results] = await db.execute(sql, params);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch appointment slots",
    });
  }
};

// Get available appointment slots for users
exports.getAvailableSlots = async (req, res) => {
  try {
    const { serviceId, date } = req.query;
    
    if (!serviceId || !date) {
      return res.status(400).json({
        success: false,
        message: "Service ID and date are required",
      });
    }
    
    const sql = `
      SELECT 
        s.id,
        s.service_id,
        s.appointment_date,
        s.start_time,
        s.end_time,
        s.slot_duration_minutes,
        s.max_patients,
        s.booked_patients,
        s.is_available,
        (s.max_patients - s.booked_patients) as available_spots
      FROM appointment_slots s
      WHERE s.service_id = ? 
        AND s.appointment_date = ? 
        AND s.is_available = TRUE
        AND s.booked_patients < s.max_patients
      ORDER BY s.start_time ASC
    `;
    
    const [results] = await db.execute(sql, [serviceId, date]);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch available appointment slots",
    });
  }
};

// Get user-viewable slots (shows all slots including booked ones for calendar display)
// This returns all slots but properly marks their availability status
exports.getUserViewableSlots = async (req, res) => {
  try {
    const { serviceId, date } = req.query;
    
    let sql = `
      SELECT 
        s.id,
        s.service_id,
        s.appointment_date,
        s.start_time,
        s.end_time,
        s.slot_duration_minutes,
        s.max_patients,
        s.booked_patients,
        s.is_available,
        CASE 
          WHEN s.is_available = TRUE AND s.booked_patients < s.max_patients THEN TRUE
          ELSE FALSE
        END as is_user_available,
        (s.max_patients - s.booked_patients) as available_spots
      FROM appointment_slots s
      WHERE 1=1
    `;
    
    const params = [];
    
    if (serviceId) {
      sql += ' AND s.service_id = ?';
      params.push(serviceId);
    }
    
    if (date) {
      sql += ' AND s.appointment_date = ?';
      params.push(date);
    }
    
    sql += ' ORDER BY s.appointment_date ASC, s.start_time ASC';
    
    const [results] = await db.execute(sql, params);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch user-viewable appointment slots",
    });
  }
};

// Create new appointment slot (admin) with enhanced validation and overflow prevention
exports.createSlot = async (req, res) => {
  let connection;
  try {
    const {
      service_id,
      appointment_date,
      start_time,
      end_time,
      slot_duration_minutes = 30,
      max_patients = 1,
      generate_slots = false
    } = req.body;
    
    // Enhanced validation for required parameters
    if (!service_id) {
      return res.status(400).json({
        success: false,
        message: "Service ID is required",
      });
    }
    
    if (!appointment_date) {
      return res.status(400).json({
        success: false,
        message: "Appointment date is required",
      });
    }
    
    if (!start_time) {
      return res.status(400).json({
        success: false,
        message: "Start time is required",
      });
    }
    
    if (!end_time) {
      return res.status(400).json({
        success: false,
        message: "End time is required",
      });
    }
    
    // Validate service ID format
    const serviceId = parseInt(service_id);
    if (isNaN(serviceId) || serviceId <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid service ID. Must be a positive integer",
      });
    }
    
    // Validate date format
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(appointment_date)) {
      return res.status(400).json({
        success: false,
        message: "Invalid date format. Expected YYYY-MM-DD",
      });
    }
    
    // Validate time formats
    const timeRegex = /^\d{2}:\d{2}:\d{2}$/;
    if (!timeRegex.test(start_time)) {
      return res.status(400).json({
        success: false,
        message: "Invalid start time format. Expected HH:MM:SS",
      });
    }
    
    if (!timeRegex.test(end_time)) {
      return res.status(400).json({
        success: false,
        message: "Invalid end time format. Expected HH:MM:SS",
      });
    }
    
    // Validate slot duration
    const duration = parseInt(slot_duration_minutes);
    if (isNaN(duration) || duration <= 0) {
      return res.status(400).json({
        success: false,
        message: "Slot duration must be a positive integer (minutes)",
      });
    }
    
    if (duration > 480) {
      return res.status(400).json({
        success: false,
        message: "Slot duration cannot exceed 8 hours (480 minutes)",
      });
    }
    
    // Validate max patients
    const maxPatients = parseInt(max_patients);
    if (isNaN(maxPatients) || maxPatients <= 0) {
      return res.status(400).json({
        success: false,
        message: "Max patients must be a positive integer",
      });
    }
    
    if (maxPatients > 20) {
      return res.status(400).json({
        success: false,
        message: "Max patients cannot exceed 20 per slot",
      });
    }
    
    // Validate that the service exists
    const serviceCheckSql = "SELECT id FROM services_config WHERE id = ? AND is_active = 1 AND is_enabled = 1";
    const [serviceResults] = await db.execute(serviceCheckSql, [serviceId]);
    
    if (serviceResults.length === 0) {
      return res.status(400).json({
        success: false,
        message: `Invalid service ID: ${serviceId}. Service not found or not enabled.`,
      });
    }
    
    // Validate date (must be today or future) - handle as pure date string to avoid timezone issues
    const today = new Date();
    const year = today.getFullYear();
    const month = (today.getMonth() + 1).toString().padStart(2, '0');
    const day = today.getDate().toString().padStart(2, '0');
    const todayStr = `${year}-${month}-${day}`;
    
    if (appointment_date < todayStr) {
      return res.status(400).json({
        success: false,
        message: "Cannot create slots for past dates",
      });
    }
    
    // Validate time range
    const [startHours, startMinutes] = start_time.split(':').map(Number);
    const [endHours, endMinutes] = end_time.split(':').map(Number);
    
    const startTimeObj = new Date(0);
    startTimeObj.setHours(startHours, startMinutes, 0, 0);
    
    const endTimeObj = new Date(0);
    endTimeObj.setHours(endHours, endMinutes, 0, 0);
    
    if (startTimeObj >= endTimeObj) {
      return res.status(400).json({
        success: false,
        message: "End time must be later than start time",
      });
    }
    
    // Validate business hours (optional - can be configured)
    const startTotalMinutes = startHours * 60 + startMinutes;
    const endTotalMinutes = endHours * 60 + endMinutes;
    
    if (startTotalMinutes < 8 * 60) { // 8:00 AM
      return res.status(400).json({
        success: false,
        message: "Start time cannot be earlier than 8:00 AM",
      });
    }
    
    if (endTotalMinutes > 18 * 60) { // 6:00 PM
      return res.status(400).json({
        success: false,
        message: "End time cannot be later than 6:00 PM",
      });
    }
    
    // If generate_slots is true, use the safe stored procedure
    if (generate_slots) {
      connection = await db.getConnection();
      await connection.beginTransaction();
      
      try {
        // Call the safe slot generation procedure
        const [results] = await connection.execute(
          'CALL GenerateSlotsSafely(?, ?, ?, ?, ?, ?, @generated_count, @error_message)',
          [serviceId, appointment_date, start_time, end_time, duration, maxPatients]
        );
        
        // Get output parameters
        const [output] = await connection.execute(
          'SELECT @generated_count as generated_count, @error_message as error_message'
        );
        
        const generatedCount = output[0].generated_count;
        const errorMessage = output[0].error_message;
        
        if (errorMessage) {
          await connection.rollback();
          return res.status(400).json({
            success: false,
            message: errorMessage,
          });
        }
        
        await connection.commit();
        
        // Get the created slots for notification
        const [createdSlots] = await db.execute(
          'SELECT * FROM appointment_slots WHERE service_id = ? AND appointment_date = ? AND created_at >= NOW() - INTERVAL 1 SECOND ORDER BY start_time',
          [serviceId, appointment_date]
        );
        
        // Emit real-time update notification
        if (req.app.locals.io) {
          req.app.locals.io.emit('slotsUpdated', { 
            action: 'bulk_created', 
            slotIds: createdSlots.map(slot => slot.id),
            serviceId: serviceId,
            date: appointment_date,
            count: generatedCount
          });
        }
        
        return res.status(201).json({
          success: true,
          message: `${generatedCount} appointment slots generated successfully`,
          data: createdSlots,
        });
      } catch (procError) {
        await connection.rollback();
        throw procError;
      }
    } else {
      // Create a single slot with enhanced validation
      connection = await db.getConnection();
      await connection.beginTransaction();
      
      try {
        // Check for overlapping slots
        const [overlapCheck] = await connection.execute(
          `SELECT id FROM appointment_slots 
           WHERE service_id = ? 
             AND appointment_date = ? 
             AND (
               (start_time < ? AND end_time > ?) OR
               (start_time < ? AND end_time > ?) OR
               (start_time >= ? AND end_time <= ?)
             )`,
          [serviceId, appointment_date, end_time, start_time, start_time, end_time, start_time, end_time]
        );
        
        if (overlapCheck.length > 0) {
          await connection.rollback();
          return res.status(409).json({
            success: false,
            message: "Slot time range conflicts with existing slots",
          });
        }
        
        // Check daily slot limit
        const [dailyCount] = await connection.execute(
          'SELECT COUNT(*) as count FROM appointment_slots WHERE service_id = ? AND appointment_date = ?',
          [serviceId, appointment_date]
        );
        
        if (dailyCount[0].count >= 100) {
          await connection.rollback();
          return res.status(429).json({
            success: false,
            message: "Daily slot limit exceeded (maximum 100 slots per service per day)",
          });
        }
        
        const sql = `
          INSERT INTO appointment_slots 
          (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients)
          VALUES (?, ?, ?, ?, ?, ?)
        `;
        
        const [result] = await connection.execute(sql, [
          serviceId,
          appointment_date,
          start_time,
          end_time,
          duration,
          maxPatients
        ]);
        
        const newSlotId = result.insertId;
        
        // Get the created slot details
        const [createdSlot] = await connection.execute(
          'SELECT * FROM appointment_slots WHERE id = ?',
          [newSlotId]
        );
        
        await connection.commit();
        
        // Emit real-time update notification
        if (req.app.locals.io) {
          req.app.locals.io.emit('slotsUpdated', { 
            action: 'created', 
            slotId: newSlotId,
            serviceId: serviceId,
            date: appointment_date
          });
        }
        
        res.status(201).json({
          success: true,
          message: "Appointment slot created successfully",
          data: createdSlot[0],
        });
      } catch (slotError) {
        await connection.rollback();
        throw slotError;
      }
    }
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to create appointment slot",
      error: err.message // Include error details in development
    });
  } finally {
    if (connection) connection.release();
  }
};

// Delete appointment slot (admin)
exports.deleteSlot = async (req, res) => {
  try {
    const { id } = req.params;
    
    // First get the slot details for notification
    const [slots] = await db.execute(
      'SELECT service_id, appointment_date FROM appointment_slots WHERE id = ?',
      [id]
    );
    
    if (slots.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Appointment slot not found",
      });
    }
    
    const slot = slots[0];
    
    const sql = 'DELETE FROM appointment_slots WHERE id = ?';
    const [result] = await db.execute(sql, [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Appointment slot not found",
      });
    }
    
    // Emit real-time update notification
    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', { 
        action: 'deleted', 
        slotId: id,
        serviceId: slot.service_id,
        date: slot.appointment_date
      });
    }
    
    res.status(200).json({
      success: true,
      message: "Appointment slot deleted successfully",
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to delete appointment slot",
    });
  }
};

// Update appointment slot (admin)
exports.updateSlot = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      service_id,
      appointment_date,
      start_time,
      end_time,
      slot_duration_minutes,
      max_patients,
      is_available
    } = req.body;
    
    // Build update query dynamically
    const updates = [];
    const params = [];
    
    if (service_id !== undefined) {
      updates.push('service_id = ?');
      params.push(service_id);
    }
    
    if (appointment_date !== undefined) {
      updates.push('appointment_date = ?');
      params.push(appointment_date);
    }
    
    if (start_time !== undefined) {
      updates.push('start_time = ?');
      params.push(start_time);
    }
    
    if (end_time !== undefined) {
      updates.push('end_time = ?');
      params.push(end_time);
    }
    
    if (slot_duration_minutes !== undefined) {
      updates.push('slot_duration_minutes = ?');
      params.push(slot_duration_minutes);
    }
    
    if (max_patients !== undefined) {
      updates.push('max_patients = ?');
      params.push(max_patients);
    }
    
    if (is_available !== undefined) {
      updates.push('is_available = ?');
      params.push(is_available);
    }
    
    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No valid fields provided for update",
      });
    }
    
    params.push(id);
    
    const sql = `UPDATE appointment_slots SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    
    const [result] = await db.execute(sql, params);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Appointment slot not found",
      });
    }
    
    // Get updated slot details
    const [updatedSlot] = await db.execute(
      'SELECT * FROM appointment_slots WHERE id = ?',
      [id]
    );
    
    // Emit real-time update notification
    if (req.app.locals.io) {
      req.app.locals.io.emit('slotsUpdated', { 
        action: 'updated', 
        slotId: id,
        serviceId: updatedSlot[0].service_id,
        date: updatedSlot[0].appointment_date
      });
    }
    
    res.status(200).json({
      success: true,
      message: "Appointment slot updated successfully",
      data: updatedSlot[0],
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to update appointment slot",
    });
  }
};

// Book an appointment slot (user) with enhanced race condition protection
exports.bookSlot = async (req, res) => {
  let connection;
  try {
    const { slotId } = req.body;
    
    if (!slotId) {
      return res.status(400).json({
        success: false,
        message: "Slot ID is required",
      });
    }
    
    connection = await db.getConnection();
    await connection.beginTransaction();
    
    try {
      // Get slot details with row-level lock
      const [slots] = await connection.execute(
        'SELECT * FROM appointment_slots WHERE id = ? FOR UPDATE',
        [slotId]
      );
      
      if (slots.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Appointment slot not found",
        });
      }
      
      const slot = slots[0];
      
      // Simple availability check without stored procedure dependency
      const [availabilityCheck] = await connection.execute(
        'SELECT is_available, booked_patients, max_patients FROM appointment_slots WHERE id = ? FOR UPDATE',
        [slotId]
      );
      
      if (availabilityCheck.length === 0) {
        await connection.rollback();
        return res.status(404).json({
          success: false,
          message: "Appointment slot not found",
        });
      }
      
      const slotData = availabilityCheck[0];
      const isAvailable = slotData.is_available === 1 && slotData.booked_patients < slotData.max_patients;
      
      if (!isAvailable) {
        await connection.rollback();
        return res.status(409).json({
          success: false,
          message: "This slot is no longer available (just booked by another user)",
        });
      }
      
      // Increment booked_patients atomically
      const [result] = await connection.execute(
        'UPDATE appointment_slots SET booked_patients = booked_patients + 1 WHERE id = ? AND booked_patients < max_patients',
        [slotId]
      );
      
      if (result.affectedRows === 0) {
        await connection.rollback();
        return res.status(409).json({
          success: false,
          message: "Failed to book slot - it may have been just booked by another user",
        });
      }
      
      // Check if slot is now full and update availability
      const [updatedSlot] = await connection.execute(
        'SELECT * FROM appointment_slots WHERE id = ?',
        [slotId]
      );
      
      const newBookedCount = updatedSlot[0].booked_patients;
      if (newBookedCount >= updatedSlot[0].max_patients) {
        await connection.execute(
          'UPDATE appointment_slots SET is_available = FALSE WHERE id = ?',
          [slotId]
        );
      }
      
      await connection.commit();
      
      // Emit real-time update notification to all connected clients
      if (req.app.locals.io) {
        req.app.locals.io.emit('slotsUpdated', { 
          action: 'booked', 
          slotId: slotId,
          serviceId: slot.service_id,
          date: slot.appointment_date,
          remainingSpots: slot.max_patients - newBookedCount,
          isFullyBooked: newBookedCount >= slot.max_patients,
          timestamp: new Date().toISOString()
        });
        
        console.log(`📡 Emitted real-time slot update: slot ${slotId} booked, ${slot.max_patients - newBookedCount} spots remaining`);
      }
      
      res.status(200).json({
        success: true,
        message: "Slot booked successfully",
        data: {
          slotId: slotId,
          remainingSpots: slot.max_patients - newBookedCount,
          isFullyBooked: newBookedCount >= slot.max_patients
        },
      });
    } catch (err) {
      await connection.rollback();
      throw err;
    }
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to book appointment slot",
      error: err.message
    });
  } finally {
    if (connection) connection.release();
  }
};

// Get slots availability for a month (for user calendar)
exports.getSlotsAvailabilityForMonth = async (req, res) => {
  try {
    const { serviceId, year, month } = req.query;
    
    if (!serviceId || !year || !month) {
      return res.status(400).json({
        success: false,
        message: "Service ID, year, and month are required",
      });
    }
    
    // Validate year and month
    const yearNum = parseInt(year);
    const monthNum = parseInt(month);
    
    if (isNaN(yearNum) || isNaN(monthNum) || monthNum < 1 || monthNum > 12) {
      return res.status(400).json({
        success: false,
        message: "Invalid year or month parameters",
      });
    }
    
    // Calculate first and last day of the month
    const firstDay = `${yearNum}-${monthNum.toString().padStart(2, '0')}-01`;
    const lastDay = `${yearNum}-${monthNum.toString().padStart(2, '0')}-31`;
    
    const sql = `
      SELECT 
        appointment_date,
        COUNT(*) as total_slots,
        SUM(CASE WHEN is_available = TRUE AND booked_patients < max_patients THEN 1 ELSE 0 END) as available_slots,
        SUM(CASE WHEN is_available = TRUE AND booked_patients >= max_patients THEN 1 ELSE 0 END) as fully_booked_slots,
        SUM(CASE WHEN is_available = FALSE THEN 1 ELSE 0 END) as unavailable_slots,
        SUM(booked_patients) as total_booked_patients,
        SUM(max_patients) as total_max_patients,
        CASE 
          WHEN SUM(CASE WHEN is_available = TRUE AND booked_patients < max_patients THEN 1 ELSE 0 END) > 0 THEN 'available'
          WHEN SUM(CASE WHEN is_available = TRUE AND booked_patients >= max_patients THEN 1 ELSE 0 END) > 0 THEN 'fully_booked'
          ELSE 'unavailable'
        END as day_status
      FROM appointment_slots 
      WHERE service_id = ? 
        AND appointment_date >= ? 
        AND appointment_date <= ?
      GROUP BY appointment_date
      ORDER BY appointment_date ASC
    `;
    
    const [results] = await db.execute(sql, [serviceId, firstDay, lastDay]);
    
    res.status(200).json({
      success: true,
      data: results,
      summary: {
        total_days_with_slots: results.length,
        available_days: results.filter(r => r.day_status === 'available').length,
        fully_booked_days: results.filter(r => r.day_status === 'fully_booked').length,
        unavailable_days: results.filter(r => r.day_status === 'unavailable').length,
      }
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch slots availability for month",
    });
  }
};

// Delete all appointment slots (admin)
exports.deleteAllSlots = async (req, res) => {
  let connection;
  try {
    // Get optional filters from query parameters
    const { serviceId, date } = req.query;
    
    connection = await db.getConnection();
    await connection.beginTransaction();
    
    // Build the WHERE clause based on provided filters
    let whereClause = 'WHERE 1=1';
    const params = [];
    
    if (serviceId) {
      whereClause += ' AND service_id = ?';
      params.push(serviceId);
    }
    
    if (date) {
      whereClause += ' AND appointment_date = ?';
      params.push(date);
    }
    
    // First, get the slots that will be deleted for notification
    const [slotsToDelete] = await connection.execute(
      `SELECT id, service_id, appointment_date FROM appointment_slots ${whereClause}`,
      params
    );
    
    if (slotsToDelete.length === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: serviceId || date 
          ? "No appointment slots found matching the specified criteria"
          : "No appointment slots found in the system",
      });
    }
    
    // Delete all slots matching the criteria
    const [result] = await connection.execute(
      `DELETE FROM appointment_slots ${whereClause}`,
      params
    );
    
    await connection.commit();
    
    // Emit real-time update notification for all deleted slots
    if (req.app.locals.io && slotsToDelete.length > 0) {
      // Group slots by service for efficient notification
      const slotsByService = {};
      slotsToDelete.forEach(slot => {
        if (!slotsByService[slot.service_id]) {
          slotsByService[slot.service_id] = [];
        }
        slotsByService[slot.service_id].push(slot);
      });
      
      // Emit notifications for each service
      Object.keys(slotsByService).forEach(serviceId => {
        const serviceSlots = slotsByService[serviceId];
        req.app.locals.io.emit('slotsUpdated', {
          action: 'bulk_deleted',
          serviceId: parseInt(serviceId),
          slotIds: serviceSlots.map(slot => slot.id),
          dates: [...new Set(serviceSlots.map(slot => slot.appointment_date))],
          count: serviceSlots.length,
          timestamp: new Date().toISOString()
        });
      });
      
      console.log(`📡 Emitted real-time bulk deletion notification: ${result.affectedRows} slots deleted`);
    }
    
    res.status(200).json({
      success: true,
      message: `${result.affectedRows} appointment slot(s) deleted successfully`,
      data: {
        deletedCount: result.affectedRows,
        serviceId: serviceId || null,
        date: date || null,
        deletedSlots: slotsToDelete
      }
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to delete appointment slots",
      error: err.message
    });
  } finally {
    if (connection) connection.release();
  }
};

// Enhanced helper function to generate multiple slots with custom duration support
async function generateMultipleSlots(service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients) {
  const slots = [];
  
  try {
    // Validate required parameters
    if (!service_id || !appointment_date || !start_time || !end_time) {
      throw new Error("Missing required parameters for slot generation");
    }
    
    if (slot_duration_minutes <= 0) {
      throw new Error("Slot duration must be greater than 0 minutes");
    }
    
    if (max_patients <= 0) {
      throw new Error("Max patients must be greater than 0");
    }

    // Parse times with proper validation
    const [startHours, startMinutes] = start_time.split(':').map(Number);
    const [endHours, endMinutes] = end_time.split(':').map(Number);
    
    // Parse date string without timezone conversion - only for validation, not stored
    const [year, month, day] = appointment_date.split('-').map(Number);
    
    // Validate that the date components are valid
    if (isNaN(year) || isNaN(month) || isNaN(day) || 
        year < 2020 || year > 2030 || month < 1 || month > 12 || day < 1 || day > 31) {
      throw new Error("Invalid date components. Please provide a valid date in YYYY-MM-DD format.");
    }
    
    // Validate time format
    if (isNaN(startHours) || isNaN(startMinutes) || isNaN(endHours) || isNaN(endMinutes)) {
      throw new Error("Invalid time format. Expected HH:MM:SS");
    }
    
    if (startHours < 0 || startHours > 23 || startMinutes < 0 || startMinutes > 59) {
      throw new Error("Invalid start time. Hours must be 0-23, minutes must be 0-59");
    }
    
    if (endHours < 0 || endHours > 23 || endMinutes < 0 || endMinutes > 59) {
      throw new Error("Invalid end time. Hours must be 0-23, minutes must be 0-59");
    }

    const startTime = new Date(0);
    startTime.setHours(startHours, startMinutes, 0, 0);
    
    const endTime = new Date(0);
    endTime.setHours(endHours, endMinutes, 0, 0);
    
    // Validate time range
    if (startTime >= endTime) {
      throw new Error("End time must be later than start time");
    }
    
    // Calculate total available time
    const totalMinutes = (endTime.getTime() - startTime.getTime()) / (1000 * 60);
    
    // Validate that we can fit at least one slot
    if (totalMinutes < slot_duration_minutes) {
      throw new Error(`Time range (${totalMinutes} minutes) is too short for ${slot_duration_minutes}-minute slots`);
    }
    
    // Generate slots with precise calculation
    const slotInterval = slot_duration_minutes;
    let currentTime = new Date(startTime);
    let slotCount = 0;
    const maxSlots = Math.floor(totalMinutes / slot_duration_minutes);
    
    console.log(`🔄 Generating up to ${maxSlots} slots with ${slot_duration_minutes}-minute intervals`);
    
    while (currentTime < endTime && slotCount < maxSlots) {
      const slotStartTime = new Date(currentTime);
      const slotEndTime = new Date(currentTime);
      slotEndTime.setMinutes(slotEndTime.getMinutes() + slot_duration_minutes);
      
      // Check if slot end time exceeds the end time
      if (slotEndTime > endTime) {
        console.log(`⏭️  Skipping slot that would end at ${slotEndTime} (after end time ${endTime})`);
        break;
      }
      
      // Format times for database with proper padding
      const formattedStartTime = `${slotStartTime.getHours().toString().padStart(2, '0')}:${slotStartTime.getMinutes().toString().padStart(2, '0')}:00`;
      const formattedEndTime = `${slotEndTime.getHours().toString().padStart(2, '0')}:${slotEndTime.getMinutes().toString().padStart(2, '0')}:00`;
      
      // Check for overlapping slots in database to prevent duplicates
      const overlapCheckSql = `
        SELECT id FROM appointment_slots 
        WHERE service_id = ? 
          AND appointment_date = ? 
          AND (
            (start_time < ? AND end_time > ?) OR
            (start_time < ? AND end_time > ?) OR
            (start_time >= ? AND end_time <= ?)
          )
      `;
      
      const [existingSlots] = await db.execute(overlapCheckSql, [
        service_id, appointment_date,
        formattedEndTime, formattedStartTime,  // New slot starts before existing ends
        formattedStartTime, formattedEndTime,  // New slot ends after existing starts
        formattedStartTime, formattedEndTime   // New slot is completely within existing
      ]);
      
      if (existingSlots.length > 0) {
        console.log(`⚠️  Skipping overlapping slot ${formattedStartTime} - ${formattedEndTime}`);
        currentTime.setMinutes(currentTime.getMinutes() + slotInterval);
        continue;
      }
      
      // Insert slot with proper error handling
      const sql = `
        INSERT INTO appointment_slots 
        (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients)
        VALUES (?, ?, ?, ?, ?, ?)
      `;
      
      try {
        const [result] = await db.execute(sql, [
          service_id,
          appointment_date,
          formattedStartTime,
          formattedEndTime,
          slot_duration_minutes,
          max_patients
        ]);
        
        // Get created slot details
        const [createdSlot] = await db.execute(
          'SELECT * FROM appointment_slots WHERE id = ?',
          [result.insertId]
        );
        
        if (createdSlot && createdSlot.length > 0) {
          slots.push(createdSlot[0]);
          slotCount++;
          console.log(`✅ Created slot ${slotCount}: ${formattedStartTime} - ${formattedEndTime}`);
        }
        
      } catch (insertError) {
        console.error(`❌ Failed to insert slot: ${insertError.message}`);
        throw new Error(`Failed to create slot ${slotCount + 1}: ${insertError.message}`);
      }
      
      // Move to next slot time
      currentTime.setMinutes(currentTime.getMinutes() + slotInterval);
    }
    
    console.log(`✅ Successfully generated ${slots.length} slots for ${appointment_date}`);
    return slots;
    
  } catch (error) {
    console.error("❌ Error in generateMultipleSlots:", error);
    throw error;
  }
}
