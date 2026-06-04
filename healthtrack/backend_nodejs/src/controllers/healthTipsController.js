"use strict";

/**
 * Health Tips Controller
 * Fixed: Replaced all callback-style db.query() with async/await db.execute()
 * The mysql2/promise pool only supports the promise interface — callbacks crash silently.
 */

const db = require("../config/db");

// ─── Get Tips by Category ─────────────────────────────────────────────────────

exports.getHealthTipsByCategory = async (req, res) => {
  try {
    const { category } = req.params;
    const { limit }    = req.query;

    const validCategories = ["maternal", "pediatric", "general"];
    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `Invalid category. Must be one of: ${validCategories.join(", ")}`,
      });
    }

    let sql    = "SELECT id, tip_text FROM health_tips WHERE tip_category = ? AND is_active = 1 ORDER BY created_at DESC";
    const params = [category];

    const parsedLimit = Number.parseInt(limit, 10);
    if (Number.isInteger(parsedLimit) && parsedLimit > 0) {
      sql += " LIMIT ?";
      params.push(parsedLimit);
    }

    const [results] = await db.execute(sql, params);
    const tips = results.map(row => row.tip_text);

    return res.status(200).json({ success: true, data: tips, count: tips.length });
  } catch (error) {
    console.error("❌ getHealthTipsByCategory:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch health tips", error: error.message });
  }
};

// ─── Get All Tips ─────────────────────────────────────────────────────────────

exports.getAllHealthTips = async (req, res) => {
  try {
    const { limit } = req.query;

    let sql    = "SELECT id, tip_category, tip_text FROM health_tips WHERE is_active = 1 ORDER BY tip_category, created_at DESC";
    const params = [];

    const parsedLimit = Number.parseInt(limit, 10);
    if (Number.isInteger(parsedLimit) && parsedLimit > 0) {
      sql += " LIMIT ?";
      params.push(parsedLimit);
    }

    const [results] = await db.execute(sql, params);
    return res.status(200).json({ success: true, data: results, count: results.length });
  } catch (error) {
    console.error("❌ getAllHealthTips:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch health tips", error: error.message });
  }
};

// ─── Add Health Tip ───────────────────────────────────────────────────────────

exports.addHealthTip = async (req, res) => {
  try {
    const { category, text } = req.body;

    if (!category || !text) {
      return res.status(400).json({ success: false, message: "Category and text are required" });
    }

    const validCategories = ["maternal", "pediatric", "general"];
    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `Invalid category. Must be one of: ${validCategories.join(", ")}`,
      });
    }

    const [result] = await db.execute(
      "INSERT INTO health_tips (tip_category, tip_text) VALUES (?, ?)",
      [category, text]
    );

    console.log(`✅ Health tip added ID=${result.insertId}`);
    return res.status(201).json({
      success: true,
      message: "Health tip added successfully",
      data: { id: result.insertId, category, text },
    });
  } catch (error) {
    console.error("❌ addHealthTip:", error);
    return res.status(500).json({ success: false, message: "Failed to add health tip", error: error.message });
  }
};

// ─── Update Health Tip ────────────────────────────────────────────────────────

exports.updateHealthTip = async (req, res) => {
  try {
    const { id }                   = req.params;
    const { category, text, isActive } = req.body;

    if (!id) {
      return res.status(400).json({ success: false, message: "Tip ID is required" });
    }

    const updates = [];
    const values  = [];

    if (category) {
      const validCategories = ["maternal", "pediatric", "general"];
      if (!validCategories.includes(category)) {
        return res.status(400).json({
          success: false,
          message: `Invalid category. Must be one of: ${validCategories.join(", ")}`,
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

    if (!updates.length) {
      return res.status(400).json({
        success: false,
        message: "At least one field (category, text, or isActive) must be provided",
      });
    }

    values.push(id);
    const [result] = await db.execute(
      `UPDATE health_tips SET ${updates.join(", ")}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: "Health tip not found" });
    }

    console.log(`✅ Health tip updated ID=${id}`);
    return res.status(200).json({ success: true, message: "Health tip updated successfully" });
  } catch (error) {
    console.error("❌ updateHealthTip:", error);
    return res.status(500).json({ success: false, message: "Failed to update health tip", error: error.message });
  }
};

// ─── Delete Health Tip ────────────────────────────────────────────────────────

exports.deleteHealthTip = async (req, res) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({ success: false, message: "Tip ID is required" });
    }

    const [result] = await db.execute("DELETE FROM health_tips WHERE id = ?", [id]);

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: "Health tip not found" });
    }

    console.log(`✅ Health tip deleted ID=${id}`);
    return res.status(200).json({ success: true, message: "Health tip deleted successfully" });
  } catch (error) {
    console.error("❌ deleteHealthTip:", error);
    return res.status(500).json({ success: false, message: "Failed to delete health tip", error: error.message });
  }
};
