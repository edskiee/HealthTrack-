const db = require('../config/db');

// Get all active services
exports.getAllServices = async (req, res) => {
  try {
    const { service_type } = req.query;
    
    let sql = "SELECT * FROM services_config WHERE is_active = 1";
    const params = [];
    
    if (service_type) {
      sql += " AND service_type = ?";
      params.push(service_type);
    }
    
    sql += " ORDER BY service_name ASC";
    
    const [results] = await db.execute(sql, params);
    
    res.status(200).json({
      success: true,
      data: results,
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch services",
    });
  }
};

// Get service by ID
exports.getServiceById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const sql = "SELECT * FROM services_config WHERE id = ? AND is_active = 1";
    const [results] = await db.execute(sql, [id]);
    
    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Service not found",
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
      message: "Failed to fetch service",
    });
  }
};

// Create new service (admin only)
exports.createService = async (req, res) => {
  try {
    const { service_name, service_type, description, is_active = true } = req.body;
    
    // Validate required fields
    if (!service_name || !service_type) {
      return res.status(400).json({
        success: false,
        message: "Service name and service type are required",
      });
    }
    
    const sql = `
      INSERT INTO services_config (service_name, service_type, description, is_active)
      VALUES (?, ?, ?, ?)
    `;
    
    const [result] = await db.execute(sql, [service_name, service_type, description, is_active]);
    
    const newServiceId = result.insertId;
    
    // Get the created service
    const [createdService] = await db.execute(
      "SELECT * FROM services_config WHERE id = ?",
      [newServiceId]
    );
    
    res.status(201).json({
      success: true,
      message: "Service created successfully",
      data: createdService[0],
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to create service",
    });
  }
};

// Update service (admin only)
exports.updateService = async (req, res) => {
  try {
    const { id } = req.params;
    const { service_name, service_type, description, is_active } = req.body;
    
    // Build update query dynamically
    const updates = [];
    const params = [];
    
    if (service_name !== undefined) {
      updates.push('service_name = ?');
      params.push(service_name);
    }
    
    if (service_type !== undefined) {
      updates.push('service_type = ?');
      params.push(service_type);
    }
    
    if (description !== undefined) {
      updates.push('description = ?');
      params.push(description);
    }
    
    if (is_active !== undefined) {
      updates.push('is_active = ?');
      params.push(is_active);
    }
    
    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No valid fields provided for update",
      });
    }
    
    params.push(id);
    
    const sql = `UPDATE services_config SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    
    const [result] = await db.execute(sql, params);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Service not found",
      });
    }
    
    // Get updated service
    const [updatedService] = await db.execute(
      "SELECT * FROM services_config WHERE id = ?",
      [id]
    );
    
    res.status(200).json({
      success: true,
      message: "Service updated successfully",
      data: updatedService[0],
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to update service",
    });
  }
};

// Delete service (admin only)
exports.deleteService = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Check if service has any associated appointments or slots
    const [appointmentCount] = await db.execute(
      "SELECT COUNT(*) as count FROM appointments WHERE appointment_type = (SELECT service_name FROM services_config WHERE id = ?)",
      [id]
    );
    
    const [slotCount] = await db.execute(
      "SELECT COUNT(*) as count FROM appointment_slots WHERE service_id = ?",
      [id]
    );
    
    if (appointmentCount[0].count > 0 || slotCount[0].count > 0) {
      return res.status(400).json({
        success: false,
        message: "Cannot delete service that has associated appointments or slots",
      });
    }
    
    const sql = "DELETE FROM services_config WHERE id = ?";
    const [result] = await db.execute(sql, [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: "Service not found",
      });
    }
    
    res.status(200).json({
      success: true,
      message: "Service deleted successfully",
    });
  } catch (err) {
    console.error("❌ Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to delete service",
    });
  }
};