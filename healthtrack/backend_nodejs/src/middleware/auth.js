/**
 * Authentication for admin Bearer sessions (stored in admin_sessions table).
 */

const crypto = require("crypto");
const db = require("../config/db");
const { ADMIN_ROLES } = require("../constants/adminRoles");

async function authenticateAdmin(req, res, next) {
  try {
    const raw = req.headers.authorization || "";
    if (!raw.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authentication required.",
      });
    }
    const token = raw.slice(7).trim();
    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Authentication required.",
      });
    }
    const tokenHash = crypto.createHash("sha256").update(token, "utf8").digest("hex");
    const [rows] = await db.execute(
      `SELECT s.id AS session_id, s.admin_id, a.username, a.role
       FROM admin_sessions s
       INNER JOIN admins a ON a.id = s.admin_id
       WHERE s.token_hash = ?
       LIMIT 1`,
      [tokenHash]
    );

    if (!rows.length) {
      return res.status(401).json({
        success: false,
        message: "Invalid or revoked session.",
      });
    }

    const roleNormalized = String(rows[0].role || "").trim().toLowerCase();
    const isPrivilegedAdmin = ADMIN_ROLES.includes(roleNormalized);
    if (!isPrivilegedAdmin) {
      return res.status(403).json({
        success: false,
        message: "Administrator role required.",
      });
    }

    req.user = {
      id: rows[0].admin_id,
      username: rows[0].username,
      role: rows[0].role,
      sessionId: rows[0].session_id,
    };

    await db.execute(
      "UPDATE admin_sessions SET last_active_at = CURRENT_TIMESTAMP WHERE id = ?",
      [req.user.sessionId]
    );

    next();
  } catch (error) {
    console.error("❌ authenticateAdmin:", error.message);
    return res.status(500).json({
      success: false,
      message: "Authentication error.",
    });
  }
}

const authenticateUser = (req, res, next) => {
  console.log("🔐 User authentication middleware (placeholder)");
  req.user = { id: null, username: "anonymous", role: "user" };
  next();
};

module.exports = {
  authenticateAdmin,
  authenticateUser,
};
