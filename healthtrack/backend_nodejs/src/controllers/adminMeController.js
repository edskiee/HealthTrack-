const path   = require("path");
const fs     = require("fs");
const crypto = require("crypto");
const bcrypt = require("bcryptjs");
const multer = require("multer");
const { authenticator } = require("otplib");
const QRCode = require("qrcode");
const db = require("../config/db");
const { ensureAdminPreferences } = require("../utils/ensureAdminPreferences");
const { writeAudit } = require("../utils/auditLog");

const BOOL_FIELDS = [
  "auto_logout_enabled",
  "analytics_enabled",
  "data_sharing_enabled",
  "appointment_reminders_enabled",
  "appointment_notify_email",
  "appointment_notify_push",
  "appointment_notify_sms",
  "system_alerts_enabled",
  "system_alert_email",
  "system_alert_push",
  "system_alert_sms",
];

const UPLOAD_ROOT = path.join(__dirname, "../../public/uploads/avatars");
if (!fs.existsSync(UPLOAD_ROOT)) {
  fs.mkdirSync(UPLOAD_ROOT, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_ROOT),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "") || ".bin";
    const safe = crypto.randomUUID() + ext;
    cb(null, safe);
  },
});

const uploadAvatarMiddleware = multer({
  storage,
  limits: { fileSize: 4 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!/^image\/(jpeg|jpg|png|gif|webp)$/.test(file.mimetype)) {
      cb(new Error("Invalid file type."));
    } else cb(null, true);
  },
});

async function emitAdminRoom(io, adminId, event, payload) {
  try {
    io.to(`admin_${adminId}`).emit(event, payload);
    io.to("admins").emit(event, payload);
  } catch (e) {
    console.warn("Socket emit skipped:", e.message);
  }
}

function loadPkg() {
  try {
    return require("../../package.json");
  } catch {
    return { version: "0.0.0" };
  }
}

exports.uploadAvatarMiddleware = uploadAvatarMiddleware;

exports.getSystemMeta = async (req, res) => {
  try {
    const pkg = loadPkg();
    const version = pkg.version || "0.0.0";
    const buildNum = process.env.BUILD_NUMBER || process.env.CI_PIPELINE_ID || "local";

    let lastUpdated = "";
    try {
      const [rows] = await db.execute(
        "SELECT last_deployed_at FROM deployment_metadata WHERE singleton_id = 1 LIMIT 1"
      );
      if (rows.length && rows[0].last_deployed_at) {
        lastUpdated = new Date(rows[0].last_deployed_at).toISOString();
      }
    } catch {
      lastUpdated = new Date().toISOString();
    }

    const nodeEnv =
      process.env.NEXT_PUBLIC_ENV ||
      process.env.APP_ENV ||
      process.env.NODE_ENV ||
      "production";

    const healthLabel =
      typeof req.app?.locals?.serverHealthLabel === "string"
        ? req.app.locals.serverHealthLabel
        : "Operational";

    return res.status(200).json({
      success: true,
      data: {
        version,
        versionLabel: `v${version} Build ${buildNum}`,
        environment: nodeEnv.charAt(0).toUpperCase() + nodeEnv.slice(1),
        lastUpdatedIso: lastUpdated,
        serverStatus: healthLabel,
      },
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Could not load system metadata.",
    });
  }
};

/**
 * List audit logs with pagination support
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
exports.listAuditLogs = async (req, res) => {
  try {
    // Parse and validate limit parameter
    const limit = parseInt(req.query.limit) || 50;
    const page = parseInt(req.query.page) || 1;
    
    // Validate parsed values
    if (isNaN(limit) || limit <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid limit parameter'
      });
    }
    
    if (isNaN(page) || page <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid page parameter'
      });
    }
    
    // Cap limit to maximum of 200
    const finalLimit = Math.min(limit, 200);
    
    // Calculate offset as guaranteed integer
    const offset = (page - 1) * finalLimit;
    
    // Get total count for pagination
    const [countResult] = await db.query(
      'SELECT COUNT(*) as total FROM audit_logs'
    );
    const total = countResult[0].total;
    
    // Get paginated audit logs
    const [rows] = await db.query(
      `SELECT id, admin_id, action, ip_address, user_agent,
              metadata, created_at
       FROM audit_logs
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [Number(finalLimit), Number(offset)]
    );
    
    return res.json({ 
      success: true, 
      data: rows, 
      pagination: { 
        page, 
        limit: finalLimit, 
        total 
      } 
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch audit logs',
      error: error.message
    });
  }
};

exports.getMyPreferences = async (req, res) => {
  try {
    const adminId = req.user.id;
    await ensureAdminPreferences(adminId);

    const [[adminPrefs]] = await db.execute(
      `SELECT * FROM admin_preferences WHERE admin_id = ? LIMIT 1`,
      [adminId]
    );

    const adminRowSqlPrimary =
      "SELECT id, username, full_name, email, last_login, created_at, role, password_changed_at FROM admins WHERE id = ?";
    const adminRowSqlFallback =
      "SELECT id, username, COALESCE(role, 'Administrator') AS role FROM admins WHERE id = ?";

    let adminRows;
    try {
      const [rows] = await db.execute(adminRowSqlPrimary, [adminId]);
      adminRows = rows;
    } catch (_err) {
      const [rows] = await db.execute(adminRowSqlFallback, [adminId]);
      adminRows = rows;
    }

    const adminRow = adminRows[0];

    let totpEnabled = 0;
    try {
      totpEnabled = adminPrefs?.totp_enabled ? 1 : 0;
    } catch (_e) {
      totpEnabled = 0;
    }

    return res.json({
      success: true,
      data: {
        admin: {
          ...adminRow,
          totp_enabled: totpEnabled,
        },
        preferences: adminPrefs,
      },
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Failed to load preferences.",
    });
  }
};

exports.patchMyPreferences = async (req, res) => {
  try {
    const adminId = req.user.id;
    await ensureAdminPreferences(adminId);

    const patch = req.body && typeof req.body === "object" ? req.body : {};
    const [[current]] = await db.execute(
      "SELECT phone FROM admin_preferences WHERE admin_id = ?",
      [adminId]
    );

    let phoneOnFile = (current?.phone || "").trim();

    const updates = [];
    const vals = [];

    if (patch.theme_mode !== undefined) {
      const t = String(patch.theme_mode).toLowerCase();
      if (!["light", "dark", "system"].includes(t)) {
        return res.status(400).json({ success: false, message: "Invalid theme_mode." });
      }
      updates.push("theme_mode = ?");
      vals.push(t);
    }

    if (patch.phone !== undefined) {
      phoneOnFile = String(patch.phone ?? "").trim();
      updates.push("phone = ?");
      vals.push(patch.phone === null ? null : String(patch.phone));
    }

    const mergedPhone = phoneOnFile;

    for (const f of BOOL_FIELDS) {
      if (patch[f] !== undefined) {
        const smsRelated =
          f === "appointment_notify_sms" || f === "system_alert_sms";
        const wantOn = !!patch[f];
        if (smsRelated && wantOn && !mergedPhone) {
          return res.status(400).json({
            success: false,
            message: "Add a mobile number to your profile before enabling SMS alerts.",
          });
        }
        updates.push(`${f} = ?`);
        vals.push(wantOn ? 1 : 0);
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: "No valid fields supplied." });
    }

    vals.push(adminId);

    await db.execute(
      `UPDATE admin_preferences SET ${updates.join(", ")}, updated_at = CURRENT_TIMESTAMP
       WHERE admin_id = ?`,
      vals
    );

    await writeAudit(adminId, "settings.preferences.updated", req, { keys: Object.keys(patch) });
    emitAdminRoom(req.app?.locals?.io, adminId, "adminPreferencesRefresh", {});

    return res.json({
      success: true,
      message: "Preferences updated.",
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Failed to save preferences.",
    });
  }
};

exports.listSessions = async (req, res) => {
  try {
    const adminId = req.user.id;
    const [rows] = await db.execute(
      `SELECT id, device_label, browser_label, ip_address,
              last_active_at, created_at
       FROM admin_sessions
       WHERE admin_id = ?
       ORDER BY last_active_at DESC`,
      [adminId]
    );

    const currentSid = req.user.sessionId;

    const data = rows.map((row) => ({
      ...row,
      isCurrent: row.id === currentSid,
    }));

    return res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Failed to list sessions.",
    });
  }
};

exports.revokeSession = async (req, res) => {
  try {
    const adminId = req.user.id;
    const sid = req.params.sessionId;

    const [chk] = await db.execute(
      "SELECT admin_id FROM admin_sessions WHERE id = ? LIMIT 1",
      [sid]
    );

    if (!chk.length || chk[0].admin_id !== adminId) {
      return res.status(404).json({
        success: false,
        message: "Session not found.",
      });
    }

    if (sid === req.user.sessionId) {
      return res.status(400).json({
        success: false,
        message: "Use sign out instead of revoking your current session here.",
      });
    }

    await db.execute("DELETE FROM admin_sessions WHERE id = ?", [sid]);
    await writeAudit(adminId, "session.revoked", req, { sessionId: sid });
    emitAdminRoom(req.app?.locals?.io, adminId, "adminSessionsRefresh", {});

    return res.json({
      success: true,
      message: "Session revoked.",
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Failed to revoke session.",
    });
  }
};

exports.postAvatarUpload = async (req, res) => {
  try {
    const adminId = req.user.id;
    if (!req.file) {
      return res.status(400).json({ success: false, message: "No file uploaded." });
    }

    await ensureAdminPreferences(adminId);

    const rel = `/uploads/avatars/${req.file.filename}`;

    await db.execute(`UPDATE admin_preferences SET avatar_url = ?, updated_at = CURRENT_TIMESTAMP
      WHERE admin_id = ?`, [rel, adminId]);

    await writeAudit(adminId, "profile.avatar.updated", req, { path: rel });

    emitAdminRoom(req.app?.locals?.io, adminId, "adminPreferencesRefresh", {});

    return res.json({
      success: true,
      message: "Avatar updated.",
      data: { avatar_url: rel },
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Avatar upload failed.",
    });
  }
};

exports.twoFactorSetupStart = async (req, res) => {
  try {
    const adminId = req.user.id;
    await ensureAdminPreferences(adminId);

    const secret = authenticator.generateSecret();
    await db.execute(
      `UPDATE admin_preferences SET totp_pending_secret = ?, updated_at = CURRENT_TIMESTAMP
       WHERE admin_id = ?`,
      [secret, adminId]
    );

    const [rows] = await db.execute("SELECT username, email FROM admins WHERE id = ?", [adminId]);
    const account = `${rows[0]?.email || rows[0]?.username || "admin"}`;
    const label = encodeURIComponent(account);
    const issuer = encodeURIComponent("HealthTrack");
    const otpauthURL = `otpauth://totp/${issuer}:${label}?issuer=${issuer}&secret=${secret}`;

    let qr_base64_png = "";
    try {
      qr_base64_png = await QRCode.toDataURL(otpauthURL);
    } catch (e) {
      console.warn("QR generation failed:", e.message);
    }

    await writeAudit(adminId, "security.2fa.setup_started", req, {});

    return res.json({
      success: true,
      data: {
        otpauth_url: otpauthURL,
        qr_base64_png,
      },
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Could not begin 2FA setup.",
    });
  }
};

exports.twoFactorConfirm = async (req, res) => {
  try {
    const adminId = req.user.id;
    const code = String(req.body?.code || "").replace(/\s/g, "");
    if (!/^\d{6}$/.test(code)) {
      return res.status(400).json({ success: false, message: "Enter a valid 6-digit code." });
    }

    await ensureAdminPreferences(adminId);

    const [[prefs]] = await db.execute(
      "SELECT totp_pending_secret FROM admin_preferences WHERE admin_id = ? LIMIT 1",
      [adminId]
    );

    const pending = prefs?.totp_pending_secret;
    if (!pending) {
      return res.status(400).json({
        success: false,
        message: "Start setup again before confirming.",
      });
    }

    if (!authenticator.check(code, pending)) {
      return res.status(400).json({ success: false, message: "Invalid verification code." });
    }

    await db.execute(
      `UPDATE admin_preferences
       SET totp_secret = ?, totp_pending_secret = NULL, totp_enabled = 1,
           updated_at = CURRENT_TIMESTAMP
       WHERE admin_id = ?`,
      [pending, adminId]
    );

    await writeAudit(adminId, "security.2fa.enabled", req, {});

    emitAdminRoom(req.app?.locals?.io, adminId, "adminPreferencesRefresh", {});

    return res.json({
      success: true,
      message: "Two-factor authentication is enabled.",
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Could not enable 2FA.",
    });
  }
};

exports.twoFactorDisable = async (req, res) => {
  try {
    const adminId = req.user.id;
    const pwd = req.body?.current_password ?? req.body?.password;
    if (!pwd || String(pwd).length < 4) {
      return res.status(400).json({ success: false, message: "Current password required." });
    }

    // Fetch stored password and verify (supports both bcrypt and legacy MD5)
    const [verify] = await db.execute(
      "SELECT password FROM admins WHERE id = ? LIMIT 1",
      [adminId]
    );
    if (!verify.length) {
      return res.status(404).json({ success: false, message: "Admin not found." });
    }

    const stored   = verify[0].password;
    const isBcrypt = /^\$2[aby]\$/.test(stored);
    let passwordOk = false;

    if (isBcrypt) {
      passwordOk = await bcrypt.compare(String(pwd), stored);
    } else {
      // Legacy MD5
      const md5 = crypto.createHash("md5").update(String(pwd)).digest("hex");
      passwordOk = md5 === stored;
      // Opportunistically rehash to bcrypt while we have the plaintext password
      if (passwordOk) {
        try {
          const newHash = await bcrypt.hash(String(pwd), 12);
          await db.execute("UPDATE admins SET password = ? WHERE id = ?", [newHash, adminId]);
          console.log(`🔐 Admin password rehashed to bcrypt for admin ID=${adminId}`);
        } catch (rehashErr) {
          console.error("⚠️ Admin password rehash failed (non-fatal):", rehashErr.message);
        }
      }
    }

    if (!passwordOk) {
      return res.status(400).json({ success: false, message: "Password is incorrect." });
    }

    await db.execute(
      `UPDATE admin_preferences
       SET totp_secret = NULL, totp_pending_secret = NULL, totp_enabled = 0,
           updated_at = CURRENT_TIMESTAMP
       WHERE admin_id = ?`,
      [adminId]
    );

    await writeAudit(adminId, "security.2fa.disabled", req, {});

    emitAdminRoom(req.app?.locals?.io, adminId, "adminPreferencesRefresh", {});

    return res.json({
      success: true,
      message: "Two-factor authentication is disabled.",
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Could not disable 2FA.",
    });
  }
};

exports.revokeMySessionLogout = async (req, res) => {
  try {
    await db.execute("DELETE FROM admin_sessions WHERE id = ?", [req.user.sessionId]);
    await writeAudit(req.user.id, "session.logout", req, {});
    return res.json({
      success: true,
      message: "Signed out.",
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "Sign out failed.",
    });
  }
};
