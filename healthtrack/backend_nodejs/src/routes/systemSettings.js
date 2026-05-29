const express = require('express');
const db = require('../config/db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware.authenticateAdmin);

/**
 * Get all system settings
 * GET /system-settings
 */
router.get('/', async (req, res) => {
  try {
    const sql = "SELECT id, setting_key, setting_value, setting_type, description, is_active, created_at, updated_at FROM system_settings WHERE is_active = 1 ORDER BY setting_key";
    const [results] = await db.execute(sql);
    
    return res.json({
      success: true,
      message: "System settings retrieved successfully",
      data: results
    });
  } catch (error) {
    console.error("❌ Error fetching system settings:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch system settings",
      error: error.message
    });
  }
});

/**
 * Get a specific setting by key
 * GET /system-settings/:key
 */
router.get('/:key', async (req, res) => {
  try {
    const { key } = req.params;
    const sql = "SELECT id, setting_key, setting_value, setting_type, description, is_active, created_at, updated_at FROM system_settings WHERE setting_key = ? AND is_active = 1";
    const [results] = await db.execute(sql, [key]);
    
    if (results.length > 0) {
      return res.json({
        success: true,
        message: "Setting retrieved successfully",
        data: results[0]
      });
    } else {
      return res.status(404).json({
        success: false,
        message: "Setting not found"
      });
    }
  } catch (error) {
    console.error(`❌ Error fetching setting ${req.params.key}:`, error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch setting",
      error: error.message
    });
  }
});

/**
 * Update a setting
 * PUT /system-settings/:key
 */
router.put('/:key', async (req, res) => {
  try {
    const { key } = req.params;
    const { value, type, description, setting_value, setting_type } = req.body;
    const normalizedValue =
      setting_value !== undefined ? setting_value : value;
    const normalizedType =
      setting_type !== undefined ? setting_type : type;

    if (normalizedValue === undefined || normalizedType === undefined) {
      return res.status(400).json({
        success: false,
        message: "setting_value and setting_type are required.",
      });
    }
    
    // Check if setting exists
    const [existing] = await db.execute(
      "SELECT id FROM system_settings WHERE setting_key = ?",
      [key]
    );
    
    if (existing.length > 0) {
      // Update existing setting
      const sql = "UPDATE system_settings SET setting_value = ?, setting_type = ?, description = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?";
      await db.execute(sql, [normalizedValue, normalizedType, description ?? null, key]);
    } else {
      // Create new setting
      const sql = "INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_active) VALUES (?, ?, ?, ?, 1)";
      await db.execute(sql, [key, normalizedValue, normalizedType, description ?? null]);
    }
    
    return res.json({
      success: true,
      message: "Setting updated successfully"
    });
  } catch (error) {
    console.error(`❌ Error updating setting ${req.params.key}:`, error);
    return res.status(500).json({
      success: false,
      message: "Failed to update setting",
      error: error.message
    });
  }
});

/**
 * Create a new setting
 * POST /system-settings
 */
router.post('/', async (req, res) => {
  try {
    const { setting_key, setting_value, setting_type, description } = req.body;
    
    // Check if setting already exists
    const [existing] = await db.execute(
      "SELECT id FROM system_settings WHERE setting_key = ?",
      [setting_key]
    );
    
    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        message: "Setting with this key already exists"
      });
    }
    
    const sql = "INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_active) VALUES (?, ?, ?, ?, 1)";
    const [result] = await db.execute(sql, [setting_key, setting_value, setting_type, description]);
    
    return res.status(201).json({
      success: true,
      message: "Setting created successfully",
      data: {
        id: result.insertId,
        setting_key,
        setting_value,
        setting_type,
        description
      }
    });
  } catch (error) {
    console.error("❌ Error creating setting:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to create setting",
      error: error.message
    });
  }
});

/**
 * Bulk update settings
 * POST /system-settings/bulk-update
 */
router.post('/bulk-update', async (req, res) => {
  try {
    const { settings } = req.body;
    
    if (!Array.isArray(settings)) {
      return res.status(400).json({
        success: false,
        message: "Settings must be an array"
      });
    }
    
    // Process each setting
    for (const setting of settings) {
      const { setting_key, setting_value, setting_type, description } = setting;
      
      // Check if setting exists
      const [existing] = await db.execute(
        "SELECT id FROM system_settings WHERE setting_key = ?",
        [setting_key]
      );
      
      if (existing.length > 0) {
        // Update existing setting
        await db.execute(
          "UPDATE system_settings SET setting_value = ?, setting_type = ?, description = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?",
          [setting_value, setting_type, description, setting_key]
        );
      } else {
        // Create new setting
        await db.execute(
          "INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_active) VALUES (?, ?, ?, ?, 1)",
          [setting_key, setting_value, setting_type, description]
        );
      }
    }
    
    return res.json({
      success: true,
      message: "Bulk settings update completed successfully"
    });
  } catch (error) {
    console.error("❌ Error in bulk settings update:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to bulk update settings",
      error: error.message
    });
  }
});

/**
 * Reset a setting to default value
 * DELETE /system-settings/:key/reset
 */
router.delete('/:key/reset', async (req, res) => {
  try {
    const { key } = req.params;
    
    // Define default values for common settings
    const defaultSettings = {
      'app_name': { value: 'HealthTrack System', type: 'string' },
      'maintenance_mode': { value: 'false', type: 'boolean' },
      'max_appointments_per_day': { value: '50', type: 'number' },
      'appointment_reminders_enabled': { value: 'true', type: 'boolean' },
      'data_retention_days': { value: '365', type: 'number' },
      'default_service_type': { value: 'immunization', type: 'string' },
      'notifications_enabled': { value: 'true', type: 'boolean' }
    };
    
    const defaultValue = defaultSettings[key];
    
    if (!defaultValue) {
      return res.status(404).json({
        success: false,
        message: "No default value found for this setting"
      });
    }
    
    const sql = "UPDATE system_settings SET setting_value = ?, setting_type = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?";
    await db.execute(sql, [defaultValue.value, defaultValue.type, key]);
    
    return res.json({
      success: true,
      message: "Setting reset to default value successfully"
    });
  } catch (error) {
    console.error(`❌ Error resetting setting ${req.params.key}:`, error);
    return res.status(500).json({
      success: false,
      message: "Failed to reset setting",
      error: error.message
    });
  }
});

module.exports = router;