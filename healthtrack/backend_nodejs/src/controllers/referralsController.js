"use strict";

/**
 * Referrals Controller
 * Fixed: db.query() → db.execute() (mysql2/promise pool requires execute/query with promise API)
 * Fixed: p.patientName → p.mother_fullname (correct column name in patients table)
 * Fixed: referrals route — no auth added here; called from protected route
 */

const db = require("../config/db");

// ─── Create Referral ──────────────────────────────────────────────────────────

exports.createReferral = async (req, res) => {
  try {
    const { patient_id, referred_to, referral_date, referral_notes, referring_admin_id } = req.body;

    if (!patient_id || !referred_to || !referral_date || !referral_notes) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields: patient_id, referred_to, referral_date, referral_notes",
      });
    }

    if (referral_notes.trim().length < 10) {
      return res.status(400).json({
        success: false,
        message: "Referral notes must be at least 10 characters long",
      });
    }

    // Verify patient exists — use correct column name (mother_fullname, not patientName)
    const [patientCheck] = await db.execute(
      "SELECT id, mother_fullname FROM patients WHERE id = ?",
      [patient_id]
    );

    if (!patientCheck.length) {
      return res.status(404).json({ success: false, message: "Patient not found" });
    }

    const [result] = await db.execute(
      `INSERT INTO referrals (patient_id, referred_to, referral_date, referral_notes, referring_admin_id)
       VALUES (?, ?, ?, ?, ?)`,
      [patient_id, referred_to, referral_date, referral_notes.trim(), referring_admin_id || null]
    );

    const newReferral = {
      id: result.insertId,
      patient_id,
      referred_to,
      referral_date,
      referral_notes: referral_notes.trim(),
      referring_admin_id: referring_admin_id || null,
      status: "pending",
      created_at: new Date().toISOString(),
    };

    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${patient_id}`).emit("newReferral", {
        type: "referral_created",
        data: newReferral,
        patient_name: patientCheck[0].mother_fullname,
        message: `New referral created: ${referred_to}`,
      });
    }

    return res.status(201).json({
      success: true,
      message: "Referral created successfully",
      data: newReferral,
    });
  } catch (error) {
    console.error("❌ createReferral:", error);
    return res.status(500).json({ success: false, message: "Internal server error", error: error.message });
  }
};

// ─── Get Referrals for a Patient ─────────────────────────────────────────────

exports.getPatientReferrals = async (req, res) => {
  try {
    const { patient_id } = req.params;
    if (!patient_id) {
      return res.status(400).json({ success: false, message: "Patient ID is required" });
    }

    const [referrals] = await db.execute(
      `SELECT r.*,
              p.mother_fullname AS patient_name,
              a.username        AS admin_name
       FROM referrals r
       LEFT JOIN patients p ON r.patient_id = p.id
       LEFT JOIN admins   a ON r.referring_admin_id = a.id
       WHERE r.patient_id = ?
       ORDER BY r.created_at DESC`,
      [patient_id]
    );

    return res.status(200).json({
      success: true,
      message: "Referrals retrieved successfully",
      data: referrals,
    });
  } catch (error) {
    console.error("❌ getPatientReferrals:", error);
    return res.status(500).json({ success: false, message: "Internal server error", error: error.message });
  }
};

// ─── Get All Referrals (admin) ────────────────────────────────────────────────

exports.getAllReferrals = async (req, res) => {
  try {
    const [referrals] = await db.execute(
      `SELECT r.*,
              p.mother_fullname AS patient_name,
              a.username        AS admin_name
       FROM referrals r
       LEFT JOIN patients p ON r.patient_id = p.id
       LEFT JOIN admins   a ON r.referring_admin_id = a.id
       ORDER BY r.created_at DESC`
    );

    return res.status(200).json({
      success: true,
      message: "All referrals retrieved successfully",
      data: referrals,
    });
  } catch (error) {
    console.error("❌ getAllReferrals:", error);
    return res.status(500).json({ success: false, message: "Internal server error", error: error.message });
  }
};

// ─── Update Referral Status ───────────────────────────────────────────────────

exports.updateReferralStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!id || !status) {
      return res.status(400).json({ success: false, message: "Referral ID and status are required" });
    }

    const validStatuses = ["pending", "accepted", "completed", "cancelled"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid status. Must be one of: " + validStatuses.join(", "),
      });
    }

    const [existingReferral] = await db.execute(
      "SELECT patient_id, referred_to FROM referrals WHERE id = ?",
      [id]
    );

    if (!existingReferral.length) {
      return res.status(404).json({ success: false, message: "Referral not found" });
    }

    await db.execute(
      "UPDATE referrals SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      [status, id]
    );

    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${existingReferral[0].patient_id}`).emit("referralStatusUpdated", {
        type: "referral_status_updated",
        referral_id: parseInt(id),
        new_status: status,
        referred_to: existingReferral[0].referred_to,
        message: `Referral status updated to: ${status}`,
      });
    }

    return res.status(200).json({
      success: true,
      message: "Referral status updated successfully",
      data: { id: parseInt(id), status, updated_at: new Date().toISOString() },
    });
  } catch (error) {
    console.error("❌ updateReferralStatus:", error);
    return res.status(500).json({ success: false, message: "Internal server error", error: error.message });
  }
};

// ─── Delete Referral ──────────────────────────────────────────────────────────

exports.deleteReferral = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Referral ID is required" });
    }

    const [existingReferral] = await db.execute(
      "SELECT patient_id, referred_to FROM referrals WHERE id = ?",
      [id]
    );

    if (!existingReferral.length) {
      return res.status(404).json({ success: false, message: "Referral not found" });
    }

    await db.execute("DELETE FROM referrals WHERE id = ?", [id]);

    const io = req.app.locals.io;
    if (io) {
      io.to(`user_${existingReferral[0].patient_id}`).emit("referralDeleted", {
        type: "referral_deleted",
        referral_id: parseInt(id),
        referred_to: existingReferral[0].referred_to,
        message: `Referral to ${existingReferral[0].referred_to} has been deleted`,
      });
    }

    return res.status(200).json({ success: true, message: "Referral deleted successfully" });
  } catch (error) {
    console.error("❌ deleteReferral:", error);
    return res.status(500).json({ success: false, message: "Internal server error", error: error.message });
  }
};
