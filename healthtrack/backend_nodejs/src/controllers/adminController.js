"use strict";

const bcrypt       = require("bcryptjs");
const { authenticator } = require("otplib");
const db           = require("../config/db");
const { createAdminSession }     = require("../utils/adminSession");
const { ensureAdminPreferences } = require("../utils/ensureAdminPreferences");
const { writeAudit }             = require("../utils/auditLog");

// ─── Constants ────────────────────────────────────────────────────────────────
const BCRYPT_ROUNDS = 12;

// ─── Password Helpers ─────────────────────────────────────────────────────────

/**
 * Hash a plain-text password with bcrypt.
 */
async function hashAdminPassword(plain) {
  return bcrypt.hash(plain, BCRYPT_ROUNDS);
}

/**
 * Verify an admin password.
 * Supports:
 *   - bcrypt hashes  ($2a$, $2b$, $2y$ prefix)
 *   - legacy MD5     (32 hex characters)
 *
 * Returns { match, isLegacyMd5 } so the caller can transparently rehash.
 */
async function verifyAdminPassword(plain, stored) {
  const isBcrypt = /^\$2[aby]\$/.test(stored);
  if (isBcrypt) {
    const match = await bcrypt.compare(plain, stored);
    return { match, isLegacyMd5: false };
  }

  // Legacy MD5 path — still supported for existing admins
  const crypto   = require("crypto");
  const md5Plain = crypto.createHash("md5").update(plain).digest("hex");
  const match    = md5Plain === stored;
  return { match, isLegacyMd5: match }; // flag rehash only when credentials are correct
}

// ─── Admin Login ──────────────────────────────────────────────────────────────

exports.adminLogin = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ success: false, message: "Please provide both username and password" });
    }
    if (username.length < 3) {
      return res.status(400).json({ success: false, message: "Username must be at least 3 characters long" });
    }
    if (password.length < 4) {
      return res.status(400).json({ success: false, message: "Password must be at least 4 characters long" });
    }

    // Fetch admin by username only — never pass password to SQL
    const [rows] = await db.execute(
      "SELECT id, username, password, role FROM admins WHERE username = ? LIMIT 1",
      [username]
    );

    if (!rows.length) {
      // Constant-time response — prevent username enumeration
      await bcrypt.compare(password, "$2b$12$invalidhashpaddingtoconsistenttime000000000000000000000");
      return res.status(401).json({ success: false, message: "Invalid username or password" });
    }

    const adminRow = rows[0];
    const { match, isLegacyMd5 } = await verifyAdminPassword(password, adminRow.password);

    if (!match) {
      return res.status(401).json({ success: false, message: "Invalid username or password" });
    }

    // ── Transparent rehash: MD5 → bcrypt on next login ───────────────────────
    if (isLegacyMd5) {
      try {
        const newHash = await hashAdminPassword(password);
        await db.execute("UPDATE admins SET password = ? WHERE id = ?", [newHash, adminRow.id]);
        console.log(`🔐 Admin password rehashed to bcrypt for admin ID=${adminRow.id}`);
      } catch (rehashErr) {
        console.error("⚠️ Admin password rehash failed (non-fatal):", rehashErr.message);
      }
    }

    const adminId = adminRow.id;

    try { await ensureAdminPreferences(adminId); } catch (_e) {}

    // Check TOTP
    let prefs = {};
    try {
      const [[p]] = await db.execute(
        "SELECT totp_enabled, totp_secret FROM admin_preferences WHERE admin_id = ? LIMIT 1",
        [adminId]
      );
      prefs = p || {};
    } catch (_e) {}

    if (prefs.totp_enabled) {
      const code    = req.body?.totp || req.body?.totp_code;
      const cleaned = code != null ? String(code).replace(/\s/g, "") : "";
      if (!cleaned) {
        return res.status(200).json({ success: false, requiresOtp: true, message: "Enter your authentication app code." });
      }
      const secret = prefs.totp_secret instanceof Buffer
        ? prefs.totp_secret.toString()
        : prefs.totp_secret;
      if (!secret || !authenticator.check(cleaned, secret)) {
        return res.status(200).json({ success: false, requiresOtp: true, message: "Authentication code rejected — try again." });
      }
    }

    try {
      const { tokenPlain } = await createAdminSession(db, adminId, req);
      await writeAudit(adminId, "auth.admin.login.success", req, {});
      console.log(`✅ Admin login successful ID=${adminId}`);

      return res.status(200).json({
        success: true,
        message: "Login success",
        access_token: tokenPlain,
        admin: {
          id:       adminId,
          username: adminRow.username,
          role:     adminRow.role || "Administrator",
        },
      });
    } catch (sessionErr) {
      console.error("⚠️ Session creation failed:", sessionErr.message);
      return res.status(500).json({ success: false, message: "Session storage is not ready. Ensure database migrations ran (admin_sessions table)." });
    }
  } catch (error) {
    console.error("❌ adminLogin:", error);
    return res.status(500).json({ success: false, message: "Server error. Please try again later." });
  }
};

// ─── Admin Register ───────────────────────────────────────────────────────────

exports.adminRegister = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ success: false, message: "Please provide both username and password" });
    }
    if (username.length < 3) {
      return res.status(400).json({ success: false, message: "Username must be at least 3 characters long" });
    }
    if (password.length < 8) {
      return res.status(400).json({ success: false, message: "Admin password must be at least 8 characters long" });
    }

    const hashedPassword = await hashAdminPassword(password);

    const [results] = await db.execute(
      "INSERT INTO admins (username, password) VALUES (?, ?)",
      [username, hashedPassword]
    );

    const [fetchResults] = await db.execute(
      "SELECT id, username FROM admins WHERE id = ?",
      [results.insertId]
    );

    console.log(`✅ Admin registered ID=${results.insertId}`);
    return res.status(201).json({
      success: true,
      message: "Admin registered successfully!",
      admin: fetchResults[0],
    });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ success: false, message: "Username already exists. Please choose a different one." });
    }
    console.error("❌ adminRegister:", error);
    return res.status(500).json({ success: false, message: "Server error. Please try again later." });
  }
};

// ─── Get Admin Profile ────────────────────────────────────────────────────────

exports.getAdminProfile = async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user && parseInt(id, 10) !== Number(req.user.id)) {
      return res.status(403).json({ success: false, message: "You can only load your own admin profile." });
    }
    if (!id || isNaN(id) || parseInt(id) <= 0) {
      return res.status(400).json({ success: false, message: "Invalid admin ID — must be a positive number" });
    }

    const adminId = parseInt(id);
    let results;

    try {
      const [rows] = await db.execute(
        "SELECT id, username, full_name, email, last_login, created_at FROM admins WHERE id = ?",
        [adminId]
      );
      results = rows;
    } catch (_e) {
      const [rows] = await db.execute("SELECT id, username FROM admins WHERE id = ?", [adminId]);
      results = rows;
    }

    if (!results.length) {
      return res.status(404).json({ success: false, message: "Admin not found" });
    }
    return res.status(200).json({ success: true, message: "Profile fetched successfully", admin: results[0] });
  } catch (error) {
    console.error("❌ getAdminProfile:", error);
    return res.status(500).json({ success: false, message: "Server error. Please try again later." });
  }
};

// ─── Update Admin Profile ─────────────────────────────────────────────────────

exports.updateAdminProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const { full_name, email, current_password, new_password } = req.body;

    if (req.user && parseInt(id, 10) !== Number(req.user.id)) {
      return res.status(403).json({ success: false, message: "You can only modify your own admin profile." });
    }
    if (!id || isNaN(id) || parseInt(id) <= 0) {
      return res.status(400).json({ success: false, message: "Invalid admin ID — must be a positive number" });
    }

    const adminId = parseInt(id);
    const updates = [];
    const params  = [];

    if (full_name !== undefined) {
      try {
        const [colResult] = await db.execute("SHOW COLUMNS FROM admins LIKE 'full_name'");
        if (colResult.length) { updates.push("full_name = ?"); params.push(full_name); }
      } catch (_e) {}
    }

    if (email !== undefined) {
      try {
        const [colResult] = await db.execute("SHOW COLUMNS FROM admins LIKE 'email'");
        if (colResult.length) { updates.push("email = ?"); params.push(email); }
      } catch (_e) {}
    }

    if (current_password !== undefined && new_password !== undefined) {
      if (new_password.length < 8) {
        return res.status(400).json({ success: false, message: "New password must be at least 8 characters long" });
      }

      // Fetch stored password and verify using bcrypt/MD5 compatible check
      const [verifyResults] = await db.execute("SELECT password FROM admins WHERE id = ?", [adminId]);
      if (!verifyResults.length) {
        return res.status(404).json({ success: false, message: "Admin not found" });
      }

      const { match } = await verifyAdminPassword(current_password, verifyResults[0].password);
      if (!match) {
        return res.status(400).json({ success: false, message: "Current password is incorrect" });
      }

      const hashedNew = await hashAdminPassword(new_password);
      updates.push("password = ?");
      params.push(hashedNew);

      try {
        const [colExist] = await db.execute("SHOW COLUMNS FROM admins LIKE 'password_changed_at'");
        if (colExist.length) updates.push("password_changed_at = CURRENT_TIMESTAMP");
      } catch (_c) {}

      // Revoke other sessions after password change
      try {
        if (req?.user?.sessionId) {
          await db.execute("DELETE FROM admin_sessions WHERE admin_id = ? AND id <> ?", [adminId, req.user.sessionId]);
        } else {
          await db.execute("DELETE FROM admin_sessions WHERE admin_id = ?", [adminId]);
        }
        await writeAudit(adminId, "security.password.changed", req, {});
      } catch (_e) {
        console.warn("Session invalidation skipped:", _e.message);
      }
    }

    if (!updates.length) {
      return res.status(400).json({ success: false, message: "No valid fields provided for update" });
    }

    updates.push("updated_at = CURRENT_TIMESTAMP");
    params.push(adminId);

    const [results] = await db.execute(
      `UPDATE admins SET ${updates.join(", ")} WHERE id = ?`,
      params
    );

    if (!results.affectedRows) {
      return res.status(404).json({ success: false, message: "Admin not found" });
    }

    let fetchResults;
    try {
      const [rows] = await db.execute(
        "SELECT id, username, full_name, email, last_login, created_at FROM admins WHERE id = ?",
        [adminId]
      );
      fetchResults = rows;
    } catch (_e) {
      const [rows] = await db.execute("SELECT id, username FROM admins WHERE id = ?", [adminId]);
      fetchResults = rows;
    }

    return res.status(200).json({ success: true, message: "Profile updated successfully", admin: fetchResults[0] });
  } catch (error) {
    console.error("❌ updateAdminProfile:", error);
    return res.status(500).json({ success: false, message: "Server error. Please try again later." });
  }
};

// ─── Placeholder dashboard/patient/export stubs ───────────────────────────────

const stub = (msg, data = {}) => (_req, res) =>
  res.status(200).json({ success: true, message: msg, data });

exports.getDashboardStats       = stub("Dashboard stats fetched", { total_patients: 0, total_appointments: 0, pending_appointments: 0, total_reminders: 0 });
exports.getDashboardPatients    = stub("Dashboard patients fetched", []);
exports.getDashboardAppointments = stub("Dashboard appointments fetched", []);
exports.getDashboardReminders   = stub("Dashboard reminders fetched", []);
exports.getAllPatients           = stub("All patients fetched", []);
exports.getPatientById          = stub("Patient fetched", {});
exports.updatePatient           = stub("Patient updated", {});
exports.deletePatient           = stub("Patient deleted");
exports.searchPatients          = stub("Patients search completed", []);
exports.getAllUsers              = stub("All users fetched", []);
exports.getUserById             = stub("User fetched", {});
exports.updateUser              = stub("User updated", {});
exports.deleteUser              = stub("User deleted");
exports.getAppointments         = stub("Appointments fetched", []);
exports.getPendingAppointmentsCount = (_req, res) => res.status(200).json({ success: true, count: 0 });
exports.getPendingAppointments  = stub("Pending appointments fetched", []);
exports.updateAppointmentStatus = stub("Appointment status updated", {});
exports.exportPatients          = stub("Patients exported", []);
exports.exportUsers             = stub("Users exported", []);
exports.exportAppointments      = stub("Appointments exported", []);
exports.getSettings             = stub("Settings fetched", {});
exports.updateSettings          = stub("Settings updated", {});
