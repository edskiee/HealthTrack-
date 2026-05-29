const db = require("../config/db");

// Get health tips by category
exports.getHealthTipsByCategory = (req, res) => {
  try {
    const { category } = req.params;
    const { limit } = req.query;
    
    // Validate category
    const validCategories = ['maternal', 'pediatric', 'general'];
    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `Invalid category. Must be one of: ${validCategories.join(', ')}`
      });
    }
    
    // Build query with optional limit
    let sql = "SELECT id, tip_text FROM health_tips WHERE tip_category = ? AND is_active = 1 ORDER BY created_at DESC";
    const params = [category];
    
    const parsedLimit = Number.parseInt(limit, 10);
    if (Number.isInteger(parsedLimit) && parsedLimit > 0) {
      sql += " LIMIT ?";
      params.push(parsedLimit);
    }
    
    db.query(sql, params, (err, results) => {
      if (err) {
        console.error("❌ Database error:", err);
        return res.status(500).json({
          success: false,
          message: "Failed to fetch health tips",
          error: err.message
        });
      }
      
      // Extract just the tip texts
      const tips = results.map(row => row.tip_text);
      
      res.status(200).json({
        success: true,
        data: tips,
        count: tips.length
      });
    });
  } catch (error) {
    console.error("❌ Unexpected error in getHealthTipsByCategory:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};

// Get all health tips
exports.getAllHealthTips = (req, res) => {
  try {
    const { limit } = req.query;
    
    // Build query with optional limit
    let sql = "SELECT id, tip_category, tip_text FROM health_tips WHERE is_active = 1 ORDER BY tip_category, created_at DESC";
    const params = [];
    
    const parsedLimit = Number.parseInt(limit, 10);
    if (Number.isInteger(parsedLimit) && parsedLimit > 0) {
      sql += " LIMIT ?";
      params.push(parsedLimit);
    }
    
    db.query(sql, params, (err, results) => {
      if (err) {
        console.error("❌ Database error:", err);
        return res.status(500).json({
          success: false,
          message: "Failed to fetch health tips",
          error: err.message
        });
      }
      
      res.status(200).json({
        success: true,
        data: results,
        count: results.length
      });
    });
  } catch (error) {
    console.error("❌ Unexpected error in getAllHealthTips:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};

// Add new health tip (admin function)
exports.addHealthTip = (req, res) => {
  try {
    const { category, text } = req.body;
    
    // Validate required fields
    if (!category || !text) {
      return res.status(400).json({
        success: false,
        message: "Category and text are required"
      });
    }
    
    // Validate category
    const validCategories = ['maternal', 'pediatric', 'general'];
    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `Invalid category. Must be one of: ${validCategories.join(', ')}`
      });
    }
    
    const sql = "INSERT INTO health_tips (tip_category, tip_text) VALUES (?, ?)";
    const values = [category, text];
    
    db.query(sql, values, (err, result) => {
      if (err) {
        console.error("❌ Database error adding health tip:", err);
        return res.status(500).json({
          success: false,
          message: "Failed to add health tip",
          error: err.message
        });
      }
      
      const tipId = result.insertId;
      console.log("✅ Health tip added successfully with ID:", tipId);
      
      res.status(201).json({
        success: true,
        message: "Health tip added successfully",
        data: { id: tipId, category, text }
      });
    });
  } catch (error) {
    console.error("❌ Unexpected error in addHealthTip:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};

// Update health tip (admin function)
exports.updateHealthTip = (req, res) => {
  try {
    const { id } = req.params;
    const { category, text, isActive } = req.body;
    
    // Validate required parameter
    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Tip ID is required"
      });
    }
    
    // Build update query dynamically based on provided fields
    const updates = [];
    const values = [];
    
    if (category) {
      const validCategories = ['maternal', 'pediatric', 'general'];
      if (!validCategories.includes(category)) {
        return res.status(400).json({
          success: false,
          message: `Invalid category. Must be one of: ${validCategories.join(', ')}`
        });
      }
      updates.push("tip_category = ?");
      values.push(category);
    }
    
    if (text) {
      updates.push("tip_text = ?");
      values.push(text);
    }
    
    if (isActive !== undefined) {
      updates.push("is_active = ?");
      values.push(isActive ? 1 : 0);
    }
    
    // If no fields to update
    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: "At least one field (category, text, or isActive) must be provided"
      });
    }
    
    // Add ID to values for WHERE clause
    values.push(id);
    
    const sql = `UPDATE health_tips SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    
    db.query(sql, values, (err, result) => {
      if (err) {
        console.error("❌ Database error updating health tip:", err);
        return res.status(500).json({
          success: false,
          message: "Failed to update health tip",
          error: err.message
        });
      }
      
      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          message: "Health tip not found"
        });
      }
      
      console.log("✅ Health tip updated successfully with ID:", id);
      
      res.status(200).json({
        success: true,
        message: "Health tip updated successfully"
      });
    });
  } catch (error) {
    console.error("❌ Unexpected error in updateHealthTip:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};

// Delete health tip (admin function)
exports.deleteHealthTip = (req, res) => {
  try {
    const { id } = req.params;
    
    // Validate required parameter
    if (!id) {
      return res.status(400).json({
        success: false,
        message: "Tip ID is required"
      });
    }
    
    const sql = "DELETE FROM health_tips WHERE id = ?";
    
    db.query(sql, [id], (err, result) => {
      if (err) {
        console.error("❌ Database error deleting health tip:", err);
        return res.status(500).json({
          success: false,
          message: "Failed to delete health tip",
          error: err.message
        });
      }
      
      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          message: "Health tip not found"
        });
      }
      
      console.log("✅ Health tip deleted successfully with ID:", id);
      
      res.status(200).json({
        success: true,
        message: "Health tip deleted successfully"
      });
    });
  } catch (error) {
    console.error("❌ Unexpected error in deleteHealthTip:", error);
    return res.status(500).json({
      success: false,
      message: "An unexpected error occurred",
      error: error.message
    });
  }
};